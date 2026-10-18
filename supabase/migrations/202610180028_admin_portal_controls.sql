-- 028: administração, telemetria e pausa de cartas. Aplicar depois do SQL 027.
begin;
do $$begin if to_regprocedure('public.open_starter_pack(text)') is null or not exists(select 1 from pg_constraint where conrelid='public.player_onboarding'::regclass and pg_get_constraintdef(oid) like '%Alyns%') then raise exception 'Execute o SQL 027 antes do SQL 028.';end if;end $$;

create index if not exists profiles_admin_created_idx on public.profiles(created_at desc,id);
create index if not exists match_history_admin_activity_idx on public.match_history(completed_at,player_id);

create table if not exists public.account_restrictions(
 player_id uuid primary key references public.profiles(id) on delete cascade,
 banned_until timestamptz,reason text not null default '' check(char_length(reason)<=300),updated_at timestamptz not null default now()
);
create table if not exists public.admin_operation_log(
 id bigint generated always as identity primary key,actor_id uuid references public.profiles(id) on delete set null,
 target_id text not null,operation text not null,details jsonb not null default '{}',created_at timestamptz not null default now()
);
create table if not exists public.card_availability(
 card_id text primary key,disabled boolean not null default false,reason text not null default '' check(char_length(reason)<=240),
 updated_at timestamptz not null default now(),updated_by uuid references public.profiles(id) on delete set null
);
alter table public.account_restrictions enable row level security;
alter table public.admin_operation_log enable row level security;
alter table public.card_availability enable row level security;
revoke all on public.account_restrictions,public.admin_operation_log,public.card_availability from public,anon,authenticated;

create or replace function public._account_active() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is null or (exists(select 1 from public.profiles where id=auth.uid()) and not exists(select 1 from public.account_restrictions where player_id=auth.uid() and banned_until>now()));
$$;
create or replace function public._assert_account_active() returns void language plpgsql stable security definer set search_path='' as $$
begin if not public._account_active() then raise exception 'Sua conta está temporariamente suspensa.' using errcode='42501';end if;end $$;
revoke all on function public._account_active(),public._assert_account_active() from public,anon,authenticated;
-- RLS policies call this predicate under the authenticated role.
grant execute on function public._account_active() to authenticated;
create or replace function public.get_account_access() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('blocked',not public._account_active(),'message',case when not public._account_active() then 'Esta conta está indisponível ou temporariamente suspensa.' else '' end);
$$;
revoke all on function public.get_account_access() from public,anon;
grant execute on function public.get_account_access() to authenticated;

create or replace function public.get_card_availability() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('card_id',card_id,'disabled',disabled,'reason',reason) order by card_id),'[]'::jsonb) from public.card_availability;
$$;
revoke all on function public.get_card_availability() from public;
grant execute on function public.get_card_availability() to anon,authenticated;
create or replace function public._card_enabled(cid text) returns boolean language sql stable security definer set search_path='' as $$
 select not exists(select 1 from public.card_availability where card_id=cid and disabled);
$$;
revoke all on function public._card_enabled(text) from public,anon,authenticated;

