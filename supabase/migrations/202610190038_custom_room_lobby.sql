begin;

-- Slots ímpares pertencem ao lado 1; pares ao lado 2. Observadores não ocupam equipes.
alter table public.sandbox_room_members add column if not exists lobby_slot integer;
with seats as (
 select room_id,player_id,row_number() over(partition by room_id order by joined_at,player_id)::integer as n
 from public.sandbox_room_members
)
update public.sandbox_room_members m set lobby_slot=s.n from seats s
where m.room_id=s.room_id and m.player_id=s.player_id and m.lobby_slot is null;
alter table public.sandbox_room_members add constraint sandbox_lobby_slot_unique unique(room_id,lobby_slot);
alter table public.sandbox_room_members add constraint sandbox_lobby_slot_range check(lobby_slot between 1 and 4);

create table public.custom_room_invitations(
 id uuid primary key default gen_random_uuid(),
 room_id uuid not null references public.sandbox_rooms(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 recipient_id uuid not null references public.profiles(id) on delete cascade,
 lobby_slot integer not null check(lobby_slot between 1 and 4),
 status text not null default 'pending' check(status in ('pending','accepted','declined','cancelled')),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '15 minutes',
 check(sender_id<>recipient_id)
);
create index custom_room_pending_recipient on public.custom_room_invitations(recipient_id,created_at desc) where status='pending';
alter table public.custom_room_invitations enable row level security;
revoke all on public.custom_room_invitations from public,anon,authenticated;

create function public.custom_room_snapshot(p_room_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.sandbox_rooms%rowtype; members jsonb; observer jsonb;
begin
 perform public._security_rpc_gate('custom_room_snapshot',120);
 select * into r from public.sandbox_rooms where id=p_room_id;
 if not found or not (r.host_id=auth.uid()
 or exists(select 1 from public.sandbox_room_members where room_id=r.id and player_id=auth.uid())
 or exists(select 1 from public.sandbox_room_spectators where room_id=r.id and spectator_id=auth.uid()))
 then raise exception 'Você não faz parte desta sala.';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'slot',m.lobby_slot,
 'name',coalesce(nullif(p.nickname,''),p.display_name,'Invocador'),'icon',p.equipped_avatar,'rating',p.rating_points) order by m.lobby_slot),'[]')
 into members from public.sandbox_room_members m join public.profiles p on p.id=m.player_id where m.room_id=r.id;
 select jsonb_build_object('id',p.id,'name',coalesce(nullif(p.nickname,''),p.display_name,'Observador'))
 into observer from public.sandbox_room_spectators s join public.profiles p on p.id=s.spectator_id where s.room_id=r.id;
 return jsonb_build_object('id',r.id,'host_id',r.host_id,'code',r.invite_code,'status',r.status,
 'rules',r.rules,'match_id',r.match_id,'members',members,'observer',observer);
end $$;

create function public.custom_room_current()
returns jsonb language plpgsql security definer set search_path='' as $$
declare rid uuid;
begin
 perform public._security_rpc_gate('custom_room_current',60);
 select r.id into rid from public.sandbox_rooms r where r.status='open' and
 (r.host_id=auth.uid() or exists(select 1 from public.sandbox_room_members m where m.room_id=r.id and m.player_id=auth.uid())
 or exists(select 1 from public.sandbox_room_spectators s where s.room_id=r.id and s.spectator_id=auth.uid()))
 order by r.created_at desc limit 1;
 if rid is null then return null;end if;
 return public.custom_room_snapshot(rid);
end $$;

create function public.custom_room_create(p_rules jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.sandbox_rooms%rowtype;cards integer;opening integer;seconds integer;
begin
 perform public._security_rpc_gate('custom_room_create',10);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,38));
 if public.custom_room_current() is not null then raise exception 'Saia da sala atual antes de criar outra.';end if;
 if p_rules is null or jsonb_typeof(p_rules)<>'object' then raise exception 'Regras inválidas.';end if;
 cards:=(p_rules->>'max_cards')::integer;opening:=(p_rules->>'starting_hand')::integer;seconds:=(p_rules->>'turn_seconds')::integer;
 if cards is null or cards not in(14,20,25,30,35) or opening is null or opening not between 3 and 5
 or seconds is null or seconds not in(30,45,60) then raise exception 'Regras fora dos limites permitidos.';end if;
 insert into public.sandbox_rooms(host_id,rules) values(auth.uid(),jsonb_build_object('max_cards',cards,'starting_hand',opening,'turn_seconds',seconds,'max_players',4)) returning * into r;
 insert into public.sandbox_room_members(room_id,player_id,lobby_slot) values(r.id,auth.uid(),1);
 return public.custom_room_snapshot(r.id);
end $$;

