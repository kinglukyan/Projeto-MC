-- 030: sorteio de unidades e decisão pelo Eclipse. Aplicar após 029.
begin;
do $$begin if to_regprocedure('public.admin_role_overview()') is null then raise exception 'Execute o SQL 029 antes do SQL 030.';end if;end $$;
create table if not exists public.random_tiebreak_results(
 match_id uuid primary key references public.game_matches(id) on delete cascade,
 payload jsonb not null,created_at timestamptz not null default now()
);
create table if not exists public.guardian_tiebreak_results(
 player_id uuid references public.profiles(id) on delete cascade,match_id uuid,
 payload jsonb not null,created_at timestamptz not null default now(),primary key(player_id,match_id)
);
alter table public.random_tiebreak_results enable row level security;
alter table public.guardian_tiebreak_results enable row level security;
revoke all on public.random_tiebreak_results,public.guardian_tiebreak_results from public,anon,authenticated;

create or replace function public._tb_random_result(first_pool jsonb,second_pool jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a jsonb; b jsonb; original_a jsonb;original_b jsonb;draws jsonb:='[]';n integer;i integer;j integer;ca text;cb text;pa integer;pb integer;winner text;lunar text;outcome text;
begin
 select coalesce(jsonb_agg(value),'[]') into original_a from jsonb_array_elements_text(first_pool) where public._r_card(value)->>'kind'='unit' and not coalesce((public._r_card(value)->>'specialOnly')::boolean,false);
 select coalesce(jsonb_agg(value),'[]') into original_b from jsonb_array_elements_text(second_pool) where public._r_card(value)->>'kind'='unit' and not coalesce((public._r_card(value)->>'specialOnly')::boolean,false);
 a:=original_a;b:=original_b;
 if jsonb_array_length(a)>0 and jsonb_array_length(b)>0 then
  for n in 1..5 loop
   -- Copies have equal chances. Recycle only when the physical unit pool runs out.
   if jsonb_array_length(a)=0 then a:=original_a;end if;if jsonb_array_length(b)=0 then b:=original_b;end if;
   i:=floor(random()*jsonb_array_length(a))::integer;j:=floor(random()*jsonb_array_length(b))::integer;
   ca:=a->>i;cb:=b->>j;a:=a-i;b:=b-j;
   pa:=coalesce((public._r_card(ca)->>'power')::integer,0);pb:=coalesce((public._r_card(cb)->>'power')::integer,0);
   draws:=draws||jsonb_build_array(jsonb_build_object('round',n,'player_one',ca,'player_two',cb,'player_one_power',pa,'player_two_power',pb));
   if pa<pb then winner:='player_one';exit;elsif pb<pa then winner:='player_two';exit;end if;
  end loop;
 end if;
 if winner is null then
  lunar:=case when get_byte(uuid_send(gen_random_uuid()),0)%2=0 then 'player_one' else 'player_two' end;
  outcome:=case when get_byte(uuid_send(gen_random_uuid()),0)%2=0 then 'eclipse-lunar' else 'eclipse-solar' end;
  winner:=case when outcome='eclipse-lunar' then lunar when lunar='player_one' then 'player_two' else 'player_one' end;
 end if;
 return jsonb_build_object('version',2,'resolved',true,'draws',draws,'winner_side',winner,'lunar_side',lunar,'eclipse',outcome,'empty_pool',jsonb_array_length(original_a)=0 or jsonb_array_length(original_b)=0);
end $$;

create or replace function public._tb_match_pool(mid uuid,side_key text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.game_matches%rowtype;players uuid[];result jsonb;fallback jsonb;
begin
 select * into g from public.game_matches where id=mid;
 if g.team_size=2 then select array_agg(player_id) into players from public.duo_match_players where match_id=mid and team=case when side_key='player_one' then 1 else 2 end;
 else players:=array[case when side_key='player_one' then g.player_one else g.player_two end];end if;
 select coalesce(jsonb_agg(e.key),'[]') into result from public.player_match_decks d
 join public.player_deck_usage u on u.player_id=d.player_id and u.deck_key=d.deck_key
 cross join lateral jsonb_each_text(u.card_counts) e cross join lateral generate_series(1,least(35,greatest(0,e.value::integer))) copies
 where d.match_id=mid and d.player_id=any(players);
 if jsonb_array_length(result)>0 then return result;end if;
 -- Compatibility for older matches without an original-deck snapshot.
 fallback:=coalesce(g.state#>array[side_key,'hand'],'[]')||coalesce(g.state#>array[side_key,'deck'],'[]')||coalesce(g.state#>array[side_key,'underworld'],'[]');
 select fallback||coalesce(jsonb_agg(coalesce(value->>'eclipseOriginalCardId',value->>'cardId')),'[]') into fallback from jsonb_array_elements(coalesce(g.state#>array[side_key,'field'],'[]'));
 if g.team_size=2 then select fallback||coalesce(jsonb_agg(cards.value),'[]') into fallback from public.duo_player_states d cross join lateral jsonb_array_elements_text(coalesce(d.private_state->'hand','[]')||coalesce(d.private_state->'deck','[]')) cards(value) where d.match_id=mid and d.player_id=any(players);end if;
 return fallback;
end $$;

create or replace function public._tb_award(mid uuid,winner_team text) returns void
language plpgsql security definer set search_path='' as $$
declare g public.game_matches%rowtype;r record;won boolean;target_xp integer;target_coins integer;
begin
 select * into g from public.game_matches where id=mid;
 for r in select h.* from public.match_history h where h.match_id=mid and h.outcome='draw' order by h.player_id for update loop
  won:=case when g.team_size=2 then exists(select 1 from public.duo_match_players d where d.match_id=mid and d.player_id=r.player_id and d.team=case when winner_team='player_one' then 1 else 2 end) else r.player_id=case when winner_team='player_one' then g.player_one else g.player_two end end;
  target_xp:=case when won then 30 else 20 end;target_coins:=case when won then 20 else 10 end;
  update public.profiles set xp=xp+target_xp-r.xp_earned,mythic_coins=mythic_coins+target_coins-r.coins_earned,
   wins=wins+case when won then 1 else 0 end,losses=losses+case when won then 0 else 1 end,
   rating_points=greatest(0,rating_points+case when g.mode='ranked' then case when won then 25 else -25 end else 0 end) where id=r.player_id;
  update public.match_history set outcome=case when won then 'victory' else 'defeat' end,xp_earned=target_xp,coins_earned=target_coins where match_id=mid and player_id=r.player_id;
  update public.player_deck_usage u set wins=u.wins+case when won then 1 else 0 end,losses=u.losses+case when won then 0 else 1 end where u.player_id=r.player_id and u.deck_key=(select d.deck_key from public.player_match_decks d where d.match_id=mid and d.player_id=r.player_id);
 end loop;
end $$;

create or replace function public.get_tiebreak_state(p_match_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.game_matches%rowtype;result jsonb;my_side text;winner uuid;one_name text;two_name text;
begin
 perform public._assert_account_active();if auth.uid() is null then raise exception 'Entre na conta.';end if;
 select * into g from public.game_matches where id=p_match_id for update;
 if not found or not coalesce(auth.uid()=any(array[g.player_one,g.player_two,g.player_three,g.player_four]),false) then raise exception 'Partida indisponível.' using errcode='42501';end if;
 if g.team_size=2 then select case when team=1 then 'player_one' else 'player_two' end into my_side from public.duo_match_players where match_id=g.id and player_id=auth.uid();else my_side:=case when auth.uid()=g.player_one then 'player_one' else 'player_two' end;end if;
 if my_side is null then raise exception 'Jogador não participa desta partida.' using errcode='42501';end if;
 select payload into result from public.random_tiebreak_results where match_id=g.id;
 if result is null then
  if g.status<>'completed' or g.winner_id is not null then raise exception 'Esta partida não está empatada.';end if;
  result:=public._tb_random_result(public._tb_match_pool(g.id,'player_one'),public._tb_match_pool(g.id,'player_two'));
  winner:=case when result->>'winner_side'='player_one' then g.player_one else g.player_two end;
  select nickname into one_name from public.profiles where id=g.player_one;select nickname into two_name from public.profiles where id=g.player_two;
  if g.team_size=2 then
   select string_agg(p.nickname,' + ' order by d.seat) into one_name from public.duo_match_players d join public.profiles p on p.id=d.player_id where d.match_id=g.id and d.team=1;
   select string_agg(p.nickname,' + ' order by d.seat) into two_name from public.duo_match_players d join public.profiles p on p.id=d.player_id where d.match_id=g.id and d.team=2;
  end if;
  result:=result||jsonb_build_object('match_id',g.id,'winner_id',winner,'player_one_name',one_name,'player_two_name',two_name,'team_size',g.team_size);
  insert into public.random_tiebreak_results(match_id,payload) values(g.id,result);
  perform public._tb_award(g.id,result->>'winner_side');
  update public.game_matches set winner_id=winner,state=jsonb_set(jsonb_set(state,'{winner_id}',to_jsonb(winner),true),'{randomTieBreak}',result,true) where id=g.id;
 end if;
 return result||jsonb_build_object('my_side',my_side);
end $$;

create or replace function public.submit_tiebreak_card(p_match_id uuid,p_card_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
begin perform public._assert_account_active();raise exception 'O desempate agora é automático. Atualize a página para assistir ao sorteio.';end $$;

create or replace function public.resolve_guardian_tiebreak(p_match_id uuid,p_points integer,p_cards jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;counts jsonb;enemy jsonb:='["soldado-esparta","soldado-esparta","soldado-esparta","athena","athena","lobo-alfa","lobo-alfa","guardiao-nordico","guardiao-nordico","medusa","poseidon","zeus","hades"]';h public.match_history%rowtype;won boolean;uid uuid:=auth.uid();
begin
 perform public._assert_account_active();if uid is null then raise exception 'Entre na conta.';end if;
 perform 1 from public.profiles where id=uid for update;
 select payload into result from public.guardian_tiebreak_results where player_id=uid and match_id=p_match_id;
 if result is not null then return result||jsonb_build_object('my_side','player_one');end if;
 if jsonb_typeof(p_cards) is distinct from 'array' or jsonb_array_length(p_cards) not between 14 and 35 then raise exception 'Baralho de desempate inválido.';end if;
 select jsonb_object_agg(card_id,n) into counts from(select value card_id,count(*) n from jsonb_array_elements_text(p_cards) group by value) c;
 perform public._assert_owned_deck(uid,counts);
 perform public.record_guardian_match(p_match_id,'draw',p_points,p_points);
 select * into h from public.match_history where guardian_match_id=p_match_id and player_id=uid for update;
 if h.outcome is distinct from 'draw' then raise exception 'Esta partida já foi resolvida.';end if;
 result:=public._tb_random_result(p_cards,enemy);won:=result->>'winner_side'='player_one';
 result:=result||jsonb_build_object('match_id',p_match_id,'player_one_name',(select nickname from public.profiles where id=uid),'player_two_name','Guardião da Arena');
 insert into public.guardian_tiebreak_results values(uid,p_match_id,result,now());
 update public.match_history set outcome=case when won then 'victory' else 'defeat' end,xp_earned=case when won then 30 else 20 end,coins_earned=case when won then 20 else 10 end where guardian_match_id=p_match_id and player_id=uid;
 update public.profiles set wins=wins+case when won then 1 else 0 end,losses=losses+case when won then 0 else 1 end,xp=xp+case when won then 15 else 5 end,mythic_coins=mythic_coins+case when won then 10 else 0 end where id=uid;
 return result||jsonb_build_object('my_side','player_one');
end $$;

revoke all on function public._tb_random_result(jsonb,jsonb),public._tb_match_pool(uuid,text),public._tb_award(uuid,text),public.get_tiebreak_state(uuid),public.submit_tiebreak_card(uuid,text),public.resolve_guardian_tiebreak(uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.get_tiebreak_state(uuid),public.submit_tiebreak_card(uuid,text),public.resolve_guardian_tiebreak(uuid,integer,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
