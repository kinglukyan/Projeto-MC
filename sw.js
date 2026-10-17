-- Apply after 202610170006_location_cards.sql.
-- Equipment target selection is validated by the server in 1v1 and 2v2.
begin;
alter table public.card_lore drop constraint if exists card_lore_card_id_check;
alter table public.card_lore add constraint card_lore_card_id_check check(card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','yggdrasil','alto-egito','baixo-egito','bifrost','esparta','labirinto-dedalos','nilfheim','asgard','egito','olho-que-tudo-ve','raio-de-zeus','excalibur','lukyan','lobo-omega','anubis','odin','lukyan-rei-de-todos','minotauro','apolo','ra','ragnar','afrodite','aquiles','seth','osiris','thor','artemis','sobek','ares','beowulf','heimdall','dionisio','butter','hefesto','hercules','hermes','horus','lobo-beta','isis','mulher','homem'));
insert into public.card_lore(card_id,card_name,ability_title,ability_text,art_url,faction,power,badge_key) values
('mjolnir','Mjölnir','Equipar','Somente Thor pode equipar. Concede +4 de poder.','assets/equipment/mjolnir.png','Nórdicos',0,'norse'),
('olho-que-tudo-ve','Olho que Tudo Vê','Equipar','Somente Hórus, Rá e Osíris podem equipar. Concede +4 de poder.','assets/equipment/olho-que-tudo-ve.png','Egípcios',0,'egypt'),
('raio-de-zeus','Raio de Zeus','Equipar','Somente Zeus pode equipar. Concede +4 de poder.','assets/equipment/raio-de-zeus.png','Grécia',0,'greece'),
('runas-nordicas','Runa Uruz','Equipar','Um personagem nórdico à sua escolha recebe +2 de poder.','assets/equipment/runas-nordicas.png','Nórdicos',0,'norse'),
('excalibur','Excalibur','Equipar','Somente Rei Arthur e Lukyan base podem equipar. Rei Arthur recebe +4 de poder. Lukyan base se transforma em Lukyan — Rei de Todos, uma carta especial que não entra no baralho nem na mão.','assets/equipment/excalibur.png','Universal',0,'celtic'),
('lukyan','Lukyan — Rei da Festa','Rei da Festa','Ao entrar numa fileira com outros personagens, ganha +3 pontos de poder.','assets/cards-20261017/lukyan.png','Alyns',3,'alyans'),
('lukyan-rei-de-todos','Lukyan — Rei de Todos','Rei de Todos','Agora com Excalibur, Lukyan tem seu poder dobrado por todos seus aliados em campo. Só aparece pela transformação de Lukyan com Excalibur; não pode entrar no baralho ou na mão.','assets/cards-20261017/lukyan-rei-de-todos.png','Alyns',6,'alyans')
on conflict(card_id) do update set card_name=excluded.card_name,ability_title=excluded.ability_title,ability_text=excluded.ability_text,art_url=excluded.art_url,faction=excluded.faction,power=excluded.power,badge_key=excluded.badge_key,updated_at=now();

create or replace function public._is_equipment_card(p_card_id text)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(p_card_id in ('mjolnir','olho-que-tudo-ve','raio-de-zeus','runas-nordicas','excalibur'),false);
$$;
create or replace function public._equipment_can_target(p_equipment text,p_unit text)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(case p_equipment
 when 'mjolnir' then p_unit='thor'
 when 'olho-que-tudo-ve' then p_unit in ('horus','ra','osiris')
 when 'raio-de-zeus' then p_unit='zeus'
 when 'runas-nordicas' then public._terrain_card_meta(p_unit)->>'faction'='Nórdicos'
 when 'excalibur' then p_unit in ('rei-arthur','lukyan')
 else false end,false);
$$;
create or replace function public._equip_field(p_side jsonb,p_card_id text,p_target integer default null)
returns jsonb language plpgsql set search_path='' immutable as $$
declare field_array jsonb:=coalesce(p_side->'field','[]'::jsonb); chosen integer:=p_target;
 unit jsonb; updated_unit jsonb;
begin
 if not public._is_equipment_card(p_card_id) then raise exception 'Equipamento inválido.';end if;
 if chosen is null then
  select ordinality::integer-1 into chosen from jsonb_array_elements(field_array) with ordinality u(value,ordinality)
  where public._equipment_can_target(p_card_id,u.value->>'cardId') order by ordinality limit 1;
 end if;
 if chosen is null or chosen<0 or chosen>=jsonb_array_length(field_array) then raise exception 'Escolha um aliado compatível em campo.';end if;
 unit:=field_array->chosen;
 if not public._equipment_can_target(p_card_id,unit->>'cardId') then raise exception 'Este personagem não pode usar esse equipamento.';end if;
 updated_unit:=jsonb_set(unit,'{equipment}',coalesce(unit->'equipment','[]'::jsonb)||jsonb_build_array(p_card_id),true);
 if p_card_id='excalibur' and unit->>'cardId'='lukyan' then
  updated_unit:=jsonb_set(updated_unit,'{sourceCardId}','"lukyan"'::jsonb,true);
  updated_unit:=jsonb_set(updated_unit,'{cardId}','"lukyan-rei-de-todos"'::jsonb,true);
 else
  updated_unit:=jsonb_set(updated_unit,'{bonus}',to_jsonb(coalesce((unit->>'bonus')::integer,0)+case when p_card_id='runas-nordicas' then 2 else 4 end),true);
 end if;
 return jsonb_set(field_array,array[chosen::text],updated_unit,false);
end;
$$;

-- Special forms revert to their base card whenever a field card leaves play.
-- Restrict normalization to hand/deck/underworld pools, preserving transformed fields.
create or replace function public._normalize_special_pools(p_value jsonb)
returns jsonb language plpgsql set search_path='' immutable as $$
declare result jsonb; item record;
begin
 if jsonb_typeof(p_value)='object' then
  result:='{}'::jsonb;
  for item in select key,value from jsonb_each(p_value) loop
   if item.key in ('hand','deck','underworld') and jsonb_typeof(item.value)='array' then
    result:=result||jsonb_build_object(item.key,coalesce((select jsonb_agg(case when a.value='"lukyan-rei-de-todos"'::jsonb then '"lukyan"'::jsonb else a.value end order by ordinality) from jsonb_array_elements(item.value) with ordinality a(value,ordinality)),'[]'::jsonb));
   else result:=result||jsonb_build_object(item.key,public._normalize_special_pools(item.value));end if;
  end loop;
  return result;
 elsif jsonb_typeof(p_value)='array' then
  return coalesce((select jsonb_agg(public._normalize_special_pools(a.value) order by ordinality) from jsonb_array_elements(p_value) with ordinality a(value,ordinality)),'[]'::jsonb);
 end if;
 return p_value;
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
 return greatest(0,total);
end;
$$;



do $migration$
declare routine record; definition text; original text; field_name text; unit_bonus text;
begin
 for routine in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.prokind='f' and p.proname in ('_new_online_game_state','_new_online_duo_state','submit_game_action','_submit_game_action_1v1','submit_duo_game_action') loop
  definition:=pg_get_functiondef(routine.oid);original:=definition;
  definition:=regexp_replace(definition,$pattern$key[[:space:]]+not[[:space:]]+in[[:space:]]*[(][^)]*'campo-troia'[^)]*[)]$pattern$,$replace$key not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','yggdrasil','alto-egito','baixo-egito','bifrost','esparta','labirinto-dedalos','nilfheim','asgard','egito','olho-que-tudo-ve','raio-de-zeus','excalibur','lukyan')$replace$,'g');
  definition:=regexp_replace(definition,$pattern$card_id[[:space:]]+not[[:space:]]+in[[:space:]]*[(][^)]*'campo-troia'[^)]*[)]$pattern$,$replace$card_id not in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','yggdrasil','alto-egito','baixo-egito','bifrost','esparta','labirinto-dedalos','nilfheim','asgard','egito','olho-que-tudo-ve','raio-de-zeus','excalibur','lukyan')$replace$,'g');
  if routine.proname in ('submit_game_action','_submit_game_action_1v1','submit_duo_game_action') and position('card_id not in' in definition)>0 then
   field_name:=case when routine.proname='submit_duo_game_action' then 'field_arr' else 'field_array' end;
   if position('public._equip_field(side,card_id' in definition)=0 then
    definition:=regexp_replace(definition,$pattern$elsif card_id='mjolnir' then.*?elsif card_id='runas-nordicas' then[^;]*;$pattern$,
     'elsif public._is_equipment_card(card_id) then '||field_name||':=public._equip_field(side,card_id,(p_action->>''target_index'')::integer);side:=jsonb_set(side,''{field}'','||field_name||',true);','g');
   end if;
   -- Add only Lukyan base to the existing unit dispatch; the special form is never playable from hand.
   definition:=regexp_replace(definition,$pattern$if card_id in[[:space:]]*[(][^)]*'soldado-esparta'[^)]*[)] then$pattern$,
    $replace$if card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','medusa','poseidon','zeus','hades','lukyan') then$replace$,'g');
   if position('/* lukyan_entry */' in definition)=0 then
    unit_bonus:='case when card_id=''lukyan'' and exists(select 1 from jsonb_array_elements('||field_name||') a(value) where coalesce((a.value->>''lane'')::integer,0)=lane) then 3 else 0 end /* lukyan_entry */';
    definition:=replace(definition,'''bonus'',0,','''bonus'','||unit_bonus||',');
   end if;
   if position('public._normalize_special_pools(s)' in definition)=0 then
    definition:=replace(definition,'set state=s,','set state=public._normalize_special_pools(s),');
   end if;
   if position('public._equip_field(side,card_id' in definition)=0 then raise exception 'Unrecognized equipment branch in %; no changes applied.',routine.proname;end if;
   if position('/* lukyan_entry */' in definition)=0 then raise exception 'Unrecognized Lukyan entry in %; no changes applied.',routine.proname;end if;
   if position('public._normalize_special_pools(s)' in definition)=0 then raise exception 'Unrecognized state persistence in %; no changes applied.',routine.proname;end if;
  end if;
  if definition<>original then execute definition;end if;
 end loop;
end; $migration$;
revoke all on function public._is_equipment_card(text) from public,anon,authenticated;
revoke all on function public._equipment_can_target(text,text) from public,anon,authenticated;
revoke all on function public._equip_field(jsonb,text,integer) from public,anon,authenticated;
revoke all on function public._normalize_special_pools(jsonb) from public,anon,authenticated;
commit;
