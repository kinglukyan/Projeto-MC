-- Terrain effects supplied by the user. Apply after 202610170004.
-- Changes the shared terrain slot in Guardian, 1v1 and 2v2.
-- No preview character is unlocked by this migration.
begin;

alter table public.card_lore drop constraint if exists card_lore_card_id_check;
alter table public.card_lore add constraint card_lore_card_id_check check (card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','yggdrasil','alto-egito','baixo-egito','bifrost','esparta','labirinto-dedalos','nilfheim','lobo-omega','lukyan','anubis','odin','lukyan-rei-de-todos','minotauro','apolo','ra','ragnar','afrodite','aquiles','seth','osiris','thor','artemis','sobek','ares','beowulf','heimdall','dionisio','butter','hefesto','hercules','hermes','horus','lobo-beta','isis','mulher','homem'));

insert into public.card_lore(card_id,card_name,ability_title,ability_text,art_url,faction,power,badge_key) values
('yggdrasil','Yggdrasil','Bônus de Terreno','Fortalece Odin em +2 de poder.','assets/terrains/yggdrasil.png','Nórdicos',0,'norse'),
('alto-egito','Alto Egito','Bônus de Terreno','Fortalece todos os egípcios em +2 de poder.','assets/terrains/alto-egito.jpg','Egípcios',0,'egypt'),
('baixo-egito','Baixo Egito','Bônus de Terreno','Fortalece todos os egípcios em +2 de poder.','assets/terrains/baixo-egito.png','Egípcios',0,'egypt'),
('bifrost','Bifrost','Bônus de Terreno','Fortalece todos os nórdicos, exceto Loki, em +2 de poder.','assets/terrains/bifrost.png','Nórdicos',0,'norse'),
('esparta','Esparta','Bônus de Terreno','Fortalece os espartanos em +2 de poder e Ares em +3 de poder.','assets/terrains/esparta.png','Grécia',0,'greece'),
('labirinto-dedalos','Labirinto de Dédalos','Bônus de Terreno','Fortalece o Minotauro e os monstros gregos em +2 de poder.','assets/terrains/labirinto-dedalos.png','Grécia',0,'greece'),
('campo-troia','Troia','Bônus de Terreno','Fortalece Aquiles, Athena e Ares em +3 de poder.','assets/terrains/campo-troia.png','Grécia',0,'greece'),
('nilfheim','Nilfheim','Bônus de Terreno','Fortalece Loki e os gigantes de gelo em +2 de poder.','assets/terrains/nilfheim.png','Nórdicos',0,'norse')
on conflict(card_id) do update set card_name=excluded.card_name,ability_title=excluded.ability_title,ability_text=excluded.ability_text,art_url=excluded.art_url,faction=excluded.faction,power=excluded.power,badge_key=excluded.badge_key,updated_at=now();

create or replace function public._is_terrain_card(p_card_id text)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(p_card_id in ('yggdrasil','alto-egito','baixo-egito','bifrost','esparta','labirinto-dedalos','campo-troia','nilfheim'),false);
$$;

-- Canonical metadata is generated from the same JSON as terrain-cards.js.
-- Reserved target IDs for Loki, Leônidas and frost giants do not create playable cards.
create or replace function public._terrain_card_meta(p_card_id text)
returns jsonb language sql immutable set search_path='' as $$
 select coalesce($metadata${"soldado-esparta":{"name":"Soldado de Esparta","power":3,"faction":"Grécia","tags":["espartano"]},"athena":{"name":"Athena","power":4,"faction":"Grécia","tags":[]},"lobo-alfa":{"name":"Lobisomem Alfa","power":4,"faction":"Monstros","tags":["monstro"]},"guardiao-nordico":{"name":"Guardião Nórdico","power":2,"faction":"Nórdicos","tags":[]},"mjolnir":{"name":"Mjölnir","power":0,"faction":"Nórdicos","tags":[]},"runas-nordicas":{"name":"Runas Nórdicas","power":0,"faction":"Nórdicos","tags":[]},"grecia":{"name":"Grécia","power":0,"faction":"Grécia","tags":[]},"eclipse":{"name":"Eclipse","power":0,"faction":"Universal","tags":[]},"campo-troia":{"name":"Troia","power":0,"faction":"Grécia","tags":[]},"medusa":{"name":"Medusa","power":4,"faction":"Grécia","tags":["monstro"]},"poseidon":{"name":"Poseidon","power":7,"faction":"Grécia","tags":[]},"zeus":{"name":"Zeus","power":8,"faction":"Grécia","tags":[]},"hades":{"name":"Hades","power":7,"faction":"Grécia","tags":[]},"lobo-omega":{"name":"Lobisomem Omega","power":1,"faction":"Monstros","tags":["monstro"]},"lukyan":{"name":"Lukyan — Rei da Festa","power":3,"faction":"Alyns","tags":[]},"anubis":{"name":"Anúbis","power":5,"faction":"Egípcios","tags":[]},"odin":{"name":"Odin","power":8,"faction":"Nórdicos","tags":[]},"lukyan-rei-de-todos":{"name":"Lukyan — Rei de Todos","power":6,"faction":"Alyns","tags":[]},"minotauro":{"name":"Minotauro","power":3,"faction":"Grécia","tags":["monstro"]},"apolo":{"name":"Apolo","power":6,"faction":"Grécia","tags":[]},"ra":{"name":"Rá","power":8,"faction":"Egípcios","tags":[]},"ragnar":{"name":"Ragnar","power":3,"faction":"Nórdicos","tags":[]},"afrodite":{"name":"Afrodite","power":5,"faction":"Grécia","tags":[]},"aquiles":{"name":"Aquiles","power":3,"faction":"Grécia","tags":[]},"seth":{"name":"Seth","power":4,"faction":"Egípcios","tags":[]},"osiris":{"name":"Osíris","power":6,"faction":"Egípcios","tags":[]},"thor":{"name":"Thor","power":6,"faction":"Nórdicos","tags":[]},"artemis":{"name":"Ártemis","power":5,"faction":"Grécia","tags":[]},"sobek":{"name":"Sobek","power":2,"faction":"Egípcios","tags":[]},"ares":{"name":"Ares","power":5,"faction":"Grécia","tags":[]},"beowulf":{"name":"Beowulf","power":3,"faction":"Nórdicos","tags":[]},"heimdall":{"name":"Heimdall","power":3,"faction":"Nórdicos","tags":[]},"dionisio":{"name":"Dionísio","power":4,"faction":"Grécia","tags":[]},"butter":{"name":"Butter","power":4,"faction":"Alyns","tags":[]},"hefesto":{"name":"Hefestos","power":4,"faction":"Grécia","tags":[]},"hercules":{"name":"Hércules","power":4,"faction":"Grécia","tags":[]},"hermes":{"name":"Hermes","power":3,"faction":"Grécia","tags":[]},"horus":{"name":"Hórus","power":4,"faction":"Egípcios","tags":[]},"lobo-beta":{"name":"Lobisomem Beta","power":2,"faction":"Monstros","tags":["monstro"]},"isis":{"name":"Ísis","power":4,"faction":"Egípcios","tags":[]},"mulher":{"name":"Mulher","power":2,"faction":"Monstros","tags":["monstro"]},"homem":{"name":"Homem","power":1,"faction":"Monstros","tags":["monstro"]},"yggdrasil":{"name":"Yggdrasil","power":0,"faction":"Nórdicos","tags":[]},"alto-egito":{"name":"Alto Egito","power":0,"faction":"Egípcios","tags":[]},"baixo-egito":{"name":"Baixo Egito","power":0,"faction":"Egípcios","tags":[]},"bifrost":{"name":"Bifrost","power":0,"faction":"Nórdicos","tags":[]},"esparta":{"name":"Esparta","power":0,"faction":"Grécia","tags":[]},"labirinto-dedalos":{"name":"Labirinto de Dédalos","power":0,"faction":"Grécia","tags":[]},"nilfheim":{"name":"Nilfheim","power":0,"faction":"Nórdicos","tags":[]},"leonidas":{"name":"Leônidas","faction":"Grécia","tags":["espartano"]},"loki":{"name":"Loki","faction":"Nórdicos","tags":[]},"gigante-de-gelo":{"name":"Gigante de Gelo","faction":"Nórdicos","tags":["gigante-de-gelo"]},"gigantes-de-gelo":{"name":"Gigantes de Gelo","faction":"Nórdicos","tags":["gigante-de-gelo"]}}$metadata$::jsonb->p_card_id,'{}'::jsonb);
$$;

create or replace function public._terrain_bonus(p_terrain text,p_card_id text)
returns integer language plpgsql immutable set search_path='' as $$
declare rules jsonb:=$rules${"yggdrasil":[{"ids":["odin"],"bonus":2}],"alto-egito":[{"faction":"Egípcios","bonus":2}],"baixo-egito":[{"faction":"Egípcios","bonus":2}],"bifrost":[{"faction":"Nórdicos","excludeIds":["loki"],"bonus":2}],"esparta":[{"ids":["ares"],"bonus":3},{"tagsAny":["espartano"],"bonus":2}],"labirinto-dedalos":[{"ids":["minotauro"],"bonus":2},{"faction":"Grécia","tagsAny":["monstro"],"bonus":2}],"campo-troia":[{"ids":["aquiles","athena","ares"],"bonus":3}],"nilfheim":[{"ids":["loki"],"bonus":2},{"tagsAny":["gigante-de-gelo"],"bonus":2}]}$rules$::jsonb;
 rule jsonb; meta jsonb:=public._terrain_card_meta(p_card_id);
begin
 for rule in select value from jsonb_array_elements(coalesce(rules->p_terrain,'[]'::jsonb)) r(value)
 loop
  if rule ? 'ids' and not ((rule->'ids') ? p_card_id) then continue; end if;
  if rule ? 'faction' and coalesce(meta->>'faction','')<>rule->>'faction' then continue; end if;
  if rule ? 'excludeIds' and ((rule->'excludeIds') ? p_card_id) then continue; end if;
  if rule ? 'tagsAny' and not exists(select 1 from jsonb_array_elements_text(rule->'tagsAny') t(tag) where coalesce(meta->'tags','[]'::jsonb) ? t.tag) then continue; end if;
  return (rule->>'bonus')::integer;
 end loop;
 return 0;
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
 if meta->>'faction'='Grécia' then total:=total+coalesce((p_side->>'greekAura')::integer,0)+case when p_zones->>'local'='grecia' then 1 else 0 end; end if;
 if meta->>'faction'='Nórdicos' then total:=total+coalesce((p_side->>'norseAura')::integer,0); end if;
 total:=total+public._terrain_bonus(p_zones->>'terrain',cid);
 return greatest(0,total);
end;
$$;

-- Target only deck construction and action routines, including the 1v1 routine
-- renamed by the duo migration. Preserve their auth checks, locks and turn rules.
do $migration$
declare routine record; definition text; original text;
begin
 for routine in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prokind='f' and p.proname in
   ('_new_online_game_state','_new_online_duo_state','submit_game_action','_submit_game_action_1v1','submit_duo_game_action')
 loop
  definition:=pg_get_functiondef(routine.oid);original:=definition;
  -- Existing deck serializers include catalog cards with a zero quantity.
  -- Accept zero placeholders but continue rejecting every unsupported positive card.
  if position('''yggdrasil''' in definition)=0 then
  definition:=regexp_replace(definition,
   E'key\s+not\s+in\s*\([^)]*''campo-troia''[^)]*\)',
   $replace$(key not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','yggdrasil','alto-egito','baixo-egito','bifrost','esparta','labirinto-dedalos','nilfheim') and value <> '0')$replace$,'g');
  definition:=regexp_replace(definition,
   E'\mcard_id\s+not\s+in\s*\([^)]*''campo-troia''[^)]*\)',
   $replace$card_id not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','yggdrasil','alto-egito','baixo-egito','bifrost','esparta','labirinto-dedalos','nilfheim')$replace$,'g');
  end if;
  if routine.proname in ('submit_game_action','_submit_game_action_1v1','submit_duo_game_action') then
   definition:=replace(definition,'elsif card_id=''campo-troia'' then','elsif public._is_terrain_card(card_id) then');
   definition:=replace(definition,'elsif card_id=''grecia'' or card_id=''campo-troia'' or card_id=''eclipse'' then','elsif card_id=''grecia'' or public._is_terrain_card(card_id) or card_id=''eclipse'' then');
   definition:=replace(definition,$old$'"campo-troia"'::jsonb$old$,'to_jsonb(card_id)');
   -- Match the already-corrected Athena/Alpha rules in both server action engines.
   definition:=replace(definition,'case when card_id=''lobo-alfa'' then 1 else 0 end','0');
   definition:=regexp_replace(definition,
    $pattern$if\s+card_id\s*=\s*'athena'\s+and\s+jsonb_array_length\((deck_array|deck_arr)\)\s*>\s*0\s+then[^;]*;\s*select[^;]*;\s*end\s+if;$pattern$,
    '/* Athena grants its lane aura in _online_unit_power. */','g');
   if position('if card_id=''athena'' and jsonb_array_length' in definition)>0 then raise exception 'Unrecognized Athena entry rule in %; no changes applied.',routine.proname;end if;
   if position('card_id not in' in definition)>0 and position('public._is_terrain_card(card_id)' in definition)=0 then raise exception 'Unrecognized terrain action branch in %; no changes applied.',routine.proname;end if;
  end if;
  if definition<>original then execute definition; end if;
 end loop;
end; $migration$;

revoke all on function public._is_terrain_card(text) from public,anon,authenticated;
revoke all on function public._terrain_card_meta(text) from public,anon,authenticated;
revoke all on function public._terrain_bonus(text,text) from public,anon,authenticated;
commit;
