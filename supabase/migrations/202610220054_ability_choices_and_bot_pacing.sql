-- 054: ability choices, public option metadata and paced authoritative Atlas bot.
-- Apply after 053. No inventories, progression, printed powers or rewards are reset.
begin;
do $prerequisites$
begin
 if to_regprocedure('public._gc_finish(public.guardian_campaign_runs)') is null
  or to_regprocedure('public._match_reward(text,text)') is null then
  raise exception 'Aplique as migrações anteriores, incluindo 052 e 053, antes da 054.';
 end if;
end $prerequisites$;
do $choice_aliases$
declare routine record;definition text;updated text;
begin
 for routine in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' and p.proname in ('_x_options','_x_resolve') loop
  definition:=pg_get_functiondef(routine.oid);updated:=definition;
  updated:=replace(updated,$old$exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) v where v->>'uid'<>e->>'uid' and v->>'lane'=e->>'lane')$old$,$new$exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) as candidate54(unit) where candidate54.unit->>'uid'<>e->>'uid' and candidate54.unit->>'lane'=e->>'lane')$new$);
  updated:=replace(updated,$old$exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) v where v->>'uid'<>e->>'uid' and not public._r_active(x->'s',t,v))$old$,$new$exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) as candidate54(unit) where candidate54.unit->>'uid'<>e->>'uid' and not public._r_active(x->'s',t,candidate54.unit))$new$);
  updated:=replace(updated,$old$exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) v where v->>'uid'<>e->>'uid' and v->>'lane'=e->>'lane' and public._r_card(public._r_identity(v))->>'faction'=r->>'faction')$old$,$new$exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) as candidate54(unit) where candidate54.unit->>'uid'<>e->>'uid' and candidate54.unit->>'lane'=e->>'lane' and public._r_card(public._r_identity(candidate54.unit))->>'faction'=r->>'faction')$new$);
  updated:=replace(updated,$old$select sum(public._r_power(x->'s',t,v)) from jsonb_array_elements(x#>array['s',t,'field']) v where v->>'lane'=e->>'lane'$old$,$new$select sum(public._r_power(x->'s',t,candidate54.unit)) from jsonb_array_elements(x#>array['s',t,'field']) as candidate54(unit) where candidate54.unit->>'lane'=e->>'lane'$new$);
  updated:=replace(updated,$old$select sum(public._r_power(x->'s',enemy,v)) from jsonb_array_elements(x#>array['s',enemy,'field']) v where v->>'lane'=e->>'lane'$old$,$new$select sum(public._r_power(x->'s',enemy,candidate54.unit)) from jsonb_array_elements(x#>array['s',enemy,'field']) as candidate54(unit) where candidate54.unit->>'lane'=e->>'lane'$new$);
  updated:=replace(updated,$old$select count(*) from jsonb_array_elements(x#>array['s',enemy,'grave']) g where g->>'owner'=public._r_unit(x->'s',enemy,sel)->>'playedBy' and public._r_card(g->>'cardId')->>'kind'='unit'$old$,$new$select count(*) from jsonb_array_elements(x#>array['s',enemy,'grave']) as grave54(entry) where grave54.entry->>'owner'=public._r_unit(x->'s',enemy,sel)->>'playedBy' and public._r_card(grave54.entry->>'cardId')->>'kind'='unit'$new$);
  updated:=replace(updated,$old$select count(*) into i from jsonb_array_elements(x#>array['s',t,'grave']) g where g->>'owner'=owner_id and public._r_card(g->>'cardId')->>'kind'='unit'$old$,$new$select count(*) into i from jsonb_array_elements(x#>array['s',t,'grave']) as grave54(entry) where grave54.entry->>'owner'=owner_id and public._r_card(grave54.entry->>'cardId')->>'kind'='unit'$new$);
  updated:=replace(updated,$old$x:=public._r_visual(x,'hearts',t,jsonb_build_array(sel))$old$,$new$x:=public._r_visual(x,'hearts',enemy,jsonb_build_array(sel))$new$);
  if updated<>definition then execute updated;end if;
 end loop;
end $choice_aliases$;

create or replace function public._gc_drive(x jsonb,uid text,level integer) returns jsonb language plpgsql volatile set search_path='' as $$
declare actor text;t text;enemy_actor text;phase text;r jsonb;p jsonb;a jsonb;one numeric;two numeric;round_no integer;wins jsonb;rows jsonb;summary jsonb;result jsonb;winner text;steps integer:=0;key text;
begin
 loop
  steps:=steps+1;if steps>500 then raise exception 'A sequência da batalha excedeu o limite. A ação não foi confirmada.';end if;
  if coalesce((x#>>'{s,finished}')::boolean,false) then return x;end if;
  p:=x#>'{s,pendingEffect}';
  if p is not null then
   if p->>'actor'<>'guardian-bot' then return x;end if;
   if x#>>'{s,campaignBotStep}' is distinct from ('choice:'||(p->>'id')) then
    return jsonb_set(jsonb_set(x,'{s,campaignBotStep}',to_jsonb('choice:'||(p->>'id')),true),'{s,campaignBotDueAt}',to_jsonb(clock_timestamp()+interval '1 second'),true);
   end if;
   if clock_timestamp()<(x#>>'{s,campaignBotDueAt}')::timestamptz then return x;end if;
   x:=x#-'{s,campaignBotDueAt}'#-'{s,campaignBotStep}';
   a:=jsonb_build_object('type','resolve_effect','choice_id',p->>'id','choice_value',public._gc_pick_choice(x,p,level));
   x:=public._r_action(x->'s',x->'r','guardian-bot',a);x:=public._gc_stats(x,'guardian-bot',a);continue;
  end if;
  actor:=x#>>'{s,campaignActor}';t:=x#>>array['r',actor,'team'];enemy_actor:=case when actor=uid then 'guardian-bot' else uid end;
  r:=x#>array['r',actor];phase:=coalesce(x#>>'{s,campaignPhase}','start');
  if phase='start' then
   if coalesce((r->>'passed')::boolean,false) then x:=jsonb_set(x,'{s,campaignPhase}','"advance"');continue;end if;
   r:=r||jsonb_build_object('playedThisTurn',false,'turnsTaken',coalesce((r->>'turnsTaken')::integer,0)+1);
   x:=jsonb_set(x,array['r',actor],r);x:=jsonb_set(x,'{s,campaignPhase}','"draw"');
   x:=public._r_turn_start(x->'s',x->'r',actor);
   if coalesce((r->>'skipNextTurn')::boolean,false) then
    x:=jsonb_set(x,array['r',actor,'skipNextTurn'],'false');x:=jsonb_set(x,'{s,campaignPhase}','"end"');
    x:=public._gc_note(x,case when actor=uid then 'Você perdeu este turno por petrificação.' else 'O adversário perdeu este turno por petrificação.' end);
   end if;continue;
  elsif phase='draw' then
   x:=public._r_finish_start(x,actor);r:=x#>array['r',actor];
   if jsonb_array_length(r->'hand')=0 and jsonb_array_length(r->'deck')=0 then x:=jsonb_set(x,array['r',actor,'passed'],'true');end if;
   x:=jsonb_set(x,'{s,campaignPhase}','"action"');continue;
  elsif phase='action' then
   if coalesce((r->>'passed')::boolean,false) then x:=jsonb_set(x,'{s,campaignPhase}','"end"');continue;end if;
   if actor=uid then return x;end if;
   if x#>>'{s,campaignBotStep}' is distinct from 'play' then
    return jsonb_set(jsonb_set(x,'{s,campaignBotStep}','"play"',true),'{s,campaignBotDueAt}',to_jsonb(clock_timestamp()+interval '2 seconds'),true);
   end if;
   if clock_timestamp()<(x#>>'{s,campaignBotDueAt}')::timestamptz then return x;end if;
   x:=x#-'{s,campaignBotDueAt}'#-'{s,campaignBotStep}';
   a:=public._gc_pick_play(x,actor,level);if a->>'type'='pass' then x:=jsonb_set(x,array['r',actor,'passed'],'true');else x:=public._r_action(x->'s',x->'r',actor,a);end if;x:=public._gc_stats(x,actor,a);
   if a->>'type'='play' then x:=public._gc_note(x,(public._r_card(a->>'card_id')->>'name')||' entrou pelo adversário.');else x:=public._gc_note(x,'O adversário passou neste Round.');end if;
   x:=jsonb_set(x,'{s,campaignPhase}','"end"');continue;
  elsif phase='end' then
   r:=x#>array['r',actor];
   x:=jsonb_set(x,'{s}',public._r_turn_end(x->'s',actor,t,coalesce((r->>'turnsTaken')::integer,0)));
   if jsonb_array_length(r->'hand')=0 and jsonb_array_length(r->'deck')=0 then x:=jsonb_set(x,array['r',actor,'passed'],'true');end if;
   x:=jsonb_set(x,'{s,campaignPhase}','"advance"');continue;
  elsif phase='advance' then
   if coalesce((x#>>array['r',uid,'passed'])::boolean,false) and coalesce((x#>>'{r,guardian-bot,passed}')::boolean,false) then
    x:=jsonb_set(x,'{s}',public._r_round_end(x->'s'));
    one:=public._r_score(x->'s','player_one');two:=public._r_score(x->'s','player_two');round_no:=(x#>>'{s,round}')::integer;
    wins:=coalesce(x#>'{s,roundWins}','{"player_one":0,"player_two":0}');winner:=case when one>two then 'player_one' when two>one then 'player_two' end;
    if winner is not null then wins:=jsonb_set(wins,array[winner],to_jsonb((wins->>winner)::integer+1));end if;
    summary:=jsonb_build_object('round',round_no,'winner',winner,'player_one',one,'player_two',two);
    x:=jsonb_set(x,'{s,roundSummary}',summary);x:=jsonb_set(x,'{s,roundWins}',wins);
    x:=jsonb_set(x,'{s,roundScores}',coalesce(x#>'{s,roundScores}','[]')||jsonb_build_array(jsonb_build_object('round',round_no,'player_one',one,'player_two',two)));
    x:=jsonb_set(x,'{s,totalPoints}',jsonb_build_object('player_one',one,'player_two',two));x:=jsonb_set(x,'{s,lastRoundPoints}',jsonb_build_object('player_one',one,'player_two',two));
    x:=jsonb_set(x,'{s,player_one,trixx}',to_jsonb(greatest(0,2-(wins->>'player_two')::integer)));
    x:=jsonb_set(x,'{s,player_two,trixx}',to_jsonb(greatest(0,2-(wins->>'player_one')::integer)));
    x:=public._gc_note(x,'Round '||round_no::text||': '||one::text||' × '||two::text||'.');
    if greatest((wins->>'player_one')::integer,(wins->>'player_two')::integer)>=2 or round_no>=3 then
     winner:=case when (wins->>'player_one')::integer>(wins->>'player_two')::integer then 'player_one' when (wins->>'player_two')::integer>(wins->>'player_one')::integer then 'player_two' end;
     if winner is null then
      result:=public._tb_random_result(x#>'{s,campaignDecks,player_one}',x#>'{s,campaignDecks,player_two}');winner:=result->>'winner_side';
      x:=jsonb_set(x,'{s,campaignTieBreak}',result||jsonb_build_object('my_side','player_one'));
     end if;
     x:=jsonb_set(x,'{s,finished}','true');x:=jsonb_set(x,'{s,campaignWinner}',to_jsonb(winner));return x;
    end if;
    x:=jsonb_set(x,'{s}',public._r_clear_round(x->'s'));x:=jsonb_set(x,'{s,sharedZones}','{"local":null,"terrain":null,"climate":null}');
    x:=jsonb_set(x,'{s,round}',to_jsonb(round_no+1));
    foreach key in array array[uid,'guardian-bot'] loop
     r:=x#>array['r',key];r:=r||jsonb_build_object('passed',false,'playedThisTurn',false,'skipNextTurn',false,'turnsTaken',0);r:=r-'privateEffects';
     x:=jsonb_set(x,array['r',key],r);x:=public._x_draw(x,jsonb_build_object('owner',key),2);
    end loop;
    x:=jsonb_set(x,'{s,campaignActor}',to_jsonb(uid));x:=jsonb_set(x,'{s,campaignPhase}','"start"');continue;
   end if;
   if coalesce((x#>>array['r',enemy_actor,'passed'])::boolean,false) then enemy_actor:=actor;end if;
   x:=jsonb_set(x,'{s,campaignActor}',to_jsonb(enemy_actor));x:=jsonb_set(x,'{s,campaignPhase}','"start"');continue;
  else raise exception 'Fase de campanha inválida.';
  end if;
 end loop;
end $$;

create or replace function public._gc_snapshot(run public.guardian_campaign_runs) returns jsonb language plpgsql stable set search_path='' as $$
declare s jsonb:=run.context->'s';r jsonb:=run.context->'r';uid text:=run.player_id::text;n jsonb:=public._gc_node(run.node_id);one jsonb;two jsonb;winner text;
begin
 one:=(s->'player_one')||(r->uid);two:=(s->'player_two')||(r->'guardian-bot');s:=jsonb_set(jsonb_set(s,'{player_one}',one),'{player_two}',two);
 s:=s-'campaignBotDueAt'-'campaignBotStep'-'campaignRegion'-'campaignStage'-'campaignDecks'-'campaignStats'-'campaignActor'-'campaignPhase'-'campaignPlayer';
 s:=public._audit_public_state(s,'player_one',run.player_id);
 s:=s||jsonb_build_object('guardianCampaign',jsonb_build_object('runId',run.id,'nodeId',run.node_id,'region',n->>'region','stage',n->'stage','version',run.version,'opponent',n->>'opponent','result',run.context#>'{s,campaignResult}','botThinking',run.context#>>'{s,campaignBotDueAt}' is not null,'botWaitMs',case when run.context#>>'{s,campaignBotDueAt}' is null then 0 else greatest(0,ceil(extract(epoch from((run.context#>>'{s,campaignBotDueAt}')::timestamptz-clock_timestamp()))*1000))::integer end,'botStep',case when run.context#>>'{s,campaignBotStep}' like 'choice:%' then 'choice' else 'play' end));
 winner:=case when run.status='completed' then case when run.context#>>'{s,campaignWinner}'='player_one' then uid else 'guardian-bot' end end;
 return jsonb_build_object('version',run.version,'node',n-'deck','match',jsonb_build_object('id',run.id,'mode','guardian','status',run.status,'player_one',uid,'player_two','guardian-bot','created_at',run.created_at,'finished_at',run.finished_at,'turn_user',case when run.context#>'{s,pendingEffect}' is not null then run.context#>>'{s,pendingEffect,actor}' else run.context#>>'{s,campaignActor}' end,'turn_deadline',run.deadline,'winner_id',winner,'state',s));
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

-- An owner sees the real cards in their own ability choices; spectators/opponents do not.
-- This enriches only existing legal options and never exposes either player's deck.
do $public_choices$
declare definition text;updated text;
begin
 definition:=pg_get_functiondef('public._audit_public_state(jsonb,text,uuid)'::regprocedure);
 if position('choice_metadata_v54' in definition)=0 then
  updated:=replace(definition,'return s;', $enrich$
   /* choice_metadata_v54 */
   if viewer_id is not null and pending->>'actor'=viewer_id::text and jsonb_typeof(pending->'options')='array' then
    s:=jsonb_set(s,'{pendingEffect,options}',coalesce((select jsonb_agg(opt.value||case when opt.value->>'cardId' is not null then jsonb_build_object('cardName',public._r_card(opt.value->>'cardId')->>'name','cardArt',public._r_card(opt.value->>'cardId')->>'art') else '{}'::jsonb end order by opt.ordinality) from jsonb_array_elements(pending->'options') with ordinality as opt(value,ordinality)),'[]'::jsonb),true);
   end if;
   return s;
  $enrich$);
  if updated<>definition then execute updated;end if;
 end if;
end $public_choices$;
revoke all on function public._gc_drive(jsonb,text,integer),public._gc_snapshot(public.guardian_campaign_runs) from public,anon,authenticated;
revoke all on function public.guardian_campaign_action(uuid,jsonb,integer,uuid) from public,anon;
grant execute on function public.guardian_campaign_action(uuid,jsonb,integer,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
