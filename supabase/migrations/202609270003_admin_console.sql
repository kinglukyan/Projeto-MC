-- Mythic Clash: protected administration, public announcements and editable lore.
begin;

create or replace function public.is_site_admin()
returns boolean
language sql stable security definer set search_path = '' as $$
  select lower(coalesce(auth.jwt()->>'email',''))='santoslucasalmeida@gmail.com'
$$;
revoke all on function public.is_site_admin() from public,anon;
grant execute on function public.is_site_admin() to authenticated;

drop policy if exists "Admins manage shop catalog" on public.shop_catalog;
create policy "Admins manage shop catalog" on public.shop_catalog for all to authenticated
  using (public.is_site_admin()) with check (public.is_site_admin());
grant insert,update,delete on public.shop_catalog to authenticated;

drop policy if exists "Admins manage gift codes" on public.redeem_codes;
create policy "Admins manage gift codes" on public.redeem_codes for all to authenticated
  using (public.is_site_admin()) with check (public.is_site_admin());
grant select,insert,update,delete on public.redeem_codes to authenticated;

create table if not exists public.game_announcements (
  id text primary key check (id='main'),
  title text not null default '',
  body text not null default '',
  active boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.game_announcements enable row level security;
drop policy if exists "Anyone reads active announcement" on public.game_announcements;
create policy "Anyone reads active announcement" on public.game_announcements for select to anon,authenticated using (active);
drop policy if exists "Admins manage announcements" on public.game_announcements;
create policy "Admins manage announcements" on public.game_announcements for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());
grant select on public.game_announcements to anon,authenticated;
grant insert,update,delete on public.game_announcements to authenticated;

create table if not exists public.card_lore (
  card_id text primary key check (card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia')),
  story text[] not null default '{}',
  theme_url text,
  updated_at timestamptz not null default now()
);
alter table public.card_lore enable row level security;
drop policy if exists "Anyone reads card lore" on public.card_lore;
create policy "Anyone reads card lore" on public.card_lore for select to anon,authenticated using (true);
drop policy if exists "Admins manage card lore" on public.card_lore;
create policy "Admins manage card lore" on public.card_lore for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());
grant select on public.card_lore to anon,authenticated;
grant insert,update,delete on public.card_lore to authenticated;

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid not null,
  target_player uuid,
  action text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.admin_audit_log enable row level security;
revoke all on public.admin_audit_log from public,anon,authenticated;

create or replace function public.admin_list_players()
returns table(user_id uuid,email text,nickname text,xp integer,mythic_coins integer,wins integer,losses integer,rating_points integer)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.'; end if;
  return query select p.id,u.email,p.nickname,p.xp,p.mythic_coins,p.wins,p.losses,p.rating_points
    from public.profiles p join auth.users u on u.id=p.id order by p.created_at desc limit 200;
end;
$$;
revoke all on function public.admin_list_players() from public,anon;
grant execute on function public.admin_list_players() to authenticated;

create or replace function public.admin_adjust_player_rewards(p_user_id uuid,p_coins_delta integer,p_xp_delta integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare updated public.profiles%rowtype;
begin
  if not public.is_site_admin() then raise exception 'Acesso administrativo necessário.'; end if;
  if p_user_id is null or p_coins_delta is null or p_xp_delta is null or p_coins_delta not between -5000 and 5000 or p_xp_delta not between -5000 and 5000 then raise exception 'Ajuste inválido; use valores entre -5000 e 5000.'; end if;
  update public.profiles set mythic_coins=mythic_coins+p_coins_delta,xp=xp+p_xp_delta
    where id=p_user_id and mythic_coins+p_coins_delta>=0 and xp+p_xp_delta>=0 returning * into updated;
  if not found then raise exception 'Jogador inexistente ou o ajuste deixaria XP/coins negativos.'; end if;
  insert into public.admin_audit_log(admin_id,target_player,action,details)
    values(auth.uid(),p_user_id,'adjust_rewards',jsonb_build_object('coins_delta',p_coins_delta,'xp_delta',p_xp_delta));
  return jsonb_build_object('user_id',updated.id,'xp',updated.xp,'mythic_coins',updated.mythic_coins);
end;
$$;
revoke all on function public.admin_adjust_player_rewards(uuid,integer,integer) from public,anon;
grant execute on function public.admin_adjust_player_rewards(uuid,integer,integer) to authenticated;

commit;
