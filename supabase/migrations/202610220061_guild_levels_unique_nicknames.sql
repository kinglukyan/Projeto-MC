-- Apply after 060. Prospective rewards only; no historical XP backfill.
begin;
lock table public.profiles in share row exclusive mode;
create or replace function public.nickname_key(p_name text) returns text
language sql immutable strict set search_path='' as $$
 select lower(regexp_replace(btrim(p_name),'[[:space:]]+',' ','g'))
$$;
revoke all on function public.nickname_key(text) from public,anon;
grant execute on function public.nickname_key(text) to authenticated;
-- Keep the oldest account's name. Only existing collisions receive a suffix.
do $deduplicate$
declare p record; candidate text; suffix integer;
begin
 for p in select id,nickname from (select id,nickname,row_number() over(partition by public.nickname_key(nickname) order by created_at,id) n from public.profiles) x where n>1 order by id loop
  suffix:=0;
  loop
   candidate:=left(btrim(p.nickname),14)||'-'||left(replace(p.id::text,'-',''),6)||case when suffix=0 then '' else '-'||suffix end;
   exit when not exists(select 1 from public.profiles q where q.id<>p.id and public.nickname_key(q.nickname)=public.nickname_key(candidate));
   suffix:=suffix+1;
  end loop;
  update public.profiles set nickname=candidate,display_name=candidate where id=p.id;
 end loop;
end $deduplicate$;
create unique index if not exists profiles_unique_nickname on public.profiles(public.nickname_key(nickname));
create or replace function public._enforce_unique_nickname() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 new.nickname:=regexp_replace(btrim(new.nickname),'[[:space:]]+',' ','g');
 if exists(select 1 from public.profiles p where p.id<>new.id and public.nickname_key(p.nickname)=public.nickname_key(new.nickname)) then
  raise exception 'Este nickname já está em uso. Escolha outro.' using errcode='23505',constraint='profiles_unique_nickname';
 end if;
 return new;
end $$;
revoke all on function public._enforce_unique_nickname() from public,anon,authenticated;
drop trigger if exists enforce_unique_nickname on public.profiles;
create trigger enforce_unique_nickname before insert or update of nickname on public.profiles for each row execute function public._enforce_unique_nickname();
create or replace function public.nickname_available(p_name text) returns boolean
language sql stable security definer set search_path='' as $$
 select char_length(btrim(p_name)) between 2 and 24 and not exists(
  select 1 from public.profiles p where public.nickname_key(p.nickname)=public.nickname_key(p_name) and p.id is distinct from auth.uid())
$$;
revoke all on function public.nickname_available(text) from public,anon,authenticated;
grant execute on function public.nickname_available(text) to anon,authenticated;

revoke insert,update,delete on public.guilds from anon,authenticated;
alter table public.guilds add column if not exists experience bigint not null default 0 check(experience>=0);
create or replace function public.guild_level(p_xp bigint) returns integer
language sql immutable set search_path='' as $$
 select count(*)::integer from unnest(array[0,10000,30000,65000,120000,200000,310000,455000,640000,870000]::bigint[]) threshold where threshold<=greatest(0,coalesce(p_xp,0))
$$;
revoke all on function public.guild_level(bigint) from public,anon;
grant execute on function public.guild_level(bigint) to authenticated;
alter table public.match_history add column if not exists guild_bonus_percent integer not null default 0;
alter table public.match_history add column if not exists guild_xp_earned integer not null default 0;
alter table public.match_history add column if not exists guild_reward_id uuid;
alter table public.match_history add column if not exists tiebreak_match_id uuid references public.tiebreak_pvp_matches(id) on delete cascade;
create unique index if not exists match_history_tiebreak_unique on public.match_history(tiebreak_match_id,player_id) where tiebreak_match_id is not null;
alter table public.match_history drop constraint if exists match_history_mode_check;
alter table public.match_history add constraint match_history_mode_check check(mode in ('normal','ranked','friend','guardian','tiebreak'));
-- A match snapshot freezes membership/level for all four players before awarding.
create table if not exists public.guild_match_snapshots(
 source_id uuid primary key,participants jsonb not null,created_at timestamptz not null default now()
);
create table if not exists public.guild_xp_ledger(
 history_id uuid primary key references public.match_history(id) on delete cascade,
 guild_id uuid references public.guilds(id) on delete set null,
 player_id uuid references public.profiles(id) on delete set null,
 amount integer not null check(amount in (100,200)),bonus_percent integer not null,
 created_at timestamptz not null default now()
);
alter table public.guild_match_snapshots enable row level security;
alter table public.guild_xp_ledger enable row level security;
revoke all on public.guild_match_snapshots,public.guild_xp_ledger from public,anon,authenticated;
create index if not exists guild_xp_ledger_guild_date on public.guild_xp_ledger(guild_id,created_at);

