-- 031: corrige a criação da partida disparada pelo segundo jogador da fila.
-- Aplicar depois da 030. Não modifica partidas em andamento nem os baralhos salvos.
begin;

-- A coleção, o catálogo e as regras de pausa continuam sendo validados pelos
-- mesmos validadores usados pelo construtor. Não manter outra lista de IDs aqui.
create or replace function public._match_deck_resources(p_player uuid,p_hand_size integer,p_first boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare counts jsonb; shuffled text[];
begin
 if p_player is null or p_hand_size not in (4,5) or p_hand_size is null or p_first is null then
  raise exception 'Participante ou distribuição inicial inválida.';
 end if;
 -- Keep the deck stable between ownership validation and the initial shuffle.
 select d.card_counts into counts from public.player_decks d where d.player_id=p_player for share;
 perform public._assert_match_inventory(p_player);
 -- Zero placeholders from older serializers do not become playable cards.
 select array_agg(c.key order by random()) into shuffled
 from jsonb_each_text(counts) c
 cross join lateral generate_series(1,c.value::integer) copy_number;
 return jsonb_build_object(
  'hand',coalesce(to_jsonb(shuffled[1:p_hand_size]),'[]'::jsonb),
  'deck',coalesce(to_jsonb(shuffled[p_hand_size+1:array_length(shuffled,1)]),'[]'::jsonb),
  'underworld','[]'::jsonb,'passed',false,'playedThisTurn',false,
  'skipNextTurn',false,'turnsTaken',case when p_first then 1 else 0 end);
end $$;
revoke all on function public._match_deck_resources(uuid,integer,boolean) from public,anon,authenticated;

create or replace function public._new_online_game_state(p_one uuid,p_two uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare one_state jsonb;two_state jsonb;field_state jsonb;
begin
 if p_one is null or p_two is null or p_one=p_two then raise exception 'Participantes inválidos.';end if;
 field_state:=jsonb_build_object('field','[]'::jsonb,'trixx',2,'roundPenalty',0,'greekAura',0,'norseAura',0);
 one_state:=public._match_deck_resources(p_one,5,true)||field_state;
 two_state:=public._match_deck_resources(p_two,4,false)||field_state;
 return jsonb_build_object(
  'player_one',one_state,'player_two',two_state,'round',1,'roundCycles',0,'current_turn',p_one,
  'sharedZones',jsonb_build_object('local',null,'terrain',null,'climate',null),
  'totalPoints',jsonb_build_object('player_one',0,'player_two',0),
  'roundWins',jsonb_build_object('player_one',0,'player_two',0),
  'finished',false,'winner_id',null,'log',jsonb_build_array('A batalha online começou.'));
end $$;
revoke all on function public._new_online_game_state(uuid,uuid) from public,anon,authenticated;

create or replace function public._new_online_duo_state(p_one uuid,p_two uuid,p_three uuid,p_four uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid;resources jsonb:='{}'::jsonb;idx integer:=0;field_state jsonb;
begin
 if p_one is null or p_two is null or p_three is null or p_four is null
 or (select count(distinct participant) from unnest(array[p_one,p_two,p_three,p_four]) participant)<>4
 then raise exception 'Participantes da dupla inválidos.';end if;
 foreach uid in array array[p_one,p_two,p_three,p_four] loop
  resources:=jsonb_set(resources,array[uid::text],
   public._match_deck_resources(uid,case when idx=0 then 5 else 4 end,idx=0),true);
  idx:=idx+1;
 end loop;
 field_state:=jsonb_build_object('field','[]'::jsonb,'underworld','[]'::jsonb,'trixx',2,'roundPenalty',0,'greekAura',0,'norseAura',0);
 return jsonb_build_object(
  'player_one',field_state,'player_two',field_state,'privatePlayers',resources,
  'round',1,'sharedZones',jsonb_build_object('local',null,'terrain',null,'climate',null),
  'totalPoints',jsonb_build_object('player_one',0,'player_two',0),
  'roundWins',jsonb_build_object('player_one',0,'player_two',0),
  'turnOrder',jsonb_build_array(p_one,p_two,p_three,p_four),'currentTurnIndex',0,
  'finished',false,'log',jsonb_build_array('Duelo de duplas iniciado. Cada jogador verá somente a própria mão.'));
end $$;
revoke all on function public._new_online_duo_state(uuid,uuid,uuid,uuid) from public,anon,authenticated;

-- Reject an invalid active deck before placing its owner in the solo queue.
-- Preserve all existing account checks, queue locks, modes and rating filters.
do $queue_validation$
declare routine regprocedure;definition text;updated text;
begin
 routine:=to_regprocedure('public.join_matchmaking(text)');
 if routine is null then raise exception 'Função de fila ausente. Aplique as migrações anteriores à 031.';end if;
 definition:=pg_get_functiondef(routine);
 if position('MATCH_QUEUE_DECK_V31' in definition)=0 then
  updated:=regexp_replace(definition,'\mBEGIN\M',
   E'begin /* MATCH_QUEUE_DECK_V31 */\n if auth.uid() is not null then perform public._assert_match_inventory(auth.uid());end if;','i');
  if updated=definition then raise exception 'Não foi possível atualizar a validação da fila.';end if;
  execute updated;
 end if;
end $queue_validation$;

notify pgrst,'reload schema';
commit;
