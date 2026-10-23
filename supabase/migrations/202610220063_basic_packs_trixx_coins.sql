-- Apply after 062. Premium packs, fixed initial edition, atomic purchases.
begin;
do $prerequisite$ begin
 if to_regprocedure('public.credit_clash_bits_service(uuid,bigint,text)') is null or to_regprocedure('public._gc_data_before062()') is null then raise exception 'Aplique primeiro as migrações anteriores até a 062.';end if;
end $prerequisite$;
create table if not exists public.basic_card_packs(
 id text primary key,name text not null,faction text not null,edition text not null,
 price integer not null check(price>0),front_asset text not null,back_asset text not null,
 content_frozen boolean not null default false,enabled boolean not null default true,created_at timestamptz not null default now()
);
create table if not exists public.basic_pack_cards(
 pack_id text not null references public.basic_card_packs(id),card_id text not null,
 ordinal integer not null,card_name text not null,art text not null,
 primary key(pack_id,card_id),unique(pack_id,ordinal)
);
create table if not exists public.basic_pack_purchases(
 id uuid primary key default gen_random_uuid(),player_id uuid not null references public.profiles(id),
 request_id uuid not null,pack_id text not null references public.basic_card_packs(id),
 price_paid integer not null check(price_paid>0),cards jsonb not null check(jsonb_typeof(cards)='array' and jsonb_array_length(cards)>0),
 revealed_count integer not null default 0 check(revealed_count>=0 and revealed_count<=jsonb_array_length(cards)),
 purchased_at timestamptz not null default now(),opened_at timestamptz,
 unique(player_id,request_id)
);
create table if not exists public.premium_spend_ledger(
 purchase_id uuid primary key references public.basic_pack_purchases(id),player_id uuid not null references public.profiles(id),
 amount bigint not null check(amount>0),spent_at timestamptz not null default now()
);
alter table public.basic_card_packs enable row level security;
alter table public.basic_pack_cards enable row level security;
alter table public.basic_pack_purchases enable row level security;
alter table public.premium_spend_ledger enable row level security;
revoke all on public.basic_card_packs,public.basic_pack_cards,public.basic_pack_purchases,public.premium_spend_ledger from public,anon,authenticated;
grant all on public.basic_card_packs,public.basic_pack_cards,public.basic_pack_purchases,public.premium_spend_ledger to service_role;
create index if not exists basic_pack_unopened on public.basic_pack_purchases(player_id,purchased_at) where opened_at is null;

