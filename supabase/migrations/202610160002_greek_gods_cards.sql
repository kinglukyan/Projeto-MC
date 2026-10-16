begin;

-- Add the three Greek gods to server validation, game rules, gifts and tie-breaks.
do $$
declare
  routine record;
  definition text;
begin
  for routine in
    select p.oid
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prokind='f'
  loop
    definition:=pg_get_functiondef(routine.oid);
    if position('campo-troia' in definition)>0 or position('medusa' in definition)>0 then
      definition:=replace(definition,'''campo-troia'')','''campo-troia'',''poseidon'',''zeus'',''hades'')');
      definition:=replace(definition,'''medusa'')','''medusa'',''poseidon'',''zeus'',''hades'')');
      definition:=replace(definition,'''medusa'' then 4 else 0 end','''medusa'' then 4 when ''poseidon'' then 7 when ''zeus'' then 8 when ''hades'' then 7 else 0 end');
      definition:=replace(definition,'''medusa'' then 4 end','''medusa'' then 4 when ''poseidon'' then 7 when ''zeus'' then 8 when ''hades'' then 7 end');
      definition:=replace(definition,
        E'if card_id=''medusa'' then other_side:=jsonb_set(other_side,''{skipNextTurn}'',''true''::jsonb,true); end if;',
        E'if card_id=''medusa'' then other_side:=jsonb_set(other_side,''{skipNextTurn}'',''true''::jsonb,true); end if;\n      if card_id=''poseidon'' then\n        select coalesce(jsonb_agg(case when coalesce((value->>''lane'')::integer,0)=0 then jsonb_set(value,''{bonus}'',to_jsonb(coalesce((value->>''bonus'')::integer,0)-2),true) else value end order by ordinality),''[]''::jsonb) into ids from jsonb_array_elements(coalesce(other_side->''field'',''[]''::jsonb)) with ordinality e(value,ordinality);\n        other_side:=jsonb_set(other_side,''{field}'',ids,true);\n      elsif card_id=''zeus'' then\n        select coalesce(jsonb_agg(value order by ordinality),''[]''::jsonb) into ids from (select value,ordinality from jsonb_array_elements(coalesce(other_side->''field'',''[]''::jsonb)) with ordinality e(value,ordinality) order by public._online_unit_power(other_side,value,zones) desc limit 2) destroyed;\n        select coalesce(jsonb_agg(value order by ordinality),''[]''::jsonb) into field_array from jsonb_array_elements(coalesce(other_side->''field'',''[]''::jsonb)) with ordinality e(value,ordinality) where value not in (select value from (select value from jsonb_array_elements(coalesce(other_side->''field'',''[]''::jsonb)) with ordinality e(value,ordinality) order by public._online_unit_power(other_side,value,zones) desc limit 2) destroyed);\n        other_side:=jsonb_set(other_side,''{field}'',field_array,true);\n        other_side:=jsonb_set(other_side,''{underworld}'',coalesce(other_side->''underworld'',''[]''::jsonb)||coalesce((select jsonb_agg(value->>''cardId'') from jsonb_array_elements(ids) e(value)),''[]''::jsonb),true);\n      elsif card_id=''hades'' and jsonb_array_length(coalesce(side->''underworld'',''[]''::jsonb))>0 then\n        hand_array:=hand_array||jsonb_build_array(side->''underworld''->-1);\n        side:=jsonb_set(side,''{underworld}'',side->''underworld''-(jsonb_array_length(side->''underworld'')-1),true);\n      end if;');
      execute definition;
    end if;
  end loop;
end $$;

alter table public.player_decks alter column card_counts set default '{"soldado-esparta":3,"athena":2,"lobo-alfa":2,"guardiao-nordico":2,"mjolnir":1,"runas-nordicas":1,"grecia":1,"eclipse":2,"medusa":1,"poseidon":1,"zeus":1,"hades":1}'::jsonb;
update public.player_decks
set card_counts=card_counts||jsonb_build_object('poseidon',1,'zeus',1,'hades',1),updated_at=now()
where (select coalesce(sum(value::integer),0) from jsonb_each_text(card_counts))<=17;

alter table public.card_lore drop constraint if exists card_lore_card_id_check;
alter table public.card_lore add constraint card_lore_card_id_check check (card_id in ('soldado-esparta','athena','lobo-alfa','guardiao-nordico','mjolnir','runas-nordicas','grecia','eclipse','campo-troia','medusa','poseidon','zeus','hades'));

commit;
