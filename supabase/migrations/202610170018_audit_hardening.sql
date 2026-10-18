-- Auditoria: aplicar após 017, junto com a atualização do site.
-- Não altera poderes, sorteios ou regras das cartas.
begin;
do $prerequisite$
begin
 if to_regprocedure('public._get_online_match_before_icons(uuid)') is null then raise exception 'Aplique o SQL 017 antes do SQL 018.';end if;
end $prerequisite$;

-- RLS protege linhas; mãos, baralhos e timeline também precisam de isolamento.
create or replace function public._audit_mask_pool(pool jsonb,keep_first boolean default false)
returns jsonb language sql immutable set search_path='' as $$
 select coalesce(jsonb_agg(case when keep_first and ordinality=1 then value else 'null'::jsonb end order by ordinality),'[]'::jsonb)
 from jsonb_array_elements(case when jsonb_typeof(pool)='array' then pool else '[]'::jsonb end) with ordinality;
$$;
create or replace function public._audit_public_state(s jsonb,viewer_team text default null,viewer_id uuid default null)
returns jsonb language plpgsql stable set search_path='' as $$
declare side_key text;side jsonb;pending jsonb:=s->'pendingEffect';peek boolean;
begin
 s:=coalesce(s,'{}'::jsonb)-'privatePlayers'-'privatePlayer';
 foreach side_key in array array['player_one','player_two'] loop
   side:=s->side_key;if side is null then continue;end if;
   peek:=viewer_id is not null and pending->>'actor'=viewer_id::text and pending#>>'{event,op}'='foresight' and side_key=viewer_team;
   side:=jsonb_set(side,'{deck}',public._audit_mask_pool(side->'deck',peek),true);
   if side_key is distinct from viewer_team then
     side:=jsonb_set(side-'privateEffects','{hand}',public._audit_mask_pool(side->'hand'),true);
   end if;
   s:=jsonb_set(s,array[side_key],side,true);
 end loop;
 -- A fila pode conter cartas ainda não reveladas ao adversário.
 s:=s-'effectQueue';
 if pending is not null and (viewer_id is null or pending->>'actor' is distinct from viewer_id::text) then
   s:=jsonb_set(s,'{pendingEffect}',jsonb_build_object('id',pending->>'id','actor',pending->>'actor','title',pending->>'title','options','[]'::jsonb),true);
 end if;
 return s;
end $$;

do $originals$
begin
 if to_regprocedure('public._audit_get_online_match(uuid)') is null then
   alter function public.get_online_match(uuid) rename to _audit_get_online_match;
 end if;
 if to_regprocedure('public._audit_submit_game_action(uuid,jsonb)') is null then
   alter function public.submit_game_action(uuid,jsonb) rename to _audit_submit_game_action;
 end if;
