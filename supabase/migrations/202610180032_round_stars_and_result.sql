-- 032: Rounds independentes; quem perde o Round perde uma Trixx.
-- Aplicar depois da 031.
begin;

do $round_stars$
declare f record;definition text;updated text;patched integer:=0;
begin
 for f in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('_submit_game_action_1v1','submit_duo_game_action') loop
  definition:=pg_get_functiondef(f.oid);updated:=definition;
  if position('ROUND_LOSER_STARS_V32' in definition)>0 then patched:=patched+1;continue;end if;
  if f.proname='_submit_game_action_1v1' then
   updated:=replace(updated,
    $old$if one_score>two_score then one_state:=jsonb_set(one_state,'{trixx}',to_jsonb(greatest(0,(one_state->>'trixx')::integer-1)),true);$old$,
    $new$if one_score>two_score then two_state:=jsonb_set(two_state,'{trixx}',to_jsonb(greatest(0,(two_state->>'trixx')::integer-1)),true);$new$);
   updated:=replace(updated,
    $old$elsif two_score>one_score then two_state:=jsonb_set(two_state,'{trixx}',to_jsonb(greatest(0,(two_state->>'trixx')::integer-1)),true);$old$,
    $new$elsif two_score>one_score then one_state:=jsonb_set(one_state,'{trixx}',to_jsonb(greatest(0,(one_state->>'trixx')::integer-1)),true);$new$);
  else
   updated:=replace(updated,
    $old$if score_one>score_two then side:=jsonb_set(side,'{trixx}',to_jsonb(greatest(0,(side->>'trixx')::integer-1)),true);$old$,
    $new$if score_one>score_two then other_side:=jsonb_set(other_side,'{trixx}',to_jsonb(greatest(0,(other_side->>'trixx')::integer-1)),true);$new$);
   updated:=replace(updated,
    $old$elsif score_two>score_one then other_side:=jsonb_set(other_side,'{trixx}',to_jsonb(greatest(0,(other_side->>'trixx')::integer-1)),true);$old$,
    $new$elsif score_two>score_one then side:=jsonb_set(side,'{trixx}',to_jsonb(greatest(0,(side->>'trixx')::integer-1)),true);$new$);
   -- Persist the two team objects before the cleanup reloads them from s.
   updated:=replace(updated,
    $old$s:=public._r_clear_round(s);foreach side_key in array array['player_one','player_two'] loop$old$,
    $new$/* DUO_ROUND_STATE_V32 */ s:=jsonb_set(s,'{player_one}',side,true);s:=jsonb_set(s,'{player_two}',other_side,true);s:=public._r_clear_round(s);foreach side_key in array array['player_one','player_two'] loop$new$);
   if position('DUO_ROUND_STATE_V32' in updated)=0 then
    raise exception 'Limpeza de Round 2x2 incompatível. Aplique as migrações anteriores à 032.';
   end if;
  end if;
  if updated=definition or position('public._r_score(s,' in updated)=0 then
   raise exception 'Finalização de Round incompatível em %. Nenhuma alteração foi aplicada.',f.proname;
  end if;
  updated:=regexp_replace(updated,'\mBEGIN\M','begin /* ROUND_LOSER_STARS_V32 */','i');
  execute updated;patched:=patched+1;
 end loop;
 if patched<>2 then raise exception 'Funções de combate ausentes. Aplique as migrações anteriores à 032.';end if;
end $round_stars$;

