-- 048: partidas encerradas não são retomadas como uma batalha atual.
-- Mantém histórico, relatórios, placares e recompensas existentes.
begin;
create or replace function public.resume_my_game(p_match_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();g public.game_matches%rowtype;rid uuid;
begin
 perform public._security_rpc_gate('resume_my_game',30);
 select m.* into g from public.game_matches as m
 where m.status='active' and uid in(m.player_one,m.player_two,m.player_three,m.player_four)
 order by (m.id=p_match_id) desc nulls last,m.created_at desc,m.id limit 1;
 if not found then return null;end if;
 select room.id into rid from public.sandbox_rooms as room where room.match_id=g.id limit 1;
 return jsonb_build_object('matchId',g.id,'status',g.status,'mode',g.mode,'roomId',rid);
end $$;
revoke all on function public.resume_my_game(uuid) from public,anon;
grant execute on function public.resume_my_game(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
