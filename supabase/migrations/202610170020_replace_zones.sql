-- Aplicar após 019. Substituição de zonas e retorno de lobisomens.
begin;
create or replace function public._zone_is_event(c jsonb) returns boolean language sql immutable set search_path='' as $$
 select coalesce(c->>'climateClass'='event',false) or coalesce((c->>'isClimateEvent')::boolean,false) or coalesce(c->>'id' ~ '^eclipse(-|$)',false) or coalesce((coalesce(c->>'subtype',c->>'type','')) ~* 'evento',false);
$$;
create or replace function public._zone_can_replace(incoming jsonb,current_card jsonb) returns boolean language sql immutable set search_path='' as $$
 select coalesce(incoming->>'kind', '') in ('location','terrain','event','climate','weather') and
 (current_card is null or current_card='{}'::jsonb or
 (case when incoming->>'kind' in('event','climate','weather') then 'climate' else incoming->>'kind' end = case when current_card->>'kind' in('event','climate','weather') then 'climate' else current_card->>'kind' end
 and (incoming->>'kind' not in('event','climate','weather') or not public._zone_is_event(current_card) or public._zone_is_event(incoming))));
$$;
create or replace function public._entry_visual(x jsonb,cid text,t text,unit_id text) returns jsonb language plpgsql volatile set search_path='' as $$
declare events jsonb;
begin
 events:=coalesce(x#>'{s,visualEvents}','[]'::jsonb)||jsonb_build_array(jsonb_build_object('id',pg_catalog.gen_random_uuid()::text,'kind','enter','team',t,'targets',case when unit_id is null then '[]'::jsonb else jsonb_build_array(unit_id) end,'sourceCardId',cid,'round',x#>'{s,round}'));
 select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into events from jsonb_array_elements(events) with ordinality where ordinality>greatest(0,jsonb_array_length(events)-80);
 return jsonb_set(x,'{s,visualEvents}',events,true);
end $$;
revoke all on function public._entry_visual(jsonb,text,text,text) from public,anon,authenticated;
do $patch$
declare d text;old_text text;new_text text;
begin
 d:=pg_get_functiondef('public._r_spawn(jsonb,text,text,text,integer,integer)'::regprocedure);
 old_text:=$a$if x#>>array['s','sharedZones',zone] is not null then raise exception 'O espaço compartilhado já está ocupado.';end if;$a$;
 new_text:=$b$if not public._zone_can_replace(c,public._r_card(x#>>array['s','sharedZones',zone])) then raise exception 'Somente Clima/Evento pode substituir o Clima/Evento ativo.';end if;$b$;
 if position('public._zone_can_replace' in d)=0 then
  if position(old_text in d)=0 then raise exception 'Versão de _r_spawn desconhecida; nenhuma alteração aplicada.';end if;
  execute replace(d,old_text,new_text);
 end if;
 d:=pg_get_functiondef('public._r_spawn(jsonb,text,text,text,integer,integer)'::regprocedure);
 old_text:=$a$x:=jsonb_set(x,array['s',t,'field'],(x#>array['s',t,'field'])||jsonb_build_array(u),true);$a$;
 if position('public._entry_visual' in d)=0 then
  if position(old_text in d)=0 then raise exception 'Entrada de carta desconhecida; nenhuma alteração aplicada.';end if;
  execute replace(d,old_text,old_text||$b$x:=public._entry_visual(x,cid,t,u->>'uid');$b$);
 end if;
 d:=pg_get_functiondef('public._r_spawn(jsonb,text,text,text,integer,integer)'::regprocedure);
 old_text:=$a$elsif c->>'kind'='equipment' then$a$;
 if position('public._entry_visual(x,cid,t,null)' in d)=0 then
  if position(old_text in d)=0 then raise exception 'Entrada de equipamento desconhecida.';end if;
  d:=replace(d,old_text,old_text||' x:=public._entry_visual(x,cid,t,null);');
  old_text:=$a$x:=jsonb_set(x,array['s','zoneOwners',zone],to_jsonb(t),true);$a$;
  if position(old_text in d)=0 then raise exception 'Entrada de zona desconhecida.';end if;
  execute replace(d,old_text,old_text||' x:=public._entry_visual(x,cid,t,null);');
 end if;
 d:=pg_get_functiondef('public._r_reconcile(jsonb)'::regprocedure);
 old_text:=$a$if x#>>'{s,sharedZones,climate}' is distinct from 'eclipse-solar' then continue;end if;$a$;
 new_text:=$b$if x#>>'{s,sharedZones,climate}' is distinct from 'eclipse-solar' then
   if u->>'eclipseOriginalCardId' is not null then u:=jsonb_set(u-'eclipseOriginalCardId','{cardId}',u->'eclipseOriginalCardId');x:=public._r_set_unit(x,t,u->>'uid',u);end if;
   continue;end if;$b$;
 if position('jsonb_set(u-''eclipseOriginalCardId''' in d)=0 then
  if position(old_text in d)=0 then raise exception 'Versão de _r_reconcile desconhecida; nenhuma alteração aplicada.';end if;
  execute replace(d,old_text,new_text);
 end if;
 d:=pg_get_functiondef('public._r_grave_ok(jsonb,jsonb,jsonb)'::regprocedure);
 old_text:=$a$return x#>>array['s','sharedZones',zone] is null;$a$;
 if position(old_text in d)>0 then execute replace(d,old_text,$b$return public._zone_can_replace(c,public._r_card(x#>>array['s','sharedZones',zone]));$b$);end if;
end $patch$;
revoke all on function public._zone_is_event(jsonb),public._zone_can_replace(jsonb,jsonb) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
