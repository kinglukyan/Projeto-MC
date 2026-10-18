-- 029: acesso administrativo por código. Aplicar depois do SQL 028.
begin;
do $$begin if to_regprocedure('public.admin_game_telemetry()') is null then raise exception 'Execute o SQL 028 antes do SQL 029.';end if;end $$;

create table if not exists public.site_admin_roles(
 player_id uuid primary key references public.profiles(id) on delete cascade,
 granted_by uuid references public.profiles(id) on delete set null,created_at timestamptz not null default now()
);
create table if not exists public.site_admin_codes(
 code_hash bytea primary key,target_id uuid not null references public.profiles(id) on delete cascade,
 issued_by uuid references public.profiles(id) on delete set null,expires_at timestamptz not null,
 used_at timestamptz,created_at timestamptz not null default now()
);
create index if not exists site_admin_codes_target_idx on public.site_admin_codes(target_id);
create table if not exists public.site_admin_code_attempts(
 player_id uuid primary key references public.profiles(id) on delete cascade,
 started_at timestamptz not null default now(),attempts integer not null default 0
);
alter table public.site_admin_roles enable row level security;
alter table public.site_admin_codes enable row level security;
alter table public.site_admin_code_attempts enable row level security;
revoke all on public.site_admin_roles,public.site_admin_codes,public.site_admin_code_attempts from public,anon,authenticated;

create or replace function public._site_admin_founder(uid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.users where id=uid and lower(email)='santoslucasalmeida@gmail.com' and email_confirmed_at is not null);
$$;
create or replace function public._inventory_admin(uid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select public._site_admin_founder(uid) or exists(select 1 from public.site_admin_roles r join auth.users u on u.id=r.player_id where r.player_id=uid and u.email_confirmed_at is not null);
$$;
create or replace function public.is_site_admin() returns boolean
language sql stable security definer set search_path='' as $$
 select public._account_active() and public._inventory_admin(auth.uid());
$$;
revoke all on function public._site_admin_founder(uuid),public._inventory_admin(uuid),public.is_site_admin() from public,anon,authenticated;
grant execute on function public.is_site_admin() to authenticated;

create or replace function public.admin_role_overview() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform public._assert_account_active();
 if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.' using errcode='42501';end if;
 if not public._site_admin_founder(auth.uid()) then return jsonb_build_object('can_manage',false,'administrators','[]'::jsonb);end if;
 select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into result from (
  select p.id user_id,p.nickname,u.email,public._site_admin_founder(p.id) founder
  from public.profiles p join auth.users u on u.id=p.id where public._inventory_admin(p.id) order by p.nickname,p.id
 ) t;
 return jsonb_build_object('can_manage',true,'administrators',result);
end $$;

create or replace function public.admin_create_role_code(p_email text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare target uuid;target_email text;secret text;deadline timestamptz:=now()+interval '24 hours';
begin
 perform public._assert_account_active();
 if not public._site_admin_founder(auth.uid()) then raise exception 'Somente a conta principal pode atribuir administradores.' using errcode='42501';end if;
 if p_email is null or char_length(p_email)>254 then raise exception 'Informe um e-mail válido.';end if;
 select u.id,u.email into target,target_email from auth.users u join public.profiles p on p.id=u.id where lower(u.email)=lower(btrim(p_email)) and u.email_confirmed_at is not null for update of p;
 if target is null then raise exception 'Conta não encontrada ou e-mail ainda não confirmado.';end if;
 if public._inventory_admin(target) then raise exception 'Esta conta já é administradora.';end if;
 if exists(select 1 from public.account_restrictions where player_id=target and banned_until>now()) then raise exception 'Não é possível promover uma conta suspensa.';end if;
 -- A new issuance invalidates older unused codes for this account.
 delete from public.site_admin_codes where target_id=target and used_at is null;
 secret:='MC-ADM-'||upper(replace(gen_random_uuid()::text,'-',''));
 insert into public.site_admin_codes(code_hash,target_id,issued_by,expires_at) values(sha256(convert_to(secret,'UTF8')),target,auth.uid(),deadline);
 insert into public.admin_operation_log(actor_id,target_id,operation,details) values(auth.uid(),target::text,'admin_code_created',jsonb_build_object('expires_at',deadline));
 return jsonb_build_object('code',secret,'email',target_email,'expires_at',deadline);
end $$;

create or replace function public.redeem_admin_role_code(p_code text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();invitation public.site_admin_codes%rowtype;counter public.site_admin_code_attempts%rowtype;normalized text;
begin
 perform public._assert_account_active();
 if uid is null then raise exception 'Entre na sua conta.' using errcode='42501';end if;
 -- Serialize issuance/redemption for a target account. No code or secret is logged.
 perform 1 from public.profiles where id=uid for update;
 if not exists(select 1 from auth.users where id=uid and email_confirmed_at is not null) then raise exception 'Confirme seu e-mail antes de ativar o acesso.';end if;
 insert into public.site_admin_code_attempts(player_id) values(uid) on conflict do nothing;
 select * into counter from public.site_admin_code_attempts where player_id=uid for update;
 if counter.started_at<=now()-interval '15 minutes' then
  update public.site_admin_code_attempts set started_at=now(),attempts=0 where player_id=uid;counter.attempts:=0;
 end if;
 if counter.attempts>=5 then return jsonb_build_object('ok',false,'message','Muitas tentativas. Aguarde 15 minutos para tentar novamente.');end if;
 update public.site_admin_code_attempts set attempts=attempts+1 where player_id=uid;
 normalized:=upper(btrim(coalesce(p_code,'')));
 if char_length(normalized)=39 then
  select * into invitation from public.site_admin_codes where code_hash=sha256(convert_to(normalized,'UTF8')) and target_id=uid for update;
 end if;
 if invitation.target_id is null or invitation.used_at is not null or invitation.expires_at<=now() then
  -- Return rather than raise so failed-attempt counters are committed.
  return jsonb_build_object('ok',false,'message','Código inválido, expirado ou destinado a outra conta.');
 end if;
 if not public._site_admin_founder(invitation.issued_by) then return jsonb_build_object('ok',false,'message','Este código não está mais disponível.');end if;
 insert into public.site_admin_roles(player_id,granted_by) values(uid,invitation.issued_by) on conflict do nothing;
 update public.site_admin_codes set used_at=now() where code_hash=invitation.code_hash;
 delete from public.site_admin_code_attempts where player_id=uid;
 perform public._ensure_player_inventory(uid);
 insert into public.admin_operation_log(actor_id,target_id,operation,details) values(uid,uid::text,'admin_role_activated',jsonb_build_object('issued_by',invitation.issued_by));
 return jsonb_build_object('ok',true);
end $$;

revoke all on function public.admin_role_overview(),public.admin_create_role_code(text),public.redeem_admin_role_code(text) from public,anon,authenticated;
grant execute on function public.admin_role_overview(),public.admin_create_role_code(text),public.redeem_admin_role_code(text) to authenticated;
notify pgrst,'reload schema';
commit;
