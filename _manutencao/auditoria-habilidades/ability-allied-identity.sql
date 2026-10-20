
-- Faction/tag checks must use copied identities, just like Locations and auras do.
do $allied_identity$
declare d text;
begin
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$public._r_card(a->>'cardId')$a$,$b$public._r_card(public._r_identity(a))$b$);
 d:=replace(d,$a$a->>'cardId'='leonidas'$a$,$b$public._r_identity(a)='leonidas'$b$);
 d:=replace(d,$a$public._r_card(v->>'cardId')$a$,$b$public._r_card(public._r_identity(v))$b$);
 d:=replace(d,$a$v->>'cardId'='leonidas'$a$,$b$public._r_identity(v)='leonidas'$b$);execute d;
end $allied_identity$;
