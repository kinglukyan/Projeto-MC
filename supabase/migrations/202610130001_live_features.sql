-- Foundation for live Mythic Clash systems. Apply after 202609270008_medusa_rank_history.sql.
begin;

create table if not exists public.missions (
  mission_id text primary key,
  title text not null,
  description text not null,
  target_count integer not null check(target_count > 0),
  reward_xp integer not null default 0 check(reward_xp >= 0),
  reward_coins integer not null default 0 check(reward_coins >= 0),
  mode text check(mode in ('normal','ranked','friend','guardian')),
  active boolean not null default true
);
insert into public.missions(mission_id,title,description,target_count,reward_xp,reward_coins,mode) values
 ('first-victory','Primeira vitória','Vença uma partida na Arena.',1,50,30,null),
 ('ranked-three','Rumo ao topo','Jogue três partidas ranqueadas.',3,100,50,'ranked'),
 ('guardian-five','Treino do Guardião','Enfrente o Guardião cinco vezes.',5,80,40,'guardian')
on conflict(mission_id) do nothing;

create table if not exists public.mission_claims (
  player_id uuid not null references public.profiles(id) on delete cascade,
  mission_id text not null references public.missions(mission_id),
  claimed_at timestamptz not null default now(),
  primary key(player_id,mission_id)
);