create or replace function public._guild_match_rewards() returns trigger
language plpgsql security definer set search_path='' as $$
declare source uuid:=coalesce(new.match_id,new.guardian_match_id,new.tiebreak_match_id);
 snapshot jsonb;entry jsonb;gid uuid;level_no integer;percent integer;duo boolean;amount integer;bonus_xp integer;bonus_coins integer;inserted integer;
begin
 if source is null then return new;end if;
 perform pg_advisory_xact_lock(hashtextextended(source::text,61));
 select s.participants into snapshot from public.guild_match_snapshots s where s.source_id=source;
 if snapshot is null then
  -- Lock guild rows in one stable order before freezing levels and membership.
  perform 1 from public.guilds g where g.id in (
   select m.guild_id from public.guild_members m where m.player_id=new.player_id or
    m.player_id in(select d.player_id from public.duo_match_players d where d.match_id=new.match_id) or
    m.player_id in(select v.uid from public.game_matches x cross join lateral (values(x.player_one),(x.player_two)) v(uid) where x.id=new.match_id) or
    m.player_id in(select v.uid from public.tiebreak_pvp_matches x cross join lateral (values(x.player_one),(x.player_two)) v(uid) where x.id=new.tiebreak_match_id)
  ) order by g.id for update;
  with players as (
   select new.player_id uid,null::integer team where new.match_id is null and new.tiebreak_match_id is null
   union select d.player_id,d.team from public.duo_match_players d where d.match_id=new.match_id
   union select x.player_one,1 from public.game_matches x where x.id=new.match_id and coalesce(x.team_size,1)=1
   union select x.player_two,2 from public.game_matches x where x.id=new.match_id and coalesce(x.team_size,1)=1
   union select x.player_one,1 from public.tiebreak_pvp_matches x where x.id=new.tiebreak_match_id
   union select x.player_two,2 from public.tiebreak_pvp_matches x where x.id=new.tiebreak_match_id
  ), members as (
   select p.*,m.guild_id,public.guild_level(g.experience) level_no from players p left join public.guild_members m on m.player_id=p.uid left join public.guilds g on g.id=m.guild_id
  ) select coalesce(jsonb_object_agg(a.uid::text,jsonb_build_object('guild',a.guild_id,'level',a.level_no,'duo',
   new.match_id is not null and exists(select 1 from public.game_matches x where x.id=new.match_id and x.team_size=2)
   and a.guild_id is not null and exists(select 1 from members b where b.uid<>a.uid and b.team=a.team and b.guild_id=a.guild_id))),'{}') into snapshot from members a;
  insert into public.guild_match_snapshots(source_id,participants) values(source,snapshot);
 end if;
 entry:=snapshot->new.player_id::text;gid:=(entry->>'guild')::uuid;
 if gid is null or not exists(select 1 from public.guilds g where g.id=gid) then return new;end if;
 level_no:=(entry->>'level')::integer;duo:=coalesce((entry->>'duo')::boolean,false);
 percent:=level_no*10+case when duo then 100 else 0 end;amount:=case when duo then 200 else 100 end;
 insert into public.guild_xp_ledger(history_id,guild_id,player_id,amount,bonus_percent) values(new.id,gid,new.player_id,amount,percent) on conflict do nothing;
 get diagnostics inserted=row_count;if inserted=0 then return new;end if;
 bonus_xp:=floor(new.xp_earned::numeric*percent/100)::integer;
 bonus_coins:=floor(new.coins_earned::numeric*percent/100)::integer;
 update public.match_history set xp_earned=new.xp_earned+bonus_xp,coins_earned=new.coins_earned+bonus_coins,
  guild_bonus_percent=percent,guild_xp_earned=amount,guild_reward_id=gid where id=new.id;
 update public.profiles set xp=xp+bonus_xp,mythic_coins=mythic_coins+bonus_coins where id=new.player_id;
 update public.guilds set experience=experience+amount where id=gid;
 return new;
