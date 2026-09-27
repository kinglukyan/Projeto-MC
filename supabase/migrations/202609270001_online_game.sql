-- Mythic Clash: auth-linked profiles, friends, private chat, invitations and queues.
-- Apply in the Supabase SQL editor or with `supabase db push`.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Lenda' check (char_length(display_name) between 2 and 24),
  friend_code text not null unique,
  avatar_url text,
  rating_points integer not null default 1000 check (rating_points >= 0),
  wins integer not null default 0 check (wins >= 0),
  losses integer not null default 0 check (losses >= 0),
  settings jsonb not null default '{"music":true,"effects":true,"notifications":true}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare generated_code text;
begin
  loop
    generated_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists(select 1 from public.profiles where friend_code = generated_code);
  end loop;
  insert into public.profiles(id, display_name, friend_code)
  values(new.id, coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'), ''), 'Lenda'), generated_code);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile after insert on auth.users
for each row execute procedure public.create_profile_for_new_user();

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  requested_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(user_a < user_b),
  check(requested_by in (user_a,user_b)),
  unique(user_a,user_b)
);

create table if not exists public.player_decks (
  player_id uuid primary key references public.profiles(id) on delete cascade,
  card_counts jsonb not null default '{"soldado-esparta":3,"athena":2,"lobo-alfa":2,"guardiao-nordico":2,"mjolnir":1,"runas-nordicas":1,"grecia":1,"eclipse":2}'::jsonb,
  updated_at timestamptz not null default now(),
  check(jsonb_typeof(card_counts)='object')
);

