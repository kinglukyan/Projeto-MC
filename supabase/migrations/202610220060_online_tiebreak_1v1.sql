begin;
create table if not exists public.tiebreak_pvp_matches(
 id uuid primary key default gen_random_uuid(),
 player_one uuid not null references public.profiles(id) on delete cascade,
 player_two uuid not null references public.profiles(id) on delete cascade,
 request_one uuid not null,request_two uuid not null,
 payload jsonb not null,created_at timestamptz not null default now(),
 seen_one timestamptz,seen_two timestamptz,
 check(player_one<>player_two),unique(player_one,request_one),unique(player_two,request_two)
);
create index if not exists tiebreak_pvp_one on public.tiebreak_pvp_matches(player_one,created_at desc);
create index if not exists tiebreak_pvp_two on public.tiebreak_pvp_matches(player_two,created_at desc);
create table if not exists public.tiebreak_pvp_queue(
 player_id uuid primary key references public.profiles(id) on delete cascade,
 request_id uuid not null,deck_slot integer not null check(deck_slot between 1 and 7),deck_counts jsonb not null,queued_at timestamptz not null default now(),
 heartbeat_at timestamptz not null default now(),match_id uuid references public.tiebreak_pvp_matches(id) on delete cascade
);
create index if not exists tiebreak_pvp_waiting on public.tiebreak_pvp_queue(queued_at) where match_id is null;
alter table public.tiebreak_pvp_matches enable row level security;
alter table public.tiebreak_pvp_queue enable row level security;
revoke all on public.tiebreak_pvp_matches,public.tiebreak_pvp_queue from public,anon,authenticated;