-- Literal snapshot: new cards added to the game cannot enter Basic I automatically.
do $seed$ declare p jsonb;c jsonb;card_position integer;created integer;begin
 for p in select value from jsonb_array_elements($catalog063$[{"id":"grecia-basico-1","name":"Grécia","faction":"Grécia","edition":"Básico I","price":1000,"front":"assets/basic-packs/grecia-frente.webp","back":"assets/basic-packs/grecia-verso.webp","cards":[{"id":"afrodite","name":"Afrodite","art":"assets/cards-remake/afrodite.webp","kind":"unit"},{"id":"apolo","name":"Apolo","art":"assets/cards-remake/apolo.webp","kind":"unit"},{"id":"aquiles","name":"Aquiles","art":"assets/cards-remake/aquiles.webp","kind":"unit"},{"id":"ares","name":"Ares","art":"assets/cards-remake/ares.webp","kind":"unit"},{"id":"artemis","name":"Ártemis","art":"assets/cards-remake/artemis.webp","kind":"unit"},{"id":"athena","name":"Athena","art":"assets/cards-remake/athena.webp","kind":"unit"},{"id":"campo-troia","name":"Troia","art":"assets/terrains/campo-troia.png","kind":"terrain"},{"id":"demeter","name":"Deméter","art":"assets/cards-remake/demeter.webp","kind":"unit"},{"id":"dionisio","name":"Dionísio","art":"assets/cards-remake/dionisio.webp","kind":"unit"},{"id":"esparta","name":"Esparta","art":"assets/terrains/esparta.png","kind":"terrain"},{"id":"grecia","name":"Grécia","art":"assets/locations/grecia.png","kind":"location"},{"id":"hades","name":"Hades","art":"assets/cards-remake/hades.webp","kind":"unit"},{"id":"hefesto","name":"Hefestos","art":"assets/cards-remake/hefesto.webp","kind":"unit"},{"id":"hera","name":"Hera","art":"assets/cards-remake/hera.webp","kind":"unit"},{"id":"hercules","name":"Hércules","art":"assets/cards-remake/hercules.webp","kind":"unit"},{"id":"hermes","name":"Hermes","art":"assets/cards-remake/hermes.webp","kind":"unit"},{"id":"hestia","name":"Héstia","art":"assets/cards-remake/hestia.webp","kind":"unit"},{"id":"labirinto-dedalos","name":"Labirinto de Dédalos","art":"assets/terrains/labirinto-dedalos.png","kind":"terrain"},{"id":"medusa","name":"Medusa","art":"assets/cards-remake/medusa.webp","kind":"unit"},{"id":"minotauro","name":"Minotauro","art":"assets/cards-remake/minotauro.webp","kind":"unit"},{"id":"perseu","name":"Perseu","art":"assets/cards-remake/perseu.webp","kind":"unit"},{"id":"poseidon","name":"Poseidon","art":"assets/cards-remake/poseidon.webp","kind":"unit"},{"id":"raio-de-zeus","name":"Raio de Zeus","art":"assets/equipment/raio-de-zeus.png","kind":"equipment"},{"id":"soldado-esparta","name":"Soldado de Esparta","art":"assets/cards-remake/soldado-esparta.webp","kind":"unit"},{"id":"zeus","name":"Zeus","art":"assets/cards-remake/zeus.webp","kind":"unit"}]},{"id":"egito-basico-1","name":"Egito","faction":"Egípcios","edition":"Básico I","price":1000,"front":"assets/basic-packs/egito-frente.webp","back":"assets/basic-packs/egito-verso.webp","cards":[{"id":"alto-egito","name":"Alto Egito","art":"assets/terrains/alto-egito.jpg","kind":"terrain"},{"id":"anubis","name":"Anúbis","art":"assets/cards-remake/anubis.webp","kind":"unit"},{"id":"baixo-egito","name":"Baixo Egito","art":"assets/terrains/baixo-egito.png","kind":"terrain"},{"id":"egito","name":"Egito","art":"assets/locations/egito.png","kind":"location"},{"id":"horus","name":"Hórus","art":"assets/cards-remake/horus.webp","kind":"unit"},{"id":"isis","name":"Ísis","art":"assets/cards-remake/isis.webp","kind":"unit"},{"id":"olho-que-tudo-ve","name":"Olho que Tudo Vê","art":"assets/equipment/olho-que-tudo-ve.png","kind":"equipment"},{"id":"osiris","name":"Osíris","art":"assets/cards-remake/osiris.webp","kind":"unit"},{"id":"ra","name":"Rá","art":"assets/cards-remake/ra.webp","kind":"unit"},{"id":"seth","name":"Seth","art":"assets/cards-remake/seth.webp","kind":"unit"},{"id":"sobek","name":"Sobek","art":"assets/cards-remake/sobek.webp","kind":"unit"}]},{"id":"nordicos-basico-1","name":"Nórdicos","faction":"Nórdicos","edition":"Básico I","price":1000,"front":"assets/basic-packs/nordicos-frente.webp","back":"assets/basic-packs/nordicos-verso.webp","cards":[{"id":"asgard","name":"Asgard","art":"assets/locations/asgard.png","kind":"location"},{"id":"beowulf","name":"Beowulf","art":"assets/cards-remake/beowulf.webp","kind":"unit"},{"id":"bifrost","name":"Bifrost","art":"assets/terrains/bifrost.png","kind":"terrain"},{"id":"guardiao-nordico","name":"Guardião Nórdico","art":"assets/cards-remake/guardiao-nordico.webp","kind":"unit"},{"id":"heimdall","name":"Heimdall","art":"assets/cards-remake/heimdall.webp","kind":"unit"},{"id":"loki","name":"Loki","art":"assets/cards-remake/loki.webp","kind":"unit"},{"id":"mjolnir","name":"Mjölnir","art":"assets/equipment/mjolnir.png","kind":"equipment"},{"id":"nilfheim","name":"Nilfheim","art":"assets/terrains/nilfheim.png","kind":"terrain"},{"id":"odin","name":"Odin","art":"assets/cards-remake/odin.webp","kind":"unit"},{"id":"ragnar","name":"Ragnar","art":"assets/cards-remake/ragnar.webp","kind":"unit"},{"id":"runas-nordicas","name":"Runa Uruz","art":"assets/equipment/runas-nordicas.png","kind":"equipment"},{"id":"thor","name":"Thor","art":"assets/cards-remake/thor.webp","kind":"unit"},{"id":"yggdrasil","name":"Yggdrasil","art":"assets/terrains/yggdrasil.png","kind":"terrain"}]},{"id":"celtas-basico-1","name":"Celtas","faction":"Celtas","edition":"Básico I","price":1000,"front":"assets/basic-packs/celtas-frente.webp","back":"assets/basic-packs/celtas-verso.webp","cards":[{"id":"celtas-brigid","name":"Brigid","art":"assets/cards-remake/celtas-brigid.webp","kind":"unit"},{"id":"celtas-cu-chulainn","name":"Cú Chulainn","art":"assets/cards-remake/celtas-cu-chulainn.webp","kind":"unit"},{"id":"celtas-dagda","name":"Dagda","art":"assets/cards-remake/celtas-dagda.webp","kind":"unit"},{"id":"celtas-dama-do-lago","name":"Dama do Lago","art":"assets/cards-remake/celtas-dama-do-lago.webp","kind":"unit"},{"id":"celtas-lancelot","name":"Lancelot","art":"assets/cards-remake/celtas-lancelot.webp","kind":"unit"},{"id":"celtas-lugh","name":"Lugh","art":"assets/cards-remake/celtas-lugh.webp","kind":"unit"},{"id":"celtas-merlin","name":"Merlin","art":"assets/cards-remake/celtas-merlin.webp","kind":"unit"},{"id":"celtas-morgana","name":"Morgana","art":"assets/cards-remake/celtas-morgana.webp","kind":"unit"},{"id":"celtas-morrigan","name":"Morrigan","art":"assets/cards-remake/celtas-morrigan.webp","kind":"unit"},{"id":"rei-arthur","name":"Rei Arthur","art":"assets/cards-remake/rei-arthur.webp","kind":"unit"}]},{"id":"mesopotamia-basico-1","name":"Mesopotâmica","faction":"Mesopotâmica","edition":"Básico I","price":1000,"front":"assets/basic-packs/mesopotamia-frente.webp","back":"assets/basic-packs/mesopotamia-verso.webp","cards":[{"id":"mesopotamica-enki","name":"Enki","art":"assets/cards-remake/mesopotamica-enki.webp","kind":"unit"},{"id":"mesopotamica-enlil","name":"Enlil","art":"assets/cards-remake/mesopotamica-enlil.webp","kind":"unit"},{"id":"mesopotamica-ereshkigal","name":"Ereshkigal","art":"assets/cards-remake/mesopotamica-ereshkigal.webp","kind":"unit"},{"id":"mesopotamica-ishtar","name":"Ishtar","art":"assets/cards-remake/mesopotamica-ishtar.webp","kind":"unit"},{"id":"mesopotamica-marduk","name":"Marduk","art":"assets/cards-remake/mesopotamica-marduk.webp","kind":"unit"},{"id":"mesopotamica-nanna-sin","name":"Nanna - Sîn","art":"assets/cards-remake/mesopotamica-nanna-sin.webp","kind":"unit"},{"id":"mesopotamica-nergal","name":"Nergal","art":"assets/cards-remake/mesopotamica-nergal.webp","kind":"unit"},{"id":"mesopotamica-ninurta","name":"Ninurta","art":"assets/cards-remake/mesopotamica-ninurta.webp","kind":"unit"},{"id":"mesopotamica-tiamat","name":"Tiamat","art":"assets/cards-remake/mesopotamica-tiamat.webp","kind":"unit"},{"id":"mesopotamica-utu-shamash","name":"Utu - Shamash","art":"assets/cards-remake/mesopotamica-utu-shamash.webp","kind":"unit"}]},{"id":"hindu-basico-1","name":"Hindu","faction":"Hindu","edition":"Básico I","price":1000,"front":"assets/basic-packs/hindu-frente.webp","back":"assets/basic-packs/hindu-verso.webp","cards":[{"id":"hindu-durga","name":"Durga","art":"assets/cards-remake/hindu-durga.webp","kind":"unit"},{"id":"hindu-ganesha","name":"Ganesha","art":"assets/cards-remake/hindu-ganesha.webp","kind":"unit"},{"id":"hindu-hanuman","name":"Hanuman","art":"assets/cards-remake/hindu-hanuman.webp","kind":"unit"},{"id":"hindu-indra","name":"Indra","art":"assets/cards-remake/hindu-indra.webp","kind":"unit"},{"id":"hindu-kali","name":"Kali","art":"assets/cards-remake/hindu-kali.webp","kind":"unit"},{"id":"hindu-krishna","name":"Krishna","art":"assets/cards-remake/hindu-krishna-v2.png","kind":"unit"},{"id":"hindu-lakshmi","name":"Lakshmi","art":"assets/cards-remake/hindu-lakshmi.webp","kind":"unit"},{"id":"hindu-saraswati","name":"Saraswati","art":"assets/cards-remake/hindu-saraswati.webp","kind":"unit"},{"id":"hindu-shiva","name":"Shiva","art":"assets/cards-remake/hindu-shiva.webp","kind":"unit"},{"id":"hindu-vishnu","name":"Vishnu","art":"assets/cards-remake/hindu-vishnu.webp","kind":"unit"}]},{"id":"chinesa-basico-1","name":"Chinesa","faction":"Chinesa","edition":"Básico I","price":1000,"front":"assets/basic-packs/chinesa-frente.webp","back":"assets/basic-packs/chinesa-verso.webp","cards":[{"id":"chinesa-ao-guang","name":"Ao Guang","art":"assets/cards-remake/chinesa-ao-guang.webp","kind":"unit"},{"id":"chinesa-change","name":"Chang'e","art":"assets/cards-remake/chinesa-change.webp","kind":"unit"},{"id":"chinesa-erlang-shen","name":"Erlang Shen","art":"assets/cards-remake/chinesa-erlang-shen.webp","kind":"unit"},{"id":"chinesa-fuxi","name":"Fuxi","art":"assets/cards-remake/chinesa-fuxi.webp","kind":"unit"},{"id":"chinesa-guanyin","name":"Guanyin","art":"assets/cards-remake/chinesa-guanyin.webp","kind":"unit"},{"id":"chinesa-hou-yi","name":"Hou Yi","art":"assets/cards-remake/chinesa-hou-yi.webp","kind":"unit"},{"id":"chinesa-imperador-jade","name":"Imperador de Jade","art":"assets/cards-remake/chinesa-imperador-jade.webp","kind":"unit"},{"id":"chinesa-nezha","name":"Nezha","art":"assets/cards-remake/chinesa-nezha.webp","kind":"unit"},{"id":"chinesa-nuwa","name":"Nüwa","art":"assets/cards-remake/chinesa-nuwa.webp","kind":"unit"},{"id":"chinesa-sun-wukong","name":"Sun Wukong","art":"assets/cards-remake/chinesa-sun-wukong.webp","kind":"unit"}]},{"id":"japonesa-basico-1","name":"Japonesa","faction":"Japonesa","edition":"Básico I","price":1000,"front":"assets/basic-packs/japonesa-frente.webp","back":"assets/basic-packs/japonesa-verso.webp","cards":[{"id":"japonesa-amaterasu","name":"Amaterasu","art":"assets/cards-remake/japonesa-amaterasu.webp","kind":"unit"},{"id":"japonesa-fujin","name":"Fūjin","art":"assets/cards-remake/japonesa-fujin.webp","kind":"unit"},{"id":"japonesa-hachiman","name":"Hachiman","art":"assets/cards-remake/japonesa-hachiman.webp","kind":"unit"},{"id":"japonesa-inari","name":"Inari","art":"assets/cards-remake/japonesa-inari.webp","kind":"unit"},{"id":"japonesa-izanagi","name":"Izanagi","art":"assets/cards-remake/japonesa-izanagi.webp","kind":"unit"},{"id":"japonesa-izanami","name":"Izanami","art":"assets/cards-remake/japonesa-izanami.webp","kind":"unit"},{"id":"japonesa-raijin","name":"Raijin","art":"assets/cards-remake/japonesa-raijin.webp","kind":"unit"},{"id":"japonesa-ryujin","name":"Ryūjin","art":"assets/cards-remake/japonesa-ryujin.webp","kind":"unit"},{"id":"japonesa-susanoo","name":"Susanoo","art":"assets/cards-remake/japonesa-susanoo.webp","kind":"unit"},{"id":"japonesa-tsukuyomi","name":"Tsukuyomi","art":"assets/cards-remake/japonesa-tsukuyomi.webp","kind":"unit"}]},{"id":"asteca-basico-1","name":"Asteca","faction":"Asteca","edition":"Básico I","price":1000,"front":"assets/basic-packs/asteca-frente.webp","back":"assets/basic-packs/asteca-verso.webp","cards":[{"id":"asteca-chalchiuhtlicue","name":"Chalchiuhtlicue","art":"assets/cards-remake/asteca-chalchiuhtlicue.webp","kind":"unit"},{"id":"asteca-coatlicue","name":"Coatlicue","art":"assets/cards-remake/asteca-coatlicue.webp","kind":"unit"},{"id":"asteca-huitzilopochtli","name":"Huitzilopochtli","art":"assets/cards-remake/asteca-huitzilopochtli.webp","kind":"unit"},{"id":"asteca-mictecacihuatl","name":"Mictecacíhuatl","art":"assets/cards-remake/asteca-mictecacihuatl.webp","kind":"unit"},{"id":"asteca-mictlantecuhtli","name":"Mictlantecuhtli","art":"assets/cards-remake/asteca-mictlantecuhtli.webp","kind":"unit"},{"id":"asteca-quetzalcoatl","name":"Quetzalcóatl","art":"assets/cards-remake/asteca-quetzalcoatl.webp","kind":"unit"},{"id":"asteca-tezcatlipoca","name":"Tezcatlipoca","art":"assets/cards-remake/asteca-tezcatlipoca.webp","kind":"unit"},{"id":"asteca-tlaloc","name":"Tláloc","art":"assets/cards-remake/asteca-tlaloc.webp","kind":"unit"},{"id":"asteca-xipe-totec","name":"Xipe Tótec","art":"assets/cards-remake/asteca-xipe-totec.webp","kind":"unit"},{"id":"asteca-xochiquetzal","name":"Xochiquétzal","art":"assets/cards-remake/asteca-xochiquetzal.webp","kind":"unit"}]},{"id":"brasil-basico-1","name":"Brasil","faction":"Brasil","edition":"Básico I","price":1000,"front":"assets/basic-packs/brasil-frente.webp","back":"assets/basic-packs/brasil-verso.webp","cards":[{"id":"brasil-boitata","name":"Boitatá","art":"assets/cards-remake/brasil-boitata.webp","kind":"unit"},{"id":"brasil-boto","name":"Boto Encantado","art":"assets/cards-remake/brasil-boto.webp","kind":"unit"},{"id":"brasil-caipora","name":"Caipora","art":"assets/cards-remake/brasil-caipora.webp","kind":"unit"},{"id":"brasil-cuca","name":"Cuca","art":"assets/cards-remake/brasil-cuca.webp","kind":"unit"},{"id":"brasil-curupira","name":"Curupira","art":"assets/cards-remake/brasil-curupira.webp","kind":"unit"},{"id":"brasil-iara","name":"Iara","art":"assets/cards-remake/brasil-iara.webp","kind":"unit"},{"id":"brasil-lampiao","name":"Lampião","art":"assets/cards-remake/brasil-lampiao.webp","kind":"unit"},{"id":"brasil-mapinguari","name":"Mapinguari","art":"assets/cards-remake/brasil-mapinguari.webp","kind":"unit"},{"id":"brasil-mula-sem-cabeca","name":"Mula sem Cabeça","art":"assets/cards-remake/brasil-mula-sem-cabeca.webp","kind":"unit"},{"id":"brasil-saci","name":"Saci-Pererê","art":"assets/cards-remake/brasil-saci.webp","kind":"unit"}]},{"id":"monstros-basico-1","name":"Monstros","faction":"Monstros","edition":"Básico I","price":1000,"front":"assets/basic-packs/monstros-frente.webp","back":"assets/basic-packs/monstros-verso.webp","cards":[{"id":"homem","name":"Homem","art":"assets/cards-remake/homem.webp","kind":"unit"},{"id":"lobo-alfa","name":"Lobisomem Alfa","art":"assets/cards-remake/lobo-alfa.webp","kind":"unit"},{"id":"lobo-beta","name":"Lobisomem Beta","art":"assets/cards-remake/lobo-beta.webp","kind":"unit"},{"id":"lobo-omega","name":"Lobisomem Omega","art":"assets/cards-remake/lobo-omega.webp","kind":"unit"},{"id":"mulher","name":"Mulher","art":"assets/cards-remake/mulher.webp","kind":"unit"}]},{"id":"alyns-basico-1","name":"Alyns","faction":"Alyns","edition":"Básico I","price":1000,"front":"assets/basic-packs/alyns-frente.webp","back":"assets/basic-packs/alyns-verso.webp","cards":[{"id":"butter","name":"Butter","art":"assets/cards-remake/butter.webp","kind":"unit"},{"id":"lukyan","name":"Lukyan — Rei da Festa","art":"assets/cards-remake/lukyan.webp","kind":"unit"}]}]$catalog063$::jsonb) loop
  insert into public.basic_card_packs(id,name,faction,edition,price,front_asset,back_asset)
  values(p->>'id',p->>'name',p->>'faction',p->>'edition',1000,p->>'front',p->>'back') on conflict do nothing;
  get diagnostics created=row_count;if created=0 then continue;end if;
  card_position:=0;
  for c in select value from jsonb_array_elements(p->'cards') loop
   insert into public.basic_pack_cards(pack_id,card_id,ordinal,card_name,art) values(p->>'id',c->>'id',card_position,c->>'name',c->>'art') on conflict do nothing;
   card_position:=card_position+1;
  end loop;
 end loop;
