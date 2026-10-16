-- Duo queue and 2v2 matches: two shared team fields, private hands per player.
begin;

alter table public.game_matches add column if not exists player_three uuid references public.profiles(id);
alter table public.game_matches add column if not exists player_four uuid references public.profiles(id);
alter table public.game_matches add column if not exists team_size smallint not null default 1 check(team_size in (1,2));

do $$ declare c record; begin
  for c in select conname from pg_constraint where conrelid='public.game_matches'::regclass and contype='c'
    and (pg_get_constraintdef(oid) ilike '%turn_user%' or pg_get_constraintdef(oid) ilike '%winner_id%')
  loop execute format('alter table public.game_matches drop constraint %I',c.conname); end loop;
end $$;

create table if not exists public.duo_queue_parties(
  id uuid primary key default gen_random_uuid(),
  mode text not null check(mode in ('normal','ranked')),
  host_id uuid not null references public.profiles(id) on delete cascade,
  partner_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'inviting' check(status in ('inviting','queued','matched','cancelled')),
  match_id uuid references public.game_matches(id) on delete set null,
  created_at timestamptz not null default now(),
  check(host_id<>partner_id)
);
create index if not exists duo_queue_waiting on public.duo_queue_parties(mode,created_at) where status='queued';
create unique index if not exists duo_queue_one_active_host on public.duo_queue_parties(host_id) where status in('inviting','queued');
create unique index if not exists duo_queue_one_active_partner on public.duo_queue_parties(partner_id) where status in('inviting','queued');
alter table public.duo_queue_parties enable row level security;
drop policy if exists "Players can view their duo queue invitations" on public.duo_queue_parties;
create policy "Players can view their duo queue invitations" on public.duo_queue_parties for select to authenticated using(auth.uid() in(host_id,partner_id));
grant select on public.duo_queue_parties to authenticated;

