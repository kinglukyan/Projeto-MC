from pathlib import Path
import re
site=Path(__file__).resolve().parents[2]
def read(p):return (site/p).read_text(encoding='utf-8-sig')
def write(p,s):(site/p).write_text(s,encoding='utf-8')
def routine(source,name):
 m=re.search(r'create or replace function public\.'+name+r'\(.*?end\s*;?\s*\$\$;',source,re.S)
 if not m:raise RuntimeError(name)
 return m.group()

if (site/'supabase/migrations/202610220054_ability_choices_and_bot_pacing.sql').exists():
 raise SystemExit('Migração 054 já preparada. As fontes já contêm o ritmo do bot; edite a migração existente para não aplicar a preparação duas vezes.')

# Patch current server definitions rather than restoring pre-audit ability functions.
pairs=[("x:=public._r_visual(x,'hearts',t,jsonb_build_array(sel))","x:=public._r_visual(x,'hearts',enemy,jsonb_build_array(sel))")]
field="jsonb_array_elements(x#>array['s',t,'field'])"
pairs.append((f"exists(select 1 from {field} v where v->>'uid'<>e->>'uid' and v->>'lane'=e->>'lane')",f"exists(select 1 from {field} as candidate54(unit) where candidate54.unit->>'uid'<>e->>'uid' and candidate54.unit->>'lane'=e->>'lane')"))
pairs.append((f"exists(select 1 from {field} v where v->>'uid'<>e->>'uid' and not public._r_active(x->'s',t,v))",f"exists(select 1 from {field} as candidate54(unit) where candidate54.unit->>'uid'<>e->>'uid' and not public._r_active(x->'s',t,candidate54.unit))"))
pairs.append((f"exists(select 1 from {field} v where v->>'uid'<>e->>'uid' and v->>'lane'=e->>'lane' and public._r_card(public._r_identity(v))->>'faction'=r->>'faction')",f"exists(select 1 from {field} as candidate54(unit) where candidate54.unit->>'uid'<>e->>'uid' and candidate54.unit->>'lane'=e->>'lane' and public._r_card(public._r_identity(candidate54.unit))->>'faction'=r->>'faction')"))
for team in ['t','enemy']:
 pairs.append((f"select sum(public._r_power(x->'s',{team},v)) from jsonb_array_elements(x#>array['s',{team},'field']) v where v->>'lane'=e->>'lane'",f"select sum(public._r_power(x->'s',{team},candidate54.unit)) from jsonb_array_elements(x#>array['s',{team},'field']) as candidate54(unit) where candidate54.unit->>'lane'=e->>'lane'"))
pairs.append(("select count(*) from jsonb_array_elements(x#>array['s',enemy,'grave']) g where g->>'owner'=public._r_unit(x->'s',enemy,sel)->>'playedBy' and public._r_card(g->>'cardId')->>'kind'='unit'","select count(*) from jsonb_array_elements(x#>array['s',enemy,'grave']) as grave54(entry) where grave54.entry->>'owner'=public._r_unit(x->'s',enemy,sel)->>'playedBy' and public._r_card(grave54.entry->>'cardId')->>'kind'='unit'"))
pairs.append(("select count(*) into i from jsonb_array_elements(x#>array['s',t,'grave']) g where g->>'owner'=owner_id and public._r_card(g->>'cardId')->>'kind'='unit'","select count(*) into i from jsonb_array_elements(x#>array['s',t,'grave']) as grave54(entry) where grave54.entry->>'owner'=owner_id and public._r_card(grave54.entry->>'cardId')->>'kind'='unit'"))
sql='''-- 054: ability choices, public option metadata and paced authoritative Atlas bot.
-- Apply after 053. No inventories, progression, printed powers or rewards are reset.
begin;
do $prerequisites$
begin
 if to_regprocedure('public._gc_finish(public.guardian_campaign_runs)') is null
  or to_regprocedure('public._match_reward(text,text)') is null then
  raise exception 'Aplique as migrações anteriores, incluindo 052 e 053, antes da 054.';
 end if;
end $prerequisites$;
do $choice_aliases$
declare routine record;definition text;updated text;
begin
 for routine in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' and p.proname in ('_x_options','_x_resolve') loop
  definition:=pg_get_functiondef(routine.oid);updated:=definition;
'''
for old,new in pairs:sql+='  updated:=replace(updated,$old$'+old+'$old$,$new$'+new+'$new$);\n'
sql+='''  if updated<>definition then execute updated;end if;
 end loop;
end $choice_aliases$;
'''
# Keep the maintained base sources aligned with the compatible changes above.
source=read('_manutencao/remake/remake-server.sql')
for old,new in pairs:source=source.replace(old,new)
write('_manutencao/remake/remake-server.sql',source)

