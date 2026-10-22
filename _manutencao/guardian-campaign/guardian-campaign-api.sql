create or replace function public.get_guardian_campaign() returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare uid uuid:=auth.uid();progress jsonb;rewards jsonb;active_run jsonb;
begin
 perform public._security_rpc_gate('guardian_campaign',40);
 select coalesce(jsonb_object_agg(region_id,cleared),'{}') into progress from public.guardian_campaign_progress where player_id=uid;
 select coalesce(jsonb_agg(jsonb_build_object('milestone',r.milestone,'itemId',r.item_id,'pending',r.granted_at is null,'name',s.title,'kind',s.kind,'asset',s.asset_path,'at',r.granted_at) order by r.milestone),'[]') into rewards from public.guardian_campaign_rewards r left join public.shop_catalog s on s.item_id=r.item_id where r.player_id=uid;
 select jsonb_build_object('id',id,'nodeId',node_id,'version',version) into active_run from public.guardian_campaign_runs where player_id=uid and status='active';
 return jsonb_build_object('progress',progress,'rewards',rewards,'active',active_run,'totalCleared',(select coalesce(sum(cleared),0) from public.guardian_campaign_progress where player_id=uid),'version',1);
end $$;

create or replace function public.get_guardian_campaign_run(p_run_id uuid) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare run public.guardian_campaign_runs%rowtype;
begin
 perform public._security_rpc_gate('guardian_campaign_read',90);
 select * into run from public.guardian_campaign_runs where id=p_run_id and player_id=auth.uid();
 if not found then raise exception 'Batalha indisponível.';end if;
 return public._gc_snapshot(run);
end $$;