create function public.custom_room_join(p_code text,p_role text,p_invitation_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.sandbox_rooms%rowtype;i public.custom_room_invitations%rowtype;chosen integer;current_room jsonb;
begin
 perform public._security_rpc_gate('custom_room_join',20);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,38));
 if p_role not in('player','observer') or p_role is null or length(trim(p_code)) not between 6 and 8 then raise exception 'Escolha jogar ou observar e informe um código válido.';end if;
 select * into r from public.sandbox_rooms where invite_code=upper(trim(p_code)) and status='open' for update;
 if not found then raise exception 'Sala indisponível ou código inválido.';end if;
 current_room:=public.custom_room_current();
 if current_room is not null and current_room->>'id'<>r.id::text then raise exception 'Saia da sua sala atual para entrar em outra.';end if;
 if exists(select 1 from public.sandbox_room_members where room_id=r.id and player_id=auth.uid())
 or exists(select 1 from public.sandbox_room_spectators where room_id=r.id and spectator_id=auth.uid()) then return public.custom_room_snapshot(r.id);end if;
 if p_invitation_id is not null then
  select * into i from public.custom_room_invitations where id=p_invitation_id and room_id=r.id and recipient_id=auth.uid() and status='pending' and expires_at>now() for update;
  if not found then raise exception 'O convite expirou. Peça um novo convite.';end if;
 end if;
 if p_role='observer' then
  if exists(select 1 from public.sandbox_room_spectators where room_id=r.id) then raise exception 'A vaga de observador já está ocupada.';end if;
  insert into public.sandbox_room_spectators(room_id,spectator_id) values(r.id,auth.uid());
 else
  chosen:=i.lobby_slot;
  if chosen is not null and exists(select 1 from public.sandbox_room_members where room_id=r.id and lobby_slot=chosen) then raise exception 'A vaga convidada já foi ocupada.';end if;
  if chosen is null then
   select n into chosen from generate_series(1,4) n where not exists(select 1 from public.sandbox_room_members where room_id=r.id and lobby_slot=n) order by n limit 1;
  end if;
  if chosen is null then raise exception 'A sala está cheia. Você pode tentar observar.';end if;
  insert into public.sandbox_room_members(room_id,player_id,lobby_slot) values(r.id,auth.uid(),chosen);
 end if;
 update public.custom_room_invitations set status='accepted' where room_id=r.id and recipient_id=auth.uid() and status='pending';
 return public.custom_room_snapshot(r.id);
end $$;

