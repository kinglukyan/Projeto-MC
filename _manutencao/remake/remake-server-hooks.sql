-- Keep the previous effect dispatcher so old cards retain their rules.
do $backup_functions$
declare signature text;definition text;original_name text;
begin
 foreach signature in array array['_r_options(jsonb,jsonb)','_r_resolve(jsonb,jsonb)','_r_grave_ok(jsonb,jsonb,jsonb)','_r_change(jsonb,text,text,text,numeric,numeric)','_r_turn_start(jsonb,jsonb,text)','_r_turn_end(jsonb,text,text,integer)','_r_clear_round(jsonb)'] loop
  original_name:=split_part(signature,'(',1);
  if to_regprocedure('public.'||replace(signature,original_name,original_name||'_before_remake')) is null then
   definition:=pg_get_functiondef(('public.'||signature)::regprocedure);
   definition:=replace(definition,'FUNCTION public.'||original_name||'(','FUNCTION public.'||original_name||'_before_remake(');execute definition;
  end if;
 end loop;
end $backup_functions$;

create or replace function public._r_active(s jsonb,t text,u jsonb) returns boolean language sql stable set search_path='' as $$
 select not(coalesce((u->>'silencedJogadas')::integer,0)>0 or coalesce((u->>'silencedOwnerEnd')::boolean,false)) and
 (public._r_live(s) or coalesce(u->>'silenceExemptStamp'=s->>'silenceStartedBy',false) or coalesce(s->>'silenceTeam'=public._r_other(t) and public._r_shield(s,t,coalesce((u->>'lane')::integer,0)),false)) $$;

do $power_hooks$
declare d text;a text;b text;
begin
 d:=pg_get_functiondef('public._r_power(jsonb,text,jsonb,integer)'::regprocedure);
 if position('remake_power_v40' in d)=0 then
  a:='p:=coalesce((u->>''copiedBasePower'')::numeric,p)+coalesce((u->>''bonus'')::numeric,0);';
  b:=a||'p:=p+public._x_bonus(s,t,u); /* remake_power_v40 */';
  if position(a in d)=0 then raise exception 'Motor de poder incompatível com a coleção Remake.';end if;d:=replace(d,a,b);
  d:=replace(d,'if public._r_gear_compatible(gear,u) then','if public._r_gear_compatible(gear,u) and not(coalesce(u->''mutedEquipment'',''[]''::jsonb) ? gear) then');
  d:=replace(d,'for gear in select jsonb_array_elements_text(coalesce(u->''equipment'',''[]''::jsonb)||coalesce(u->''copiedEquipment'',''[]''::jsonb)) loop','for gear in select jsonb_array_elements_text(case when coalesce((u->>''equipmentMuted'')::boolean,false) then ''[]''::jsonb else coalesce(u->''equipment'',''[]''::jsonb)||coalesce(u->''copiedEquipment'',''[]''::jsonb) end) loop');
  d:=replace(d,'if id=''lukyan-rei-de-todos'' then p:=p*power(2::numeric,greatest(0,jsonb_array_length(a->''field'')-1));end if;','if id=''lukyan-rei-de-todos'' then p:=p+greatest(0,jsonb_array_length(a->''field'')-1);end if;');execute d;
 end if;
end $power_hooks$;

