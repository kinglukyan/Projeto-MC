-- 045: Guardian campaign. Apply after the corrected migration 044.
begin;
do $prerequisites$ begin
 if to_regprocedure('public._r_action_before_audit44(jsonb,jsonb,text,jsonb)') is null then
  raise exception 'Aplique primeiro a migração 044 corrigida.';
 end if;
end $prerequisites$;
__CATALOG__

create table if not exists public.guardian_campaign_progress(
 player_id uuid not null references public.profiles(id) on delete cascade,
 region_id text not null,cleared integer not null default 0 check(cleared between 0 and 20),
 updated_at timestamptz not null default now(),primary key(player_id,region_id)
);
create table if not exists public.guardian_campaign_runs(
 id uuid primary key default gen_random_uuid(),player_id uuid not null references public.profiles(id) on delete cascade,
 node_id text not null,context jsonb not null,status text not null default 'active' check(status in('active','completed')),
 version integer not null default 1,deadline timestamptz not null default now()+interval '30 seconds',
 created_at timestamptz not null default now(),finished_at timestamptz
);
create unique index if not exists guardian_campaign_one_active on public.guardian_campaign_runs(player_id) where status='active';
create index if not exists guardian_campaign_run_owner on public.guardian_campaign_runs(player_id,created_at desc);
create table if not exists public.guardian_campaign_requests(
 run_id uuid not null references public.guardian_campaign_runs(id) on delete cascade,
 request_id uuid not null,payload_hash text not null,created_at timestamptz not null default now(),primary key(run_id,request_id)
);
create table if not exists public.guardian_campaign_rewards(
 player_id uuid not null references public.profiles(id) on delete cascade,
 milestone integer not null check(milestone between 1 and 44),item_id text,
 granted_at timestamptz,created_at timestamptz not null default now(),primary key(player_id,milestone)
);
alter table public.guardian_campaign_progress enable row level security;
alter table public.guardian_campaign_runs enable row level security;
alter table public.guardian_campaign_requests enable row level security;
alter table public.guardian_campaign_rewards enable row level security;
revoke all on public.guardian_campaign_progress,public.guardian_campaign_runs,public.guardian_campaign_requests,public.guardian_campaign_rewards from public,anon,authenticated;

create or replace function public._gc_node(nid text) returns jsonb language sql immutable set search_path='' as $$
 select public._gc_data()#>array['nodes',nid] $$;
create or replace function public._gc_region(rid text) returns jsonb language sql immutable set search_path='' as $$
 select value from jsonb_array_elements(public._gc_data()->'regions') where value->>'id'=rid limit 1 $$;
create or replace function public._gc_shuffle(pool jsonb) returns jsonb language sql volatile set search_path='' as $$
 select coalesce(jsonb_agg(value order by random()),'[]') from jsonb_array_elements(pool) $$;
