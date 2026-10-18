-- Guardião Nórdico: nova sinergia. Aplicar após as migrações anteriores (018).
begin;
do $patch$
declare signature text;definition text;
old_return text:=$old$return greatest(0,floor(p+coalesce((u->>'powerShift')::numeric,0)));$old$;
new_return text:=$new$p:=greatest(0,floor(p+coalesce((u->>'powerShift')::numeric,0)));
 -- guardian_same_lane_synergy: dobra uma vez, sem acumular por companheiro.
 if id='guardiao-nordico' and exists(select 1 from jsonb_array_elements(coalesce(a->'field','[]'::jsonb)) v
  where v->>'uid' is distinct from u->>'uid' and v->>'cardId'='guardiao-nordico'
  and coalesce((v->>'lane')::integer,0)=coalesce((u->>'lane')::integer,0)) then p:=p*2;end if;
 return p;$new$;
begin
 if to_regprocedure('public._r_power(jsonb,text,jsonb,integer)') is null then raise exception 'Aplique as migrações de habilidades antes do SQL 019.';end if;
 definition:=pg_get_functiondef('public._r_power(jsonb,text,jsonb,integer)'::regprocedure);
 if position('guardian_same_lane_synergy' in definition)=0 then
  if position(old_return in definition)=0 then raise exception 'Regra de poder desconhecida. Nenhuma alteração aplicada.';end if;
  execute replace(definition,old_return,new_return);
 end if;
 foreach signature in array array['public._r_card(text)','public._r_data()'] loop
  if to_regprocedure(signature) is not null then
   definition:=pg_get_functiondef(to_regprocedure(signature));
   execute replace(replace(definition,'As Runas Nórdicas aumentam seu poder enquanto estiver em campo.','Se houver outro Guardião Nórdico aliado na mesma fileira, o poder deste Guardião dobra.'),'Habilidade — Vontade do Norte: recebe o poder concedido pelas Runas Nórdicas quando equipado.','Habilidade — Vontade do Norte: dobra o próprio poder enquanto houver outro Guardião Nórdico aliado na mesma fileira.');
  end if;
 end loop;
end $patch$;
update public.card_lore set ability_title='Vontade do Norte',ability_text='Se houver outro Guardião Nórdico aliado na mesma fileira, o poder deste Guardião dobra.',
 art_url='assets/cards-20261017/guardiao-nordico.png',updated_at=now() where card_id='guardiao-nordico';
notify pgrst,'reload schema';
commit;