engine_path='_manutencao/guardian-campaign/guardian-campaign-engine.sql'
engine=read(engine_path);drive=routine(engine,'_gc_drive');old_drive=drive
drive=drive.replace("if p->>'actor'<>'guardian-bot' then return x;end if;", """if p->>'actor'<>'guardian-bot' then return x;end if;
   if x#>>'{s,campaignBotStep}' is distinct from ('choice:'||(p->>'id')) then
    return jsonb_set(jsonb_set(x,'{s,campaignBotStep}',to_jsonb('choice:'||(p->>'id')),true),'{s,campaignBotDueAt}',to_jsonb(clock_timestamp()+interval '1 second'),true);
   end if;
   if clock_timestamp()<(x#>>'{s,campaignBotDueAt}')::timestamptz then return x;end if;
   x:=x#-'{s,campaignBotDueAt}'#-'{s,campaignBotStep}';""",1)
drive=drive.replace("a:=public._gc_pick_play(x,actor,level);", """if x#>>'{s,campaignBotStep}' is distinct from 'play' then
    return jsonb_set(jsonb_set(x,'{s,campaignBotStep}','"play"',true),'{s,campaignBotDueAt}',to_jsonb(clock_timestamp()+interval '2 seconds'),true);
   end if;
   if clock_timestamp()<(x#>>'{s,campaignBotDueAt}')::timestamptz then return x;end if;
   x:=x#-'{s,campaignBotDueAt}'#-'{s,campaignBotStep}';
   a:=public._gc_pick_play(x,actor,level);""",1)
engine=engine.replace(old_drive,drive,1);sql+='\n'+drive+'\n'
snapshot=routine(engine,'_gc_snapshot');old_snapshot=snapshot
snapshot=snapshot.replace("s:=s-'campaignRegion'", "s:=s-'campaignBotDueAt'-'campaignBotStep'-'campaignRegion'",1)
snapshot=snapshot.replace("'result',run.context#>'{s,campaignResult}'", "'result',run.context#>'{s,campaignResult}','botThinking',run.context#>>'{s,campaignBotDueAt}' is not null,'botWaitMs',case when run.context#>>'{s,campaignBotDueAt}' is null then 0 else greatest(0,ceil(extract(epoch from((run.context#>>'{s,campaignBotDueAt}')::timestamptz-clock_timestamp()))*1000))::integer end,'botStep',case when run.context#>>'{s,campaignBotStep}' like 'choice:%' then 'choice' else 'play' end",1)
engine=engine.replace(old_snapshot,snapshot,1);sql+='\n'+snapshot+'\n';write(engine_path,engine)

api_path='_manutencao/guardian-campaign/guardian-campaign-api.sql'
api=read(api_path);action=routine(api,'guardian_campaign_action');old_action=action
action=action.replace("('play','pass','resolve_effect','expire','surrender')","('play','pass','resolve_effect','expire','surrender','bot_tick')",1)
action=action.replace("if kind not in('expire','surrender')", "if kind not in('expire','surrender','bot_tick')",1)
action=action.replace("if kind='surrender' then", """if kind='bot_tick' then
  if (pending is not null and pending->>'actor' is distinct from 'guardian-bot') or (pending is null and x#>>'{s,campaignActor}' is distinct from 'guardian-bot') then raise exception 'Aguarde a vez do adversário.';end if;
  if x#>>'{s,campaignBotDueAt}' is not null and clock_timestamp()<(x#>>'{s,campaignBotDueAt}')::timestamptz then return public._gc_snapshot(run);end if;
 elsif kind='surrender' then""",1)
api=api.replace(old_action,action,1);sql+='\n'+action+'\n';write(api_path,api)
sql+='''
-- An owner sees the real cards in their own ability choices; spectators/opponents do not.
-- This enriches only existing legal options and never exposes either player's deck.
do $public_choices$
declare definition text;updated text;
begin
 definition:=pg_get_functiondef('public._audit_public_state(jsonb,text,uuid)'::regprocedure);
 if position('choice_metadata_v54' in definition)=0 then
  updated:=replace(definition,'return s;', $enrich$
   /* choice_metadata_v54 */
   if viewer_id is not null and pending->>'actor'=viewer_id::text and jsonb_typeof(pending->'options')='array' then
    s:=jsonb_set(s,'{pendingEffect,options}',coalesce((select jsonb_agg(opt.value||case when opt.value->>'cardId' is not null then jsonb_build_object('cardName',public._r_card(opt.value->>'cardId')->>'name','cardArt',public._r_card(opt.value->>'cardId')->>'art') else '{}'::jsonb end order by opt.ordinality) from jsonb_array_elements(pending->'options') with ordinality as opt(value,ordinality)),'[]'::jsonb),true);
   end if;
   return s;
  $enrich$);
  if updated<>definition then execute updated;end if;
 end if;
end $public_choices$;
revoke all on function public._gc_drive(jsonb,text,integer),public._gc_snapshot(public.guardian_campaign_runs) from public,anon,authenticated;
revoke all on function public.guardian_campaign_action(uuid,jsonb,integer,uuid) from public,anon;
grant execute on function public.guardian_campaign_action(uuid,jsonb,integer,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
'''
write('supabase/migrations/202610220054_ability_choices_and_bot_pacing.sql',sql)
print('Migração 054 e fontes do Atlas preparadas.')