create or replace function public._gc_note(x jsonb,message text) returns jsonb language sql immutable set search_path='' as $$
 select jsonb_set(x,'{s,log}',coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(jsonb_build_array(message)||coalesce(x#>'{s,log}','[]')) with ordinality a(value,ordinality) where ordinality<=30),'[]'),true) $$;
create or replace function public._gc_stats(x jsonb,actor text,a jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare stats jsonb:=coalesce(x#>'{s,campaignStats}','{"plays":[],"actions":0,"passes":0}');
begin
 stats:=stats||jsonb_build_object('actions',coalesce((stats->>'actions')::integer,0)+1,'passes',coalesce((stats->>'passes')::integer,0)+case when a->>'type'='pass' then 1 else 0 end);
 if a->>'type'='play' then stats:=jsonb_set(stats,'{plays}',coalesce(stats->'plays','[]')||jsonb_build_array(jsonb_build_object('actor_id',actor,'card_id',a->>'card_id','round',x#>'{s,round}','at',clock_timestamp())),true);end if;
 return jsonb_set(x,'{s,campaignStats}',stats,true);
end $$;
create or replace function public._gc_deck(nid text) returns jsonb language plpgsql stable set search_path='' as $$
declare n jsonb:=public._gc_node(nid);f text:=public._gc_region(n->>'region')->>'faction';result jsonb:='[]';entry record;c jsonb;target integer:=(n->>'deckSize')::integer;i integer;pool text[];
begin
 if not coalesce((n->>'placeholder')::boolean,false) and not public._card_enabled(n->>'opponent') then raise exception 'Este guardião está temporariamente em manutenção.';end if;
 for entry in select key,value from jsonb_each_text(n->'deck') loop
  if public._card_enabled(entry.key) then for i in 1..entry.value::integer loop result:=result||jsonb_build_array(entry.key);end loop;end if;
 end loop;
 select array_agg(value->>'id' order by value->>'id') into pool from jsonb_array_elements(public._gc_data()->'cards')
  where value->>'faction'=f and value->>'kind'='unit' and not coalesce((value->>'specialOnly')::boolean,false) and not coalesce((value->>'previewOnly')::boolean,false) and public._card_enabled(value->>'id');
 if coalesce(array_length(pool,1),0)=0 then raise exception 'Esta trilha está em manutenção. Tente novamente mais tarde.';end if;
 -- Replace paused cards without introducing off-faction cards or changing their printed power.
 foreach f in array pool loop
  exit when jsonb_array_length(result)>=target;
  select count(*)::integer into i from jsonb_array_elements_text(result) where value=f;
  while i<4 and jsonb_array_length(result)<target loop result:=result||jsonb_build_array(f);i:=i+1;end loop;
 end loop;
 if jsonb_array_length(result)<14 then raise exception 'Cartas insuficientes disponíveis nesta trilha.';end if;
 return result;
end $$;

-- Heuristic evaluation only uses public board information and the AI's own cards.
create or replace function public._gc_value(cid text) returns numeric language plpgsql stable set search_path='' as $$
declare c jsonb:=public._r_card(cid);r jsonb:=public._gc_data()#>array['impact',cid];
begin return coalesce((c->>'power')::numeric,0)+coalesce((r#>>'{}')::numeric,1);end $$;
create or replace function public._gc_card_score(x jsonb,actor text,cid text,l integer,level integer) returns numeric language plpgsql stable set search_path='' as $$
declare t text:=x#>>array['r',actor,'team'];enemy text:=public._r_other(t);c jsonb:=public._r_card(cid);r jsonb:=public._r_data()#>array['remakeRules',cid];
 score numeric:=coalesce((c->>'power')::numeric,0);n integer;same integer;own numeric;opp numeric;v jsonb;op text:=r->>'op';valid_count integer;
begin
 select count(*)::integer,coalesce(sum(public._r_power(x->'s',t,value)),0) into n,own from jsonb_array_elements(x#>array['s',t,'field']) where (value->>'lane')::integer=l;
 select count(*)::integer into same from jsonb_array_elements(x#>array['s',t,'field']) where (value->>'lane')::integer=l and public._r_identity(value)=cid;
 select coalesce(sum(public._r_power(x->'s',enemy,value)),0) into opp from jsonb_array_elements(x#>array['s',enemy,'field']) where (value->>'lane')::integer=l;
 if level=1 then return case when c->>'kind'='unit' then coalesce((c->>'power')::numeric,0)-n*.8 else 1 end;end if;
 if c->>'kind'='unit' then
  score:=score+level*.15*coalesce((public._gc_data()#>>array['impact',cid])::numeric,1);
  if cid in('soldado-esparta','guardiao-nordico','homem') then score:=score*power(2::numeric,same)+own*least(.75,same*.2);end if;
  if cid='athena' then score:=score+n*2;end if;
  if cid='apolo' then score:=score*2+own;end if;
  if cid='minotauro' and n=0 then score:=score+3;end if;
  if cid='sobek' and n>0 then score:=score+2;end if;
  if cid='lobo-omega' and n=0 and opp>score then score:=score+8;end if;
  if cid='lobo-alfa' then score:=score+2*(select count(*) from jsonb_array_elements(x#>array['s',t,'field']) where (value->>'lane')::integer=l and public._r_identity(value)='lobo-beta');end if;
  if cid='mulher' then score:=score*power(2::numeric,(select count(*) from jsonb_array_elements(x#>array['s',t,'field']) where (value->>'lane')::integer=l and public._r_identity(value)='homem'));end if;
  if cid in('ra','ares','aquiles','heimdall') then score:=score+n*(case when cid='heimdall' then level*.5 else 1.2 end);end if;
  if cid='poseidon' then score:=score+(select coalesce(sum(least(2,public._r_power(x->'s',enemy,value))),0) from jsonb_array_elements(x#>array['s',enemy,'field']) where (value->>'lane')::integer=0 and not public._x_block(x->'s',enemy,value,t,'reduce'));end if;
  if cid='zeus' then select count(*)::integer,coalesce(avg(public._r_power(x->'s',enemy,value)),0) into valid_count,opp from jsonb_array_elements(x#>array['s',enemy,'field']) where not public._x_block(x->'s',enemy,value,t,'destroy');score:=score+least(2,valid_count)*opp;end if;
  if cid='thor' then score:=score+(select coalesce(max(public._r_power(x->'s',enemy,value)),0) from jsonb_array_elements(x#>array['s',enemy,'field']) where not public._x_block(x->'s',enemy,value,t,'destroy'));end if;
  if cid='medusa' and jsonb_array_length(x#>array['r',case when actor='guardian-bot' then x#>>'{s,campaignPlayer}' else 'guardian-bot' end,'hand'])>0 then score:=score+level+2;end if;
  if cid in('hades','isis','anubis') or op in('recover','reviveQuiet','graveDraw','graveGrowth') then score:=score+least(7,jsonb_array_length(x#>array['s',t,'grave']))*.7;end if;
  if op in('aura','company','occupiedAura','equipmentAura','grow','saveOnce','protectMove','protectDestroy','protectReduction') then score:=score+n*coalesce((r->>'amount')::numeric,1)*(case when level>2 then 1 else .4 end);end if;
  if op in('drawBuff','drawMove','drawCompany','draft','reorder','choice','unsilenceDraw') then score:=score+case when jsonb_array_length(x#>array['r',actor,'deck'])>0 then 2+level*.4 else 0 end;end if;
  if op in('wave','waveBoth') then
   score:=score+(select coalesce(sum(least(coalesce((r->>'amount')::numeric,2),public._r_power(x->'s',enemy,value))),0) from jsonb_array_elements(x#>array['s',enemy,'field']) where (value->>'lane')::integer=coalesce((r->>'fixedLane')::integer,l) and not public._x_block(x->'s',enemy,value,t,'reduce'));
   if op='waveBoth' then score:=score-(select coalesce(sum(least(2,public._r_power(x->'s',t,value))),0) from jsonb_array_elements(x#>array['s',t,'field']) where (value->>'lane')::integer=l);end if;
  end if;
  if op in('destroy','reduce','steal','silence','purge','moveEnemy') then score:=score+least(opp,6)*(.3+level*.12);end if;
  if op='clones' then score:=score+4;end if;
  -- Reinforce existing same-faction allies instead of scattering company units.
  score:=score+n*least(.6,level*.1);
 elsif c->>'kind'='equipment' then score:=coalesce((public._r_data()#>>array['equipment',cid,'bonus'])::numeric,2)+level*.35;
 else score:=2+level*.3+(select count(*) from jsonb_array_elements(x#>array['s',t,'field']) where public._r_card(public._r_identity(value))->>'faction'=c->>'faction');
 end if;
 return score;
end $$;

create or replace function public._gc_pick_play(x jsonb,actor text,level integer) returns jsonb language plpgsql stable set search_path='' as $$
declare t text:=x#>>array['r',actor,'team'];enemy text:=public._r_other(t);cid text;c jsonb;l integer;score numeric;best numeric:=-1e30;result jsonb;zone text;own numeric;opp numeric;
begin
 if (x#>>'{s,guardianCampaign,region}'='greece' or x#>>'{s,campaignRegion}'='greece') and actor='guardian-bot' and coalesce((x#>>array['r',actor,'turnsTaken'])::integer,0)> (case when coalesce((x#>>'{s,campaignStage}')::integer,1)<=5 then 3 when (x#>>'{s,campaignStage}')::integer<=10 then 4 when (x#>>'{s,campaignStage}')::integer<=15 then 5 else 6 end) then return jsonb_build_object('type','pass');end if;
 own:=public._r_score(x->'s',t);opp:=public._r_score(x->'s',enemy);
 if (x#>>array['r',case when actor='guardian-bot' then x#>>'{s,campaignPlayer}' else 'guardian-bot' end,'passed'])::boolean and own>opp then return jsonb_build_object('type','pass');end if;
 if level>=3 and coalesce((x#>>'{s,round}')::integer,1)<3 and own>opp+12 and jsonb_array_length(x#>array['r',actor,'hand'])<=3 then return jsonb_build_object('type','pass');end if;
 for cid in select distinct value from jsonb_array_elements_text(x#>array['r',actor,'hand']) loop
  c:=public._r_card(cid);if not public._card_enabled(cid) then continue;end if;
  if c->>'kind'='equipment' and not exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) where public._x_global(x->'s',t,value) and public._r_equip(cid,value)) then continue;end if;
  if c->>'kind' not in('unit','equipment') then zone:=case c->>'kind' when 'location' then 'local' when 'terrain' then 'terrain' else 'climate' end;if not public._zone_can_replace(c,public._r_card(x#>>array['s','sharedZones',zone])) then continue;end if;end if;
  for l in 0..(case when c->>'kind'='unit' then 2 else 0 end) loop
   if c->>'kind'='unit' and not public._x_room(x->'s',t,l) then continue;end if;
   score:=public._gc_card_score(x,actor,cid,l,level);
   if score>best then best:=score;result:=jsonb_build_object('type','play','card_id',cid,'lane',l);end if;
  end loop;
 end loop;
 return coalesce(result,jsonb_build_object('type','pass'));
end $$;

create or replace function public._gc_pick_choice(x jsonb,p jsonb,level integer) returns text language plpgsql stable set search_path='' as $$
declare e jsonb:=p->'event';actor text:=p->>'actor';t text:=x#>>array['r',actor,'team'];enemy text:=public._r_other(t);r jsonb:=coalesce(e->'rule',public._x_rule(public._r_unit(x->'s',e->>'team',e->>'uid')));op text:=coalesce(r->>'op',e->>'op');
 o jsonb;v jsonb;score numeric;best numeric:=-1e30;result text;pwr numeric;list jsonb;key text;
begin
 for o in select value from jsonb_array_elements(p->'options') loop
  score:=0;key:=o->>'value';v:=coalesce(public._r_unit(x->'s',t,key),public._r_unit(x->'s',enemy,key));
  if key='skip' then score:=-100;
  elsif e->>'phase' in('draft','order') then score:=public._gc_value(o->>'cardId');
  elsif e->>'phase'='lane' or e->>'op'='move_lane' then
   v:=public._r_unit(x->'s',coalesce(e->>'targetTeam',t),coalesce(e->>'targetUid',e->>'targetUid'));score:=(select count(*) from jsonb_array_elements(x#>array['s',coalesce(e->>'targetTeam',t),'field']) where value->>'lane'=key)*case when coalesce(e->>'targetTeam',t)=t then 2 else -2 end;
  elsif key='draw' then score:=case when jsonb_array_length(x#>array['r',actor,'hand'])<4 then 8 else 3 end;
  elsif key='buff' then score:=5;
  elsif key='discard' then score:=case when public._gc_value(x#>>array['r',actor,'deck','0'])<5 then 5 else 0 end;
  elsif key='keep' then score:=3;
  elsif op in('recover','reviveQuiet') or e->>'op' in('revive','revive_cost','anubis_revive') then score:=public._gc_value(o->>'cardId');
  elsif e->>'op'='shuffle_lane' then score:=(select coalesce(sum(public._r_power(x->'s',enemy,value)),0) from jsonb_array_elements(x#>array['s',enemy,'field']) where value->>'lane'=key)-(select coalesce(sum(public._r_power(x->'s',t,value)),0) from jsonb_array_elements(x#>array['s',t,'field']) where value->>'lane'=key);
  elsif op in('equipmentDestroy','equipmentReturn') then score:=public._gc_value(o->>'cardId');
  elsif v is not null then
   pwr:=public._r_power(x->'s',case when public._r_unit(x->'s',t,key) is not null then t else enemy end,v);
   score:=pwr+level*.2*coalesce((public._gc_data()#>>array['impact',public._r_identity(v)])::numeric,1);
   if op in('sacrificeBuff','sacrificeFeed','sacrificeHunt','bounce') and coalesce(e->>'phase','')<>'hunt' then score:=-pwr;end if;
   if op='cleanse' then score:=-least(0,coalesce((v->>'bonus')::numeric,0))-least(0,coalesce((v->>'powerShift')::numeric,0));end if;
   if op='reduce' then score:=least(pwr,coalesce((r->>'amount')::numeric,2));end if;
   if e->>'phase'='shiva' and e->>'targetTeam'=t then score:=-public._gc_value(v->>'cardId');end if;
   if e->>'op'='equip' or op in('guard','buff') then score:=score+(select count(*) from jsonb_array_elements(x#>array['s',t,'field']) where value->>'lane'=v->>'lane');end if;
  elsif op='copyPower' then
   v:=public._r_unit(x->'s',split_part(key,':',1),split_part(key,':',2));score:=public._r_power(x->'s',split_part(key,':',1),v);
  else score:=public._gc_value(o->>'cardId');end if;
  if score>best then best:=score;result:=key;end if;
 end loop;
 return coalesce(result,p#>>'{options,0,value}');
end $$;