-- roundWins is the authoritative history for remaining stars. This also repairs
-- the display of an ongoing match with inverted stars on its next state update.
create or replace function public._round_stars_from_losses()
returns trigger language plpgsql set search_path='' as $$
begin
 if jsonb_typeof(new.state->'roundWins')='object'
 and jsonb_typeof(new.state->'player_one')='object'
 and jsonb_typeof(new.state->'player_two')='object' then
  new.state:=jsonb_set(new.state,'{player_one,trixx}',to_jsonb(greatest(0,least(2,
   2-coalesce((new.state#>>'{roundWins,player_two}')::integer,0)))),true);
  new.state:=jsonb_set(new.state,'{player_two,trixx}',to_jsonb(greatest(0,least(2,
   2-coalesce((new.state#>>'{roundWins,player_one}')::integer,0)))),true);
 end if;
 return new;
end $$;
revoke all on function public._round_stars_from_losses() from public,anon,authenticated;
drop trigger if exists zz_round_stars_from_losses on public.game_matches;
create trigger zz_round_stars_from_losses before insert or update on public.game_matches
for each row execute function public._round_stars_from_losses();

-- Preserve each Round's score independently. The legacy totalPoints field is
-- kept for compatibility but now holds only this Round's score, never a sum.
create or replace function public._round_points_snapshot(s jsonb,a numeric,b numeric)
returns jsonb language plpgsql immutable set search_path='' as $$
declare summary jsonb;
begin
 summary:=jsonb_build_object('round',coalesce((s->>'round')::integer,1),
  'player_one',a,'player_two',b,
  'winner',case when a>b then 'player_one' when b>a then 'player_two' else null end);
 s:=jsonb_set(s,'{roundSummary}',summary,true);
 s:=jsonb_set(s,'{lastRoundPoints}',jsonb_build_object('player_one',a,'player_two',b),true);
 s:=jsonb_set(s,'{roundScores}',coalesce(s->'roundScores','[]'::jsonb)||jsonb_build_array(summary),true);
 return s;
end $$;
revoke all on function public._round_points_snapshot(jsonb,numeric,numeric) from public,anon,authenticated;

do $individual_rounds$
declare f record;definition text;updated text;patched integer:=0;
begin
 for f in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('_submit_game_action_1v1','submit_duo_game_action') loop
  definition:=pg_get_functiondef(f.oid);updated:=definition;
  if position('INDIVIDUAL_ROUNDS_V32' in definition)>0 then patched:=patched+1;continue;end if;
  -- Replace only the old cumulative arithmetic, preserving numeric precision.
  updated:=regexp_replace(updated,
   $p$one_total:=coalesce\(\(s#>>'\{totalPoints,player_one\}'\)::(integer|numeric),0\)\+one_score;$p$,
   'one_total:=one_score;');
  updated:=regexp_replace(updated,
   $p$two_total:=coalesce\(\(s#>>'\{totalPoints,player_two\}'\)::(integer|numeric),0\)\+two_score;$p$,
   'two_total:=two_score;');
  updated:=regexp_replace(updated,
   $p$total_one:=coalesce\(\(s#>>'\{totalPoints,player_one\}'\)::(integer|numeric),0\)\+score_one;$p$,
   'total_one:=score_one;');
  updated:=regexp_replace(updated,
   $p$total_two:=coalesce\(\(s#>>'\{totalPoints,player_two\}'\)::(integer|numeric),0\)\+score_two;$p$,
   'total_two:=score_two;');
  if f.proname='_submit_game_action_1v1' then
   updated:=replace(updated,'next_round<=2 or (next_round=3 and one_total=two_total)',
    $n$next_round<=3 and greatest(coalesce((s#>>'{roundWins,player_one}')::integer,0),coalesce((s#>>'{roundWins,player_two}')::integer,0))<2$n$);
   updated:=replace(updated,
    'case when one_total>two_total then g.player_one when two_total>one_total then g.player_two else null end',
    $n$case when coalesce((s#>>'{roundWins,player_one}')::integer,0)>coalesce((s#>>'{roundWins,player_two}')::integer,0) then g.player_one when coalesce((s#>>'{roundWins,player_two}')::integer,0)>coalesce((s#>>'{roundWins,player_one}')::integer,0) then g.player_two else null end$n$);
   updated:=replace(updated,'s:=public._r_clear_round(s);one_state:=',
    's:=public._round_points_snapshot(s,one_score,two_score);s:=public._r_clear_round(s);one_state:=');
  else
   updated:=replace(updated,
    $o$coalesce((s->>'round')::integer,1)<2 or (coalesce((s->>'round')::integer,1)=2 and total_one=total_two)$o$,
    $n$coalesce((s->>'round')::integer,1)<3 and greatest(coalesce((s#>>'{roundWins,player_one}')::integer,0),coalesce((s#>>'{roundWins,player_two}')::integer,0))<2$n$);
   updated:=replace(updated,
    'case when total_one>total_two then g.player_one when total_two>total_one then g.player_two else null end',
    $n$case when coalesce((s#>>'{roundWins,player_one}')::integer,0)>coalesce((s#>>'{roundWins,player_two}')::integer,0) then g.player_one when coalesce((s#>>'{roundWins,player_two}')::integer,0)>coalesce((s#>>'{roundWins,player_one}')::integer,0) then g.player_two else null end$n$);
   updated:=replace(updated,'s:=public._r_clear_round(s);foreach side_key',
    's:=public._round_points_snapshot(s,score_one,score_two);s:=public._r_clear_round(s);foreach side_key');
  end if;
  if updated=definition or position('public._round_points_snapshot(s,' in updated)=0
  or updated~'(one_total>two_total|total_one>total_two|one_total=two_total|total_one=total_two)'
  or updated~$p$coalesce\(\(s#>>'\{totalPoints,[^']+\}'\)::(integer|numeric),0\)\+(one_score|two_score|score_one|score_two)$p$
  then raise exception 'Estrutura de Rounds incompatível em %. Nenhuma alteração foi aplicada.',f.proname;end if;
  updated:=regexp_replace(updated,'\mBEGIN\M','begin /* INDIVIDUAL_ROUNDS_V32 */','i');
  execute updated;patched:=patched+1;
 end loop;
 if patched<>2 then raise exception 'Funções de combate ausentes para a regra de Rounds.';end if;
end $individual_rounds$;

-- The cinematic used to infer each Round by subtracting cumulative totals.
-- The saved snapshot now contains the exact score of that individual Round.
do $round_cinematic$
declare definition text;updated text;
begin
 definition:=pg_get_functiondef('public._cinematic_round_transition()'::regprocedure);
 updated:=replace(definition,
  $o$coalesce((new.state#>>'{totalPoints,player_one}')::numeric,0)-coalesce((old.state#>>'{totalPoints,player_one}')::numeric,0)$o$,
  $n$coalesce((new.state#>>'{lastRoundPoints,player_one}')::numeric,0)$n$);
 updated:=replace(updated,
  $o$coalesce((new.state#>>'{totalPoints,player_two}')::numeric,0)-coalesce((old.state#>>'{totalPoints,player_two}')::numeric,0)$o$,
  $n$coalesce((new.state#>>'{lastRoundPoints,player_two}')::numeric,0)$n$);
 if updated=definition and position('lastRoundPoints,player_one' in definition)=0 then
  raise exception 'Animação de Round incompatível.';
 end if;
 execute updated;
end $round_cinematic$;

-- Reward outcomes already use winner_id. Record the series score (Rounds won)
-- in the history rather than a sum of power across unrelated Rounds.
do $round_history$
declare f record;definition text;updated text;
begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('reward_completed_match','reward_duo_completed_match') loop
  definition:=pg_get_functiondef(f.oid);
  updated:=replace(definition,$o$new.state->'totalPoints'$o$,$n$new.state->'roundWins'$n$);
  updated:=replace(updated,$o$new.state#>>'{totalPoints,$o$,$n$new.state#>>'{roundWins,$n$);
  if updated<>definition then execute updated;end if;
 end loop;
end $round_history$;

notify pgrst,'reload schema';
commit;
