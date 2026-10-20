
-- Keep the un-clamped total available for exact copy/swap/rebirth assignments.
do $exact_power$
declare d text;raw_d text;
begin
 d:=pg_get_functiondef('public._r_power(jsonb,text,jsonb,integer)'::regprocedure);
 d:=replace(d,$a$if enemy>p then p:=p+8;end if;$a$,$b$if enemy>public._r_power(s,t,u,1) then p:=p+8;end if;$b$);
 d:=replace(d,$a$p:=greatest(0,floor(p+coalesce((u->>'powerShift')::numeric,0)));$a$,$b$p:=p+coalesce((u->>'powerShift')::numeric,0);$b$);
 execute d;
 raw_d:=replace(d,'FUNCTION public._r_power(','FUNCTION public._x_raw_power(');
 raw_d:=replace(raw_d,$a$p:=greatest(0,floor(p+coalesce((u->>'copyOffset')::numeric,0)+coalesce((u->>'reviveOffset')::numeric,0)));$a$,$b$p:=p+coalesce((u->>'copyOffset')::numeric,0)+coalesce((u->>'reviveOffset')::numeric,0);$b$);
 execute raw_d;
 d:=pg_get_functiondef('public._x_resolve(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$public._x_adjust(u,'powerShift',public._r_power(x->'s',team,v)-public._r_power(x->'s',t,u))$a$,$b$public._x_adjust(u,'powerShift',public._r_power(x->'s',team,v)-public._x_raw_power(x->'s',t,u,0))$b$);
 d:=replace(d,$a$public._x_adjust(u,'powerShift',wanted-p);v:=public._x_adjust(v,'powerShift',p-wanted)$a$,$b$public._x_adjust(u,'powerShift',wanted-public._x_raw_power(x->'s',t,u,0));v:=public._x_adjust(v,'powerShift',p-public._x_raw_power(x->'s',t,v,0))$b$);execute d;
 d:=pg_get_functiondef('public._r_resolve(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$public._x_adjust(v,'powerShift',delta)$a$,$b$public._x_adjust(v,'powerShift',(vals->>i)::numeric-public._x_raw_power(x->'s',team,v,0))$b$);execute d;
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$wanted-public._r_power(x->'s',t,v)$a$,$b$wanted-public._x_raw_power(x->'s',t,v,0)$b$);
 d:=replace(d,$a$snapshot-public._r_power(x->'s',t,u)$a$,$b$snapshot-public._x_raw_power(x->'s',t,u,0)$b$);execute d;
 d:=pg_get_functiondef('public._r_destroy(jsonb,text,jsonb,boolean)'::regprocedure);
 d:=replace(d,$a$3-public._r_power(x->'s',t,v)$a$,$b$3-public._x_raw_power(x->'s',t,v,0)$b$);execute d;
 d:=pg_get_functiondef('public._x_block(jsonb,text,jsonb,text,text)'::regprocedure);
 d:=replace(d,$a$if u ? 'guardOwner' and k in$a$,$b$if u ? 'guardOwner' and public._x_global(s,t,u) and k in$b$);execute d;
end $exact_power$;
