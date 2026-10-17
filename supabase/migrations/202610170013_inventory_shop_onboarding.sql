-- Apply after migration 012. Safe to reapply; starter grants are recorded once.
begin;
drop trigger if exists grant_chibi_avatars on public.profiles;
drop trigger if exists check_owned_deck on public.player_decks;
drop trigger if exists check_owned_saved_deck on public.player_saved_decks;
create table if not exists public.player_starter_grants(
 player_id uuid primary key references public.profiles(id) on delete cascade,
 granted_at timestamptz not null default now(),card_ids text[] not null,icon_ids text[] not null
);
alter table public.player_starter_grants enable row level security;
revoke all on public.player_starter_grants from public,anon,authenticated;

insert into public.shop_catalog(item_id,title,description,kind,price,asset_path,card_id,active) values
('card-soldado-esparta','Soldado de Esparta','Adicione esta carta à sua coleção.','card',1000,'assets/soldado-esparta-sem-pontas-azuis.png','soldado-esparta',true),
('card-athena','Athena','Todas as outras cartas na mesma fileira de Athena ganham +2 pontos de poder cada.','card',1000,'assets/cards-20261017/athena.png','athena',true),
('card-lobo-alfa','Lobisomem Alfa','A cada Lobisomem Beta em campo, ganha 2 pontos de poder.','card',1000,'assets/cards-20261017/lobo-alfa.png','lobo-alfa',true),
('card-guardiao-nordico','Guardião Nórdico','As Runas Nórdicas aumentam seu poder enquanto estiver em campo.','card',1000,'assets/cards-20261017/guardiao-nordico.png','guardiao-nordico',true),
('card-mjolnir','Mjölnir','Somente Thor pode equipar. Concede +4 de poder.','card',1000,'assets/equipment/mjolnir.png','mjolnir',true),
('card-runas-nordicas','Runa Uruz','Um personagem nórdico à sua escolha recebe +2 de poder.','card',1000,'assets/equipment/runas-nordicas.png','runas-nordicas',true),
('card-grecia','Grécia','Enquanto este Local estiver ativo, todos os gregos recebem +2 de poder, nos dois lados do campo.','card',1000,'assets/locations/grecia.png','grecia',true),
('card-eclipse','Eclipse','Ao jogar na área de Clima/Evento, sorteia Eclipse Lunar ou Solar, com 50% de chance para cada. O resultado afeta os dois lados até o fim da rodada.','card',1000,'assets/eclipse/eclipse.png','eclipse',true),
('card-campo-troia','Troia','Fortalece Aquiles, Athena e Ares em +3 de poder.','card',1000,'assets/terrains/campo-troia.png','campo-troia',true),
('card-medusa','Medusa','Adicione esta carta à sua coleção.','card',1000,'assets/medusa-full.png','medusa',true),
('card-poseidon','Poseidon','Adicione esta carta à sua coleção.','card',1000,'assets/poseidon-full.png','poseidon',true),
('card-zeus','Zeus','Adicione esta carta à sua coleção.','card',1000,'assets/zeus-full.png','zeus',true),
('card-hades','Hades','Ao entrar em campo, escolha uma carta do seu próprio Submundo para voltar ao campo. A carta retorna na fileira de Hades e ativa sua habilidade de entrada.','card',1000,'assets/hades-full.png','hades',true),
('card-lobo-omega','Lobisomem Omega','Se o Lobisomem Omega for o único na sua fileira de batalha e o inimigo tiver mais poder que o Omega, seu poder aumenta em 8.','card',1000,'assets/cards-20261017/lobo-omega.png','lobo-omega',true),
('card-lukyan','Lukyan — Rei da Festa','Ao entrar numa fileira com outros personagens, ganha +3 pontos de poder.','card',1000,'assets/cards-20261017/lukyan.png','lukyan',true),
('card-anubis','Anúbis','Ao entrar em campo, escolhe uma carta inimiga com 3 ou menos pontos de poder e a envia para o Submundo. Recupera uma carta de mesmo poder do Submundo do invocador.','card',1000,'assets/cards-20261017/anubis.png','anubis',true),
('card-odin','Odin','No início do próximo turno do dono, observe a carta do topo do seu baralho. Você pode descartá-la para ganhar +2 na soma da rodada ou mantê-la no topo.','card',1000,'assets/cards-20261017/odin.png','odin',true),
('card-minotauro','Minotauro','Ao entrar em campo, se estiver sozinho em sua fileira de batalha, ganha +3 pontos de poder.','card',1000,'assets/cards-20261017/minotauro.png','minotauro',true),
('card-apolo','Apolo','Ao ser colocado numa fileira, todos os personagens dessa fileira têm seu poder dobrado.','card',1000,'assets/cards-20261017/apolo.png','apolo',true),
('card-ra','Rá','No final de cada rodada, adiciona +1 de poder a todas as cartas da sua facção Egito em campo.','card',1000,'assets/cards-20261017/ra.png','ra',true),
('card-ragnar','Ragnar','Ao entrar em campo, move uma carta aliada de baixo poder de outra fileira para a mesma fileira de Ragnar, unindo as forças.','card',1000,'assets/cards-20261017/ragnar.png','ragnar',true),
('card-afrodite','Afrodite','Ao entrar em campo, o invocador pode escolher uma carta inimiga em campo para roubar, desde que ela tenha menos de 5 de poder.','card',1000,'assets/cards-20261017/afrodite.png','afrodite',true),
('card-aquiles','Aquiles','Ao entrar em campo, ganha +1 de poder para cada soldado grego ou herói aliado em sua fileira.','card',1000,'assets/cards-20261017/aquiles.png','aquiles',true),
('card-seth','Seth','Ao entrar em campo, escolhe uma fileira e troca os valores de poder de todas as cartas nela, aliadas e inimigas, de forma aleatória entre elas.','card',1000,'assets/cards-20261017/seth.png','seth',true),
('card-osiris','Osíris','Ao ser destruído e enviado para o cemitério, dobra o poder de outra carta aliada aleatória em campo.','card',1000,'assets/cards-20261017/osiris.png','osiris',true),
('card-thor','Thor','Ao entrar em campo, escolhe a carta inimiga de maior poder e a envia para o Submundo.','card',1000,'assets/cards-20261017/thor.png','thor',true),
('card-artemis','Ártemis','Ao entrar em campo, elimina duas cartas Monstros de cada lado.','card',1000,'assets/cards-20261017/artemis.png','artemis',true),
('card-sobek','Sobek','Ao entrar em campo, se houver outra carta aliada na mesma fileira, ganha +2 de poder adicional.','card',1000,'assets/cards-20261017/sobek.png','sobek',true),
('card-ares','Ares','Ao entrar na Guerra, todos os Soldados de Esparta e Leônidas ganham 2 pontos de poder e todos os gregos ganham 1.','card',1000,'assets/cards-20261017/ares.png','ares',true),
('card-beowulf','Beowulf','Ao entrar em campo, se houver alguma carta da facção Monstros na mesa, ganha +3 pontos de poder adicional.','card',1000,'assets/cards-20261017/beowulf.png','beowulf',true),
('card-heimdall','Heimdall','Enquanto estiver em campo, nenhuma carta inimiga pode alterar o valor de poder das suas cartas nesta fileira.','card',1000,'assets/cards-20261017/heimdall.png','heimdall',true),
('card-dionisio','Dionísio','Todos os efeitos de cartas de ambos os lados ficam desativados até o fim da rodada atual.','card',1000,'assets/cards-20261017/dionisio.png','dionisio',true),
('card-butter','Butter','Ao entrar em campo, rouba uma carta aleatória da mão do oponente.','card',1000,'assets/cards-20261017/butter.png','butter',true),
('card-hefesto','Hefestos','Ao entrar em campo, aumenta em +3 os pontos de poder de um personagem com carta de equipamento.','card',1000,'assets/cards-20261017/hefesto.png','hefesto',true),
('card-hercules','Hércules','No fim da rodada, ganha +1 de poder. Todo progresso é zerado na troca de rodada.','card',1000,'assets/cards-20261017/hercules.png','hercules',true),
('card-hermes','Hermes','Ao entrar em campo, você pode mover outra carta sua de uma fileira para outra, reorganizando sua pontuação.','card',1000,'assets/cards-20261017/hermes.png','hermes',true),
('card-horus','Hórus','Ao entrar em campo, pode ver duas cartas do adversário.','card',1000,'assets/cards-20261017/horus.png','horus',true),
('card-lobo-beta','Lobisomem Beta','Ao entrar em campo, chama os outros Betas que estiverem na mão do invocador para o campo.','card',1000,'assets/cards-20261017/lobo-beta.png','lobo-beta',true),
('card-isis','Ísis','Ao entrar em campo, escolha uma carta com 2 ou menos de poder do seu próprio Submundo para retornar ao campo na fileira de Ísis.','card',1000,'assets/cards-20261017/isis.png','isis',true),
('card-mulher','Mulher','Alfa sem poderes, usa sua labia para ganhar poder liderando homens humanos, cada homem dobra sua força.','card',1000,'assets/cards-20261017/mulher.png','mulher',true),
('card-homem','Homem','Ao perder os poderes, humanos se unem para duplicar suas forças.','card',1000,'assets/cards-20261017/homem.png','homem',true),
('card-yggdrasil','Yggdrasil','Fortalece Odin em +2 de poder.','card',1000,'assets/terrains/yggdrasil.png','yggdrasil',true),
('card-alto-egito','Alto Egito','Fortalece todos os egípcios em +2 de poder.','card',1000,'assets/terrains/alto-egito.jpg','alto-egito',true),
('card-baixo-egito','Baixo Egito','Fortalece todos os egípcios em +2 de poder.','card',1000,'assets/terrains/baixo-egito.png','baixo-egito',true),
('card-bifrost','Bifrost','Fortalece todos os nórdicos, exceto Loki, em +2 de poder.','card',1000,'assets/terrains/bifrost.png','bifrost',true),
('card-esparta','Esparta','Fortalece os espartanos em +2 de poder e Ares em +3 de poder.','card',1000,'assets/terrains/esparta.png','esparta',true),
('card-labirinto-dedalos','Labirinto de Dédalos','Fortalece o Minotauro e os monstros gregos em +2 de poder.','card',1000,'assets/terrains/labirinto-dedalos.png','labirinto-dedalos',true),
('card-nilfheim','Nilfheim','Fortalece Loki e os gigantes de gelo em +2 de poder.','card',1000,'assets/terrains/nilfheim.png','nilfheim',true),
('card-asgard','Asgard','Enquanto este Local estiver ativo, todos os nórdicos recebem +2 de poder, nos dois lados do campo.','card',1000,'assets/locations/asgard.png','asgard',true),
('card-egito','Egito','Enquanto este Local estiver ativo, todos os egípcios recebem +2 de poder, nos dois lados do campo.','card',1000,'assets/locations/egito.png','egito',true),
('card-olho-que-tudo-ve','Olho que Tudo Vê','Somente Hórus, Rá e Osíris podem equipar. Concede +4 de poder.','card',1000,'assets/equipment/olho-que-tudo-ve.png','olho-que-tudo-ve',true),
('card-raio-de-zeus','Raio de Zeus','Somente Zeus pode equipar. Concede +4 de poder.','card',1000,'assets/equipment/raio-de-zeus.png','raio-de-zeus',true),
('card-excalibur','Excalibur','Somente Rei Arthur e Lukyan base podem equipar. Rei Arthur recebe +4 de poder. Lukyan base se transforma em Lukyan — Rei de Todos, uma carta especial que não entra no baralho nem na mão.','card',1000,'assets/equipment/excalibur.png','excalibur',true),
('card-loki','Loki','Ao entrar em campo, Loki copia o valor de poder e a habilidade de uma carta inimiga já jogada na mesa até o fim da rodada.','card',1000,'assets/cards-20261017/loki.png','loki',true),
('chibi-soldado-esparta','Soldado de Esparta · Chibi','Ícone de perfil de Soldado de Esparta','avatar',500,'assets/avatars-chibi/portraits-01.png#chibi-0-0',null,true),
('chibi-athena','Athena · Chibi','Ícone de perfil de Athena','avatar',500,'assets/avatars-chibi/portraits-01.png#chibi-1-0',null,true),
('chibi-lobo-alfa','Lobisomem Alfa · Chibi','Ícone de perfil de Lobisomem Alfa','avatar',500,'assets/avatars-chibi/portraits-01.png#chibi-2-0',null,true),
('chibi-guardiao-nordico','Guardião Nórdico · Chibi','Ícone de perfil de Guardião Nórdico','avatar',500,'assets/avatars-chibi/portraits-01.png#chibi-0-1',null,true),
('chibi-medusa','Medusa · Chibi','Ícone de perfil de Medusa','avatar',500,'assets/avatars-chibi/portraits-01.png#chibi-1-1',null,true),
('chibi-poseidon','Poseidon · Chibi','Ícone de perfil de Poseidon','avatar',500,'assets/avatars-chibi/portraits-02.png#chibi-0-0',null,true),
('chibi-zeus','Zeus · Chibi','Ícone de perfil de Zeus','avatar',500,'assets/avatars-chibi/portraits-02.png#chibi-1-0',null,true),
('chibi-hades','Hades · Chibi','Ícone de perfil de Hades','avatar',500,'assets/avatars-chibi/portraits-02.png#chibi-2-0',null,true),
('chibi-lobo-omega','Lobisomem Omega · Chibi','Ícone de perfil de Lobisomem Omega','avatar',500,'assets/avatars-chibi/portraits-02.png#chibi-0-1',null,true),
('chibi-lukyan','Lukyan — Rei da Festa · Chibi','Ícone de perfil de Lukyan — Rei da Festa','avatar',500,'assets/avatars-chibi/portraits-02.png#chibi-1-1',null,true),
('chibi-anubis','Anúbis · Chibi','Ícone de perfil de Anúbis','avatar',500,'assets/avatars-chibi/portraits-03.png#chibi-0-0',null,true),
('chibi-odin','Odin · Chibi','Ícone de perfil de Odin','avatar',500,'assets/avatars-chibi/portraits-03.png#chibi-1-0',null,true),
('chibi-minotauro','Minotauro · Chibi','Ícone de perfil de Minotauro','avatar',500,'assets/avatars-chibi/portraits-03.png#chibi-2-0',null,true),
('chibi-apolo','Apolo · Chibi','Ícone de perfil de Apolo','avatar',500,'assets/avatars-chibi/portraits-03.png#chibi-0-1',null,true),
('chibi-ra','Rá · Chibi','Ícone de perfil de Rá','avatar',500,'assets/avatars-chibi/portraits-03.png#chibi-1-1',null,true),
('chibi-ragnar','Ragnar · Chibi','Ícone de perfil de Ragnar','avatar',500,'assets/avatars-chibi/portraits-04.png#chibi-0-0',null,true),
('chibi-afrodite','Afrodite · Chibi','Ícone de perfil de Afrodite','avatar',500,'assets/avatars-chibi/portraits-04.png#chibi-1-0',null,true),
('chibi-aquiles','Aquiles · Chibi','Ícone de perfil de Aquiles','avatar',500,'assets/avatars-chibi/portraits-04.png#chibi-2-0',null,true),
('chibi-seth','Seth · Chibi','Ícone de perfil de Seth','avatar',500,'assets/avatars-chibi/portraits-04.png#chibi-0-1',null,true),
('chibi-osiris','Osíris · Chibi','Ícone de perfil de Osíris','avatar',500,'assets/avatars-chibi/portraits-04.png#chibi-1-1',null,true),
('chibi-thor','Thor · Chibi','Ícone de perfil de Thor','avatar',500,'assets/avatars-chibi/portraits-05.png#chibi-0-0',null,true),
('chibi-artemis','Ártemis · Chibi','Ícone de perfil de Ártemis','avatar',500,'assets/avatars-chibi/portraits-05.png#chibi-1-0',null,true),
('chibi-sobek','Sobek · Chibi','Ícone de perfil de Sobek','avatar',500,'assets/avatars-chibi/portraits-05.png#chibi-2-0',null,true),
('chibi-ares','Ares · Chibi','Ícone de perfil de Ares','avatar',500,'assets/avatars-chibi/portraits-05.png#chibi-0-1',null,true),
('chibi-beowulf','Beowulf · Chibi','Ícone de perfil de Beowulf','avatar',500,'assets/avatars-chibi/portraits-05.png#chibi-1-1',null,true),
('chibi-heimdall','Heimdall · Chibi','Ícone de perfil de Heimdall','avatar',500,'assets/avatars-chibi/portraits-06.png#chibi-0-0',null,true),
('chibi-dionisio','Dionísio · Chibi','Ícone de perfil de Dionísio','avatar',500,'assets/avatars-chibi/portraits-06.png#chibi-1-0',null,true),
('chibi-butter','Butter · Chibi','Ícone de perfil de Butter','avatar',500,'assets/avatars-chibi/portraits-06.png#chibi-2-0',null,true),
('chibi-hefesto','Hefestos · Chibi','Ícone de perfil de Hefestos','avatar',500,'assets/avatars-chibi/portraits-06.png#chibi-0-1',null,true),
('chibi-hercules','Hércules · Chibi','Ícone de perfil de Hércules','avatar',500,'assets/avatars-chibi/portraits-06.png#chibi-1-1',null,true),
('chibi-hermes','Hermes · Chibi','Ícone de perfil de Hermes','avatar',500,'assets/avatars-chibi/portraits-07.png#chibi-0-0',null,true),
('chibi-horus','Hórus · Chibi','Ícone de perfil de Hórus','avatar',500,'assets/avatars-chibi/portraits-07.png#chibi-1-0',null,true),
('chibi-lobo-beta','Lobisomem Beta · Chibi','Ícone de perfil de Lobisomem Beta','avatar',500,'assets/avatars-chibi/portraits-07.png#chibi-2-0',null,true),
('chibi-isis','Ísis · Chibi','Ícone de perfil de Ísis','avatar',500,'assets/avatars-chibi/portraits-07.png#chibi-0-1',null,true),
('chibi-mulher','Mulher · Chibi','Ícone de perfil de Mulher','avatar',500,'assets/avatars-chibi/portraits-07.png#chibi-1-1',null,true),
('chibi-homem','Homem · Chibi','Ícone de perfil de Homem','avatar',500,'assets/avatars-chibi/portraits-08.png#chibi-0-0',null,true),
('chibi-loki','Loki · Chibi','Ícone de perfil de Loki','avatar',500,'assets/avatars-chibi/portraits-08.png#chibi-1-0',null,true)
on conflict(item_id) do update set title=excluded.title,description=excluded.description,kind=excluded.kind,price=excluded.price,asset_path=excluded.asset_path,card_id=excluded.card_id,active=true;
update public.shop_catalog set price=case when kind='avatar' then 500 else 1000 end,active=true where kind in ('avatar','card');
update public.shop_catalog set active=false where kind='card' and card_id in ('lukyan-rei-de-todos','eclipse-lunar','eclipse-solar');

