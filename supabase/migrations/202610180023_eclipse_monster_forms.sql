-- Apply after 022. Stable origins for Solar/Lunar transformations.
begin;
create or replace function public._eclipse_form_for(original text,climate text) returns text
language sql immutable set search_path='' as $$
 select case when climate='eclipse-solar' then
  case original when 'lobo-alfa' then 'mulher' when 'lobo-beta' then 'homem' when 'lobo-omega' then 'homem' else original end
 when climate='eclipse-lunar' and lower(btrim(public._r_card(original)->>'faction')) in('monstros','monstro') then
  case original when 'mulher' then 'lobo-alfa' when 'homem' then 'lobo-beta' else original end
 else original end;
$$;
create or replace function public._r_reconcile(x jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare t text;u jsonb;original text;form text;climate text:=x#>>'{s,sharedZones,climate}';enabled boolean:=public._r_live(x->'s');active boolean;
begin
 foreach t in array array['player_one','player_two'] loop
  for u in select value from jsonb_array_elements(coalesce(x#>array['s',t,'field'],'[]'::jsonb)) loop
   if enabled and u->>'cardId'='lukyan' and (u->'equipment') ? 'excalibur' then
    u:=u||jsonb_build_object('sourceCardId','lukyan','cardId','lukyan-rei-de-todos');
   end if;
   original:=coalesce(u->>'eclipseOriginalCardId',u->>'cardId');
   if public._r_card(original)='{}'::jsonb then original:=u->>'cardId';end if;
   active:=enabled and not public._r_protect(x->'s',t,coalesce((u->>'lane')::integer,0),coalesce(x#>>'{s,zoneOwners,climate}',t));
   if active and climate='eclipse-solar' and public._eclipse_is_vampire(original) then
    x:=public._r_destroy(x,t,jsonb_build_array(u->>'uid'));continue;
   end if;
   form:=public._eclipse_form_for(original,case when active then climate else null end);
   if form is distinct from u->>'cardId' then u:=(u-'copiedAbilityId'-'copiedPower')||jsonb_build_object('cardId',form);end if;
   if form is distinct from original then u:=u||jsonb_build_object('eclipseOriginalCardId',original);else u:=u-'eclipseOriginalCardId';end if;
   x:=public._r_set_unit(x,t,u->>'uid',u);
  end loop;
 end loop;
 return x;
end $$;
-- Keep the older climate integration consistent with the current engine.
create or replace function public._eclipse_side(p_side jsonb,p_zones jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare unit jsonb;kept jsonb:='[]'::jsonb;underworld jsonb:=coalesce(p_side->'underworld','[]'::jsonb);original text;form text;climate text:=p_zones->>'climate';
begin
 for unit in select value from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) loop
  original:=coalesce(unit->>'eclipseOriginalCardId',unit->>'cardId');
  if climate='eclipse-solar' and public._eclipse_is_vampire(original) then underworld:=underworld||jsonb_build_array(original);continue;end if;
  form:=public._eclipse_form_for(original,climate);unit:=unit||jsonb_build_object('cardId',form);
  if form is distinct from original then unit:=unit||jsonb_build_object('eclipseOriginalCardId',original);else unit:=unit-'eclipseOriginalCardId';end if;
  kept:=kept||jsonb_build_array(unit);
 end loop;
 return jsonb_set(jsonb_set(p_side,'{field}',kept,true),'{underworld}',underworld,true);
end $$;
-- Normalize persisted forms before processing actions and turn-start effects.
do $init_patch$
declare definition text;
begin
 definition:=pg_get_functiondef('public._r_init(jsonb,jsonb)'::regprocedure);
 if position('return public._r_reconcile(x);' in definition)=0 then
  if position('end loop;return x;' in definition)=0 then raise exception 'Inicialização de habilidades desconhecida; nenhuma alteração aplicada.';end if;
  execute replace(definition,'end loop;return x;','end loop;return public._r_reconcile(x);');
 end if;
end $init_patch$;
update public.card_lore set ability_text='Cada Homem aliado dobra seu poder. No Eclipse Lunar, Mulher da facção Monstros vira Lobisomem Alfa; fora do Lunar, recupera sua forma original.',updated_at=now() where card_id='mulher';
update public.card_lore set ability_text='Cada outro Homem aliado dobra seu poder. No Eclipse Lunar, Homem da facção Monstros vira Lobisomem Beta; fora do Lunar, recupera sua forma original.',updated_at=now() where card_id='homem';
revoke all on function public._eclipse_form_for(text,text),public._r_reconcile(jsonb),public._eclipse_side(jsonb,jsonb) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
