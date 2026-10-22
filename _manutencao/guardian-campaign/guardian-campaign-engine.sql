-- State machine shared with the existing card engine. Bot actions never come from the browser.
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

create or replace function public._gc_grant_reward(uid uuid,m integer) returns jsonb language plpgsql volatile set search_path='' as $$
declare reward public.guardian_campaign_rewards%rowtype;item public.shop_catalog%rowtype;want_icon boolean:=random()<.5;
begin
 select * into reward from public.guardian_campaign_rewards where player_id=uid and milestone=m for update;
 if not found then return null;end if;
 if reward.granted_at is not null then
  select * into item from public.shop_catalog where item_id=reward.item_id;
 else
  if want_icon then
   select * into item from public.shop_catalog s where s.active and s.kind='avatar' and (public._gc_data()->'rewardIcons') ? s.item_id
    and not exists(select 1 from public.player_inventory i where i.player_id=uid and i.item_id=s.item_id) order by random() limit 1;
  end if;
  if item.item_id is null then
   select * into item from public.shop_catalog s where s.active and s.kind='card' and public._card_enabled(s.card_id)
    and public._r_card(s.card_id)->>'faction' not in('Alyn','Alyns','Alyans') and not coalesce((public._r_card(s.card_id)->>'specialOnly')::boolean,false)
    order by random() limit 1;
  end if;
  if item.item_id is null then
   select * into item from public.shop_catalog s where s.active and s.kind='avatar' and (public._gc_data()->'rewardIcons') ? s.item_id
    and not exists(select 1 from public.player_inventory i where i.player_id=uid and i.item_id=s.item_id) order by random() limit 1;
  end if;
  if item.item_id is null then return jsonb_build_object('milestone',m,'pending',true);end if;
  if item.kind='card' then
   insert into public.player_card_copies(player_id,card_id,copies) values(uid,item.card_id,1) on conflict(player_id,card_id) do update set copies=public.player_card_copies.copies+1;
  end if;
  insert into public.player_inventory(player_id,item_id) values(uid,item.item_id) on conflict do nothing;
  update public.guardian_campaign_rewards set item_id=item.item_id,granted_at=clock_timestamp() where player_id=uid and milestone=m;
 end if;
 return jsonb_build_object('milestone',m,'pending',false,'itemId',item.item_id,'name',item.title,'kind',item.kind,'cardId',item.card_id,'asset',item.asset_path);
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
 return run;
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
