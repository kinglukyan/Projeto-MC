-- An opponent may resolve only a pending choice explicitly assigned to them.
-- The original turn owner confirms the completed chain, so turn advancement
-- continues through the existing executor and cannot skip or steal a turn.
do $preserve_executor$
declare d text;
begin if to_regprocedure('public._security_submit_game_action_v37_before_remake(uuid,jsonb)') is null then d:=pg_get_functiondef('public._security_submit_game_action_v37(uuid,jsonb)'::regprocedure);d:=replace(d,'FUNCTION public._security_submit_game_action_v37(','FUNCTION public._security_submit_game_action_v37_before_remake(');execute d;end if;end $preserve_executor$;
create or replace function public._security_submit_game_action_v37(p_match_id uuid,p_action jsonb) returns public.game_matches language plpgsql volatile security definer set search_path='' as $$
declare g public.game_matches%rowtype;uid uuid:=auth.uid();resources jsonb:='{}';x jsonb;row_item record;t text;participant uuid;pending jsonb;e jsonb;
begin
 select * into g from public.game_matches where id=p_match_id and uid in(player_one,player_two,player_three,player_four) for update;
 if not found then raise exception 'Partida indisponível.';end if;pending:=g.state->'pendingEffect';
 if p_action->>'type'='resolve_effect' and g.turn_user<>uid and pending->>'actor'=uid::text then
  if g.status<>'active' then raise exception 'Esta partida já terminou.';end if;
  if coalesce(g.team_size,1)=2 then
   for row_item in select ps.player_id,ps.private_state,mp.team from public.duo_player_states ps join public.duo_match_players mp on mp.match_id=ps.match_id and mp.player_id=ps.player_id where ps.match_id=g.id for update of ps loop
    t:=case when row_item.team=1 then 'player_one' else 'player_two' end;
    resources:=resources||jsonb_build_object(row_item.player_id::text,row_item.private_state||jsonb_build_object('team',t));
   end loop;
  else resources:=jsonb_build_object(g.player_one::text,(g.state->'player_one')||jsonb_build_object('team','player_one'),g.player_two::text,(g.state->'player_two')||jsonb_build_object('team','player_two'));end if;
  x:=public._r_action(g.state,resources,uid::text,p_action);
  if x#>'{s,pendingEffect}' is null then
   e:=jsonb_build_object('op','remake','rule',jsonb_build_object('op','finish'),'phase','finish','team',pending#>>'{event,team}','owner',pending#>>'{event,owner}','uid',pending#>>'{event,uid}','lane',pending#>'{event,lane}');
   x:=jsonb_set(x,'{s,pendingEffect}',jsonb_build_object('id',gen_random_uuid()::text,'actor',g.turn_user::text,'event',e,'title','Habilidade resolvida','options',jsonb_build_array(public._r_option('confirm','Continuar a partida'))),true);
  end if;
  if coalesce(g.team_size,1)=2 then
   for participant in select player_id from public.duo_player_states where match_id=g.id loop update public.duo_player_states set private_state=public._r_personal(x#>array['r',participant::text]) where match_id=g.id and player_id=participant;end loop;
  else x:=jsonb_set(x,'{s,player_one}',(x#>'{s,player_one}')||public._r_personal(x#>array['r',g.player_one::text]),true);x:=jsonb_set(x,'{s,player_two}',(x#>'{s,player_two}')||public._r_personal(x#>array['r',g.player_two::text]),true);end if;
  update public.game_matches set state=x->'s',turn_deadline=clock_timestamp()+interval '30 seconds' where id=g.id returning * into g;return g;
 end if;
 return public._security_submit_game_action_v37_before_remake(p_match_id,p_action);
end $$;
revoke all on function public._security_submit_game_action_v37(uuid,jsonb) from public,anon,authenticated;

-- Choice options and the reordered private deck must never be sent to rivals
-- or spectators. The actor receives the real pending event through this RPC.
do $getter_backup$
declare d text;
begin if to_regprocedure('public._x_get_online_match_before_remake(uuid)') is null then d:=pg_get_functiondef('public.get_online_match(uuid)'::regprocedure);d:=replace(d,'FUNCTION public.get_online_match(','FUNCTION public._x_get_online_match_before_remake(');execute d;end if;end $getter_backup$;
create or replace function public.get_online_match(p_match_id uuid) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare result jsonb;pending jsonb;
begin result:=public._x_get_online_match_before_remake(p_match_id);pending:=result#>'{match,state,pendingEffect}';
 if jsonb_typeof(pending)='object' and pending->>'actor' is distinct from auth.uid()::text then
  result:=jsonb_set(result,'{match,state,pendingEffect}',jsonb_build_object('id',pending->'id','actor',pending->'actor','title','Outro jogador está resolvendo uma habilidade.'),true);
 end if;return result;
end $$;
revoke all on function public.get_online_match(uuid) from public,anon;
grant execute on function public.get_online_match(uuid) to authenticated;