create or replace function public.admin_search_users(p_query text default '',p_offset integer default 0,p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;total bigint;q text:=lower(btrim(coalesce(p_query,'')));off integer:=greatest(coalesce(p_offset,0),0);lim integer:=least(greatest(coalesce(p_limit,50),1),100);
begin
 if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.';end if;
 if char_length(q)>120 then raise exception 'Busca muito longa.';end if;
 select count(*) into total from public.profiles p join auth.users u on u.id=p.id
 where q='' or strpos(lower(coalesce(p.nickname,'')||' '||coalesce(u.email::text,'')||' '||p.id::text),q)>0;
 select coalesce(jsonb_agg(row_to_json(t)),'[]'::jsonb) into result from (
  select p.id user_id,p.nickname,u.email::text email,p.created_at,public._inventory_admin(p.id) is_admin,r.banned_until
  from public.profiles p join auth.users u on u.id=p.id left join public.account_restrictions r on r.player_id=p.id
  where q='' or strpos(lower(coalesce(p.nickname,'')||' '||coalesce(u.email::text,'')||' '||p.id::text),q)>0
  order by p.created_at desc,p.id limit lim offset off
 ) t;
 return jsonb_build_object('users',result,'total',total,'offset',off,'limit',lim);
end $$;
revoke all on function public.admin_search_users(text,integer,integer) from public,anon;
grant execute on function public.admin_search_users(text,integer,integer) to authenticated;

create or replace function public.admin_suspend_user(p_user_id uuid,p_hours integer,p_reason text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare until_at timestamptz;
begin
 if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.';end if;
 if p_user_id is null or p_user_id=auth.uid() or public._inventory_admin(p_user_id) then raise exception 'Contas administrativas estão protegidas.';end if;
 if p_hours is null or p_hours not between 0 and 8760 or char_length(coalesce(p_reason,''))>300 or (p_hours>0 and char_length(btrim(coalesce(p_reason,'')))=0) then raise exception 'Informe duração e motivo válidos.';end if;
 perform 1 from public.profiles where id=p_user_id for update;if not found then raise exception 'Jogador não encontrado.';end if;
 until_at:=case when p_hours>0 then now()+make_interval(hours=>p_hours) end;
 insert into public.account_restrictions(player_id,banned_until,reason) values(p_user_id,until_at,btrim(coalesce(p_reason,'')))
 on conflict(player_id) do update set banned_until=excluded.banned_until,reason=excluded.reason,updated_at=now();
 update auth.users set banned_until=until_at where id=p_user_id;
 if p_hours>0 then
  delete from public.matchmaking_queue where user_id=p_user_id;
  delete from public.player_presence where player_id=p_user_id;
  -- Sessions are revoked as well as blocking already issued JWTs through RPC/RLS guards.
  delete from auth.sessions where user_id=p_user_id;
 end if;
 insert into public.admin_operation_log(actor_id,target_id,operation,details) values(auth.uid(),p_user_id::text,case when p_hours=0 then 'unban' else 'ban' end,jsonb_build_object('until',until_at,'reason',p_reason));
 return jsonb_build_object('banned_until',until_at);
end $$;
revoke all on function public.admin_suspend_user(uuid,integer,text) from public,anon;
grant execute on function public.admin_suspend_user(uuid,integer,text) to authenticated;

create or replace function public.admin_delete_user(p_user_id uuid,p_confirmation text) returns void
language plpgsql security definer set search_path='' as $$
declare nick text;fk record;col text;
begin
 if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.';end if;
 if p_user_id is null or p_user_id=auth.uid() or public._inventory_admin(p_user_id) then raise exception 'Contas administrativas estão protegidas.';end if;
 select nickname into nick from public.profiles where id=p_user_id for update;if not found then raise exception 'Jogador não encontrado.';end if;
 if p_confirmation is distinct from nick then raise exception 'Confirmação de apelido incorreta.';end if;
 -- Remove matches owned by the deleted participant; dependent replay/timeline rows cascade.
 delete from public.game_matches where p_user_id in(player_one,player_two,player_three,player_four);
 -- Older schemas have nullable references without ON DELETE SET NULL and a credit ledger
 -- with a required player reference. Resolve only actual references to this exact account.
 for fk in select c.conrelid,c.conkey[1] attnum from pg_constraint c where c.contype='f' and c.confrelid='public.profiles'::regclass and c.confdeltype in ('a','r') and cardinality(c.conkey)=1 loop
  select attname into col from pg_attribute where attrelid=fk.conrelid and attnum=fk.attnum;
  if (select attnotnull from pg_attribute where attrelid=fk.conrelid and attnum=fk.attnum) then
   execute format('delete from %s where %I=$1',fk.conrelid::regclass,col) using p_user_id;
  else execute format('update %s set %I=null where %I=$1',fk.conrelid::regclass,col,col) using p_user_id;end if;
 end loop;
 insert into public.admin_operation_log(actor_id,target_id,operation,details) values(auth.uid(),p_user_id::text,'delete_user',jsonb_build_object('nickname',nick));
 delete from auth.users where id=p_user_id;
 if exists(select 1 from public.profiles where id=p_user_id) then raise exception 'A exclusão não foi concluída. Nenhum dado foi removido.';end if;
end $$;
revoke all on function public.admin_delete_user(uuid,text) from public,anon;
grant execute on function public.admin_delete_user(uuid,text) to authenticated;

create or replace function public.admin_set_card_availability(p_card_id text,p_disabled boolean,p_reason text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.';end if;
 if p_card_id is null or public._r_card(p_card_id)='{}'::jsonb or p_disabled is null or char_length(coalesce(p_reason,''))>240 or (p_disabled and char_length(btrim(coalesce(p_reason,'')))=0) then raise exception 'Informe uma carta e um motivo válidos.';end if;
 insert into public.card_availability(card_id,disabled,reason,updated_by) values(p_card_id,p_disabled,btrim(coalesce(p_reason,'')),auth.uid())
 on conflict(card_id) do update set disabled=excluded.disabled,reason=excluded.reason,updated_by=excluded.updated_by,updated_at=now();
 insert into public.admin_operation_log(actor_id,target_id,operation,details) values(auth.uid(),p_card_id,case when p_disabled then 'pause_card' else 'resume_card' end,jsonb_build_object('reason',p_reason));
end $$;
revoke all on function public.admin_set_card_availability(text,boolean,text) from public,anon;
grant execute on function public.admin_set_card_availability(text,boolean,text) to authenticated;

create or replace function public.admin_game_telemetry() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare ages jsonb;preferences jsonb;factions jsonb;modes jsonb;top_cards jsonb;onboarding jsonb;summary jsonb;
begin
 if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.';end if;
 select jsonb_build_object('Contas',count(*),'Novas contas · 7 dias',count(*) filter(where created_at>=now()-interval '7 days'),'Novas contas · 30 dias',count(*) filter(where created_at>=now()-interval '30 days'),'Tutorial concluído',count(*) filter(where tutorial_completed)) into summary from public.profiles;
 summary:=summary||jsonb_build_object('Jogadores ativos · 30 dias',(select count(distinct player_id) from public.match_history where completed_at>=now()-interval '30 days'),'Partidas online concluídas',(select count(*) from public.game_matches where status='completed'),'Contas suspensas',(select count(*) from public.account_restrictions where banned_until>now()));
 select coalesce(jsonb_agg(row_to_json(t) order by label),'[]'::jsonb) into ages from (
  select case when age is null then 'Não informado' when age<18 then '13–17' when age<25 then '18–24' when age<35 then '25–34' when age<45 then '35–44' when age<60 then '45–59' else '60+' end label,count(*) value from public.profiles group by 1
 ) t;
 select coalesce(jsonb_agg(row_to_json(t) order by value desc),'[]'::jsonb) into preferences from (
  select coalesce(settings->>'preferred_mythology','Não informado') label,count(*) value from public.profiles group by 1
 ) t;
 select coalesce(jsonb_agg(row_to_json(t) order by value desc),'[]'::jsonb) into factions from (
  select coalesce(public._r_card(card_id)->>'faction','Outras') label,sum(plays) value from (select card_id,sum(plays) plays from public.player_card_usage group by card_id) usage group by 1
 ) t;
 -- History stores one row per participant: count online matches at their source.
 select coalesce(jsonb_agg(row_to_json(t) order by value desc),'[]'::jsonb) into modes from (
  select mode label,count(*) value from public.game_matches where status='completed' group by mode
  union all select 'guardian',count(*) from public.guardian_match_claims
 ) t;
 select coalesce(jsonb_agg(row_to_json(t) order by value desc),'[]'::jsonb) into top_cards from (
  select coalesce(public._r_card(card_id)->>'name',card_id) label,sum(plays) value from public.player_card_usage group by card_id order by sum(plays) desc limit 15
 ) t;
 select coalesce(jsonb_agg(row_to_json(t)),'[]'::jsonb) into onboarding from (select stage label,count(*) value from public.player_onboarding group by stage) t;
 return jsonb_build_object('summary',summary,'ages',ages,'preferences',preferences,'factions',factions,'modes',modes,'cards',top_cards,'onboarding',onboarding,'generated_at',now());
end $$;
revoke all on function public.admin_game_telemetry() from public,anon;
grant execute on function public.admin_game_telemetry() to authenticated;

create or replace function public.get_guardian_journey() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare uid uuid:=auth.uid();missions_data jsonb;
begin
 if uid is null then raise exception 'Entre na conta.';end if;
 select coalesce(jsonb_agg(row_to_json(t)),'[]'::jsonb) into missions_data from (
  select m.mission_id,m.title,m.description,m.target_count,m.reward_xp,m.reward_coins,
  (select count(*) from public.match_history h where h.player_id=uid and h.mode='guardian') progress,
  exists(select 1 from public.mission_claims c where c.player_id=uid and c.mission_id=m.mission_id) claimed
  from public.missions m where m.active and m.mode='guardian' order by m.mission_id
 ) t;
 return jsonb_build_object('tutorial_completed',(select tutorial_completed from public.profiles where id=uid),'missions',missions_data);
end $$;
revoke all on function public.get_guardian_journey() from public,anon;
grant execute on function public.get_guardian_journey() to authenticated;

-- Enforce pauses in the authoritative engine and deck validation. The original
-- bodies are patched in place, preserving function identities and permissions.
do $availability_guards$
declare signature regprocedure;definition text;updated text;
begin
 foreach signature in array array[to_regprocedure('public._assert_owned_deck(uuid,jsonb)'),to_regprocedure('public._r_action(jsonb,jsonb,text,jsonb)'),to_regprocedure('public._r_spawn(jsonb,text,text,text,integer,integer)'),to_regprocedure('public.purchase_shop_item(text)'),to_regprocedure('public.open_starter_pack(text)')] loop
  if signature is null then raise exception 'Função de inventário/combate ausente. Aplique todas as migrações anteriores.';end if;
  definition:=pg_get_functiondef(signature);updated:=definition;
  if definition like '%_assert_owned_deck(%' and definition not like '%PAUSE_DECK_GUARD%' then
   updated:=regexp_replace(definition,'\mBEGIN\M',E'begin /* PAUSE_DECK_GUARD */ if exists(select 1 from jsonb_each(counts) e where e.value::text ~ ''^[1-9][0-9]*$'' and not public._card_enabled(e.key)) then raise exception ''Este baralho contém uma carta temporariamente pausada.'';end if;','i');
  elsif definition like '%FUNCTION public._r_action(%' and definition not like '%PAUSE_PLAY_GUARD%' then
   updated:=regexp_replace(definition,'\mBEGIN\M',E'begin /* PAUSE_PLAY_GUARD */ if a->>''type''=''play'' and not public._card_enabled(a->>''card_id'') then raise exception ''Esta carta está temporariamente pausada.'';end if;','i');
  elsif definition like '%FUNCTION public._r_spawn(%' and definition not like '%PAUSE_SPAWN_GUARD%' then
   updated:=regexp_replace(definition,'\mBEGIN\M',E'begin /* PAUSE_SPAWN_GUARD */ if not public._card_enabled(cid) then return x;end if;','i');
  elsif definition like '%FUNCTION public.purchase_shop_item(%' and definition not like '%PAUSE_PURCHASE_GUARD%' then
   updated:=regexp_replace(definition,'\mBEGIN\M',E'begin /* PAUSE_PURCHASE_GUARD */ if exists(select 1 from public.shop_catalog where item_id=p_item_id and kind=''card'' and not public._card_enabled(card_id)) then raise exception ''Esta carta está temporariamente pausada.'';end if;','i');
  elsif definition like '%FUNCTION public.open_starter_pack(%' and definition not like '%PAUSE_STARTER_GUARD%' then
   updated:=replace(definition,'c.kind=''card'' and c.active','c.kind=''card'' and c.active and public._card_enabled(c.card_id) /* PAUSE_STARTER_GUARD */');
  end if;
  if updated<>definition then execute updated;end if;
 end loop;
end $availability_guards$;

do $additional_guards$
declare signature regprocedure;definition text;updated text;
begin
 signature:=to_regprocedure('public._r_grave_ok(jsonb,jsonb,jsonb)');
 if signature is not null then
  definition:=pg_get_functiondef(signature);
  if definition not like '%PAUSE_GRAVE_GUARD%' then
   updated:=regexp_replace(definition,'\mBEGIN\M',E'begin /* PAUSE_GRAVE_GUARD */ if not public._card_enabled(g->>''cardId'') then return false;end if;','i');execute updated;
  end if;
 end if;
 signature:=to_regprocedure('public._assert_match_inventory(uuid)');
 if signature is not null then
  definition:=pg_get_functiondef(signature);
  if definition not like '%MATCH_ACCOUNT_GUARD%' then
   updated:=regexp_replace(definition,'\mBEGIN\M',E'begin /* MATCH_ACCOUNT_GUARD */ if exists(select 1 from public.account_restrictions where player_id=uid and banned_until>now()) then raise exception ''Um participante está temporariamente suspenso.'';end if;','i');execute updated;
  end if;
 end if;
end $additional_guards$;

do $pending_pause_guard$
declare definition text;updated text;
begin
 definition:=pg_get_functiondef('public._r_resolve(jsonb,jsonb)'::regprocedure);
 if definition not like '%PAUSE_PENDING_GUARD%' then
  updated:=regexp_replace(definition,'\mBEGIN\M',E'begin /* PAUSE_PENDING_GUARD */ if op in (''revive'',''revive_cost'',''anubis_revive'') and exists(select 1 from jsonb_array_elements(x#>array[''s'',t,''grave'']) entry where entry->>''uid''=selected and not public._card_enabled(entry->>''cardId'')) then return x;end if;','i');execute updated;
 end if;
end $pending_pause_guard$;

-- Already issued JWTs must obey the suspension too. Restrictive policies are
-- ANDed with existing permissions; no existing permissive policy is replaced.
do $restricted_rls$
declare t record;
begin
 for t in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and c.relrowsecurity loop
  execute format('drop policy if exists account_active_access on public.%I',t.relname);
  execute format('create policy account_active_access on public.%I as restrictive for all to authenticated using(public._account_active()) with check(public._account_active())',t.relname);
 end loop;
end $restricted_rls$;

-- Definer RPCs bypass RLS, therefore every exposed PL/pgSQL definer gets its own
-- guard. Internal engine helpers remain private. Reapplication is idempotent.
do $rpc_guards$
declare f record;definition text;updated text;
begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
 where n.nspname='public' and p.prokind='f' and p.prosecdef and l.lanname='plpgsql' and p.proname not like '\_%' escape '\'
 and p.proname not in ('get_account_access') and has_function_privilege('authenticated',p.oid,'EXECUTE') and p.prorettype<>'trigger'::regtype loop
  definition:=pg_get_functiondef(f.oid);
  if definition like '%ACCOUNT_ACTIVE_GUARD%' then continue;end if;
  updated:=regexp_replace(definition,'\mBEGIN\M',E'begin /* ACCOUNT_ACTIVE_GUARD */ perform public._assert_account_active();','i');
  if updated=definition then raise exception 'Não foi possível proteger a função %.',f.oid::regprocedure;end if;
  execute updated;
 end loop;
end $rpc_guards$;
-- Older read/cancel RPCs were authored in SQL. Keep their signatures and
-- privileges while giving their bodies the same account guard.
do $sql_rpc_guards$
declare f record;definition text;body text;
begin
 for f in select p.oid,p.prosrc,p.proretset,p.prorettype from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
 where n.nspname='public' and l.lanname='sql' and p.prosecdef and p.proname=any(array['find_player_by_friend_code','list_my_friends','list_my_friends_with_icons','list_friend_active_matches','get_friend_presence','cancel_matchmaking']) loop
  definition:=pg_get_functiondef(f.oid);
  body:=regexp_replace(btrim(f.prosrc),';[[:space:]]*$','');
  if f.proretset then body:='return query '||body||';';
  elsif f.prorettype='void'::regtype then body:=body||';return;';
  else body:='return ('||body||');';end if;
  definition:=replace(definition,f.prosrc,'begin /* ACCOUNT_ACTIVE_GUARD */ perform public._assert_account_active();'||chr(10)||body||chr(10)||'end;');
  definition:=replace(definition,'LANGUAGE sql','LANGUAGE plpgsql');execute definition;
 end loop;
end $sql_rpc_guards$;
notify pgrst,'reload schema';
commit;