end $seed$;
update public.basic_card_packs set content_frozen=true where not content_frozen;
create or replace function public._protect_basic_pack_content() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op<>'INSERT' and exists(select 1 from public.basic_card_packs p where p.id=old.pack_id and p.content_frozen) then
  raise exception 'O conteúdo desta edição básica está fechado. Crie outra edição para novas cartas.';
 end if;
 if tg_op<>'DELETE' and exists(select 1 from public.basic_card_packs p where p.id=new.pack_id and p.content_frozen) then
  raise exception 'O conteúdo desta edição básica está fechado. Crie outra edição para novas cartas.';
 end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
revoke all on function public._protect_basic_pack_content() from public,anon,authenticated;
drop trigger if exists protect_basic_pack_content on public.basic_pack_cards;
create trigger protect_basic_pack_content before insert or update or delete on public.basic_pack_cards for each row execute function public._protect_basic_pack_content();


create or replace function public._basic_pack_receipt(p_id uuid) returns jsonb
language sql volatile security definer set search_path='' as $$
 select jsonb_build_object('id',b.id,'request_id',b.request_id,'pack_id',b.pack_id,'name',p.name,'edition',p.edition,'front',p.front_asset,'back',p.back_asset,
 'price_paid',b.price_paid,'cards',b.cards,'revealed_count',b.revealed_count,'opened_at',b.opened_at,'purchased_at',b.purchased_at)
 from public.basic_pack_purchases b join public.basic_card_packs p on p.id=b.pack_id where b.id=p_id