create or replace function public.start_guardian_campaign(p_node_id text,p_cards jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare uid uuid:=auth.uid();n jsonb:=public._gc_node(p_node_id);region jsonb;previous_region jsonb;cleared integer;previous_cleared integer;stage integer;
 run public.guardian_campaign_runs%rowtype;player_deck jsonb;bot_deck jsonb;x jsonb;s jsonb;resources jsonb;side jsonb;
begin
 perform public._security_rpc_gate('guardian_campaign_start',12);
 perform pg_advisory_xact_lock(hashtextextended('guardian:'||uid::text,0));
 if n is null then raise exception 'Desafio indisponível.';end if;
 select * into run from public.guardian_campaign_runs where player_id=uid and status='active' for update;
 if found then
  if run.node_id=p_node_id then return public._gc_snapshot(run);end if;
  raise exception 'Você tem uma batalha para retomar. Termine ou encerre essa batalha primeiro.';
 end if;
 if exists(select 1 from public.game_matches where status='active' and uid in(player_one,player_two,player_three,player_four)) then raise exception 'Termine sua partida atual antes de iniciar a campanha.';end if;
 region:=public._gc_region(n->>'region');stage:=(n->>'stage')::integer;
 select coalesce(max(p.cleared),0) into cleared from public.guardian_campaign_progress p where p.player_id=uid and p.region_id=region->>'id';
 if stage>cleared+1 then raise exception 'Vença o desafio anterior para avançar.';end if;
 if (region->>'order')::integer>1 then
  select value into previous_region from jsonb_array_elements(public._gc_data()->'regions') where (value->>'order')::integer=(region->>'order')::integer-1;
  select coalesce(max(p.cleared),0) into previous_cleared from public.guardian_campaign_progress p where p.player_id=uid and p.region_id=previous_region->>'id';
  if previous_cleared<20 then raise exception 'Conclua a trilha anterior para desbloquear esta mitologia.';end if;
 end if;
 perform public._assert_owned_deck(uid,p_cards);
 if (select coalesce(sum((value::text)::integer),0) from jsonb_each(p_cards)) not between 14 and 35 then raise exception 'Selecione um baralho de 14 a 35 cartas.';end if;
 if exists(select 1 from jsonb_each(p_cards) where (value::text)::integer>0 and not public._card_enabled(key)) then raise exception 'Seu baralho contém uma carta temporariamente pausada.';end if;
 select coalesce(jsonb_agg(e.key),'[]') into player_deck from jsonb_each_text(p_cards) e cross join lateral generate_series(1,e.value::integer);
 if not exists(select 1 from jsonb_array_elements_text(player_deck) where public._r_card(value)->>'kind'='unit') then raise exception 'Seu baralho precisa ter uma unidade.';end if;
 bot_deck:=public._gc_deck(p_node_id);
 side:=jsonb_build_object('field','[]'::jsonb,'grave','[]'::jsonb,'underworld','[]'::jsonb,'roundScoreBonus',0,'trixx',2);
 s:=jsonb_build_object('round',1,'sharedZones',jsonb_build_object('local',null,'terrain',null,'climate',null),'zoneOwners','{}'::jsonb,'effectQueue','[]'::jsonb,'log','[]'::jsonb,'visualEvents','[]'::jsonb,'roundScores','[]'::jsonb,'roundWins',jsonb_build_object('player_one',0,'player_two',0),'totalPoints',jsonb_build_object('player_one',0,'player_two',0),'player_one',side,'player_two',side,'campaignRegion',n->>'region','campaignStage',stage,'campaignActor',uid::text,'campaignPhase','start','campaignPlayer',uid::text,'campaignDecks',jsonb_build_object('player_one',player_deck,'player_two',bot_deck),'campaignStats',jsonb_build_object('plays','[]'::jsonb,'actions',0,'passes',0),'finished',false);
 resources:=jsonb_build_object(uid::text,jsonb_build_object('team','player_one','hand','[]'::jsonb,'deck',public._gc_shuffle(player_deck),'passed',false,'playedThisTurn',false,'skipNextTurn',false,'turnsTaken',0),'guardian-bot',jsonb_build_object('team','player_two','hand','[]'::jsonb,'deck',public._gc_shuffle(bot_deck),'passed',false,'playedThisTurn',false,'skipNextTurn',false,'turnsTaken',0));
 x:=public._r_init(s,resources);x:=public._x_draw(x,jsonb_build_object('owner',uid::text),4);x:=public._x_draw(x,jsonb_build_object('owner','guardian-bot'),4);
 x:=public._gc_note(x,'Desafio '||stage::text||' · '||(n->>'name')||'. Cada Round tem sua própria pontuação.');
 x:=public._gc_drive(x,uid::text,(n->>'difficulty')::integer);
 insert into public.guardian_campaign_runs(player_id,node_id,context) values(uid,p_node_id,x) returning * into run;
 return public._gc_snapshot(run);
end $$;

create or replace function public.guardian_campaign_action(p_run_id uuid,p_action jsonb,p_version integer,p_request_id uuid) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare uid uuid:=auth.uid();run public.guardian_campaign_runs%rowtype;pending jsonb;kind text:=p_action->>'type';x jsonb;a jsonb:=p_action;receipt text;fingerprint text:=md5(p_action::text||':'||coalesce(p_version::text,''));n jsonb;
begin
 perform public._security_rpc_gate('guardian_campaign_action',90);
 perform pg_advisory_xact_lock(hashtextextended('guardian:'||uid::text,0));
 if p_request_id is null or p_version is null or jsonb_typeof(p_action) is distinct from 'object'
  or kind is null or kind not in('play','pass','resolve_effect','expire','surrender','bot_tick')
  or exists(select 1 from jsonb_object_keys(p_action) k where k not in('type','card_id','lane','choice_id','choice_value'))
  or length(coalesce(p_action->>'card_id',''))>100 or length(coalesce(p_action->>'choice_id',''))>120 or length(coalesce(p_action->>'choice_value',''))>512
 then raise exception 'Ação inválida.';end if;
 if p_action ? 'lane' and (jsonb_typeof(p_action->'lane')<>'number' or p_action->>'lane' not in('0','1','2')) then raise exception 'Fileira inválida.';end if;
 select * into run from public.guardian_campaign_runs where id=p_run_id and player_id=uid for update;
 if not found then raise exception 'Batalha indisponível.';end if;
 select payload_hash into receipt from public.guardian_campaign_requests where run_id=run.id and request_id=p_request_id;
 if receipt is not null then
  if receipt<>fingerprint then raise exception 'Identificador de ação já utilizado.';end if;
  return public._gc_snapshot(run);
 end if;
 if run.status<>'active' then return public._gc_snapshot(run);end if;
 if run.version<>p_version then raise exception 'A batalha foi atualizada em outra aba. Aguarde a sincronização.';end if;
 x:=run.context;pending:=x#>'{s,pendingEffect}';n:=public._gc_node(run.node_id);
 if kind not in('expire','surrender','bot_tick') and clock_timestamp()>=run.deadline then kind:='expire';end if;
 if kind='bot_tick' then
  if (pending is not null and pending->>'actor' is distinct from 'guardian-bot') or (pending is null and x#>>'{s,campaignActor}' is distinct from 'guardian-bot') then raise exception 'Aguarde a vez do adversário.';end if;
  if x#>>'{s,campaignBotDueAt}' is not null and clock_timestamp()<(x#>>'{s,campaignBotDueAt}')::timestamptz then return public._gc_snapshot(run);end if;
 elsif kind='surrender' then
  x:=jsonb_set(x,'{s,finished}','true');x:=jsonb_set(x,'{s,campaignWinner}','"player_two"');x:=public._gc_note(x,'Você encerrou este desafio. Seu avanço anterior foi preservado.');
 elsif kind='expire' then
  if clock_timestamp()<run.deadline then raise exception 'O tempo desta jogada ainda não acabou.';end if;
  if pending is not null then
   if pending->>'actor'<>uid::text then raise exception 'Aguarde o adversário.';end if;
   a:=jsonb_build_object('type','resolve_effect','choice_id',pending->>'id','choice_value',pending#>>'{options,0,value}');
   x:=public._r_action(x->'s',x->'r',uid::text,a);x:=public._gc_stats(x,uid::text,a);
  else
   if x#>>'{s,campaignActor}'<>uid::text or x#>>'{s,campaignPhase}'<>'action' then raise exception 'Aguarde sua jogada.';end if;
   a:=jsonb_build_object('type','pass');x:=jsonb_set(x,array['r',uid::text,'passed'],'true');x:=public._gc_stats(x,uid::text,a);x:=jsonb_set(x,'{s,campaignPhase}','"end"');
  end if;
 elsif pending is not null then
  if kind<>'resolve_effect' or pending->>'actor'<>uid::text then raise exception 'Resolva a habilidade pendente.';end if;
  x:=public._r_action(x->'s',x->'r',uid::text,a);x:=public._gc_stats(x,uid::text,a);
 else
  if x#>>'{s,campaignActor}'<>uid::text or x#>>'{s,campaignPhase}'<>'action' or kind not in('play','pass') then raise exception 'Aguarde sua jogada.';end if;
  if kind='pass' then x:=jsonb_set(x,array['r',uid::text,'passed'],'true');else x:=public._r_action(x->'s',x->'r',uid::text,a);end if;x:=public._gc_stats(x,uid::text,a);
  if kind='play' then x:=public._gc_note(x,(public._r_card(a->>'card_id')->>'name')||' entrou pelo seu lado.');else x:=public._gc_note(x,'Você passou neste Round.');end if;
  x:=jsonb_set(x,'{s,campaignPhase}','"end"');
 end if;
 x:=public._gc_drive(x,uid::text,(n->>'difficulty')::integer);
 update public.guardian_campaign_runs set context=x,version=version+1,deadline=clock_timestamp()+interval '30 seconds' where id=run.id returning * into run;
 if coalesce((x#>>'{s,finished}')::boolean,false) then run:=public._gc_finish(run);end if;
 insert into public.guardian_campaign_requests(run_id,request_id,payload_hash) values(run.id,p_request_id,fingerprint);
 return public._gc_snapshot(run);
end $$;

create or replace function public.claim_guardian_campaign_reward(p_milestone integer) returns jsonb language plpgsql volatile security definer set search_path='' as $$
begin
 perform public._security_rpc_gate('guardian_campaign_reward',20);
 perform pg_advisory_xact_lock(hashtextextended('guardian:'||auth.uid()::text,0));
 if not exists(select 1 from public.guardian_campaign_rewards where player_id=auth.uid() and milestone=p_milestone) then raise exception 'Esta recompensa ainda não foi conquistada.';end if;
 return public._gc_grant_reward(auth.uid(),p_milestone);
end $$;

create or replace function public.get_guardian_campaign_report(p_run_id uuid) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare uid uuid:=auth.uid();run public.guardian_campaign_runs%rowtype;n jsonb;s jsonb;plays jsonb;actions jsonb;opponent text;icon text;
begin
 perform public._security_rpc_gate('guardian_campaign_report',40);
 select * into run from public.guardian_campaign_runs where id=p_run_id and player_id=uid;
 if not found or run.status<>'completed' then raise exception 'Relatório indisponível.';end if;
 n:=public._gc_node(run.node_id);s:=run.context->'s';opponent:=n->>'name';icon:=n->>'icon';
 select coalesce(jsonb_agg(jsonb_build_object('actor_id',actor_id,'card_id',card_id,'count',amount)),'[]') into plays from
  (select value->>'actor_id' actor_id,value->>'card_id' card_id,count(*) amount from jsonb_array_elements(s#>'{campaignStats,plays}') group by value->>'actor_id',value->>'card_id') entries;
 actions:=jsonb_build_array(jsonb_build_object('actor_id',uid::text,'actions',s#>'{campaignStats,actions}','passes',s#>'{campaignStats,passes}'));
 return jsonb_build_object('id',run.id,'mode','guardian','team_size',1,'my_team','player_one','outcome',case when s->>'campaignWinner'='player_one' then 'victory' else 'defeat' end,
  'participants',jsonb_build_array(jsonb_build_object('id',uid::text,'name',(select coalesce(nickname,'Você') from public.profiles where id=uid),'team','player_one','icon',(select equipped_avatar from public.profiles where id=uid)),jsonb_build_object('id','guardian-bot','name',opponent,'team','player_two','icon',icon)),
  'started_at',run.created_at,'finished_at',run.finished_at,'duration_seconds',extract(epoch from(run.finished_at-run.created_at)),
  'round_wins',s->'roundWins','rounds',s->'roundScores','cards',plays,'actions',actions,'complete_tracking',true,'tiebreak',s->'campaignTieBreak',
  'rewards',jsonb_build_object('xp',coalesce((s#>>'{campaignResult,xp}')::integer,0),'coins',coalesce((s#>>'{campaignResult,coins}')::integer,0)),'campaign',jsonb_build_object('nodeId',run.node_id,'region',n->>'region','stage',n->'stage','result',s->'campaignResult'));
end $$;

-- Only the public RPCs can access private decks and mutate campaign state/rewards.
do $acl$
declare f record;
begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and left(p.proname,4)='_gc_' loop
  execute 'revoke all on function '||f.signature||' from public,anon,authenticated';
 end loop;
end $acl$;
revoke all on function public.get_guardian_campaign(),public.get_guardian_campaign_run(uuid),public.start_guardian_campaign(text,jsonb),public.guardian_campaign_action(uuid,jsonb,integer,uuid),public.claim_guardian_campaign_reward(integer),public.get_guardian_campaign_report(uuid) from public,anon;
grant execute on function public.get_guardian_campaign(),public.get_guardian_campaign_run(uuid),public.start_guardian_campaign(text,jsonb),public.guardian_campaign_action(uuid,jsonb,integer,uuid),public.claim_guardian_campaign_reward(integer),public.get_guardian_campaign_report(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