create or replace function public._inventory_admin(uid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.users where id=uid and lower(email)='santoslucasalmeida@gmail.com')
$$;
revoke all on function public._inventory_admin(uuid) from public,anon,authenticated;

create or replace function public._ensure_player_inventory(uid uuid) returns void
language plpgsql security definer set search_path='' as $$
declare chosen_cards text[];chosen_icons text[];is_admin boolean;fresh boolean;
begin
 perform 1 from public.profiles where id=uid for update;
 if not found then return;end if;
 is_admin:=public._inventory_admin(uid);
 if is_admin then
  update public.profiles set tutorial_completed=true,xp=greatest(xp,100) where id=uid and (not tutorial_completed or xp<100);
  insert into public.player_inventory(player_id,item_id) select uid,item_id from public.shop_catalog on conflict do nothing;
  insert into public.player_card_copies(player_id,card_id,copies) select uid,card_id,3 from public.shop_catalog where kind='card' and card_id is not null
    on conflict(player_id,card_id) do update set copies=greatest(public.player_card_copies.copies,excluded.copies);
 else
  if not exists(select 1 from public.player_starter_grants where player_id=uid) then
   select array_agg(card_id) into chosen_cards from (select card_id from public.shop_catalog where kind='card' and active and public._r_card(card_id)->>'kind'='unit' group by card_id order by random() limit 10) u;
   select chosen_cards||array_agg(card_id) into chosen_cards from (select card_id from public.shop_catalog where kind='card' and active and public._r_card(card_id)->>'kind'<>'unit' group by card_id order by random() limit 4) s;
   select array_agg(item_id) into chosen_icons from (select item_id from public.shop_catalog where kind='avatar' and active order by random() limit 2) a;
   if cardinality(chosen_cards)<>14 or cardinality(chosen_icons)<>2 then raise exception 'Catálogo insuficiente para o presente inicial.';end if;
   insert into public.player_starter_grants(player_id,card_ids,icon_ids) values(uid,chosen_cards,chosen_icons);
   insert into public.player_card_copies(player_id,card_id,copies) select uid,unnest(chosen_cards),1 on conflict do nothing;
   insert into public.player_inventory(player_id,item_id) select uid,unnest(chosen_icons) on conflict do nothing;
   update public.profiles set equipped_avatar=chosen_icons[1] where id=uid and equipped_avatar in ('default','guardian');
  end if;
 end if;
 -- Retain purchases and gifts when bringing older accounts into actual ownership.
 insert into public.player_card_copies(player_id,card_id,copies)
 select uid,c.card_id,1 from public.player_inventory i join public.shop_catalog c using(item_id) where i.player_id=uid and c.kind='card' and c.card_id is not null
 on conflict do nothing;
 insert into public.player_inventory(player_id,item_id) select uid,c.item_id from public.shop_catalog c join public.player_card_copies p on p.card_id=c.card_id and p.player_id=uid and p.copies>0 where c.kind='card' on conflict do nothing;
 insert into public.player_inventory(player_id,item_id) select uid,item_id from public.shop_catalog where item_id in ('battle-forest','hand-heaven') on conflict do nothing;
 insert into public.player_decks(player_id,card_counts)
 select uid,coalesce(jsonb_object_agg(card_id,least(copies,1)),'{}'::jsonb) from (select card_id,copies from public.player_card_copies where player_id=uid and copies>0 and not coalesce((public._r_card(card_id)->>'specialOnly')::boolean,false) order by random() limit 14) c
 on conflict do nothing;
