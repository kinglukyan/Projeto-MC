-- Validate choices through the stable function interface, independently of its source formatting.
do $choice_guard$
declare definition text;arguments text;
begin
 if to_regprocedure('public._r_action_before_audit44(jsonb,jsonb,text,jsonb)') is null then
  definition:=pg_get_functiondef('public._r_action(jsonb,jsonb,text,jsonb)'::regprocedure);
  execute replace(definition,'FUNCTION public._r_action(','FUNCTION public._r_action_before_audit44(');
 end if;
 arguments:=pg_get_function_arguments('public._r_action(jsonb,jsonb,text,jsonb)'::regprocedure);
 execute format($definition$
  create or replace function public._r_action(%s) returns jsonb
  language plpgsql volatile set search_path='' as $wrapper$
  declare audit_context jsonb; audit_pending jsonb; audit_options jsonb;
  begin
   /* choice_wrapper_v44: retain all existing action/security/pause checks. */
   audit_context:=public._r_init($1,$2);
   if $4->>'type'='resolve_effect' then
    audit_pending:=audit_context#>'{s,pendingEffect}';
    if audit_pending is null
      or audit_pending->>'actor' is distinct from $3
      or audit_pending->>'id' is distinct from $4->>'choice_id' then
     raise exception 'Esta escolha não está mais disponível.';
    end if;
    audit_options:=public._r_options(audit_context,audit_pending->'event');
    if not exists(select 1 from jsonb_array_elements(coalesce(audit_options,'[]'::jsonb)) choice
      where choice->>'value'=$4->>'choice_value') then
     raise exception 'Essa escolha não está mais disponível.';
    end if;
   end if;
   return public._r_action_before_audit44(audit_context->'s',audit_context->'r',$3,$4);
  end $wrapper$;
 $definition$,arguments);
end $choice_guard$;
