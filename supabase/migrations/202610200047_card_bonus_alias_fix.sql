-- 047: corrige "column reference v is ambiguous" no cálculo de bônus.
-- Para a instalação existente, execute este arquivo após a 046.
-- Não altera poderes, critérios de bônus, placares ou resultados já gravados.
begin;
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
revoke all on function public._x_bonus(jsonb,text,jsonb) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