end $$;
revoke all on function public._ensure_player_inventory(uuid) from public,anon,authenticated;
create or replace function public.sync_player_entitlements() returns void
language plpgsql security definer set search_path='' as $$
begin if auth.uid() is null then raise exception 'Entre na conta.';end if;perform public._ensure_player_inventory(auth.uid());end $$;
revoke all on function public.sync_player_entitlements() from public,anon;
grant execute on function public.sync_player_entitlements() to authenticated;

create or replace function public._inventory_profile_created() returns trigger language plpgsql security definer set search_path='' as $$
begin perform public._ensure_player_inventory(new.id);return new;end $$;
drop trigger if exists inventory_profile_created on public.profiles;
create trigger inventory_profile_created after insert on public.profiles for each row execute function public._inventory_profile_created();
revoke all on function public._inventory_profile_created() from public,anon,authenticated;

create or replace function public._inventory_catalog_added() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.player_inventory(player_id,item_id) select id,new.item_id from auth.users where lower(email)='santoslucasalmeida@gmail.com' and exists(select 1 from public.profiles where id=auth.users.id) on conflict do nothing;
 if new.kind='card' and new.card_id is not null then
  insert into public.player_card_copies(player_id,card_id,copies) select id,new.card_id,3 from auth.users where lower(email)='santoslucasalmeida@gmail.com' and exists(select 1 from public.profiles where id=auth.users.id)
  on conflict(player_id,card_id) do update set copies=greatest(public.player_card_copies.copies,3);
 end if;return new;
