-- Once-per-Round abilities keep their spent state through resurrection.
create or replace function public._x_memory(s jsonb,u jsonb,g jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare k text;
begin if g->>'rebornRound'=s->>'round' then foreach k in array array['rebornOnce','savedOnce','mourningUsed'] loop if coalesce((g->>k)::boolean,false) then u:=u||jsonb_build_object(k,true);end if;end loop;end if;return u;end $$;
do $revive_memory$
declare d text;a text;b text;
begin
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 a:='x:=public._r_spawn(x,cid,t,owner_id,lane,coalesce((g->>''progress'')::integer,0));';
 b:=a||'/* round_memory_v40 */ select value into v from jsonb_array_elements(x#>array[''s'',t,''field'']) with ordinality a(value,ordinality) where value->>''cardId''=cid and value->>''playedBy''=owner_id order by ordinality desc limit 1;if v is not null then x:=public._r_set_unit(x,t,v->>''uid'',public._x_memory(x->''s'',v,g));end if;';
 if position('round_memory_v40' in d)=0 then d:=replace(d,a,b);execute d;end if;
end $revive_memory$;
