-- Finishing the first Guardian match always grants enough XP for level 2.
-- Bring accounts that already completed the tutorial before this change up to the same threshold.
begin;

update public.profiles
set xp = greatest(coalesce(xp, 0), 100)
where tutorial_completed = true;

create or replace function public.complete_tutorial_once()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  new_xp integer;
  new_coins integer;
begin
  if uid is null then
    raise exception 'Entre para salvar seu tutorial.';
  end if;

  update public.profiles
  set tutorial_completed = true,
      xp = greatest(coalesce(xp, 0) + 100, 100),
      mythic_coins = coalesce(mythic_coins, 0) + 30
  where id = uid and tutorial_completed = false
  returning xp, mythic_coins into new_xp, new_coins;

  if not found then
    select xp, mythic_coins into new_xp, new_coins
    from public.profiles where id = uid;
    return jsonb_build_object(
      'already_completed', true,
      'xp', coalesce(new_xp, 0),
      'coins', coalesce(new_coins, 0)
    );
  end if;

  return jsonb_build_object('xp', new_xp, 'coins', new_coins);
end;
$$;

revoke all on function public.complete_tutorial_once() from public, anon;
grant execute on function public.complete_tutorial_once() to authenticated;

commit;