end $$;
drop trigger if exists inventory_catalog_added on public.shop_catalog;
create trigger inventory_catalog_added after insert or update on public.shop_catalog for each row execute function public._inventory_catalog_added();
revoke all on function public._inventory_catalog_added() from public,anon,authenticated;

create or replace function public._inventory_catalog_price() returns trigger language plpgsql set search_path='' as $$
begin
 if new.kind='avatar' then new.price:=500;
 elsif new.kind='card' then new.price:=1000;
  if new.card_id in ('lukyan-rei-de-todos','eclipse-lunar','eclipse-solar') then new.active:=false;end if;
 end if;return new;
end $$;
drop trigger if exists inventory_catalog_price on public.shop_catalog;
create trigger inventory_catalog_price before insert or update on public.shop_catalog for each row execute function public._inventory_catalog_price();
revoke all on function public._inventory_catalog_price() from public,anon,authenticated;

-- A gift for a card item must create usable copies as well as its shop record.
create or replace function public._inventory_item_received() returns trigger language plpgsql security definer set search_path='' as $$
declare cid text;
begin
 select card_id into cid from public.shop_catalog where item_id=new.item_id and kind='card';
 if cid is not null then insert into public.player_card_copies(player_id,card_id,copies) values(new.player_id,cid,1) on conflict do nothing;end if;return new;
