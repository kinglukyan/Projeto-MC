-- 037: proteção de ações, limites e auditoria. Aplicar após 036.
-- Publicar também online.js e security-center.js desta entrega.
begin;
do $$begin
 if to_regprocedure('public._release_idle_match_sessions(uuid)') is null or to_regprocedure('public._assert_account_active()') is null then
  raise exception 'Aplique as migrações anteriores até a 036 antes da 037.';
 end if;
end $$;
create table if not exists public.security_events(
 id bigint generated always as identity primary key,
 actor_id uuid references public.profiles(id) on delete set null,
 category text not null check(char_length(category)<=80),
 severity text not null check(severity in('info','warning','high')),
 match_id uuid references public.game_matches(id) on delete set null,
 metadata jsonb not null default '{}'::jsonb check(octet_length(metadata::text)<=2048),
 reviewed_at timestamptz,reviewed_by uuid references public.profiles(id) on delete set null,
 review_note text not null default '' check(char_length(review_note)<=500),
 created_at timestamptz not null default clock_timestamp()
);
create index if not exists security_events_recent on public.security_events(created_at desc,id desc);
create index if not exists security_events_actor on public.security_events(actor_id,created_at desc);
create table if not exists public.security_rate_windows(
 actor_id uuid not null references public.profiles(id) on delete cascade,
 operation text not null,window_at timestamptz not null,count integer not null default 1,
 primary key(actor_id,operation,window_at)
);
create table if not exists public.security_action_requests(
 actor_id uuid not null references public.profiles(id) on delete cascade,
 match_id uuid not null references public.game_matches(id) on delete cascade,
 request_id uuid not null,payload_hash bytea not null,accepted boolean not null default false,
 created_at timestamptz not null default clock_timestamp(),primary key(actor_id,match_id,request_id)
);
create index if not exists security_requests_created on public.security_action_requests(created_at);
alter table public.security_events enable row level security;
alter table public.security_rate_windows enable row level security;
alter table public.security_action_requests enable row level security;
revoke all on public.security_events,public.security_rate_windows,public.security_action_requests from public,anon,authenticated;

-- Uma conta não pode receber duas partidas ativas em chamadas simultâneas.
create table if not exists public.security_match_leases(
 player_id uuid primary key references public.profiles(id) on delete cascade,
 match_id uuid not null references public.game_matches(id) on delete cascade
);
alter table public.security_match_leases enable row level security;
revoke all on public.security_match_leases from public,anon,authenticated;
insert into public.security_match_leases(player_id,match_id)
 select distinct on(u.player_id) u.player_id,g.id from public.game_matches g
 cross join lateral unnest(array[g.player_one,g.player_two,g.player_three,g.player_four]) u(player_id)
 where g.status='active' and u.player_id is not null order by u.player_id,g.created_at desc,g.id
 on conflict(player_id) do nothing;
create or replace function public._security_match_lease()
returns trigger language plpgsql security definer set search_path='' as $$
declare uid uuid;n integer;
begin
 if new.status<>'active' then return new;end if;
 for uid in select distinct p from unnest(array[new.player_one,new.player_two,new.player_three,new.player_four]) p where p is not null order by p loop
  insert into public.security_match_leases(player_id,match_id) values(uid,new.id)
  on conflict(player_id) do update set match_id=excluded.match_id
   where not exists(select 1 from public.game_matches old_match where old_match.id=public.security_match_leases.match_id and old_match.status='active');
  get diagnostics n=row_count;
  if n=0 then raise exception 'Um participante já tem uma partida em andamento. Retome ou conclua a partida existente.';end if;
 end loop;return new;
end $$;
drop trigger if exists security_match_lease on public.game_matches;
create trigger security_match_lease after insert on public.game_matches for each row execute function public._security_match_lease();
revoke all on function public._security_match_lease() from public,anon,authenticated;

create or replace function public._security_take(p_operation text,p_limit integer,p_seconds integer)
returns boolean language plpgsql volatile security definer set search_path='' as $$
declare uid uuid:=auth.uid(); n integer; slot timestamptz;
begin
 if uid is null then return false;end if;
 slot:=to_timestamp(floor(extract(epoch from clock_timestamp())/p_seconds)*p_seconds);
 insert into public.security_rate_windows(actor_id,operation,window_at) values(uid,p_operation,slot)
 on conflict(actor_id,operation,window_at) do update set count=least(public.security_rate_windows.count+1,p_limit+1)
 returning count into n;
 return n<=p_limit;
end $$;

create or replace function public._security_event(p_category text,p_severity text,p_match uuid default null,p_metadata jsonb default '{}')
returns void language plpgsql volatile security definer set search_path='' as $$
begin
 -- Não guardar corpo de requisições, tokens, códigos, mãos ou baralhos.
 if auth.uid() is not null and not public._security_take('event:'||p_category,20,60) then return;end if;
 insert into public.security_events(actor_id,category,severity,match_id,metadata)
 values(auth.uid(),left(p_category,80),p_severity,p_match,p_metadata);
