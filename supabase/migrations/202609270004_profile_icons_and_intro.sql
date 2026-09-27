-- Mythic Clash: purchasable profile icons and opponent badge for the pre-match reveal.
begin;

insert into public.shop_catalog(item_id,title,description,kind,price,asset_path,card_id,active)
values('spartan-chibi','Soldado de Esparta · Chibi','Um retrato chibi do guerreiro espartano para seu perfil.','avatar',120,'assets/spartan-chibi.svg',null,true)
on conflict(item_id) do update set title=excluded.title,description=excluded.description,kind=excluded.kind,price=excluded.price,asset_path=excluded.asset_path,active=true;

create or replace function public.get_online_match(p_match_id uuid)
returns jsonb language sql security definer set search_path = '' stable as $$
  select jsonb_build_object(
    'match',to_jsonb(g),
    'opponent_name',coalesce(nullif(p.nickname,''),p.display_name),
    'opponent_icon',p.equipped_avatar
  )
  from public.game_matches g
  join public.profiles p on p.id=case when g.player_one=auth.uid() then g.player_two else g.player_one end
  where g.id=p_match_id and auth.uid() in (g.player_one,g.player_two)
  limit 1;
$$;
revoke all on function public.get_online_match(uuid) from public,anon;
grant execute on function public.get_online_match(uuid) to authenticated;

commit;
