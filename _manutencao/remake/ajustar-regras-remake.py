from pathlib import Path
root=Path(__file__).resolve().parents[1];site=root/'outputs/Mythic-Clash-Completo'
for p in [root/'work/remake-engine-fragment.js',site/'abilities-engine.js']:
 s=p.read_text(encoding='utf-8')
 s=s.replace('Number(x.s.rowCapacity||12)','Number(x.s.rowCapacity||Number.MAX_SAFE_INTEGER)')
 old="if(['equipmentDestroy','equipmentReturn'].includes(op))return x.s[en].field.flatMap(v=>remakeBlocked(x,en,v,t,'equipment')?[]:(v.equipment||[]).map((id,i)=>option(v.uid+':'+i,C[id]?.name+' · '+C[v.cardId]?.name,id)));"
 new="if(['equipmentDestroy','equipmentReturn'].includes(op)){const list=x.s[en].field.flatMap(v=>remakeBlocked(x,en,v,t,'equipment')?[]:(v.equipment||[]).map((id,i)=>option(v.uid+':'+i,C[id]?.name+' · '+C[v.cardId]?.name,id)));return list.length?list:null;}"
 s=s.replace(old,new)
 s=s.replace("enemy.purgedBuffs=true;enemy.equipmentMuted=true;", "enemy.equipmentMuted=true;")
 s=s.replace("enemy.reviveOffset=Math.min(0,enemy.reviveOffset||0);}","enemy.reviveOffset=Math.min(0,enemy.reviveOffset||0);enemy.progress=0;const current=power(x,en,enemy),wanted=Math.min(current,C[identity(enemy)]?.power||0);enemy.powerShift=(enemy.powerShift||0)+wanted-current;}")
 s=s.replace("if(e.phase==='lane'){", "if(e.phase==='finish')return [option('confirm','Continuar a partida')];\n if(e.phase==='lane'){",1)
 s=s.replace("function remakeResolve(x,e){", "function remakeResolve(x,e){if(e.phase==='finish')return;")
 # Silence expires after end-of-turn effects, including Ra and Hercules.
 old="for(const team of teams)for(const u of x.s[team].field){if(u.silencedOwnerEnd&&u.playedBy===owner)delete u.silencedOwnerEnd;if(u.silencedJogadas&&u.silencedStamp!==stamp){u.silencedJogadas--;if(!u.silencedJogadas)delete u.silencedStamp;}}\n for(const u of x.s[t].field){const r=ruleFor(u);if(u.playedBy===owner&&active(x,t,u)&&r.op==='grow'&&(!r.company||rowUnits(x,t,u.lane).length>1)&&(!r.climate||x.s.sharedZones.climate))change(x,t,u,t,r.amount);}"
 new="for(const u of x.s[t].field){const r=ruleFor(u);if(u.playedBy===owner&&active(x,t,u)&&r.op==='grow'&&(!r.company||rowUnits(x,t,u.lane).length>1)&&(!r.climate||x.s.sharedZones.climate))change(x,t,u,t,r.amount);}\n for(const team of teams)for(const u of x.s[team].field){if(u.silencedOwnerEnd&&u.playedBy===owner)delete u.silencedOwnerEnd;if(u.silencedJogadas&&u.silencedStamp!==stamp){u.silencedJogadas--;if(!u.silencedJogadas)delete u.silencedStamp;}}"
 s=s.replace(old,new)
 s=s.replace("if(op==='reviveQuiet')", "if(op==='reviveQuiet')")
 p.write_text(s,encoding='utf-8')
p=site/'abilities-engine.js';s=p.read_text(encoding='utf-8')
s=s.replace("deathPower:p});", "deathPower:p,rebornOnce:Boolean(u.rebornOnce),rebornRound:x.s.round});")
s=s.replace("if(e.op==='anubis_revive'&&raised)", "if(raised&&g.rebornOnce&&g.rebornRound===x.s.round)raised.rebornOnce=true;if(e.op==='anubis_revive'&&raised)")
s=s.replace("else spawn(x,g.cardId,t,e.owner,e.lane,0,true);", "else {const raised=spawn(x,g.cardId,t,e.owner,e.lane,0,true);if(g.rebornOnce&&g.rebornRound===x.s.round)raised.rebornOnce=true;}")
s=s.replace("filter(g=>!C[g.cardId]?.specialOnly&&C[g.cardId])", "filter(g=>!C[g.cardId]?.specialOnly&&C[g.cardId]&&remakeGraveAllowed(x,e,g,false))")
s=s.replace("case 'destroy_strongest':{const max=Math.max(-1,...x.s[enemy].field.filter(u=>!protectedRow(x,enemy,u.lane,e.team))", "case 'destroy_strongest':{const max=Math.max(-1,...x.s[enemy].field.filter(u=>!remakeBlocked(x,enemy,u,e.team,'destroy'))")
s=s.replace("u=>!protectedRow(x,enemy,u.lane,e.team)&&power(x,enemy,u)===max", "u=>!remakeBlocked(x,enemy,u,e.team,'destroy')&&power(x,enemy,u)===max")
s=s.replace("case 'steal':return [...unitOptions(x,enemy,u=>!protectedRow(x,enemy,u.lane,e.team)&&power", "case 'steal':return [...unitOptions(x,enemy,u=>!remakeBlocked(x,enemy,u,e.team,'steal')&&power")
p.write_text(s,encoding='utf-8')
p=root/'work/remake-server.sql';s=p.read_text(encoding='utf-8').replace("coalesce((s->>'rowCapacity')::integer,12)","coalesce((s->>'rowCapacity')::integer,2147483647)")
s=s.replace("if phase='lane' then", "if phase='finish' then return jsonb_build_array(public._r_option('confirm','Continuar a partida'));end if;\n if phase='lane' then",1)
s=s.replace("e:=e||jsonb_build_object('rule',r);if sel='skip' then return x;end if;", "e:=e||jsonb_build_object('rule',r);if sel='skip' or phase='finish' then return x;end if;")
p.write_text(s,encoding='utf-8')
print('Ajustes de expiração, proteção e escolhas aplicados',flush=True)