end $originals$;
create or replace function public.get_online_match(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' stable as $$
declare result jsonb;game jsonb;s jsonb;personal jsonb;team text;peek boolean;
begin
 if auth.uid() is null then raise exception 'Entre na conta.';end if;
 result:=public._audit_get_online_match(p_match_id);if result is null then return null;end if;
 game:=result->'match';personal:=game#>'{state,privatePlayer}';team:=result->>'my_team';
 s:=public._audit_public_state(game->'state',team,auth.uid());
 if personal is not null then
   peek:=game#>>'{state,pendingEffect,actor}'=auth.uid()::text and game#>>'{state,pendingEffect,event,op}'='foresight';
   personal:=jsonb_set(personal,'{deck}',public._audit_mask_pool(personal->'deck',coalesce(peek,false)),true);
   s:=jsonb_set(s,'{privatePlayer}',personal,true);
 end if;
 return jsonb_set(result,'{match,state}',s,true);
end $$;
create or replace function public.submit_game_action(p_match_id uuid,p_action jsonb)
returns public.game_matches language plpgsql security definer set search_path='' as $$
declare result public.game_matches%rowtype;
begin
 if auth.uid() is null or jsonb_typeof(p_action) is distinct from 'object' or octet_length(p_action::text)>8192 then raise exception 'Ação inválida.';end if;
 result:=public._audit_submit_game_action(p_match_id,p_action);
 result.state:=public.get_online_match(p_match_id)#>'{match,state}';
 return result;
end $$;

-- Nunca publique o JSON privado por REST ou Realtime.
revoke select on public.game_matches from public,anon,authenticated;
revoke select(state) on public.game_matches from public,anon,authenticated;
do $columns$
declare column_list text;
begin
 select string_agg(quote_ident(attname),',') into column_list from pg_attribute
 where attrelid='public.game_matches'::regclass and attnum>0 and not attisdropped and attname<>'state';
 execute 'grant select ('||column_list||') on public.game_matches to authenticated';
end $columns$;
revoke all on public.game_state_timeline from public,anon,authenticated;
revoke select on public.duo_player_states from public,anon,authenticated;
revoke select(private_state) on public.duo_player_states from public,anon,authenticated;

-- Sinal sem cartas privadas: mantém notificações em tempo real.
create table if not exists public.match_update_signals(
 match_id uuid primary key references public.game_matches(id) on delete cascade,
 version bigint not null default 1,updated_at timestamptz not null default now()
);
alter table public.match_update_signals enable row level security;
revoke all on public.match_update_signals from public,anon,authenticated;
grant select on public.match_update_signals to authenticated;
drop policy if exists participant_match_signal on public.match_update_signals;
create policy participant_match_signal on public.match_update_signals for select to authenticated
 using(exists(select 1 from public.game_matches g where g.id=match_id and auth.uid() in(g.player_one,g.player_two,g.player_three,g.player_four)));
create or replace function public._audit_match_signal() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.match_update_signals(match_id) values(new.id)
 on conflict(match_id) do update set version=public.match_update_signals.version+1,updated_at=clock_timestamp();return new;
end $$;
drop trigger if exists audit_match_signal on public.game_matches;
create trigger audit_match_signal after insert or update of state,status,turn_user on public.game_matches
 for each row execute function public._audit_match_signal();
insert into public.match_update_signals(match_id) select id from public.game_matches where status='active' on conflict do nothing;
do $realtime$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime' and puballtables) then
   raise exception 'A publicação Realtime está em FOR ALL TABLES. Configure uma publicação explícita antes do SQL 018 para não publicar estados privados.';
 end if;
 if exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='game_matches') then
   alter publication supabase_realtime drop table public.game_matches;
 end if;
 if exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='duo_player_states') then
   alter publication supabase_realtime drop table public.duo_player_states;
 end if;
 if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='match_update_signals') then
   alter publication supabase_realtime add table public.match_update_signals;
 end if;
end $realtime$;

