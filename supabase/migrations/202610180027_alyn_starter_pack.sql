-- 027: símbolos e Reino de Alyn. Aplicar após SQL 026.
begin;
do $$begin if to_regprocedure('public.open_starter_pack(text)') is null then raise exception 'Execute o SQL 026 antes do SQL 027.';end if;end $$;
alter table public.player_onboarding drop constraint if exists player_onboarding_mythology_check;
alter table public.player_onboarding add constraint player_onboarding_mythology_check check(mythology in ('Grécia','Nórdicos','Egípcios','Alyns'));
create or replace function public.open_starter_pack(p_mythology text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();progress public.player_onboarding%rowtype;chosen text[]:='{}';extra text[];icons text[];local_id text;terrain_id text;first_icon text;second_icon text;counts jsonb;
begin
 if uid is null then raise exception 'Entre na conta para receber seu pacote.';end if;
 if p_mythology is null or p_mythology not in ('Grécia','Nórdicos','Egípcios','Alyns') then raise exception 'Escolha uma das mitologias disponíveis.';end if;
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
 if cardinality(chosen)=0 then raise exception 'Esta mitologia ainda não tem unidades disponíveis no catálogo.';end if;
 select coalesce(array_agg(card_id),'{}'::text[]) into extra from (
  select card_id from (select distinct c.card_id from public.shop_catalog c where c.kind='card' and c.active and c.card_id is not null and not(c.card_id=any(chosen))
   and public._r_card(c.card_id)->>'kind'='unit' and not coalesce((public._r_card(c.card_id)->>'specialOnly')::boolean,false)) available order by random() limit (10-cardinality(chosen))
 ) other_units;chosen:=chosen||extra;

 -- A matching Local and Terrain make the preferred mythology playable from the beginning.
 select c.card_id into local_id from public.shop_catalog c where c.kind='card' and c.active and public._r_card(c.card_id)->>'kind'='location' and public._r_card(c.card_id)->>'faction'=p_mythology order by random() limit 1;
 select c.card_id into terrain_id from public.shop_catalog c where c.kind='card' and c.active and public._r_card(c.card_id)->>'kind'='terrain' and public._r_card(c.card_id)->>'faction'=p_mythology order by random() limit 1;
 chosen:=chosen||array_remove(array[local_id,terrain_id],null);
 -- Only include equipment for which the starter units have a valid wearer.
 select coalesce(array_agg(card_id),'{}'::text[]) into extra from (
  select card_id from (select distinct c.card_id from public.shop_catalog c where c.kind='card' and c.active and c.card_id is not null and not(c.card_id=any(chosen))
   and public._r_card(c.card_id)->>'kind'<>'unit' and not coalesce((public._r_card(c.card_id)->>'specialOnly')::boolean,false)
   and (public._r_card(c.card_id)->>'kind'<>'equipment' or exists(select 1 from unnest(chosen) wearer where public._r_gear_compatible(c.card_id,jsonb_build_object('cardId',wearer))))
  ) available order by random() limit (14-cardinality(chosen))
 ) other_cards;chosen:=chosen||extra;
 select c.item_id into first_icon from public.shop_catalog c where c.kind='avatar' and c.active and c.item_id<>'ares-helm' and public._starter_avatar_faction(c.item_id)=p_mythology order by random() limit 1;
 select c.item_id into second_icon from public.shop_catalog c where c.kind='avatar' and c.active and c.item_id<>'ares-helm' and public._starter_avatar_faction(c.item_id) in ('Grécia','Nórdicos','Egípcios','Alyns') and public._starter_avatar_faction(c.item_id)<>p_mythology order by random() limit 1;
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
notify pgrst,'reload schema';
commit;
