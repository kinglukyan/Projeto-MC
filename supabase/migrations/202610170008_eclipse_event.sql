-- Apply after 202610170007_equipment_cards.sql.
-- The server draws one outcome at play time and persists it for all clients.
begin;
alter table public.card_lore drop constraint if exists card_lore_card_id_check;
alter table public.card_lore add constraint card_lore_card_id_check check(card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','lobo-omega','lukyan','anubis','odin','lukyan-rei-de-todos','minotauro','apolo','ra','ragnar','afrodite','aquiles','seth','osiris','thor','artemis','sobek','ares','beowulf','heimdall','dionisio','butter','hefesto','hercules','hermes','horus','lobo-beta','isis','mulher','homem','yggdrasil','alto-egito','baixo-egito','bifrost','esparta','labirinto-dedalos','nilfheim','asgard','egito','olho-que-tudo-ve','raio-de-zeus','excalibur','eclipse-lunar','eclipse-solar'));
insert into public.card_lore(card_id,card_name,ability_title,ability_text,art_url,faction,power) values
('eclipse','Eclipse','Destino Celestial','Ao jogar na área de Clima/Evento, sorteia Eclipse Lunar ou Solar, com 50% de chance para cada. O resultado afeta os dois lados até o fim da rodada.','assets/eclipse/eclipse.png','Universal',0),
('eclipse-lunar','Eclipse Lunar','Destino Celestial','Dobra o poder dos lobisomens, vampiros e de Ártemis. Apolo e Rá perdem metade do poder, arredondada para baixo.','assets/eclipse/eclipse-lunar.png','Universal',0),
('eclipse-solar','Eclipse Solar','Destino Celestial','Dobra o poder de Apolo e Rá. Vampiros vão ao Submundo; lobisomens Beta e Omega viram Homem, e Alfa vira Mulher. Ártemis perde metade do poder, arredondada para baixo.','assets/eclipse/eclipse-solar.png','Universal',0)
on conflict(card_id) do update set card_name=excluded.card_name,ability_title=excluded.ability_title,ability_text=excluded.ability_text,art_url=excluded.art_url,faction=excluded.faction,power=excluded.power,badge_key=null,updated_at=now();

create or replace function public._eclipse_is_vampire(p_card_id text)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(p_card_id ~ '^vampir' or p_card_id='dracula',false);
$$;
create or replace function public._eclipse_power(p_side jsonb,p_unit jsonb,p_power integer,p_climate text)
returns integer language plpgsql immutable set search_path='' as $$
declare cid text:=p_unit->>'cardId'; total integer:=greatest(0,p_power); men integer;
begin
 if cid in ('mulher','homem') then
  select count(*)::integer into men from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) a(value) where a.value->>'cardId'='homem';
  total:=total*(2^greatest(0,men-case when cid='homem' then 1 else 0 end))::integer;
 end if;
 if p_climate='eclipse-lunar' then
  if cid in ('lobo-alfa','lobo-beta','lobo-omega','artemis') or public._eclipse_is_vampire(cid) then total:=total*2;end if;
  if cid in ('apolo','ra') then total:=total/2;end if;
 elsif p_climate='eclipse-solar' then
  if cid in ('apolo','ra') then total:=total*2;end if;
  if cid='artemis' then total:=total/2;end if;
 end if;
 return greatest(0,total);
end;
$$;

create or replace function public._eclipse_side(p_side jsonb,p_zones jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare unit jsonb; kept jsonb:='[]'::jsonb; underworld jsonb:=coalesce(p_side->'underworld','[]'::jsonb); form text;
begin
 if p_zones->>'climate' is distinct from 'eclipse-solar' then return p_side;end if;
 for unit in select value from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) loop
  if public._eclipse_is_vampire(unit->>'cardId') then
   underworld:=underworld||jsonb_build_array(coalesce(unit->>'eclipseOriginalCardId',unit->>'cardId'));
   continue;
  end if;
  form:=case unit->>'cardId' when 'lobo-beta' then 'homem' when 'lobo-omega' then 'homem' when 'lobo-alfa' then 'mulher' else null end;
  if form is not null then
   unit:=jsonb_set(unit,'{eclipseOriginalCardId}',unit->'cardId',true);
   unit:=jsonb_set(unit,'{cardId}',to_jsonb(form),true);
  end if;
  kept:=kept||jsonb_build_array(unit);
 end loop;
 return jsonb_set(jsonb_set(p_side,'{field}',kept,true),'{underworld}',underworld,true);
end;
$$;

