-- Aplicar após 023. Bônus de grupo por fileira e aura contínua de Apolo.
begin;
create or replace function public._r_power(s jsonb,t text,u jsonb,depth integer default 0)
returns numeric language plpgsql stable set search_path='' as $$
declare c jsonb:=public._r_card(u->>'cardId'); a jsonb:=s->t; id text:=public._r_id(u); p numeric:=coalesce((c->>'power')::numeric,0); n integer; item jsonb; gear text; r jsonb; climate text:=s#>>'{sharedZones,climate}'; enemy numeric;
begin
 if not public._r_live(s) then return p;end if;
 p:=coalesce((u->>'copiedPower')::numeric,p)+coalesce((u->>'bonus')::numeric,0);
 if id='hercules' then p:=p+least(12,coalesce((u->>'progress')::integer,0));end if;
 for gear in select jsonb_array_elements_text(coalesce(u->'equipment','[]'::jsonb)) loop if public._r_equip(gear,u) then p:=p+coalesce((public._r_data()#>>array['equipment',gear,'bonus'])::integer,0);end if;end loop;
 if id='soldado-esparta' then select count(*)::integer into n from jsonb_array_elements(a->'field') v where v->>'cardId'='soldado-esparta' and v->>'uid'<>u->>'uid' and v->>'lane'=u->>'lane';p:=p*power(2::numeric,n);end if;
 if id='lobo-alfa' then p:=p+2*(select count(*) from jsonb_array_elements(a->'field') v where v->>'cardId'='lobo-beta' and v->>'lane'=u->>'lane');end if;
 p:=p+2*(select count(*) from jsonb_array_elements(a->'field') v where v->>'uid'<>u->>'uid' and public._r_id(v)='athena' and (v->>'lane')::integer=(u->>'lane')::integer);
 if id='lobo-omega' and depth=0 and (select count(*) from jsonb_array_elements(a->'field') v where v->>'lane'=u->>'lane')=1 then
  select coalesce(sum(public._r_power(s,public._r_other(t),v,1)),0) into enemy from jsonb_array_elements(coalesce(s#>array[public._r_other(t),'field'],'[]'::jsonb)) v where v->>'lane'=u->>'lane';if enemy>p then p:=p+8;end if;
 end if;
 if id in ('mulher','homem') then select count(*)::integer into n from jsonb_array_elements(a->'field') v where v->>'cardId'='homem' and v->>'lane'=u->>'lane' and (id='mulher' or v->>'uid'<>u->>'uid');p:=p*power(2::numeric,n);end if;
 p:=p*coalesce((u->>'multiplier')::numeric,1);
 p:=p*power(2::numeric,(select count(*) from jsonb_array_elements(a->'field') v where public._r_id(v)='apolo' and v->>'lane'=u->>'lane'));
 if not public._r_protect(s,t,(u->>'lane')::integer,coalesce(s#>>'{zoneOwners,local}',t)) and public._r_data()#>>array['locations',s#>>'{sharedZones,local}']=c->>'faction' then p:=p+2;end if;
 if not public._r_protect(s,t,(u->>'lane')::integer,coalesce(s#>>'{zoneOwners,terrain}',t)) then p:=p+public._terrain_bonus(s#>>'{sharedZones,terrain}',u->>'cardId');end if;
 if c->>'faction'='Grécia' then p:=p+coalesce((a->>'greekAura')::numeric,0);end if;if c->>'faction'='Nórdicos' then p:=p+coalesce((a->>'norseAura')::numeric,0);end if;
 if id='lukyan-rei-de-todos' then p:=p*power(2::numeric,greatest(0,(select count(*) from jsonb_array_elements(a->'field') v where v->>'lane'=u->>'lane')-1));end if;
 if not public._r_protect(s,t,(u->>'lane')::integer,coalesce(s#>>'{zoneOwners,climate}',t)) then
  if climate='eclipse-lunar' then if u->>'cardId' in ('lobo-alfa','lobo-beta','lobo-omega','artemis') or public._eclipse_is_vampire(u->>'cardId') then p:=p*2;end if;if u->>'cardId' in ('apolo','ra') then p:=floor(p/2);end if;
  elsif climate='eclipse-solar' then if u->>'cardId' in ('apolo','ra') then p:=p*2;end if;if u->>'cardId'='artemis' then p:=floor(p/2);end if;end if;
 end if;
 p:=greatest(0,floor(p+coalesce((u->>'powerShift')::numeric,0)));
 -- guardian_same_lane_synergy: dobra uma vez, sem acumular por companheiro.
 if id='guardiao-nordico' and exists(select 1 from jsonb_array_elements(coalesce(a->'field','[]'::jsonb)) v
  where v->>'uid' is distinct from u->>'uid' and v->>'cardId'='guardiao-nordico'
  and coalesce((v->>'lane')::integer,0)=coalesce((u->>'lane')::integer,0)) then p:=p*2;end if;
 return p;
end; $$;
create or replace function public._r_round_end(s jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare x jsonb:=jsonb_build_object('s',s,'r','{}'::jsonb);t text;u jsonb;v jsonb;
begin
 if s->>'endEffectsRound'=s->>'round' then return s;end if;
 if public._r_live(s) then foreach t in array array['player_one','player_two'] loop for u in select value from jsonb_array_elements(s#>array[t,'field']) loop
  if public._r_id(u)='ra' then for v in select value from jsonb_array_elements(x#>array['s',t,'field']) where public._r_card(value->>'cardId')->>'faction'='Egípcios' and value->>'lane'=u->>'lane' loop x:=public._r_change(x,t,v->>'uid',t,1);end loop;end if;
  if public._r_id(u)='hercules' then v:=public._r_unit(x->'s',t,u->>'uid');v:=jsonb_set(v,'{progress}',to_jsonb(least(12,coalesce((v->>'progress')::integer,0)+1)),true);x:=public._r_set_unit(x,t,u->>'uid',v);end if;
 end loop;end loop;end if;return jsonb_set(x->'s','{endEffectsRound}',s->'round',true);
end; $$;
do $patch$
declare definition text;old_text text;new_text text;
begin
 definition:=pg_get_functiondef('public._r_resolve(jsonb,jsonb)'::regprocedure);
 old_text:=$old$when 'double_lane' then for v in select value from jsonb_array_elements(x#>array['s',t,'field']) where (value->>'lane')::integer=lane loop x:=public._r_change(x,t,v->>'uid',t,0,2);end loop;$old$;
 new_text:=$new$when 'double_lane' then null; -- row_apolo_aura_v24$new$;
 if position(new_text in definition)=0 then
  if position(old_text in definition)=0 then raise exception 'Resolução de bônus desconhecida; nenhuma alteração aplicada.';end if;
  definition:=replace(definition,old_text,new_text);
 end if;
 old_text:=$old$when 'war_buff' then for v in select value from jsonb_array_elements(x#>array['s',t,'field']) loop g:=public._r_card(v->>'cardId');amount:=case when (g->'tags') ? 'espartano' or v->>'cardId'='leonidas' then 2 when g->>'faction'='Grécia' then 1 else 0 end;x:=public._r_change(x,t,v->>'uid',t,amount);end loop;$old$;
 new_text:=$new$when 'war_buff' then for v in select value from jsonb_array_elements(x#>array['s',t,'field']) where (value->>'lane')::integer=lane loop g:=public._r_card(v->>'cardId');amount:=case when (g->'tags') ? 'espartano' or v->>'cardId'='leonidas' then 2 when g->>'faction'='Grécia' then 1 else 0 end;x:=public._r_change(x,t,v->>'uid',t,amount);end loop;$new$;
 if position(new_text in definition)=0 then
  if position(old_text in definition)=0 then raise exception 'Resolução de bônus desconhecida; nenhuma alteração aplicada.';end if;
  definition:=replace(definition,old_text,new_text);
 end if;
 execute definition;
end $patch$;
update public.card_lore set ability_text='Cada outro Soldado de Esparta aliado na mesma fileira dobra o poder desta carta. O efeito é recíproco e acumulativo.',updated_at=now() where card_id='soldado-esparta';
update public.card_lore set ability_text='Recebe +2 de poder por Lobisomem Beta aliado na mesma fileira.',updated_at=now() where card_id='lobo-alfa';
update public.card_lore set ability_text='Cada outro Homem aliado na mesma fileira dobra seu poder. No Eclipse Lunar, Homem da facção Monstros vira Lobisomem Beta; fora do Lunar, recupera sua forma original.',updated_at=now() where card_id='homem';
update public.card_lore set ability_text='Cada Homem aliado na mesma fileira dobra seu poder. No Eclipse Lunar, Mulher da facção Monstros vira Lobisomem Alfa; fora do Lunar, recupera sua forma original.',updated_at=now() where card_id='mulher';
update public.card_lore set ability_text='Enquanto Apolo estiver em campo, dobra o poder de todas as cartas aliadas na sua fileira, incluindo ele próprio e as que entrarem depois.',updated_at=now() where card_id='apolo';
update public.card_lore set ability_text='Com Excalibur, seu poder dobra por cada outro aliado na mesma fileira. Esta forma só aparece pela transformação de Lukyan.',updated_at=now() where card_id='lukyan-rei-de-todos';
update public.card_lore set ability_text='Ao entrar, concede +2 aos espartanos e a Leônidas e +1 aos demais gregos aliados na mesma fileira.',updated_at=now() where card_id='ares';
update public.card_lore set ability_text='No fim da rodada, concede +1 de poder a cada egípcio aliado na mesma fileira.',updated_at=now() where card_id='ra';
revoke all on function public._r_power(jsonb,text,jsonb,integer),public._r_round_end(jsonb),public._r_resolve(jsonb,jsonb) from public,anon,authenticated;
create or replace function public._eclipse_power(p_side jsonb,p_unit jsonb,p_power integer,p_climate text)
returns integer language plpgsql immutable set search_path='' as $$
declare cid text:=p_unit->>'cardId'; total integer:=greatest(0,p_power); men integer;
begin
 if cid in ('mulher','homem') then
  select count(*)::integer into men from jsonb_array_elements(coalesce(p_side->'field','[]'::jsonb)) a(value) where a.value->>'cardId'='homem' and a.value->>'lane'=p_unit->>'lane';
  total:=total*(2^greatest(0,men-case when cid='homem' then 1 else 0 end))::integer;
 end if;
 if p_climate='eclipse-lunar' then
  if cid in ('lobo-alfa','lobo-beta','lobo-omega','artemis') or public._eclipse_is_vampire(cid) then total:=total*2;end if;
  if cid in ('apolo','ra') then total:=total/2;end if;
 elsif p_climate='eclipse-solar' then
  if cid in ('apolo','ra') then total:=total*2;end if;
  if cid='artemis' then total:=total/2;end if;
 end if;
 return greatest(0,total);
end;
$$;
revoke all on function public._eclipse_power(jsonb,jsonb,integer,text) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
