-- Apply after 013. Reconciles old free avatar grants without resetting cards.
begin;
create table if not exists public.inventory_icon_repair_backup(
 player_id uuid not null,item_id text not null,acquired_at timestamptz not null,
 reason text not null,archived_at timestamptz not null default now(),primary key(player_id,item_id)
);
alter table public.inventory_icon_repair_backup enable row level security;
revoke all on public.inventory_icon_repair_backup from public,anon,authenticated;

create or replace function public._ensure_player_inventory(uid uuid) returns void
language plpgsql security definer set search_path='' as $$
declare chosen_cards text[];chosen_icons text[];is_admin boolean;fresh boolean;
begin
 perform 1 from public.profiles where id=uid for update;
 if not found then return;end if;
 is_admin:=public._inventory_admin(uid);
 if is_admin then
  update public.profiles set tutorial_completed=true,xp=greatest(xp,100) where id=uid and (not tutorial_completed or xp<100);
  insert into public.player_inventory(player_id,item_id) select uid,item_id from public.shop_catalog where item_id<>'ares-helm' on conflict do nothing;
  insert into public.player_card_copies(player_id,card_id,copies) select uid,card_id,3 from public.shop_catalog where kind='card' and card_id is not null
    on conflict(player_id,card_id) do update set copies=greatest(public.player_card_copies.copies,excluded.copies);
 else
  if not exists(select 1 from public.player_starter_grants where player_id=uid) then
   select array_agg(card_id) into chosen_cards from (select card_id from public.shop_catalog where kind='card' and active and public._r_card(card_id)->>'kind'='unit' group by card_id order by random() limit 10) u;
   select chosen_cards||array_agg(card_id) into chosen_cards from (select card_id from public.shop_catalog where kind='card' and active and public._r_card(card_id)->>'kind'<>'unit' group by card_id order by random() limit 4) s;
   select array_agg(item_id) into chosen_icons from (select item_id from public.shop_catalog where kind='avatar' and active and item_id<>'ares-helm' order by random() limit 2) a;
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

create or replace function public._inventory_catalog_added() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.item_id='ares-helm' then return new;end if;
 insert into public.player_inventory(player_id,item_id) select id,new.item_id from auth.users where lower(email)='santoslucasalmeida@gmail.com' and exists(select 1 from public.profiles where id=auth.users.id) on conflict do nothing;
 if new.kind='card' and new.card_id is not null then
  insert into public.player_card_copies(player_id,card_id,copies) select id,new.card_id,3 from auth.users where lower(email)='santoslucasalmeida@gmail.com' and exists(select 1 from public.profiles where id=auth.users.id)
  on conflict(player_id,card_id) do update set copies=greatest(public.player_card_copies.copies,3);
 end if;return new;
end $$;
revoke all on function public._inventory_catalog_added() from public,anon,authenticated;

-- Keep a hidden tombstone because historical redemption codes may reference it.
update public.shop_catalog set active=false where item_id='ares-helm';
update public.redeem_codes set active=false where item_id='ares-helm';

do $repair$
declare p record;kept text[];extra text[];
begin
 for p in select id from public.profiles order by id loop
  perform public._ensure_player_inventory(p.id);
  if public._inventory_admin(p.id) then continue;end if;
  -- Preserve valid starter choices and replace any retired icon among the two.
  select coalesce(array_agg(item_id order by position),'{}'::text[]) into kept
  from (select distinct on (c.item_id) c.item_id,a.position
   from public.player_starter_grants g cross join lateral unnest(g.icon_ids) with ordinality a(item_id,position)
   join public.shop_catalog c on c.item_id=a.item_id and c.kind='avatar' and c.active and c.item_id<>'ares-helm'
   where g.player_id=p.id order by c.item_id,a.position limit 2) valid;
  select coalesce(array_agg(item_id),'{}'::text[]) into extra from
   (select item_id from public.shop_catalog where kind='avatar' and active and item_id<>'ares-helm' and not(item_id=any(kept)) order by random() limit greatest(0,2-cardinality(kept))) draw;
  kept:=kept||extra;
  if cardinality(kept)<>2 then raise exception 'É necessário haver pelo menos dois ícones ativos.';end if;
  update public.player_starter_grants set icon_ids=kept where player_id=p.id;
  insert into public.player_inventory(player_id,item_id) select p.id,unnest(kept) on conflict do nothing;
 end loop;
