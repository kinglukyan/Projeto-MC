-- 044: Reviewed choices, guard duration, movement, and shared-zone ownership.
-- Compatibility revision: stable action wrapper and explicit revival dispatcher.
-- Run this complete file after migrations 040–043; do not run only a selected block.
begin;
create or replace function public._x_options(x jsonb,e jsonb) returns jsonb language plpgsql stable set search_path='' as $$
declare t text:=e->>'team';enemy text:=public._r_other(t);u jsonb:=public._r_unit(x->'s',t,e->>'uid');r jsonb:=coalesce(e->'rule',public._x_rule(u));op text:=r->>'op';phase text:=e->>'phase';result jsonb:='[]';v jsonb;c jsonb;g jsonb;list jsonb;team text;id text;p numeric;mn numeric;k text;i integer;l integer;allowed boolean;
begin
 if phase='finish' then return jsonb_build_array(public._r_option('confirm','Continuar a partida'));end if;
 if phase='lane' then v:=public._r_unit(x->'s',e->>'targetTeam',e->>'targetUid');if v is null then return result;end if;for i in 0..2 loop if i<>(v->>'lane')::integer and public._x_room(x->'s',e->>'targetTeam',i) then result:=result||jsonb_build_array(public._r_option(i::text,'Fileira '||(i+1)::text));end if;end loop;return result;end if;
 if phase in ('order','draft') then list:=case when phase='order' then e->'remaining' else coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['r',e->>'owner','deck']) with ordinality a(value,ordinality) where ordinality<=(r->>'count')::integer),'[]') end;
  for id,i in select value,ordinality::integer-1 from jsonb_array_elements_text(list) with ordinality loop result:=result||jsonb_build_array(public._r_option(i::text,coalesce(public._r_card(id)->>'name',id),id));end loop;return result;end if;
 if phase='shiva' then team:=e->>'targetTeam';select min(public._r_power(x->'s',team,value)) into mn from jsonb_array_elements(x#>array['s',team,'field']) where value->>'uid'<>e->>'uid' and not public._x_block(x->'s',team,value,t,'destroy');for v in select value from jsonb_array_elements(x#>array['s',team,'field']) where value->>'uid'<>e->>'uid' and not public._x_block(x->'s',team,value,t,'destroy') and public._r_power(x->'s',team,value)=mn loop result:=result||jsonb_build_array(public._r_option(v->>'uid',public._r_card(v->>'cardId')->>'name',v->>'cardId'));end loop;return result;end if;
 if op='choice' and phase is null then if jsonb_array_length(x#>array['r',e->>'owner','deck'])>0 then result:=result||jsonb_build_array(public._r_option('draw','Comprar 1 carta'));end if;if exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) v where v->>'uid'<>e->>'uid' and v->>'lane'=e->>'lane') then result:=result||jsonb_build_array(public._r_option('buff','Conceder +3 de poder'));end if;return result;end if;
 if op in ('recover','reviveQuiet','lockGrave') then team:=case when op='lockGrave' then enemy else t end;
  for g in select value from jsonb_array_elements(x#>array['s',team,'grave']) loop c:=public._r_card(g->>'cardId');if c='{}' or not public._card_enabled(g->>'cardId') or coalesce((c->>'specialOnly')::boolean,false) or (op<>'lockGrave' and g->>'owner' is distinct from e->>'owner') or not public._x_grave_ok(x,e,g,op='reviveQuiet') then continue;end if;
   if r ? 'kind' and r->>'kind'<>c->>'kind' or r ? 'kinds' and not(r->'kinds' ? (c->>'kind')) or r ? 'faction' and r->>'faction'<>c->>'faction' or r ? 'max' and (c->>'power')::numeric>(r->>'max')::numeric or op in ('reviveQuiet','lockGrave') and c->>'kind'<>'unit' then continue;end if;
   result:=result||jsonb_build_array(public._r_option(g->>'uid',c->>'name',g->>'cardId'));
  end loop;if coalesce((r->>'optional')::boolean,false) and jsonb_array_length(result)>0 then result:=result||jsonb_build_array(public._r_option('skip','Concluir'));end if;return result;end if;
 if op in ('equipmentDestroy','equipmentReturn') then for v in select value from jsonb_array_elements(x#>array['s',enemy,'field']) loop if public._x_block(x->'s',enemy,v,t,'equipment') then continue;end if;for id,i in select value,ordinality::integer-1 from jsonb_array_elements_text(coalesce(v->'equipment','[]')) with ordinality loop result:=result||jsonb_build_array(public._r_option((v->>'uid')||':'||i::text,(public._r_card(id)->>'name')||' · '||(public._r_card(v->>'cardId')->>'name'),id));end loop;end loop;if jsonb_array_length(result)=0 then return null;end if;return result;end if;
 if op in ('draft','reorder','drawCompany','clones','wave','waveBoth','cleanseAll','graveDraw','shiva','grow') or op in ('drawMove','drawBuff') and phase is null then return null;end if;
 if op='unsilenceDraw' and not exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) v where v->>'uid'<>e->>'uid' and not public._r_active(x->'s',t,v)) then return null;end if;
 if op='moveSelf' then return jsonb_build_array(public._r_option(e->>'uid','Mover unidade',u->>'cardId'),public._r_option('skip','Permanecer na fileira'));end if;
 if op='copyPower' then foreach team in array array[t,enemy] loop for v in select value from jsonb_array_elements(x#>array['s',team,'field']) where value->>'uid'<>e->>'uid' loop if not public._x_block(x->'s',team,v,t,'power') then result:=result||jsonb_build_array(public._r_option(team||':'||(v->>'uid'),public._r_card(v->>'cardId')->>'name',v->>'cardId'));end if;end loop;end loop;return result;end if;
 team:=case when op in ('destroy','reduce','drainGrave','purge','silence','moveEnemy','steal') or op='sacrificeHunt' and phase='hunt' then enemy else t end;
 if op='steal' and coalesce((r->>'losing')::boolean,false) and coalesce((select sum(public._r_power(x->'s',t,v)) from jsonb_array_elements(x#>array['s',t,'field']) v where v->>'lane'=e->>'lane'),0)>=coalesce((select sum(public._r_power(x->'s',enemy,v)) from jsonb_array_elements(x#>array['s',enemy,'field']) v where v->>'lane'=e->>'lane'),0) then return result;end if;
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
 when 'drawCompany' then x:=public._x_draw(x,e);if exists(select 1 from jsonb_array_elements(x#>array['s',t,'field']) v where v->>'uid'<>e->>'uid' and v->>'lane'=e->>'lane' and public._r_card(public._r_identity(v))->>'faction'=r->>'faction') then x:=public._r_change(x,t,e->>'uid',t,(r->>'amount')::numeric);end if;
 when 'drawBuff' then if phase is null then return public._x_next(public._x_draw(x,e),e,jsonb_build_object('phase','buff'));end if;return public._r_change(x,t,sel,t,(r->>'amount')::numeric);
 when 'drawMove' then if phase is null then return public._x_next(public._x_draw(x,e),e,jsonb_build_object('phase','move'));end if;return public._x_next(x,e,jsonb_build_object('phase','lane','targetTeam',t,'targetUid',sel));
 when 'moveAlly','moveSelf','moveEnemy' then return public._x_next(x,e,jsonb_build_object('phase','lane','targetTeam',case when op='moveEnemy' then enemy else t end,'targetUid',sel));
 when 'rally' then v:=public._r_unit(x->'s',t,sel);if v is not null and v->>'lane'<>e->>'lane' and public._x_room(x->'s',t,(e->>'lane')::integer) then x:=public._r_set_unit(x,t,sel,v||jsonb_build_object('lane',e->'lane'));x:=public._r_change(x,t,sel,t,(r->>'amount')::numeric);end if;
 when 'bounce' then v:=public._r_unit(x->'s',t,sel);if v is not null then x:=jsonb_set(x,array['s',t,'field'],coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['s',t,'field']) with ordinality a(value,ordinality) where value->>'uid'<>sel),'[]'),true);id:=coalesce(v->>'eclipseOriginalCardId',v->>'sourceCardId',case when v->>'cardId'='lukyan-rei-de-todos' then 'lukyan' else v->>'cardId' end);if not coalesce((v->>'token')::boolean,false) then x:=jsonb_set(x,array['r',owner_id,'hand'],(x#>array['r',owner_id,'hand'])||jsonb_build_array(id),true);end if;for id in select jsonb_array_elements_text(coalesce(v->'equipment','[]')) loop x:=jsonb_set(x,array['s',t,'grave'],(x#>array['s',t,'grave'])||jsonb_build_array(jsonb_build_object('uid',gen_random_uuid()::text,'cardId',id,'owner',coalesce(v#>>array['equipmentOwners',id],v->>'playedBy'),'progress',0)),true);end loop;x:=public._r_grave_sync(x,t);x:=public._r_change(x,t,e->>'uid',t,(r->>'amount')::numeric);end if;
 when 'steal' then v:=public._r_unit(x->'s',enemy,sel);if v is not null and not public._x_block(x->'s',enemy,v,t,'steal') and public._x_room(x->'s',t,(e->>'lane')::integer) then x:=jsonb_set(x,array['s',enemy,'field'],coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['s',enemy,'field']) with ordinality a(value,ordinality) where value->>'uid'<>sel),'[]'),true);v:=v||jsonb_build_object('lane',e->'lane','playedBy',owner_id);x:=jsonb_set(x,array['s',t,'field'],(x#>array['s',t,'field'])||jsonb_build_array(v),true);x:=public._r_visual(x,'hearts',t,jsonb_build_array(sel));end if;
 when 'reduce','drainGrave' then amount:=case when op='drainGrave' then (select count(*) from jsonb_array_elements(x#>array['s',enemy,'grave']) g where g->>'owner'=public._r_unit(x->'s',enemy,sel)->>'playedBy' and public._r_card(g->>'cardId')->>'kind'='unit') else (r->>'amount')::numeric end;x:=public._r_change(x,enemy,sel,t,-amount);if op='reduce' and jsonb_array_length(coalesce(e->'chosen','[]'))+1<coalesce((r->>'count')::integer,1) then return public._x_next(x,e,jsonb_build_object('chosen',coalesce(e->'chosen','[]')||jsonb_build_array(sel)));end if;
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
 when 'graveDraw' then select count(*) into i from jsonb_array_elements(x#>array['s',t,'grave']) g where g->>'owner'=owner_id and public._r_card(g->>'cardId')->>'kind'='unit';if i>0 then x:=public._x_draw(x,e);end if;if i>=(r->>'count')::integer then x:=public._r_change(x,t,e->>'uid',t,(r->>'amount')::numeric);end if;
 when 'shiva' then return public._x_shiva(x,e,t);
 else null;
 end case;return public._r_reconcile(x);
end $$;

create or replace function public._r_turn_start(s jsonb,resources jsonb,actor text) returns jsonb language plpgsql volatile set search_path='' as $$
declare t text;v jsonb;x jsonb:=jsonb_build_object('s',s,'r',resources);
begin foreach t in array array['player_one','player_two'] loop for v in select value from jsonb_array_elements(coalesce(s#>array[t,'field'],'[]')) where value->>'guardOwner'=actor and value->>'guardStamp' is distinct from actor||':'||coalesce(resources#>>array[actor,'turnsTaken'],'0') loop x:=public._r_set_unit(x,t,v->>'uid',v-'guardOwner'-'guardStamp');end loop;end loop;return public._r_turn_start_before_remake(x->'s',resources,actor);end $$;

create or replace function public._r_turn_end(s jsonb,actor text,t text,turn_no integer) returns jsonb language plpgsql volatile set search_path='' as $$
declare x jsonb:=jsonb_build_object('s',s,'r','{}'::jsonb);u jsonb;r jsonb;team text;stamp text:=actor||':'||turn_no::text;
begin
 if s#>>array['endedTurns',actor]=coalesce(s->>'round','1')||':'||turn_no::text then return s;end if;
 for u in select value from jsonb_array_elements(coalesce(s#>array[t,'field'],'[]')) where value->>'playedBy'=actor loop r:=public._x_rule(u);
  if public._r_active(s,t,u) and r->>'op'='grow' and (not coalesce((r->>'company')::boolean,false) or (select count(*) from jsonb_array_elements(s#>array[t,'field']) v where v->>'lane'=u->>'lane')>1) and (not coalesce((r->>'climate')::boolean,false) or s#>>'{sharedZones,climate}' is not null) then x:=public._r_change(x,t,u->>'uid',t,(r->>'amount')::numeric);end if;
 end loop;
 -- Owner-end expiry is applied after end-of-turn growth, while the silence still acts.
 s:=public._r_turn_end_before_remake(x->'s',actor,t,turn_no);x:=jsonb_build_object('s',s,'r','{}'::jsonb);
 foreach team in array array['player_one','player_two'] loop for u in select value from jsonb_array_elements(coalesce(s#>array[team,'field'],'[]')) loop
  
  if coalesce((u->>'silencedOwnerEnd')::boolean,false) and u->>'playedBy'=actor then u:=u-'silencedOwnerEnd';end if;
  if coalesce((u->>'silencedJogadas')::integer,0)>0 and u->>'silencedStamp' is distinct from stamp then u:=u||jsonb_build_object('silencedJogadas',(u->>'silencedJogadas')::integer-1);end if;x:=public._r_set_unit(x,team,u->>'uid',u);
 end loop;end loop;return public._r_reconcile(x)->'s';
end $$;
-- Preserve the exact owner's shared cards, so Enki and Isis can recover them later.
do $zone_backups$
declare sig text;n text;d text;
begin
 foreach sig in array array['_r_spawn(jsonb,text,text,text,integer,integer)','_r_clear_round(jsonb)'] loop
  n:=split_part(sig,'(',1);
  if to_regprocedure('public.'||replace(sig,n,n||'_before_audit44')) is null then
   d:=pg_get_functiondef(('public.'||sig)::regprocedure);
   execute replace(d,'FUNCTION public.'||n||'(','FUNCTION public.'||n||'_before_audit44(');
  end if;
 end loop;
end $zone_backups$;
create or replace function public._x_discard_zone(x jsonb,z text) returns jsonb language plpgsql volatile set search_path='' as $$
declare c jsonb:=x#>array['s','zoneCards',z];t text;
begin
 if c is null or c->>'cardId' is null then return x;end if;t:=c->>'team';
 if t not in ('player_one','player_two') then return x;end if;
 x:=jsonb_set(x,array['s',t,'grave'],coalesce(x#>array['s',t,'grave'],'[]')||jsonb_build_array(jsonb_build_object('uid',gen_random_uuid()::text,'cardId',c->>'cardId','owner',c->>'owner','progress',0)),true);
 x:=x#-array['s','zoneCards',z];return public._r_grave_sync(x,t);
end $$;
create or replace function public._r_spawn(x jsonb,cid text,t text,owner_id text,lane integer,progress integer default 0) returns jsonb language plpgsql volatile set search_path='' as $$
declare c jsonb:=public._r_card(cid);z text;
begin
 if c->>'kind' in ('location','terrain','climate','event','weather') then
  z:=case c->>'kind' when 'location' then 'local' when 'terrain' then 'terrain' else 'climate' end;
  -- The original spawn validates whether replacement is legal. An error rolls this whole transaction back.
  x:=public._x_discard_zone(x,z);
  x:=jsonb_set(x,'{s,zoneCards}',coalesce(x#>'{s,zoneCards}','{}')||jsonb_build_object(z,jsonb_build_object('cardId',cid,'owner',owner_id,'team',t)),true);
 end if;
 return public._r_spawn_before_audit44(x,cid,t,owner_id,lane,progress);
end $$;
create or replace function public._r_clear_round(s jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare x jsonb:=jsonb_build_object('s',s,'r','{}'::jsonb);z text;
begin
 foreach z in array array['local','terrain','climate'] loop x:=public._x_discard_zone(x,z);end loop;
 return public._r_clear_round_before_audit44(x->'s')-'zoneCards';
end $$;


-- Validate choices through the stable function interface, independently of its source formatting.
do $choice_guard$
declare definition text;arguments text;
begin
 if to_regprocedure('public._r_action_before_audit44(jsonb,jsonb,text,jsonb)') is null then
  definition:=pg_get_functiondef('public._r_action(jsonb,jsonb,text,jsonb)'::regprocedure);
  execute replace(definition,'FUNCTION public._r_action(','FUNCTION public._r_action_before_audit44(');
 end if;
 arguments:=pg_get_function_arguments('public._r_action(jsonb,jsonb,text,jsonb)'::regprocedure);
 execute format($definition$
  create or replace function public._r_action(%s) returns jsonb
  language plpgsql volatile set search_path='' as $wrapper$
  declare audit_context jsonb; audit_pending jsonb; audit_options jsonb;
  begin
   /* choice_wrapper_v44: retain all existing action/security/pause checks. */
   audit_context:=public._r_init($1,$2);
   if $4->>'type'='resolve_effect' then
    audit_pending:=audit_context#>'{s,pendingEffect}';
    if audit_pending is null
      or audit_pending->>'actor' is distinct from $3
      or audit_pending->>'id' is distinct from $4->>'choice_id' then
     raise exception 'Esta escolha não está mais disponível.';
    end if;
    audit_options:=public._r_options(audit_context,audit_pending->'event');
    if not exists(select 1 from jsonb_array_elements(coalesce(audit_options,'[]'::jsonb)) choice
      where choice->>'value'=$4->>'choice_value') then
     raise exception 'Essa escolha não está mais disponível.';
    end if;
   end if;
   return public._r_action_before_audit44(audit_context->'s',audit_context->'r',$3,$4);
  end $wrapper$;
 $definition$,arguments);
end $choice_guard$;


-- Quiet revivals/clones must not announce the unit's entry ability as if it had fired.
do $quiet_backup$
declare d text;
begin
 if to_regprocedure('public._x_quiet_before_audit44(jsonb,text,text,text,integer,boolean)') is null then
  d:=pg_get_functiondef('public._x_quiet(jsonb,text,text,text,integer,boolean)'::regprocedure);
  execute replace(d,'FUNCTION public._x_quiet(','FUNCTION public._x_quiet_before_audit44(');
 end if;
end $quiet_backup$;
create or replace function public._x_quiet(x jsonb,cid text,t text,owner_id text,l integer,token boolean default false) returns jsonb language plpgsql volatile set search_path='' as $$
declare old_ids jsonb;events jsonb;
begin
 select coalesce(jsonb_agg(value->'id'),'[]') into old_ids from jsonb_array_elements(coalesce(x#>'{s,visualEvents}','[]'));
 x:=public._x_quiet_before_audit44(x,cid,t,owner_id,l,token);
 select coalesce(jsonb_agg(case when value->>'kind'='enter' and not(old_ids ? (value->>'id')) then value||jsonb_build_object('quiet',true) else value end order by ordinality),'[]') into events from jsonb_array_elements(coalesce(x#>'{s,visualEvents}','[]')) with ordinality a(value,ordinality);
 return jsonb_set(x,'{s,visualEvents}',events,true);
end $$;

-- Preserve buffs and reductions separately even when their numeric sum cancels out.
create or replace function public._x_part(u jsonb,k text) returns jsonb language plpgsql immutable set search_path='' as $$
declare n numeric:=coalesce((u->>k)::numeric,0);p jsonb:=u#>array['powerLedger',k];
begin
 if p is null or coalesce((p->>'positive')::numeric,0)+coalesce((p->>'negative')::numeric,0)<>n then return jsonb_build_object('positive',greatest(0,n),'negative',least(0,n));end if;
 return p;
end $$;
create or replace function public._x_adjust(u jsonb,k text,delta numeric) returns jsonb language plpgsql immutable set search_path='' as $$
declare p jsonb:=public._x_part(u,k);pos numeric:=(p->>'positive')::numeric;neg numeric:=(p->>'negative')::numeric;
begin
 if delta>=0 then pos:=pos+delta;else neg:=neg+delta;end if;
 u:=jsonb_set(u,'{powerLedger}',coalesce(u->'powerLedger','{}')||jsonb_build_object(k,jsonb_build_object('positive',pos,'negative',neg)),true);
 return jsonb_set(u,array[k],to_jsonb(pos+neg),true);
end $$;
create or replace function public._x_remove_buff(u jsonb,k text,amount numeric) returns jsonb language plpgsql immutable set search_path='' as $$
declare p jsonb:=public._x_part(u,k);pos numeric:=greatest(0,(p->>'positive')::numeric-amount);neg numeric:=(p->>'negative')::numeric;
begin
 u:=jsonb_set(u,'{powerLedger}',coalesce(u->'powerLedger','{}')||jsonb_build_object(k,jsonb_build_object('positive',pos,'negative',neg)),true);
 return jsonb_set(u,array[k],to_jsonb(pos+neg),true);
end $$;
create or replace function public._x_clean_parts(u jsonb,remove_positive boolean default false) returns jsonb language plpgsql immutable set search_path='' as $$
declare k text;p jsonb;pos numeric;neg numeric;
begin
 foreach k in array array['bonus','powerShift','copyOffset','reviveOffset'] loop
  p:=public._x_part(u,k);pos:=case when remove_positive then 0 else (p->>'positive')::numeric end;neg:=case when remove_positive then (p->>'negative')::numeric else 0 end;
  u:=jsonb_set(u,'{powerLedger}',coalesce(u->'powerLedger','{}')||jsonb_build_object(k,jsonb_build_object('positive',pos,'negative',neg)),true);
  u:=jsonb_set(u,array[k],to_jsonb(pos+neg),true);
 end loop;
 return u;
end $$;
create or replace function public._x_clean(u jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
begin u:=public._x_clean_parts(u);if coalesce((u->>'multiplier')::numeric,1)<1 then u:=jsonb_set(u,'{multiplier}','1'::jsonb);end if;return u;end $$;
create or replace function public._x_purge(u jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
begin
 u:=public._x_clean_parts(u,true)||jsonb_build_object('mutedEquipment',coalesce(u->'equipment','[]')||coalesce(u->'copiedEquipment','[]'),'equipmentMuted',false,'multiplier',least(1,coalesce((u->>'multiplier')::numeric,1)),'progress',0);
 if u ? 'greekBonusAmount' then u:=jsonb_set(u,'{greekBonusAmount}','0'::jsonb);end if;return u;
end $$;
create or replace function public._r_change(x jsonb,t text,id text,src text,amount numeric default 0,mult numeric default 1) returns jsonb language plpgsql immutable set search_path='' as $$
declare old_u jsonb:=public._r_unit(x->'s',t,id);new_u jsonb;recorded jsonb;
begin
 if old_u is null or amount<0 and public._x_block(x->'s',t,old_u,src,'reduce') then return x;end if;
 x:=public._r_change_before_remake(x,t,id,src,amount,mult);new_u:=public._r_unit(x->'s',t,id);
 if new_u is not null then
  recorded:=public._x_adjust(old_u,'bonus',coalesce((new_u->>'bonus')::numeric,0)-coalesce((old_u->>'bonus')::numeric,0));
  x:=public._r_set_unit(x,t,id,new_u||jsonb_build_object('powerLedger',recorded->'powerLedger'));
 end if;return x;
end $$;
do $ledger_hooks$
declare d text;a text;b text;
begin
 d:=pg_get_functiondef('public._x_resolve(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$u:=u||jsonb_build_object('powerShift',coalesce((u->>'powerShift')::numeric,0)+public._r_power(x->'s',team,v)-public._r_power(x->'s',t,u));$a$,$b$u:=public._x_adjust(u,'powerShift',public._r_power(x->'s',team,v)-public._r_power(x->'s',t,u));$b$);
 d:=replace(d,$a$u:=u||jsonb_build_object('powerShift',coalesce((u->>'powerShift')::numeric,0)+wanted-p);v:=v||jsonb_build_object('powerShift',coalesce((v->>'powerShift')::numeric,0)+p-wanted);$a$,$b$u:=public._x_adjust(u,'powerShift',wanted-p);v:=public._x_adjust(v,'powerShift',p-wanted);$b$);
 a:=$a$v:=v||jsonb_build_object('mutedEquipment',coalesce(v->'equipment','[]')||coalesce(v->'copiedEquipment','[]'),'equipmentMuted',false,'bonus',least(0,coalesce((v->>'bonus')::numeric,0)),'multiplier',least(1,coalesce((v->>'multiplier')::numeric,1)),'powerShift',least(0,coalesce((v->>'powerShift')::numeric,0)),'copyOffset',least(0,coalesce((v->>'copyOffset')::numeric,0)),'reviveOffset',least(0,coalesce((v->>'reviveOffset')::numeric,0)),'progress',0);$a$;
 d:=replace(d,a,'v:=public._x_purge(v);');execute d;
 d:=pg_get_functiondef('public._r_resolve(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$v:=v||jsonb_build_object('powerShift',coalesce((v->>'powerShift')::numeric,0)+delta);$a$,$b$v:=public._x_adjust(v,'powerShift',delta);$b$);execute d;
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 if position('''powerLedger'',coalesce(target' in d)=0 then
  d:=replace(d,$a$'copiedEquipment',coalesce(target->'equipment'$a$,$b$'powerLedger',coalesce(target->'powerLedger','{}')-'copyOffset'-'reviveOffset','mutedEquipment',coalesce(target->'mutedEquipment','[]'),'copiedEquipment',coalesce(target->'equipment'$b$);
 end if;execute d;
 d:=pg_get_functiondef('public._r_reconcile(jsonb)'::regprocedure);
 d:=replace(d,$a$(u||jsonb_build_object('bonus',coalesce((u->>'bonus')::numeric,0)-coalesce((u->>'greekBonusAmount')::numeric,0)))$a$,$b$public._x_remove_buff(u,'bonus',coalesce((u->>'greekBonusAmount')::numeric,0))$b$);execute d;
 d:=pg_get_functiondef('public._r_reconcile_before_remake(jsonb)'::regprocedure);
 d:=replace(d,$a$u:=u||jsonb_build_object('bonus',coalesce((u->>'bonus')::numeric,0)+3);$a$,$b$u:=public._x_adjust(u,'bonus',3);$b$);execute d;
end $ledger_hooks$;


-- Keep the un-clamped total available for exact copy/swap/rebirth assignments.
do $exact_power$
declare d text;raw_d text;
begin
 d:=pg_get_functiondef('public._r_power(jsonb,text,jsonb,integer)'::regprocedure);
 d:=replace(d,$a$if enemy>p then p:=p+8;end if;$a$,$b$if enemy>public._r_power(s,t,u,1) then p:=p+8;end if;$b$);
 d:=replace(d,$a$p:=greatest(0,floor(p+coalesce((u->>'powerShift')::numeric,0)));$a$,$b$p:=p+coalesce((u->>'powerShift')::numeric,0);$b$);
 execute d;
 raw_d:=replace(d,'FUNCTION public._r_power(','FUNCTION public._x_raw_power(');
 raw_d:=replace(raw_d,$a$p:=greatest(0,floor(p+coalesce((u->>'copyOffset')::numeric,0)+coalesce((u->>'reviveOffset')::numeric,0)));$a$,$b$p:=p+coalesce((u->>'copyOffset')::numeric,0)+coalesce((u->>'reviveOffset')::numeric,0);$b$);
 execute raw_d;
 d:=pg_get_functiondef('public._x_resolve(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$public._x_adjust(u,'powerShift',public._r_power(x->'s',team,v)-public._r_power(x->'s',t,u))$a$,$b$public._x_adjust(u,'powerShift',public._r_power(x->'s',team,v)-public._x_raw_power(x->'s',t,u,0))$b$);
 d:=replace(d,$a$public._x_adjust(u,'powerShift',wanted-p);v:=public._x_adjust(v,'powerShift',p-wanted)$a$,$b$public._x_adjust(u,'powerShift',wanted-public._x_raw_power(x->'s',t,u,0));v:=public._x_adjust(v,'powerShift',p-public._x_raw_power(x->'s',t,v,0))$b$);execute d;
 d:=pg_get_functiondef('public._r_resolve(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$public._x_adjust(v,'powerShift',delta)$a$,$b$public._x_adjust(v,'powerShift',(vals->>i)::numeric-public._x_raw_power(x->'s',team,v,0))$b$);execute d;
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$wanted-public._r_power(x->'s',t,v)$a$,$b$wanted-public._x_raw_power(x->'s',t,v,0)$b$);
 d:=replace(d,$a$snapshot-public._r_power(x->'s',t,u)$a$,$b$snapshot-public._x_raw_power(x->'s',t,u,0)$b$);execute d;
 d:=pg_get_functiondef('public._r_destroy(jsonb,text,jsonb,boolean)'::regprocedure);
 d:=replace(d,$a$3-public._r_power(x->'s',t,v)$a$,$b$3-public._x_raw_power(x->'s',t,v,0)$b$);execute d;
 d:=pg_get_functiondef('public._x_block(jsonb,text,jsonb,text,text)'::regprocedure);
 d:=replace(d,$a$if u ? 'guardOwner' and k in$a$,$b$if u ? 'guardOwner' and public._x_global(s,t,u) and k in$b$);execute d;
end $exact_power$;

-- Stable resurrection handler; it does not depend on variable names in older dispatchers.
create or replace function public._x_legacy_revive(x jsonb,e jsonb) returns jsonb
language plpgsql volatile set search_path='' as $$
declare t text:=e->>'team';owner_id text:=e->>'owner';selected text:=e->>'selection';
 g jsonb;fresh jsonb;old_ids jsonb;lane integer:=coalesce((e->>'lane')::integer,0);
begin
 if selected='skip' then return x;end if;
 if e->>'op'<>'anubis_revive' and public._r_unit(x->'s',t,e->>'uid') is null then return x;end if;
 select value into g from jsonb_array_elements(coalesce(x#>array['s',t,'grave'],'[]')) where value->>'uid'=selected limit 1;
 if g is null or not public._r_grave_ok(x,e,g) then raise exception 'Esta carta não pode ser ressuscitada.';end if;
 if not public._card_enabled(g->>'cardId') then return x;end if;
 x:=jsonb_set(x,array['s',t,'grave'],coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['s',t,'grave']) with ordinality a(value,ordinality) where value->>'uid'<>selected),'[]'),true);
 x:=public._r_grave_sync(x,t);
 select coalesce(jsonb_agg(value->'uid'),'[]') into old_ids from jsonb_array_elements(x#>array['s',t,'field']);
 x:=public._r_spawn(x,g->>'cardId',t,owner_id,lane,coalesce((g->>'progress')::integer,0));
 select value into fresh from jsonb_array_elements(x#>array['s',t,'field']) with ordinality a(value,ordinality)
  where not(old_ids ? (value->>'uid')) and value->>'playedBy'=owner_id order by ordinality desc limit 1;
 if fresh is not null then
  fresh:=public._x_memory(x->'s',fresh,g);
  if e->>'op'='anubis_revive' then
   fresh:=fresh||jsonb_build_object('reviveOffset',(e->>'wantedPower')::numeric-public._x_raw_power(x->'s',t,fresh,0));
  end if;
  x:=public._r_set_unit(x,t,fresh->>'uid',fresh);
 end if;
 return x;
end $$;

-- Optional legacy-copy calibrations remain compatible with the old dispatcher.
do $copy_calibration$
declare d text;
begin
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$wanted-public._r_power(x->'s',t,u)$a$,$b$wanted-public._x_raw_power(x->'s',t,u,0)$b$);
 execute d;
end $copy_calibration$;

-- Existing area attacks choose eligible units before applying their effects.
create or replace function public._r_resolve(x jsonb,e jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare t text:=e->>'team';enemy text:=public._r_other(t);u jsonb:=public._r_unit(x->'s',t,e->>'uid');v jsonb;g jsonb;team text;ids jsonb;op text:=e->>'op';selected text:=e->>'selection';r jsonb;owner_id text:=e->>'owner';list jsonb;vals jsonb;item jsonb;i integer;delta numeric;
begin
 if not public._r_enabled(x,e) then return x;end if;
 x:=jsonb_set(x,'{s,remakeSource}',to_jsonb(t),true);
 if op='remake' then x:=public._x_resolve(x,e);
 elsif op in ('revive','revive_cost','anubis_revive') then x:=public._x_legacy_revive(x,e);
 elsif op='destroy_two' then
  select coalesce(jsonb_agg(q->'uid'),'[]') into ids from (select value q from jsonb_array_elements(x#>array['s',enemy,'field']) where not public._x_block(x->'s',enemy,value,t,'destroy') order by random() limit 2) eligible;
  x:=public._r_visual(x,'lightning',enemy,ids);x:=public._r_destroy(x,enemy,ids);
 elsif op='hunt_monsters' then
  foreach team in array array[t,enemy] loop
   select coalesce(jsonb_agg(q->'uid'),'[]') into ids from (select value q from jsonb_array_elements(x#>array['s',team,'field']) where (public._r_card(public._r_identity(value))->'tags') ? 'monstro' and not public._x_block(x->'s',team,value,t,'destroy') order by public._r_power(x->'s',team,value) desc limit 2) eligible;
   x:=public._r_visual(x,'arrows',team,ids);x:=public._r_destroy(x,team,ids);
  end loop;
 elsif op='shuffle_lane' then
  list:='[]';foreach team in array array[t,enemy] loop for v in select value from jsonb_array_elements(x#>array['s',team,'field']) where value->>'lane'=selected and not public._r_protect(x->'s',team,(value->>'lane')::integer,t) loop list:=list||jsonb_build_array(jsonb_build_object('team',team,'uid',v->>'uid','power',public._r_power(x->'s',team,v)));end loop;end loop;
  select coalesce(jsonb_agg(value->'power' order by random()),'[]') into vals from jsonb_array_elements(list);
  for item,i in select value,ordinality::integer-1 from jsonb_array_elements(list) with ordinality loop team:=item->>'team';v:=public._r_unit(x->'s',team,item->>'uid');delta:=(vals->>i)::numeric-(item->>'power')::numeric;if delta>=0 or not public._x_block(x->'s',team,v,t,'reduce') then v:=public._x_adjust(v,'powerShift',(vals->>i)::numeric-public._x_raw_power(x->'s',team,v,0));x:=public._r_set_unit(x,team,v->>'uid',v);end if;end loop;
 elsif op='anubis' then
  v:=public._r_unit(x->'s',enemy,selected);
  if v is not null and not public._x_block(x->'s',enemy,v,t,'destroy') then
   delta:=public._r_power(x->'s',enemy,v);x:=public._r_destroy(x,enemy,jsonb_build_array(selected));
   if public._r_unit(x->'s',enemy,selected) is null then x:=public._r_evt(x,e-'selection'||jsonb_build_object('op','anubis_revive','wantedPower',delta));end if;
  end if;
 elsif op='steal' and public._x_block(x->'s',enemy,public._r_unit(x->'s',enemy,selected),t,'steal') then null;
 elsif op='steal_hand' and not exists(select 1 from jsonb_each(x->'r') where value->>'team'=enemy and (jsonb_array_length(coalesce(value->'hand','[]'))>0 or jsonb_array_length(coalesce(value->'deck','[]'))>0)) then
  select value into g from jsonb_array_elements(x#>array['s',enemy,'grave']) where public._r_card(value->>'cardId')<>'{}' and not coalesce((public._r_card(value->>'cardId')->>'specialOnly')::boolean,false) and public._x_grave_ok(x,e,value,false) order by random() limit 1;
  if g is not null then x:=jsonb_set(x,array['s',enemy,'grave'],coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['s',enemy,'grave']) with ordinality a(value,ordinality) where value->>'uid'<>g->>'uid'),'[]'),true);x:=public._r_grave_sync(x,enemy);x:=jsonb_set(x,array['r',owner_id,'hand'],(x#>array['r',owner_id,'hand'])||jsonb_build_array(g->'cardId'),true);end if;
 else x:=public._r_resolve_before_remake(x,e);
 end if;if op='equip' then v:=public._r_unit(x->'s',t,selected);if v is not null then v:=v||jsonb_build_object('equipmentOwners',coalesce(v->'equipmentOwners','{}')||jsonb_build_object(e->>'cardId',owner_id),'mutedEquipment',coalesce(v->'mutedEquipment','[]')-(e->>'cardId'));x:=public._r_set_unit(x,t,selected,v);end if;end if;return public._r_reconcile(x)#-'{s,remakeSource}';
end $$;


-- Faction/tag checks must use copied identities, just like Locations and auras do.
do $allied_identity$
declare d text;
begin
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$public._r_card(a->>'cardId')$a$,$b$public._r_card(public._r_identity(a))$b$);
 d:=replace(d,$a$a->>'cardId'='leonidas'$a$,$b$public._r_identity(a)='leonidas'$b$);
 d:=replace(d,$a$public._r_card(v->>'cardId')$a$,$b$public._r_card(public._r_identity(v))$b$);
 d:=replace(d,$a$v->>'cardId'='leonidas'$a$,$b$public._r_identity(v)='leonidas'$b$);execute d;
end $allied_identity$;

-- Ereshkigal forbids unit resurrection, not recovering/equipping non-unit cards.
create or replace function public._x_grave_ok(x jsonb,e jsonb,g jsonb,revive boolean default true) returns boolean language sql stable set search_path='' as $$
 select coalesce((g->>'lockedRound')::integer,0)<>coalesce((x#>>'{s,round}')::integer,1)
 and (not revive or public._r_card(g->>'cardId')->>'kind'<>'unit' or not exists(
  select 1 from jsonb_array_elements(x#>array['s',public._r_other(e->>'team'),'field']) v
  where v->>'lane'=e->>'lane' and public._x_rule(v)->>'op'='blockRevive' and public._r_active(x->'s',public._r_other(e->>'team'),v))) $$;

-- Round cleanup is simultaneous: record every final power before removing any aura.
create or replace function public._r_clear_round(s jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare x jsonb:=jsonb_build_object('s',s,'r','{}'::jsonb);z text;t text;snapshot jsonb:='{}';part jsonb;
begin
 foreach t in array array['player_one','player_two'] loop
  select coalesce(jsonb_object_agg(value->>'uid',public._r_power(s,t,value)),'{}') into part from jsonb_array_elements(coalesce(s#>array[t,'field'],'[]'));
  snapshot:=snapshot||part;
 end loop;
 x:=jsonb_set(x,'{s,clearRoundPowers}',snapshot,true);
 foreach z in array array['local','terrain','climate'] loop x:=public._x_discard_zone(x,z);end loop;
 return public._r_clear_round_before_audit44(x->'s')-'zoneCards'-'clearRoundPowers';
end $$;
do $round_power_snapshot$
declare d text;
begin
 d:=pg_get_functiondef('public._r_destroy(jsonb,text,jsonb,boolean)'::regprocedure);
 d:=replace(d,$a$death:=public._r_power(x->'s',t,u);$a$,$b$death:=case when not killed and coalesce(x#>'{s,clearRoundPowers}','{}') ? (u->>'uid') then (x#>>array['s','clearRoundPowers',u->>'uid'])::numeric else public._r_power(x->'s',t,u) end;$b$);
 execute d;
end $round_power_snapshot$;

do $acl$ declare f record;begin for f in select p.oid::regprocedure r from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (left(p.proname,3)='_x_' or p.proname like '%_before_audit44') loop execute 'revoke all on function '||f.r||' from public,anon,authenticated';end loop;end $acl$;
notify pgrst,'reload schema';
commit;
