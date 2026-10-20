-- A timed-out opponent choice cannot hold the original turn indefinitely.
do $action_backup$
declare d text;
begin if to_regprocedure('public._r_action_before_remake(jsonb,jsonb,text,jsonb)') is null then d:=pg_get_functiondef('public._r_action(jsonb,jsonb,text,jsonb)'::regprocedure);d:=replace(d,'FUNCTION public._r_action(','FUNCTION public._r_action_before_remake(');execute d;end if;end $action_backup$;
create or replace function public._r_action(s jsonb,resources jsonb,actor text,a jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare x jsonb;p jsonb:=s->'pendingEffect';e jsonb;
begin
 if a->>'type'='skip_turn' and p->>'actor' is distinct from actor and p->>'expiresAt' is not null and (p->>'expiresAt')::timestamptz<=clock_timestamp() then
  x:=public._r_init(s,resources);e:=(p->'event')||jsonb_build_object('selection',p#>>'{options,0,value}');x:=x#-'{s,pendingEffect}';x:=jsonb_set(x,'{s,effectQueue}',jsonb_build_array(e)||coalesce(x#>'{s,effectQueue}','[]'),true);x:=public._r_drain(x,true);x:=x#-'{s,abilityPhase}';x:=jsonb_set(x,array['r',actor,'skipNextTurn'],'false'::jsonb,true);return jsonb_set(x,array['r',actor,'playedThisTurn'],'true'::jsonb,true);
 end if;return public._r_action_before_remake(s,resources,actor,a);
end $$;
do $choice_deadline$
declare d text;a text;b text;
begin d:=pg_get_functiondef('public._r_drain(jsonb,boolean)'::regprocedure);
 a:='x:=jsonb_set(x,''{s,pendingEffect}'',pending,true);';b:='pending:=pending||jsonb_build_object(''expiresAt'',clock_timestamp()+interval ''30 seconds'');'||a;
 if position(b in d)=0 then d:=replace(d,a,b);execute d;end if;
end $choice_deadline$;
