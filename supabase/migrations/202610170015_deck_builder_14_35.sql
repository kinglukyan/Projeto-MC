-- 015: construtor de baralhos. Aplicar depois das migrações 013 e 014.
begin;

create or replace function public._assert_owned_deck(uid uuid,counts jsonb)
returns void language plpgsql security definer set search_path='' as $$
begin
 if jsonb_typeof(counts) is distinct from 'object' then raise exception 'Baralho inválido.';end if;
 if exists(select 1 from jsonb_each(counts) e
   left join public.player_card_copies p on p.player_id=uid and p.card_id=e.key
   where jsonb_typeof(e.value)<>'number' or e.value::text !~ '^[0-9]{1,2}$'
   or case when e.value::text ~ '^[0-9]{1,2}$' then
     (e.value::text)::integer>coalesce(p.copies,0)
     or ((e.value::text)::integer>0 and
       (public._r_card(e.key)='{}'::jsonb or coalesce((public._r_card(e.key)->>'specialOnly')::boolean,false)))
   else false end)
 then raise exception 'Este baralho usa cartas ou cópias que você ainda não tem.';end if;
 if (select coalesce(sum((value::text)::integer),0) from jsonb_each(counts))>35
 then raise exception 'O baralho aceita no máximo 35 cartas.';end if;
end $$;
revoke all on function public._assert_owned_deck(uuid,jsonb) from public,anon,authenticated;

create or replace function public._assert_match_inventory(uid uuid)
returns void language plpgsql security definer set search_path='' as $$
declare counts jsonb;total integer;
begin
 select card_counts into counts from public.player_decks where player_id=uid;
 perform public._assert_owned_deck(uid,counts);
 select coalesce(sum((value::text)::integer),0) into total from jsonb_each(counts);
 if total not between 14 and 35 then raise exception 'Monte um baralho de 14 a 35 cartas da sua coleção.';end if;
end $$;
revoke all on function public._assert_match_inventory(uuid) from public,anon,authenticated;

-- Salva o slot e o baralho ativo na mesma transação, usando a coleção do servidor.
create or replace function public.save_builder_deck(p_slot integer,p_name text,p_cards jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();title text;total integer;normalized jsonb;
begin
 if uid is null then raise exception 'Entre na conta para salvar o baralho.';end if;
 if p_slot is null or p_slot not between 1 and 5 then raise exception 'Slot de baralho inválido.';end if;
 title:=btrim(coalesce(p_name,''));
 if length(title) not between 1 and 24 then raise exception 'Use um nome de 1 a 24 caracteres.';end if;
 perform 1 from public.profiles where id=uid for update;
 if not found then raise exception 'Perfil não encontrado.';end if;
 perform public._assert_owned_deck(uid,p_cards);
 select coalesce(sum((value::text)::integer),0),
   coalesce(jsonb_object_agg(key,value) filter(where (value::text)::integer>0),'{}'::jsonb)
 into total,normalized from jsonb_each(p_cards);
 if total not between 14 and 35 then raise exception 'O baralho precisa ter de 14 a 35 cartas.';end if;
 insert into public.player_saved_decks(player_id,slot,name,card_counts,updated_at)
 values(uid,p_slot,title,normalized,now()) on conflict(player_id,slot)
 do update set name=excluded.name,card_counts=excluded.card_counts,updated_at=excluded.updated_at;
 insert into public.player_decks(player_id,card_counts,updated_at)
 values(uid,normalized,now()) on conflict(player_id)
 do update set card_counts=excluded.card_counts,updated_at=excluded.updated_at;
 return jsonb_build_object('slot',p_slot,'name',title,'total',total);
end $$;
revoke all on function public.save_builder_deck(integer,text,jsonb) from public,anon;
grant execute on function public.save_builder_deck(integer,text,jsonb) to authenticated;

-- Ajusta somente limites dos construtores existentes, preservando as habilidades.
do $limits$
declare routine regprocedure;definition text;updated text;
begin
 foreach routine in array array[
   to_regprocedure('public._new_online_game_state(uuid,uuid)'),
   to_regprocedure('public._new_online_duo_state(uuid,uuid,uuid,uuid)'),
   to_regprocedure('public.create_sandbox_room(jsonb)'),
   to_regprocedure('public.start_sandbox_match(uuid)')
 ] loop
   if routine is null then raise exception 'Uma função de partidas está ausente. Aplique as migrações anteriores ao SQL 015.';end if;
   definition:=pg_get_functiondef(routine);
   updated:=regexp_replace(definition,'between[[:space:]]+12[[:space:]]+and[[:space:]]+20','between 14 and 35','gi');
   updated:=replace(updated,'12 e 20 cartas','14 e 35 cartas');
   updated:=replace(updated,'^(0|[1-9]|1[0-9]|20)$','^(0|[1-9]|[12][0-9]|3[0-5])$');
   updated:=replace(updated,'(p_rules->>''max_cards'')::integer,20','(p_rules->>''max_cards'')::integer,35');
   updated:=replace(updated,'(room.rules->>''max_cards'')::integer,20','(room.rules->>''max_cards'')::integer,35');
   if updated<>definition then execute updated;end if;
 end loop;
end $limits$;

-- Presentes e expedições também respeitam o mínimo do baralho ativo.
do $minimum$
declare routine regprocedure;definition text;updated text;
begin
 routine:=to_regprocedure('public.send_friend_card_gift(uuid,text)');
 if routine is not null then
   definition:=pg_get_functiondef(routine);
   updated:=regexp_replace(definition,'(jsonb_each_text\(card_counts\)\))[[:space:]]*>[[:space:]]*12','\1>14','g');
   if updated<>definition then execute updated;end if;
 end if;
 routine:=to_regprocedure('public.start_player_expedition(text,integer)');
 if routine is not null then
   definition:=pg_get_functiondef(routine);
   updated:=regexp_replace(definition,'deck_size[[:space:]]*<=[[:space:]]*12','deck_size<=14','gi');
   updated:=replace(updated,'at least 12 cards','at least 14 cards');
   if updated<>definition then execute updated;end if;
 end if;
end $minimum$;

notify pgrst,'reload schema';
commit;
