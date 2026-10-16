begin;

-- Tournament creation is an administrative action, including direct RPC calls.
create or replace function public.create_player_tournament(p_title text,p_format text,p_starts_at timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); tid uuid;
begin
 if uid is null then raise exception 'authentication required'; end if;
 if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.'; end if;
 if length(trim(coalesce(p_title,''))) not between 3 and 64 then raise exception 'invalid tournament title'; end if;
 if p_format not in ('single_elimination','swiss') then raise exception 'invalid tournament format'; end if;
 if p_starts_at<now()+interval '10 minutes' then raise exception 'start time must be at least 10 minutes ahead'; end if;
 insert into public.player_tournaments(host_id,title,format,starts_at) values(uid,trim(p_title),p_format,p_starts_at) returning id into tid;
 insert into public.tournament_entries(tournament_id,player_id) values(tid,uid);
 return tid;
end $$;
revoke all on function public.create_player_tournament(text,text,timestamptz) from public,anon;
grant execute on function public.create_player_tournament(text,text,timestamptz) to authenticated;

commit;
create or replace function public.get_sandbox_room_roster(p_room_id uuid)
returns table(slot integer,nickname text)
language plpgsql security definer set search_path='' stable as $$
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 if not exists(select 1 from public.sandbox_room_members m where m.room_id=p_room_id and m.player_id=auth.uid()) then
  raise exception 'room access denied';
 end if;
 return query
 select row_number() over(order by m.joined_at,m.player_id)::integer,
        coalesce(nullif(p.nickname,''),nullif(p.display_name,''),'Invocador')
 from public.sandbox_room_members m
 join public.profiles p on p.id=m.player_id
 where m.room_id=p_room_id
 order by m.joined_at,m.player_id;
end $$;
revoke all on function public.get_sandbox_room_roster(uuid) from public,anon;
grant execute on function public.get_sandbox_room_roster(uuid) to authenticated;
create table if not exists public.sandbox_room_spectators (
 room_id uuid not null references public.sandbox_rooms(id) on delete cascade,
 spectator_id uuid not null references public.profiles(id) on delete cascade,
 joined_at timestamptz not null default now(),
 primary key(room_id,spectator_id),
 unique(room_id)
);
alter table public.sandbox_room_spectators enable row level security;
revoke all on public.sandbox_room_spectators from public,anon,authenticated;

create or replace function public.join_sandbox_spectator(p_invite_code text)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); v_room_id uuid;
begin
 if uid is null then raise exception 'authentication required'; end if;
 select id into v_room_id from public.sandbox_rooms where invite_code=upper(trim(p_invite_code)) and status='open' for update;
 if v_room_id is null then raise exception 'room unavailable'; end if;
 if exists(select 1 from public.sandbox_room_members where sandbox_room_members.room_id=v_room_id and player_id=uid) then raise exception 'players cannot occupy the spectator seat'; end if;
 insert into public.sandbox_room_spectators(room_id,spectator_id) values(v_room_id,uid) on conflict(room_id) do nothing;
 if not exists(select 1 from public.sandbox_room_spectators where sandbox_room_spectators.room_id=v_room_id and spectator_id=uid) then raise exception 'spectator seat is occupied'; end if;
 return v_room_id;
end $$;
revoke all on function public.join_sandbox_spectator(text) from public,anon;
grant execute on function public.join_sandbox_spectator(text) to authenticated;

drop function if exists public.get_sandbox_room_roster(uuid);
create or replace function public.get_sandbox_room_roster(p_room_id uuid)
returns table(slot integer,nickname text)
language plpgsql security definer set search_path='' stable as $$
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 if not exists(select 1 from public.sandbox_room_members m where m.room_id=p_room_id and m.player_id=auth.uid())
 and not exists(select 1 from public.sandbox_room_spectators s where s.room_id=p_room_id and s.spectator_id=auth.uid()) then
  raise exception 'room access denied';
 end if;
 return query
 select slots.seat,coalesce(nullif(p.nickname,''),nullif(p.display_name,''),'Invocador')
 from (
  select row_number() over(order by m.joined_at,m.player_id)::integer as seat,m.player_id,m.joined_at from public.sandbox_room_members m where m.room_id=p_room_id
  union all
  select 3::integer,s.spectator_id,s.joined_at from public.sandbox_room_spectators s where s.room_id=p_room_id
 ) slots join public.profiles p on p.id=slots.player_id
 order by slots.seat;
end $$;
revoke all on function public.get_sandbox_room_roster(uuid) from public,anon;
grant execute on function public.get_sandbox_room_roster(uuid) to authenticated;
alter table public.sandbox_rooms add column if not exists match_id uuid references public.game_matches(id) on delete set null;

create or replace function public.register_sandbox_match(p_room_id uuid,p_match_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare room public.sandbox_rooms%rowtype; game_row public.game_matches%rowtype; members uuid[];
begin
 select * into room from public.sandbox_rooms where id=p_room_id and host_id=auth.uid() for update;
 if not found then raise exception 'only the room host can register its match'; end if;
 select * into game_row from public.game_matches where id=p_match_id and status='active';
 if not found then raise exception 'match unavailable'; end if;
 select array_agg(player_id order by joined_at,player_id) into members from public.sandbox_room_members where room_id=p_room_id;
 if coalesce(array_length(members,1),0)<>2 or not (game_row.player_one=any(members) and game_row.player_two=any(members)) then raise exception 'match does not belong to this room'; end if;
 update public.sandbox_rooms set match_id=p_match_id,status='playing' where id=p_room_id;
end $$;
revoke all on function public.register_sandbox_match(uuid,uuid) from public,anon;
grant execute on function public.register_sandbox_match(uuid,uuid) to authenticated;

create or replace function public.get_sandbox_spectator_match(p_room_id uuid)
returns uuid language plpgsql security definer set search_path='' stable as $$
declare result uuid;
begin
 if auth.uid() is null or not exists(select 1 from public.sandbox_room_spectators s where s.room_id=p_room_id and s.spectator_id=auth.uid()) then raise exception 'spectator access denied'; end if;
 select r.match_id into result from public.sandbox_rooms r where r.id=p_room_id and r.status='playing';
 return result;
end $$;
revoke all on function public.get_sandbox_spectator_match(uuid) from public,anon;
grant execute on function public.get_sandbox_spectator_match(uuid) to authenticated;

create or replace function public.request_match_spectator(p_match_id uuid,p_delay_seconds integer default 60)
returns void language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); one_id uuid; two_id uuid; sandbox_spectator boolean;
begin
 select player_one,player_two into one_id,two_id from public.game_matches where id=p_match_id and status='active';
 if not found or uid in(one_id,two_id) then raise exception 'match unavailable'; end if;
 select exists(select 1 from public.sandbox_rooms r join public.sandbox_room_spectators s on s.room_id=r.id where r.match_id=p_match_id and s.spectator_id=uid) into sandbox_spectator;
 if not sandbox_spectator and not exists(select 1 from public.friendships f where f.status='accepted' and ((f.user_a=uid and f.user_b in(one_id,two_id)) or (f.user_b=uid and f.user_a in(one_id,two_id)))) then raise exception 'only friends or the room spectator can watch'; end if;
 insert into public.match_spectators(match_id,spectator_id,requested_by,delay_seconds) values(p_match_id,uid,uid,greatest(30,least(300,p_delay_seconds))) on conflict(match_id,spectator_id) do update set delay_seconds=excluded.delay_seconds;
end $$;
revoke all on function public.request_match_spectator(uuid,integer) from public,anon;
grant execute on function public.request_match_spectator(uuid,integer) to authenticated;
