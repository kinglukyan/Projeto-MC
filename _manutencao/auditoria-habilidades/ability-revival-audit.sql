-- Complete the exact assignments against the current approved legacy dispatcher.
do $revival_audit$
declare d text;a text;b text;
begin
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$wanted-public._r_power(x->'s',t,u)$a$,$b$wanted-public._x_raw_power(x->'s',t,u,0)$b$);
 if position('fresh_revival_v44' in d)=0 then
  a:=$a$x:=public._r_spawn(x,g->>'cardId',t,owner_id,lane,coalesce((g->>'progress')::integer,0));$a$;
  b:=$b$/* fresh_revival_v44 */ select coalesce(jsonb_agg(value->'uid'),'[]') into ids from jsonb_array_elements(x#>array['s',t,'field']);$b$||a||$b$
   select value into target from jsonb_array_elements(x#>array['s',t,'field']) with ordinality a(value,ordinality) where not(ids ? (value->>'uid')) and value->>'playedBy'=owner_id order by ordinality desc limit 1;
   if target is not null then target:=public._x_memory(x->'s',target,g);x:=public._r_set_unit(x,t,target->>'uid',target);end if;
  $b$;
  if position(a in d)=0 then raise exception 'Ressurreição incompatível com a versão aprovada 025.';end if;
  d:=replace(d,a,b);
  a:=$a$if op='anubis_revive' then target:=x#>array['s',t,'field', (jsonb_array_length(x#>array['s',t,'field'])-1)::text];target:=target||jsonb_build_object('reviveOffset',(e->>'wantedPower')::numeric-public._r_power(x->'s',t,target));x:=public._r_set_unit(x,t,target->>'uid',target);end if;$a$;
  b:=$b$if op='anubis_revive' and target is not null then target:=target||jsonb_build_object('reviveOffset',(e->>'wantedPower')::numeric-public._x_raw_power(x->'s',t,target,0));x:=public._r_set_unit(x,t,target->>'uid',target);end if;$b$;
  if position(a in d)=0 then raise exception 'Ajuste de Anúbis incompatível com a versão aprovada 025.';end if;
  d:=replace(d,a,b);
 end if;execute d;
 d:=pg_get_functiondef('public._r_resolve(jsonb,jsonb)'::regprocedure);
 a:=$a$elsif op='anubis' and public._x_block(x->'s',enemy,public._r_unit(x->'s',enemy,selected),t,'destroy') then null;$a$;
 b:=$b$elsif op='anubis' then
  v:=public._r_unit(x->'s',enemy,selected);
  if v is not null and not public._x_block(x->'s',enemy,v,t,'destroy') then
   delta:=public._r_power(x->'s',enemy,v);x:=public._r_destroy(x,enemy,jsonb_build_array(selected));
   if public._r_unit(x->'s',enemy,selected) is null then x:=public._r_evt(x,e-'selection'||jsonb_build_object('op','anubis_revive','wantedPower',delta));end if;
  end if;$b$;
 d:=replace(d,a,b);execute d;
end $revival_audit$;
