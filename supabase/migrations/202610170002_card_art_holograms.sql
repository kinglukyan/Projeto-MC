-- Apply after the earlier Mythic Clash migrations, before publishing this edition.
-- Adds visual catalog entries. The 27 preview cards stay unavailable in matches.
-- Athena and the Alpha retain their existing IDs, copies and saved deck positions.
begin;

alter table public.card_lore drop constraint if exists card_lore_card_id_check;
alter table public.card_lore add constraint card_lore_card_id_check check (card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades','lobo-omega','lukyan','anubis','odin','lukyan-rei-de-todos','minotauro','apolo','ra','ragnar','afrodite','aquiles','seth','osiris','thor','artemis','sobek','ares','beowulf','heimdall','dionisio','butter','hefesto','hercules','hermes','horus','lobo-beta','isis'));

insert into public.card_lore(card_id,card_name,ability_title,ability_text,art_url,faction,power,badge_key)
values
('lobo-omega','Lobisomem Omega','Encurralado','Se o Lobisomem Omega for o único na sua fileira de batalha e o inimigo tiver mais poder que o Omega, seu poder aumenta em 8.','assets/cards-20261017/lobo-omega.png','Monstros',1,'monster'),
('lukyan','Lukyan — Rei da Festa','Rei da Festa','Ao entrar numa fileira com outros personagens, ganha +3 pontos de poder.','assets/cards-20261017/lukyan.png','Alyns',3,'alyans'),
('anubis','Anúbis','Troca Veloz','Ao entrar em campo, escolhe uma carta inimiga com 3 ou menos pontos de poder e a envia para o Submundo. Recupera uma carta de mesmo poder do Submundo do invocador.','assets/cards-20261017/anubis.png','Egípcios',5,'egypt'),
('odin','Odin','Sabedoria de Yggdrasil','No início da rodada, olha a carta do topo do seu deck e pode descartá-la para ganhar +2 pontos de poder na soma final.','assets/cards-20261017/odin.png','Nórdicos',8,'norse'),
('lukyan-rei-de-todos','Lukyan — Rei de Todos','Rei de Todos','Agora com Excalibur, Lukyan tem seu poder dobrado por todos seus aliados em campo.','assets/cards-20261017/lukyan-rei-de-todos.png','Alyns',6,'alyans'),
('minotauro','Minotauro','Fúria do Labirinto','Ao entrar em campo, se estiver sozinho em sua fileira de batalha, ganha +3 pontos de poder.','assets/cards-20261017/minotauro.png','Grécia',3,'greece'),
('apolo','Apolo','Benção do Sol','Ao ser colocado numa fileira, todos os personagens dessa fileira têm seu poder dobrado.','assets/cards-20261017/apolo.png','Grécia',6,'greece'),
('ra','Rá','Luz da Criação','No final de cada rodada, adiciona +1 de poder a todas as cartas da sua facção Egito em campo.','assets/cards-20261017/ra.png','Egípcios',8,'egypt'),
('ragnar','Ragnar','Invasores de Katgat','Ao entrar em campo, move uma carta aliada de baixo poder de outra fileira para a mesma fileira de Ragnar, unindo as forças.','assets/cards-20261017/ragnar.png','Nórdicos',3,'norse'),
('afrodite','Afrodite','Meu Amado Traidor','Ao entrar em campo, o invocador pode escolher uma carta inimiga em campo para roubar, desde que ela tenha menos de 5 de poder.','assets/cards-20261017/afrodite.png','Grécia',5,'greece'),
('aquiles','Aquiles','A Fúria de Mirmidão','Ao entrar em campo, ganha +1 de poder para cada soldado grego ou herói aliado em sua fileira.','assets/cards-20261017/aquiles.png','Grécia',3,'greece'),
('seth','Seth','Trovoada do Caos','Ao entrar em campo, escolhe uma fileira e troca os valores de poder de todas as cartas nela, aliadas e inimigas, de forma aleatória entre elas.','assets/cards-20261017/seth.png','Egípcios',4,'egypt'),
('osiris','Osíris','Justiça Cíclica','Ao ser destruído e enviado para o cemitério, dobra o poder de outra carta aliada aleatória em campo.','assets/cards-20261017/osiris.png','Egípcios',6,'egypt'),
('thor','Thor','Martelada de Mjölnir','Ao entrar em campo, escolhe a carta inimiga de maior poder e a envia para o Submundo.','assets/cards-20261017/thor.png','Nórdicos',6,'norse'),
('artemis','Ártemis','Tiro Preciso','Ao entrar em campo, elimina duas cartas Monstros de cada lado.','assets/cards-20261017/artemis.png','Grécia',5,'greece'),
('sobek','Sobek','Inundação Fertilizante','Ao entrar em campo, se houver outra carta aliada na mesma fileira, ganha +2 de poder adicional.','assets/cards-20261017/sobek.png','Egípcios',2,'egypt'),
('ares','Ares','Deus da Guerra','Ao entrar na Guerra, todos os Soldados de Esparta e Leônidas ganham 2 pontos de poder e todos os gregos ganham 1.','assets/cards-20261017/ares.png','Grécia',5,'greece'),
('beowulf','Beowulf','Coragem de Geat','Ao entrar em campo, se houver alguma carta da facção Monstros na mesa, ganha +3 pontos de poder adicional.','assets/cards-20261017/beowulf.png','Nórdicos',3,'norse'),
('heimdall','Heimdall','Vigília de Bifröst','Enquanto estiver em campo, nenhuma carta inimiga pode alterar o valor de poder das suas cartas nesta fileira.','assets/cards-20261017/heimdall.png','Nórdicos',3,'norse'),
('dionisio','Dionísio','Festival do Vinho','Todos os efeitos de cartas de ambos os lados ficam desativados por 3 rodadas.','assets/cards-20261017/dionisio.png','Grécia',4,'greece'),
('athena','Athena','Formação Falange','Todas as outras cartas na mesma fileira de Athena ganham +2 pontos de poder cada.','assets/cards-20261017/athena.png','Grécia',4,'greece'),
('butter','Butter','Cleptomaníaco','Ao entrar em campo, rouba uma carta aleatória da mão do oponente.','assets/cards-20261017/butter.png','Alyns',4,'alyans'),
('hefesto','Hefestos','Melhoria Artefatual','Ao entrar em campo, aumenta em +3 os pontos de poder de um personagem com carta de equipamento.','assets/cards-20261017/hefesto.png','Grécia',4,'greece'),
('hercules','Hércules','Os Doze Trabalhos','A cada rodada ganha 1 de poder, podendo chegar a 16 pontos após 12 rodadas, concluindo seus doze trabalhos.','assets/cards-20261017/hercules.png','Grécia',4,'greece'),
('hermes','Hermes','Troca Veloz','Ao entrar em campo, você pode mover outra carta sua de uma fileira para outra, reorganizando sua pontuação.','assets/cards-20261017/hermes.png','Grécia',3,'greece'),
('horus','Hórus','Olho de Hórus','Ao entrar em campo, pode ver duas cartas do adversário.','assets/cards-20261017/horus.png','Egípcios',4,'egypt'),
('lobo-beta','Lobisomem Beta','Uivo do Betinha','Ao entrar em campo, chama os outros Betas que estiverem na mão do invocador para o campo.','assets/cards-20261017/lobo-beta.png','Monstros',2,'monster'),
('isis','Ísis','Ressurreição de Osíris','Ao entrar em campo, retorna uma carta de custo 2 ou menos do seu cemitério para o campo, na fileira de Ísis.','assets/cards-20261017/isis.png','Egípcios',4,'egypt'),
('lobo-alfa','Lobisomem Alfa','Uivo de Alfa','A cada Lobisomem Beta em campo, ganha 2 pontos de poder.','assets/cards-20261017/lobo-alfa.png','Monstros',4,'monster')
on conflict(card_id) do update set
 card_name=excluded.card_name,ability_title=excluded.ability_title,ability_text=excluded.ability_text,
 art_url=excluded.art_url,faction=excluded.faction,power=excluded.power,badge_key=excluded.badge_key,updated_at=now();

-- Synchronize the two existing cards with the newly supplied printed rules.
-- Operate on these named routines only; never replace unrelated function bodies.
do $migration$
declare routine record; definition text; original text;
begin
 for routine in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.prokind='f' and p.proname in ('_online_unit_power','submit_game_action','get_tiebreak_state','submit_tiebreak_card')
 loop
  definition:=pg_get_functiondef(routine.oid);original:=definition;
  definition:=replace(definition,'''athena'' then 5','''athena'' then 4');
  if routine.proname='_online_unit_power' and position('edition_20261017' in definition)=0 then
   if position('total:=base_power+bonus;' in definition)=0 then raise exception 'Unexpected _online_unit_power definition. No changes applied.'; end if;
   definition:=replace(definition,'total:=base_power+bonus;',
    E'total:=base_power+bonus;
  -- edition_20261017: allied lane aura, excluding this Athena instance.
  total:=total+2*(select count(*)::integer from jsonb_array_elements(coalesce(p_side->''field'',''[]''::jsonb)) with ordinality a(value,ordinality) where a.value->>''cardId''=''athena'' and coalesce((a.value->>''lane'')::integer,0)=coalesce((p_unit->>''lane'')::integer,0));
  if cid=''athena'' then total:=total-2; end if;
  if cid=''lobo-alfa'' then total:=total+2*(select count(*)::integer from jsonb_array_elements(coalesce(p_side->''field'',''[]''::jsonb)) a(value) where a.value->>''cardId''=''lobo-beta''); end if;');
  elsif routine.proname='submit_game_action' then
   definition:=replace(definition,'case when card_id=''lobo-alfa'' then 1 else 0 end','0');
   definition:=regexp_replace(definition,
    'if card_id=''athena'' and jsonb_array_length\(deck_array\)>0 then[^;]*;select[^;]*; end if;',
    '-- Athena now grants a lane aura in _online_unit_power.','g');
   if position('if card_id=''athena'' and jsonb_array_length' in definition)>0 then raise exception 'Unexpected Athena entry effect. No changes applied.'; end if;
  end if;
  if definition<>original then execute definition; end if;
 end loop;
end; $migration$;

commit;