end $$;
revoke all on function public._guild_match_rewards() from public,anon,authenticated;
drop trigger if exists award_guild_progression on public.match_history;
create trigger award_guild_progression after insert on public.match_history for each row execute function public._guild_match_rewards();

create or replace function public.guild_social_hub(p_search text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); gid uuid; my_role text; result jsonb;
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 select m.guild_id,m.role into gid,my_role from public.guild_members m where m.player_id=uid;
 select jsonb_build_object('guild',case when gid is null then null else
  (select to_jsonb(g)||jsonb_build_object('role',my_role,'level',public.guild_level(g.experience),'bonus_percent',public.guild_level(g.experience)*10,'next_xp',(array[0,10000,30000,65000,120000,200000,310000,455000,640000,870000]::bigint[])[public.guild_level(g.experience)+1],'level_start_xp',(array[0,10000,30000,65000,120000,200000,310000,455000,640000,870000]::bigint[])[public.guild_level(g.experience)]) from public.guilds g where g.id=gid) end,
  'members',coalesce((select jsonb_agg(jsonb_build_object('id',m.player_id,'name',coalesce(p.nickname,p.display_name,'Jogador'),'avatar',p.equipped_avatar,'role',m.role) order by m.joined_at)
   from public.guild_members m join public.profiles p on p.id=m.player_id where m.guild_id=gid),'[]'),
  'requests',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'kind',q.kind,'guild',g.name,'player',coalesce(p.nickname,p.display_name,'Jogador'),'created_at',q.created_at) order by q.created_at desc)
   from public.guild_requests q join public.guilds g on g.id=q.guild_id join public.profiles p on p.id=q.player_id
   where q.status='pending' and (q.player_id=uid or (q.guild_id=gid and my_role in ('leader','officer')))),'[]'),
  'directory',coalesce((select jsonb_agg(x.payload) from (
   select jsonb_build_object('id',g.id,'name',g.name,'description',g.description,'level',public.guild_level(g.experience),'members',(select count(*) from public.guild_members m where m.guild_id=g.id),
    'applied',exists(select 1 from public.guild_requests q where q.guild_id=g.id and q.player_id=uid and q.kind='application' and q.status='pending')) as payload
   from public.guilds g where g.discoverable and (p_search='' or g.name ilike '%'||left(p_search,80)||'%') order by g.created_at desc limit 40)x),'[]')) into result;
 return result;
end $$;


create or replace function public._gc_finish(run public.guardian_campaign_runs) returns public.guardian_campaign_runs language plpgsql volatile set search_path='' as $$
declare n jsonb:=public._gc_node(run.node_id);region text:=n->>'region';stage integer:=(n->>'stage')::integer;uid uuid:=run.player_id;
 old integer;total integer;milestone integer;first_clear boolean:=false;won boolean:=run.context#>>'{s,campaignWinner}'='player_one';xp_before integer;earned integer:=0;coins integer:=0;reward jsonb;pay jsonb;inserted integer;
