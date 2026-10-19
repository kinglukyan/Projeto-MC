-- 033: corrige column u.wins does not exist ao resolver um empate online.
-- Aplicar após a 032. A tabela de baralhos usa victories/defeats/draws.
begin;

create or replace function public._tb_award(mid uuid,winner_team text) returns void
language plpgsql security definer set search_path='' as $$
declare g public.game_matches%rowtype;r record;won boolean;target_xp integer;target_coins integer;
begin
 if winner_team is null or winner_team not in ('player_one','player_two') then
  raise exception 'Equipe vencedora do desempate inválida.';
 end if;
 select * into g from public.game_matches where id=mid for update;
 if not found or g.status<>'completed' then raise exception 'Partida de desempate indisponível.';end if;
 -- Only unresolved draw rows are converted. A retry cannot award them twice.
 for r in select h.* from public.match_history h
  where h.match_id=mid and h.outcome='draw' order by h.player_id for update loop
  won:=case when g.team_size=2 then exists(
   select 1 from public.duo_match_players d where d.match_id=mid and d.player_id=r.player_id
   and d.team=case when winner_team='player_one' then 1 else 2 end)
   else r.player_id=case when winner_team='player_one' then g.player_one else g.player_two end end;
  target_xp:=case when won then 30 else 20 end;
  target_coins:=case when won then 20 else 10 end;
  update public.profiles set
   xp=xp+target_xp-r.xp_earned,mythic_coins=mythic_coins+target_coins-r.coins_earned,
   wins=wins+case when won then 1 else 0 end,
   losses=losses+case when won then 0 else 1 end,
   rating_points=greatest(0,rating_points+case when g.mode='ranked' then case when won then 25 else -25 end else 0 end)
  where id=r.player_id;
  update public.match_history set outcome=case when won then 'victory' else 'defeat' end,
   xp_earned=target_xp,coins_earned=target_coins where match_id=mid and player_id=r.player_id;
  -- track_player_deck_result runs on INSERT only: move the original draw into
  -- the final outcome without incrementing games_played a second time.
  update public.player_deck_usage u set
   victories=u.victories+case when won then 1 else 0 end,
   defeats=u.defeats+case when won then 0 else 1 end,
   draws=greatest(0,u.draws-1)
  where u.player_id=r.player_id and u.deck_key=(
   select d.deck_key from public.player_match_decks d where d.match_id=mid and d.player_id=r.player_id);
 end loop;
end $$;
revoke all on function public._tb_award(uuid,text) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
