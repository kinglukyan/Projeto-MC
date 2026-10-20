-- 043: Locate only the caller's own match. Never accept client-supplied state.
begin;
create or replace function public.resume_my_game(p_match_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();g public.game_matches;rid uuid;
begin
 perform public._security_rpc_gate('resume_my_game',30);
 select * into g from public.game_matches m where uid in(m.player_one,m.player_two,m.player_three,m.player_four)
 and (m.status='active' or (m.id=p_match_id and m.status in ('completed','abandoned')))
 order by (m.status='active') desc,(m.id=p_match_id) desc,m.created_at desc limit 1;
 if not found then return null;end if;
 select r.id into rid from public.sandbox_rooms r where r.match_id=g.id limit 1;
 return jsonb_build_object('matchId',g.id,'status',g.status,'mode',g.mode,'roomId',rid);
end $$;
revoke all on function public.resume_my_game(uuid) from public,anon;
grant execute on function public.resume_my_game(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
