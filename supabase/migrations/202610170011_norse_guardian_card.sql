-- Apply after 202610170010_all_character_abilities.sql.
begin;
insert into public.card_lore(card_id,card_name,ability_title,ability_text,art_url,faction,power,badge_key) values ('guardiao-nordico','Guardião Nórdico','Vontade do Norte','As Runas Nórdicas aumentam seu poder enquanto estiver em campo.','assets/cards-20261017/guardiao-nordico.png','Nórdicos',2,'norse')
on conflict(card_id) do update set card_name=excluded.card_name,ability_title=excluded.ability_title,ability_text=excluded.ability_text,art_url=excluded.art_url,faction=excluded.faction,power=excluded.power,badge_key=excluded.badge_key,updated_at=now();
commit;
