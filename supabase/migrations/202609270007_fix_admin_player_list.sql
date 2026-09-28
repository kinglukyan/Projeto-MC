-- Corrige o tipo do e-mail retornado e mantém a listagem protegida para administradores.
begin;

create or replace function public.admin_list_players()
returns table(user_id uuid,email text,nickname text,xp integer,mythic_coins integer,wins integer,losses integer,rating_points integer)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_site_admin() then
    raise exception 'Acesso administrativo necessário.';
  end if;

  return query
    select p.id, u.email::text, p.nickname, p.xp, p.mythic_coins,
           p.wins, p.losses, p.rating_points
    from public.profiles as p
    join auth.users as u on u.id = p.id
    order by p.created_at desc
    limit 200;
end;
$$;

revoke all on function public.admin_list_players() from public, anon;
grant execute on function public.admin_list_players() to authenticated;

commit;
