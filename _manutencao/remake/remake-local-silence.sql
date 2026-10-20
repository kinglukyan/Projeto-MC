-- A lock on one unit disables its own ability, not its equipment or allied auras.
-- Dionysus continues to suspend all effects according to the approved rules.
create or replace function public._r_shield(s jsonb,t text,l integer) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from jsonb_array_elements(coalesce(s#>array[t,'field'],'[]')) v where coalesce((v->>'lane')::integer,0)=l and public._r_id(v)='heimdall' and coalesce((v->>'silencedJogadas')::integer,0)=0 and not coalesce((v->>'silencedOwnerEnd')::boolean,false) and (public._r_live(s) or s->>'silenceTeam'=public._r_other(t) or coalesce(v->>'silenceExemptStamp'=s->>'silenceStartedBy',false))) $$;
create or replace function public._x_global(s jsonb,t text,u jsonb) returns boolean language sql stable set search_path='' as $$
 select public._r_live(s) or coalesce(u->>'silenceExemptStamp'=s->>'silenceStartedBy',false) or coalesce(s->>'silenceTeam'=public._r_other(t) and public._r_shield(s,t,coalesce((u->>'lane')::integer,0)),false) $$;
create or replace function public._r_active(s jsonb,t text,u jsonb) returns boolean language sql stable set search_path='' as $$
 select public._x_global(s,t,u) and coalesce((u->>'silencedJogadas')::integer,0)=0 and not coalesce((u->>'silencedOwnerEnd')::boolean,false) $$;
do $personal_power$
declare d text;clause text;
begin
 d:=pg_get_functiondef('public._r_power(jsonb,text,jsonb,integer)'::regprocedure);
 d:=replace(d,'if not public._r_active(s,t,u) then return','if not public._x_global(s,t,u) then return');
 foreach clause in array array['if id=''lukyan'' and','if id in (''soldado-esparta'',''guardiao-nordico'') then','if id=''lobo-alfa'' then','if id=''lobo-omega'' and','if id in (''mulher'',''homem'') then','if id=''lukyan-rei-de-todos'' then'] loop
  if position('if public._r_active(s,t,u) and '||substring(clause from 4) in d)=0 then d:=replace(d,clause,'if public._r_active(s,t,u) and '||substring(clause from 4));end if;
 end loop;execute d;
 d:=pg_get_functiondef('public._r_options_before_remake(jsonb,jsonb)'::regprocedure);d:=replace(d,'public._r_active(x->''s'',t,candidate)','public._x_global(x->''s'',t,candidate)');execute d;
end $personal_power$;

-- Achilles' entry bonus belongs to the row in which it was earned.
do $achilles_backup$
declare d text;
begin
 if to_regprocedure('public._r_reconcile_before_remake(jsonb)') is null then d:=pg_get_functiondef('public._r_reconcile(jsonb)'::regprocedure);d:=replace(d,'FUNCTION public._r_reconcile(','FUNCTION public._r_reconcile_before_remake(');execute d;end if;
 d:=pg_get_functiondef('public._r_reconcile_before_remake(jsonb)'::regprocedure);d:=replace(d,'enabled:=public._r_active(x->''s'',t,u);','enabled:=public._x_global(x->''s'',t,u);');execute d;
 d:=replace(d,'if exists(select 1 from jsonb_array_elements(x#>array[''s'',t,''field'']) v where v->>''uid''<>u->>''uid'' and v->>''lane''=u->>''lane'') then u:=u||jsonb_build_object(''bonus''','if public._r_active(x->''s'',t,u) and exists(select 1 from jsonb_array_elements(x#>array[''s'',t,''field'']) v where v->>''uid''<>u->>''uid'' and v->>''lane''=u->>''lane'') then u:=u||jsonb_build_object(''bonus''');execute d;
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 if position('greekBonusLane' in d)=0 then
  d:=replace(d,'x:=public._r_change(x,t,u->>''uid'',t,n);','x:=public._r_change(x,t,u->>''uid'',t,n);v:=public._r_unit(x->''s'',t,u->>''uid'');if v is not null then x:=public._r_set_unit(x,t,v->>''uid'',v||jsonb_build_object(''greekBonusLane'',lane,''greekBonusTeam'',t,''greekBonusAmount'',n));end if;');execute d;
 end if;
end $achilles_backup$;
create or replace function public._r_reconcile(x jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare t text;u jsonb;
begin
 foreach t in array array['player_one','player_two'] loop for u in select value from jsonb_array_elements(coalesce(x#>array['s',t,'field'],'[]')) where value ? 'greekBonusLane' loop
  if u->>'greekBonusLane' is distinct from u->>'lane' or u->>'greekBonusTeam' is distinct from t then u:=(u||jsonb_build_object('bonus',coalesce((u->>'bonus')::numeric,0)-coalesce((u->>'greekBonusAmount')::numeric,0)))-'greekBonusLane'-'greekBonusTeam'-'greekBonusAmount';x:=public._r_set_unit(x,t,u->>'uid',u);end if;
 end loop;end loop;return public._r_reconcile_before_remake(x);
end $$;
