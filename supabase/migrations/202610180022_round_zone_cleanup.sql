-- Apply after 021. Clear shared zones together with all round effects.
begin;
do $patch$
declare definition text;anchor text;
begin
 definition:=pg_get_functiondef('public._r_clear_round(jsonb)'::regprocedure);
 anchor:=$a$x:=public._r_destroy(x,t,ids,false);$a$;
 if position('round_zone_cleanup_v22' in definition)=0 then
  if position(anchor in definition)=0 then raise exception 'Versão de limpeza desconhecida; nenhuma alteração aplicada.';end if;
  -- Destroy/move units first so graveyard records retain their original identities.
  definition:=replace(definition,$a$return jsonb_set(jsonb_set(jsonb_set($a$,$b$x:=jsonb_set(x,'{s,sharedZones}','{"local":null,"terrain":null,"climate":null}'::jsonb,true); -- round_zone_cleanup_v22
return jsonb_set(jsonb_set(jsonb_set($b$);
  if position('round_zone_cleanup_v22' in definition)=0 then raise exception 'Retorno de limpeza desconhecido; nenhuma alteração aplicada.';end if;
  execute definition;
 end if;
end $patch$;
notify pgrst,'reload schema';
commit;
