-- 040: Character collection imported from the owner's finished card exports.
-- Runs after migration 039. Does not change existing decks or reset inventories.
begin;
__CATALOG__

create or replace function public._x_rule(u jsonb) returns jsonb language sql stable set search_path='' as $$ select coalesce(public._r_data()#>array['remakeRules',public._r_id(u)],'{}'::jsonb) $$;
create or replace function public._x_room(s jsonb,t text,l integer) returns boolean language sql stable set search_path='' as $$ select (select count(*) from jsonb_array_elements(coalesce(s#>array[t,'field'],'[]'::jsonb)) v where (v->>'lane')::integer=l)<coalesce((s->>'rowCapacity')::integer,2147483647) $$;
create or replace function public._x_bonus(s jsonb,t text,u jsonb)
returns numeric language plpgsql stable set search_path='' as $$
declare
 r jsonb:=public._x_rule(u);
 c jsonb:=public._r_card(public._r_identity(u));
 ally_unit jsonb;
 aura_rule jsonb;
 bonus_total numeric:=0;
 seen_abilities text[]:='{}';
begin
 if public._r_active(s,t,u) and r->>'op'='company' and (
  select count(*) from jsonb_array_elements(s#>array[t,'field']) as company_rows(unit_data)
  where company_rows.unit_data->>'uid'<>u->>'uid'
   and company_rows.unit_data->>'lane'=u->>'lane'
   and public._r_card(public._r_identity(company_rows.unit_data))->>'faction'=r->>'faction'
 )>=coalesce((r->>'count')::integer,1) then
  bonus_total:=bonus_total+(r->>'amount')::numeric;
 end if;

 if public._r_active(s,t,u) and r->>'op'='graveGrowth' then
  bonus_total:=bonus_total+floor((
   select count(*) from jsonb_array_elements(s#>array[t,'grave']) as grave_rows(unit_data)
   where grave_rows.unit_data->>'owner'=u->>'playedBy'
    and public._r_card(grave_rows.unit_data->>'cardId')->>'kind'='unit'
  )/(r->>'every')::numeric);
 end if;

 for ally_unit in
  select field_rows.unit_data from jsonb_array_elements(s#>array[t,'field']) as field_rows(unit_data)
  where field_rows.unit_data->>'uid'<>u->>'uid' and field_rows.unit_data->>'lane'=u->>'lane'
 loop
  if not public._r_active(s,t,ally_unit) then continue;end if;
  aura_rule:=public._x_rule(ally_unit);
  if aura_rule->>'faction' is distinct from c->>'faction' then continue;end if;
  if aura_rule->>'op'='aura' and (
   not coalesce((aura_rule->>'unique')::boolean,false)
   or not(public._r_id(ally_unit)=any(seen_abilities))
  ) then
   bonus_total:=bonus_total+(aura_rule->>'amount')::numeric;
   seen_abilities:=array_append(seen_abilities,public._r_id(ally_unit));
  end if;
  if aura_rule->>'op'='equipmentAura' then
   bonus_total:=bonus_total+least((aura_rule->>'max')::integer,
    jsonb_array_length(coalesce(u->'equipment','[]'))+jsonb_array_length(coalesce(u->'copiedEquipment','[]')));
  end if;
  if aura_rule->>'op'='occupiedAura' then
   bonus_total:=bonus_total+(
    select count(distinct occupied_rows.unit_data->>'lane')
    from jsonb_array_elements(s#>array[t,'field']) as occupied_rows(unit_data)
   );
  end if;
 end loop;
 return bonus_total;
end $$;
create or replace function public._x_block(s jsonb,t text,u jsonb,src text,k text) returns boolean language plpgsql stable set search_path='' as $$
declare v jsonb;r jsonb;
begin
 if u is null or src=t then return false;end if;if public._r_protect(s,t,(u->>'lane')::integer,src) then return true;end if;
 if u ? 'guardOwner' and k in ('destroy','steal') then return true;end if;
 for v in select value from jsonb_array_elements(s#>array[t,'field']) where value->>'lane'=u->>'lane' loop
  if not public._r_active(s,t,v) then continue;end if;r:=public._x_rule(v);if v->>'uid'=u->>'uid' and r->>'op'<>'protectMove' then continue;end if;
  if k='move' and r->>'op'='protectMove' then return true;end if;
  if r->>'faction'=public._r_card(public._r_identity(u))->>'faction' and ((k='destroy' and r->>'op'='protectDestroy') or (k='reduce' and r->>'op'='protectReduction')) then return true;end if;
 end loop;return false;
end $$;
create or replace function public._x_grave_ok(x jsonb,e jsonb,g jsonb,revive boolean default true) returns boolean language sql stable set search_path='' as $$
 select coalesce((g->>'lockedRound')::integer,0)<>coalesce((x#>>'{s,round}')::integer,1) and (not revive or not exists(select 1 from jsonb_array_elements(x#>array['s',public._r_other(e->>'team'),'field']) v where v->>'lane'=e->>'lane' and public._x_rule(v)->>'op'='blockRevive' and public._r_active(x->'s',public._r_other(e->>'team'),v))) $$;
create or replace function public._x_clean(u jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare k text;n numeric;
begin foreach k in array array['bonus','powerShift','copyOffset','reviveOffset'] loop n:=coalesce((u->>k)::numeric,0);if n<0 then u:=jsonb_set(u,array[k],'0'::jsonb);end if;end loop;if coalesce((u->>'multiplier')::numeric,1)<1 then u:=jsonb_set(u,'{multiplier}','1'::jsonb);end if;return u;end $$;
create or replace function public._x_unsilence(s jsonb,u jsonb) returns jsonb language sql immutable set search_path='' as $$ select (u-'silencedJogadas'-'silencedOwnerEnd')||jsonb_build_object('silenceExemptStamp',s->'silenceStartedBy') $$;
create or replace function public._x_draw(x jsonb,e jsonb,n integer default 1) returns jsonb language plpgsql immutable set search_path='' as $$
declare i integer;deck jsonb;hand jsonb;owner_id text:=e->>'owner';
begin deck:=coalesce(x#>array['r',owner_id,'deck'],'[]');hand:=coalesce(x#>array['r',owner_id,'hand'],'[]');for i in 1..n loop exit when jsonb_array_length(deck)=0;hand:=hand||jsonb_build_array(deck->0);deck:=deck-0;end loop;x:=jsonb_set(x,array['r',owner_id,'deck'],deck,true);return jsonb_set(x,array['r',owner_id,'hand'],hand,true);end $$;
create or replace function public._x_next(x jsonb,e jsonb,extra jsonb) returns jsonb language sql immutable set search_path='' as $$ select public._r_evt(x,(e-'selection')||extra||jsonb_build_object('op','remake')) $$;
create or replace function public._x_quiet(x jsonb,cid text,t text,owner_id text,l integer,token boolean default false) returns jsonb language plpgsql volatile set search_path='' as $$
declare queue jsonb:=coalesce(x#>'{s,effectQueue}','[]');u jsonb;
begin
 if not public._x_room(x->'s',t,l) then return x;end if;
 if token then u:=jsonb_build_object('uid',gen_random_uuid()::text,'cardId',cid,'playedBy',owner_id,'lane',l,'slot',jsonb_array_length(x#>array['s',t,'field']),'bonus',0,'multiplier',1,'equipment','[]'::jsonb,'progress',0,'token',true);x:=jsonb_set(x,array['s',t,'field'],(x#>array['s',t,'field'])||jsonb_build_array(u),true);x:=public._r_visual(x,'enter',t,jsonb_build_array(u->>'uid'));
 else x:=public._r_spawn(x,cid,t,owner_id,l,0);end if;
 x:=jsonb_set(x,'{s,effectQueue}',queue,true);return public._r_reconcile(x);
end $$;

create or replace function public._x_options(x jsonb,e jsonb) returns jsonb language plpgsql stable set search_path='' as $$
declare t text:=e->>'team';enemy text:=public._r_other(t);u jsonb:=public._r_unit(x->'s',t,e->>'uid');r jsonb:=coalesce(e->'rule',public._x_rule(u));op text:=r->>'op';phase text:=e->>'phase';result jsonb:='[]';v jsonb;c jsonb;g jsonb;list jsonb;team text;id text;p numeric;mn numeric;k text;i integer;l integer;allowed boolean;
begin
 if phase='finish' then return jsonb_build_array(public._r_option('confirm','Continuar a partida'));end if;
 if phase='lane' then v:=public._r_unit(x->'s',e->>'targetTeam',e->>'targetUid');if v is null then return result;end if;for i in 0..2 loop if i<>(v->>'lane')::integer and public._x_room(x->'s',e->>'targetTeam',i) then result:=result||jsonb_build_array(public._r_option(i::text,'Fileira '||(i+1)::text));end if;end loop;return result;end if;
 if phase in ('order','draft') then list:=case when phase='order' then e->'remaining' else coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['r',e->>'owner','deck']) with ordinality a(value,ordinality) where ordinality<=(r->>'count')::integer),'[]') end;
  for id,i in select value,ordinality::integer-1 from jsonb_array_elements_text(list) with ordinality loop result:=result||jsonb_build_array(public._r_option(i::text,coalesce(public._r_card(id)->>'name',id),id));end loop;return result;end if;
 if phase='shiva' then team:=e->>'targetTeam';select min(public._r_power(x->'s',team,value)) into mn from jsonb_array_elements(x#>array['s',team,'field']) where value->>'uid'<>e->>'uid' and not public._x_block(x->'s',team,value,t,'destroy');for v in select value from jsonb_array_elements(x#>array['s',team,'field']) where value->>'uid'<>e->>'uid' and not public._x_block(x->'s',team,value,t,'destroy') and public._r_power(x->'s',team,value)=mn loop result:=result||jsonb_build_array(public._r_option(v->>'uid',public._r_card(v->>'cardId')->>'name',v->>'cardId'));end loop;return result;end if;
 if op='choice' and phase is null then if jsonb_array_length(x#>array['r',e->>'owner','deck'])>0 then result:=result||jsonb_build_array(public._r_option('draw','Comprar 1 carta'));end if;if exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) as candidate54(unit) where candidate54.unit->>'uid'<>e->>'uid' and candidate54.unit->>'lane'=e->>'lane') then result:=result||jsonb_build_array(public._r_option('buff','Conceder +3 de poder'));end if;return result;end if;
 if op in ('recover','reviveQuiet','lockGrave') then team:=case when op='lockGrave' then enemy else t end;
  for g in select value from jsonb_array_elements(x#>array['s',team,'grave']) loop c:=public._r_card(g->>'cardId');if c='{}' or not public._card_enabled(g->>'cardId') or coalesce((c->>'specialOnly')::boolean,false) or (op<>'lockGrave' and g->>'owner' is distinct from e->>'owner') or not public._x_grave_ok(x,e,g,op='reviveQuiet') then continue;end if;
   if r ? 'kind' and r->>'kind'<>c->>'kind' or r ? 'kinds' and not(r->'kinds' ? (c->>'kind')) or r ? 'faction' and r->>'faction'<>c->>'faction' or r ? 'max' and (c->>'power')::numeric>(r->>'max')::numeric or op in ('reviveQuiet','lockGrave') and c->>'kind'<>'unit' then continue;end if;
   result:=result||jsonb_build_array(public._r_option(g->>'uid',c->>'name',g->>'cardId'));
  end loop;if coalesce((r->>'optional')::boolean,false) and jsonb_array_length(result)>0 then result:=result||jsonb_build_array(public._r_option('skip','Concluir'));end if;return result;end if;
 if op in ('equipmentDestroy','equipmentReturn') then for v in select value from jsonb_array_elements(x#>array['s',enemy,'field']) loop if public._x_block(x->'s',enemy,v,t,'equipment') then continue;end if;for id,i in select value,ordinality::integer-1 from jsonb_array_elements_text(coalesce(v->'equipment','[]')) with ordinality loop result:=result||jsonb_build_array(public._r_option((v->>'uid')||':'||i::text,(public._r_card(id)->>'name')||' · '||(public._r_card(v->>'cardId')->>'name'),id));end loop;end loop;if jsonb_array_length(result)=0 then return null;end if;return result;end if;
 if op in ('draft','reorder','drawCompany','clones','wave','waveBoth','cleanseAll','graveDraw','shiva','grow') or op in ('drawMove','drawBuff') and phase is null then return null;end if;
 if op='unsilenceDraw' and not exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) as candidate54(unit) where candidate54.unit->>'uid'<>e->>'uid' and not public._r_active(x->'s',t,candidate54.unit)) then return null;end if;
 if op='moveSelf' then return jsonb_build_array(public._r_option(e->>'uid','Mover unidade',u->>'cardId'),public._r_option('skip','Permanecer na fileira'));end if;
 if op='copyPower' then foreach team in array array[t,enemy] loop for v in select value from jsonb_array_elements(x#>array['s',team,'field']) where value->>'uid'<>e->>'uid' loop if not public._x_block(x->'s',team,v,t,'power') then result:=result||jsonb_build_array(public._r_option(team||':'||(v->>'uid'),public._r_card(v->>'cardId')->>'name',v->>'cardId'));end if;end loop;end loop;return result;end if;
 team:=case when op in ('destroy','reduce','drainGrave','purge','silence','moveEnemy','steal') or op='sacrificeHunt' and phase='hunt' then enemy else t end;
 if op='steal' and coalesce((r->>'losing')::boolean,false) and coalesce((select sum(public._r_power(x->'s',t,candidate54.unit)) from jsonb_array_elements(x#>array['s',t,'field']) as candidate54(unit) where candidate54.unit->>'lane'=e->>'lane'),0)>=coalesce((select sum(public._r_power(x->'s',enemy,candidate54.unit)) from jsonb_array_elements(x#>array['s',enemy,'field']) as candidate54(unit) where candidate54.unit->>'lane'=e->>'lane'),0) then return result;end if;
 k:=case when op='moveEnemy' then 'move' when op='steal' then 'steal' when op in ('destroy','sacrificeHunt') then 'destroy' when op in ('reduce','drainGrave','purge') then 'reduce' else 'power' end;
 for v in select value from jsonb_array_elements(x#>array['s',team,'field']) loop c:=public._r_card(public._r_identity(v));p:=public._r_power(x->'s',team,v);l:=(v->>'lane')::integer;
  if v->>'uid'=e->>'uid' or coalesce(e->'chosen','[]') ? (v->>'uid') or coalesce((r->>'opposite')::boolean,false) and v->>'lane'<>e->>'lane' or r ? 'faction' and op<>'moveAlly' and c->>'faction'<>r->>'faction' or r ? 'max' and p>(r->>'max')::numeric or public._x_block(x->'s',team,v,t,k) then continue;end if;
  if op='rally' and v->>'lane'=e->>'lane' or op<>'rally' and team=t and op not in ('moveAlly','drawMove','unsilenceDraw') and v->>'lane'<>e->>'lane' or op='sacrificeHunt' and phase='hunt' and p>(e->>'wanted')::numeric or op='unsilenceDraw' and public._r_active(x->'s',t,v) then continue;end if;
  if op in ('moveEnemy','moveAlly','drawMove') and not exists(select 1 from generate_series(0,2) l2 where l2<>l and public._x_room(x->'s',team,l2)) or op in ('rally','steal') and not public._x_room(x->'s',t,(e->>'lane')::integer) then continue;end if;
  result:=result||jsonb_build_array(public._r_option(v->>'uid',(c->>'name')||' · '||p::text||' poder · Fileira '||(l+1)::text,v->>'cardId'));
 end loop;if coalesce((r->>'optional')::boolean,false) and jsonb_array_length(result)>0 then result:=result||jsonb_build_array(public._r_option('skip','Concluir sem escolher'));end if;return result;
end $$;

create or replace function public._x_shiva(x jsonb,e jsonb,team text) returns jsonb language plpgsql volatile set search_path='' as $$
declare v jsonb;mn numeric;t text:=e->>'team';
begin select min(public._r_power(x->'s',team,value)) into mn from jsonb_array_elements(x#>array['s',team,'field']) where value->>'uid'<>e->>'uid' and not public._x_block(x->'s',team,value,t,'destroy');
 select value into v from jsonb_array_elements(x#>array['s',team,'field']) where value->>'uid'<>e->>'uid' and not public._x_block(x->'s',team,value,t,'destroy') and public._r_power(x->'s',team,value)=mn limit 1;
 if v is null then if team=t then return public._x_shiva(x,e,public._r_other(t));end if;return x;end if;
 if (select count(*) from jsonb_array_elements(x#>array['s',team,'field']) a where a->>'uid'<>e->>'uid' and not public._x_block(x->'s',team,a,t,'destroy') and public._r_power(x->'s',team,a)=mn)=1 then x:=public._r_destroy(x,team,jsonb_build_array(v->>'uid'));if team=t then return public._x_shiva(x,e,public._r_other(t));end if;return x;end if;
 return public._x_next(x,e,jsonb_build_object('phase','shiva','targetTeam',team,'choiceActor',case when team=t then e->>'owner' else v->>'playedBy' end));
end $$;

create or replace function public._x_resolve(x jsonb,e jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare t text:=e->>'team';enemy text:=public._r_other(t);owner_id text:=e->>'owner';u jsonb:=public._r_unit(x->'s',t,e->>'uid');r jsonb:=coalesce(e->'rule',public._x_rule(u));op text:=r->>'op';phase text:=e->>'phase';sel text:=e->>'selection';v jsonb;g jsonb;c jsonb;list jsonb;top_cards jsonb;remaining jsonb;ordered jsonb;team text;id text;target_id text;amount numeric;wanted numeric;p numeric;i integer;l integer;idx integer;
begin
 e:=e||jsonb_build_object('rule',r);if sel='skip' or phase='finish' then return x;end if;
 if phase='lane' then team:=e->>'targetTeam';v:=public._r_unit(x->'s',team,e->>'targetUid');l:=sel::integer;
  if v is not null and (v->>'lane')::integer<>l and public._x_room(x->'s',team,l) and not public._x_block(x->'s',team,v,t,'move') then v:=v||jsonb_build_object('lane',l);x:=public._r_set_unit(x,team,v->>'uid',v);if r ? 'amount' and (not(r ? 'faction') or public._r_card(public._r_identity(v))->>'faction'=r->>'faction') then x:=public._r_change(x,team,v->>'uid',t,(r->>'amount')::numeric);end if;end if;return x;end if;
 if phase='order' then remaining:=e->'remaining';id:=remaining->>sel::integer;remaining:=remaining-sel::integer;ordered:=coalesce(e->'ordered','[]')||jsonb_build_array(id);
  if jsonb_array_length(remaining)>0 then return public._x_next(x,e,jsonb_build_object('phase','order','remaining',remaining,'ordered',ordered));end if;
  top_cards:=x#>array['r',owner_id,'deck'];top_cards:=case when e->>'destination'='top' then ordered||top_cards else top_cards||ordered end;x:=jsonb_set(x,array['r',owner_id,'deck'],top_cards,true);if coalesce((e->>'drawAfter')::boolean,false) then x:=public._x_draw(x,e);end if;return x;end if;
 if phase='draft' then select coalesce(jsonb_agg(value order by ordinality) filter(where ordinality<=(r->>'count')::integer),'[]'),coalesce(jsonb_agg(value order by ordinality) filter(where ordinality>(r->>'count')::integer),'[]') into top_cards,remaining from jsonb_array_elements(x#>array['r',owner_id,'deck']) with ordinality a(value,ordinality);
  id:=top_cards->>sel::integer;top_cards:=top_cards-sel::integer;x:=jsonb_set(x,array['r',owner_id,'deck'],remaining,true);if id is not null then x:=jsonb_set(x,array['r',owner_id,'hand'],(x#>array['r',owner_id,'hand'])||jsonb_build_array(id),true);end if;
  if jsonb_array_length(top_cards)>0 then return public._x_next(x,e,jsonb_build_object('phase','order','remaining',top_cards,'ordered','[]'::jsonb,'destination','bottom'));end if;return x;end if;
 if phase='shiva' then team:=e->>'targetTeam';x:=public._r_destroy(x,team,jsonb_build_array(sel));if team=t then x:=public._x_shiva(x,e,enemy);end if;return x;end if;
 case op
 when 'draft' then return public._x_next(x,e,jsonb_build_object('phase','draft'));
 when 'reorder' then select coalesce(jsonb_agg(value order by ordinality) filter(where ordinality<=(r->>'count')::integer),'[]'),coalesce(jsonb_agg(value order by ordinality) filter(where ordinality>(r->>'count')::integer),'[]') into top_cards,remaining from jsonb_array_elements(x#>array['r',owner_id,'deck']) with ordinality a(value,ordinality);x:=jsonb_set(x,array['r',owner_id,'deck'],remaining,true);if jsonb_array_length(top_cards)>0 then return public._x_next(x,e,jsonb_build_object('phase','order','remaining',top_cards,'ordered','[]'::jsonb,'destination','top','drawAfter',true));end if;
 when 'choice' then if sel='draw' then return public._x_draw(x,e);else return public._x_next(x,e,jsonb_build_object('phase','buff','rule',jsonb_build_object('op','buff','amount',3)));end if;
 when 'buff' then return public._r_change(x,t,sel,t,(r->>'amount')::numeric);
 when 'recover','reviveQuiet','lockGrave' then team:=case when op='lockGrave' then enemy else t end;select value into g from jsonb_array_elements(x#>array['s',team,'grave']) where value->>'uid'=sel limit 1;if g is null or not public._x_grave_ok(x,e,g,op='reviveQuiet') then return x;end if;
  if op='lockGrave' then x:=jsonb_set(x,array['s',team,'grave'],coalesce((select jsonb_agg(case when value->>'uid'=sel then value||jsonb_build_object('lockedRound',x#>'{s,round}') else value end order by ordinality) from jsonb_array_elements(x#>array['s',team,'grave']) with ordinality a(value,ordinality)),'[]'),true);if jsonb_array_length(coalesce(e->'chosen','[]'))+1<(r->>'count')::integer then return public._x_next(x,e,jsonb_build_object('chosen',coalesce(e->'chosen','[]')||jsonb_build_array(sel)));end if;return x;end if;
  if op='reviveQuiet' and not public._x_room(x->'s',t,(e->>'lane')::integer) then return x;end if;
  x:=jsonb_set(x,array['s',team,'grave'],coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['s',team,'grave']) with ordinality a(value,ordinality) where value->>'uid'<>sel),'[]'),true);x:=public._r_grave_sync(x,team);
  if op='recover' then return jsonb_set(x,array['r',owner_id,'hand'],(x#>array['r',owner_id,'hand'])||jsonb_build_array(g->'cardId'),true);else x:=public._x_quiet(x,g->>'cardId',t,owner_id,(e->>'lane')::integer);if g->>'rebornRound'=x#>>'{s,round}' then select value into v from jsonb_array_elements(x#>array['s',t,'field']) with ordinality a(value,ordinality) where value->>'cardId'=g->>'cardId' and value->>'playedBy'=owner_id order by ordinality desc limit 1;if v is not null then x:=public._r_set_unit(x,t,v->>'uid',public._x_memory(x->'s',v,g));end if;end if;return x;end if;
 when 'drawCompany' then x:=public._x_draw(x,e);if exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) as candidate54(unit) where candidate54.unit->>'uid'<>e->>'uid' and candidate54.unit->>'lane'=e->>'lane' and public._r_card(public._r_identity(candidate54.unit))->>'faction'=r->>'faction') then x:=public._r_change(x,t,e->>'uid',t,(r->>'amount')::numeric);end if;
 when 'drawBuff' then if phase is null then return public._x_next(public._x_draw(x,e),e,jsonb_build_object('phase','buff'));end if;return public._r_change(x,t,sel,t,(r->>'amount')::numeric);
 when 'drawMove' then if phase is null then return public._x_next(public._x_draw(x,e),e,jsonb_build_object('phase','move'));end if;return public._x_next(x,e,jsonb_build_object('phase','lane','targetTeam',t,'targetUid',sel));
 when 'moveAlly','moveSelf','moveEnemy' then return public._x_next(x,e,jsonb_build_object('phase','lane','targetTeam',case when op='moveEnemy' then enemy else t end,'targetUid',sel));
 when 'rally' then v:=public._r_unit(x->'s',t,sel);if v is not null and v->>'lane'<>e->>'lane' and public._x_room(x->'s',t,(e->>'lane')::integer) then x:=public._r_set_unit(x,t,sel,v||jsonb_build_object('lane',e->'lane'));x:=public._r_change(x,t,sel,t,(r->>'amount')::numeric);end if;
 when 'bounce' then v:=public._r_unit(x->'s',t,sel);if v is not null then x:=jsonb_set(x,array['s',t,'field'],coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['s',t,'field']) with ordinality a(value,ordinality) where value->>'uid'<>sel),'[]'),true);id:=coalesce(v->>'eclipseOriginalCardId',v->>'sourceCardId',case when v->>'cardId'='lukyan-rei-de-todos' then 'lukyan' else v->>'cardId' end);if not coalesce((v->>'token')::boolean,false) then x:=jsonb_set(x,array['r',owner_id,'hand'],(x#>array['r',owner_id,'hand'])||jsonb_build_array(id),true);end if;for id in select jsonb_array_elements_text(coalesce(v->'equipment','[]')) loop x:=jsonb_set(x,array['s',t,'grave'],(x#>array['s',t,'grave'])||jsonb_build_array(jsonb_build_object('uid',gen_random_uuid()::text,'cardId',id,'owner',coalesce(v#>>array['equipmentOwners',id],v->>'playedBy'),'progress',0)),true);end loop;x:=public._r_grave_sync(x,t);x:=public._r_change(x,t,e->>'uid',t,(r->>'amount')::numeric);end if;
 when 'steal' then v:=public._r_unit(x->'s',enemy,sel);if v is not null and not public._x_block(x->'s',enemy,v,t,'steal') and public._x_room(x->'s',t,(e->>'lane')::integer) then x:=jsonb_set(x,array['s',enemy,'field'],coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['s',enemy,'field']) with ordinality a(value,ordinality) where value->>'uid'<>sel),'[]'),true);v:=v||jsonb_build_object('lane',e->'lane','playedBy',owner_id);x:=jsonb_set(x,array['s',t,'field'],(x#>array['s',t,'field'])||jsonb_build_array(v),true);x:=public._r_visual(x,'hearts',enemy,jsonb_build_array(sel));end if;
 when 'reduce','drainGrave' then amount:=case when op='drainGrave' then (select count(*) from jsonb_array_elements(x#>array['s',enemy,'grave']) as grave54(entry) where grave54.entry->>'owner'=public._r_unit(x->'s',enemy,sel)->>'playedBy' and public._r_card(grave54.entry->>'cardId')->>'kind'='unit') else (r->>'amount')::numeric end;x:=public._r_change(x,enemy,sel,t,-amount);if op='reduce' and jsonb_array_length(coalesce(e->'chosen','[]'))+1<coalesce((r->>'count')::integer,1) then return public._x_next(x,e,jsonb_build_object('chosen',coalesce(e->'chosen','[]')||jsonb_build_array(sel)));end if;
 when 'wave','waveBoth' then foreach team in array case when op='waveBoth' then array[t,enemy] else array[enemy] end loop for v in select value from jsonb_array_elements(x#>array['s',team,'field']) where value->>'uid'<>e->>'uid' and (value->>'lane')::integer=coalesce((r->>'fixedLane')::integer,(e->>'lane')::integer) loop x:=public._r_change(x,team,v->>'uid',t,-(r->>'amount')::numeric);end loop;end loop;
 when 'destroy' then x:=public._r_destroy(x,enemy,jsonb_build_array(sel));if (coalesce((r->>'costOnAttempt')::boolean,false) or public._r_unit(x->'s',enemy,sel) is null) and r ? 'selfCost' then x:=public._r_change(x,t,e->>'uid',t,-(r->>'selfCost')::numeric);end if;
 when 'sacrificeHunt' then if phase='hunt' then return public._r_destroy(x,enemy,jsonb_build_array(sel));end if;v:=public._r_unit(x->'s',t,sel);wanted:=public._r_power(x->'s',t,v);x:=public._r_destroy(x,t,jsonb_build_array(sel));if public._r_unit(x->'s',t,sel) is null then return public._x_next(x,e,jsonb_build_object('phase','hunt','wanted',wanted));end if;
 when 'sacrificeBuff','sacrificeFeed' then v:=public._r_unit(x->'s',t,sel);if v is null then return x;end if;wanted:=public._r_power(x->'s',t,v);list:=x#>array['s',t,'field'];x:=public._r_destroy(x,t,jsonb_build_array(sel));if public._r_unit(x->'s',t,sel) is null then if op='sacrificeFeed' then x:=public._r_change(x,t,e->>'uid',t,floor(wanted/2));else for v in select value from jsonb_array_elements(list) where value->>'uid'<>sel and value->>'lane'=e->>'lane' loop x:=public._r_change(x,t,v->>'uid',t,(r->>'amount')::numeric);end loop;end if;end if;
 when 'copyPower' then team:=split_part(sel,':',1);target_id:=split_part(sel,':',2);v:=public._r_unit(x->'s',team,target_id);if v is not null then u:=u||jsonb_build_object('powerShift',coalesce((u->>'powerShift')::numeric,0)+public._r_power(x->'s',team,v)-public._r_power(x->'s',t,u));x:=public._r_set_unit(x,t,u->>'uid',u);end if;
 when 'swap' then v:=public._r_unit(x->'s',t,sel);if v is not null then p:=public._r_power(x->'s',t,u);wanted:=public._r_power(x->'s',t,v);u:=u||jsonb_build_object('powerShift',coalesce((u->>'powerShift')::numeric,0)+wanted-p);v:=v||jsonb_build_object('powerShift',coalesce((v->>'powerShift')::numeric,0)+p-wanted);x:=public._r_set_unit(public._r_set_unit(x,t,u->>'uid',u),t,v->>'uid',v);end if;
 when 'purge' then v:=public._r_unit(x->'s',enemy,sel);if v is not null and not public._x_block(x->'s',enemy,v,t,'reduce') then v:=v||jsonb_build_object('mutedEquipment',coalesce(v->'equipment','[]')||coalesce(v->'copiedEquipment','[]'),'equipmentMuted',false,'bonus',least(0,coalesce((v->>'bonus')::numeric,0)),'multiplier',least(1,coalesce((v->>'multiplier')::numeric,1)),'powerShift',least(0,coalesce((v->>'powerShift')::numeric,0)),'copyOffset',least(0,coalesce((v->>'copyOffset')::numeric,0)),'reviveOffset',least(0,coalesce((v->>'reviveOffset')::numeric,0)),'progress',0);x:=public._r_set_unit(x,enemy,sel,v);end if;
 when 'cleanse' then v:=public._r_unit(x->'s',t,sel);if v is not null then x:=public._r_set_unit(x,t,sel,public._x_clean(v));if r ? 'amount' then x:=public._r_change(x,t,sel,t,(r->>'amount')::numeric);end if;if jsonb_array_length(coalesce(e->'chosen','[]'))+1<coalesce((r->>'count')::integer,1) then return public._x_next(x,e,jsonb_build_object('chosen',coalesce(e->'chosen','[]')||jsonb_build_array(sel)));end if;end if;
 when 'cleanseAll' then for v in select value from jsonb_array_elements(x#>array['s',t,'field']) where value->>'uid'<>e->>'uid' and value->>'lane'=e->>'lane' and public._r_card(public._r_identity(value))->>'faction'=r->>'faction' loop x:=public._r_set_unit(x,t,v->>'uid',public._x_unsilence(x->'s',public._x_clean(v)));end loop;
 when 'unsilenceDraw' then v:=public._r_unit(x->'s',t,sel);if v is null then x:=public._x_draw(x,e);else x:=public._r_set_unit(x,t,sel,public._x_unsilence(x->'s',v));end if;
 when 'silence' then v:=public._r_unit(x->'s',enemy,sel);if v is not null and not public._x_block(x->'s',enemy,v,t,'silence') then v:=v||jsonb_build_object('silencedStamp',owner_id||':'||coalesce(x#>>array['r',owner_id,'turnsTaken'],'0'));if coalesce((r->>'ownerEnd')::boolean,false) then v:=v||jsonb_build_object('silencedOwnerEnd',true);else v:=v||jsonb_build_object('silencedJogadas',(r->>'turns')::integer);end if;x:=public._r_set_unit(x,enemy,sel,v);end if;
 when 'guard' then v:=public._r_unit(x->'s',t,sel);if v is not null then x:=public._r_set_unit(x,t,sel,v||jsonb_build_object('guardOwner',owner_id,'guardStamp',owner_id||':'||coalesce(x#>>array['r',owner_id,'turnsTaken'],'0')));end if;
 when 'equipmentDestroy','equipmentReturn' then if sel is null then if r ? 'fallback' then x:=public._r_change(x,t,e->>'uid',t,(r->>'fallback')::numeric);end if;return x;end if;target_id:=split_part(sel,':',1);idx:=split_part(sel,':',2)::integer;v:=public._r_unit(x->'s',enemy,target_id);if v is null or public._x_block(x->'s',enemy,v,t,'equipment') then return x;end if;id:=v#>>array['equipment',idx::text];if id is null then return x;end if;v:=jsonb_set(v,'{equipment}',(v->'equipment')-idx,true);x:=public._r_set_unit(x,enemy,target_id,v);
  if op='equipmentReturn' then target_id:=coalesce(v#>>array['equipmentOwners',id],v->>'playedBy');if x#>array['r',target_id] is null then select key into target_id from jsonb_each(x->'r') where value->>'team'=enemy limit 1;end if;x:=jsonb_set(x,array['r',target_id,'hand'],(x#>array['r',target_id,'hand'])||jsonb_build_array(id),true);x:=public._x_draw(x,e);
  else x:=jsonb_set(x,array['s',enemy,'grave'],(x#>array['s',enemy,'grave'])||jsonb_build_array(jsonb_build_object('uid',gen_random_uuid()::text,'cardId',id,'owner',coalesce(v#>>array['equipmentOwners',id],v->>'playedBy'),'progress',0)),true);x:=public._r_grave_sync(x,enemy);end if;
 when 'clones' then for i in 1..(r->>'count')::integer loop exit when not public._x_room(x->'s',t,(e->>'lane')::integer);x:=public._x_quiet(x,'clone-macaco',t,owner_id,(e->>'lane')::integer,true);end loop;
 when 'graveDraw' then select count(*) into i from jsonb_array_elements(x#>array['s',t,'grave']) as grave54(entry) where grave54.entry->>'owner'=owner_id and public._r_card(grave54.entry->>'cardId')->>'kind'='unit';if i>0 then x:=public._x_draw(x,e);end if;if i>=(r->>'count')::integer then x:=public._r_change(x,t,e->>'uid',t,(r->>'amount')::numeric);end if;
 when 'shiva' then return public._x_shiva(x,e,t);
 else null;
 end case;return public._r_reconcile(x);
end $$;

__HOOKS__
-- Restrict helper functions to the authoritative engine.
do $acl$ declare f record;begin for f in select p.oid::regprocedure r from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (left(p.proname,3)='_x_' or p.proname like '%_before_remake') loop execute 'revoke all on function '||f.r||' from public,anon,authenticated';end loop;end $acl$;
notify pgrst,'reload schema';
commit;
