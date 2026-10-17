-- Aplicar após o SQL 016. Os sete slots estão disponíveis sem compra nesta versão.
begin;
alter table public.player_saved_decks drop constraint if exists player_saved_decks_slot_check;
alter table public.player_saved_decks add constraint player_saved_decks_slot_check check(slot between 1 and 7);
do $slots$
declare signature text;definition text;
begin
 foreach signature in array array['public.save_builder_deck(integer,text,jsonb)','public.delete_builder_deck(integer,integer,jsonb)'] loop
   if to_regprocedure(signature) is null then raise exception 'Aplique os SQLs 015 e 016 antes do SQL 017.';end if;
   definition:=pg_get_functiondef(to_regprocedure(signature));
   execute replace(definition,'between 1 and 5','between 1 and 7');
 end loop;
end $slots$;

create or replace function public.list_my_friends_with_icons()
returns jsonb language sql security definer set search_path='' stable as $$
 select coalesce(jsonb_agg(to_jsonb(f)||jsonb_build_object('equipped_avatar',p.equipped_avatar)
   order by f.incoming desc,f.display_name),'[]'::jsonb)
 from public.list_my_friends() f join public.profiles p on p.id=f.friend_id;
$$;
revoke all on function public.list_my_friends_with_icons() from public,anon;
grant execute on function public.list_my_friends_with_icons() to authenticated;

-- Preserve the existing private-hand filtering and participant authorization.
do $base$
begin
 if to_regprocedure('public._get_online_match_before_icons(uuid)') is null then
   alter function public.get_online_match(uuid) rename to _get_online_match_before_icons;
 end if;
end $base$;
revoke all on function public._get_online_match_before_icons(uuid) from public,anon,authenticated;
create or replace function public.get_online_match(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' stable as $$
declare result jsonb;game jsonb;participants jsonb;
begin
 result:=public._get_online_match_before_icons(p_match_id);
 if result is null then return null;end if;
 game:=result->'match';
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',coalesce(nullif(p.nickname,''),p.display_name),
   'icon',p.equipped_avatar,'team',case when p.id in((game->>'player_one')::uuid,(game->>'player_three')::uuid) then 'player_one' else 'player_two' end)
   order by case when p.id=auth.uid() then 0 when p.id=(game->>'player_one')::uuid then 1 when p.id=(game->>'player_three')::uuid then 2 else 3 end),'[]'::jsonb)
 into participants from public.profiles p
 where p.id in((game->>'player_one')::uuid,(game->>'player_two')::uuid,(game->>'player_three')::uuid,(game->>'player_four')::uuid);
 return result||jsonb_build_object('participants',participants);
end $$;
revoke all on function public.get_online_match(uuid) from public,anon;
grant execute on function public.get_online_match(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