end $repair$;

-- Remove the retired helmet globally. Archive entries before removing access.
insert into public.inventory_icon_repair_backup(player_id,item_id,acquired_at,reason)
select player_id,item_id,acquired_at,'retired-ares-helm' from public.player_inventory where item_id='ares-helm' on conflict do nothing;
delete from public.player_inventory where item_id='ares-helm';

-- Migration 012 granted all chibis BEFORE the recorded starter grant in 013.
-- Purchases after the starter grant, and confirmed code rewards, remain owned.
insert into public.inventory_icon_repair_backup(player_id,item_id,acquired_at,reason)
select i.player_id,i.item_id,i.acquired_at,'legacy-free-chibi-grant'
from public.player_inventory i join public.player_starter_grants g on g.player_id=i.player_id
where not public._inventory_admin(i.player_id) and i.item_id like 'chibi-%'
 and not(i.item_id=any(g.icon_ids)) and i.acquired_at<=g.granted_at
 and not exists(select 1 from public.gift_claims gc join public.redeem_codes rc on rc.code=gc.code where gc.player_id=i.player_id and rc.reward_type='item' and rc.item_id=i.item_id)
on conflict do nothing;
delete from public.player_inventory i using public.player_starter_grants g
where g.player_id=i.player_id and not public._inventory_admin(i.player_id)
 and i.item_id like 'chibi-%' and not(i.item_id=any(g.icon_ids)) and i.acquired_at<=g.granted_at
 and not exists(select 1 from public.gift_claims gc join public.redeem_codes rc on rc.code=gc.code where gc.player_id=i.player_id and rc.reward_type='item' and rc.item_id=i.item_id);

-- Equip a starter portrait if the previous portrait was retired or revoked.
update public.profiles p set equipped_avatar=coalesce(
 (select g.icon_ids[1] from public.player_starter_grants g where g.player_id=p.id),
 (select i.item_id from public.player_inventory i join public.shop_catalog c using(item_id) where i.player_id=p.id and c.kind='avatar' and c.active and c.item_id<>'ares-helm' order by i.item_id limit 1),'default')
where p.equipped_avatar='ares-helm' or (not public._inventory_admin(p.id) and not exists(
 select 1 from public.player_inventory i join public.shop_catalog c using(item_id) where i.player_id=p.id and i.item_id=p.equipped_avatar and c.kind='avatar' and c.active));

-- Prevent future catalog edits or codes from bringing the retired icon back.
create or replace function public._inventory_catalog_price() returns trigger language plpgsql set search_path='' as $$
begin
 if new.item_id='ares-helm' then new.active:=false;end if;
 if new.kind='avatar' then new.price:=500;
 elsif new.kind='card' then new.price:=1000;
  if new.card_id in ('lukyan-rei-de-todos','eclipse-lunar','eclipse-solar') then new.active:=false;end if;
 end if;return new;
end $$;
revoke all on function public._inventory_catalog_price() from public,anon,authenticated;

create or replace function public._inventory_item_received() returns trigger language plpgsql security definer set search_path='' as $$
declare cid text;
begin
 if new.item_id='ares-helm' then raise exception 'Este ícone foi retirado do jogo.';end if;
 select card_id into cid from public.shop_catalog where item_id=new.item_id and kind='card';
 if cid is not null then insert into public.player_card_copies(player_id,card_id,copies) values(new.player_id,cid,1) on conflict do nothing;end if;
 return new;
end $$;
revoke all on function public._inventory_item_received() from public,anon,authenticated;
commit;
