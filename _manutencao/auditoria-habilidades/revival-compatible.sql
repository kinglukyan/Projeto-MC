-- Stable resurrection handler; it does not depend on variable names in older dispatchers.
create or replace function public._x_legacy_revive(x jsonb,e jsonb) returns jsonb
language plpgsql volatile set search_path='' as $$
declare t text:=e->>'team';owner_id text:=e->>'owner';selected text:=e->>'selection';
 g jsonb;fresh jsonb;old_ids jsonb;lane integer:=coalesce((e->>'lane')::integer,0);
begin
 if selected='skip' then return x;end if;
 if e->>'op'<>'anubis_revive' and public._r_unit(x->'s',t,e->>'uid') is null then return x;end if;
 select value into g from jsonb_array_elements(coalesce(x#>array['s',t,'grave'],'[]')) where value->>'uid'=selected limit 1;
 if g is null or not public._r_grave_ok(x,e,g) then raise exception 'Esta carta não pode ser ressuscitada.';end if;
 if not public._card_enabled(g->>'cardId') then return x;end if;
 x:=jsonb_set(x,array['s',t,'grave'],coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['s',t,'grave']) with ordinality a(value,ordinality) where value->>'uid'<>selected),'[]'),true);
 x:=public._r_grave_sync(x,t);
 select coalesce(jsonb_agg(value->'uid'),'[]') into old_ids from jsonb_array_elements(x#>array['s',t,'field']);
 x:=public._r_spawn(x,g->>'cardId',t,owner_id,lane,coalesce((g->>'progress')::integer,0));
 select value into fresh from jsonb_array_elements(x#>array['s',t,'field']) with ordinality a(value,ordinality)
  where not(old_ids ? (value->>'uid')) and value->>'playedBy'=owner_id order by ordinality desc limit 1;
 if fresh is not null then
  fresh:=public._x_memory(x->'s',fresh,g);
  if e->>'op'='anubis_revive' then
   fresh:=fresh||jsonb_build_object('reviveOffset',(e->>'wantedPower')::numeric-public._x_raw_power(x->'s',t,fresh,0));
  end if;
  x:=public._r_set_unit(x,t,fresh->>'uid',fresh);
 end if;
 return x;
end $$;

-- Optional legacy-copy calibrations remain compatible with the old dispatcher.
do $copy_calibration$
declare d text;
begin
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$wanted-public._r_power(x->'s',t,u)$a$,$b$wanted-public._x_raw_power(x->'s',t,u,0)$b$);
 execute d;
end $copy_calibration$;