end $$;

create or replace function public._security_rpc_gate(p_operation text,p_limit integer default 60)
returns void language plpgsql volatile security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entre na conta.' using errcode='42501';end if;
 perform public._assert_account_active();
 if not public._security_take('rpc:'||p_operation,p_limit,60) then
  -- RAISE LOG permanece no log PostgreSQL mesmo com rollback da requisição.
  raise log 'MYTHIC_SECURITY rate_limit actor=% operation=%',auth.uid(),p_operation;
  raise exception 'Muitas solicitações. Aguarde um minuto e tente novamente.' using errcode='P0001';
 end if;
end $$;

create or replace function public._security_action_rejected(p_category text,p_message text,p_match uuid default null,p_metadata jsonb default '{}')
returns public.game_matches language plpgsql volatile security definer set search_path='' as $$
declare result public.game_matches%rowtype;
begin
 perform public._security_event(p_category,case when p_category in('request_reused','invalid_payload','foreign_match') then 'high' else 'warning' end,p_match,p_metadata);
 result.state:=jsonb_build_object('_securityError',jsonb_build_object('code',p_category,'message',p_message));
 return result;
end $$;

-- Preservar o motor atual e seu mascaramento das informações privadas.
do $$begin
 if to_regprocedure('public._security_submit_game_action_v37(uuid,jsonb)') is null then
  alter function public.submit_game_action(uuid,jsonb) rename to _security_submit_game_action_v37;
 end if;
end $$;
revoke all on function public._security_submit_game_action_v37(uuid,jsonb) from public,anon,authenticated;
create or replace function public.submit_game_action(p_match_id uuid,p_action jsonb)
returns public.game_matches language plpgsql volatile security definer set search_path='' as $$
declare uid uuid:=auth.uid(); rid uuid; fingerprint bytea; prior public.security_action_requests%rowtype;
 result public.game_matches%rowtype; n integer; action_type text; reason text; errstate text;
begin
 if uid is null then raise exception 'Entre na conta para jogar.' using errcode='42501';end if;
 perform public._assert_account_active();
 -- Retorno de rejeição mantém contadores e auditoria mesmo sem aplicar a jogada.
 if not public._security_take('action:minute',120,60) or not public._security_take('action:burst',12,2) then
  return public._security_action_rejected('action_rate','Muitas ações. Aguarde alguns segundos.');
 end if;
 if p_action is null or jsonb_typeof(p_action)<>'object' or octet_length(p_action::text)>8192 then
  return public._security_action_rejected('invalid_payload','Formato de ação inválido.');
 end if;
 action_type:=p_action->>'type';
 if action_type is null or action_type not in('play','pass','skip_turn','resolve_effect')
 or exists(select 1 from jsonb_object_keys(p_action) k where k not in('type','card_id','lane','zone_key','target_index','choice_id','choice_value','request_id'))
 or coalesce(p_action->>'request_id','')!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 or (p_action?'lane' and p_action->'lane'<>'null'::jsonb and (p_action->>'lane')!~'^[0-2]$')
 or (p_action?'target_index' and p_action->'target_index'<>'null'::jsonb and (p_action->>'target_index')!~'^[0-9]{1,3}$')
 or length(coalesce(p_action->>'card_id',''))>100 or length(coalesce(p_action->>'choice_value',''))>512 or length(coalesce(p_action->>'choice_id',''))>120
 then return public._security_action_rejected('invalid_payload','Ação inválida. Atualize a página se estiver usando uma versão antiga.');end if;
 -- Não expor a existência ou o conteúdo de partidas de terceiros.
 select * into result from public.game_matches where id=p_match_id and uid in(player_one,player_two,player_three,player_four) for update;
 if not found then return public._security_action_rejected('foreign_match','Partida indisponível para esta conta.');end if;
 rid:=(p_action->>'request_id')::uuid;fingerprint:=sha256(convert_to((p_action-'request_id')::text,'UTF8'));
 select * into prior from public.security_action_requests where actor_id=uid and match_id=p_match_id and request_id=rid;
 if found then
  if prior.payload_hash<>fingerprint then return public._security_action_rejected('request_reused','Identificador de ação já utilizado.',p_match_id);end if;
  if not prior.accepted then return public._security_action_rejected('repeated_rejection','Esta ação já foi rejeitada. Atualize a mesa.',p_match_id);end if;
  result.state:=public.get_online_match(p_match_id)#>'{match,state}';return result;
 end if;
 insert into public.security_action_requests(actor_id,match_id,request_id,payload_hash) values(uid,p_match_id,rid,fingerprint);
 begin
  result:=public._security_submit_game_action_v37(p_match_id,p_action-'request_id');
  update public.security_action_requests set accepted=true where actor_id=uid and match_id=p_match_id and request_id=rid;
  return result;
 exception when others then
  get stacked diagnostics reason=MESSAGE_TEXT,errstate=RETURNED_SQLSTATE;
  -- Erros de infraestrutura não revelam SQL nem dados internos ao cliente.
  if errstate<>'P0001' then reason:='Não foi possível aplicar a ação. Atualize a mesa e tente novamente.';end if;
  return public._security_action_rejected('action_rejected',left(reason,240),p_match_id,jsonb_build_object('type',action_type,'sqlstate',errstate));
 end;