create function public.custom_room_leave(p_room_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare r public.sandbox_rooms%rowtype;
begin
 perform public._security_rpc_gate('custom_room_leave',20);
 select * into r from public.sandbox_rooms where id=p_room_id for update;
 if not found or r.status<>'open' then return;end if;
 if r.host_id=auth.uid() then
  update public.sandbox_rooms set status='closed' where id=r.id;
  update public.custom_room_invitations set status='cancelled' where room_id=r.id and status='pending';
 else
  delete from public.sandbox_room_members where room_id=r.id and player_id=auth.uid();
  delete from public.sandbox_room_spectators where room_id=r.id and spectator_id=auth.uid();
 end if;
end $$;

create function public.custom_room_invite(p_room_id uuid,p_friend_id uuid,p_slot integer)
returns void language plpgsql security definer set search_path='' as $$
declare r public.sandbox_rooms%rowtype;
begin
 perform public._security_rpc_gate('custom_room_invite',20);
 select * into r from public.sandbox_rooms where id=p_room_id and host_id=auth.uid() and status='open' for update;
 if not found then raise exception 'Somente o anfitrião pode convidar para esta sala.';end if;
 if p_slot is null or p_slot not between 1 and 4 or exists(select 1 from public.sandbox_room_members where room_id=r.id and lobby_slot=p_slot) then raise exception 'Escolha uma vaga livre.';end if;
 if p_friend_id=auth.uid() or not exists(select 1 from public.friendships where status='accepted' and ((user_a=auth.uid() and user_b=p_friend_id) or (user_b=auth.uid() and user_a=p_friend_id))) then raise exception 'Escolha alguém da sua lista de amigos.';end if;
 if exists(select 1 from public.sandbox_room_members where room_id=r.id and player_id=p_friend_id) or exists(select 1 from public.sandbox_room_spectators where room_id=r.id and spectator_id=p_friend_id) then raise exception 'Este amigo já está na sala.';end if;
 update public.custom_room_invitations set status='cancelled' where room_id=r.id and recipient_id=p_friend_id and status='pending';
 insert into public.custom_room_invitations(room_id,sender_id,recipient_id,lobby_slot) values(r.id,auth.uid(),p_friend_id,p_slot);
end $$;

create function public.custom_room_inbox()
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform public._security_rpc_gate('custom_room_inbox',60);
 return (select jsonb_build_object('id',i.id,'code',r.invite_code,'slot',i.lobby_slot,'name',coalesce(nullif(p.nickname,''),p.display_name,'Seu amigo'),'icon',p.equipped_avatar,'rating',p.rating_points)
 from public.custom_room_invitations i join public.sandbox_rooms r on r.id=i.room_id join public.profiles p on p.id=i.sender_id
 where i.recipient_id=auth.uid() and i.status='pending' and i.expires_at>now() and r.status='open' order by i.created_at desc limit 1);
end $$;

create function public.custom_room_decline(p_invitation_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform public._security_rpc_gate('custom_room_decline',20);
 update public.custom_room_invitations set status='declined' where id=p_invitation_id and recipient_id=auth.uid() and status='pending';
end $$;

create function public.custom_room_start(p_room_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.sandbox_rooms%rowtype;one_count integer;two_count integer;players uuid[];
 state jsonb;resources jsonb;side jsonb;pool jsonb;hand jsonb;deck jsonb;k text;mid uuid;
begin
 perform public._security_rpc_gate('custom_room_start',10);
 select * into r from public.sandbox_rooms where id=p_room_id and host_id=auth.uid() and status='open' for update;
 if not found then raise exception 'Somente o anfitrião pode iniciar uma sala aberta.';end if;
 select count(*) filter(where lobby_slot%2=1),count(*) filter(where lobby_slot%2=0),array_agg(player_id order by lobby_slot)
 into one_count,two_count,players from public.sandbox_room_members where room_id=r.id;
 if one_count<>two_count or one_count not in(1,2) then raise exception 'É necessário um jogador de cada lado ou duas duplas completas.';end if;
 if exists(select 1 from public.account_restrictions where player_id=any(players) and banned_until>now()) then raise exception 'Um participante está temporariamente suspenso.';end if;
 if exists(select 1 from public.matchmaking_queue where user_id=any(players) and status='waiting')
 or exists(select 1 from public.duo_queue_parties where status in('inviting','ready','queued') and (host_id=any(players) or partner_id=any(players)))
 then raise exception 'Um participante está em outra sala ou fila. Ele precisa sair antes de começar.';end if;
 if one_count=1 then
  -- Ordem por lado, inclusive se o jogador tiver ocupado a segunda vaga da equipe.
  select array_agg(player_id order by lobby_slot%2 desc,lobby_slot) into players from public.sandbox_room_members where room_id=r.id;
  state:=public._new_online_game_state(players[1],players[2]);
  resources:=jsonb_build_object('player_one',state->'player_one','player_two',state->'player_two');
 else
  -- Slots 1 e 3 são aliados; slots 2 e 4 são adversários.
  state:=public._new_online_duo_state(players[1],players[3],players[2],players[4]);
  resources:=state->'privatePlayers';
 end if;
 for k,side in select key,value from jsonb_each(resources) loop
  pool:=coalesce(side->'hand','[]')||coalesce(side->'deck','[]');
  select coalesce(jsonb_agg(value order by ordinality),'[]') into pool from jsonb_array_elements(pool) with ordinality e(value,ordinality) where ordinality<=(r.rules->>'max_cards')::integer;
  select coalesce(jsonb_agg(value order by ordinality) filter(where ordinality<=(r.rules->>'starting_hand')::integer),'[]'),
  coalesce(jsonb_agg(value order by ordinality) filter(where ordinality>(r.rules->>'starting_hand')::integer),'[]')
  into hand,deck from jsonb_array_elements(pool) with ordinality e(value,ordinality);
  side:=jsonb_set(jsonb_set(side,'{hand}',hand),'{deck}',deck);
  resources:=jsonb_set(resources,array[k],side);
 end loop;
 state:=state||jsonb_build_object('sandboxRules',r.rules,'turnSeconds',(r.rules->>'turn_seconds')::integer);
 if one_count=1 then
  state:=state||resources;
  insert into public.game_matches(player_one,player_two,mode,status,state,turn_user) values(players[1],players[2],'friend','active',state,players[1]) returning id into mid;
 else
  insert into public.game_matches(player_one,player_two,player_three,player_four,team_size,mode,status,state,turn_user)
  values(players[1],players[2],players[3],players[4],2,'friend','active',state-'privatePlayers',players[1]) returning id into mid;
  insert into public.duo_match_players(match_id,player_id,team,seat) values(mid,players[1],1,1),(mid,players[3],1,2),(mid,players[2],2,1),(mid,players[4],2,2);
  insert into public.duo_player_states(match_id,player_id,private_state) select mid,key::uuid,value from jsonb_each(resources);
  perform public.record_duo_deck_usage(mid);
 end if;
 update public.sandbox_rooms set status='playing',match_id=mid where id=r.id;
 update public.custom_room_invitations set status='cancelled' where room_id=r.id and status='pending';
 return mid;
end $$;

revoke all on function public.custom_room_snapshot(uuid),public.custom_room_current(),public.custom_room_create(jsonb),public.custom_room_join(text,text,uuid),public.custom_room_leave(uuid),public.custom_room_invite(uuid,uuid,integer),public.custom_room_inbox(),public.custom_room_decline(uuid),public.custom_room_start(uuid) from public,anon;
grant execute on function public.custom_room_snapshot(uuid),public.custom_room_current(),public.custom_room_create(jsonb),public.custom_room_join(text,text,uuid),public.custom_room_leave(uuid),public.custom_room_invite(uuid,uuid,integer),public.custom_room_inbox(),public.custom_room_decline(uuid),public.custom_room_start(uuid) to authenticated;

-- Clientes antigos não podem inserir participantes sem uma posição no novo lobby.
revoke execute on function public.create_sandbox_room(jsonb),public.join_sandbox_room(text),public.join_sandbox_spectator(text),public.start_sandbox_match(uuid),public.register_sandbox_match(uuid,uuid) from public,anon,authenticated;

commit;