end $$;
drop trigger if exists inventory_item_received on public.player_inventory;
create trigger inventory_item_received after insert on public.player_inventory for each row execute function public._inventory_item_received();
revoke all on function public._inventory_item_received() from public,anon,authenticated;

create or replace function public.purchase_shop_item(p_item_id text) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();item public.shop_catalog%rowtype;balance integer;
begin
 if uid is null then raise exception 'Entre na conta para comprar.';end if;
 perform public._ensure_player_inventory(uid);
 select * into item from public.shop_catalog where item_id=p_item_id and active for update;
 if not found then raise exception 'Este item não está disponível.';end if;
 if exists(select 1 from public.player_inventory where player_id=uid and item_id=p_item_id) or (item.kind='card' and exists(select 1 from public.player_card_copies where player_id=uid and card_id=item.card_id and copies>0)) then raise exception 'Você já tem este item.';end if;
 update public.profiles set mythic_coins=mythic_coins-item.price where id=uid and mythic_coins>=item.price returning mythic_coins into balance;
 if not found then raise exception 'Você ainda não tem Mythic Coins suficientes.';end if;
 insert into public.player_inventory(player_id,item_id) values(uid,p_item_id);
 return jsonb_build_object('item_id',p_item_id,'balance',balance);
end $$;
revoke all on function public.purchase_shop_item(text) from public,anon;
grant execute on function public.purchase_shop_item(text) to authenticated;