end $$;
revoke all on function public.submit_game_action(uuid,jsonb) from public,anon;
grant execute on function public.submit_game_action(uuid,jsonb) to authenticated;

-- As novas funções do lobby perderam o guard ao serem recriadas nas migrações 035/036.
-- Reaplicar em todos os RPCs PL/pgSQL públicos autenticados, mantendo assinaturas.
do $guards$
declare f record;body text;definition text;updated text;lim integer;
begin
 for f in select p.oid,p.proname,p.prosrc from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
 where n.nspname='public' and p.prokind='f' and p.prosecdef and l.lanname='plpgsql' and left(p.proname,1)<>'_'
 and p.proname not in('get_account_access','submit_game_action') and p.prorettype<>'trigger'::regtype
 and has_function_privilege('authenticated',p.oid,'EXECUTE') loop
  body:=f.prosrc;definition:=pg_get_functiondef(f.oid);
  if position('SECURITY_ACCOUNT_V37' in body)=0 then
   updated:=regexp_replace(body,'\mBEGIN\M',E'begin /* SECURITY_ACCOUNT_V37 */ perform public._assert_account_active();','i');
   if updated=body then raise exception 'Não foi possível proteger %.',f.oid::regprocedure;end if;
   definition:=replace(definition,body,updated);execute definition;
  end if;
  if f.proname='join_matchmaking' then
   definition:=pg_get_functiondef(f.oid);select prosrc into body from pg_proc where oid=f.oid;
   if position('SECURITY_QUEUE_V37' in body)=0 then
    updated:=regexp_replace(body,'\mBEGIN\M',E'begin /* SECURITY_QUEUE_V37 */ perform public._release_idle_match_sessions(auth.uid());','i');
    definition:=replace(definition,body,updated);execute definition;
   end if;
  end if;
  if f.proname=any(array['create_duo_queue','create_game_invite','respond_duo_queue_invite','start_duo_lobby_queue','join_matchmaking','leave_duo_lobby','send_friend_card_gift','send_friend_gift','claim_gift_code','purchase_shop_item','claim_mission','save_builder_deck']) then
   definition:=pg_get_functiondef(f.oid);select prosrc into body from pg_proc where oid=f.oid;
   if position('SECURITY_RATE_V37' in body)=0 then
    lim:=case when f.proname in('create_duo_queue','create_game_invite','send_friend_card_gift','send_friend_gift','claim_gift_code') then 20 else 60 end;
    updated:=regexp_replace(body,'\mBEGIN\M','begin /* SECURITY_RATE_V37 */ perform public._security_rpc_gate('||quote_literal(f.proname)||','||lim||');','i');
    definition:=replace(definition,body,updated);execute definition;
   end if;
  end if;
 end loop;
end $guards$;

-- Registro de alterações econômicas e administrativas, sem dados privados de cartas.
create or replace function public._security_economy_audit()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if (new.mythic_coins,new.xp,new.rating_points,new.wins,new.losses) is distinct from (old.mythic_coins,old.xp,old.rating_points,old.wins,old.losses) then
  perform public._security_event('economy_change','info',null,jsonb_build_object('player_id',new.id,'coins_delta',new.mythic_coins-old.mythic_coins,'xp_delta',new.xp-old.xp,'rank_delta',new.rating_points-old.rating_points,'wins_delta',new.wins-old.wins,'losses_delta',new.losses-old.losses));
 end if;return new;
end $$;
drop trigger if exists security_economy_audit on public.profiles;
create trigger security_economy_audit after update of mythic_coins,xp,rating_points,wins,losses on public.profiles for each row execute function public._security_economy_audit();
create or replace function public._security_admin_audit()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.security_events(actor_id,category,severity,metadata) values(new.actor_id,'admin_operation','info',jsonb_build_object('operation',new.operation,'target_id',new.target_id));return new;
end $$;
drop trigger if exists security_admin_audit on public.admin_operation_log;
create trigger security_admin_audit after insert on public.admin_operation_log for each row execute function public._security_admin_audit();

