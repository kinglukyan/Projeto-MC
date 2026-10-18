-- Aplicar após 025, antes de publicar as boas-vindas.
begin;
do $prerequisite$
begin
 if to_regprocedure('public._r_gear_compatible(text,jsonb)') is null then raise exception 'Execute o SQL 025 antes do SQL 026.';end if;
end $prerequisite$;
create table if not exists public.player_onboarding(
 player_id uuid primary key references public.profiles(id) on delete cascade,
 stage text not null default 'welcome' check(stage in ('welcome','granted','completed')),
 mythology text check(mythology in ('Grécia','Nórdicos','Egípcios')),
 created_at timestamptz not null default now(),completed_at timestamptz
);
alter table public.player_onboarding enable row level security;
revoke all on public.player_onboarding from public,anon,authenticated;
-- Accounts that already received their gift keep it and are not given another one.
insert into public.player_onboarding(player_id,stage,completed_at)
select player_id,'completed',now() from public.player_starter_grants on conflict do nothing;
do $keep_inventory$
begin
 if to_regprocedure('public._ensure_player_inventory_before_welcome(uuid)') is null then
  alter function public._ensure_player_inventory(uuid) rename to _ensure_player_inventory_before_welcome;
 end if;
end $keep_inventory$;

create or replace function public._ensure_player_inventory(uid uuid) returns void
language plpgsql security definer set search_path='' as $$
declare progress public.player_onboarding%rowtype;
begin
 perform 1 from public.profiles where id=uid for update;if not found then return;end if;
 if public._inventory_admin(uid) then
  perform public._ensure_player_inventory_before_welcome(uid);
  insert into public.player_onboarding(player_id,stage,completed_at) values(uid,'completed',now()) on conflict(player_id) do update set stage='completed',completed_at=coalesce(public.player_onboarding.completed_at,now());
  return;
 end if;
 insert into public.player_onboarding(player_id,stage,completed_at)
 values(uid,case when exists(select 1 from public.player_starter_grants where player_id=uid) then 'completed' else 'welcome' end,
 case when exists(select 1 from public.player_starter_grants where player_id=uid) then now() else null end) on conflict do nothing;
 select * into progress from public.player_onboarding where player_id=uid;
 if progress.stage='welcome' and not exists(select 1 from public.player_starter_grants where player_id=uid) then
  -- Defer only the starter gift until the player chooses a mythology.
  insert into public.player_inventory(player_id,item_id) select uid,item_id from public.shop_catalog where item_id in ('battle-forest','hand-heaven') on conflict do nothing;
  return;
 end if;
 perform public._ensure_player_inventory_before_welcome(uid);
end $$;
revoke all on function public._ensure_player_inventory(uuid),public._ensure_player_inventory_before_welcome(uuid) from public,anon,authenticated;

create or replace function public._inventory_profile_created() returns trigger language plpgsql security definer set search_path='' as $$
begin perform public._ensure_player_inventory(new.id);return new;end $$;
revoke all on function public._inventory_profile_created() from public,anon,authenticated;
create or replace function public.sync_player_entitlements() returns void language plpgsql security definer set search_path='' as $$
begin if auth.uid() is null then raise exception 'Entre na conta.';end if;perform public._ensure_player_inventory(auth.uid());end $$;
revoke all on function public.sync_player_entitlements() from public,anon;
grant execute on function public.sync_player_entitlements() to authenticated;

create or replace function public._starter_avatar_faction(item_id text) returns text
language sql stable set search_path='' as $$
 select case when item_id like 'chibi-%' then public._r_card(substr(item_id,7))->>'faction' end;
$$;
revoke all on function public._starter_avatar_faction(text) from public,anon,authenticated;

create or replace function public.get_welcome_state() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();progress public.player_onboarding%rowtype;gift public.player_starter_grants%rowtype;
begin
 if uid is null then raise exception 'Entre na conta para iniciar sua jornada.';end if;
 perform public._ensure_player_inventory(uid);
 select * into progress from public.player_onboarding where player_id=uid;
 if not found then raise exception 'Seu perfil ainda está sendo preparado. Tente novamente.';end if;
 select * into gift from public.player_starter_grants where player_id=uid;
 return jsonb_build_object('stage',progress.stage,'mythology',progress.mythology,'card_ids',coalesce(to_jsonb(gift.card_ids),'[]'::jsonb),'icon_ids',coalesce(to_jsonb(gift.icon_ids),'[]'::jsonb));
end $$;
revoke all on function public.get_welcome_state() from public,anon;
grant execute on function public.get_welcome_state() to authenticated;