begin
 perform 1 from public.guardian_campaign_runs saved where saved.id=run.id for update;
 if exists(select 1 from public.guardian_campaign_runs saved where saved.id=run.id and saved.status='completed') then
  select saved.* into run from public.guardian_campaign_runs saved where saved.id=run.id;return run;
 end if;
 if run.status='completed' or not coalesce((run.context#>>'{s,finished}')::boolean,false) then return run;end if;
 insert into public.guardian_campaign_progress(player_id,region_id) values(uid,region) on conflict do nothing;
 select cleared into old from public.guardian_campaign_progress where player_id=uid and region_id=region for update;
 if won and stage=old+1 then
  update public.guardian_campaign_progress set cleared=stage,updated_at=clock_timestamp() where player_id=uid and region_id=region;first_clear:=true;
  select sum(cleared)::integer into total from public.guardian_campaign_progress where player_id=uid;
  if total%5=0 then
   milestone:=total/5;
   insert into public.guardian_campaign_rewards(player_id,milestone) values(uid,milestone) on conflict do nothing;
   reward:=public._gc_grant_reward(uid,milestone);
  end if;
  if region='greece' and stage=1 then
   select xp into xp_before from public.profiles where id=uid and not coalesce(tutorial_completed,false) for update;
   if found then update public.profiles set tutorial_completed=true where id=uid;end if;
  end if;
 end if;
 pay:=public._match_reward('guardian',case when won then 'victory' else 'defeat' end);earned:=(pay->>'xp')::integer;coins:=(pay->>'coins')::integer;
 run.status:='completed';run.finished_at:=clock_timestamp();
 run.context:=jsonb_set(run.context,'{s,campaignResult}',jsonb_build_object('firstClear',first_clear,'reward',reward,'xp',earned,'coins',coins));
 update public.guardian_campaign_runs set status=run.status,finished_at=run.finished_at,context=run.context where id=run.id;
 insert into public.guardian_match_claims(match_id,player_id) values(run.id,uid) on conflict do nothing;
 insert into public.match_history(match_id,guardian_match_id,player_id,opponent_name,mode,outcome,player_points,opponent_points,xp_earned,coins_earned)
 values(null,run.id,uid,n->>'name','guardian',case when won then 'victory' else 'defeat' end,coalesce((run.context#>>'{s,roundWins,player_one}')::integer,0),coalesce((run.context#>>'{s,roundWins,player_two}')::integer,0),earned,coins)
 on conflict do nothing;
 get diagnostics inserted=row_count;
 if inserted=1 then update public.profiles set xp=xp+earned,mythic_coins=mythic_coins+coins where id=uid;end if;
 select h.xp_earned,h.coins_earned into earned,coins from public.match_history h where h.guardian_match_id=run.id and h.player_id=uid;
 run.context:=jsonb_set(run.context,'{s,campaignResult}',(run.context#>'{s,campaignResult}')||jsonb_build_object('xp',earned,'coins',coins));
 update public.guardian_campaign_runs set context=run.context where id=run.id;
 return run;
end $$;
revoke all on function public._gc_finish(public.guardian_campaign_runs) from public,anon,authenticated;


create or replace function public.record_guardian_match(p_match_id uuid,p_outcome text,p_player_points integer,p_opponent_points integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); earned_xp integer; earned_coins integer; inserted integer;

begin

  if uid is null then raise exception 'Entre na conta para registrar a partida.'; end if;

  if p_match_id is null or p_outcome is null or p_player_points is null or p_opponent_points is null or p_outcome not in ('victory','defeat','draw') or p_player_points not between 0 and 5000 or p_opponent_points not between 0 and 5000 then raise exception 'Resultado de partida inválido.'; end if;

  if (p_outcome='victory' and p_player_points<=p_opponent_points) or (p_outcome='defeat' and p_player_points>=p_opponent_points) or (p_outcome='draw' and p_player_points<>p_opponent_points) then raise exception 'O resultado não corresponde aos pontos.'; end if;

  perform 1 from public.profiles where id=uid for update;
  if exists(select 1 from public.guardian_match_claims where player_id=uid and match_id=p_match_id) then return jsonb_build_object('already_recorded',true);end if;
  if (select count(*) from public.guardian_match_claims where player_id=uid and claimed_at >= date_trunc('day',now()))>=5 then raise exception 'Limite diário de partidas recompensadas contra o Guardião atingido.'; end if;

  insert into public.guardian_match_claims(match_id,player_id) values(p_match_id,uid) on conflict do nothing;

  get diagnostics inserted = row_count;

  if inserted=0 then return jsonb_build_object('already_recorded',true); end if;

  if p_outcome='victory' then earned_xp:=20;earned_coins:=50; update public.profiles set wins=wins+1,xp=xp+earned_xp,mythic_coins=mythic_coins+earned_coins where id=uid;

  elsif p_outcome='defeat' then earned_xp:=10;earned_coins:=25; update public.profiles set losses=losses+1,xp=xp+earned_xp,mythic_coins=mythic_coins+earned_coins where id=uid;

  else earned_xp:=10;earned_coins:=25; update public.profiles set xp=xp+earned_xp,mythic_coins=mythic_coins+earned_coins where id=uid; end if;

  insert into public.match_history(match_id,guardian_match_id,player_id,opponent_name,mode,outcome,player_points,opponent_points,xp_earned,coins_earned)

  values(null,p_match_id,uid,'Guardião da Arena','guardian',p_outcome,p_player_points,p_opponent_points,earned_xp,earned_coins);

  select h.xp_earned,h.coins_earned into earned_xp,earned_coins from public.match_history h where h.guardian_match_id=p_match_id and h.player_id=uid;
  return jsonb_build_object('xp_earned',earned_xp,'coins_earned',earned_coins);

end;
$$;


create or replace function public._tb_award(mid uuid,winner_team text) returns void
language plpgsql security definer set search_path='' as $$
declare g public.game_matches%rowtype;r record;won boolean;target_xp integer;target_coins integer;
begin
 if winner_team is null or winner_team not in ('player_one','player_two') then
  raise exception 'Equipe vencedora do desempate inválida.';
 end if;
 select * into g from public.game_matches where id=mid for update;
 if not found or g.status<>'completed' then raise exception 'Partida de desempate indisponível.';end if;
 -- Only unresolved draw rows are converted. A retry cannot award them twice.
 for r in select h.* from public.match_history h
  where h.match_id=mid and h.outcome='draw' order by h.player_id for update loop
  won:=case when g.team_size=2 then exists(
   select 1 from public.duo_match_players d where d.match_id=mid and d.player_id=r.player_id
   and d.team=case when winner_team='player_one' then 1 else 2 end)
   else r.player_id=case when winner_team='player_one' then g.player_one else g.player_two end end;
  target_xp:=(public._match_reward(g.mode,case when won then 'victory' else 'defeat' end)->>'xp')::integer;
  target_coins:=(public._match_reward(g.mode,case when won then 'victory' else 'defeat' end)->>'coins')::integer;
  target_xp:=floor(target_xp::numeric*(100+r.guild_bonus_percent)/100)::integer;
  target_coins:=floor(target_coins::numeric*(100+r.guild_bonus_percent)/100)::integer;
  update public.profiles set
   xp=xp+target_xp-r.xp_earned,mythic_coins=mythic_coins+target_coins-r.coins_earned,
   wins=wins+case when won then 1 else 0 end,
   losses=losses+case when won then 0 else 1 end,
   rating_points=greatest(0,rating_points+case when g.mode='ranked' then case when won then 25 else -25 end else 0 end)
  where id=r.player_id;
  update public.match_history set outcome=case when won then 'victory' else 'defeat' end,
   xp_earned=target_xp,coins_earned=target_coins where match_id=mid and player_id=r.player_id;
  -- track_player_deck_result runs on INSERT only: move the original draw into
  -- the final outcome without incrementing games_played a second time.
  update public.player_deck_usage u set
   victories=u.victories+case when won then 1 else 0 end,
   defeats=u.defeats+case when won then 0 else 1 end,
   draws=greatest(0,u.draws-1)
  where u.player_id=r.player_id and u.deck_key=(
   select d.deck_key from public.player_match_decks d where d.match_id=mid and d.player_id=r.player_id);
 end loop;
end $$;
revoke all on function public._tb_award(uuid,text) from public,anon,authenticated;

-- Independent online Desempate uses the same base as custom games: 50/20,
-- half on defeat. A single server-created result awards each participant once.
create or replace function public._reward_online_tiebreak() returns trigger
language plpgsql security definer set search_path='' as $$
declare uid uuid;side text;other_name text;result text;pay jsonb;inserted integer;
begin
 for uid,side in select new.player_one,'player_one'::text union all select new.player_two,'player_two'::text loop
  select p.nickname into other_name from public.profiles p where p.id=case when uid=new.player_one then new.player_two else new.player_one end;
  result:=case when new.payload->>'winner_side'=side then 'victory' else 'defeat' end;pay:=public._match_reward('friend',result);
  insert into public.match_history(tiebreak_match_id,player_id,opponent_name,mode,outcome,xp_earned,coins_earned)
  values(new.id,uid,coalesce(other_name,'Adversário'),'tiebreak',result,(pay->>'xp')::integer,(pay->>'coins')::integer) on conflict do nothing;
  get diagnostics inserted=row_count;
  if inserted=1 then update public.profiles set xp=xp+(pay->>'xp')::integer,mythic_coins=mythic_coins+(pay->>'coins')::integer,wins=wins+case when result='victory' then 1 else 0 end,losses=losses+case when result='defeat' then 1 else 0 end where id=uid;end if;
 end loop;
 return new;
end $$;
revoke all on function public._reward_online_tiebreak() from public,anon,authenticated;
drop trigger if exists reward_online_tiebreak on public.tiebreak_pvp_matches;
create trigger reward_online_tiebreak after insert on public.tiebreak_pvp_matches for each row execute function public._reward_online_tiebreak();
notify pgrst,'reload schema';
commit;
