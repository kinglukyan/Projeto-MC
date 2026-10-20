-- Preserve the exact owner's shared cards, so Enki and Isis can recover them later.
do $zone_backups$
declare sig text;n text;d text;
begin
 foreach sig in array array['_r_spawn(jsonb,text,text,text,integer,integer)','_r_clear_round(jsonb)'] loop
  n:=split_part(sig,'(',1);
  if to_regprocedure('public.'||replace(sig,n,n||'_before_audit44')) is null then
   d:=pg_get_functiondef(('public.'||sig)::regprocedure);
   execute replace(d,'FUNCTION public.'||n||'(','FUNCTION public.'||n||'_before_audit44(');
  end if;
 end loop;
end $zone_backups$;
create or replace function public._x_discard_zone(x jsonb,z text) returns jsonb language plpgsql volatile set search_path='' as $$
declare c jsonb:=x#>array['s','zoneCards',z];t text;
begin
 if c is null or c->>'cardId' is null then return x;end if;t:=c->>'team';
 if t not in ('player_one','player_two') then return x;end if;
 x:=jsonb_set(x,array['s',t,'grave'],coalesce(x#>array['s',t,'grave'],'[]')||jsonb_build_array(jsonb_build_object('uid',gen_random_uuid()::text,'cardId',c->>'cardId','owner',c->>'owner','progress',0)),true);
 x:=x#-array['s','zoneCards',z];return public._r_grave_sync(x,t);
end $$;
create or replace function public._r_spawn(x jsonb,cid text,t text,owner_id text,lane integer,progress integer default 0) returns jsonb language plpgsql volatile set search_path='' as $$
declare c jsonb:=public._r_card(cid);z text;
begin
 if c->>'kind' in ('location','terrain','climate','event') then
  z:=case c->>'kind' when 'location' then 'local' when 'terrain' then 'terrain' else 'climate' end;
  -- The original spawn validates whether replacement is legal. An error rolls this whole transaction back.
  x:=public._x_discard_zone(x,z);
  x:=jsonb_set(x,'{s,zoneCards}',coalesce(x#>'{s,zoneCards}','{}')||jsonb_build_object(z,jsonb_build_object('cardId',cid,'owner',owner_id,'team',t)),true);
 end if;
 return public._r_spawn_before_audit44(x,cid,t,owner_id,lane,progress);
end $$;
create or replace function public._r_clear_round(s jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare x jsonb:=jsonb_build_object('s',s,'r','{}'::jsonb);z text;
begin
 foreach z in array array['local','terrain','climate'] loop x:=public._x_discard_zone(x,z);end loop;
 return public._r_clear_round_before_audit44(x->'s')-'zoneCards';
end $$;
