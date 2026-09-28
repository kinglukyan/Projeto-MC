-- Add Medusa as a server-authoritative card and include her in future default decks.
begin;

alter table public.player_decks alter column card_counts set default '{"soldado-esparta":3,"athena":2,"lobo-alfa":2,"guardiao-nordico":2,"mjolnir":1,"runas-nordicas":1,"grecia":1,"eclipse":2,"medusa":1}'::jsonb;
alter table public.card_lore drop constraint if exists card_lore_card_id_check;
alter table public.card_lore add constraint card_lore_card_id_check check (card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa'));

create or replace function public.get_online_match(p_match_id uuid)
returns jsonb language sql security definer set search_path = '' stable as $$
  select jsonb_build_object(
    'match',to_jsonb(g),
    'opponent_name',coalesce(nullif(p.nickname,''),p.display_name),
    'opponent_icon',p.equipped_avatar,
    'opponent_rating',p.rating_points
  )
  from public.game_matches g
  join public.profiles p on p.id=case when g.player_one=auth.uid() then g.player_two else g.player_one end
  where g.id=p_match_id and auth.uid() in (g.player_one,g.player_two)
  limit 1;
$$;
revoke all on function public.get_online_match(uuid) from public,anon;
grant execute on function public.get_online_match(uuid) to authenticated;

create or replace function public._new_online_game_state(p_one uuid,p_two uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  counts jsonb;
  shuffled text[];
  one_state jsonb;
  two_state jsonb;
begin
  for counts in select coalesce(d.card_counts,'{"soldado-esparta":3,"athena":2,"lobo-alfa":2,"guardiao-nordico":2,"mjolnir":1,"runas-nordicas":1,"grecia":1,"eclipse":2,"medusa":1}'::jsonb)
    from (select 1) seed left join public.player_decks d on d.player_id=p_one
  loop
    if (select coalesce(sum(value::integer),0) from jsonb_each_text(counts)) not between 12 and 20 then
      raise exception 'Os dois jogadores precisam de um baralho entre 12 e 20 cartas.';
    end if;
    if exists(select 1 from jsonb_each_text(counts) where key not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa') or value !~ '^(0|[1-9]|1[0-9]|20)$') then
      raise exception 'O baralho contém quantidade ou carta inválida.';
    end if;
    select array_agg(card_id order by random()) into shuffled
    from jsonb_each_text(counts) c cross join lateral generate_series(1,c.value::integer) copies
    cross join lateral (select c.key as card_id) alias_card;
    one_state:=jsonb_build_object('hand',to_jsonb(shuffled[1:5]),'deck',to_jsonb(shuffled[6:array_length(shuffled,1)]),'field','[]'::jsonb,'underworld','[]'::jsonb,'trixx',2,'roundPenalty',0,'turnsTaken',1,'passed',false,'playedThisTurn',false,'greekAura',0,'norseAura',0);
  end loop;
  select coalesce(d.card_counts,'{"soldado-esparta":3,"athena":2,"lobo-alfa":2,"guardiao-nordico":2,"mjolnir":1,"runas-nordicas":1,"grecia":1,"eclipse":2,"medusa":1}'::jsonb) into counts
    from (select 1) seed left join public.player_decks d on d.player_id=p_two;
  if (select coalesce(sum(value::integer),0) from jsonb_each_text(counts)) not between 12 and 20 then raise exception 'O baralho do segundo jogador precisa ter entre 12 e 20 cartas.'; end if;
  if exists(select 1 from jsonb_each_text(counts) where key not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa') or value !~ '^(0|[1-9]|1[0-9]|20)$') then raise exception 'O segundo baralho contém quantidade ou carta inválida.'; end if;
  select array_agg(card_id order by random()) into shuffled
    from jsonb_each_text(counts) c cross join lateral generate_series(1,c.value::integer) copies
    cross join lateral (select c.key as card_id) alias_card;
  two_state:=jsonb_build_object('hand',to_jsonb(shuffled[1:4]),'deck',to_jsonb(shuffled[5:array_length(shuffled,1)]),'field','[]'::jsonb,'underworld','[]'::jsonb,'trixx',2,'roundPenalty',0,'turnsTaken',0,'passed',false,'playedThisTurn',false,'greekAura',0,'norseAura',0);
  return jsonb_build_object('player_one',one_state,'player_two',two_state,'round',1,'roundCycles',0,'current_turn',p_one,'sharedZones',jsonb_build_object('local',null,'terrain',null,'climate',null),'totalPoints',jsonb_build_object('player_one',0,'player_two',0),'roundWins',jsonb_build_object('player_one',0,'player_two',0),'finished',false,'winner_id',null,'log',jsonb_build_array('A batalha online começou.'));
end;
$$;

create or replace function public._online_unit_power(p_side jsonb,p_unit jsonb,p_zones jsonb)
returns integer language plpgsql security definer set search_path = '' stable as $$
declare cid text:=p_unit->>'cardId'; base_power integer; soldiers integer; faction text; bonus integer:=coalesce((p_unit->>'bonus')::integer,0); total integer;
begin
  select count(*) into soldiers from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) u where u->>'cardId'='soldado-esparta';
  base_power:=case cid when 'soldado-esparta' then 3*(2^greatest(soldiers-1,0))::integer when 'athena' then 5 when 'lobo-alfa' then 4 when 'guardiao-nordico' then 2 when 'medusa' then 4 else 0 end;
  faction:=case when cid in ('soldado-esparta','athena','grecia','medusa') then 'greek' when cid in ('guardiao-nordico','mjolnir','runas-nordicas') then 'norse' else '' end;
  total:=base_power+bonus;
  if faction='greek' then total:=total+coalesce((p_side->>'greekAura')::integer,0)+case when p_zones->>'local'='grecia' then 1 else 0 end+case when p_zones->>'terrain'='campo-troia' then 1 else 0 end; end if;
  if faction='norse' then total:=total+coalesce((p_side->>'norseAura')::integer,0); end if;
  return greatest(0,total);
end;
$$;

create or replace function public.submit_game_action(p_match_id uuid,p_action jsonb)
returns public.game_matches language plpgsql security definer set search_path = '' as $$
declare
  g public.game_matches%rowtype; s jsonb; side_key text; other_key text; side jsonb; other_side jsonb;
  action_type text:=p_action->>'type'; card_id text; card_idx integer; lane integer; hand_array jsonb; deck_array jsonb; field_array jsonb; unit jsonb;
  target_idx integer; target_power integer; candidate_power integer; best_bonus integer; zones jsonb;
  current_player uuid; next_player uuid; one_score integer; two_score integer; one_total integer; two_total integer; next_round integer;
  one_state jsonb; two_state jsonb; winner uuid; finished boolean:=false; round_advanced boolean:=false; i integer; j integer; ids jsonb;
begin
  if auth.uid() is null then raise exception 'Faça login para jogar.'; end if;
  select * into g from public.game_matches where id=p_match_id for update;
  if not found or g.status<>'active' then raise exception 'Partida não encontrada ou encerrada.'; end if;
  if auth.uid() not in (g.player_one,g.player_two) then raise exception 'Você não participa desta partida.'; end if;
  if g.turn_user<>auth.uid() then raise exception 'Aguarde a sua vez.'; end if;
  s:=g.state; side_key:=case when auth.uid()=g.player_one then 'player_one' else 'player_two' end;
  other_key:=case when side_key='player_one' then 'player_two' else 'player_one' end;
  side:=s->side_key; other_side:=s->other_key; zones:=s->'sharedZones';
  if coalesce((side->>'passed')::boolean,false) then raise exception 'Você já passou nesta rodada.'; end if;

  if action_type='play' then
    if coalesce((side->>'skipNextTurn')::boolean,false) then raise exception 'Você foi petrificado e perdeu este turno.'; end if;
    if coalesce((side->>'playedThisTurn')::boolean,false) then raise exception 'Você já jogou uma carta neste turno.'; end if;
    card_id:=p_action->>'card_id';
    if card_id not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa') then raise exception 'Carta inválida.'; end if;
    hand_array:=coalesce(side->'hand','[]'::jsonb);
    select ordinality::integer into card_idx from jsonb_array_elements_text(hand_array) with ordinality h(value,ordinality) where h.value=card_id limit 1;
    if card_idx is null then raise exception 'Essa carta não está na sua mão.'; end if;
    select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into hand_array from jsonb_array_elements(hand_array) with ordinality e(value,ordinality) where ordinality<>card_idx;
    field_array:=coalesce(side->'field','[]'::jsonb); deck_array:=coalesce(side->'deck','[]'::jsonb);
    if card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','medusa') then
      lane:=greatest(0,least(2,coalesce((p_action->>'lane')::integer,0)));
      unit:=jsonb_build_object('cardId',card_id,'bonus',case when card_id='lobo-alfa' then 1 else 0 end,'lane',lane,'slot',jsonb_array_length(field_array));
      field_array:=field_array||jsonb_build_array(unit);
      if card_id='medusa' then other_side:=jsonb_set(other_side,'{skipNextTurn}','true'::jsonb,true); end if;
      if card_id='athena' and jsonb_array_length(deck_array)>0 then hand_array:=hand_array||jsonb_build_array(deck_array->0);select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into deck_array from jsonb_array_elements(deck_array) with ordinality e(value,ordinality) where ordinality>1; end if;
    elsif card_id='mjolnir' then
      if jsonb_array_length(field_array)=0 then raise exception 'Jogue um personagem antes de usar Mjölnir.'; end if;
      target_idx:=0;best_bonus:=-100000; i:=0;
      for unit in select value from jsonb_array_elements(field_array) loop
        candidate_power:=public._online_unit_power(side,unit,zones);
        if candidate_power>best_bonus then best_bonus:=candidate_power;target_idx:=i;end if;
        i:=i+1;
      end loop;
      select coalesce(jsonb_agg(case when ordinality=target_idx+1 then jsonb_set(value,'{bonus}',to_jsonb(coalesce((value->>'bonus')::integer,0)+2),true) else value end order by ordinality),'[]'::jsonb) into field_array from jsonb_array_elements(field_array) with ordinality e(value,ordinality);
    elsif card_id='runas-nordicas' then side:=jsonb_set(side,'{norseAura}',to_jsonb(coalesce((side->>'norseAura')::integer,0)+2),true);
    elsif card_id='grecia' then
      if zones->>'local' is not null then raise exception 'O espaço compartilhado de Local já está ocupado.'; end if;
      zones:=jsonb_set(zones,'{local}','"grecia"'::jsonb,true);
    elsif card_id='eclipse' then
      if zones->>'climate' is not null then raise exception 'O espaço compartilhado de Clima já está ocupado.'; end if;
      zones:=jsonb_set(zones,'{climate}','"eclipse"'::jsonb,true);
      other_side:=jsonb_set(other_side,'{roundPenalty}',to_jsonb(coalesce((other_side->>'roundPenalty')::integer,0)+3),true);
    elsif card_id='campo-troia' then
      if zones->>'terrain' is not null then raise exception 'O espaço compartilhado de Terreno já está ocupado.'; end if;
      zones:=jsonb_set(zones,'{terrain}','"campo-troia"'::jsonb,true);
    end if;
    side:=jsonb_set(side,'{hand}',hand_array,true);side:=jsonb_set(side,'{field}',field_array,true);side:=jsonb_set(side,'{deck}',deck_array,true);
    side:=jsonb_set(side,'{playedThisTurn}','true'::jsonb,true);
    if jsonb_array_length(hand_array)=0 and jsonb_array_length(deck_array)=0 then side:=jsonb_set(side,'{passed}','true'::jsonb,true);end if;
  elsif action_type='pass' then
    side:=jsonb_set(side,'{passed}','true'::jsonb,true);
  elsif action_type='skip_turn' then
    if not coalesce((side->>'skipNextTurn')::boolean,false) then raise exception 'Você não está sob o efeito da Medusa.'; end if;
    side:=jsonb_set(side,'{skipNextTurn}','false'::jsonb,true);
    side:=jsonb_set(side,'{playedThisTurn}','true'::jsonb,true);
  else
    raise exception 'Ação de jogo inválida.';
  end if;

  s:=jsonb_set(s,ARRAY[side_key],side,true);s:=jsonb_set(s,ARRAY[other_key],other_side,true);s:=jsonb_set(s,'{sharedZones}',zones,true);
  if (coalesce((side->>'passed')::boolean,false) or (jsonb_array_length(side->'hand')=0 and jsonb_array_length(side->'deck')=0))
     and (coalesce((other_side->>'passed')::boolean,false) or (jsonb_array_length(other_side->'hand')=0 and jsonb_array_length(other_side->'deck')=0)) then
    one_state:=s->'player_one';two_state:=s->'player_two';one_score:=public._online_side_score(one_state,zones);two_score:=public._online_side_score(two_state,zones);
    one_total:=coalesce((s#>>'{totalPoints,player_one}')::integer,0)+one_score;two_total:=coalesce((s#>>'{totalPoints,player_two}')::integer,0)+two_score;
    s:=jsonb_set(s,'{totalPoints,player_one}',to_jsonb(one_total),true);s:=jsonb_set(s,'{totalPoints,player_two}',to_jsonb(two_total),true);
    if one_score>two_score then one_state:=jsonb_set(one_state,'{trixx}',to_jsonb(greatest(0,(one_state->>'trixx')::integer-1)),true);s:=jsonb_set(s,'{roundWins,player_one}',to_jsonb(coalesce((s#>>'{roundWins,player_one}')::integer,0)+1),true);
    elsif two_score>one_score then two_state:=jsonb_set(two_state,'{trixx}',to_jsonb(greatest(0,(two_state->>'trixx')::integer-1)),true);s:=jsonb_set(s,'{roundWins,player_two}',to_jsonb(coalesce((s#>>'{roundWins,player_two}')::integer,0)+1),true);end if;
    for unit in select value from jsonb_array_elements(coalesce(one_state->'field','[]'::jsonb)) loop one_state:=jsonb_set(one_state,'{underworld}',coalesce(one_state->'underworld','[]'::jsonb)||jsonb_build_array(unit->>'cardId'),true);end loop;
    for unit in select value from jsonb_array_elements(coalesce(two_state->'field','[]'::jsonb)) loop two_state:=jsonb_set(two_state,'{underworld}',coalesce(two_state->'underworld','[]'::jsonb)||jsonb_build_array(unit->>'cardId'),true);end loop;
    one_state:=jsonb_set(one_state,'{field}','[]'::jsonb,true);two_state:=jsonb_set(two_state,'{field}','[]'::jsonb,true);
    for i in 1..2 loop
      ids:=case when i=1 then one_state else two_state end;
      ids:=jsonb_set(ids,'{roundPenalty}','0'::jsonb,true);ids:=jsonb_set(ids,'{greekAura}','0'::jsonb,true);ids:=jsonb_set(ids,'{norseAura}','0'::jsonb,true);
      ids:=jsonb_set(ids,'{playedThisTurn}','false'::jsonb,true);ids:=jsonb_set(ids,'{passed}','false'::jsonb,true);ids:=jsonb_set(ids,'{turnsTaken}','0'::jsonb,true);
      deck_array:=coalesce(ids->'deck','[]'::jsonb);hand_array:=coalesce(ids->'hand','[]'::jsonb);
      for j in 1..2 loop if jsonb_array_length(deck_array)>0 then hand_array:=hand_array||jsonb_build_array(deck_array->0);select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into deck_array from jsonb_array_elements(deck_array) with ordinality e(value,ordinality) where ordinality>1;end if;end loop;
      ids:=jsonb_set(ids,'{hand}',hand_array,true);ids:=jsonb_set(ids,'{deck}',deck_array,true);
      if i=1 then one_state:=ids;else two_state:=ids;end if;
    end loop;
    s:=jsonb_set(s,'{player_one}',one_state,true);s:=jsonb_set(s,'{player_two}',two_state,true);s:=jsonb_set(s,'{sharedZones}',jsonb_build_object('local',null,'terrain',null,'climate',null),true);
    next_round:=(s->>'round')::integer+1;
    if next_round<=2 or (next_round=3 and one_total=two_total) then
      round_advanced:=true;s:=jsonb_set(s,'{round}',to_jsonb(next_round),true);current_player:=g.player_one;
    else
      finished:=true;winner:=case when one_total>two_total then g.player_one when two_total>one_total then g.player_two else null end;
      s:=jsonb_set(s,'{finished}','true'::jsonb,true);s:=jsonb_set(s,'{winner_id}',coalesce(to_jsonb(winner),'null'::jsonb),true);s:=jsonb_set(s,'{lastRoundPoints}',jsonb_build_object('player_one',one_score,'player_two',two_score),true);
    end if;
  end if;

  if not finished and round_advanced then
    side_key:='player_one';side:=s->side_key;side:=jsonb_set(side,'{turnsTaken}','1'::jsonb,true);side:=jsonb_set(side,'{playedThisTurn}','false'::jsonb,true);
    deck_array:=coalesce(side->'deck','[]'::jsonb);hand_array:=coalesce(side->'hand','[]'::jsonb);
    if jsonb_array_length(deck_array)>0 then hand_array:=hand_array||jsonb_build_array(deck_array->0);select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into deck_array from jsonb_array_elements(deck_array) with ordinality e(value,ordinality) where ordinality>1;end if;
    side:=jsonb_set(side,'{hand}',hand_array,true);side:=jsonb_set(side,'{deck}',deck_array,true);s:=jsonb_set(s,ARRAY[side_key],side,true);
  elsif not finished then
    s:=jsonb_set(s,ARRAY[side_key],side,true);s:=jsonb_set(s,ARRAY[other_key],other_side,true);
    if coalesce((s#>>ARRAY[other_key,'passed'])::boolean,false) then current_player:=auth.uid();else current_player:=case when side_key='player_one' then g.player_two else g.player_one end;end if;
    next_player:=current_player;
    side_key:=case when next_player=g.player_one then 'player_one' else 'player_two' end;side:=s->side_key;
    if not coalesce((side->>'passed')::boolean,false) then
      side:=jsonb_set(side,'{playedThisTurn}','false'::jsonb,true);side:=jsonb_set(side,'{turnsTaken}',to_jsonb(coalesce((side->>'turnsTaken')::integer,0)+1),true);
      if mod((side->>'turnsTaken')::integer,2)=1 and jsonb_array_length(coalesce(side->'deck','[]'::jsonb))>0 then
        deck_array:=side->'deck';hand_array:=coalesce(side->'hand','[]'::jsonb)||jsonb_build_array(deck_array->0);
        select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into deck_array from jsonb_array_elements(deck_array) with ordinality e(value,ordinality) where ordinality>1;
        side:=jsonb_set(side,'{hand}',hand_array,true);side:=jsonb_set(side,'{deck}',deck_array,true);
      end if;
      if jsonb_array_length(coalesce(side->'hand','[]'::jsonb))=0 and jsonb_array_length(coalesce(side->'deck','[]'::jsonb))=0 then side:=jsonb_set(side,'{passed}','true'::jsonb,true);end if;
    end if;
    s:=jsonb_set(s,ARRAY[side_key],side,true);
    if coalesce((s#>>'{player_one,passed}')::boolean,false) and coalesce((s#>>'{player_two,passed}')::boolean,false) then
      -- Both sides exhausted during an automatic turn start; the next action closes the round.
      current_player:=case when side_key='player_one' then g.player_two else g.player_one end;
    end if;
  end if;

  update public.game_matches set state=s,turn_user=case when finished then null else current_player end,
    status=case when finished then 'completed' else 'active' end,winner_id=winner,finished_at=case when finished then now() else null end
    where id=p_match_id returning * into g;
  if finished and winner is not null then
    update public.profiles set wins=wins+1,rating_points=rating_points+case when g.mode='ranked' then 25 else 0 end where id=winner;
    update public.profiles set losses=losses+1,rating_points=greatest(0,rating_points-case when g.mode='ranked' then 25 else 0 end) where id in (g.player_one,g.player_two) and id<>winner;
  end if;
  return g;
end;
$$;

commit;
