begin;

-- O relatório contém somente jogadas aceitas. Mãos/baralhos privados não são copiados.
create table public.match_report_actions(
 match_id uuid not null references public.game_matches(id) on delete cascade,
 actor_id uuid not null references public.profiles(id) on delete cascade,
 request_id uuid not null,
 action_type text not null check(action_type in('play','pass','skip_turn','resolve_effect')),
 card_id text,
 round_number integer not null,
 played_at timestamptz not null default clock_timestamp(),
 primary key(match_id,actor_id,request_id)
);
alter table public.match_report_actions enable row level security;
revoke all on public.match_report_actions from public,anon,authenticated;
alter table public.game_matches add column report_version smallint not null default 0;
alter table public.game_matches alter column report_version set default 1;
alter table public.sandbox_rooms add column last_match_id uuid references public.game_matches(id) on delete set null;
alter table public.sandbox_room_members add column ready_after_match boolean not null default true;
alter table public.duo_queue_parties add column report_returns uuid[] not null default '{}';
alter table public.duo_queue_parties add column awaiting_report boolean not null default false;

-- Quem ainda está lendo o relatório não pode ser colocado numa revanche automaticamente.
create function public._report_room_waiting() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='playing' and old.status='open' then
  update public.sandbox_room_members set ready_after_match=false where room_id=new.id;
 end if;
 return new;
end $$;
revoke all on function public._report_room_waiting() from public,anon,authenticated;
create trigger custom_room_wait_for_report after update of status on public.sandbox_rooms for each row execute function public._report_room_waiting();

