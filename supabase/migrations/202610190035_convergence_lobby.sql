-- 035: aceitar convite forma o lobby; somente Convergir inicia a fila.
-- Aplicar depois de 202610190034_rank_strix_stars.sql.
begin;
alter table public.duo_queue_parties drop constraint if exists duo_queue_parties_status_check;
alter table public.duo_queue_parties add constraint duo_queue_parties_status_check check(status in('inviting','ready','queued','matched','cancelled'));
drop index if exists public.duo_queue_one_active_host;
drop index if exists public.duo_queue_one_active_partner;
create unique index duo_queue_one_active_host on public.duo_queue_parties(host_id) where status in('inviting','ready','queued');
create unique index duo_queue_one_active_partner on public.duo_queue_parties(partner_id) where status in('inviting','ready','queued');

create or replace function public.get_duo_lobby()
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); party public.duo_queue_parties%rowtype; members jsonb;
begin
 if uid is null then raise exception 'Entre na sua conta.';end if;
 update public.duo_queue_parties set status='cancelled' where status='inviting' and created_at<now()-interval '5 minutes' and uid in(host_id,partner_id);
 select q.* into party from public.duo_queue_parties q where uid in(q.host_id,q.partner_id) and
  (q.status in('inviting','ready','queued') or (q.status='matched' and exists(select 1 from public.game_matches m where m.id=q.match_id and m.status='active')))
 order by q.created_at desc limit 1;
 if not found then return null;end if;
 select jsonb_agg(jsonb_build_object('id',p.id,'name',coalesce(nullif(p.nickname,''),p.display_name),'icon',p.equipped_avatar,'rating',p.rating_points))
 into members from public.profiles p where p.id in(party.host_id,party.partner_id);
 return to_jsonb(party)||jsonb_build_object('members',members,'expires_at',party.created_at+interval '5 minutes');
end $$;

create or replace function public.create_duo_queue(p_mode text,p_partner_code text)
returns table(party_id uuid,partner_name text,party_status text)
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); partner uuid; pid uuid; lock_uid uuid;
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
 if exists(select 1 from public.matchmaking_queue q where q.status='waiting' and q.user_id in(uid,partner)) or exists(select 1 from public.game_matches m where m.status='active' and (uid in(m.player_one,m.player_two,m.player_three,m.player_four) or partner in(m.player_one,m.player_two,m.player_three,m.player_four))) then raise exception 'Você ou seu amigo está em uma busca ou partida.';end if;
 insert into public.duo_queue_parties(mode,host_id,partner_id) values(p_mode,uid,partner) returning id into pid;
 return query select pid,coalesce(nullif(p.nickname,''),p.display_name),'inviting'::text from public.profiles p where p.id=partner;
end $$;

create or replace function public.respond_duo_queue_invite(p_party_id uuid,p_accept boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); party public.duo_queue_parties%rowtype;
begin
 if uid is null or p_accept is null then raise exception 'Resposta inválida.';end if;
 select * into party from public.duo_queue_parties where id=p_party_id and partner_id=uid for update;
 if not found then raise exception 'Convite indisponível.';end if;
 if p_accept and party.status='ready' then return jsonb_build_object('status','ready','party_id',party.id);end if;
 if party.status<>'inviting' then raise exception 'Este convite já foi respondido.';end if;
 if party.created_at<now()-interval '5 minutes' then
  update public.duo_queue_parties set status='cancelled' where id=party.id;
  return jsonb_build_object('status','expired');
 end if;
 if not p_accept then update public.duo_queue_parties set status='cancelled' where id=party.id;return jsonb_build_object('status','declined');end if;
 if not public._player_pvp_unlocked(uid) then raise exception 'Conclua o tutorial para liberar o PvP.';end if;
 update public.duo_queue_parties set status='ready' where id=party.id;
 return jsonb_build_object('status','ready','party_id',party.id);
end $$;

create or replace function public.start_duo_lobby_queue(p_party_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); party public.duo_queue_parties%rowtype;
begin
 if uid is null then raise exception 'Entre na conta para convergir.';end if;
 select * into party from public.duo_queue_parties where id=p_party_id and host_id=uid for update;
 if not found then raise exception 'Somente o anfitrião inicia a fila.';end if;
 if party.status='matched' then return jsonb_build_object('status','matched','match_id',party.match_id);end if;
 if party.status not in('ready','queued') then raise exception 'Aguarde seu amigo entrar na sala.';end if;
 if not public._player_pvp_unlocked(party.host_id) or not public._player_pvp_unlocked(party.partner_id) then raise exception 'Os dois jogadores precisam liberar o PvP.';end if;
 if exists(select 1 from public.matchmaking_queue q where q.status='waiting' and q.user_id in(party.host_id,party.partner_id)) or exists(select 1 from public.game_matches m where m.status='active' and (party.host_id in(m.player_one,m.player_two,m.player_three,m.player_four) or party.partner_id in(m.player_one,m.player_two,m.player_three,m.player_four))) then raise exception 'Um integrante está em outra busca ou partida.';end if;
 update public.duo_queue_parties set status='queued' where id=party.id;
 return public.try_match_duo_queue(party.id);
end $$;

create or replace function public.cancel_duo_queue()
returns void language plpgsql security definer set search_path='' as $$
begin
 update public.duo_queue_parties set status=case when status='queued' then 'ready' else 'cancelled' end where auth.uid() in(host_id,partner_id) and status in('inviting','queued');
end $$;
create or replace function public.leave_duo_lobby()
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entre na conta.';end if;
 update public.duo_queue_parties set status='cancelled' where auth.uid() in(host_id,partner_id) and status in('inviting','ready','queued');
end $$;

create or replace function public.join_matchmaking(p_mode text default 'normal')
returns table(queue_status text,match_id uuid,opponent_id uuid) language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entre na conta.';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,350));
 if exists(select 1 from public.duo_queue_parties where status in('inviting','ready','queued') and auth.uid() in(host_id,partner_id)) then raise exception 'Saia da sala em dupla antes de entrar solo.';end if;
 return query select * from public._join_matchmaking_solo(p_mode);
end $$;
revoke all on function public.get_duo_lobby(),public.start_duo_lobby_queue(uuid),public.leave_duo_lobby(),public.create_duo_queue(text,text),public.respond_duo_queue_invite(uuid,boolean),public.cancel_duo_queue(),public.join_matchmaking(text) from public,anon;
grant execute on function public.get_duo_lobby(),public.start_duo_lobby_queue(uuid),public.leave_duo_lobby(),public.create_duo_queue(text,text),public.respond_duo_queue_invite(uuid,boolean),public.cancel_duo_queue(),public.join_matchmaking(text) to authenticated;
notify pgrst,'reload schema';
commit;