create or replace function public.get_delayed_spectator_snapshot(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' stable as $$
declare delay integer;snapshot jsonb;
begin
 select delay_seconds into delay from public.match_spectators where match_id=p_match_id and spectator_id=auth.uid();
 if not found then raise exception 'Acesso de espectador não autorizado.';end if;
 select jsonb_build_object('state',public._audit_public_state(t.state),'turn_user',t.turn_user,'captured_at',t.created_at)
 into snapshot from public.game_state_timeline t where t.match_id=p_match_id and t.created_at<=now()-make_interval(secs=>delay)
 order by t.event_id desc limit 1;return snapshot;
end $$;
create or replace function public.save_match_replay(p_match_id uuid,p_title text,p_events jsonb,p_public boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();rid uuid;events jsonb;
begin
 if uid is null or not exists(select 1 from public.game_matches where id=p_match_id and status='completed' and uid in(player_one,player_two,player_three,player_four)) then raise exception 'Partida indisponível.';end if;
 if char_length(btrim(coalesce(p_title,'')))>80 then raise exception 'Título muito longo.';end if;
 -- Somente eventos registrados no servidor; nunca aceite HTML/estado do navegador.
 select coalesce(jsonb_agg(jsonb_build_object('state',public._audit_public_state(state),'turn_user',turn_user,'captured_at',created_at) order by event_id),'[]'::jsonb)
 into events from (select state,turn_user,created_at,event_id from public.game_state_timeline where match_id=p_match_id order by event_id limit 500) timeline;
 insert into public.game_replays(match_id,owner_id,title,events,is_public)
 values(p_match_id,uid,coalesce(nullif(btrim(p_title),''),'Replay da Arena'),events,coalesce(p_public,false))
 on conflict(match_id,owner_id) do update set title=excluded.title,events=excluded.events,is_public=excluded.is_public returning id into rid;
 return rid;
end $$;
-- Remova cartas privadas de replays antigos, preservando as versões originais fora da API.
create table if not exists public.audit_replay_backup(replay_id uuid primary key,events jsonb not null,archived_at timestamptz not null default now());
alter table public.audit_replay_backup enable row level security;
revoke all on public.audit_replay_backup from public,anon,authenticated;
insert into public.audit_replay_backup(replay_id,events) select id,events from public.game_replays on conflict do nothing;
update public.game_replays r set events=(select coalesce(jsonb_agg(case when jsonb_typeof(e.value)='object' and jsonb_typeof(e.value->'state')='object' then jsonb_set(e.value,'{state}',public._audit_public_state(e.value->'state')) else '{}'::jsonb end order by e.ordinality),'[]'::jsonb) from jsonb_array_elements(r.events) with ordinality e);

-- Tutoriais e inventário dependem de campos controlados no servidor.
create or replace function public._player_pvp_unlocked(p_player_id uuid)
returns boolean language sql security definer set search_path='' stable as $$
 select coalesce(tutorial_completed,false) or coalesce(xp,0)>=100 from public.profiles where id=p_player_id;
$$;
revoke update(equipped_avatar,equipped_battlefield,equipped_hand) on public.profiles from authenticated;

-- Admin por identidade verificada, em vez de confiar só no e-mail do JWT.
create or replace function public.is_site_admin() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.users where id=auth.uid() and lower(email)='santoslucasalmeida@gmail.com' and email_confirmed_at is not null);
$$;
create or replace function public._inventory_admin(uid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.users where id=uid and lower(email)='santoslucasalmeida@gmail.com' and email_confirmed_at is not null);
$$;

-- Índices para as consultas de perfil, presentes e carregamento inicial.
create index if not exists audit_history_player_date on public.match_history(player_id,completed_at desc);
create index if not exists audit_expedition_player_started on public.player_expeditions(player_id,started_at desc);
create index if not exists audit_friend_gifts_unclaimed on public.friend_gifts(receiver_id,created_at desc) where claimed_at is null;
create index if not exists audit_card_gifts_unclaimed on public.friend_card_gifts(receiver_id,created_at desc) where claimed_at is null;
create index if not exists audit_guardian_player_claimed on public.guardian_match_claims(player_id,claimed_at desc);
create index if not exists audit_matches_deadline on public.game_matches(turn_deadline) where status='active';

-- Transferir ou reservar uma carta deve afetar a coleção, não criar cópias ao editar decks.
create or replace function public._audit_reserved_copies(uid uuid,cid text) returns integer
language sql stable security definer set search_path='' as $$
 select coalesce(max(qty),0) from (
  select coalesce((card_counts->>cid)::integer,0) qty from public.player_decks where player_id=uid
  union all select coalesce((card_counts->>cid)::integer,0) from public.player_saved_decks where player_id=uid
 ) decks;
$$;
create or replace function public.send_friend_card_gift(p_receiver uuid,p_card_id text)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();gift_id uuid;quantity integer;
begin
 if uid is null or p_receiver is null or uid=p_receiver or p_card_id is null or p_card_id not in('soldado-esparta','athena','lobo-alfa','guardiao-nordico','medusa') then raise exception 'Presente inválido.';end if;
 if not exists(select 1 from public.friendships where status='accepted' and uid in(user_a,user_b) and p_receiver in(user_a,user_b)) then raise exception 'O destinatário precisa ser seu amigo.';end if;
 perform 1 from public.profiles where id=uid for update;
 select copies into quantity from public.player_card_copies where player_id=uid and card_id=p_card_id for update;
 if coalesce(quantity,0)<2 then raise exception 'Mantenha pelo menos uma cópia na coleção.';end if;
 if quantity-1<public._audit_reserved_copies(uid,p_card_id) then raise exception 'Retire uma cópia dos seus baralhos antes de enviá-la.';end if;
 update public.player_card_copies set copies=copies-1 where player_id=uid and card_id=p_card_id;
 insert into public.friend_card_gifts(sender_id,receiver_id,card_id) values(uid,p_receiver,p_card_id) returning id into gift_id;
 return gift_id;
end $$;
create or replace function public.claim_friend_card_gift(p_gift_id uuid)
returns text language plpgsql security definer set search_path='' as $$
declare gift public.friend_card_gifts%rowtype;uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'Entre na conta.';end if;
 perform 1 from public.profiles where id=uid for update;
 update public.friend_card_gifts set claimed_at=now() where id=p_gift_id and receiver_id=uid and claimed_at is null returning * into gift;
 if not found then raise exception 'Presente indisponível ou já resgatado.';end if;
 insert into public.player_card_copies(player_id,card_id,copies) values(uid,gift.card_id,1)
 on conflict(player_id,card_id) do update set copies=public.player_card_copies.copies+1;
 insert into public.player_inventory(player_id,item_id) select uid,item_id from public.shop_catalog where kind='card' and card_id=gift.card_id on conflict do nothing;
 return gift.card_id;
end $$;
alter table public.player_expeditions add column if not exists inventory_reserved boolean not null default false;
create or replace function public.start_player_expedition(p_card_id text,p_duration integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();eid uuid;quantity integer;
begin
 if uid is null or p_duration is null or p_duration not in(4,8,12) or p_card_id is null then raise exception 'Expedição inválida.';end if;
 perform 1 from public.profiles where id=uid for update;
 if public._r_card(p_card_id)='{}'::jsonb or coalesce((public._r_card(p_card_id)->>'specialOnly')::boolean,false) then raise exception 'Carta indisponível.';end if;
 select copies into quantity from public.player_card_copies where player_id=uid and card_id=p_card_id for update;
 if coalesce(quantity,0)<2 then raise exception 'Mantenha pelo menos uma cópia da carta na coleção.';end if;
 if quantity-1<public._audit_reserved_copies(uid,p_card_id) then raise exception 'Retire uma cópia dos seus baralhos antes da expedição.';end if;
 update public.player_card_copies set copies=copies-1 where player_id=uid and card_id=p_card_id;
 insert into public.player_expeditions(player_id,card_id,duration_hours,ends_at,reward_coins,inventory_reserved)
 values(uid,p_card_id,p_duration,now()+make_interval(hours=>p_duration),p_duration*5,true) returning id into eid;
 return eid;
end $$;
create or replace function public.claim_player_expedition(p_expedition_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();expedition public.player_expeditions%rowtype;
begin
 if uid is null then raise exception 'Entre na conta.';end if;
 perform 1 from public.profiles where id=uid for update;
 select * into expedition from public.player_expeditions where id=p_expedition_id and player_id=uid and claimed_at is null and ends_at<=now() for update;
 if not found then raise exception 'Expedição indisponível ou ainda em andamento.';end if;
 update public.player_expeditions set claimed_at=now() where id=expedition.id;
 if expedition.inventory_reserved then
  insert into public.player_card_copies(player_id,card_id,copies) values(uid,expedition.card_id,1)
  on conflict(player_id,card_id) do update set copies=public.player_card_copies.copies+1;
 else
  -- A versão antiga retirava a carta somente do deck. Não duplique a coleção.
  update public.player_decks set card_counts=jsonb_set(card_counts,array[expedition.card_id],to_jsonb(coalesce((card_counts->>expedition.card_id)::integer,0)+1),true)
  where player_id=uid and (select coalesce(sum(value::integer),0) from jsonb_each_text(card_counts))<35
   and coalesce((card_counts->>expedition.card_id)::integer,0)<coalesce((select copies from public.player_card_copies where player_id=uid and card_id=expedition.card_id),0);
 end if;
 update public.profiles set mythic_coins=mythic_coins+expedition.reward_coins where id=uid;
 return expedition.reward_coins;
end $$;

-- A expiração solicitada por um jogador só percorre as suas partidas.
create or replace function public.expire_game_turns() returns integer
language plpgsql security definer set search_path='' as $$
declare g record;side_key text;action_name text;expired integer:=0;personal jsonb;
 caller uuid:=auth.uid();prior_sub text:=current_setting('request.jwt.claim.sub',true);
begin
 if caller is null and coalesce(auth.role(),'')<>'service_role' then raise exception 'Entre na conta.';end if;
 for g in select id,player_one,player_two,player_three,player_four,team_size,turn_user,state from public.game_matches
  where status='active' and turn_user is not null and turn_deadline<=clock_timestamp()
  and (auth.role()='service_role' or caller in(player_one,player_two,player_three,player_four))
  order by turn_deadline limit 50 for update skip locked loop
  if coalesce(g.team_size,1)=2 then
    select private_state into personal from public.duo_player_states where match_id=g.id and player_id=g.turn_user;
  else side_key:=case when g.turn_user=g.player_one then 'player_one' else 'player_two' end;personal:=g.state->side_key;end if;
  action_name:=case when coalesce((personal->>'skipNextTurn')::boolean,false) then 'skip_turn' else 'pass' end;
  begin
    perform set_config('request.jwt.claim.sub',g.turn_user::text,true);
    perform public._audit_submit_game_action(g.id,jsonb_build_object('type',action_name));expired:=expired+1;
  exception when others then null;end;
  perform set_config('request.jwt.claim.sub',coalesce(prior_sub,''),true);
 end loop;return expired;
end $$;

-- Os blocos finais da migração são gerados a partir das rotinas históricas,
-- preservando seus tipos de retorno, permissões explícitas e regras existentes.

create or replace function public._check_owned_saved_deck() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.profiles where id=new.player_id for update;
 perform public._assert_owned_deck(new.player_id,new.card_counts);return new;
end $$;

create or replace function public.record_guardian_match(p_match_id uuid,p_outcome text,p_player_points integer,p_opponent_points integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); earned_xp integer; earned_coins integer; inserted integer;

begin

  if uid is null then raise exception 'Entre na conta para registrar a partida.'; end if;

  if p_match_id is null or p_outcome is null or p_player_points is null or p_opponent_points is null or p_outcome not in ('victory','defeat','draw') or p_player_points not between 0 and 5000 or p_opponent_points not between 0 and 5000 then raise exception 'Resultado de partida inválido.'; end if;

  if (p_outcome='victory' and p_player_points<=p_opponent_points) or (p_outcome='defeat' and p_player_points>=p_opponent_points) or (p_outcome='draw' and p_player_points<>p_opponent_points) then raise exception 'O resultado não corresponde aos pontos.'; end if;

  perform 1 from public.profiles where id=uid for update;
  if exists(select 1 from public.guardian_match_claims where player_id=uid and match_id=p_match_id) then return jsonb_build_object('already_recorded',true);end if;
  if (select count(*) from public.guardian_match_claims where player_id=uid and claimed_at >= date_trunc('day',now()))>=5 then raise exception 'Limite diário de partidas recompensadas contra o Guardião atingido.'; end if;

  insert into public.guardian_match_claims(match_id,player_id) values(p_match_id,uid) on conflict do nothing;

  get diagnostics inserted = row_count;

  if inserted=0 then return jsonb_build_object('already_recorded',true); end if;

  if p_outcome='victory' then earned_xp:=30;earned_coins:=20; update public.profiles set wins=wins+1,xp=xp+earned_xp,mythic_coins=mythic_coins+earned_coins where id=uid;

  elsif p_outcome='defeat' then earned_xp:=20;earned_coins:=10; update public.profiles set losses=losses+1,xp=xp+earned_xp,mythic_coins=mythic_coins+earned_coins where id=uid;

  else earned_xp:=15;earned_coins:=10; update public.profiles set xp=xp+earned_xp,mythic_coins=mythic_coins+earned_coins where id=uid; end if;

  insert into public.match_history(match_id,guardian_match_id,player_id,opponent_name,mode,outcome,player_points,opponent_points,xp_earned,coins_earned)

  values(null,p_match_id,uid,'Guardião da Arena','guardian',p_outcome,p_player_points,p_opponent_points,earned_xp,earned_coins);

  return jsonb_build_object('xp_earned',earned_xp,'coins_earned',earned_coins);

end;
$$;

create or replace function public.get_tiebreak_state(p_match_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
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
      coalesce((public._r_card(e.card_id)->>'power')::integer,0) as power
    from jsonb_array_elements_text(coalesce(side->'hand','[]'::jsonb)||coalesce(side->'deck','[]'::jsonb)||coalesce(side->'underworld','[]'::jsonb)) e(card_id)
    where public._r_card(e.card_id)->>'kind'='unit' and not coalesce((public._r_card(e.card_id)->>'specialOnly')::boolean,false)
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
end
$$;

create or replace function public.submit_tiebreak_card(p_match_id uuid,p_card_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
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
  if (public._r_card(p_card_id)->>'kind' is distinct from 'unit' or coalesce((public._r_card(p_card_id)->>'specialOnly')::boolean,false))
    or not ((coalesce(side->'hand','[]'::jsonb)||coalesce(side->'deck','[]'::jsonb)||coalesce(side->'underworld','[]'::jsonb)) ? p_card_id)
    or (select count(*) from jsonb_array_elements_text(used) u(value) where u.value=p_card_id)>=
       (select count(*) from jsonb_array_elements_text(coalesce(side->'hand','[]'::jsonb)||coalesce(side->'deck','[]'::jsonb)||coalesce(side->'underworld','[]'::jsonb)) available(value) where available.value=p_card_id)
  then raise exception 'card is not available for this draw'; end if;
  power:=coalesce((public._r_card(p_card_id)->>'power')::integer,0);
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
end
$$;

create or replace function public.list_friend_active_matches()
returns table(match_id uuid,friend_name text,opponent_name text,mode text,started_at timestamptz)
language sql security definer set search_path='' stable as $$
 select distinct g.id,coalesce(nullif(p.nickname,''),p.display_name),
 coalesce(nullif(other.nickname,''),other.display_name),g.mode,g.created_at
 from public.friendships f join public.profiles p on p.id=case when f.user_a=auth.uid() then f.user_b else f.user_a end
 join public.game_matches g on g.status='active' and p.id in(g.player_one,g.player_two,g.player_three,g.player_four)
 join public.profiles other on other.id=case when p.id in(g.player_one,g.player_three) then g.player_two else g.player_one end
 where f.status='accepted' and auth.uid() in(f.user_a,f.user_b)
 and auth.uid() not in(g.player_one,g.player_two,coalesce(g.player_three,g.player_one),coalesce(g.player_four,g.player_two))
 order by g.created_at desc limit 20;
$$;

do $table_grants$
declare table_name text;column_list text;
begin
 foreach table_name in array array['admin_audit_log','audit_replay_backup','card_lore','community_deck_votes','community_decks','duo_match_players','duo_player_states','duo_queue_parties','friend_card_gifts','friend_gifts','friend_messages','friendships','game_announcements','game_card_play_events','game_invites','game_matches','game_replays','game_state_timeline','game_tiebreaks','gift_claims','guardian_match_claims','guild_members','guild_war_matches','guild_wars','guild_weekly_claims','guild_weekly_missions','guilds','honor_catalog','inventory_icon_repair_backup','match_history','match_spectators','match_update_signals','matchmaking_queue','mission_claims','missions','player_card_copies','player_card_usage','player_deck_usage','player_decks','player_expeditions','player_honor_display','player_honors','player_inventory','player_match_decks','player_saved_decks','player_starter_grants','player_tournament_rounds','player_tournaments','premium_credit_ledger','premium_wallets','profiles','redeem_codes','sandbox_room_members','sandbox_room_spectators','sandbox_rooms','shop_catalog','tournament_entries'] loop
  execute format('revoke insert,update,delete,truncate,references,trigger on public.%I from public,anon,authenticated',table_name);
  select string_agg(quote_ident(attname),',') into column_list from pg_attribute where attrelid=to_regclass('public.'||table_name) and attnum>0 and not attisdropped;
  execute format('revoke insert (%s),update (%s),references (%s) on public.%I from public,anon,authenticated',column_list,column_list,column_list,table_name);
 end loop;
end $table_grants$;
grant update(display_name,avatar_url,nickname,phone,age,settings) on public.profiles to authenticated;
grant insert,update on public.player_decks to authenticated;
grant insert,update,delete on public.player_saved_decks to authenticated;
grant insert on public.friend_messages to authenticated;
grant delete on public.matchmaking_queue to authenticated;
grant insert,update,delete on public.shop_catalog,public.redeem_codes,public.game_announcements,public.card_lore to authenticated;

do $function_grants$
declare routine record;
begin
 for routine in select p.oid::regprocedure signature,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' and p.proname=any(array['_assert_match_inventory','_assert_owned_deck','_audit_get_online_match','_audit_mask_pool','_audit_match_signal','_audit_public_state','_audit_reserved_copies','_audit_submit_game_action','_check_owned_saved_deck','_cinematic_round_transition','_eclipse_is_vampire','_eclipse_power','_eclipse_side','_eclipse_state','_ensure_player_inventory','_equip_field','_equipment_can_target','_get_online_match_before_icons','_grant_chibi_avatars','_inventory_admin','_inventory_catalog_added','_inventory_catalog_price','_inventory_item_received','_inventory_lore_added','_inventory_profile_created','_is_equipment_card','_is_location_card','_is_terrain_card','_join_matchmaking_solo','_location_bonus','_new_online_duo_state','_new_online_game_state','_normalize_special_pools','_online_side_score','_online_unit_power','_player_pvp_unlocked','_r_action','_r_card','_r_change','_r_clear_round','_r_data','_r_destroy','_r_drain','_r_equip','_r_evt','_r_finish_start','_r_grave_ok','_r_grave_sync','_r_id','_r_init','_r_live','_r_option','_r_options','_r_other','_r_personal','_r_power','_r_protect','_r_reconcile','_r_resolve','_r_round_end','_r_score','_r_set_unit','_r_spawn','_r_turn_start','_r_unit','_r_visual','_submit_game_action_1v1','_terrain_bonus','_terrain_card_meta','admin_adjust_player_rewards','admin_list_players','advance_tournament_bracket','cancel_duo_queue','cancel_matchmaking','claim_friend_card_gift','claim_friend_gift','claim_gift_code','claim_guild_weekly_reward','claim_mission','claim_player_expedition','complete_tutorial_once','create_duo_queue','create_game_invite','create_guild','create_guild_war','create_player_tournament','create_profile_for_new_user','create_sandbox_room','create_tournament_bracket','credit_clash_bits_service','delete_builder_deck','enter_player_tournament','equip_player_honors','equip_shop_item','expire_game_turns','find_player_by_friend_code','get_delayed_spectator_snapshot','get_online_match','get_player_honors','get_player_profile_stats','get_sandbox_room_roster','get_sandbox_spectator_match','get_tiebreak_state','is_site_admin','join_game_invite','join_guild','join_matchmaking','join_sandbox_room','join_sandbox_spectator','list_friend_active_matches','list_my_friends','list_my_friends_with_icons','publish_community_deck','purchase_shop_item','record_duo_deck_usage','record_game_state_timeline','record_guardian_match','record_guild_war_result','record_guild_weekly_match','record_tournament_match_result','register_sandbox_match','request_friend','request_match_spectator','respond_duo_queue_invite','respond_friend_request','reward_completed_match','reward_duo_completed_match','save_builder_deck','save_match_replay','seed_guild_weekly_mission','send_friend_card_gift','send_friend_gift','set_game_turn_deadline','set_replay_public','start_player_expedition','start_sandbox_match','start_tournament_match','submit_duo_game_action','submit_game_action','submit_tiebreak_card','sync_player_entitlements','track_player_deck_result','track_player_match_usage','try_match_duo_queue','vote_community_deck']) loop
  execute format('revoke execute on function %s from public,anon,authenticated',routine.signature);
  if routine.proname=any(array['admin_adjust_player_rewards','admin_list_players','advance_tournament_bracket','cancel_duo_queue','cancel_matchmaking','claim_friend_card_gift','claim_friend_gift','claim_gift_code','claim_guild_weekly_reward','claim_mission','claim_player_expedition','complete_tutorial_once','create_duo_queue','create_game_invite','create_guild','create_guild_war','create_player_tournament','create_sandbox_room','create_tournament_bracket','delete_builder_deck','enter_player_tournament','equip_player_honors','equip_shop_item','expire_game_turns','find_player_by_friend_code','get_delayed_spectator_snapshot','get_online_match','get_player_honors','get_player_profile_stats','get_sandbox_room_roster','get_sandbox_spectator_match','get_tiebreak_state','is_site_admin','join_game_invite','join_guild','join_matchmaking','join_sandbox_room','join_sandbox_spectator','list_friend_active_matches','list_my_friends','list_my_friends_with_icons','publish_community_deck','purchase_shop_item','record_guardian_match','register_sandbox_match','request_friend','request_match_spectator','respond_duo_queue_invite','respond_friend_request','save_builder_deck','save_match_replay','send_friend_card_gift','send_friend_gift','set_replay_public','start_player_expedition','start_sandbox_match','start_tournament_match','submit_game_action','submit_tiebreak_card','sync_player_entitlements','try_match_duo_queue','vote_community_deck']) then
   execute format('grant execute on function %s to authenticated',routine.signature);
  end if;
 end loop;
end $function_grants$;
create or replace function public.get_community_deck_votes(p_deck_ids uuid[])
returns table(deck_id uuid,votes bigint) language plpgsql security definer set search_path='' stable as $$
begin
 if auth.uid() is null or cardinality(p_deck_ids)>20 then raise exception 'Consulta inválida.';end if;
 return query select v.deck_id,count(*) from public.community_deck_votes v where v.deck_id=any(p_deck_ids) group by v.deck_id;
end $$;
revoke all on function public.get_community_deck_votes(uuid[]) from public,anon;
grant execute on function public.get_community_deck_votes(uuid[]) to authenticated;

create or replace function public._inventory_catalog_added() returns trigger language plpgsql security definer set search_path='' as $$
begin

 if new.item_id='ares-helm' then return new;end if;

 insert into public.player_inventory(player_id,item_id) select id,new.item_id from auth.users where public._inventory_admin(id) and exists(select 1 from public.profiles where id=auth.users.id) on conflict do nothing;

 if new.kind='card' and new.card_id is not null then

  insert into public.player_card_copies(player_id,card_id,copies) select id,new.card_id,3 from auth.users where public._inventory_admin(id) and exists(select 1 from public.profiles where id=auth.users.id)

  on conflict(player_id,card_id) do update set copies=greatest(public.player_card_copies.copies,3);

 end if;return new;

end
$$;
revoke all on function public._inventory_catalog_added() from public,anon,authenticated;

create or replace function public._audit_profile_input() returns trigger language plpgsql set search_path='' as $$
begin
 if new.settings is null or jsonb_typeof(new.settings)<>'object' or octet_length(new.settings::text)>16384 then raise exception 'Preferências de perfil inválidas.';end if;
 if char_length(btrim(new.nickname)) not between 2 and 24 or char_length(coalesce(new.phone,''))>32 then raise exception 'Use um apelido de 2 a 24 caracteres e um telefone de até 32 caracteres.';end if;
 return new;
end $$;
drop trigger if exists audit_profile_input on public.profiles;
create trigger audit_profile_input before insert or update of settings,nickname,phone on public.profiles for each row execute function public._audit_profile_input();
revoke all on function public._audit_profile_input() from public,anon,authenticated;

create or replace function public.create_profile_for_new_user() returns trigger language plpgsql security definer set search_path='' as $$
declare generated_code text; public_nick text; player_age smallint;

begin

  loop

    generated_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

    exit when not exists(select 1 from public.profiles where friend_code = generated_code);

  end loop;

  public_nick:=coalesce(nullif(trim(new.raw_user_meta_data->>'nickname'),''),nullif(trim(new.raw_user_meta_data->>'display_name'),''),'Lenda');

  begin player_age:=nullif(new.raw_user_meta_data->>'age','')::smallint; exception when others then player_age:=null; end;

  if player_age is not null and player_age not between 13 and 120 then player_age:=null; end if;

  insert into public.profiles(id,display_name,nickname,friend_code,phone,age)

  values(new.id,left(case when char_length(public_nick)<2 then 'Lenda' else public_nick end,24),left(case when char_length(public_nick)<2 then 'Lenda' else public_nick end,24),generated_code,left(coalesce(new.raw_user_meta_data->>'phone',''),32),player_age);

  return new;

end;
$$;
revoke all on function public.create_profile_for_new_user() from public,anon,authenticated;

create or replace function public.get_public_player_cosmetics(p_ids uuid[])
returns table(id uuid,display_name text,nickname text,rating_points integer,equipped_avatar text)
language plpgsql security definer set search_path='' stable as $$
begin
 if auth.uid() is null or cardinality(p_ids)>200 then raise exception 'Consulta inválida.';end if;
 return query select p.id,p.display_name,p.nickname,p.rating_points,p.equipped_avatar from public.profiles p
 where p.id=any(p_ids) and (p.id=auth.uid()
 or exists(select 1 from public.friendships f where f.status='accepted' and p.id in(f.user_a,f.user_b) and auth.uid() in(f.user_a,f.user_b))
 or exists(select 1 from public.guild_members a join public.guild_members b on b.guild_id=a.guild_id where a.player_id=auth.uid() and b.player_id=p.id)
 or exists(select 1 from public.community_decks d where d.player_id=p.id));
end $$;
revoke all on function public.get_public_player_cosmetics(uuid[]) from public,anon;
grant execute on function public.get_public_player_cosmetics(uuid[]) to authenticated;
notify pgrst,'reload schema';
commit;