-- Historical experience and completed matches are also evidence of an experienced account.
update public.profiles p set tutorial_completed=true,xp=greatest(coalesce(xp,0),100)
where public._inventory_admin(p.id) or coalesce(xp,0)>=100 or coalesce((settings->>'tutorial_completed')='true',false)
 or coalesce(wins,0)+coalesce(losses,0)>0 or exists(select 1 from public.match_history h where h.player_id=p.id);
do $$ declare p record;begin for p in select id from public.profiles order by id loop perform public._ensure_player_inventory(p.id);end loop;end $$;

-- Clamp legacy saved decks without deleting earned or purchased cards.
update public.player_decks d set card_counts=coalesce((select jsonb_object_agg(e.key,least(e.value::integer,coalesce(p.copies,0))) from jsonb_each_text(d.card_counts) e left join public.player_card_copies p on p.player_id=d.player_id and p.card_id=e.key where e.value ~ '^[0-9]+$' and coalesce(p.copies,0)>0 and not coalesce((public._r_card(e.key)->>'specialOnly')::boolean,false)),'{}'::jsonb);
update public.player_saved_decks d set card_counts=coalesce((select jsonb_object_agg(e.key,least(e.value::integer,coalesce(p.copies,0))) from jsonb_each_text(d.card_counts) e left join public.player_card_copies p on p.player_id=d.player_id and p.card_id=e.key where e.value ~ '^[0-9]+$' and coalesce(p.copies,0)>0 and not coalesce((public._r_card(e.key)->>'specialOnly')::boolean,false)),'{}'::jsonb);
-- Repair the active legacy default when fewer than twelve owned cards survived.
update public.player_decks d set card_counts=(select jsonb_object_agg(card_id,1) from (select card_id from public.player_card_copies where player_id=d.player_id and copies>0 and not coalesce((public._r_card(card_id)->>'specialOnly')::boolean,false) order by public._r_card(card_id)->>'kind'='unit' desc,card_id limit 14) c)
where (select coalesce(sum(value::integer),0) from jsonb_each_text(d.card_counts))<12;

