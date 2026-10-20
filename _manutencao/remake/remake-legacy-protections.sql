-- Existing area attacks choose eligible units before applying their effects.
create or replace function public._r_resolve(x jsonb,e jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare t text:=e->>'team';enemy text:=public._r_other(t);u jsonb:=public._r_unit(x->'s',t,e->>'uid');v jsonb;g jsonb;team text;ids jsonb;op text:=e->>'op';selected text:=e->>'selection';r jsonb;owner_id text:=e->>'owner';list jsonb;vals jsonb;item jsonb;i integer;delta numeric;
begin
 if not public._r_enabled(x,e) then return x;end if;
 x:=jsonb_set(x,'{s,remakeSource}',to_jsonb(t),true);
 if op='remake' then x:=public._x_resolve(x,e);
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
  for item,i in select value,ordinality::integer-1 from jsonb_array_elements(list) with ordinality loop team:=item->>'team';v:=public._r_unit(x->'s',team,item->>'uid');delta:=(vals->>i)::numeric-(item->>'power')::numeric;if delta>=0 or not public._x_block(x->'s',team,v,t,'reduce') then v:=v||jsonb_build_object('powerShift',coalesce((v->>'powerShift')::numeric,0)+delta);x:=public._r_set_unit(x,team,v->>'uid',v);end if;end loop;
 elsif op='anubis' and public._x_block(x->'s',enemy,public._r_unit(x->'s',enemy,selected),t,'destroy') then null;
 elsif op='steal' and public._x_block(x->'s',enemy,public._r_unit(x->'s',enemy,selected),t,'steal') then null;
 elsif op='steal_hand' and not exists(select 1 from jsonb_each(x->'r') where value->>'team'=enemy and (jsonb_array_length(coalesce(value->'hand','[]'))>0 or jsonb_array_length(coalesce(value->'deck','[]'))>0)) then
  select value into g from jsonb_array_elements(x#>array['s',enemy,'grave']) where public._r_card(value->>'cardId')<>'{}' and not coalesce((public._r_card(value->>'cardId')->>'specialOnly')::boolean,false) and public._x_grave_ok(x,e,value,false) order by random() limit 1;
  if g is not null then x:=jsonb_set(x,array['s',enemy,'grave'],coalesce((select jsonb_agg(value order by ordinality) from jsonb_array_elements(x#>array['s',enemy,'grave']) with ordinality a(value,ordinality) where value->>'uid'<>g->>'uid'),'[]'),true);x:=public._r_grave_sync(x,enemy);x:=jsonb_set(x,array['r',owner_id,'hand'],(x#>array['r',owner_id,'hand'])||jsonb_build_array(g->'cardId'),true);end if;
 else x:=public._r_resolve_before_remake(x,e);
 end if;if op='equip' then v:=public._r_unit(x->'s',t,selected);if v is not null then v:=v||jsonb_build_object('equipmentOwners',coalesce(v->'equipmentOwners','{}')||jsonb_build_object(e->>'cardId',owner_id),'mutedEquipment',coalesce(v->'mutedEquipment','[]')-(e->>'cardId'));x:=public._r_set_unit(x,t,selected,v);end if;end if;return public._r_reconcile(x)#-'{s,remakeSource}';
end $$;