create or replace function public._tb_pvp_snapshot(p_uid uuid,p_match_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.tiebreak_pvp_matches%rowtype;q public.tiebreak_pvp_queue%rowtype;name_one text;name_two text;
begin
 select x.* into m from public.tiebreak_pvp_matches x
 where (x.player_one=p_uid or x.player_two=p_uid) and
  ((p_match_id is not null and x.id=p_match_id) or (p_match_id is null and ((x.player_one=p_uid and x.seen_one is null) or (x.player_two=p_uid and x.seen_two is null))))
 order by x.created_at desc limit 1;
 if m.id is not null then
  select coalesce(p.nickname,p.display_name,'Jogador') into name_one from public.profiles p where p.id=m.player_one;
  select coalesce(p.nickname,p.display_name,'Jogador') into name_two from public.profiles p where p.id=m.player_two;
  return jsonb_build_object('status','matched','match_id',m.id,'result',m.payload||jsonb_build_object(
   'match_id',m.id,'standalone',true,'online_tiebreak',true,'my_side',case when p_uid=m.player_one then 'player_one' else 'player_two' end,
   'player_one_name',name_one,'player_two_name',name_two));
 end if;
 if p_match_id is not null then raise exception 'Partida indisponível para esta conta.';end if;
 select x.* into q from public.tiebreak_pvp_queue x where x.player_id=p_uid and x.match_id is null;
 if q.player_id is not null then return jsonb_build_object('status','waiting','queued_at',q.queued_at,'deck_slot',q.deck_slot);end if;
 return jsonb_build_object('status','idle');
end $$;

create or replace function public._tb_pvp_match(p_uid uuid) returns void
language plpgsql security definer set search_path='' as $$
declare a public.tiebreak_pvp_queue%rowtype;b public.tiebreak_pvp_queue%rowtype;pool_a jsonb;pool_b jsonb;result jsonb;mid uuid;
begin
 select q.* into a from public.tiebreak_pvp_queue q where q.player_id=p_uid and q.match_id is null for update;
 if a.player_id is null then return;end if;
 select q.* into b from public.tiebreak_pvp_queue q where q.player_id<>p_uid and q.match_id is null and q.heartbeat_at>now()-interval '45 seconds'
  and not exists(select 1 from public.game_matches g where g.status='active' and (g.player_one=q.player_id or g.player_two=q.player_id))
 order by q.queued_at,q.player_id limit 1 for update skip locked;
 if b.player_id is null then return;end if;
 -- Recheck ownership after waiting: inventory can change while players are queued.
 begin
  perform public._assert_owned_deck(a.player_id,a.deck_counts);
 exception when others then delete from public.tiebreak_pvp_queue q where q.player_id=a.player_id;return;end;
 begin
  perform public._assert_owned_deck(b.player_id,b.deck_counts);
 exception when others then delete from public.tiebreak_pvp_queue q where q.player_id=b.player_id;return;end;
 select coalesce(jsonb_agg(e.key),'[]') into pool_a from jsonb_each_text(a.deck_counts) e cross join lateral generate_series(1,e.value::integer) n
 where public._r_card(e.key)->>'kind'='unit' and not coalesce((public._r_card(e.key)->>'specialOnly')::boolean,false);
 select coalesce(jsonb_agg(e.key),'[]') into pool_b from jsonb_each_text(b.deck_counts) e cross join lateral generate_series(1,e.value::integer) n
 where public._r_card(e.key)->>'kind'='unit' and not coalesce((public._r_card(e.key)->>'specialOnly')::boolean,false);
 result:=public._tb_random_result(pool_a,pool_b);
 insert into public.tiebreak_pvp_matches(player_one,player_two,request_one,request_two,payload)
 values(a.player_id,b.player_id,a.request_id,b.request_id,result) returning id into mid;
 update public.tiebreak_pvp_queue q set match_id=mid where q.player_id in(a.player_id,b.player_id);
end $$;

create or replace function public.join_tiebreak_queue(p_slot integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();counts jsonb;snapshot jsonb;mid uuid;unit_count integer;total integer;
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 perform pg_advisory_xact_lock(hashtext('mythic-tiebreak-1v1'));
 select m.id into mid from public.tiebreak_pvp_matches m where (m.player_one=uid and m.request_one=p_request_id) or (m.player_two=uid and m.request_two=p_request_id) limit 1;
 if mid is not null then return public._tb_pvp_snapshot(uid,mid);end if;
 snapshot:=public._tb_pvp_snapshot(uid);
 if snapshot->>'status'='matched' then return snapshot;end if;
 if not coalesce((select s.enabled from public.solo_mode_settings s where s.id='tiebreak'),false) then raise exception 'O modo Desempate não está disponível agora.';end if;
 if not public._player_pvp_unlocked(uid) then raise exception 'Conclua o tutorial para jogar online.';end if;
 if exists(select 1 from public.game_matches g where g.status='active' and (g.player_one=uid or g.player_two=uid)) then raise exception 'Conclua a partida em andamento antes de entrar na fila.';end if;
 select d.card_counts into counts from public.player_saved_decks d where d.player_id=uid and d.slot=p_slot;
 if counts is null or p_request_id is null then raise exception 'Escolha um baralho salvo.';end if;
 perform public._assert_owned_deck(uid,counts);
 select coalesce(sum(e.value::integer),0),coalesce(sum(case when public._r_card(e.key)->>'kind'='unit' then e.value::integer else 0 end),0) into total,unit_count from jsonb_each_text(counts) e;
 if total<14 or total>35 or unit_count=0 then raise exception 'Escolha um baralho de 14 a 35 cartas que contenha personagens.';end if;
 perform public.cancel_matchmaking();
 delete from public.tiebreak_pvp_queue q where q.match_id is null and q.heartbeat_at<now()-interval '3 minutes';
 delete from public.tiebreak_pvp_queue q where q.player_id=uid and q.match_id is not null;
 insert into public.tiebreak_pvp_queue(player_id,request_id,deck_slot,deck_counts) values(uid,p_request_id,p_slot,counts)
 on conflict(player_id) do update set heartbeat_at=now();
 perform public._tb_pvp_match(uid);return public._tb_pvp_snapshot(uid);
end $$;

create or replace function public.get_tiebreak_queue(p_match_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();snapshot jsonb;
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 perform pg_advisory_xact_lock(hashtext('mythic-tiebreak-1v1'));
 if p_match_id is not null then return public._tb_pvp_snapshot(uid,p_match_id);end if;
 snapshot:=public._tb_pvp_snapshot(uid);if snapshot->>'status'='matched' then return snapshot;end if;
 if not coalesce((select s.enabled from public.solo_mode_settings s where s.id='tiebreak'),false) then
  delete from public.tiebreak_pvp_queue q where q.player_id=uid and q.match_id is null;return jsonb_build_object('status','unavailable');end if;
 if exists(select 1 from public.game_matches g where g.status='active' and (g.player_one=uid or g.player_two=uid)) then
  delete from public.tiebreak_pvp_queue q where q.player_id=uid and q.match_id is null;return jsonb_build_object('status','busy');end if;
 update public.tiebreak_pvp_queue q set heartbeat_at=now() where q.player_id=uid and q.match_id is null;
 perform public._tb_pvp_match(uid);return public._tb_pvp_snapshot(uid);
end $$;

create or replace function public.cancel_tiebreak_queue() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();snapshot jsonb;
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 perform pg_advisory_xact_lock(hashtext('mythic-tiebreak-1v1'));
 snapshot:=public._tb_pvp_snapshot(uid);if snapshot->>'status'='matched' then return snapshot;end if;
 delete from public.tiebreak_pvp_queue q where q.player_id=uid and q.match_id is null;return jsonb_build_object('status','idle');
end $$;

create or replace function public.ack_tiebreak_match(p_match_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 update public.tiebreak_pvp_matches m set seen_one=case when m.player_one=uid then coalesce(m.seen_one,now()) else m.seen_one end,
 seen_two=case when m.player_two=uid then coalesce(m.seen_two,now()) else m.seen_two end where m.id=p_match_id and (m.player_one=uid or m.player_two=uid);
 if not found then raise exception 'Partida indisponível para esta conta.';end if;
 delete from public.tiebreak_pvp_queue q where q.player_id=uid and q.match_id=p_match_id;
end $$;
-- Old clients must not create a bot duel for this mode after the 1v1 migration.
revoke all on function public.start_solo_tiebreak(integer,uuid) from public,anon,authenticated;
revoke all on function public._tb_pvp_snapshot(uuid,uuid),public._tb_pvp_match(uuid),public.join_tiebreak_queue(integer,uuid),public.get_tiebreak_queue(uuid),public.cancel_tiebreak_queue(),public.ack_tiebreak_match(uuid) from public,anon,authenticated;
grant execute on function public.join_tiebreak_queue(integer,uuid),public.get_tiebreak_queue(uuid),public.cancel_tiebreak_queue(),public.ack_tiebreak_match(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
