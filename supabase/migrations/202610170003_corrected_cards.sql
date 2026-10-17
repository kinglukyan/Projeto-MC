-- Corrected cards supplied by the user. Apply after 202610170002.
begin;
update public.card_lore set card_name='Ragnar',ability_title='Invasores de Katgat',ability_text='Ao entrar em campo, move uma carta aliada de baixo poder de outra fileira para a mesma fileira de Ragnar, unindo as forças.',art_url='assets/cards-20261017/ragnar.png',power=3,updated_at=now() where card_id='ragnar';
update public.card_lore set card_name='Ártemis',ability_title='Tiro Preciso',ability_text='Ao entrar em campo, elimina duas cartas Monstros de cada lado.',art_url='assets/cards-20261017/artemis.png',power=5,updated_at=now() where card_id='artemis';
update public.card_lore set card_name='Beowulf',ability_title='Coragem de Geat',ability_text='Ao entrar em campo, se houver alguma carta da facção Monstros na mesa, ganha +3 pontos de poder adicional.',art_url='assets/cards-20261017/beowulf.png',power=3,updated_at=now() where card_id='beowulf';
commit;
