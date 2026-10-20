from pathlib import Path
import re, json, shutil
root=Path(__file__).resolve().parents[1]
site=root/'outputs/Mythic-Clash-Completo'
p=site/'abilities-engine.js'
s=p.read_text(encoding='utf-8')
def sub(a,b):
 global s
 assert a in s,a[:120]
 s=s.replace(a,b)
sub("if(u.guardOwner===owner)delete u.guardOwner;if(u.silencedOwnerEnd", "if(u.silencedOwnerEnd")
sub("(!r.faction||C[identity(v)]?.faction===r.faction)&&(!r.max", "(!r.faction||op==='moveAlly'||C[identity(v)]?.faction===r.faction)&&(!r.max")
sub("case 'guard':if(ally)ally.guardOwner=e.owner;break;", "case 'guard':if(ally){ally.guardOwner=e.owner;ally.guardStamp=e.owner+':'+(res.turnsTaken||0);}break;")
# A replayed start phase must not expire a guard created during that same turn.
sub("function remakeStart(x,owner){for(const t of teams)for(const u of x.s[t].field)if(u.guardOwner===owner)delete u.guardOwner;}", "function remakeStart(x,owner){const stamp=owner+':'+(x.r[owner]?.turnsTaken||0);for(const t of teams)for(const u of x.s[t].field)if(u.guardOwner===owner&&u.guardStamp!==stamp){delete u.guardOwner;delete u.guardStamp;}}")
# Shiva chooses only on a tie; the allied invoker chooses their side, an enemy owner their side.
sub("remakeNext(x,e,{rule:e.rule||ruleFor(x.s[e.team].field.find(v=>v.uid===e.uid)),phase:'shiva',targetTeam:team,choiceActor:ties[0].playedBy});", "const next={...e,rule:e.rule||ruleFor(x.s[e.team].field.find(v=>v.uid===e.uid)),phase:'shiva',targetTeam:team,choiceActor:team===e.team?e.owner:ties[0].playedBy};if(ties.length===1){graveUnit(x,team,ties[0],true,e.team);if(team===e.team)remakeShiva(x,e,other(team));}else remakeNext(x,e,next);")
# Owner turns may never be negative/undefined; token returns disappear rather than becoming collectible cards.
sub("res.hand.push(origin(ally));for(const id", "if(!ally.token)res.hand.push(origin(ally));for(const id")
sub("fresh.powerShift=3-power(x,t,fresh)", "fresh.powerShift=Number(ruleFor(u).power||3)-power(x,t,fresh)")
# Revival metadata must follow the exact removed object, never a different identical card.
sub("if(g)x.s[t].grave=grave.filter(v=>v.uid!==g.uid);", "if(g)x.s[t].grave=grave.filter(v=>v.uid!==g.uid);")
# Resource consumption must not occur against a stale option list.
sub("if(!pending.options.some(v=>v.value===String(a.choice_value)))throw Error('Escolha inválida.');", "const legal=options(x,pending.event);if(!pending.options.some(v=>v.value===String(a.choice_value))||!legal?.some(v=>v.value===String(a.choice_value)))throw Error('Essa escolha não está mais disponível.');")
# A paused card cannot produce the whole engine context as a fake spawned unit.
sub("if(window.MythicAvailability?.isDisabled(id))return x;", "if(window.MythicAvailability?.isDisabled(id))return null;")
sub("v.token=true;", "if(v)v.token=true;")
# Track shared cards by the actual player, including in duos, and discard them on replacement/Round end.
sub("function spawn(x,id,t,owner,lane,progress=0,quiet=false)", "function discardZone(x,zone){const z=x.s.zoneCards?.[zone];if(z&&C[z.cardId]){x.s[z.team].grave.push({uid:uid(),cardId:z.cardId,owner:z.owner,progress:0});syncGrave(x.s[z.team]);}if(x.s.zoneCards)delete x.s.zoneCards[zone];}\nfunction spawn(x,id,t,owner,lane,progress=0,quiet=false)")
sub("x.s.zoneOwners[zone]=t;", "discardZone(x,zone);x.s.zoneCards=x.s.zoneCards||{};x.s.zoneCards[zone]={cardId:id,owner,team:t};x.s.zoneOwners[zone]=t;")
sub("x.s.sharedZones={local:null,terrain:null,climate:null};", "for(const zone of ['local','terrain','climate'])discardZone(x,zone);x.s.zoneCards={};x.s.sharedZones={local:null,terrain:null,climate:null};")
p.write_text(s,encoding='utf-8')