create or replace function public.open_starter_pack(p_mythology text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();progress public.player_onboarding%rowtype;chosen text[]:='{}';extra text[];icons text[];local_id text;terrain_id text;first_icon text;second_icon text;counts jsonb;
begin
 if uid is null then raise exception 'Entre na conta para receber seu pacote.';end if;
 if p_mythology is null or p_mythology not in ('Grécia','Nórdicos','Egípcios') then raise exception 'Escolha uma das mitologias disponíveis.';end if;
 perform 1 from public.profiles where id=uid for update;if not found then raise exception 'Perfil indisponível.';end if;
 perform public._ensure_player_inventory(uid);
 select * into progress from public.player_onboarding where player_id=uid for update;
 -- The same account always receives the original receipt, even after retries or a different choice.
 if progress.stage<>'welcome' or exists(select 1 from public.player_starter_grants where player_id=uid) then return public.get_welcome_state();end if;

 -- Six units from the selected mythology, then four other units: ten characters total.
 select coalesce(array_agg(card_id),'{}'::text[]) into chosen from (
  select distinct c.card_id from public.shop_catalog c where c.kind='card' and c.active and c.card_id is not null
   and public._r_card(c.card_id)->>'kind'='unit' and not coalesce((public._r_card(c.card_id)->>'specialOnly')::boolean,false)
   and public._r_card(c.card_id)->>'faction'=p_mythology
 ) candidates where true;
 select coalesce(array_agg(card_id),'{}'::text[]) into chosen from (select card_id from unnest(chosen) card_id order by random() limit 6) preferred;
 if cardinality(chosen)<>6 then raise exception 'Esta mitologia precisa de pelo menos seis unidades disponíveis no catálogo.';end if;
 select coalesce(array_agg(card_id),'{}'::text[]) into extra from (
  select card_id from (select distinct c.card_id from public.shop_catalog c where c.kind='card' and c.active and c.card_id is not null and not(c.card_id=any(chosen))
   and public._r_card(c.card_id)->>'kind'='unit' and not coalesce((public._r_card(c.card_id)->>'specialOnly')::boolean,false)) available order by random() limit 4
 ) other_units;chosen:=chosen||extra;

 -- A matching Local and Terrain make the preferred mythology playable from the beginning.
 select c.card_id into local_id from public.shop_catalog c where c.kind='card' and c.active and public._r_card(c.card_id)->>'kind'='location' and public._r_card(c.card_id)->>'faction'=p_mythology order by random() limit 1;
 select c.card_id into terrain_id from public.shop_catalog c where c.kind='card' and c.active and public._r_card(c.card_id)->>'kind'='terrain' and public._r_card(c.card_id)->>'faction'=p_mythology order by random() limit 1;
 if local_id is null or terrain_id is null then raise exception 'Esta mitologia precisa de Local e Terreno disponíveis.';end if;
 chosen:=chosen||array[local_id,terrain_id];
 -- Only include equipment for which the starter units have a valid wearer.
 select coalesce(array_agg(card_id),'{}'::text[]) into extra from (
  select card_id from (select distinct c.card_id from public.shop_catalog c where c.kind='card' and c.active and c.card_id is not null and not(c.card_id=any(chosen))
   and public._r_card(c.card_id)->>'kind'<>'unit' and not coalesce((public._r_card(c.card_id)->>'specialOnly')::boolean,false)
   and (public._r_card(c.card_id)->>'kind'<>'equipment' or exists(select 1 from unnest(chosen) wearer where public._r_gear_compatible(c.card_id,jsonb_build_object('cardId',wearer))))
  ) available order by random() limit 2
 ) other_cards;chosen:=chosen||extra;
 select c.item_id into first_icon from public.shop_catalog c where c.kind='avatar' and c.active and c.item_id<>'ares-helm' and public._starter_avatar_faction(c.item_id)=p_mythology order by random() limit 1;
 select c.item_id into second_icon from public.shop_catalog c where c.kind='avatar' and c.active and c.item_id<>'ares-helm' and public._starter_avatar_faction(c.item_id) in ('Grécia','Nórdicos','Egípcios') and public._starter_avatar_faction(c.item_id)<>p_mythology order by random() limit 1;
 icons:=array[first_icon,second_icon];
 if cardinality(chosen)<>14 or first_icon is null or second_icon is null or (select count(distinct id) from unnest(chosen) id)<>14 then raise exception 'Catálogo insuficiente para completar seu presente inicial.';end if;

 insert into public.player_starter_grants(player_id,card_ids,icon_ids) values(uid,chosen,icons);
 insert into public.player_card_copies(player_id,card_id,copies) select uid,unnest(chosen),1 on conflict(player_id,card_id) do update set copies=public.player_card_copies.copies+1;
 insert into public.player_inventory(player_id,item_id) select uid,unnest(icons) on conflict do nothing;
 insert into public.player_inventory(player_id,item_id) select uid,c.item_id from public.shop_catalog c where c.kind='card' and c.card_id=any(chosen) on conflict do nothing;
 update public.profiles set equipped_avatar=first_icon,settings=coalesce(settings,'{}'::jsonb)||jsonb_build_object('preferred_mythology',p_mythology) where id=uid;
 select jsonb_object_agg(id,1) into counts from unnest(chosen) id;
 insert into public.player_decks(player_id,card_counts) values(uid,counts) on conflict do nothing;
 insert into public.player_saved_decks(player_id,slot,name,card_counts) values(uid,1,'Primeiro baralho',counts) on conflict(player_id,slot) do nothing;
 update public.player_onboarding set stage='granted',mythology=p_mythology where player_id=uid;
 return public.get_welcome_state();
end $$;
revoke all on function public.open_starter_pack(text) from public,anon;
grant execute on function public.open_starter_pack(text) to authenticated;

create or replace function public.complete_welcome() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();progress public.player_onboarding%rowtype;
begin
 if uid is null then raise exception 'Entre na conta.';end if;
 perform 1 from public.profiles where id=uid for update;
 select * into progress from public.player_onboarding where player_id=uid for update;
 if progress.stage is null or progress.stage='welcome' then raise exception 'Receba seu pacote inicial antes de montar o baralho.';end if;
 update public.player_onboarding set stage='completed',completed_at=coalesce(completed_at,now()) where player_id=uid;
 return public.get_welcome_state();
end $$;
revoke all on function public.complete_welcome() from public,anon;
grant execute on function public.complete_welcome() to authenticated;
notify pgrst,'reload schema';
commit;