create or replace function public._eclipse_state(p_state jsonb,p_zones jsonb)
returns jsonb language plpgsql volatile set search_path='' as $$
declare result jsonb:=p_state; side_key text;
begin
 foreach side_key in array array['player_one','player_two'] loop
  result:=jsonb_set(result,array[side_key],public._eclipse_side(result->side_key,p_zones),true);
 end loop;
 if p_zones->>'climate' in ('eclipse-lunar','eclipse-solar') and
  (result#>>'{eclipseReveal,round}' is distinct from result->>'round' or result#>>'{eclipseReveal,outcome}' is distinct from p_zones->>'climate') then
  result:=jsonb_set(result,'{eclipseReveal}',jsonb_build_object('id',pg_catalog.gen_random_uuid()::text,'outcome',p_zones->>'climate','round',result->'round'),true);
 end if;
 return result;
end;
$$;
create or replace function public._online_unit_power(p_side jsonb,p_unit jsonb,p_zones jsonb)
returns integer language plpgsql security definer set search_path='' stable as $$
declare cid text:=p_unit->>'cardId'; meta jsonb:=public._terrain_card_meta(p_unit->>'cardId');
 base_power integer; soldiers integer; aura_count integer; total integer;
begin
 base_power:=coalesce((meta->>'power')::integer,0);
 if cid='soldado-esparta' then
  select count(*)::integer into soldiers from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) u where u->>'cardId'='soldado-esparta';
  base_power:=base_power*(2^greatest(soldiers-1,0))::integer;
 end if;
 total:=base_power+coalesce((p_unit->>'bonus')::integer,0);
 select count(*)::integer into aura_count from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) u
  where u->>'cardId'='athena' and coalesce((u->>'lane')::integer,0)=coalesce((p_unit->>'lane')::integer,0);
 total:=total+2*greatest(0,aura_count-case when cid='athena' then 1 else 0 end);
 if cid='lobo-alfa' then total:=total+2*(select count(*)::integer from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) u where u->>'cardId'='lobo-beta'); end if;
 if meta->>'faction'='Grécia' then total:=total+coalesce((p_side->>'greekAura')::integer,0); end if;
 if meta->>'faction'='Nórdicos' then total:=total+coalesce((p_side->>'norseAura')::integer,0); end if;
 total:=total+public._location_bonus(p_zones->>'local',cid);
 total:=total+public._terrain_bonus(p_zones->>'terrain',cid);
 if cid='lukyan-rei-de-todos' then total:=total*(2^greatest(0,jsonb_array_length(coalesce(p_side->'field','[]'::jsonb))-1))::integer; end if;
 return public._eclipse_power(p_side,p_unit,greatest(0,total),p_zones->>'climate');
end;
$$;




do $migration$
declare routine record; definition text; original text; anchor text;
begin
 for routine in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.prokind='f' and p.proname in ('submit_game_action','_submit_game_action_1v1','submit_duo_game_action') loop
  definition:=pg_get_functiondef(routine.oid);original:=definition;
  if position('card_id not in' in definition)>0 then
   -- This literal occurs only in the climate placement branch, after the occupied-slot guard.
   definition:=replace(definition,$old$'"eclipse"'::jsonb$old$,$new$to_jsonb(case when random()<0.5 then 'eclipse-lunar'::text else 'eclipse-solar'::text end)$new$);
   definition:=replace(definition,$old$other_side:=jsonb_set(other_side,'{roundPenalty}',to_jsonb(coalesce((other_side->>'roundPenalty')::integer,0)+3),true);$old$,'/* Eclipse now affects unit power on both sides. */');
   if position('public._eclipse_state(s,zones)' in definition)=0 then
    anchor:=$anchor$s:=jsonb_set(s,'{sharedZones}',zones,true);$anchor$;
    if position(anchor in definition)=0 then raise exception 'Unrecognized climate state update in %; no changes applied.',routine.proname;end if;
    definition:=replace(definition,anchor,anchor||'s:=public._eclipse_state(s,zones);side:=s->side_key;other_side:=s->other_key;');
   end if;
   -- Return transformed wolves to their original identity in the Submundo.
   definition:=replace(definition,$old$jsonb_build_array(unit->>'cardId')$old$,$new$jsonb_build_array(coalesce(unit->>'eclipseOriginalCardId',unit->>'cardId'))$new$);
   if position('random()<0.5' in definition)=0 then raise exception 'Unrecognized Eclipse draw in %; no changes applied.',routine.proname;end if;
   if position('/* Eclipse now affects unit power on both sides. */' in definition)=0 then raise exception 'Unrecognized legacy Eclipse penalty in %; no changes applied.',routine.proname;end if;
  end if;
  if definition<>original then execute definition;end if;
 end loop;
end; $migration$;

revoke all on function public._eclipse_is_vampire(text) from public,anon,authenticated;
revoke all on function public._eclipse_power(jsonb,jsonb,integer,text) from public,anon,authenticated;
revoke all on function public._eclipse_side(jsonb,jsonb) from public,anon,authenticated;
revoke all on function public._eclipse_state(jsonb,jsonb) from public,anon,authenticated;
commit;