create or replace function public._r_change(x jsonb,t text,id text,src text,amount numeric default 0,mult numeric default 1) returns jsonb language plpgsql immutable set search_path='' as $$
begin if amount<0 and public._x_block(x->'s',t,public._r_unit(x->'s',t,id),src,'reduce') then return x;end if;return public._r_change_before_remake(x,t,id,src,amount,mult);end $$;
create or replace function public._r_grave_ok(x jsonb,e jsonb,g jsonb) returns boolean language sql stable set search_path='' as $$ select public._x_grave_ok(x,e,g) and public._r_grave_ok_before_remake(x,e,g) $$;
create or replace function public._r_options(x jsonb,e jsonb) returns jsonb language plpgsql stable set search_path='' as $$
declare result jsonb;v jsonb;team text:=public._r_other(e->>'team');k text;mn numeric;
begin
 if e->>'op'='remake' then return public._x_options(x,e);end if;
 if e->>'op'='destroy_strongest' then select max(public._r_power(x->'s',team,value)) into mn from jsonb_array_elements(x#>array['s',team,'field']) where not public._x_block(x->'s',team,value,e->>'team','destroy');select coalesce(jsonb_agg(public._r_option(value->>'uid',public._r_card(value->>'cardId')->>'name',value->>'cardId')),'[]') into result from jsonb_array_elements(x#>array['s',team,'field']) where public._r_power(x->'s',team,value)=mn and not public._x_block(x->'s',team,value,e->>'team','destroy');return result;end if;
 result:=public._r_options_before_remake(x,e);
 if e->>'op' in ('steal','anubis') then select coalesce(jsonb_agg(value order by ordinality),'[]') into result from jsonb_array_elements(result) with ordinality a(value,ordinality) where value->>'value'='skip' or not public._x_block(x->'s',team,public._r_unit(x->'s',team,value->>'value'),e->>'team',case when e->>'op'='anubis' then 'destroy' else 'steal' end);end if;
 return result;
end $$;

create or replace function public._r_destroy(x jsonb,t text,ids jsonb,killed boolean default true) returns jsonb language plpgsql volatile set search_path='' as $$
declare u jsonb;v jsonb;g jsonb;guard jsonb;r jsonb;gear text;original text;src text:=coalesce(x#>>'{s,remakeSource}',public._r_other(t));fresh_id text;was_live boolean;grave_id text;death numeric;
begin
 for u in select value from jsonb_array_elements(coalesce(x#>array['s',t,'field'],'[]'::jsonb)) where ids ? (value->>'uid') loop
  if public._r_unit(x->'s',t,u->>'uid') is null then continue;end if;
  if killed and public._x_block(x->'s',t,u,src,'destroy') then continue;end if;
  if killed and src<>t then
   select value into guard from jsonb_array_elements(x#>array['s',t,'field']) v where value->>'uid'<>u->>'uid' and value->>'lane'=u->>'lane' and public._r_active(x->'s',t,value) and public._x_rule(value)->>'op'='saveOnce' and not coalesce((value->>'savedOnce')::boolean,false) and public._x_rule(value)->>'faction'=public._r_card(public._r_identity(u))->>'faction' limit 1;
   if guard is not null then x:=public._r_set_unit(x,t,guard->>'uid',guard||jsonb_build_object('savedOnce',true));x:=public._r_visual(x,'shield',t,jsonb_build_array(u->>'uid'));continue;end if;
  end if;
  was_live:=public._r_active(x->'s',t,u);death:=public._r_power(x->'s',t,u);
  x:=jsonb_set(x,array['s',t,'field'],coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['s',t,'field']) with ordinality a(value,ordinality) where value->>'uid'<>u->>'uid'),'[]'),true);
  if coalesce((u->>'token')::boolean,false) then if killed then for v in select value from jsonb_array_elements(x#>array['s',t,'field']) where value->>'lane'=u->>'lane' loop if public._x_rule(v)->>'op'='mourning' and public._r_active(x->'s',t,v) and not coalesce((v->>'mourningUsed')::boolean,false) then x:=public._r_set_unit(x,t,v->>'uid',v||jsonb_build_object('mourningUsed',true));x:=public._r_change(x,t,v->>'uid',t,4);end if;end loop;end if;continue;end if;
  if killed then x:=public._r_visual(x,'destroy',t,jsonb_build_array(u->>'uid'));end if;
  original:=coalesce(u->>'eclipseOriginalCardId',u->>'sourceCardId',case when u->>'cardId'='lukyan-rei-de-todos' then 'lukyan' else u->>'cardId' end);grave_id:=gen_random_uuid()::text;
  g:=jsonb_build_object('uid',grave_id,'cardId',original,'owner',u->>'playedBy','progress',coalesce((u->>'progress')::integer,0),'deathPower',death,'rebornOnce',coalesce((u->>'rebornOnce')::boolean,false),'savedOnce',coalesce((u->>'savedOnce')::boolean,false),'mourningUsed',coalesce((u->>'mourningUsed')::boolean,false),'rebornRound',x#>'{s,round}');
  x:=jsonb_set(x,array['s',t,'grave'],coalesce(x#>array['s',t,'grave'],'[]')||jsonb_build_array(g),true);
  for gear in select jsonb_array_elements_text(coalesce(u->'equipment','[]')) loop x:=jsonb_set(x,array['s',t,'grave'],(x#>array['s',t,'grave'])||jsonb_build_array(jsonb_build_object('uid',gen_random_uuid()::text,'cardId',gear,'owner',coalesce(u#>>array['equipmentOwners',gear],u->>'playedBy'),'progress',0)),true);end loop;
  if killed and was_live and public._r_id(u)='osiris' then x:=public._r_evt(x,jsonb_build_object('op','osiris','team',t,'owner',u->>'playedBy','lane',u->'lane','shielded',public._r_shield(x->'s',t,(u->>'lane')::integer)));end if;
  if killed then
   for v in select value from jsonb_array_elements(x#>array['s',t,'field']) where value->>'lane'=u->>'lane' loop
    if public._x_rule(v)->>'op'='mourning' and public._r_active(x->'s',t,v) and not coalesce((v->>'mourningUsed')::boolean,false) then x:=public._r_set_unit(x,t,v->>'uid',v||jsonb_build_object('mourningUsed',true));x:=public._r_change(x,t,v->>'uid',t,4);end if;
   end loop;
   if was_live and public._x_rule(u)->>'op'='rebirth' and not coalesce((u->>'rebornOnce')::boolean,false) and public._x_room(x->'s',t,(u->>'lane')::integer) then
    x:=jsonb_set(x,array['s',t,'grave'],coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['s',t,'grave']) with ordinality a(value,ordinality) where value->>'uid'<>grave_id),'[]'),true);
    x:=public._x_quiet(x,u->>'cardId',t,u->>'playedBy',(u->>'lane')::integer);
    select value into v from jsonb_array_elements(x#>array['s',t,'field']) with ordinality a(value,ordinality) where value->>'cardId'=u->>'cardId' and value->>'playedBy'=u->>'playedBy' order by ordinality desc limit 1;
    v:=v||jsonb_build_object('rebornOnce',true,'powerShift',3-public._r_power(x->'s',t,v));x:=public._r_set_unit(x,t,v->>'uid',v);
   end if;
  end if;
 end loop;return public._r_grave_sync(x,t);
end $$;

create or replace function public._r_resolve(x jsonb,e jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare u jsonb:=public._r_unit(x->'s',e->>'team',e->>'uid');v jsonb;team text:=public._r_other(e->>'team');
begin
 if e->>'op'='remake' and not public._r_enabled(x,e) then return x;end if;
 x:=jsonb_set(x,'{s,remakeSource}',to_jsonb(e->>'team'),true);
 if e->>'op'='remake' then x:=public._x_resolve(x,e);
 else
  if e->>'op'='steal' and public._x_block(x->'s',team,public._r_unit(x->'s',team,e->>'selection'),e->>'team','steal') then return x#-'{s,remakeSource}';end if;
  x:=public._r_resolve_before_remake(x,e);
 end if;return x#-'{s,remakeSource}';
end $$;

do $drain_actor$
declare d text;
begin d:=pg_get_functiondef('public._r_drain(jsonb,boolean)'::regprocedure);d:=replace(d,'''actor'',e->>''owner''','''actor'',coalesce(e->>''choiceActor'',e->>''owner'')');execute d;end $drain_actor$;

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

create or replace function public._r_clear_round(s jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare t text;
begin s:=public._r_clear_round_before_remake(s);foreach t in array array['player_one','player_two'] loop s:=jsonb_set(s,array[t,'grave'],coalesce((select jsonb_agg(value-'lockedRound'-'rebornOnce'-'rebornRound'-'savedOnce'-'mourningUsed' order by ordinality) from jsonb_array_elements(coalesce(s#>array[t,'grave'],'[]')) with ordinality a(value,ordinality)),'[]'),true);end loop;return s;end $$;

do $revive_state$
declare d text;a text;b text;
begin
 d:=pg_get_functiondef('public._r_resolve_before_remake(jsonb,jsonb)'::regprocedure);
 a:='x:=public._r_spawn(x,cid,t,owner_id,lane,coalesce((g->>''progress'')::integer,0));';
 b:=a||'if coalesce((g->>''rebornOnce'')::boolean,false) and g->>''rebornRound''=x#>>''{s,round}'' then select value into v from jsonb_array_elements(x#>array[''s'',t,''field'']) with ordinality a(value,ordinality) where value->>''cardId''=cid and value->>''playedBy''=owner_id order by ordinality desc limit 1;if v is not null then x:=public._r_set_unit(x,t,v->>''uid'',v||jsonb_build_object(''rebornOnce'',true));end if;end if;';
 if position(b in d)=0 then d:=replace(d,a,b);end if;
 d:=replace(d,'(public._r_card(a->>''cardId'')->''tags'') ?| array[''heroi'',''soldado'',''espartano'']','((public._r_card(a->>''cardId'')->''tags'') ?| array[''heroi'',''soldado'',''espartano''] or public._r_card(a->>''cardId'')->>''characterClass''=''Herói'')');
 execute d;
end $revive_state$;