create table if not exists public.friend_messages (
  id uuid primary key default gen_random_uuid(),
  friendship_id uuid not null references public.friendships(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check(char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists friend_messages_thread_created on public.friend_messages(friendship_id, created_at desc);

create table if not exists public.game_matches (
  id uuid primary key default gen_random_uuid(),
  player_one uuid not null references public.profiles(id),
  player_two uuid not null references public.profiles(id),
  mode text not null check(mode in ('normal','ranked','friend')),
  status text not null default 'active' check(status in ('active','completed','abandoned')),
  state jsonb not null default '{}'::jsonb,
  turn_user uuid references public.profiles(id),
  winner_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  finished_at timestamptz,
  check(player_one <> player_two),
  check(turn_user is null or turn_user in (player_one,player_two)),
  check(winner_id is null or winner_id in (player_one,player_two))
);

create table if not exists public.game_invites (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  host_id uuid not null references public.profiles(id) on delete cascade,
  invited_user_id uuid references public.profiles(id) on delete cascade,
  guest_id uuid references public.profiles(id) on delete set null,
  mode text not null default 'friend' check(mode in ('normal','ranked','friend')),
  status text not null default 'waiting' check(status in ('waiting','accepted','declined','expired','playing','completed')),
  match_id uuid references public.game_matches(id) on delete set null,
  expires_at timestamptz not null default now() + interval '15 minutes',
  created_at timestamptz not null default now(),
  check(guest_id is null or guest_id <> host_id)
);
create index if not exists game_invites_waiting_code on public.game_invites(code) where status='waiting';

create table if not exists public.matchmaking_queue (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  mode text not null check(mode in ('normal','ranked')),
  rating_points integer not null default 1000,
  status text not null default 'waiting' check(status in ('waiting','matched')),
  match_id uuid references public.game_matches(id) on delete set null,
  joined_at timestamptz not null default now()
);
create index if not exists matchmaking_waiting_mode on public.matchmaking_queue(mode,joined_at) where status='waiting';

alter table public.profiles enable row level security;
alter table public.player_decks enable row level security;
alter table public.friendships enable row level security;
alter table public.friend_messages enable row level security;
alter table public.game_matches enable row level security;
alter table public.game_invites enable row level security;
alter table public.matchmaking_queue enable row level security;

drop policy if exists "Profiles can be viewed by signed-in players" on public.profiles;
create policy "Players can view their own private profile row" on public.profiles for select to authenticated using (id=auth.uid());
drop policy if exists "Players can update their own public profile" on public.profiles;
create policy "Players can update their own public profile" on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());
grant select on public.profiles to authenticated;
grant update(display_name,avatar_url,settings) on public.profiles to authenticated;

drop policy if exists "Players can read their own deck" on public.player_decks;
create policy "Players can read their own deck" on public.player_decks for select to authenticated using (player_id=auth.uid());
drop policy if exists "Players can save their own deck" on public.player_decks;
create policy "Players can save their own deck" on public.player_decks for insert to authenticated with check (player_id=auth.uid());
drop policy if exists "Players can update their own deck" on public.player_decks;
create policy "Players can update their own deck" on public.player_decks for update to authenticated using (player_id=auth.uid()) with check (player_id=auth.uid());
grant select,insert,update on public.player_decks to authenticated;

drop policy if exists "Players can view their friendships" on public.friendships;
create policy "Players can view their friendships" on public.friendships for select to authenticated using (auth.uid() in (user_a,user_b));
grant select on public.friendships to authenticated;

drop policy if exists "Friends can read their own chat" on public.friend_messages;
create policy "Friends can read their own chat" on public.friend_messages for select to authenticated
using (exists(select 1 from public.friendships f where f.id=friendship_id and f.status='accepted' and auth.uid() in (f.user_a,f.user_b)));
drop policy if exists "Friends can send chat messages" on public.friend_messages;
create policy "Friends can send chat messages" on public.friend_messages for insert to authenticated
with check(sender_id=auth.uid() and exists(select 1 from public.friendships f where f.id=friendship_id and f.status='accepted' and auth.uid() in (f.user_a,f.user_b)));
grant select,insert on public.friend_messages to authenticated;

drop policy if exists "Players can read their matches" on public.game_matches;
create policy "Players can read their matches" on public.game_matches for select to authenticated using (auth.uid() in (player_one,player_two));
grant select on public.game_matches to authenticated;
-- Match state changes are reserved for trusted server functions, never direct browser updates.

create or replace function public.get_online_match(p_match_id uuid)
returns jsonb language sql security definer set search_path = '' stable as $$
  select jsonb_build_object('match',to_jsonb(g),'opponent_name',p.display_name)
  from public.game_matches g
  join public.profiles p on p.id=case when g.player_one=auth.uid() then g.player_two else g.player_one end
  where g.id=p_match_id and auth.uid() in (g.player_one,g.player_two)
  limit 1;
$$;
revoke all on function public.get_online_match(uuid) from public,anon;
grant execute on function public.get_online_match(uuid) to authenticated;

drop policy if exists "Players can read their invitations" on public.game_invites;
create policy "Players can read their invitations" on public.game_invites for select to authenticated using (auth.uid() in (host_id,invited_user_id,guest_id));
grant select on public.game_invites to authenticated;

drop policy if exists "Players can read their queue entries" on public.matchmaking_queue;
create policy "Players can read their queue entries" on public.matchmaking_queue for select to authenticated using (auth.uid()=user_id);
drop policy if exists "Players can leave their queue" on public.matchmaking_queue;
create policy "Players can leave their queue" on public.matchmaking_queue for delete to authenticated using (auth.uid()=user_id);
grant select,delete on public.matchmaking_queue to authenticated;

create or replace function public.find_player_by_friend_code(p_code text)
returns table(id uuid, display_name text, friend_code text, rating_points integer)
language sql security definer set search_path = '' stable as $$
  select p.id,p.display_name,p.friend_code,p.rating_points
  from public.profiles p
  where auth.uid() is not null and p.friend_code=upper(trim(p_code))
  limit 1;
$$;
revoke all on function public.find_player_by_friend_code(text) from public, anon;
grant execute on function public.find_player_by_friend_code(text) to authenticated;

create or replace function public.request_friend(p_friend_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare current_user_id uuid := auth.uid(); target_id uuid; a uuid; b uuid; existing public.friendships%rowtype;
begin
  if current_user_id is null then raise exception 'Faça login para adicionar amigos.'; end if;
  select id into target_id from public.profiles where friend_code=upper(trim(p_friend_code));
  if target_id is null then raise exception 'Código de amigo não encontrado.'; end if;
  if target_id=current_user_id then raise exception 'Você não pode adicionar a si mesmo.'; end if;
  a:=least(current_user_id,target_id); b:=greatest(current_user_id,target_id);
  select * into existing from public.friendships where user_a=a and user_b=b for update;
  if found then
    if existing.status='accepted' then return jsonb_build_object('status','friends','friendship_id',existing.id); end if;
    if existing.requested_by<>current_user_id then
      update public.friendships set status='accepted',updated_at=now() where id=existing.id;
      return jsonb_build_object('status','accepted','friendship_id',existing.id);
    end if;
    return jsonb_build_object('status','pending','friendship_id',existing.id);
  end if;
  insert into public.friendships(user_a,user_b,requested_by) values(a,b,current_user_id) returning * into existing;
  return jsonb_build_object('status','pending','friendship_id',existing.id);
end;
$$;
revoke all on function public.request_friend(text) from public, anon;
grant execute on function public.request_friend(text) to authenticated;

create or replace function public.respond_friend_request(p_friendship_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_accept then
    update public.friendships set status='accepted',updated_at=now()
      where id=p_friendship_id and status='pending' and requested_by<>auth.uid() and auth.uid() in (user_a,user_b);
  else
    delete from public.friendships
      where id=p_friendship_id and status='pending' and requested_by<>auth.uid() and auth.uid() in (user_a,user_b);
  end if;
  if not found then raise exception 'Solicitação não encontrada ou já respondida.'; end if;
end;
$$;
revoke all on function public.respond_friend_request(uuid,boolean) from public, anon;
grant execute on function public.respond_friend_request(uuid,boolean) to authenticated;

create or replace function public.list_my_friends()
returns table(friendship_id uuid, friend_id uuid, display_name text, friend_code text, rating_points integer, request_status text, incoming boolean)
language sql security definer set search_path = '' stable as $$
  select f.id,p.id,p.display_name,p.friend_code,p.rating_points,f.status,(f.status='pending' and f.requested_by<>auth.uid())
  from public.friendships f
  join public.profiles p on p.id=case when f.user_a=auth.uid() then f.user_b else f.user_a end
  where auth.uid() in (f.user_a,f.user_b)
  order by (f.status='pending' and f.requested_by<>auth.uid()) desc,p.display_name;
$$;
revoke all on function public.list_my_friends() from public, anon;
grant execute on function public.list_my_friends() to authenticated;

create or replace function public._new_online_game_state(p_one uuid,p_two uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  counts jsonb;
  shuffled text[];
  one_state jsonb;
  two_state jsonb;
begin
  for counts in select coalesce(d.card_counts,'{"soldado-esparta":3,"athena":2,"lobo-alfa":2,"guardiao-nordico":2,"mjolnir":1,"runas-nordicas":1,"grecia":1,"eclipse":2}'::jsonb)
    from (select 1) seed left join public.player_decks d on d.player_id=p_one
  loop
    if (select coalesce(sum(value::integer),0) from jsonb_each_text(counts)) not between 12 and 20 then
      raise exception 'Os dois jogadores precisam de um baralho entre 12 e 20 cartas.';
    end if;
    if exists(select 1 from jsonb_each_text(counts) where key not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse') or value !~ '^[0-3]$') then
      raise exception 'O baralho contém quantidade ou carta inválida.';
    end if;
    select array_agg(card_id order by random()) into shuffled
    from jsonb_each_text(counts) c cross join lateral generate_series(1,c.value::integer) copies
    cross join lateral (select c.key as card_id) alias_card;
    one_state:=jsonb_build_object('hand',to_jsonb(shuffled[1:5]),'deck',to_jsonb(shuffled[6:array_length(shuffled,1)]),'field','[]'::jsonb,'underworld','[]'::jsonb,'trixx',2,'roundPenalty',0,'turnsTaken',1,'passed',false,'playedThisTurn',false,'greekAura',0,'norseAura',0);
  end loop;
  select coalesce(d.card_counts,'{"soldado-esparta":3,"athena":2,"lobo-alfa":2,"guardiao-nordico":2,"mjolnir":1,"runas-nordicas":1,"grecia":1,"eclipse":2}'::jsonb) into counts
    from (select 1) seed left join public.player_decks d on d.player_id=p_two;
  if (select coalesce(sum(value::integer),0) from jsonb_each_text(counts)) not between 12 and 20 then raise exception 'O baralho do segundo jogador precisa ter entre 12 e 20 cartas.'; end if;
  if exists(select 1 from jsonb_each_text(counts) where key not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse') or value !~ '^[0-3]$') then raise exception 'O segundo baralho contém quantidade ou carta inválida.'; end if;
  select array_agg(card_id order by random()) into shuffled
    from jsonb_each_text(counts) c cross join lateral generate_series(1,c.value::integer) copies
    cross join lateral (select c.key as card_id) alias_card;
  two_state:=jsonb_build_object('hand',to_jsonb(shuffled[1:4]),'deck',to_jsonb(shuffled[5:array_length(shuffled,1)]),'field','[]'::jsonb,'underworld','[]'::jsonb,'trixx',2,'roundPenalty',0,'turnsTaken',0,'passed',false,'playedThisTurn',false,'greekAura',0,'norseAura',0);
  return jsonb_build_object('player_one',one_state,'player_two',two_state,'round',1,'roundCycles',0,'current_turn',p_one,'sharedZones',jsonb_build_object('local',null,'terrain',null,'climate',null),'totalPoints',jsonb_build_object('player_one',0,'player_two',0),'roundWins',jsonb_build_object('player_one',0,'player_two',0),'finished',false,'winner_id',null,'log',jsonb_build_array('A batalha online começou.'));
end;
$$;
revoke all on function public._new_online_game_state(uuid,uuid) from public,anon,authenticated;

create or replace function public._online_unit_power(p_side jsonb,p_unit jsonb,p_zones jsonb)
returns integer language plpgsql security definer set search_path = '' stable as $$
declare cid text:=p_unit->>'cardId'; base_power integer; soldiers integer; faction text; bonus integer:=coalesce((p_unit->>'bonus')::integer,0); total integer;
begin
  select count(*) into soldiers from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) u where u->>'cardId'='soldado-esparta';
  base_power:=case cid when 'soldado-esparta' then 3*(2^greatest(soldiers-1,0))::integer when 'athena' then 5 when 'lobo-alfa' then 4 when 'guardiao-nordico' then 2 else 0 end;
  faction:=case when cid in ('soldado-esparta','athena','grecia') then 'greek' when cid in ('guardiao-nordico','mjolnir','runas-nordicas') then 'norse' else '' end;
  total:=base_power+bonus;
  if faction='greek' then total:=total+coalesce((p_side->>'greekAura')::integer,0)+case when p_zones->>'local'='grecia' then 1 else 0 end; end if;
  if faction='norse' then total:=total+coalesce((p_side->>'norseAura')::integer,0); end if;
  return greatest(0,total);
end;
$$;
revoke all on function public._online_unit_power(jsonb,jsonb,jsonb) from public,anon,authenticated;

create or replace function public._online_side_score(p_side jsonb,p_zones jsonb)
returns integer language plpgsql security definer set search_path = '' stable as $$
declare unit jsonb; result integer:=0;
begin
  for unit in select value from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) loop
    result:=result+public._online_unit_power(p_side,unit,p_zones);
  end loop;
  return greatest(0,result-coalesce((p_side->>'roundPenalty')::integer,0));
end;
$$;
revoke all on function public._online_side_score(jsonb,jsonb) from public,anon,authenticated;

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
    if coalesce((side->>'playedThisTurn')::boolean,false) then raise exception 'Você já jogou uma carta neste turno.'; end if;
    card_id:=p_action->>'card_id';
    if card_id not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse') then raise exception 'Carta inválida.'; end if;
    hand_array:=coalesce(side->'hand','[]'::jsonb);
    select ordinality::integer into card_idx from jsonb_array_elements_text(hand_array) with ordinality h(value,ordinality) where h.value=card_id limit 1;
    if card_idx is null then raise exception 'Essa carta não está na sua mão.'; end if;
    select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into hand_array from jsonb_array_elements(hand_array) with ordinality e(value,ordinality) where ordinality<>card_idx;
    field_array:=coalesce(side->'field','[]'::jsonb); deck_array:=coalesce(side->'deck','[]'::jsonb);
    if card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico') then
      lane:=greatest(0,least(2,coalesce((p_action->>'lane')::integer,0)));
      unit:=jsonb_build_object('cardId',card_id,'bonus',case when card_id='lobo-alfa' then 1 else 0 end,'lane',lane,'slot',jsonb_array_length(field_array));
      field_array:=field_array||jsonb_build_array(unit);
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
    end if;
    side:=jsonb_set(side,'{hand}',hand_array,true);side:=jsonb_set(side,'{field}',field_array,true);side:=jsonb_set(side,'{deck}',deck_array,true);
    side:=jsonb_set(side,'{playedThisTurn}','true'::jsonb,true);
    if jsonb_array_length(hand_array)=0 and jsonb_array_length(deck_array)=0 then side:=jsonb_set(side,'{passed}','true'::jsonb,true);end if;
  elsif action_type='pass' then
    side:=jsonb_set(side,'{passed}','true'::jsonb,true);
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
revoke all on function public.submit_game_action(uuid,jsonb) from public,anon;
grant execute on function public.submit_game_action(uuid,jsonb) to authenticated;

create or replace function public.create_game_invite(p_mode text default 'friend',p_invited_friend_code text default null)
returns table(invite_id uuid,invite_code text,invite_status text)
language plpgsql security definer set search_path = '' as $$
declare uid uuid:=auth.uid(); friend_id uuid; generated_code text; invite_row public.game_invites%rowtype;
begin
  if uid is null then raise exception 'Faça login para desafiar alguém.'; end if;
  if p_mode not in ('normal','ranked','friend') then raise exception 'Modo inválido.'; end if;
  if p_invited_friend_code is not null then
    select id into friend_id from public.profiles where friend_code=upper(trim(p_invited_friend_code));
    if friend_id is null or friend_id=uid then raise exception 'Código de amigo inválido.'; end if;
    if not exists(select 1 from public.friendships where status='accepted' and uid in (user_a,user_b) and friend_id in (user_a,user_b)) then raise exception 'Vocês precisam ser amigos para enviar este convite.'; end if;
  end if;
  loop
    generated_code:=upper(substr(encode(gen_random_bytes(5),'hex'),1,8));
    exit when not exists(select 1 from public.game_invites where code=generated_code and status='waiting');
  end loop;
  insert into public.game_invites(code,host_id,invited_user_id,mode) values(generated_code,uid,friend_id,p_mode) returning * into invite_row;
  return query select invite_row.id,invite_row.code,invite_row.status;
end;
$$;
revoke all on function public.create_game_invite(text,text) from public, anon;
grant execute on function public.create_game_invite(text,text) to authenticated;

create or replace function public.join_game_invite(p_code text)
returns table(match_id uuid,mode text,opponent_id uuid)
language plpgsql security definer set search_path = '' as $$
declare uid uuid:=auth.uid(); invite public.game_invites%rowtype; new_match uuid;
begin
  if uid is null then raise exception 'Faça login para entrar no desafio.'; end if;
  select * into invite from public.game_invites where code=upper(trim(p_code)) and status='waiting' and expires_at>now() for update;
  if not found then raise exception 'Código inválido, expirado ou já utilizado.'; end if;
  if invite.host_id=uid then raise exception 'Envie o código para outra pessoa entrar.'; end if;
  if invite.invited_user_id is not null and invite.invited_user_id<>uid then raise exception 'Este convite foi enviado a outro jogador.'; end if;
  insert into public.game_matches(player_one,player_two,mode,turn_user,state)
  values(invite.host_id,uid,invite.mode,invite.host_id,public._new_online_game_state(invite.host_id,uid)) returning id into new_match;
  update public.game_invites set guest_id=uid,status='accepted',match_id=new_match where id=invite.id;
  return query select new_match,invite.mode,invite.host_id;
end;
$$;
revoke all on function public.join_game_invite(text) from public, anon;
grant execute on function public.join_game_invite(text) to authenticated;

create or replace function public.join_matchmaking(p_mode text default 'normal')
returns table(queue_status text,match_id uuid,opponent_id uuid)
language plpgsql security definer set search_path = '' as $$
declare uid uuid:=auth.uid(); candidate public.matchmaking_queue%rowtype; new_match uuid; my_rating integer;
begin
  if uid is null then raise exception 'Faça login para procurar uma partida.'; end if;
  if p_mode not in ('normal','ranked') then raise exception 'Modo de fila inválido.'; end if;
  delete from public.matchmaking_queue where user_id=uid;
  select rating_points into my_rating from public.profiles where id=uid;
  select * into candidate from public.matchmaking_queue q
    where q.mode=p_mode and q.status='waiting' and q.user_id<>uid
      and (p_mode<>'ranked' or abs(q.rating_points-my_rating)<=250)
    order by q.joined_at limit 1 for update skip locked;
  if found then
    insert into public.game_matches(player_one,player_two,mode,turn_user,state)
      values(candidate.user_id,uid,p_mode,candidate.user_id,public._new_online_game_state(candidate.user_id,uid)) returning id into new_match;
    update public.matchmaking_queue set status='matched',match_id=new_match where user_id=candidate.user_id;
    insert into public.matchmaking_queue(user_id,mode,rating_points,status,match_id)
      values(uid,p_mode,coalesce(my_rating,1000),'matched',new_match);
    return query select 'matched'::text,new_match,candidate.user_id;
  else
    insert into public.matchmaking_queue(user_id,mode,rating_points,status,match_id)
      values(uid,p_mode,coalesce(my_rating,1000),'waiting',null);
    return query select 'waiting'::text,null::uuid,null::uuid;
  end if;
end;
$$;
revoke all on function public.join_matchmaking(text) from public, anon;
grant execute on function public.join_matchmaking(text) to authenticated;

create or replace function public.cancel_matchmaking()
returns void language sql security definer set search_path = '' as $$
  delete from public.matchmaking_queue where user_id=auth.uid() and status='waiting';
$$;
revoke all on function public.cancel_matchmaking() from public, anon;
grant execute on function public.cancel_matchmaking() to authenticated;

do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='friend_messages') then alter publication supabase_realtime add table public.friend_messages; end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='game_invites') then alter publication supabase_realtime add table public.game_invites; end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='game_matches') then alter publication supabase_realtime add table public.game_matches; end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='matchmaking_queue') then alter publication supabase_realtime add table public.matchmaking_queue; end if;
  end if;
end $$;
