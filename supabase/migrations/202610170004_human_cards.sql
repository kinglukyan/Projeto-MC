-- Human character cards supplied by the user. Apply after 202610170003.
begin;
alter table public.card_lore drop constraint if exists card_lore_card_id_check;
alter table public.card_lore add constraint card_lore_card_id_check check (card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','lobo-omega','lukyan','anubis','odin','lukyan-rei-de-todos','minotauro','apolo','ra','ragnar','afrodite','aquiles','seth','osiris','thor','artemis','sobek','ares','beowulf','heimdall','dionisio','butter','hefesto','hercules','hermes','horus','lobo-beta','isis','mulher','homem'));
insert into public.card_lore(card_id,card_name,ability_title,ability_text,art_url,faction,power,badge_key) values
('mulher','Mulher','Ainda Sou Alfa','Alfa sem poderes, usa sua labia para ganhar poder liderando homens humanos, cada homem dobra sua força.','assets/cards-20261017/mulher.png','Monstros',2,'monster'),
('homem','Homem','Juntos Somos Fortes','Ao perder os poderes, humanos se unem para duplicar suas forças.','assets/cards-20261017/homem.png','Monstros',1,'monster')
on conflict(card_id) do update set card_name=excluded.card_name,ability_title=excluded.ability_title,ability_text=excluded.ability_text,art_url=excluded.art_url,faction=excluded.faction,power=excluded.power,badge_key=excluded.badge_key,updated_at=now();
commit;