$$;
revoke all on function public._basic_pack_receipt(uuid) from public,anon,authenticated;

create or replace function public.get_basic_pack_shop() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();catalog jsonb;pending jsonb;balance bigint;
begin
 perform public._assert_account_active();if uid is null then raise exception 'Entre na sua conta.';end if;
 select coalesce(w.clash_bits,0) into balance from public.premium_wallets w where w.player_id=uid;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'faction',p.faction,'edition',p.edition,'price',p.price,'front',p.front_asset,'back',p.back_asset,
  'cards',(select jsonb_agg(jsonb_build_object('id',c.card_id,'name',c.card_name,'art',c.art) order by c.ordinal) from public.basic_pack_cards c where c.pack_id=p.id)) order by p.created_at,p.id),'[]') into catalog from public.basic_card_packs p where p.enabled;
 select coalesce(jsonb_agg(public._basic_pack_receipt(b.id) order by b.purchased_at),'[]') into pending from public.basic_pack_purchases b where b.player_id=uid and b.opened_at is null;
 return jsonb_build_object('currency','Trixx Coins','balance',coalesce(balance,0),'recharge_enabled',false,'catalog',catalog,'pending',pending);
end $$;
revoke all on function public.get_basic_pack_shop() from public,anon;
grant execute on function public.get_basic_pack_shop() to authenticated;