create or replace function public._security_admin_code_audit()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.attempts>=3 then perform public._security_event('admin_code_failures','warning',null,jsonb_build_object('attempts',new.attempts));end if;return new;
end $$;
drop trigger if exists security_admin_code_audit on public.site_admin_code_attempts;
create trigger security_admin_code_audit after insert or update on public.site_admin_code_attempts for each row execute function public._security_admin_code_audit();
revoke all on function public._security_admin_code_audit() from public,anon,authenticated;

create or replace function public.admin_security_events(p_before bigint default null,p_category text default '',p_actor uuid default null)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare events jsonb;summary jsonb;
begin
 perform public._assert_account_active();if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.id desc),'[]'::jsonb) into events from(
  select e.id,e.actor_id,e.category,e.severity,e.match_id,e.metadata,e.created_at,e.reviewed_at,e.review_note,p.nickname
  from public.security_events e left join public.profiles p on p.id=e.actor_id
  where (p_before is null or e.id<p_before) and (coalesce(p_category,'')='' or e.category=p_category) and (p_actor is null or e.actor_id=p_actor)
  order by e.id desc limit 50) t;
 select jsonb_build_object('events_24h',count(*),'high_24h',count(*) filter(where severity='high'),'pending_24h',count(*) filter(where reviewed_at is null and severity<>'info')) into summary from public.security_events where created_at>=now()-interval '24 hours';
 return jsonb_build_object('events',events,'summary',summary);
end $$;
create or replace function public.admin_review_security_event(p_event_id bigint,p_note text)
returns void language plpgsql volatile security definer set search_path='' as $$
begin
 perform public._assert_account_active();if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 if length(coalesce(p_note,''))>500 then raise exception 'Nota muito longa.';end if;
 update public.security_events set reviewed_at=clock_timestamp(),reviewed_by=auth.uid(),review_note=btrim(coalesce(p_note,'')) where id=p_event_id;
 if not found then raise exception 'Registro indisponível.';end if;
 insert into public.admin_operation_log(actor_id,target_id,operation) values(auth.uid(),p_event_id::text,'security_event_review');
end $$;
create or replace function public.admin_security_health()
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare missing_rls jsonb;helpers jsonb;grants jsonb;
begin
 perform public._assert_account_active();if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 select coalesce(jsonb_agg(c.relname),'[]') into missing_rls from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in('r','p') and not c.relrowsecurity;
 select coalesce(jsonb_agg(p.oid::regprocedure::text),'[]') into helpers from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and left(p.proname,1)='_' and p.proname<>'_account_active' and (has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('authenticated',p.oid,'EXECUTE'));
 select coalesce(jsonb_agg(t),'[]') into grants from (
  select table_name,grantee,privilege_type from information_schema.role_table_grants where table_schema='public' and grantee in('PUBLIC','anon','authenticated') and privilege_type in('INSERT','UPDATE','DELETE','TRUNCATE') and table_name in('game_matches','duo_player_states','player_inventory','player_card_copies','security_events','security_match_leases','site_admin_roles','site_admin_codes','premium_wallets','premium_credit_ledger')) t;
 return jsonb_build_object('checked_at',clock_timestamp(),'tables_without_rls',missing_rls,'exposed_internal_helpers',helpers,'sensitive_write_grants',grants);
end $$;
create or replace function public.security_prune_history()
returns void language plpgsql volatile security definer set search_path='' as $$
begin
 if coalesce(auth.role(),'')<>'service_role' and not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 delete from public.security_rate_windows where window_at<now()-interval '2 days';
 delete from public.security_action_requests where created_at<now()-interval '30 days' and exists(select 1 from public.game_matches g where g.id=match_id and g.status<>'active');
 delete from public.security_events where created_at<now()-interval '90 days' and reviewed_at is not null;
end $$;
-- Arquivos enviados ficam limitados a tipos necessários, inclusive no servidor.
update storage.buckets set file_size_limit=5242880,allowed_mime_types=array['image/png','image/jpeg','image/webp'] where id='mythic-card-art';
update storage.buckets set file_size_limit=52428800,allowed_mime_types=array['application/pdf','image/png','image/jpeg','image/webp'] where id='mythic-comics';
revoke all on function public._security_take(text,integer,integer),public._security_event(text,text,uuid,jsonb),public._security_rpc_gate(text,integer),public._security_action_rejected(text,text,uuid,jsonb),public._security_economy_audit(),public._security_admin_audit() from public,anon,authenticated;
revoke all on function public.admin_security_events(bigint,text,uuid),public.admin_review_security_event(bigint,text),public.admin_security_health(),public.security_prune_history() from public,anon;
grant execute on function public.admin_security_events(bigint,text,uuid),public.admin_review_security_event(bigint,text),public.admin_security_health() to authenticated;
grant execute on function public.security_prune_history() to authenticated,service_role;
-- Evitar exposição automática nas próximas funções criadas pelo mesmo owner.
alter default privileges in schema public revoke execute on functions from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