update public.player_saved_decks d set card_counts=(select card_counts from public.player_decks where player_id=d.player_id)
where (select coalesce(sum(value::integer),0) from jsonb_each_text(d.card_counts))<12;

create or replace function public._assert_owned_deck(uid uuid,counts jsonb) returns void language plpgsql security definer set search_path='' as $$
begin
 if jsonb_typeof(counts)<>'object' then raise exception 'Baralho inválido.';end if;
 if exists(select 1 from jsonb_each_text(counts) e left join public.player_card_copies p on p.player_id=uid and p.card_id=e.key
  where e.value !~ '^[0-9]{1,2}$' or case when e.value ~ '^[0-9]{1,2}$' then e.value::integer>coalesce(p.copies,0) or (e.value::integer>0 and (public._r_card(e.key)='{}'::jsonb or coalesce((public._r_card(e.key)->>'specialOnly')::boolean,false))) else false end)
 then raise exception 'Este baralho usa cartas ou cópias que você ainda não tem.';end if;
end $$;
revoke all on function public._assert_owned_deck(uuid,jsonb) from public,anon,authenticated;
create or replace function public._check_owned_saved_deck() returns trigger language plpgsql security definer set search_path='' as $$
begin perform public._assert_owned_deck(new.player_id,new.card_counts);return new;end $$;
drop trigger if exists check_owned_deck on public.player_decks;
create trigger check_owned_deck before insert or update of card_counts on public.player_decks for each row execute function public._check_owned_saved_deck();
drop trigger if exists check_owned_saved_deck on public.player_saved_decks;
create trigger check_owned_saved_deck before insert or update of card_counts on public.player_saved_decks for each row execute function public._check_owned_saved_deck();
revoke all on function public._check_owned_saved_deck() from public,anon,authenticated;