do $room_readiness$
declare definition text;updated text;
begin
 definition:=pg_get_functiondef('public.custom_room_snapshot(uuid)'::regprocedure);
 updated:=replace(definition,'''rating'',p.rating_points)', '''rating'',p.rating_points,''ready'',m.ready_after_match)');
 if updated=definition then raise exception 'Aplique a migração 038 antes da 039.';end if;execute updated;
 definition:=pg_get_functiondef('public.custom_room_start(uuid)'::regprocedure);
 updated:=replace(definition,'select count(*) filter(where lobby_slot%2=1)',
  'if exists(select 1 from public.sandbox_room_members where room_id=r.id and not ready_after_match) then raise exception ''Aguarde todos os jogadores voltarem do resumo da partida.'';end if;
   select count(*) filter(where lobby_slot%2=1)');
 if updated=definition then raise exception 'Formato do lobby inesperado.';end if;execute updated;
end $room_readiness$;

-- Inserir o registro dentro da transação já protegida da migração 037.
-- Reenvios idempotentes retornam antes deste trecho; ações rejeitadas não passam aqui.
do $capture$
declare f regprocedure:='public.submit_game_action(uuid,jsonb)'::regprocedure;definition text;updated text;
begin
 definition:=pg_get_functiondef(f);
 if position('MATCH_REPORT_V39' in definition)>0 then return;end if;
 updated:=replace(definition,'rid:=(p_action->>''request_id'')::uuid;',
  'n:=coalesce((result.state->>''round'')::integer,1);rid:=(p_action->>''request_id'')::uuid;');
 updated:=replace(updated,
  'update public.security_action_requests set accepted=true where actor_id=uid and match_id=p_match_id and request_id=rid;',
  'update public.security_action_requests set accepted=true where actor_id=uid and match_id=p_match_id and request_id=rid;
   /* MATCH_REPORT_V39 */
   insert into public.match_report_actions(match_id,actor_id,request_id,action_type,card_id,round_number)
   values(p_match_id,uid,rid,action_type,case when action_type=''play'' then p_action->>''card_id'' else null end,n)
   on conflict do nothing;');
 if updated=definition or position('MATCH_REPORT_V39' in updated)=0
 or position('n:=coalesce((result.state' in updated)=0 then raise exception 'Formato do motor inesperado. Aplique a migração 037 antes da 039.';end if;
 execute updated;
end $capture$;

create function public.get_match_report(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare g public.game_matches%rowtype;mine text;other_side text;participants jsonb;cards jsonb;actions jsonb;
 rewards jsonb;tie jsonb;room_id uuid;
begin
 perform public._security_rpc_gate('get_match_report',60);
 select * into g from public.game_matches where id=p_match_id and auth.uid() in(player_one,player_two,player_three,player_four);
 if not found or g.status not in('completed','abandoned') then raise exception 'O relatório estará disponível ao encerrar esta partida.';end if;
 mine:=case when auth.uid() in(g.player_one,g.player_three) then 'player_one' else 'player_two' end;
 other_side:=case when mine='player_one' then 'player_two' else 'player_one' end;
 select jsonb_agg(jsonb_build_object('id',p.id,'name',coalesce(nullif(p.nickname,''),p.display_name,'Invocador'),
  'icon',p.equipped_avatar,'team',case when p.id in(g.player_one,g.player_three) then 'player_one' else 'player_two' end) order by seat)
 into participants from unnest(array[g.player_one,g.player_three,g.player_two,g.player_four]) with ordinality u(id,seat) join public.profiles p on p.id=u.id;
 select coalesce(jsonb_agg(jsonb_build_object('actor_id',a.actor_id,'card_id',a.card_id,'count',a.n) order by a.n desc,a.card_id),'[]') into cards
 from(select actor_id,card_id,count(*) n from public.match_report_actions where match_id=g.id and action_type='play' group by actor_id,card_id) a;
 select coalesce(jsonb_agg(jsonb_build_object('actor_id',a.actor_id,'actions',a.n,'passes',a.passes) order by a.actor_id),'[]') into actions
 from(select actor_id,count(*) n,count(*) filter(where action_type='pass') passes from public.match_report_actions where match_id=g.id group by actor_id) a;
 select jsonb_build_object('xp',xp_earned,'coins',coins_earned) into rewards from public.match_history where match_id=g.id and player_id=auth.uid() limit 1;
 select payload into tie from public.random_tiebreak_results where match_id=g.id;
 select id into room_id from public.sandbox_rooms where match_id=g.id or last_match_id=g.id order by created_at desc limit 1;
 return jsonb_build_object('id',g.id,'mode',case when room_id is not null then 'custom' else g.mode end,
  'team_size',coalesce(g.team_size,1),'my_team',mine,'participants',participants,
  'started_at',g.created_at,'finished_at',g.finished_at,
  'duration_seconds',case when g.finished_at is not null then greatest(0,extract(epoch from(g.finished_at-g.created_at))) else null end,
  'outcome',case when g.status='abandoned' then 'abandoned' when g.winner_id is null then 'draw'
   when coalesce(g.winner_id in(g.player_one,g.player_three),false)=(mine='player_one') then 'victory' else 'defeat' end,
  'round_wins',g.state->'roundWins','rounds',coalesce(g.state->'roundScores','[]'),
  'cards',cards,'actions',actions,'complete_tracking',g.report_version=1,'rewards',rewards,'tiebreak',tie,'room_id',room_id);
end $$;

create function public.custom_room_return(p_room_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.sandbox_rooms%rowtype;
begin
 perform public._security_rpc_gate('custom_room_return',20);
 select * into r from public.sandbox_rooms where id=p_room_id for update;
 if not found or not exists(select 1 from public.sandbox_room_members where room_id=r.id and player_id=auth.uid()) then raise exception 'Você não faz parte desta sala.';end if;
 if r.status='playing' then
  if not exists(select 1 from public.game_matches where id=r.match_id and status in('completed','abandoned')) then raise exception 'A partida ainda está em andamento.';end if;
  update public.sandbox_rooms set status='open',last_match_id=match_id,match_id=null where id=r.id;
 elsif r.status<>'open' then raise exception 'A sala já foi encerrada.';end if;
 update public.sandbox_room_members set ready_after_match=true where room_id=r.id and player_id=auth.uid();
 return public.custom_room_snapshot(r.id);
end $$;

create function public.return_match_lobby(p_match_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare g public.game_matches%rowtype;p public.duo_queue_parties%rowtype;returned uuid[];
begin
 perform public._security_rpc_gate('return_match_lobby',20);
 select * into g from public.game_matches where id=p_match_id and status in('completed','abandoned') and auth.uid() in(player_one,player_two,player_three,player_four);
 if not found then raise exception 'Partida indisponível.';end if;
 if coalesce(g.team_size,1)<>2 or g.mode not in('normal','ranked') then return;end if;
 select * into p from public.duo_queue_parties where match_id=g.id and auth.uid() in(host_id,partner_id) and status in('matched','ready') for update;
 if not found then return;end if;
 if exists(select 1 from public.duo_queue_parties q where q.id<>p.id and q.status in('inviting','ready','queued') and (q.host_id in(p.host_id,p.partner_id) or q.partner_id in(p.host_id,p.partner_id))) then return;end if;
 returned:=case when p.status='matched' then array[auth.uid()] when auth.uid()=any(p.report_returns) then p.report_returns else array_append(p.report_returns,auth.uid()) end;
 update public.duo_queue_parties set status='ready',report_returns=returned,awaiting_report=not(p.host_id=any(returned) and p.partner_id=any(returned)) where id=p.id;
end $$;

do $duo_readiness$
declare definition text;updated text;
begin
 definition:=pg_get_functiondef('public.start_duo_lobby_queue(uuid)'::regprocedure);
 updated:=replace(definition,'if party.status=''matched'' then',
  'if party.awaiting_report then raise exception ''Aguarde seu parceiro voltar do resumo da partida.'';end if;
   if party.status=''matched'' then');
 if updated=definition then raise exception 'Formato da sala de dupla inesperado.';end if;execute updated;
end $duo_readiness$;

revoke all on function public.get_match_report(uuid),public.custom_room_return(uuid),public.return_match_lobby(uuid) from public,anon;
grant execute on function public.get_match_report(uuid),public.custom_room_return(uuid),public.return_match_lobby(uuid) to authenticated;
commit;