create table if not exists public.duo_match_players(
  match_id uuid not null references public.game_matches(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  team smallint not null check(team in (1,2)),
  seat smallint not null check(seat in (1,2)),
  primary key(match_id,player_id),
  unique(match_id,team,seat)
);
alter table public.duo_match_players enable row level security;
drop policy if exists "Players can view their own duo match seats" on public.duo_match_players;
create policy "Players can view their own duo match seats" on public.duo_match_players for select to authenticated using(player_id=auth.uid());
grant select on public.duo_match_players to authenticated;

create table if not exists public.duo_player_states(
  match_id uuid not null references public.game_matches(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  private_state jsonb not null,
  primary key(match_id,player_id)
);
alter table public.duo_player_states enable row level security;
drop policy if exists "Players can only read their own private deck state" on public.duo_player_states;
create policy "Players can only read their own private deck state" on public.duo_player_states for select to authenticated using(player_id=auth.uid());
revoke all on public.duo_player_states from anon,authenticated;
grant select on public.duo_player_states to authenticated;

create or replace function public._new_online_duo_state(p_one uuid,p_two uuid,p_three uuid,p_four uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid; counts jsonb; shuffled text[]; resources jsonb:='{}'::jsonb; idx integer:=0; hand_size integer;
begin
 foreach uid in array array[p_one,p_two,p_three,p_four] loop
  select coalesce(d.card_counts,'{"soldado-esparta":3,"athena":2,"lobo-alfa":2,"guardiao-nordico":2,"mjolnir":1,"runas-nordicas":1,"grecia":1,"eclipse":2,"campo-troia":1,"medusa":1,"poseidon":1,"zeus":1,"hades":1}'::jsonb)
    into counts from (select 1) seed left join public.player_decks d on d.player_id=uid;
  if (select coalesce(sum(value::integer),0) from jsonb_each_text(counts)) not between 12 and 20 then raise exception 'Cada integrante precisa de um baralho entre 12 e 20 cartas.'; end if;
  if exists(select 1 from jsonb_each_text(counts) where key not in('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades') or value !~ '^(0|[1-9]|1[0-9]|20)$') then raise exception 'Um baralho contém carta ou quantidade inválida.'; end if;
  select array_agg(card_id order by random()) into shuffled from jsonb_each_text(counts) c cross join lateral generate_series(1,c.value::integer) copies cross join lateral (select c.key as card_id) alias_card;
  hand_size:=case when idx=0 then 5 else 4 end;
  resources:=jsonb_set(resources,array[uid::text],jsonb_build_object('hand',to_jsonb(shuffled[1:hand_size]),'deck',to_jsonb(shuffled[hand_size+1:array_length(shuffled,1)]),'passed',false,'playedThisTurn',false,'skipNextTurn',false,'turnsTaken',case when idx=0 then 1 else 0 end,'underworld','[]'::jsonb),true);
  idx:=idx+1;
 end loop;
 return jsonb_build_object(
  'player_one',jsonb_build_object('field','[]'::jsonb,'underworld','[]'::jsonb,'trixx',2,'roundPenalty',0,'greekAura',0,'norseAura',0),
  'player_two',jsonb_build_object('field','[]'::jsonb,'underworld','[]'::jsonb,'trixx',2,'roundPenalty',0,'greekAura',0,'norseAura',0),
  'privatePlayers',resources,'round',1,'sharedZones',jsonb_build_object('local',null,'terrain',null,'climate',null),
  'totalPoints',jsonb_build_object('player_one',0,'player_two',0),'roundWins',jsonb_build_object('player_one',0,'player_two',0),
  'turnOrder',jsonb_build_array(p_one,p_two,p_three,p_four),'currentTurnIndex',0,'finished',false,'log',jsonb_build_array('Duelo de duplas iniciado. Cada jogador verá somente a própria mão.'));
end $$;
revoke all on function public._new_online_duo_state(uuid,uuid,uuid,uuid) from public,anon,authenticated;

create or replace function public.record_duo_deck_usage(p_match_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare player_row record; counts jsonb; deck_key text; deck_title text;
begin
 for player_row in select player_id,private_state from public.duo_player_states where match_id=p_match_id loop
  select coalesce(jsonb_object_agg(card_id,quantity),'{}'::jsonb) into counts from (select card_id,count(*)::integer quantity from jsonb_array_elements_text(coalesce(player_row.private_state->'hand','[]'::jsonb)||coalesce(player_row.private_state->'deck','[]'::jsonb)) cards(card_id) group by card_id) deck_counts;
  deck_key:=md5(counts::text);select name into deck_title from public.player_saved_decks where player_id=player_row.player_id and card_counts=counts order by updated_at desc limit 1;deck_title:=coalesce(deck_title,'Baralho · '||upper(substr(deck_key,1,5)));
  insert into public.player_deck_usage(player_id,deck_key,deck_name,card_counts,games_played,last_used_at) values(player_row.player_id,deck_key,deck_title,counts,1,now())
   on conflict(player_id,deck_key) do update set games_played=public.player_deck_usage.games_played+1,last_used_at=now();
  insert into public.player_match_decks(match_id,player_id,deck_key) values(p_match_id,player_row.player_id,deck_key) on conflict do nothing;
 end loop;
end $$;
revoke all on function public.record_duo_deck_usage(uuid) from public,anon,authenticated;

create or replace function public._player_pvp_unlocked(p_player_id uuid)
returns boolean language sql security definer set search_path='' stable as $$
 select coalesce(p.tutorial_completed,false) or coalesce(p.xp,0)>=100 or coalesce((p.settings->>'tutorial_completed')::boolean,false)
 from public.profiles p where p.id=p_player_id
$$;
revoke all on function public._player_pvp_unlocked(uuid) from public,anon,authenticated;
create or replace function public.create_duo_queue(p_mode text,p_partner_code text)
returns table(party_id uuid,partner_name text,party_status text)
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); partner uuid; pid uuid;
begin
 if uid is null then raise exception 'Entre na sua conta para formar uma dupla.'; end if;
 if p_mode not in('normal','ranked') then raise exception 'Este modo ainda não aceita fila em dupla.'; end if;
 select id into partner from public.profiles where friend_code=upper(trim(p_partner_code));
 if partner is null or partner=uid then raise exception 'Código de parceiro inválido.'; end if;
 if not exists(select 1 from public.friendships f where f.status='accepted' and uid in(f.user_a,f.user_b) and partner in(f.user_a,f.user_b)) then raise exception 'Adicione esse jogador como amigo antes de convidá-lo.'; end if;
 if not public._player_pvp_unlocked(uid) or not public._player_pvp_unlocked(partner) then raise exception 'Você e seu parceiro precisam concluir o tutorial para liberar o PvP.'; end if;
 if exists(select 1 from public.duo_queue_parties where status in('inviting','queued') and (auth.uid() in(host_id,partner_id) or partner in(host_id,partner_id))) then raise exception 'Você ou seu parceiro já está em uma dupla/fila.'; end if;
 if exists(select 1 from public.matchmaking_queue where status='waiting' and user_id in(uid,partner)) then raise exception 'Você ou seu parceiro já está na fila solo.'; end if;
 insert into public.duo_queue_parties(mode,host_id,partner_id) values(p_mode,uid,partner) returning id into pid;
 return query select pid,coalesce(nullif(p.nickname,''),p.display_name),'inviting'::text from public.profiles p where p.id=partner;
end $$;
revoke all on function public.create_duo_queue(text,text) from public,anon;
grant execute on function public.create_duo_queue(text,text) to authenticated;

create or replace function public.respond_duo_queue_invite(p_party_id uuid,p_accept boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); party public.duo_queue_parties%rowtype; other public.duo_queue_parties%rowtype; mid uuid; p1 uuid; p2 uuid; p3 uuid; p4 uuid; state jsonb;
begin
 if uid is null then raise exception 'Entre na sua conta para responder.'; end if;
 if not public._player_pvp_unlocked(uid) then raise exception 'Conclua o tutorial para liberar o PvP.'; end if;
 select * into party from public.duo_queue_parties where id=p_party_id and partner_id=uid and status='inviting' for update;
 if not found then raise exception 'Convite de dupla expirado ou indisponível.'; end if;
 if not p_accept then update public.duo_queue_parties set status='cancelled' where id=party.id; return jsonb_build_object('status','declined'); end if;
 update public.duo_queue_parties set status='queued' where id=party.id;
 select * into other from public.duo_queue_parties q where q.id<party.id and q.mode=party.mode and q.status='queued' and q.host_id<>party.host_id and q.host_id<>party.partner_id and q.partner_id<>party.host_id and q.partner_id<>party.partner_id and (party.mode<>'ranked' or abs((select avg(rating_points)::numeric from public.profiles where id in(q.host_id,q.partner_id))-(select avg(rating_points)::numeric from public.profiles where id in(party.host_id,party.partner_id)))<=250) order by q.created_at limit 1 for update skip locked;
 if not found then return jsonb_build_object('status','queued','party_id',party.id); end if;
 p1:=other.host_id;p2:=other.partner_id;p3:=party.host_id;p4:=party.partner_id;
 state:=public._new_online_duo_state(p1,p2,p3,p4);
 insert into public.game_matches(player_one,player_two,player_three,player_four,team_size,mode,status,state,turn_user)
 values(p1,p3,p2,p4,2,party.mode,'active',state-'privatePlayers',p1) returning id into mid;
 insert into public.duo_match_players(match_id,player_id,team,seat) values(mid,p1,1,1),(mid,p2,1,2),(mid,p3,2,1),(mid,p4,2,2);
 insert into public.duo_player_states(match_id,player_id,private_state) select mid,key::uuid,value from jsonb_each(state->'privatePlayers');
 perform public.record_duo_deck_usage(mid);
 update public.duo_queue_parties set status='matched',match_id=mid where id in(party.id,other.id);
 return jsonb_build_object('status','matched','match_id',mid,'team_size',2);
end $$;
revoke all on function public.respond_duo_queue_invite(uuid,boolean) from public,anon;
grant execute on function public.respond_duo_queue_invite(uuid,boolean) to authenticated;

create or replace function public.try_match_duo_queue(p_party_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); party public.duo_queue_parties%rowtype; other public.duo_queue_parties%rowtype; mid uuid; p1 uuid; p2 uuid; p3 uuid; p4 uuid; state jsonb;
begin
 if uid is null then raise exception 'Entre na sua conta para procurar uma dupla.'; end if;
 select * into party from public.duo_queue_parties where id=p_party_id and uid in(host_id,partner_id) for update;
 if not found then raise exception 'Fila de dupla não encontrada.'; end if;
 if party.status='matched' then return jsonb_build_object('status','matched','match_id',party.match_id); end if;
 if party.status<>'queued' then return jsonb_build_object('status',party.status,'party_id',party.id); end if;
 select * into other from public.duo_queue_parties q where q.id<party.id and q.mode=party.mode and q.status='queued' and q.host_id<>party.host_id and q.host_id<>party.partner_id and q.partner_id<>party.host_id and q.partner_id<>party.partner_id and (party.mode<>'ranked' or abs((select avg(rating_points)::numeric from public.profiles where id in(q.host_id,q.partner_id))-(select avg(rating_points)::numeric from public.profiles where id in(party.host_id,party.partner_id)))<=250) order by q.created_at limit 1 for update skip locked;
 if not found then return jsonb_build_object('status','queued','party_id',party.id); end if;
 p1:=other.host_id;p2:=other.partner_id;p3:=party.host_id;p4:=party.partner_id;state:=public._new_online_duo_state(p1,p2,p3,p4);
 insert into public.game_matches(player_one,player_two,player_three,player_four,team_size,mode,status,state,turn_user) values(p1,p3,p2,p4,2,party.mode,'active',state-'privatePlayers',p1) returning id into mid;
 insert into public.duo_match_players(match_id,player_id,team,seat) values(mid,p1,1,1),(mid,p2,1,2),(mid,p3,2,1),(mid,p4,2,2);
 insert into public.duo_player_states(match_id,player_id,private_state) select mid,key::uuid,value from jsonb_each(state->'privatePlayers');
 perform public.record_duo_deck_usage(mid);
 update public.duo_queue_parties set status='matched',match_id=mid where id in(party.id,other.id);
 return jsonb_build_object('status','matched','match_id',mid,'team_size',2);
end $$;
revoke all on function public.try_match_duo_queue(uuid) from public,anon;
grant execute on function public.try_match_duo_queue(uuid) to authenticated;
create or replace function public.cancel_duo_queue()
returns void language plpgsql security definer set search_path='' as $$
begin update public.duo_queue_parties set status='cancelled' where auth.uid() in(host_id,partner_id) and status in('inviting','queued'); end $$;
revoke all on function public.cancel_duo_queue() from public,anon;
grant execute on function public.cancel_duo_queue() to authenticated;

-- Keep 1v1 behavior intact; the next migration section routes team matches to the team-aware engine.
commit;

begin;

drop policy if exists "Players can read their matches" on public.game_matches;
create policy "Players can read their matches" on public.game_matches for select to authenticated
 using(auth.uid() in(player_one,player_two,player_three,player_four) or exists(select 1 from public.duo_match_players d where d.match_id=game_matches.id and d.player_id=auth.uid()));

create or replace function public._online_unit_power(p_side jsonb,p_unit jsonb,p_zones jsonb)
returns integer language plpgsql security definer set search_path='' stable as $$
declare cid text:=p_unit->>'cardId'; base_power integer; soldiers integer; faction text; bonus integer:=coalesce((p_unit->>'bonus')::integer,0); total integer;
begin
 select count(*) into soldiers from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) u where u->>'cardId'='soldado-esparta';
 base_power:=case cid when 'soldado-esparta' then 3*(2^greatest(soldiers-1,0))::integer when 'athena' then 5 when 'lobo-alfa' then 4 when 'guardiao-nordico' then 2 when 'medusa' then 4 when 'poseidon' then 7 when 'zeus' then 8 when 'hades' then 7 else 0 end;
 faction:=case when cid in('soldado-esparta','athena','grecia','medusa','poseidon','zeus','hades') then 'greek' when cid in('guardiao-nordico','mjolnir','runas-nordicas') then 'norse' else '' end;
 total:=base_power+bonus;
 if faction='greek' then total:=total+coalesce((p_side->>'greekAura')::integer,0)+case when p_zones->>'local'='grecia' then 1 else 0 end+case when p_zones->>'terrain'='campo-troia' then 1 else 0 end; end if;
 if faction='norse' then total:=total+coalesce((p_side->>'norseAura')::integer,0); end if;
 return greatest(0,total);
end $$;

create or replace function public.get_online_match(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' stable as $$
declare g public.game_matches%rowtype; my_team integer; my_seat integer; mate_name text; rival_names text; safe_state jsonb; me jsonb; team_key text; enemy_key text;
begin
 select * into g from public.game_matches where id=p_match_id and auth.uid() in(player_one,player_two,player_three,player_four);
 if not found then return null; end if;
 if coalesce(g.team_size,1)=1 then
  return (select jsonb_build_object('match',to_jsonb(g),'opponent_name',coalesce(nullif(p.nickname,''),p.display_name),'opponent_icon',p.equipped_avatar,'opponent_rating',p.rating_points,'my_team',case when g.player_one=auth.uid() then 'player_one' else 'player_two' end,'team_size',1)
    from public.profiles p where p.id=case when g.player_one=auth.uid() then g.player_two else g.player_one end);
 end if;
 select team,seat into my_team,my_seat from public.duo_match_players where match_id=g.id and player_id=auth.uid();
 team_key:=case when my_team=1 then 'player_one' else 'player_two' end;enemy_key:=case when my_team=1 then 'player_two' else 'player_one' end;
 select coalesce(nullif(p.nickname,''),p.display_name) into mate_name from public.duo_match_players d join public.profiles p on p.id=d.player_id where d.match_id=g.id and d.team=my_team and d.player_id<>auth.uid();
 select string_agg(coalesce(nullif(p.nickname,''),p.display_name),' & ' order by d.seat) into rival_names from public.duo_match_players d join public.profiles p on p.id=d.player_id where d.match_id=g.id and d.team<>my_team;
 select private_state into me from public.duo_player_states where match_id=g.id and player_id=auth.uid();
 safe_state:=g.state-'privatePlayers';
 safe_state:=jsonb_set(safe_state,'{privatePlayer}',coalesce(me,'{}'::jsonb),true);
 -- Publish only counts for the other three hands, never their card ids.
 safe_state:=jsonb_set(safe_state,'{teamHandCounts}',coalesce((select jsonb_object_agg(d.team::text||':'||d.seat::text,jsonb_build_object('hand',jsonb_array_length(coalesce(ps.private_state->'hand','[]'::jsonb)),'deck',jsonb_array_length(coalesce(ps.private_state->'deck','[]'::jsonb)))) from public.duo_match_players d join public.duo_player_states ps on ps.match_id=d.match_id and ps.player_id=d.player_id where d.match_id=g.id),'{}'::jsonb),true);
 return jsonb_build_object('match',to_jsonb(g)-'state'||jsonb_build_object('state',safe_state),'opponent_name',rival_names,'teammate_name',mate_name,'my_team',team_key,'my_seat',my_seat,'team_size',2);
end $$;
revoke all on function public.get_online_match(uuid) from public,anon;
grant execute on function public.get_online_match(uuid) to authenticated;

create or replace function public.submit_duo_game_action(p_match_id uuid,p_action jsonb)
returns public.game_matches language plpgsql security definer set search_path='' as $$
declare
 g public.game_matches%rowtype; s jsonb; order_ids jsonb; private_state jsonb; side_key text; other_key text; side jsonb; other_side jsonb;
 zones jsonb; actor uuid:=auth.uid(); team_no integer; card_id text; hand_arr jsonb; deck_arr jsonb; field_arr jsonb; unit jsonb; all_players jsonb;
 idx integer; lane integer; pass_all boolean:=true; finished boolean:=false; advanced boolean:=false; winner uuid;
 turn_idx integer; try_idx integer; next_user uuid; i integer; score_one integer; score_two integer; total_one integer; total_two integer;
begin
 select * into g from public.game_matches where id=p_match_id for update;
 if not found or g.status<>'active' or g.team_size<>2 then raise exception 'Partida de dupla indisponível.'; end if;
 if actor is null or not exists(select 1 from public.duo_match_players where match_id=g.id and player_id=actor) then raise exception 'Você não participa desta partida.'; end if;
 if g.turn_user<>actor then raise exception 'Aguarde a sua vez.'; end if;
 select team into team_no from public.duo_match_players where match_id=g.id and player_id=actor;
 side_key:=case when team_no=1 then 'player_one' else 'player_two' end;other_key:=case when team_no=1 then 'player_two' else 'player_one' end;
 s:=g.state;side:=s->side_key;other_side:=s->other_key;zones:=s->'sharedZones';select coalesce(jsonb_object_agg(player_id::text,private_state),'{}'::jsonb) into all_players from public.duo_player_states where match_id=g.id;private_state:=all_players#>array[actor::text];
 if coalesce((private_state->>'passed')::boolean,false) then raise exception 'Você já passou nesta rodada.'; end if;
 if p_action->>'type'='play' then
  if coalesce((private_state->>'skipNextTurn')::boolean,false) then raise exception 'Você perdeu este turno por um efeito.'; end if;
  if coalesce((private_state->>'playedThisTurn')::boolean,false) then raise exception 'Você já jogou neste turno.'; end if;
  card_id:=p_action->>'card_id';
  if card_id not in('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades') then raise exception 'Carta inválida.'; end if;
  hand_arr:=coalesce(private_state->'hand','[]'::jsonb);
  select ordinality::integer into idx from jsonb_array_elements_text(hand_arr) with ordinality h(value,ordinality) where h.value=card_id limit 1;
  if idx is null then raise exception 'Essa carta não está na sua mão.'; end if;
  select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into hand_arr from jsonb_array_elements(hand_arr) with ordinality h(value,ordinality) where ordinality<>idx;
  deck_arr:=coalesce(private_state->'deck','[]'::jsonb);field_arr:=coalesce(side->'field','[]'::jsonb);
  if card_id in('soldado-esparta','athena','lobo-alfa','guardiao-nordico','medusa','poseidon','zeus','hades') then
   lane:=greatest(0,least(2,coalesce((p_action->>'lane')::integer,0)));
   field_arr:=field_arr||jsonb_build_array(jsonb_build_object('cardId',card_id,'bonus',case when card_id='lobo-alfa' then 1 else 0 end,'lane',lane,'slot',jsonb_array_length(field_arr),'playedBy',actor));
   side:=jsonb_set(side,'{field}',field_arr,true);
   if card_id='athena' and jsonb_array_length(deck_arr)>0 then hand_arr:=hand_arr||jsonb_build_array(deck_arr->0);select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into deck_arr from jsonb_array_elements(deck_arr) with ordinality h(value,ordinality) where ordinality>1;end if;
   if card_id='medusa' then order_ids:=s->'turnOrder';turn_idx:=coalesce((s->>'currentTurnIndex')::integer,0);for i in 1..4 loop try_idx:=mod(turn_idx+i,4);next_user:=(order_ids->>try_idx)::uuid;if exists(select 1 from public.duo_match_players d where d.match_id=g.id and d.player_id=next_user and d.team<>team_no) then all_players:=jsonb_set(all_players,array[next_user::text,'skipNextTurn'],'true'::jsonb,true);exit;end if;end loop;end if;
   if card_id='zeus' then
    for i in 1..2 loop
     idx:=null;turn_idx:=-100000;
     for unit in select value from jsonb_array_elements(coalesce(other_side->'field','[]'::jsonb)) loop
      if public._online_unit_power(other_side,unit,zones)>turn_idx then turn_idx:=public._online_unit_power(other_side,unit,zones);idx:=(unit->>'slot')::integer;end if;
     end loop;
     if idx is not null then select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into field_arr from jsonb_array_elements(coalesce(other_side->'field','[]'::jsonb)) with ordinality h(value,ordinality) where coalesce((value->>'slot')::integer,-1)<>idx;other_side:=jsonb_set(other_side,'{field}',field_arr,true);end if;
    end loop;
   end if;
   if card_id='poseidon' then select coalesce(jsonb_agg(case when coalesce((value->>'lane')::integer,0)=0 then jsonb_set(value,'{bonus}',to_jsonb(coalesce((value->>'bonus')::integer,0)-1),true) else value end order by ordinality),'[]'::jsonb) into field_arr from jsonb_array_elements(coalesce(other_side->'field','[]'::jsonb)) with ordinality h(value,ordinality);other_side:=jsonb_set(other_side,'{field}',field_arr,true);end if;
   if card_id='hades' and jsonb_array_length(coalesce(side->'underworld','[]'::jsonb))>0 then
    hand_arr:=hand_arr||jsonb_build_array((side->'underworld')->(jsonb_array_length(side->'underworld')-1));
    side:=jsonb_set(side,'{underworld}',coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(side->'underworld') with ordinality h(value,ordinality) where ordinality<jsonb_array_length(side->'underworld')),'[]'::jsonb),true);
   end if;
  elsif card_id='mjolnir' then
   if jsonb_array_length(field_arr)=0 then raise exception 'Jogue um personagem aliado antes de usar Mjölnir.';end if;
   idx:=null;turn_idx:=-100000;for unit in select value from jsonb_array_elements(field_arr) loop if public._online_unit_power(side,unit,zones)>turn_idx then turn_idx:=public._online_unit_power(side,unit,zones);idx:=(unit->>'slot')::integer;end if;end loop;
   select coalesce(jsonb_agg(case when (value->>'slot')::integer=idx then jsonb_set(value,'{bonus}',to_jsonb(coalesce((value->>'bonus')::integer,0)+2),true) else value end order by ordinality),'[]'::jsonb) into field_arr from jsonb_array_elements(field_arr) with ordinality h(value,ordinality);side:=jsonb_set(side,'{field}',field_arr,true);
  elsif card_id='runas-nordicas' then side:=jsonb_set(side,'{norseAura}',to_jsonb(coalesce((side->>'norseAura')::integer,0)+2),true);
  elsif card_id='grecia' or card_id='campo-troia' or card_id='eclipse' then
   if card_id='grecia' then if zones->>'local' is not null then raise exception 'O espaço de Local já está ocupado.';end if;zones:=jsonb_set(zones,'{local}','"grecia"'::jsonb,true);
   elsif card_id='campo-troia' then if zones->>'terrain' is not null then raise exception 'O espaço de Terreno já está ocupado.';end if;zones:=jsonb_set(zones,'{terrain}','"campo-troia"'::jsonb,true);
   else if zones->>'climate' is not null then raise exception 'O espaço de Clima já está ocupado.';end if;zones:=jsonb_set(zones,'{climate}','"eclipse"'::jsonb,true);other_side:=jsonb_set(other_side,'{roundPenalty}',to_jsonb(coalesce((other_side->>'roundPenalty')::integer,0)+3),true);end if;
  end if;
  private_state:=jsonb_set(private_state,'{hand}',hand_arr,true);private_state:=jsonb_set(private_state,'{deck}',deck_arr,true);private_state:=jsonb_set(private_state,'{playedThisTurn}','true'::jsonb,true);
  if jsonb_array_length(hand_arr)=0 and jsonb_array_length(deck_arr)=0 then private_state:=jsonb_set(private_state,'{passed}','true'::jsonb,true);end if;
 elsif p_action->>'type'='pass' then private_state:=jsonb_set(private_state,'{passed}','true'::jsonb,true);
 elsif p_action->>'type'='skip_turn' then if not coalesce((private_state->>'skipNextTurn')::boolean,false) then raise exception 'Você não tem turno perdido.';end if;private_state:=jsonb_set(private_state,'{skipNextTurn}','false'::jsonb,true);private_state:=jsonb_set(private_state,'{playedThisTurn}','true'::jsonb,true);
 else raise exception 'Ação inválida.';end if;
 all_players:=jsonb_set(all_players,array[actor::text],private_state,true);s:=jsonb_set(s,array[side_key],side,true);s:=jsonb_set(s,array[other_key],other_side,true);s:=jsonb_set(s,'{sharedZones}',zones,true);
 for next_user in select player_id from public.duo_match_players where match_id=g.id loop private_state:=all_players#>array[next_user::text];if not coalesce((private_state->>'passed')::boolean,false) and (jsonb_array_length(coalesce(private_state->'hand','[]'::jsonb))>0 or jsonb_array_length(coalesce(private_state->'deck','[]'::jsonb))>0) then pass_all:=false;exit;end if;end loop;
 if pass_all then
  side:=s->'player_one';other_side:=s->'player_two';score_one:=public._online_side_score(side,zones);score_two:=public._online_side_score(other_side,zones);
  total_one:=coalesce((s#>>'{totalPoints,player_one}')::integer,0)+score_one;total_two:=coalesce((s#>>'{totalPoints,player_two}')::integer,0)+score_two;
  s:=jsonb_set(s,'{totalPoints,player_one}',to_jsonb(total_one),true);s:=jsonb_set(s,'{totalPoints,player_two}',to_jsonb(total_two),true);
  if score_one>score_two then side:=jsonb_set(side,'{trixx}',to_jsonb(greatest(0,(side->>'trixx')::integer-1)),true);s:=jsonb_set(s,'{roundWins,player_one}',to_jsonb(coalesce((s#>>'{roundWins,player_one}')::integer,0)+1),true);elsif score_two>score_one then other_side:=jsonb_set(other_side,'{trixx}',to_jsonb(greatest(0,(other_side->>'trixx')::integer-1)),true);s:=jsonb_set(s,'{roundWins,player_two}',to_jsonb(coalesce((s#>>'{roundWins,player_two}')::integer,0)+1),true);end if;
  foreach side_key in array array['player_one','player_two'] loop side:=s->side_key;private_state:=side;for unit in select value from jsonb_array_elements(coalesce(side->'field','[]'::jsonb)) loop private_state:=jsonb_set(private_state,'{underworld}',coalesce(private_state->'underworld','[]'::jsonb)||jsonb_build_array(unit->>'cardId'),true);end loop;private_state:=jsonb_set(private_state,'{field}','[]'::jsonb,true);private_state:=jsonb_set(private_state,'{roundPenalty}','0'::jsonb,true);private_state:=jsonb_set(private_state,'{greekAura}','0'::jsonb,true);private_state:=jsonb_set(private_state,'{norseAura}','0'::jsonb,true);s:=jsonb_set(s,array[side_key],private_state,true);end loop;
  if coalesce((s->>'round')::integer,1)<2 or (coalesce((s->>'round')::integer,1)=2 and total_one=total_two) then
   advanced:=true;s:=jsonb_set(s,'{round}',to_jsonb((s->>'round')::integer+1),true);s:=jsonb_set(s,'{currentTurnIndex}','0'::jsonb,true);s:=jsonb_set(s,'{sharedZones}',jsonb_build_object('local',null,'terrain',null,'climate',null),true);
   for next_user in select player_id from public.duo_match_players where match_id=g.id loop private_state:=all_players#>array[next_user::text];hand_arr:=coalesce(private_state->'hand','[]'::jsonb);deck_arr:=coalesce(private_state->'deck','[]'::jsonb);for i in 1..2 loop if jsonb_array_length(deck_arr)>0 then hand_arr:=hand_arr||jsonb_build_array(deck_arr->0);select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into deck_arr from jsonb_array_elements(deck_arr) with ordinality h(value,ordinality) where ordinality>1;end if;end loop;private_state:=jsonb_set(private_state,'{hand}',hand_arr,true);private_state:=jsonb_set(private_state,'{deck}',deck_arr,true);private_state:=jsonb_set(private_state,'{passed}','false'::jsonb,true);private_state:=jsonb_set(private_state,'{playedThisTurn}','false'::jsonb,true);private_state:=jsonb_set(private_state,'{turnsTaken}','0'::jsonb,true);all_players:=jsonb_set(all_players,array[next_user::text],private_state,true);end loop;
   order_ids:=s->'turnOrder';next_user:=(order_ids->>0)::uuid;
  else finished:=true;winner:=case when total_one>total_two then g.player_one when total_two>total_one then g.player_two else null end;s:=jsonb_set(s,'{finished}','true'::jsonb,true);s:=jsonb_set(s,'{winner_id}',coalesce(to_jsonb(winner),'null'::jsonb),true);s:=jsonb_set(s,'{lastRoundPoints}',jsonb_build_object('player_one',score_one,'player_two',score_two),true);next_user:=null;
  end if;
 else
  order_ids:=s->'turnOrder';turn_idx:=coalesce((s->>'currentTurnIndex')::integer,0);
  for i in 1..4 loop try_idx:=mod(turn_idx+i,4);next_user:=(order_ids->>try_idx)::uuid;private_state:=all_players#>array[next_user::text];if not coalesce((private_state->>'passed')::boolean,false) and (jsonb_array_length(coalesce(private_state->'hand','[]'::jsonb))>0 or jsonb_array_length(coalesce(private_state->'deck','[]'::jsonb))>0) then exit;end if;end loop;
  turn_idx:=try_idx;s:=jsonb_set(s,'{currentTurnIndex}',to_jsonb(turn_idx),true);private_state:=all_players#>array[next_user::text];private_state:=jsonb_set(private_state,'{playedThisTurn}','false'::jsonb,true);private_state:=jsonb_set(private_state,'{turnsTaken}',to_jsonb(coalesce((private_state->>'turnsTaken')::integer,0)+1),true);
  if mod((private_state->>'turnsTaken')::integer,2)=1 and jsonb_array_length(coalesce(private_state->'deck','[]'::jsonb))>0 then deck_arr:=private_state->'deck';hand_arr:=coalesce(private_state->'hand','[]'::jsonb)||jsonb_build_array(deck_arr->0);select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into deck_arr from jsonb_array_elements(deck_arr) with ordinality h(value,ordinality) where ordinality>1;private_state:=jsonb_set(private_state,'{hand}',hand_arr,true);private_state:=jsonb_set(private_state,'{deck}',deck_arr,true);end if;
  all_players:=jsonb_set(all_players,array[next_user::text],private_state,true);
 end if;
 update public.duo_player_states ps set private_state=all_players->(ps.player_id::text) where ps.match_id=g.id;
 update public.game_matches set state=s,turn_user=next_user,status=case when finished then 'completed' else 'active' end,winner_id=winner,finished_at=case when finished then now() else null end where id=g.id returning * into g;
 if finished and winner is not null then
  update public.profiles set wins=wins+1,rating_points=rating_points+case when g.mode='ranked' and winner is not null then 25 else 0 end where id in(select player_id from public.duo_match_players where match_id=g.id and team=case when winner=g.player_one then 1 else 2 end);
  update public.profiles set losses=losses+1,rating_points=greatest(0,rating_points-case when g.mode='ranked' and winner is not null then 25 else 0 end) where id in(select player_id from public.duo_match_players where match_id=g.id and team<>case when winner=g.player_one then 1 else 2 end);
 end if;
 return g;
end $$;

alter function public.submit_game_action(uuid,jsonb) rename to _submit_game_action_1v1;
create or replace function public.submit_game_action(p_match_id uuid,p_action jsonb)
returns public.game_matches language plpgsql security definer set search_path='' as $$
declare g public.game_matches%rowtype;
begin
 select * into g from public.game_matches where id=p_match_id;
 if not found then raise exception 'Partida não encontrada.';end if;
 if coalesce(g.team_size,1)=2 then return public.submit_duo_game_action(p_match_id,p_action);end if;
 return public._submit_game_action_1v1(p_match_id,p_action);
end $$;
revoke all on function public.submit_game_action(uuid,jsonb) from public,anon;
grant execute on function public.submit_game_action(uuid,jsonb) to authenticated;
revoke all on function public.submit_duo_game_action(uuid,jsonb) from public,anon;
grant execute on function public.submit_duo_game_action(uuid,jsonb) to authenticated;
revoke all on function public._submit_game_action_1v1(uuid,jsonb) from public,anon,authenticated;

alter function public.join_matchmaking(text) rename to _join_matchmaking_solo;
create or replace function public.join_matchmaking(p_mode text default 'normal')
returns table(queue_status text,match_id uuid,opponent_id uuid) language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.duo_queue_parties where status in('inviting','queued') and auth.uid() in(host_id,partner_id)) then raise exception 'Cancele primeiro sua fila de dupla para entrar solo.';end if;
 return query select * from public._join_matchmaking_solo(p_mode);
end $$;
revoke all on function public.join_matchmaking(text) from public,anon;
grant execute on function public.join_matchmaking(text) to authenticated;
revoke all on function public._join_matchmaking_solo(text) from public,anon,authenticated;

create or replace function public.expire_game_turns()
returns integer language plpgsql security definer set search_path='' as $$
declare g record; side_key text; action_name text; expired integer:=0; personal jsonb;
begin
 for g in select id,player_one,player_two,player_three,player_four,team_size,turn_user,state from public.game_matches where status='active' and turn_user is not null and turn_deadline<=clock_timestamp() order by turn_deadline for update skip locked loop
  if coalesce(g.team_size,1)=2 then
   select private_state into personal from public.duo_player_states where match_id=g.id and player_id=g.turn_user;
   action_name:=case when coalesce((personal->>'skipNextTurn')::boolean,false) then 'skip_turn' else 'pass' end;
  else
   side_key:=case when g.turn_user=g.player_one then 'player_one' else 'player_two' end;
   action_name:=case when coalesce((g.state#>>array[side_key,'skipNextTurn'])::boolean,false) then 'skip_turn' else 'pass' end;
  end if;
  begin
   perform set_config('request.jwt.claim.sub',g.turn_user::text,true);
   perform public.submit_game_action(g.id,jsonb_build_object('type',action_name));
   expired:=expired+1;
  exception when others then null;
  end;
 end loop;
 return expired;
end $$;
revoke all on function public.expire_game_turns() from public,anon;
grant execute on function public.expire_game_turns() to authenticated;

create or replace function public.reward_duo_completed_match()
returns trigger language plpgsql security definer set search_path='' as $$
declare one_name text;two_name text;one_score integer;two_score integer;team_one_won boolean;team_two_won boolean;reward_xp integer;reward_coins integer;row_player record;inserted integer;
begin
 if new.team_size<>2 or new.status<>'completed' or old.status='completed' then return new;end if;
 select string_agg(coalesce(nullif(p.nickname,''),p.display_name),' & ' order by d.seat) into one_name from public.duo_match_players d join public.profiles p on p.id=d.player_id where d.match_id=new.id and d.team=1;
 select string_agg(coalesce(nullif(p.nickname,''),p.display_name),' & ' order by d.seat) into two_name from public.duo_match_players d join public.profiles p on p.id=d.player_id where d.match_id=new.id and d.team=2;
 one_score:=coalesce((new.state#>>'{totalPoints,player_one}')::integer,0);two_score:=coalesce((new.state#>>'{totalPoints,player_two}')::integer,0);team_one_won:=new.winner_id=new.player_one;team_two_won:=new.winner_id=new.player_two;
 update public.match_history set opponent_name=case when player_id in(select player_id from public.duo_match_players where match_id=new.id and team=1) then two_name else one_name end,
  outcome=case when new.winner_id is null then 'draw' when (player_id in(select player_id from public.duo_match_players where match_id=new.id and team=1) and team_one_won) or (player_id in(select player_id from public.duo_match_players where match_id=new.id and team=2) and team_two_won) then 'victory' else 'defeat' end,
  player_points=case when player_id in(select player_id from public.duo_match_players where match_id=new.id and team=1) then one_score else two_score end,
  opponent_points=case when player_id in(select player_id from public.duo_match_players where match_id=new.id and team=1) then two_score else one_score end
 where match_id=new.id;
 for row_player in select d.player_id,d.team from public.duo_match_players d where d.match_id=new.id and d.player_id not in(new.player_one,new.player_two) loop
  if new.winner_id is null then reward_xp:=15;reward_coins:=10;
  elsif (row_player.team=1 and team_one_won) or (row_player.team=2 and team_two_won) then reward_xp:=30;reward_coins:=20;
  else reward_xp:=20;reward_coins:=10;end if;
  insert into public.match_history(match_id,player_id,opponent_name,mode,outcome,player_points,opponent_points,xp_earned,coins_earned)
  values(new.id,row_player.player_id,case when row_player.team=1 then two_name else one_name end,new.mode,case when new.winner_id is null then 'draw' when (row_player.team=1 and team_one_won) or (row_player.team=2 and team_two_won) then 'victory' else 'defeat' end,case when row_player.team=1 then one_score else two_score end,case when row_player.team=1 then two_score else one_score end,reward_xp,reward_coins)
  on conflict(match_id,player_id) do nothing;
  get diagnostics inserted=row_count;
  if inserted>0 then update public.profiles set xp=xp+reward_xp,mythic_coins=mythic_coins+reward_coins where id=row_player.player_id;end if;
 end loop;
 return new;
end $$;
revoke all on function public.reward_duo_completed_match() from public,anon,authenticated;
drop trigger if exists reward_duo_completed_game_match on public.game_matches;
create trigger reward_duo_completed_game_match after update of status on public.game_matches for each row execute function public.reward_duo_completed_match();

do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='duo_queue_parties') then alter publication supabase_realtime add table public.duo_queue_parties; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='duo_match_players') then alter publication supabase_realtime add table public.duo_match_players; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='duo_player_states') then alter publication supabase_realtime add table public.duo_player_states; end if;
 end if;
end $$;

commit;
