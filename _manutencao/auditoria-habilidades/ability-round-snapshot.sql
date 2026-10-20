-- Round cleanup is simultaneous: record every final power before removing any aura.
create or replace function public._r_clear_round(s jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare x jsonb:=jsonb_build_object('s',s,'r','{}'::jsonb);z text;t text;snapshot jsonb:='{}';part jsonb;
begin
 foreach t in array array['player_one','player_two'] loop
  select coalesce(jsonb_object_agg(value->>'uid',public._r_power(s,t,value)),'{}') into part from jsonb_array_elements(coalesce(s#>array[t,'field'],'[]'));
  snapshot:=snapshot||part;
 end loop;
 x:=jsonb_set(x,'{s,clearRoundPowers}',snapshot,true);
 foreach z in array array['local','terrain','climate'] loop x:=public._x_discard_zone(x,z);end loop;
 return public._r_clear_round_before_audit44(x->'s')-'zoneCards'-'clearRoundPowers';
end $$;
do $round_power_snapshot$
declare d text;
begin
 d:=pg_get_functiondef('public._r_destroy(jsonb,text,jsonb,boolean)'::regprocedure);
 d:=replace(d,$a$death:=public._r_power(x->'s',t,u);$a$,$b$death:=case when not killed and coalesce(x#>'{s,clearRoundPowers}','{}') ? (u->>'uid') then (x#>>array['s','clearRoundPowers',u->>'uid'])::numeric else public._r_power(x->'s',t,u) end;$b$);
 execute d;
end $round_power_snapshot$;
