-- Apply after 202610170005_terrain_cards.sql. Local bonuses affect both sides.
begin;
alter table public.card_lore drop constraint if exists card_lore_card_id_check;
alter table public.card_lore add constraint card_lore_card_id_check check(card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','yggdrasil','alto-egito','baixo-egito','bifrost','esparta','labirinto-dedalos','nilfheim','asgard','egito','lobo-omega','lukyan','anubis','odin','lukyan-rei-de-todos','minotauro','apolo','ra','ragnar','afrodite','aquiles','seth','osiris','thor','artemis','sobek','ares','beowulf','heimdall','dionisio','butter','hefesto','hercules','hermes','horus','lobo-beta','isis','mulher','homem'));
insert into public.card_lore(card_id,card_name,ability_title,ability_text,art_url,faction,power,badge_key) values
('asgard','Asgard','Bônus de Local','Enquanto este Local estiver ativo, todos os nórdicos recebem +2 de poder, nos dois lados do campo.','assets/locations/asgard.png','Nórdicos',0,'norse'),
('egito','Egito','Bônus de Local','Enquanto este Local estiver ativo, todos os egípcios recebem +2 de poder, nos dois lados do campo.','assets/locations/egito.png','Egípcios',0,'egypt'),
('grecia','Grécia','Bônus de Local','Enquanto este Local estiver ativo, todos os gregos recebem +2 de poder, nos dois lados do campo.','assets/locations/grecia.png','Grécia',0,'greece')
on conflict(card_id) do update set card_name=excluded.card_name,ability_title=excluded.ability_title,ability_text=excluded.ability_text,art_url=excluded.art_url,faction=excluded.faction,power=excluded.power,badge_key=excluded.badge_key,updated_at=now();
create or replace function public._is_location_card(p_card_id text)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(p_card_id in ('asgard','egito','grecia'),false);
$$;
create or replace function public._location_bonus(p_location text,p_card_id text)
returns integer language sql immutable set search_path='' as $$
 select case when public._terrain_card_meta(p_card_id)->>'faction'=case p_location when 'asgard' then 'Nórdicos' when 'egito' then 'Egípcios' when 'grecia' then 'Grécia' end then 2 else 0 end;
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
 return greatest(0,total);
end;
$$;


do $migration$
declare routine record; definition text; original text;
begin
 for routine in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.prokind='f' and p.proname in ('_new_online_game_state','_new_online_duo_state','submit_game_action','_submit_game_action_1v1','submit_duo_game_action')
 loop
  definition:=pg_get_functiondef(routine.oid);original:=definition;
  definition:=regexp_replace(definition,E'key\\s+not\\s+in\\s*\\([^)]*''campo-troia''[^)]*\\)',$replace$key not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','yggdrasil','alto-egito','baixo-egito','bifrost','esparta','labirinto-dedalos','nilfheim','asgard','egito')$replace$,'g');
  definition:=regexp_replace(definition,E'\\mcard_id\\s+not\\s+in\\s*\\([^)]*''campo-troia''[^)]*\\)',$replace$card_id not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','yggdrasil','alto-egito','baixo-egito','bifrost','esparta','labirinto-dedalos','nilfheim','asgard','egito')$replace$,'g');
  if routine.proname in ('submit_game_action','_submit_game_action_1v1','submit_duo_game_action') then
   definition:=replace(definition,'card_id=''grecia'' then','public._is_location_card(card_id) then');
   definition:=replace(definition,'card_id=''grecia'' or public._is_terrain_card(card_id)','public._is_location_card(card_id) or public._is_terrain_card(card_id)');
   definition:=replace(definition,$old$'"grecia"'::jsonb$old$,'to_jsonb(card_id)');
   if position('card_id not in' in definition)>0 and position('public._is_location_card(card_id)' in definition)=0 then raise exception 'Unrecognized Local action branch in %; no changes applied.',routine.proname;end if;
  end if;
  if definition<>original then execute definition;end if;
 end loop;
end; $migration$;
revoke all on function public._is_location_card(text) from public,anon,authenticated;
revoke all on function public._location_bonus(text,text) from public,anon,authenticated;
commit;