-- New or revised character art in the administrator editor also publishes its card.
create or replace function public._inventory_lore_added() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.card_id in ('lukyan-rei-de-todos','eclipse-lunar','eclipse-solar') then return new;end if;
 insert into public.shop_catalog(item_id,title,description,kind,price,asset_path,card_id,active)
 values('card-'||new.card_id,coalesce(nullif(new.card_name,''),new.card_id),coalesce(new.ability_text,''),'card',1000,coalesce(nullif(new.art_url,''),'assets/card-back.svg'),new.card_id,true)
 on conflict(item_id) do update set title=coalesce(nullif(new.card_name,''),public.shop_catalog.title),description=coalesce(nullif(new.ability_text,''),public.shop_catalog.description),asset_path=coalesce(nullif(new.art_url,''),public.shop_catalog.asset_path);
 return new;
end $$;
drop trigger if exists inventory_lore_added on public.card_lore;
create trigger inventory_lore_added after insert or update on public.card_lore for each row execute function public._inventory_lore_added();
revoke all on function public._inventory_lore_added() from public,anon,authenticated;

-- Respect character names and artwork already customized in the live catalog.
insert into public.shop_catalog(item_id,title,description,kind,price,asset_path,card_id,active)
select 'card-'||l.card_id,coalesce(nullif(l.card_name,''),c.title,l.card_id),coalesce(nullif(l.ability_text,''),c.description,''),'card',1000,coalesce(nullif(l.art_url,''),c.asset_path,'assets/card-back.svg'),l.card_id,true
from public.card_lore l left join public.shop_catalog c on c.item_id='card-'||l.card_id
where l.card_id not in ('lukyan-rei-de-todos','eclipse-lunar','eclipse-solar')
on conflict(item_id) do update set title=excluded.title,description=excluded.description,asset_path=excluded.asset_path;

create or replace function public._assert_match_inventory(uid uuid) returns void language plpgsql security definer set search_path='' as $$
declare counts jsonb;
begin
 select card_counts into counts from public.player_decks where player_id=uid;
 if counts is null or counts='{}'::jsonb then raise exception 'Monte seu baralho com as cartas da sua coleção.';end if;
 perform public._assert_owned_deck(uid,counts);
end $$;
revoke all on function public._assert_match_inventory(uuid) from public,anon,authenticated;

-- Match creation checks actual ownership too, including 2v2 and legacy decks.
-- Insert after BEGIN by signature, without matching any ability's source text.
do $ownership$
declare signature text;definition text;injection text;
begin
 foreach signature in array array['public._new_online_game_state(uuid,uuid)','public._new_online_duo_state(uuid,uuid,uuid,uuid)'] loop
  definition:=pg_get_functiondef(to_regprocedure(signature));
  if definition is null then raise exception 'Função de partida ausente: %',signature;end if;
  if strpos(definition,'inventory_ownership_v13')>0 then continue;end if;
  injection:=E'BEGIN\n -- inventory_ownership_v13\n perform public._assert_match_inventory(p_one);\n perform public._assert_match_inventory(p_two);\n';
  if signature like '%duo%' then
   injection:=injection||E' perform public._assert_match_inventory(p_three);\n perform public._assert_match_inventory(p_four);\n';
  end if;
  execute regexp_replace(definition,'\mBEGIN\M',injection,'i');
 end loop;
end $ownership$;

commit;
