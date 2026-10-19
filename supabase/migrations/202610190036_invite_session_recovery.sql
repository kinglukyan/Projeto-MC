-- 036: sessões de fila/partida, recuperação e bloqueios precisos de convite.
-- Aplicar após 035. Não altera pontos, estrelas ou resultados concluídos.
begin;
alter table public.matchmaking_queue add column if not exists session_touched_at timestamptz;
-- Filas antigas usam joined_at até o próximo heartbeat do cliente.
create table if not exists public.match_session_presence(
 match_id uuid not null references public.game_matches(id) on delete cascade,
 player_id uuid not null references public.profiles(id) on delete cascade,
 touched_at timestamptz not null default clock_timestamp(),primary key(match_id,player_id)
);
alter table public.match_session_presence enable row level security;
revoke all on public.match_session_presence from public,anon,authenticated;

create or replace function public._queue_session_insert()
returns trigger language plpgsql security definer set search_path='' as $$
begin new.session_touched_at:=clock_timestamp();return new;end $$;
drop trigger if exists queue_session_insert on public.matchmaking_queue;
create trigger queue_session_insert before insert on public.matchmaking_queue for each row execute function public._queue_session_insert();

create or replace function public.touch_match_session(p_match_id uuid default null,p_queue boolean default false)
returns void language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 if p_queue then update public.matchmaking_queue set session_touched_at=clock_timestamp() where user_id=uid and status='waiting';end if;
 if p_match_id is not null then
  perform 1 from public.game_matches where id=p_match_id and status='active' and uid in(player_one,player_two,player_three,player_four) for update;
  if found then insert into public.match_session_presence(match_id,player_id) values(p_match_id,uid)
   on conflict(match_id,player_id) do update set touched_at=clock_timestamp();end if;
 end if;
end $$;

create or replace function public._release_idle_match_sessions(p_player uuid)
returns void language plpgsql security definer set search_path='' as $$
declare g record;
begin
 -- Somente filas sem confirmação de cliente há mais de 90 segundos.
 delete from public.matchmaking_queue where user_id=p_player and status='waiting' and coalesce(session_touched_at,joined_at)<clock_timestamp()-interval '90 seconds';
 -- Uma sessão só é encerrada após 15 min sem ação nem heartbeat de participante.
 -- SKIP LOCKED preserva qualquer partida recebendo uma jogada/heartbeat neste instante.
 for g in select m.id from public.game_matches m where m.status='active' and p_player in(m.player_one,m.player_two,m.player_three,m.player_four)
  and greatest(coalesce(m.turn_deadline,m.created_at),coalesce((select max(h.touched_at) from public.match_session_presence h where h.match_id=m.id),m.created_at))<clock_timestamp()-interval '15 minutes'
  for update of m skip locked loop
  update public.game_matches set status='abandoned',turn_user=null,finished_at=clock_timestamp() where id=g.id and status='active';
 end loop;
end $$;

create or replace function public.refresh_invite_sessions(p_friend_code text default null)
returns void language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); partner uuid; player uuid;
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 if p_friend_code is not null then
  select p.id into partner from public.profiles p where p.friend_code=upper(trim(p_friend_code)) and exists(
   select 1 from public.friendships f where f.status='accepted' and uid in(f.user_a,f.user_b) and p.id in(f.user_a,f.user_b));
  if partner is null then raise exception 'Escolha alguém da sua lista de amigos.';end if;
 end if;
 for player in select distinct u from unnest(array[uid,partner]) u where u is not null order by u loop
  perform pg_advisory_xact_lock(hashtextextended(player::text,350));
  perform public._release_idle_match_sessions(player);
 end loop;
end $$;
create or replace function public.create_duo_queue(p_mode text,p_partner_code text)
returns table(party_id uuid,partner_name text,party_status text)
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); partner uuid; pid uuid; lock_uid uuid; active_mid uuid;
begin
 if uid is null then raise exception 'Entre na sua conta para convidar.';end if;
 if p_mode is null or p_mode not in('normal','ranked') then raise exception 'Modo de partida inválido.';end if;
 select id into partner from public.profiles where friend_code=upper(trim(p_partner_code));
 if partner is null or partner=uid then raise exception 'Amigo indisponível.';end if;
 -- A mesma ordem de bloqueio evita convites cruzados e fila solo simultânea.
 for lock_uid in select u from unnest(array[uid,partner]) u order by u loop
  perform pg_advisory_xact_lock(hashtextextended(lock_uid::text,350));
 end loop;
 update public.duo_queue_parties set status='cancelled' where status='inviting' and created_at<now()-interval '5 minutes' and (uid in(host_id,partner_id) or partner in(host_id,partner_id));
 if not exists(select 1 from public.friendships f where f.status='accepted' and uid in(f.user_a,f.user_b) and partner in(f.user_a,f.user_b)) then raise exception 'Escolha alguém da sua lista de amigos.';end if;
 if not public._player_pvp_unlocked(uid) or not public._player_pvp_unlocked(partner) then raise exception 'Os dois jogadores precisam liberar o PvP.';end if;
 if exists(select 1 from public.duo_queue_parties q where q.status in('inviting','ready','queued') and (uid in(q.host_id,q.partner_id) or partner in(q.host_id,q.partner_id))) then raise exception 'Você ou seu amigo já está em uma sala ou fila.';end if;
 perform public._release_idle_match_sessions(uid);
 perform public._release_idle_match_sessions(partner);
 if exists(select 1 from public.matchmaking_queue where status='waiting' and user_id=uid) then
  raise exception using message='Você está na fila solo. Saia da fila para convidar.',detail=jsonb_build_object('kind','self_queue')::text;
 end if;
 if exists(select 1 from public.matchmaking_queue where status='waiting' and user_id=partner) then
  raise exception 'Seu amigo está na fila solo. Ele precisa sair da fila para receber o convite.';
 end if;
 select m.id into active_mid from public.game_matches m where m.status='active' and uid in(m.player_one,m.player_two,m.player_three,m.player_four) order by m.created_at desc limit 1;
 if active_mid is not null then
  raise exception using message='Você tem uma partida em andamento. Retome a partida antes de convidar.',detail=jsonb_build_object('kind','self_match','match_id',active_mid)::text;
 end if;
 if exists(select 1 from public.game_matches m where m.status='active' and partner in(m.player_one,m.player_two,m.player_three,m.player_four)) then
  raise exception 'Seu amigo está em uma partida em andamento. Aguarde ele terminar.';
 end if;
 insert into public.duo_queue_parties(mode,host_id,partner_id) values(p_mode,uid,partner) returning id into pid;
 return query select pid,coalesce(nullif(p.nickname,''),p.display_name),'inviting'::text from public.profiles p where p.id=partner;
end $$;

revoke all on function public._queue_session_insert(),public._release_idle_match_sessions(uuid) from public,anon,authenticated;
revoke all on function public.touch_match_session(uuid,boolean),public.refresh_invite_sessions(text),public.create_duo_queue(text,text) from public,anon;
grant execute on function public.touch_match_session(uuid,boolean),public.refresh_invite_sessions(text),public.create_duo_queue(text,text) to authenticated;
notify pgrst,'reload schema';
commit;