create or replace function public.buy_basic_pack(p_pack_id text,p_request_id uuid,p_expected_price integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();p public.basic_card_packs%rowtype;purchase public.basic_pack_purchases%rowtype;balance bigint;items jsonb;cid text;total integer;
begin
 perform public._assert_account_active();if uid is null then raise exception 'Entre na sua conta.';end if;
 if p_request_id is null then raise exception 'Atualize a loja e tente novamente.';end if;
 perform pg_advisory_xact_lock(hashtextextended('basic-packs:'||uid::text,63));
 select b.* into purchase from public.basic_pack_purchases b where b.player_id=uid and b.request_id=p_request_id;
 if found then
  if purchase.pack_id<>p_pack_id then raise exception 'Solicitação já utilizada para outro pacote.';end if;
  select w.clash_bits into balance from public.premium_wallets w where w.player_id=uid;
  return jsonb_build_object('balance',coalesce(balance,0),'purchase',public._basic_pack_receipt(purchase.id));
 end if;
 -- Resume an unfinished pack instead of charging for a second copy after a lost response.
 select b.* into purchase from public.basic_pack_purchases b where b.player_id=uid and b.pack_id=p_pack_id and b.opened_at is null order by b.purchased_at limit 1 for update;
 if found then
  select w.clash_bits into balance from public.premium_wallets w where w.player_id=uid;
  return jsonb_build_object('balance',coalesce(balance,0),'purchase',public._basic_pack_receipt(purchase.id));
 end if;
 perform public._security_rpc_gate('buy_basic_pack',10);
 select c.* into p from public.basic_card_packs c where c.id=p_pack_id and c.enabled for share;
 if not found then raise exception 'Este pacote está indisponível.';end if;
 if p_expected_price is distinct from p.price then raise exception 'O preço foi atualizado. Reabra a loja antes de comprar.';end if;
 select jsonb_agg(jsonb_build_object('id',c.card_id,'name',c.card_name,'art',c.art) order by c.ordinal),count(*) into items,total from public.basic_pack_cards c where c.pack_id=p.id;
 if total=0 then raise exception 'O conteúdo deste pacote está indisponível.';end if;
 for cid in select x->>'id' from jsonb_array_elements(items) x loop
  if public._r_card(cid)->>'id' is distinct from cid then raise exception 'Uma carta do pacote aguarda atualização. Tente novamente mais tarde.';end if;
 end loop;
 insert into public.premium_wallets(player_id,clash_bits) values(uid,0) on conflict do nothing;
 update public.premium_wallets set clash_bits=clash_bits-p.price,updated_at=now() where player_id=uid and clash_bits>=p.price returning clash_bits into balance;
 if not found then raise exception 'Saldo insuficiente de Trixx Coins. As recargas serão disponibilizadas em breve.';end if;
 insert into public.basic_pack_purchases(player_id,request_id,pack_id,price_paid,cards) values(uid,p_request_id,p.id,p.price,items) returning * into purchase;
 insert into public.premium_spend_ledger(purchase_id,player_id,amount) values(purchase.id,uid,p.price);
 -- Grant once in the same transaction as the debit. Animation cannot lose items.
 for cid in select x->>'id' from jsonb_array_elements(items) x loop
  insert into public.player_card_copies(player_id,card_id,copies) values(uid,cid,1)
   on conflict(player_id,card_id) do update set copies=public.player_card_copies.copies+1;
 end loop;
 insert into public.player_inventory(player_id,item_id) select uid,c.item_id from public.shop_catalog c where c.kind='card' and c.card_id in(select x->>'id' from jsonb_array_elements(items) x) on conflict do nothing;
 return jsonb_build_object('balance',balance,'purchase',public._basic_pack_receipt(purchase.id));
end $$;
revoke all on function public.buy_basic_pack(text,uuid,integer) from public,anon;
grant execute on function public.buy_basic_pack(text,uuid,integer) to authenticated;

create or replace function public.reveal_basic_pack_card(p_purchase_id uuid,p_expected_count integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();p public.basic_pack_purchases%rowtype;
begin
 perform public._assert_account_active();if uid is null then raise exception 'Entre na sua conta.';end if;
 select b.* into p from public.basic_pack_purchases b where b.id=p_purchase_id and b.player_id=uid for update;
 if not found then raise exception 'Pacote indisponível para esta conta.';end if;
 if p_expected_count is null or p_expected_count<0 or p_expected_count>p.revealed_count then raise exception 'Reabra o pacote para atualizar a próxima carta.';end if;
 if p_expected_count=p.revealed_count and p.revealed_count<jsonb_array_length(p.cards) then
  update public.basic_pack_purchases set revealed_count=revealed_count+1,
   opened_at=case when revealed_count+1=jsonb_array_length(cards) then now() else null end where id=p.id;
 end if;
 return public._basic_pack_receipt(p.id);
end $$;
revoke all on function public.reveal_basic_pack_card(uuid,integer) from public,anon;
grant execute on function public.reveal_basic_pack_card(uuid,integer) to authenticated;

-- The future payment webhook must verify a real payment BEFORE using this service-only entry point.
-- No client, match reward, gift code or ordinary admin RPC can call it.
create or replace function public.credit_trixx_coins_service(p_player uuid,p_amount bigint,p_payment_reference text) returns bigint
language sql security definer set search_path='' as $$
 select public.credit_clash_bits_service(p_player,p_amount,p_payment_reference)
$$;
revoke all on function public.credit_trixx_coins_service(uuid,bigint,text) from public,anon,authenticated;
grant execute on function public.credit_trixx_coins_service(uuid,bigint,text) to service_role;
notify pgrst,'reload schema';
commit;
