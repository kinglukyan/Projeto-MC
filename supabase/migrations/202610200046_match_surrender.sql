-- 046: desistência confirmada. Aplicar após 045.
begin;
create or replace function public.surrender_game_match(p_match_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare uid uuid:=auth.uid();g public.game_matches%rowtype;run public.guardian_campaign_runs%rowtype;
 s jsonb;loser text;winner uuid;one numeric;two numeric;
begin
 perform public._security_rpc_gate('surrender_game_match',12);
 -- Same ordering as campaign actions: caller lock before the battle row.
 perform pg_advisory_xact_lock(hashtextextended('guardian:'||uid::text,0));
 select * into g from public.game_matches where id=p_match_id and uid in(player_one,player_two,player_three,player_four) for update;
 if not found then
  select * into run from public.guardian_campaign_runs where id=p_match_id and player_id=uid for update;
  if not found then raise exception 'Partida indisponível.';end if;
  if run.status='active' then
   perform public.guardian_campaign_action(run.id,jsonb_build_object('type','surrender'),run.version,gen_random_uuid());
   update public.guardian_campaign_runs set context=jsonb_set(context,'{s}',
    ((context->'s')-'pendingEffect'-'abilityPhase'-'eclipseReveal'-'roundSummary'-'roundReadyAt')||jsonb_build_object(
     'effectQueue','[]'::jsonb,'visualEvents','[]'::jsonb,'matchEndReason','surrender'))
   where id=run.id returning * into run;
  end if;
  return jsonb_build_object('campaign',public._gc_snapshot(run));
 end if;
 -- A repeated request, or a result that arrived while the dialog was open,
 -- must never change the already committed winner or grant rewards again.
 if g.status<>'active' then return jsonb_build_object('completed',true);end if;
 loser:=case when uid in(g.player_one,g.player_three) then 'player_one' else 'player_two' end;
 winner:=case when loser='player_one' then g.player_two else g.player_one end;
 if winner is null then raise exception 'O adversário desta partida não está disponível.';end if;
 s:=g.state;one:=public._r_score(s,'player_one');two:=public._r_score(s,'player_two');
 if not exists(select 1 from jsonb_array_elements(coalesce(s->'roundScores','[]')) where value->>'round'=s->>'round') then
  s:=jsonb_set(s,'{roundScores}',coalesce(s->'roundScores','[]')||jsonb_build_array(jsonb_build_object('round',coalesce((s->>'round')::integer,1),'player_one',one,'player_two',two,'in_progress',true)));
 end if;
 s:=s-'pendingEffect'-'abilityPhase'-'eclipseReveal'-'roundReadyAt'-'roundSummary';
 s:=s||jsonb_build_object('finished',true,'winner_id',winner,'matchEndReason','surrender',
  'forfeit',jsonb_build_object('actor',uid,'team',loser,'at',clock_timestamp()),'effectQueue','[]'::jsonb,'visualEvents','[]'::jsonb,
  'lastRoundPoints',jsonb_build_object('player_one',one,'player_two',two));
 s:=jsonb_set(s,'{log}',jsonb_build_array('A partida terminou por desistência.')||coalesce(s->'log','[]'));
 -- Existing completion triggers record history, ranked stars and rewards once.
 -- Round wins and completed Round scores retain their real values.
 update public.game_matches set state=s,status='completed',winner_id=winner,turn_user=null,turn_deadline=null,finished_at=clock_timestamp() where id=g.id;
 perform public._security_event('match_surrender','info',g.id,jsonb_build_object('team',loser));
 return jsonb_build_object('completed',true);
end $$;
revoke all on function public.surrender_game_match(uuid) from public,anon;
grant execute on function public.surrender_game_match(uuid) to authenticated;

-- Keep the existing report intact and append the reason for ending the game.
do $report$ begin
 if to_regprocedure('public._match_report_before_surrender46(uuid)') is null then
  alter function public.get_match_report(uuid) rename to _match_report_before_surrender46;
 end if;
end $report$;
create or replace function public.get_match_report(p_match_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare result jsonb;reason text;
begin
 result:=public._match_report_before_surrender46(p_match_id);
 select state->>'matchEndReason' into reason from public.game_matches where id=p_match_id and auth.uid() in(player_one,player_two,player_three,player_four);
 return result||jsonb_build_object('end_reason',reason);
end $$;
revoke all on function public._match_report_before_surrender46(uuid) from public,anon,authenticated;
revoke all on function public.get_match_report(uuid) from public,anon;
grant execute on function public.get_match_report(uuid) to authenticated;

do $campaign_report$ begin
 if to_regprocedure('public._guardian_report_before_surrender46(uuid)') is null then
  alter function public.get_guardian_campaign_report(uuid) rename to _guardian_report_before_surrender46;
 end if;
end $campaign_report$;
create or replace function public.get_guardian_campaign_report(p_run_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare result jsonb;reason text;
begin
 result:=public._guardian_report_before_surrender46(p_run_id);
 select context#>>'{s,matchEndReason}' into reason from public.guardian_campaign_runs where id=p_run_id and player_id=auth.uid();
 return result||jsonb_build_object('end_reason',reason);
end $$;
revoke all on function public._guardian_report_before_surrender46(uuid) from public,anon,authenticated;
revoke all on function public.get_guardian_campaign_report(uuid) from public,anon;
grant execute on function public.get_guardian_campaign_report(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