p=root/'work/remake-server.sql';s=p.read_text(encoding='utf-8')
s=s.replace("or r ? 'faction' and c->>'faction'<>r->>'faction' or r ? 'max' and p>", "or r ? 'faction' and op<>'moveAlly' and c->>'faction'<>r->>'faction' or r ? 'max' and p>")
s=s.replace("'choiceActor',v->>'playedBy'", "'choiceActor',case when team=t then e->>'owner' else v->>'playedBy' end")
s=s.replace("return public._x_next(x,e,jsonb_build_object('phase','shiva'", "if (select count(*) from jsonb_array_elements(x#>array['s',team,'field']) a where a->>'uid'<>e->>'uid' and not public._x_block(x->'s',team,a,t,'destroy') and public._r_power(x->'s',team,a)=mn)=1 then x:=public._r_destroy(x,team,jsonb_build_array(v->>'uid'));if team=t then return public._x_shiva(x,e,public._r_other(t));end if;return x;end if;\n return public._x_next(x,e,jsonb_build_object('phase','shiva'")
s=s.replace("jsonb_build_object('guardOwner',owner_id)", "jsonb_build_object('guardOwner',owner_id,'guardStamp',owner_id||':'||coalesce(x#>>array['r',owner_id,'turnsTaken'],'0'))")
s=s.replace("x:=jsonb_set(x,array['r',owner_id,'hand'],(x#>array['r',owner_id,'hand'])||jsonb_build_array(id),true);for id in", "if not coalesce((v->>'token')::boolean,false) then x:=jsonb_set(x,array['r',owner_id,'hand'],(x#>array['r',owner_id,'hand'])||jsonb_build_array(id),true);end if;for id in")
p.write_text(s,encoding='utf-8')
p=root/'work/remake-server-hooks.sql';s=p.read_text(encoding='utf-8')
s=s.replace("if u->>'guardOwner'=actor then u:=u-'guardOwner';end if;", "")
# start receives private resources with the current turn count
s=s.replace("where value->>'guardOwner'=actor loop", "where value->>'guardOwner'=actor and value->>'guardStamp' is distinct from actor||':'||coalesce(resources#>>array[actor,'turnsTaken'],'0') loop")
s=s.replace("v-'guardOwner'", "v-'guardOwner'-'guardStamp'")
p.write_text(s,encoding='utf-8')

# Incremental migration: replace reviewed helpers without importing cards again or renaming backups again.
base=(root/'work/remake-server.sql').read_text(encoding='utf-8')
hooks=(root/'work/remake-server-hooks.sql').read_text(encoding='utf-8')
names={'_x_options','_x_resolve','_x_shiva','_r_turn_start','_r_turn_end'}
defs=[]
for match in re.finditer(r'create or replace function public\.(\w+)\(.*?\$\$;',base+'\n'+hooks,re.S):
 if match.group(1) in names:defs.append(match.group())
audit='-- 044: Reviewed choices, guard duration, movement, and shared-zone ownership.\nbegin;\n'+'\n\n'.join(defs)+'\n'
extra=root/'work/ability-audit-zones.sql'
if extra.exists():audit+=extra.read_text(encoding='utf-8')
audit+="\ndo $acl$ declare f record;begin for f in select p.oid::regprocedure r from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (left(p.proname,3)='_x_' or p.proname like '%_before_audit44') loop execute 'revoke all on function '||f.r||' from public,anon,authenticated';end loop;end $acl$;\nnotify pgrst,'reload schema';\ncommit;\n"
(site/'supabase/migrations/202610200044_ability_interaction_audit.sql').write_text(audit,encoding='utf-8')
for n in ['remake-server.sql','remake-server-hooks.sql']:shutil.copy2(root/'work'/n,site/'_manutencao/remake'/n)
print('Native engine and incremental migration 044 updated.')
