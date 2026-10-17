-- 016: exclusão de baralhos e reorganização dos cinco slots. Aplicar após 015.
begin;
create or replace function public.delete_builder_deck(p_slot integer,p_active_slot integer,p_decks jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();entry jsonb;remaining jsonb:='[]'::jsonb;normalized jsonb;
 title text;deck_count integer;slot_index integer:=0;next_active integer;
begin
 if uid is null then raise exception 'Entre na conta para excluir um baralho.';end if;
 if jsonb_typeof(p_decks) is distinct from 'array' then raise exception 'Lista de baralhos inválida.';end if;
 deck_count:=jsonb_array_length(p_decks);
 if deck_count not between 1 and 5 or p_slot is null or p_slot not between 1 and deck_count
 or p_active_slot is null or p_active_slot not between 1 and deck_count
 then raise exception 'Selecione um slot de baralho válido.';end if;
 perform 1 from public.profiles where id=uid for update;
 if not found then raise exception 'Perfil não encontrado.';end if;
 -- A lista mantém também rascunhos locais. Cada baralho restante é validado
 -- contra a coleção real antes de substituir qualquer montagem salva.
 for entry in select value from jsonb_array_elements(p_decks) loop
   slot_index:=slot_index+1;
   if slot_index=p_slot then continue;end if;
   title:=btrim(coalesce(entry->>'name',''));
   if length(title) not between 1 and 24 then raise exception 'Nome de baralho inválido.';end if;
   perform public._assert_owned_deck(uid,entry->'cards');
   select coalesce(jsonb_object_agg(key,value) filter(where (value::text)::integer>0),'{}'::jsonb)
   into normalized from jsonb_each(entry->'cards');
   remaining:=remaining||jsonb_build_array(jsonb_build_object('name',title,'cards',normalized));
 end loop;
 if jsonb_array_length(remaining)=0 then
   remaining:='[{"name":"Deck 1","cards":{}}]'::jsonb;
 end if;
 next_active:=greatest(1,least(jsonb_array_length(remaining),case when p_active_slot>p_slot then p_active_slot-1 else p_active_slot end));
 delete from public.player_saved_decks where player_id=uid;
 insert into public.player_saved_decks(player_id,slot,name,card_counts,updated_at)
 select uid,ordinality::smallint,value->>'name',value->'cards',now()
 from jsonb_array_elements(remaining) with ordinality;
 insert into public.player_decks(player_id,card_counts,updated_at)
 values(uid,remaining->(next_active-1)->'cards',now())
 on conflict(player_id) do update set card_counts=excluded.card_counts,updated_at=excluded.updated_at;
 return jsonb_build_object('decks',remaining,'activeSlot',next_active-1);
end $$;
revoke all on function public.delete_builder_deck(integer,integer,jsonb) from public,anon;
grant execute on function public.delete_builder_deck(integer,integer,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
