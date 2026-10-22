-- Após 049. Regras iguais no laboratório e nos modos online.
begin;
create or replace function public._x_rule(u jsonb) returns jsonb
language sql stable set search_path='' as $$
 select case when public._r_id(u)='hindu-krishna'
  then '{"op":"aura","faction":"Hindu","amount":1,"unique":true}'::jsonb
  else coalesce(public._r_data()#>array['remakeRules',public._r_id(u)],'{}'::jsonb) end
$$;
update public.card_lore set ability_text='Enquanto Krishna estiver em campo, as outras unidades Hindus aliadas em sua fileira recebem +1 de poder.',art_url='assets/cards-remake/hindu-krishna-v2.png' where card_id='hindu-krishna';
update public.shop_items set description='Enquanto Krishna estiver em campo, as outras unidades Hindus aliadas em sua fileira recebem +1 de poder.',asset_path='assets/cards-remake/hindu-krishna-v2.png' where card_id='hindu-krishna';
update public.shop_items set title=regexp_replace(regexp_replace(title,'^Chibi[ ·—-]+','','i'),'[ ·—-]+Chibi$','','i') where item_id like 'chibi-%';

-- Preserva todos os outros dados do catálogo oficial.
do $$ begin
 if to_regprocedure('public._r_card_v50(text)') is null then alter function public._r_card(text) rename to _r_card_v50;end if;
end $$;
create or replace function public._r_card(cid text) returns jsonb language sql immutable set search_path='' as $$
 select public._r_card_v50(cid)||case when cid='hindu-krishna' then jsonb_build_object(
  'ability','Enquanto Krishna estiver em campo, as outras unidades Hindus aliadas em sua fileira recebem +1 de poder.',
  'art','assets/cards-remake/hindu-krishna-v2.png')
 when cid='asteca-mictlantecuhtli' then '{"subtype":"Deus","characterClass":"Deus"}'::jsonb else '{}'::jsonb end
$$;
revoke all on function public._r_card_v50(text),public._r_card(text) from public,anon,authenticated;

-- Os slots mantêm a semântica: 1/3 equipe um, 2/4 equipe dois.
-- Protege o início da personalizada contra participantes já em outra partida.
do $$ begin
 if to_regprocedure('public._custom_room_start_v50(uuid)') is null then
  alter function public.custom_room_start(uuid) rename to _custom_room_start_v50;
 end if;
end $$;
create or replace function public.custom_room_start(p_room_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare r public.sandbox_rooms%rowtype;participant uuid;
begin
 if auth.uid() is null then raise exception 'Entre na conta para iniciar a sala.';end if;
 select * into r from public.sandbox_rooms where id=p_room_id and host_id=auth.uid() and status='open' for update;
 if not found then raise exception 'Somente o anfitrião pode iniciar uma sala aberta.';end if;
 for participant in select player_id from public.sandbox_room_members where room_id=r.id order by player_id loop
  perform pg_advisory_xact_lock(hashtextextended(participant::text,350));
 end loop;
 if exists(select 1 from public.sandbox_room_members m join public.game_matches g
  on m.player_id in(g.player_one,g.player_two,g.player_three,g.player_four)
  where m.room_id=r.id and g.status='active') then
  raise exception 'Um participante já está em uma partida. Termine-a antes de começar.';
 end if;
 if exists(select 1 from public.sandbox_room_members m join public.guardian_campaign_runs g
  on g.player_id=m.player_id where m.room_id=r.id and g.status='active') then
  raise exception 'Um participante está em um desafio do Atlas. Termine-o antes de começar.';
 end if;
 -- A implementação anterior conserva validação dos decks, regras, equilíbrio,
 -- privacidade das mãos, prontidão após relatório e criação 1x1/2x2.
 return public._custom_room_start_v50(p_room_id);
end $$;
revoke all on function public._custom_room_start_v50(uuid) from public,anon,authenticated;
revoke all on function public.custom_room_start(uuid) from public,anon;
grant execute on function public.custom_room_start(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