create table if not exists public.guilds (
  id uuid primary key default gen_random_uuid(),
  name text not null check(char_length(name) between 3 and 32),
  invite_code text not null unique default upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
  description text not null default '' check(char_length(description)<=240),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.guild_members (
  guild_id uuid not null references public.guilds(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check(role in ('leader','officer','member')),
  joined_at timestamptz not null default now(),
  primary key(guild_id,player_id),
  unique(player_id)
);

create table if not exists public.player_tournaments (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check(char_length(title) between 3 and 64),
  format text not null default 'single_elimination' check(format in ('single_elimination','swiss')),
  starts_at timestamptz not null,
  status text not null default 'registration' check(status in ('registration','in_progress','completed','cancelled')),
  created_at timestamptz not null default now()
);
create table if not exists public.tournament_entries (
  tournament_id uuid not null references public.player_tournaments(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(tournament_id,player_id)
);

create table if not exists public.friend_gifts (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  coins integer not null check(coins between 1 and 500),
  note text not null default '' check(char_length(note)<=160),
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  check(sender_id<>receiver_id)
);

create table if not exists public.player_expeditions (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  card_id text not null,
  duration_hours integer not null check(duration_hours in (4,8,12)),
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  reward_coins integer not null check(reward_coins > 0),
  claimed_at timestamptz
);
create unique index if not exists player_expeditions_one_card_active on public.player_expeditions(player_id,card_id) where claimed_at is null;

create table if not exists public.game_replays (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.game_matches(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null default 'Replay da Arena' check(char_length(title)<=80),
  events jsonb not null check(jsonb_typeof(events)='array'),
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  unique(match_id,owner_id)
);
create table if not exists public.game_state_timeline (
  event_id bigint generated always as identity primary key,
  match_id uuid not null references public.game_matches(id) on delete cascade,
  state jsonb not null check(jsonb_typeof(state)='object'),
  turn_user uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists game_state_timeline_match_order on public.game_state_timeline(match_id,event_id desc);
insert into public.game_state_timeline(match_id,state,turn_user,created_at)
 select id,state,turn_user,created_at from public.game_matches where status in ('active','completed')
 and not exists(select 1 from public.game_state_timeline t where t.match_id=game_matches.id);
create or replace function public.record_game_state_timeline()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.state is distinct from old.state then insert into public.game_state_timeline(match_id,state,turn_user) values(new.id,new.state,new.turn_user); end if;
 return new;
end $$;
drop trigger if exists game_state_timeline_capture on public.game_matches;
create trigger game_state_timeline_capture after update of state on public.game_matches for each row execute function public.record_game_state_timeline();

create table if not exists public.match_spectators (
  match_id uuid not null references public.game_matches(id) on delete cascade,
  spectator_id uuid not null references public.profiles(id) on delete cascade,
  requested_by uuid not null references public.profiles(id) on delete cascade,
  delay_seconds integer not null default 60 check(delay_seconds between 30 and 300),
  created_at timestamptz not null default now(),
  primary key(match_id,spectator_id)
);

create or replace function public.list_friend_active_matches()
returns table(match_id uuid,friend_name text,opponent_name text,mode text,started_at timestamptz)
language sql security definer set search_path='' stable as $$
 select g.id,coalesce(friend_profile.nickname,friend_profile.display_name),coalesce(opponent.nickname,opponent.display_name),g.mode,g.created_at
 from public.friendships f
 join public.game_matches g on g.status='active' and (g.player_one in(f.user_a,f.user_b) or g.player_two in(f.user_a,f.user_b))
 join public.profiles friend_profile on friend_profile.id=case when g.player_one in(f.user_a,f.user_b) and g.player_one<>auth.uid() then g.player_one else g.player_two end
 join public.profiles opponent on opponent.id=case when g.player_one in(f.user_a,f.user_b) and g.player_one<>auth.uid() then g.player_two else g.player_one end
 where f.status='accepted' and auth.uid() in(f.user_a,f.user_b) and auth.uid() not in(g.player_one,g.player_two)
   and case when g.player_one=auth.uid() then g.player_two else g.player_one end in(f.user_a,f.user_b)
 order by g.created_at desc limit 20;
$$;

create or replace function public.get_delayed_spectator_snapshot(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' stable as $$
declare delay integer; snapshot jsonb;
begin
 select delay_seconds into delay from public.match_spectators where match_id=p_match_id and spectator_id=auth.uid();
 if not found then raise exception 'spectator access not granted'; end if;
 select jsonb_build_object('state',t.state,'turn_user',t.turn_user,'captured_at',t.created_at)
 into snapshot from public.game_state_timeline t
 where t.match_id=p_match_id and t.created_at<=now()-make_interval(secs=>delay)
 order by t.event_id desc limit 1;
 return snapshot;
end $$;

create table if not exists public.sandbox_rooms (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles(id) on delete cascade,
  invite_code text not null unique default upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
  rules jsonb not null default '{}'::jsonb check(jsonb_typeof(rules)='object'),
  status text not null default 'open' check(status in ('open','playing','closed')),
  created_at timestamptz not null default now()
);

alter table public.card_lore add column if not exists comic_url text;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('mythic-comics','mythic-comics',true,52428800,array['application/pdf','image/png','image/jpeg','image/webp'])
on conflict(id) do update set public=true,file_size_limit=52428800,allowed_mime_types=array['application/pdf','image/png','image/jpeg','image/webp'];
drop policy if exists "Public reads Mythic comics" on storage.objects;
create policy "Public reads Mythic comics" on storage.objects for select to anon,authenticated using(bucket_id='mythic-comics');
drop policy if exists "Admins upload Mythic comics" on storage.objects;
create policy "Admins upload Mythic comics" on storage.objects for insert to authenticated with check(bucket_id='mythic-comics' and public.is_site_admin());
drop policy if exists "Admins update Mythic comics" on storage.objects;
create policy "Admins update Mythic comics" on storage.objects for update to authenticated using(bucket_id='mythic-comics' and public.is_site_admin()) with check(bucket_id='mythic-comics' and public.is_site_admin());
drop policy if exists "Admins delete Mythic comics" on storage.objects;
create policy "Admins delete Mythic comics" on storage.objects for delete to authenticated using(bucket_id='mythic-comics' and public.is_site_admin());

create table if not exists public.community_decks (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check(char_length(title) between 3 and 40),
  deck_code text not null check(char_length(deck_code)<=2000),
  description text not null default '' check(char_length(description)<=240),
  created_at timestamptz not null default now()
);
create table if not exists public.community_deck_votes (
  deck_id uuid not null references public.community_decks(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(deck_id,player_id)
);

alter table public.game_matches add column if not exists turn_deadline timestamptz;
update public.game_matches set turn_deadline=coalesce(turn_deadline,now()+interval '30 seconds') where status='active' and turn_user is not null;
create or replace function public.set_game_turn_deadline()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.status='active' and new.turn_user is not null and (tg_op='INSERT' or new.state is distinct from old.state or new.turn_user is distinct from old.turn_user) then
   new.turn_deadline:=clock_timestamp()+interval '30 seconds';
 elsif new.status<>'active' or new.turn_user is null then new.turn_deadline:=null;
 end if;
 return new;
end $$;
drop trigger if exists game_turn_deadline on public.game_matches;
create trigger game_turn_deadline before insert or update of state,turn_user,status on public.game_matches for each row execute function public.set_game_turn_deadline();

create or replace function public.expire_game_turns()
returns integer language plpgsql security definer set search_path='' as $$
declare g record; side_key text; action_name text; expired integer:=0;
begin
 for g in select id,player_one,player_two,turn_user,state from public.game_matches where status='active' and turn_user is not null and turn_deadline<=clock_timestamp() order by turn_deadline for update skip locked loop
  side_key:=case when g.turn_user=g.player_one then 'player_one' else 'player_two' end;
  action_name:=case when coalesce((g.state#>>array[side_key,'skipNextTurn'])::boolean,false) then 'skip_turn' else 'pass' end;
  begin
   perform set_config('request.jwt.claim.sub',g.turn_user::text,true);
   perform public.submit_game_action(g.id,jsonb_build_object('type',action_name));
   expired:=expired+1;
  exception when others then
   -- A simultaneous player action or an already completed round may make this deadline stale.
   null;
  end;
 end loop;
 return expired;
end $$;
revoke all on function public.expire_game_turns() from public,anon;
grant execute on function public.expire_game_turns() to authenticated;

do $$ begin
 if exists(select 1 from pg_extension where extname='pg_cron') then
  execute 'select cron.unschedule(jobid) from cron.job where jobname = ''mythic-clash-turn-expiry''';
  execute 'select cron.schedule(''mythic-clash-turn-expiry'',''* * * * *'',''select public.expire_game_turns()'')';
 end if;
end $$;

create or replace function public.claim_mission(p_mission_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); mission public.missions%rowtype; played integer;
begin
 if uid is null then raise exception 'authentication required'; end if;
 select * into mission from public.missions where mission_id=p_mission_id and active;
 if not found then raise exception 'mission unavailable'; end if;
 select count(*) into played from public.match_history h where h.player_id=uid
   and (mission.mode is null or h.mode=mission.mode)
   and (p_mission_id<>'first-victory' or h.outcome='victory');
 if played<mission.target_count then raise exception 'mission not completed'; end if;
 insert into public.mission_claims(player_id,mission_id) values(uid,p_mission_id) on conflict do nothing;
 if not found then raise exception 'mission already claimed'; end if;
 update public.profiles set xp=xp+mission.reward_xp,mythic_coins=mythic_coins+mission.reward_coins where id=uid;
 return jsonb_build_object('xp',mission.reward_xp,'coins',mission.reward_coins);
end $$;

create or replace function public.create_guild(p_name text,p_description text default '')
returns public.guilds language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); result public.guilds%rowtype;
begin
 if uid is null then raise exception 'authentication required'; end if;
 if exists(select 1 from public.guild_members where player_id=uid) then raise exception 'already in a guild'; end if;
 insert into public.guilds(name,description,owner_id) values(trim(p_name),trim(coalesce(p_description,'')),uid) returning * into result;
 insert into public.guild_members(guild_id,player_id,role) values(result.id,uid,'leader'); return result;
end $$;

create or replace function public.join_guild(p_invite_code text)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); gid uuid;
begin
 if uid is null then raise exception 'authentication required'; end if;
 if exists(select 1 from public.guild_members where player_id=uid) then raise exception 'already in a guild'; end if;
 select id into gid from public.guilds where invite_code=upper(trim(p_invite_code));
 if gid is null then raise exception 'guild not found'; end if;
 insert into public.guild_members(guild_id,player_id) values(gid,uid); return gid;
end $$;

create or replace function public.create_player_tournament(p_title text,p_format text,p_starts_at timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); tid uuid;
begin
 if uid is null then raise exception 'authentication required'; end if;
 if p_starts_at<now()+interval '10 minutes' then raise exception 'start time must be at least 10 minutes ahead'; end if;
 insert into public.player_tournaments(host_id,title,format,starts_at) values(uid,trim(p_title),p_format,p_starts_at) returning id into tid;
 insert into public.tournament_entries(tournament_id,player_id) values(tid,uid); return tid;
end $$;

create or replace function public.enter_player_tournament(p_tournament_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 insert into public.tournament_entries(tournament_id,player_id)
 select id,auth.uid() from public.player_tournaments where id=p_tournament_id and status='registration' and starts_at>now();
 if not found then raise exception 'registration closed'; end if;
end $$;

create or replace function public.send_friend_gift(p_receiver uuid,p_coins integer,p_note text default '')
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); gid uuid;
begin
 if uid is null or uid=p_receiver then raise exception 'invalid recipient'; end if;
 if not exists(select 1 from public.friendships f where f.status='accepted' and ((f.user_a=uid and f.user_b=p_receiver) or (f.user_b=uid and f.user_a=p_receiver))) then raise exception 'recipient must be a friend'; end if;
 update public.profiles set mythic_coins=mythic_coins-p_coins where id=uid and mythic_coins>=p_coins;
 if not found then raise exception 'insufficient coins'; end if;
 insert into public.friend_gifts(sender_id,receiver_id,coins,note) values(uid,p_receiver,p_coins,trim(coalesce(p_note,''))) returning id into gid;return gid;
end $$;

create or replace function public.claim_friend_gift(p_gift_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare gift public.friend_gifts%rowtype;
begin
 update public.friend_gifts set claimed_at=now() where id=p_gift_id and receiver_id=auth.uid() and claimed_at is null returning * into gift;
 if not found then raise exception 'gift unavailable'; end if;
 update public.profiles set mythic_coins=mythic_coins+gift.coins where id=auth.uid() returning mythic_coins into gift.coins;
 return gift.coins;
end $$;

create or replace function public.start_player_expedition(p_card_id text,p_duration integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); eid uuid;
begin
 if uid is null or p_duration not in (4,8,12) then raise exception 'invalid expedition'; end if;
 if not exists(select 1 from public.player_decks d where d.player_id=uid and coalesce((d.card_counts->>p_card_id)::integer,0)>0) then raise exception 'card is not in your collection'; end if;
 insert into public.player_expeditions(player_id,card_id,duration_hours,ends_at,reward_coins)
 values(uid,p_card_id,p_duration,now()+make_interval(hours=>p_duration),p_duration*5) returning id into eid; return eid;
end $$;

create or replace function public.claim_player_expedition(p_expedition_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare reward integer;
begin
 update public.player_expeditions set claimed_at=now() where id=p_expedition_id and player_id=auth.uid() and claimed_at is null and ends_at<=now() returning reward_coins into reward;
 if not found then raise exception 'expedition is not ready'; end if;
 update public.profiles set mythic_coins=mythic_coins+reward where id=auth.uid();return reward;
end $$;

create or replace function public.save_match_replay(p_match_id uuid,p_title text,p_events jsonb,p_public boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); rid uuid; replay_events jsonb;
begin
 if uid is null or jsonb_typeof(p_events)<>'array' or jsonb_array_length(p_events)>500 then raise exception 'invalid replay'; end if;
 if not exists(select 1 from public.game_matches where id=p_match_id and status='completed' and uid in(player_one,player_two)) then raise exception 'match unavailable'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('state',state,'turn_user',turn_user,'captured_at',created_at) order by event_id),p_events) into replay_events from public.game_state_timeline where match_id=p_match_id;
 insert into public.game_replays(match_id,owner_id,title,events,is_public) values(p_match_id,uid,trim(coalesce(p_title,'Replay da Arena')),replay_events,p_public)
 on conflict(match_id,owner_id) do update set title=excluded.title,events=excluded.events,is_public=excluded.is_public returning id into rid;return rid;
end $$;

create or replace function public.set_replay_public(p_replay_id uuid,p_public boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 update public.game_replays set is_public=p_public where id=p_replay_id and owner_id=auth.uid();
 if not found then raise exception 'replay unavailable'; end if;
end $$;

create or replace function public.request_match_spectator(p_match_id uuid,p_delay_seconds integer default 60)
returns void language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); one_id uuid; two_id uuid;
begin
 select player_one,player_two into one_id,two_id from public.game_matches where id=p_match_id and status='active';
 if not found or uid in(one_id,two_id) then raise exception 'match unavailable'; end if;
 if not exists(select 1 from public.friendships f where f.status='accepted' and ((f.user_a=uid and f.user_b in(one_id,two_id)) or (f.user_b=uid and f.user_a in(one_id,two_id)))) then raise exception 'only friends can spectate'; end if;
 insert into public.match_spectators(match_id,spectator_id,requested_by,delay_seconds) values(p_match_id,uid,uid,greatest(30,least(300,p_delay_seconds))) on conflict(match_id,spectator_id) do update set delay_seconds=excluded.delay_seconds;
end $$;

create or replace function public.create_sandbox_room(p_rules jsonb default '{}')
returns public.sandbox_rooms language plpgsql security definer set search_path='' as $$
declare result public.sandbox_rooms%rowtype;
begin
 if auth.uid() is null or jsonb_typeof(p_rules)<>'object' then raise exception 'invalid sandbox rules'; end if;
 insert into public.sandbox_rooms(host_id,rules) values(auth.uid(),p_rules) returning * into result;return result;
end $$;

create or replace function public.publish_community_deck(p_title text,p_deck_code text,p_description text default '')
returns uuid language plpgsql security definer set search_path='' as $$
declare did uuid;
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 insert into public.community_decks(player_id,title,deck_code,description) values(auth.uid(),trim(p_title),trim(p_deck_code),trim(coalesce(p_description,''))) returning id into did;return did;
end $$;

create or replace function public.vote_community_deck(p_deck_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.community_decks where id=p_deck_id) then raise exception 'deck unavailable'; end if;
 insert into public.community_deck_votes(deck_id,player_id) values(p_deck_id,auth.uid()) on conflict do nothing;
end $$;

create or replace view public.public_match_meta with (security_invoker=false) as
 select mode,count(*)::integer as matches,
        count(*) filter(where outcome='victory')::integer as victories,
        count(*) filter(where outcome='defeat')::integer as defeats,
        count(*) filter(where outcome='draw')::integer as draws
 from public.match_history group by mode;
grant select on public.public_match_meta to authenticated;
revoke all on function public.list_friend_active_matches() from public,anon;
grant execute on function public.list_friend_active_matches() to authenticated;
revoke all on function public.get_delayed_spectator_snapshot(uuid) from public,anon;
grant execute on function public.get_delayed_spectator_snapshot(uuid) to authenticated;

do $$ declare f text; begin
 foreach f in array array['claim_mission(text)','create_guild(text,text)','join_guild(text)','create_player_tournament(text,text,timestamptz)','enter_player_tournament(uuid)','send_friend_gift(uuid,integer,text)','claim_friend_gift(uuid)','start_player_expedition(text,integer)','claim_player_expedition(uuid)','save_match_replay(uuid,text,jsonb,boolean)','set_replay_public(uuid,boolean)','request_match_spectator(uuid,integer)','create_sandbox_room(jsonb)','publish_community_deck(text,text,text)','vote_community_deck(uuid)'] loop
  execute 'revoke all on function public.'||f||' from public,anon';execute 'grant execute on function public.'||f||' to authenticated';
 end loop;
end $$;

-- Read access stays scoped; mutations happen through authenticated RPCs/client workflows.
do $$ declare t text; begin
  foreach t in array array['missions','mission_claims','guilds','guild_members','player_tournaments','tournament_entries','friend_gifts','player_expeditions','game_replays','game_state_timeline','match_spectators','sandbox_rooms','community_decks','community_deck_votes'] loop
    execute format('alter table public.%I enable row level security',t);
  end loop;
end $$;
drop policy if exists "Read active missions" on public.missions;
create policy "Read active missions" on public.missions for select to authenticated using(active);
drop policy if exists "Read guilds" on public.guilds;
create policy "Read guilds" on public.guilds for select to authenticated using(true);
drop policy if exists "Read guild members" on public.guild_members;
create policy "Read guild members" on public.guild_members for select to authenticated using(true);
drop policy if exists "Read open tournaments" on public.player_tournaments;
create policy "Read open tournaments" on public.player_tournaments for select to authenticated using(status in ('registration','in_progress','completed'));
drop policy if exists "Read tournament entries" on public.tournament_entries;
create policy "Read tournament entries" on public.tournament_entries for select to authenticated using(true);
drop policy if exists "Read community decks" on public.community_decks;
create policy "Read community decks" on public.community_decks for select to authenticated using(true);
drop policy if exists "Read community deck votes" on public.community_deck_votes;
create policy "Read community deck votes" on public.community_deck_votes for select to authenticated using(true);
drop policy if exists "Read own mission claims" on public.mission_claims;
create policy "Read own mission claims" on public.mission_claims for select to authenticated using(player_id=auth.uid());
drop policy if exists "Read own expeditions" on public.player_expeditions;
create policy "Read own expeditions" on public.player_expeditions for select to authenticated using(player_id=auth.uid());
drop policy if exists "Read own gifts" on public.friend_gifts;
create policy "Read own gifts" on public.friend_gifts for select to authenticated using(auth.uid() in(sender_id,receiver_id));
drop policy if exists "Read own replays" on public.game_replays;
create policy "Read own replays" on public.game_replays for select to authenticated using(owner_id=auth.uid() or is_public);
drop policy if exists "Read own match timeline" on public.game_state_timeline;
create policy "Read own match timeline" on public.game_state_timeline for select to authenticated using(exists(select 1 from public.game_matches g where g.id=match_id and auth.uid() in(g.player_one,g.player_two)));
drop policy if exists "Read own spectator requests" on public.match_spectators;
create policy "Read own spectator requests" on public.match_spectators for select to authenticated using(spectator_id=auth.uid() or requested_by=auth.uid());
drop policy if exists "Read sandbox rooms" on public.sandbox_rooms;
create policy "Read sandbox rooms" on public.sandbox_rooms for select to authenticated using(status='open' or host_id=auth.uid());

grant select on public.missions,public.guilds,public.guild_members,public.player_tournaments,public.tournament_entries,public.community_decks,public.community_deck_votes to authenticated;
grant select on public.mission_claims,public.player_expeditions,public.friend_gifts,public.game_replays,public.game_state_timeline,public.match_spectators,public.sandbox_rooms to authenticated;
commit;
