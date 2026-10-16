-- Server-side rules for tie-breaks, mission chapters, guild activity,
-- tournament brackets, sandbox invitations and card gifting.
begin;

create table if not exists public.game_tiebreaks (
  match_id uuid primary key references public.game_matches(id) on delete cascade,
  player_one_card text,
  player_two_card text,
  player_one_used jsonb not null default '[]'::jsonb,
  player_two_used jsonb not null default '[]'::jsonb,
  player_one_power integer,
  player_two_power integer,
  round integer not null default 1,
  resolved_winner uuid references public.profiles(id),
  resolved boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(player_one_used)='array' and jsonb_typeof(player_two_used)='array')
);
alter table public.game_tiebreaks enable row level security;
revoke all on public.game_tiebreaks from public,anon,authenticated;

create or replace function public.get_tiebreak_state(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare g public.game_matches%rowtype; tb public.game_tiebreaks%rowtype; sk text; side jsonb; used jsonb; options jsonb;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into g from public.game_matches where id=p_match_id and auth.uid() in(player_one,player_two);
  if not found or g.status<>'completed' or g.winner_id is not null then raise exception 'this match has no tie-break'; end if;
  select * into tb from public.game_tiebreaks where match_id=p_match_id;
  if not found then
    insert into public.game_tiebreaks(match_id) values(p_match_id) on conflict do nothing;
    select * into tb from public.game_tiebreaks where match_id=p_match_id;
  end if;
  sk:=case when auth.uid()=g.player_one then 'player_one' else 'player_two' end;
  side:=g.state->sk;used:=case when sk='player_one' then tb.player_one_used else tb.player_two_used end;
  select coalesce(jsonb_agg(jsonb_build_object('id',q.card_id,'power',q.power) order by q.card_id),'[]'::jsonb) into options
  from (
    select distinct e.card_id,
      case e.card_id when 'soldado-esparta' then 3 when 'athena' then 5 when 'lobo-alfa' then 4 when 'guardiao-nordico' then 2 when 'medusa' then 4 end as power
    from jsonb_array_elements_text(coalesce(side->'hand','[]'::jsonb)||coalesce(side->'deck','[]'::jsonb)||coalesce(side->'underworld','[]'::jsonb)) e(card_id)
    where e.card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','medusa')
      and (select count(*) from jsonb_array_elements_text(used) u(value) where u.value=e.card_id)<
          (select count(*) from jsonb_array_elements_text(coalesce(side->'hand','[]'::jsonb)||coalesce(side->'deck','[]'::jsonb)||coalesce(side->'underworld','[]'::jsonb)) available(value) where available.value=e.card_id)
  ) q;
  return jsonb_build_object('round',tb.round,'options',options,
    'opponent_ready',case when sk='player_one' then tb.player_two_card is not null else tb.player_one_card is not null end,
    'my_card',case when sk='player_one' then tb.player_one_card else tb.player_two_card end,
    'resolved',tb.resolved,
    'winner_id',tb.resolved_winner,
    'cards',case when tb.resolved or (tb.player_one_card is not null and tb.player_two_card is not null)
      then jsonb_build_object('player_one',tb.player_one_card,'player_two',tb.player_two_card,'player_one_power',tb.player_one_power,'player_two_power',tb.player_two_power)
      else null end);
end $$;

create or replace function public.submit_tiebreak_card(p_match_id uuid,p_card_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare g public.game_matches%rowtype; tb public.game_tiebreaks%rowtype; sk text; side jsonb; used jsonb; already text; power integer; winner uuid; next_options jsonb;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into g from public.game_matches where id=p_match_id for update;
  if not found or g.status<>'completed' or g.winner_id is not null or auth.uid() not in(g.player_one,g.player_two) then raise exception 'this match has no available tie-break'; end if;
  insert into public.game_tiebreaks(match_id) values(p_match_id) on conflict do nothing;
  select * into tb from public.game_tiebreaks where match_id=p_match_id for update;
  if tb.resolved then raise exception 'tie-break already resolved'; end if;
  sk:=case when auth.uid()=g.player_one then 'player_one' else 'player_two' end;
  side:=g.state->sk;used:=case when sk='player_one' then tb.player_one_used else tb.player_two_used end;
  already:=case when sk='player_one' then tb.player_one_card else tb.player_two_card end;
  if already is not null then raise exception 'you already chose a card for this draw'; end if;
  if p_card_id not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','medusa')
    or not ((coalesce(side->'hand','[]'::jsonb)||coalesce(side->'deck','[]'::jsonb)||coalesce(side->'underworld','[]'::jsonb)) ? p_card_id)
    or (select count(*) from jsonb_array_elements_text(used) u(value) where u.value=p_card_id)>=
       (select count(*) from jsonb_array_elements_text(coalesce(side->'hand','[]'::jsonb)||coalesce(side->'deck','[]'::jsonb)||coalesce(side->'underworld','[]'::jsonb)) available(value) where available.value=p_card_id)
  then raise exception 'card is not available for this draw'; end if;
  power:=case p_card_id when 'soldado-esparta' then 3 when 'athena' then 5 when 'lobo-alfa' then 4 when 'guardiao-nordico' then 2 when 'medusa' then 4 end;
  if sk='player_one' then update public.game_tiebreaks set player_one_card=p_card_id,player_one_power=power,updated_at=now() where match_id=p_match_id;
  else update public.game_tiebreaks set player_two_card=p_card_id,player_two_power=power,updated_at=now() where match_id=p_match_id; end if;
  select * into tb from public.game_tiebreaks where match_id=p_match_id for update;
  if tb.player_one_card is not null and tb.player_two_card is not null then
    if tb.player_one_power<tb.player_two_power then winner:=g.player_one;
    elsif tb.player_two_power<tb.player_one_power then winner:=g.player_two;
    else
      if tb.round>=5 then
        update public.game_tiebreaks set resolved=true,updated_at=now() where match_id=p_match_id returning * into tb;
        return jsonb_build_object('resolved',true,'round',tb.round,'winner_id',null,'cards',jsonb_build_object('player_one',tb.player_one_card,'player_two',tb.player_two_card,'player_one_power',tb.player_one_power,'player_two_power',tb.player_two_power));
      end if;
      update public.game_tiebreaks set player_one_used=player_one_used||to_jsonb(player_one_card),player_two_used=player_two_used||to_jsonb(player_two_card),player_one_card=null,player_two_card=null,player_one_power=null,player_two_power=null,round=round+1,updated_at=now() where match_id=p_match_id returning * into tb;
      return jsonb_build_object('resolved',false,'round',tb.round,'message','Empate na puxada. Cada invocador precisa escolher outra carta.');
    end if;
    update public.game_tiebreaks set resolved_winner=winner,resolved=true,updated_at=now() where match_id=p_match_id;
    update public.game_matches set winner_id=winner,state=jsonb_set(state,'{winner_id}',to_jsonb(winner),true) where id=p_match_id;
    update public.match_history set outcome=case when player_id=winner then 'victory' else 'defeat' end,
      xp_earned=case when player_id=winner then 30 else 20 end,
      coins_earned=case when player_id=winner then 20 else 10 end
      where match_id=p_match_id and outcome='draw';
    update public.profiles set wins=wins+1,xp=xp+15,mythic_coins=mythic_coins+10,
      rating_points=rating_points+case when g.mode='ranked' then 25 else 0 end where id=winner;
    update public.profiles set losses=losses+1,xp=xp+5,
      rating_points=greatest(0,rating_points-case when g.mode='ranked' then 25 else 0 end)
      where id=case when winner=g.player_one then g.player_two else g.player_one end;
  end if;
  select * into tb from public.game_tiebreaks where match_id=p_match_id;
  return jsonb_build_object('resolved',tb.resolved,'round',tb.round,'opponent_ready',case when sk='player_one' then tb.player_two_card is not null else tb.player_one_card is not null end,
    'winner_id',tb.resolved_winner,'cards',case when tb.resolved_winner is not null then jsonb_build_object('player_one',tb.player_one_card,'player_two',tb.player_two_card,'player_one_power',tb.player_one_power,'player_two_power',tb.player_two_power) else null end);
end $$;

-- Campaign chapters are ordered. A chapter unlocks only after the previous one is claimed.
alter table public.missions add column if not exists chapter integer not null default 1;
update public.missions set chapter=case mission_id when 'first-victory' then 1 when 'ranked-three' then 2 when 'guardian-five' then 3 else chapter end;
insert into public.missions(mission_id,title,description,target_count,reward_xp,reward_coins,mode,chapter) values
 ('chapter-4','Lendas em ascensão','Vença três partidas em qualquer modo.',3,100,60,null,4),
 ('chapter-5','Estratégia da convergência','Vença duas partidas usando o modo ranqueado.',2,140,80,'ranked',5),
 ('chapter-6','Guardião derrotado','Vença o Guardião da Arena três vezes.',3,180,100,'guardian',6)
on conflict(mission_id) do update set chapter=excluded.chapter;

create or replace function public.claim_mission(p_mission_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); mission public.missions%rowtype; played integer; prior_unclaimed integer;
begin
 if uid is null then raise exception 'authentication required'; end if;
 select * into mission from public.missions where mission_id=p_mission_id and active for update;
 if not found then raise exception 'mission unavailable'; end if;
 select count(*) into prior_unclaimed from public.missions m where m.active and m.chapter<mission.chapter
   and not exists(select 1 from public.mission_claims c where c.player_id=uid and c.mission_id=m.mission_id);
 if prior_unclaimed>0 then raise exception 'complete the previous chapter first'; end if;
 select count(*) into played from public.match_history h where h.player_id=uid
   and (mission.mode is null or h.mode=mission.mode)
   and (p_mission_id not in ('first-victory','chapter-4','chapter-5','chapter-6') or h.outcome='victory');
 if played<mission.target_count then raise exception 'mission not completed'; end if;
 insert into public.mission_claims(player_id,mission_id) values(uid,p_mission_id) on conflict do nothing;
 if not found then raise exception 'mission already claimed'; end if;
 update public.profiles set xp=xp+mission.reward_xp,mythic_coins=mythic_coins+mission.reward_coins where id=uid;
 return jsonb_build_object('xp',mission.reward_xp,'coins',mission.reward_coins,'chapter',mission.chapter);
end $$;

create table if not exists public.guild_weekly_missions (
  id uuid primary key default gen_random_uuid(),
  guild_id uuid not null references public.guilds(id) on delete cascade,
  week_start date not null,
  title text not null,
  target integer not null check(target>0),
  progress integer not null default 0 check(progress>=0),
  reward_coins integer not null check(reward_coins>=0),
  claimed_at timestamptz,
  unique(guild_id,week_start)
);
create table if not exists public.guild_wars (
  id uuid primary key default gen_random_uuid(),
  guild_one uuid not null references public.guilds(id) on delete cascade,
  guild_two uuid not null references public.guilds(id) on delete cascade,
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null default now()+interval '7 days',
  score_one integer not null default 0,
  score_two integer not null default 0,
  status text not null default 'active' check(status in('active','completed')),
  check(guild_one<>guild_two)
);
create table if not exists public.guild_war_matches (
  match_id uuid primary key references public.game_matches(id) on delete cascade,
  war_id uuid not null references public.guild_wars(id) on delete cascade,
  winner_guild uuid references public.guilds(id),
  created_at timestamptz not null default now()
);
create table if not exists public.guild_weekly_claims (
  mission_id uuid not null references public.guild_weekly_missions(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  primary key(mission_id,player_id)
);
create table if not exists public.sandbox_room_members (
  room_id uuid not null references public.sandbox_rooms(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(room_id,player_id)
);
create table if not exists public.friend_card_gifts (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  card_id text not null,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  check(sender_id<>receiver_id)
);

create table if not exists public.player_tournament_rounds (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.player_tournaments(id) on delete cascade,
  round_number integer not null check(round_number>0),
  player_one uuid references public.profiles(id) on delete set null,
  player_two uuid references public.profiles(id) on delete set null,
  winner_id uuid references public.profiles(id) on delete set null,
  match_id uuid references public.game_matches(id) on delete set null,
  status text not null default 'pending' check(status in('pending','active','completed','bye')),
  created_at timestamptz not null default now(),
  unique(tournament_id,round_number,player_one,player_two)
);

-- Public, aggregate-only card usage for the Supabase REST API.
create table if not exists public.game_card_play_events (
  id bigint generated always as identity primary key,
  match_id uuid not null references public.game_matches(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  card_id text not null,
  card_type text not null check(card_type in('character','local','terrain','climate','special')),
  created_at timestamptz not null default now()
);
create index if not exists game_card_play_events_card_match on public.game_card_play_events(card_id,match_id);
alter table public.game_card_play_events enable row level security;
revoke all on public.game_card_play_events from public,anon,authenticated;

create or replace view public.public_card_meta with (security_invoker=false) as
 select e.card_id,e.card_type,count(*)::integer as plays,
   count(distinct e.match_id)::integer as matches,
   count(distinct e.match_id) filter(where g.winner_id=e.player_id)::integer as wins,
   case when count(distinct e.match_id)=0 then 0::numeric else round(
     count(distinct e.match_id) filter(where g.winner_id=e.player_id)::numeric /
     count(distinct e.match_id)::numeric * 100,1) end as win_rate
 from public.game_card_play_events e join public.game_matches g on g.id=e.match_id and g.status='completed'
 group by e.card_id,e.card_type;
grant select on public.public_card_meta to anon,authenticated;

create or replace function public.record_game_state_timeline()
returns trigger language plpgsql security definer set search_path='' as $$
declare side_key text; side_player uuid; card record; prior_count integer; copies integer; zone_key text; zone_card text; zone_type text; old_bonus integer; new_bonus integer; old_units integer; new_units integer;
begin
 if new.state is not distinct from old.state then return new; end if;
 insert into public.game_state_timeline(match_id,state,turn_user) values(new.id,new.state,new.turn_user);
 foreach side_key in array array['player_one','player_two'] loop
  side_player:=case when side_key='player_one' then new.player_one else new.player_two end;
  for card in select unit->>'cardId' as card_id,count(*)::integer as card_count
    from jsonb_array_elements(coalesce(new.state#>array[side_key,'field'],'[]'::jsonb)) units(unit)
    where unit->>'cardId' is not null group by unit->>'cardId'
  loop
   select count(*)::integer into prior_count from jsonb_array_elements(coalesce(old.state#>array[side_key,'field'],'[]'::jsonb)) units(unit) where unit->>'cardId'=card.card_id;
   copies:=greatest(0,card.card_count-prior_count);
   if copies>0 then
    insert into public.game_card_play_events(match_id,player_id,card_id,card_type)
    select new.id,side_player,card.card_id,'character' from generate_series(1,copies);
   end if;
  end loop;
  if coalesce((new.state#>>array[side_key,'norseAura'])::integer,0)>coalesce((old.state#>>array[side_key,'norseAura'])::integer,0) then
   insert into public.game_card_play_events(match_id,player_id,card_id,card_type) values(new.id,side_player,'runas-nordicas','special');
  end if;
  select coalesce(sum((unit->>'bonus')::integer),0),count(*) into new_bonus,new_units from jsonb_array_elements(coalesce(new.state#>array[side_key,'field'],'[]'::jsonb)) units(unit);
  select coalesce(sum((unit->>'bonus')::integer),0),count(*) into old_bonus,old_units from jsonb_array_elements(coalesce(old.state#>array[side_key,'field'],'[]'::jsonb)) units(unit);
  if new_units=old_units and new_bonus-old_bonus>=2 then
   insert into public.game_card_play_events(match_id,player_id,card_id,card_type) values(new.id,side_player,'mjolnir','special');
  end if;
 end loop;
 foreach zone_key in array array['local','terrain','climate'] loop
  zone_card:=new.state#>>array['sharedZones',zone_key];
  if zone_card is not null and zone_card is distinct from old.state#>>array['sharedZones',zone_key] then
   zone_type:=case zone_key when 'local' then 'local' when 'terrain' then 'terrain' else 'climate' end;
   insert into public.game_card_play_events(match_id,player_id,card_id,card_type)
   values(new.id,old.turn_user,zone_card,zone_type);
  end if;
 end loop;
 return new;
end $$;
revoke all on function public.record_game_state_timeline() from public,anon,authenticated;

create or replace function public.join_sandbox_room(p_invite_code text)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); room public.sandbox_rooms%rowtype; members integer;
begin
 if uid is null then raise exception 'authentication required'; end if;
 select * into room from public.sandbox_rooms where invite_code=upper(trim(p_invite_code)) and status='open' for update;
 if not found then raise exception 'room unavailable'; end if;
 if exists(select 1 from public.sandbox_room_members where room_id=room.id and player_id=uid) then return room.id; end if;
 if coalesce((room.rules->>'max_players')::integer,2)<>2 then raise exception 'this arena supports exactly two players per room'; end if;
 select count(*) into members from public.sandbox_room_members where room_id=room.id;
 if members>=coalesce((room.rules->>'max_players')::integer,2) then raise exception 'room is full'; end if;
 insert into public.sandbox_room_members(room_id,player_id) values(room.id,uid) on conflict do nothing;
 return room.id;
end $$;

create or replace function public.create_sandbox_room(p_rules jsonb default '{}')
returns public.sandbox_rooms language plpgsql security definer set search_path='' as $$
declare result public.sandbox_rooms%rowtype; max_cards integer; max_players integer; starting_hand integer; turn_seconds integer;
begin
 if auth.uid() is null or p_rules is null or jsonb_typeof(p_rules)<>'object' then raise exception 'invalid sandbox rules'; end if;
 if exists(select 1 from jsonb_object_keys(p_rules) as rule_key(key) where key not in('max_cards','max_players','starting_hand','turn_seconds')) then raise exception 'unsupported sandbox rule'; end if;
 max_cards:=coalesce((p_rules->>'max_cards')::integer,20);max_players:=coalesce((p_rules->>'max_players')::integer,2);starting_hand:=coalesce((p_rules->>'starting_hand')::integer,5);turn_seconds:=coalesce((p_rules->>'turn_seconds')::integer,30);
 if max_cards not between 12 and 20 or max_players<>2 or starting_hand not between 3 and 5 or turn_seconds not between 20 and 120 then raise exception 'rules outside supported limits'; end if;
 insert into public.sandbox_rooms(host_id,rules) values(auth.uid(),jsonb_build_object('max_cards',max_cards,'max_players',max_players,'starting_hand',starting_hand,'turn_seconds',turn_seconds)) returning * into result;
 insert into public.sandbox_room_members(room_id,player_id) values(result.id,auth.uid());return result;
end $$;

create or replace function public.start_sandbox_match(p_room_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare room public.sandbox_rooms%rowtype; players uuid[]; max_cards integer; opening_hand integer; state jsonb; side_key text; side jsonb; pool jsonb; new_hand jsonb; new_deck jsonb; match_id uuid; i integer;
begin
 select * into room from public.sandbox_rooms where id=p_room_id and host_id=auth.uid() and status='open' for update;
 if not found then raise exception 'only the room host can start this room'; end if;
 select array_agg(player_id order by joined_at,player_id) into players from public.sandbox_room_members where room_id=room.id;
 if coalesce(array_length(players,1),0)<>2 then raise exception 'the room needs exactly two players'; end if;
 max_cards:=coalesce((room.rules->>'max_cards')::integer,20);opening_hand:=coalesce((room.rules->>'starting_hand')::integer,5);
 state:=public._new_online_game_state(players[1],players[2]);
 foreach side_key in array array['player_one','player_two'] loop
  side:=state->side_key;pool:=coalesce(side->'hand','[]'::jsonb)||coalesce(side->'deck','[]'::jsonb);
  select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into pool from jsonb_array_elements(pool) with ordinality e(value,ordinality) where ordinality<=max_cards;
  select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into new_hand from jsonb_array_elements(pool) with ordinality e(value,ordinality) where ordinality<=opening_hand;
  select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into new_deck from jsonb_array_elements(pool) with ordinality e(value,ordinality) where ordinality>opening_hand;
  side:=jsonb_set(side,'{hand}',new_hand,true);side:=jsonb_set(side,'{deck}',new_deck,true);
  state:=jsonb_set(state,array[side_key],side,true);
 end loop;
 state:=jsonb_set(state,'{sandboxRules}',room.rules,true);state:=jsonb_set(state,'{turnSeconds}',room.rules->'turn_seconds',true);
 insert into public.game_matches(player_one,player_two,mode,status,state,turn_user) values(players[1],players[2],'friend','active',state,players[1]) returning id into match_id;
 update public.sandbox_rooms set status='playing' where id=room.id;return match_id;
end $$;

create or replace function public.send_friend_card_gift(p_receiver uuid,p_card_id text)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); gift_id uuid; owned integer;
begin
 if uid is null or uid=p_receiver or p_card_id not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','medusa') then raise exception 'invalid card gift'; end if;
 if not exists(select 1 from public.friendships where status='accepted' and ((user_a=uid and user_b=p_receiver) or (user_b=uid and user_a=p_receiver))) then raise exception 'recipient must be a friend'; end if;
 update public.player_decks set card_counts=jsonb_set(card_counts,array[p_card_id],to_jsonb(greatest(0,coalesce((card_counts->>p_card_id)::integer,0)-1)),true) where player_id=uid and coalesce((card_counts->>p_card_id)::integer,0)>1 and (select coalesce(sum(value::integer),0) from jsonb_each_text(card_counts))>12;
 if not found then raise exception 'you need at least two copies to gift one'; end if;
 insert into public.friend_card_gifts(sender_id,receiver_id,card_id) values(uid,p_receiver,p_card_id) returning id into gift_id;return gift_id;
end $$;

create or replace function public.claim_friend_card_gift(p_gift_id uuid)
returns text language plpgsql security definer set search_path='' as $$
declare gift public.friend_card_gifts%rowtype; counts jsonb;
begin
 update public.friend_card_gifts set claimed_at=now() where id=p_gift_id and receiver_id=auth.uid() and claimed_at is null returning * into gift;
 if not found then raise exception 'gift unavailable'; end if;
 insert into public.player_decks(player_id,card_counts) values(auth.uid(),jsonb_build_object(gift.card_id,1)) on conflict(player_id) do nothing;
 update public.player_decks set card_counts=jsonb_set(card_counts,array[gift.card_id],to_jsonb(coalesce((card_counts->>gift.card_id)::integer,0)+1),true),updated_at=now() where player_id=auth.uid();
 return gift.card_id;
end $$;

-- An expedition temporarily reserves a copy, then returns it with the reward.
create or replace function public.start_player_expedition(p_card_id text,p_duration integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); eid uuid; counts jsonb; quantity integer; deck_size integer;
begin
 if uid is null or p_duration not in(4,8,12) then raise exception 'invalid expedition'; end if;
 select card_counts into counts from public.player_decks where player_id=uid for update;
 if not found then raise exception 'collection unavailable'; end if;
 quantity:=coalesce((counts->>p_card_id)::integer,0);
 select coalesce(sum(value::integer),0) into deck_size from jsonb_each_text(counts);
 if quantity<2 or deck_size<=12 then raise exception 'keep one copy and at least 12 cards in your deck'; end if;
 update public.player_decks set card_counts=jsonb_set(counts,array[p_card_id],to_jsonb(quantity-1),true),updated_at=now() where player_id=uid;
 insert into public.player_expeditions(player_id,card_id,duration_hours,ends_at,reward_coins)
 values(uid,p_card_id,p_duration,now()+make_interval(hours=>p_duration),p_duration*5) returning id into eid;
 return eid;
end $$;

create or replace function public.claim_player_expedition(p_expedition_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare expedition public.player_expeditions%rowtype; counts jsonb; reward integer;
begin
 select * into expedition from public.player_expeditions where id=p_expedition_id and player_id=auth.uid() and claimed_at is null and ends_at<=now() for update;
 if not found then raise exception 'expedition is not ready'; end if;
 update public.player_expeditions set claimed_at=now() where id=expedition.id;
 insert into public.player_decks(player_id,card_counts) values(auth.uid(),jsonb_build_object(expedition.card_id,1)) on conflict(player_id) do nothing;
 update public.player_decks set card_counts=jsonb_set(card_counts,array[expedition.card_id],to_jsonb(coalesce((card_counts->>expedition.card_id)::integer,0)+1),true),updated_at=now() where player_id=auth.uid();
 update public.profiles set mythic_coins=mythic_coins+expedition.reward_coins where id=auth.uid();
 return expedition.reward_coins;
end $$;

create or replace function public.create_guild_war(p_opponent_guild uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); own_guild uuid; war_id uuid;
begin
 select guild_id into own_guild from public.guild_members where player_id=uid and role in('leader','officer');
 if own_guild is null or own_guild=p_opponent_guild then raise exception 'guild leader access required'; end if;
 if not exists(select 1 from public.guilds where id=p_opponent_guild) then raise exception 'opponent guild not found'; end if;
 insert into public.guild_wars(guild_one,guild_two) values(own_guild,p_opponent_guild) returning id into war_id;return war_id;
end $$;

create or replace function public.seed_guild_weekly_mission()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.guild_weekly_missions(guild_id,week_start,title,target,progress,reward_coins)
 values(new.guild_id,date_trunc('week',now())::date,'Partidas da guilda',5,0,50)
 on conflict(guild_id,week_start) do nothing;
 return new;
end $$;
drop trigger if exists seed_guild_weekly_mission on public.guild_members;
create trigger seed_guild_weekly_mission after insert on public.guild_members for each row execute function public.seed_guild_weekly_mission();

create or replace function public.record_guild_weekly_match()
returns trigger language plpgsql security definer set search_path='' as $$
declare gid uuid;
begin
 select guild_id into gid from public.guild_members where player_id=new.player_id;
 if gid is not null then
  insert into public.guild_weekly_missions(guild_id,week_start,title,target,progress,reward_coins)
  values(gid,date_trunc('week',now())::date,'Partidas da guilda',5,0,50) on conflict(guild_id,week_start) do nothing;
  update public.guild_weekly_missions set progress=least(target,progress+1) where guild_id=gid and week_start=date_trunc('week',now())::date;
 end if;
 return new;
end $$;
drop trigger if exists record_guild_weekly_match on public.match_history;
create trigger record_guild_weekly_match after insert on public.match_history for each row execute function public.record_guild_weekly_match();

create or replace function public.claim_guild_weekly_reward(p_mission_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare reward integer;
begin
 if not exists(select 1 from public.guild_weekly_missions m join public.guild_members gm on gm.guild_id=m.guild_id where m.id=p_mission_id and gm.player_id=auth.uid() and m.progress>=m.target) then raise exception 'weekly mission not complete'; end if;
 select reward_coins into reward from public.guild_weekly_missions where id=p_mission_id for update;
 insert into public.guild_weekly_claims(mission_id,player_id) values(p_mission_id,auth.uid()) on conflict do nothing;
 if not found then raise exception 'weekly reward already claimed'; end if;
 update public.profiles set mythic_coins=mythic_coins+reward where id=auth.uid();return reward;
end $$;

create or replace function public.record_guild_war_result()
returns trigger language plpgsql security definer set search_path='' as $$
declare one_guild uuid;two_guild uuid;w record;
begin
 if new.status<>'completed' or new.winner_id is null or (old.status='completed' and old.winner_id is not distinct from new.winner_id) then return new; end if;
 select guild_id into one_guild from public.guild_members where player_id=new.player_one;
 select guild_id into two_guild from public.guild_members where player_id=new.player_two;
 if one_guild is null or two_guild is null or one_guild=two_guild then return new; end if;
 for w in select * from public.guild_wars where status='active' and ends_at>now() and ((guild_one=one_guild and guild_two=two_guild) or (guild_one=two_guild and guild_two=one_guild)) loop
  insert into public.guild_war_matches(match_id,war_id,winner_guild) values(new.id,w.id,case when new.winner_id=new.player_one then one_guild else two_guild end) on conflict(match_id) do nothing;
  if found then update public.guild_wars set score_one=score_one+case when (new.winner_id=new.player_one and guild_one=one_guild) or (new.winner_id=new.player_two and guild_one=two_guild) then 1 else 0 end,score_two=score_two+case when (new.winner_id=new.player_one and guild_two=one_guild) or (new.winner_id=new.player_two and guild_two=two_guild) then 1 else 0 end where id=w.id; end if;
 end loop;
 return new;
end $$;
drop trigger if exists record_guild_war_result on public.game_matches;
create trigger record_guild_war_result after update of status,winner_id on public.game_matches for each row execute function public.record_guild_war_result();

create or replace function public.create_tournament_bracket(p_tournament_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare t public.player_tournaments%rowtype; ids uuid[]; idx integer; total integer:=0; r integer:=1; current_ids uuid[];
begin
 select * into t from public.player_tournaments where id=p_tournament_id and host_id=auth.uid() and status='registration' for update;
 if not found or t.starts_at>now() then raise exception 'tournament is not ready to start'; end if;
 select array_agg(player_id order by joined_at,player_id) into ids from public.tournament_entries where tournament_id=p_tournament_id;
 if coalesce(array_length(ids,1),0)<2 then raise exception 'at least two players are required'; end if;
 update public.player_tournaments set status='in_progress' where id=p_tournament_id;
 idx:=1;
 while idx<=array_length(ids,1) loop
   insert into public.player_tournament_rounds(tournament_id,round_number,player_one,player_two,status,winner_id)
   values(p_tournament_id,r,ids[idx],ids[idx+1],case when idx+1>array_length(ids,1) then 'bye' else 'pending' end,case when idx+1>array_length(ids,1) then ids[idx] else null end);
   total:=total+1;idx:=idx+2;
 end loop;
 return total;
end $$;

create or replace function public.start_tournament_match(p_round_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.player_tournament_rounds%rowtype; mid uuid; state jsonb;
begin
 select * into r from public.player_tournament_rounds where id=p_round_id and status='pending' for update;
 if not found or auth.uid() not in(r.player_one,r.player_two) then raise exception 'tournament round unavailable'; end if;
 state:=public._new_online_game_state(r.player_one,r.player_two);
 insert into public.game_matches(player_one,player_two,mode,status,state,turn_user) values(r.player_one,r.player_two,'friend','active',state,r.player_one) returning id into mid;
 update public.player_tournament_rounds set match_id=mid,status='active' where id=r.id;
 return mid;
end $$;

create or replace function public.advance_tournament_bracket(p_tournament_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare t public.player_tournaments%rowtype; last_round integer; ids uuid[]; idx integer; count_matches integer:=0; next_round integer; entrants integer; target_rounds integer:=1; power_of_two integer:=2;
begin
 select * into t from public.player_tournaments where id=p_tournament_id and host_id=auth.uid() and status='in_progress' for update;
 if not found then raise exception 'tournament host access required'; end if;
 select max(round_number) into last_round from public.player_tournament_rounds where tournament_id=p_tournament_id;
 if exists(select 1 from public.player_tournament_rounds where tournament_id=p_tournament_id and round_number=last_round and status not in('completed','bye')) then raise exception 'current round has unfinished matches'; end if;
 if t.format='swiss' then
  select count(*) into entrants from public.tournament_entries where tournament_id=p_tournament_id;
  while power_of_two<entrants loop target_rounds:=target_rounds+1;power_of_two:=power_of_two*2;end loop;
  if last_round>=target_rounds then update public.player_tournaments set status='completed' where id=p_tournament_id; return 0; end if;
  select array_agg(e.player_id order by coalesce(scores.points,0) desc,e.joined_at,e.player_id) into ids
  from public.tournament_entries e left join lateral (select count(*)::integer points from public.player_tournament_rounds rr where rr.tournament_id=e.tournament_id and rr.round_number<=last_round and rr.winner_id=e.player_id) scores on true
  where e.tournament_id=p_tournament_id;
 else
  select array_agg(winner_id order by id) filter(where winner_id is not null) into ids from public.player_tournament_rounds where tournament_id=p_tournament_id and round_number=last_round;
  if coalesce(array_length(ids,1),0)=1 then update public.player_tournaments set status='completed' where id=p_tournament_id; return 0; end if;
 end if;
 if coalesce(array_length(ids,1),0)<2 then raise exception 'no winners to advance'; end if;
 next_round:=last_round+1;idx:=1;
 while idx<=array_length(ids,1) loop
  insert into public.player_tournament_rounds(tournament_id,round_number,player_one,player_two,status,winner_id)
  values(p_tournament_id,next_round,ids[idx],ids[idx+1],case when idx+1>array_length(ids,1) then 'bye' else 'pending' end,case when idx+1>array_length(ids,1) then ids[idx] else null end);
  count_matches:=count_matches+1;idx:=idx+2;
 end loop;
 return count_matches;
end $$;

create or replace function public.record_tournament_match_result()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='completed' and new.winner_id is not null then
  update public.player_tournament_rounds set status='completed',winner_id=new.winner_id where match_id=new.id;
 end if;
 return new;
end $$;
drop trigger if exists tournament_match_result on public.game_matches;
create trigger tournament_match_result after update of status,winner_id on public.game_matches for each row execute function public.record_tournament_match_result();

create or replace function public.set_game_turn_deadline()
returns trigger language plpgsql set search_path='' as $$
declare seconds integer;
begin
 if tg_op='INSERT' then
  if new.status='active' and new.turn_user is not null then
   seconds:=greatest(10,least(120,coalesce((new.state->>'turnSeconds')::integer,30)));
   new.turn_deadline:=clock_timestamp()+make_interval(secs=>seconds);
  else new.turn_deadline:=null; end if;
  return new;
 end if;
 if new.status='active' and new.turn_user is not null and (new.state is distinct from old.state or new.turn_user is distinct from old.turn_user or new.status is distinct from old.status) then
   seconds:=greatest(10,least(120,coalesce((new.state->>'turnSeconds')::integer,30)));
   new.turn_deadline:=clock_timestamp()+make_interval(secs=>seconds);
 elsif new.status<>'active' or new.turn_user is null then new.turn_deadline:=null;
 end if;
 return new;
end $$;
drop trigger if exists game_turn_deadline on public.game_matches;
create trigger game_turn_deadline before insert or update of state,turn_user,status on public.game_matches for each row execute function public.set_game_turn_deadline();

do $$ declare f text; t text; begin
 foreach f in array array['get_tiebreak_state(uuid)','submit_tiebreak_card(uuid,text)','join_sandbox_room(text)','start_sandbox_match(uuid)','send_friend_card_gift(uuid,text)','claim_friend_card_gift(uuid)','create_guild_war(uuid)','claim_guild_weekly_reward(uuid)','create_tournament_bracket(uuid)','start_tournament_match(uuid)','advance_tournament_bracket(uuid)','start_player_expedition(text,integer)','claim_player_expedition(uuid)'] loop
   execute 'revoke all on function public.'||f||' from public,anon';execute 'grant execute on function public.'||f||' to authenticated';
 end loop;
 foreach t in array array['game_tiebreaks','guild_weekly_missions','guild_weekly_claims','guild_wars','guild_war_matches','sandbox_room_members','friend_card_gifts','player_tournament_rounds','game_card_play_events'] loop
   execute format('alter table public.%I enable row level security',t);
 end loop;
end $$;
grant select on public.guild_weekly_missions,public.guild_wars,public.sandbox_room_members,public.friend_card_gifts,public.player_tournament_rounds to authenticated;
drop policy if exists "Guild members see weekly missions" on public.guild_weekly_missions;
create policy "Guild members see weekly missions" on public.guild_weekly_missions for select to authenticated using(exists(select 1 from public.guild_members gm where gm.guild_id=public.guild_weekly_missions.guild_id and gm.player_id=auth.uid()));
drop policy if exists "Guild members see wars" on public.guild_wars;
create policy "Guild members see wars" on public.guild_wars for select to authenticated using(exists(select 1 from public.guild_members gm where gm.guild_id in(public.guild_wars.guild_one,public.guild_wars.guild_two) and gm.player_id=auth.uid()));
drop policy if exists "Sandbox members see room members" on public.sandbox_room_members;
create policy "Sandbox members see room members" on public.sandbox_room_members for select to authenticated using(player_id=auth.uid() or exists(select 1 from public.sandbox_rooms r where r.id=public.sandbox_room_members.room_id and r.host_id=auth.uid()));
drop policy if exists "Players see received card gifts" on public.friend_card_gifts;
create policy "Players see received card gifts" on public.friend_card_gifts for select to authenticated using(auth.uid() in(sender_id,receiver_id));
drop policy if exists "Tournament entries see rounds" on public.player_tournament_rounds;
create policy "Tournament entries see rounds" on public.player_tournament_rounds for select to authenticated using(exists(select 1 from public.tournament_entries e where e.tournament_id=public.player_tournament_rounds.tournament_id and e.player_id=auth.uid()));
commit;
