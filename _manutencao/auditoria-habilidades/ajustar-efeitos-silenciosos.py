from pathlib import Path
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
p=site/'abilities-engine.js';s=p.read_text(encoding='utf-8').replace("visual(x,'enter',t,[u.uid],{sourceCardId:id});", "visual(x,'enter',t,[u.uid],{sourceCardId:id,quiet});");p.write_text(s,encoding='utf-8')
p=site/'combat-fx.js';s=p.read_text(encoding='utf-8').replace("for(const e of entries)add(e.sourceCardId", "for(const e of entries)if(!e.quiet)add(e.sourceCardId");p.write_text(s,encoding='utf-8')
p=site/'supabase/migrations/202610200044_ability_interaction_audit.sql';s=p.read_text(encoding='utf-8')
extra="""
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
"""
if '$quiet_backup$' not in s:s=s.replace('do $acl$',extra+'\ndo $acl$')
p.write_text(s,encoding='utf-8')
p=site/'REVISAO-HABILIDADES.md';s=p.read_text(encoding='utf-8').replace('- **Retorno de tokens:**','- **Ressurreição sem entrada:** Dagda, Izanagi, Xipe e clones não exibem a vinheta de habilidade de entrada como se ela tivesse sido ativada. A aparição da unidade continua visível.\n- **Retorno de tokens:**');p.write_text(s,encoding='utf-8')
print('Quiet summons keep their visual entry without a false ability announcement.')
