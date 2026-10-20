// Character expansion: all choices use the normal authoritative effect queue.
const remakeRules=window.MythicRemakeRules||D.remakeRules||{};
const ruleFor=u=>remakeRules[ability(u)]||{};
const rowUnits=(x,t,l)=>x.s[t].field.filter(v=>v.lane===l);
const room=(x,t,l)=>rowUnits(x,t,l).length<Number(x.s.rowCapacity||Number.MAX_SAFE_INTEGER);
function localSilence(x,u){return Boolean(u&&((u.silencedJogadas||0)>0||u.silencedOwnerEnd));}
function remakeBonus(x,t,u){const r=ruleFor(u),c=C[identity(u)],row=rowUnits(x,t,u.lane);let b=0;
 if(active(x,t,u)&&r.op==='company'&&row.filter(v=>v!==u&&C[identity(v)]?.faction===r.faction).length>=r.count)b+=r.amount;
 if(active(x,t,u)&&r.op==='graveGrowth')b+=Math.floor(x.s[t].grave.filter(g=>C[g.cardId]?.kind==='unit').length/r.every);
 const used=new Set();for(const v of row){if(v===u||!active(x,t,v))continue;const a=ruleFor(v);if(a.faction!==c?.faction)continue;
  if(a.op==='aura'&&(!a.unique||!used.has(ability(v)))){b+=a.amount;used.add(ability(v));}
  if(a.op==='equipmentAura')b+=Math.min(a.max,(u.equipment||[]).length+(u.copiedEquipment||[]).length);
  if(a.op==='occupiedAura')b+=new Set(x.s[t].field.map(v=>v.lane)).size;
 }return b;
}
function remakeBlocked(x,t,u,from,kind){if(!u||from===t)return false;if(protectedRow(x,t,u.lane,from))return true;
 if(u.guardOwner&&['destroy','steal'].includes(kind))return true;
 return rowUnits(x,t,u.lane).some(v=>(v!==u||ruleFor(v).op==='protectMove')&&active(x,t,v)&&(
  kind==='move'&&ruleFor(v).op==='protectMove'||
  kind==='destroy'&&ruleFor(v).op==='protectDestroy'&&ruleFor(v).faction===C[identity(u)]?.faction||
  kind==='reduce'&&ruleFor(v).op==='protectReduction'&&ruleFor(v).faction===C[identity(u)]?.faction));
}
function remakeBeforeDestroy(x,t,u,from){if(remakeBlocked(x,t,u,from,'destroy'))return false;
 if(from!==t){const guardian=rowUnits(x,t,u.lane).find(v=>v!==u&&active(x,t,v)&&ruleFor(v).op==='saveOnce'&&!v.savedOnce&&ruleFor(v).faction===C[identity(u)]?.faction);if(guardian){guardian.savedOnce=true;visual(x,'shield',t,[u.uid]);return false;}}
 return true;
}
function remakeAfterDestroy(x,t,u,wasLive,killed){if(!killed)return;
 for(const v of rowUnits(x,t,u.lane)){const r=ruleFor(v);if(r.op==='mourning'&&active(x,t,v)&&!v.mourningUsed){v.mourningUsed=true;change(x,t,v,t,r.amount);}}
 if(wasLive&&ruleFor(u).op==='rebirth'&&!u.rebornOnce&&room(x,t,u.lane)){
  const grave=x.s[t].grave;const g=[...grave].reverse().find(v=>v.cardId===origin(u)&&v.owner===u.playedBy);if(g)x.s[t].grave=grave.filter(v=>v.uid!==g.uid);
  const fresh=spawn(x,u.cardId,t,u.playedBy,u.lane,0,true);fresh.rebornOnce=true;fresh.powerShift=3-power(x,t,fresh);syncGrave(x.s[t]);
 }
}
function remakeGraveAllowed(x,e,g,revive=true){if(g.lockedRound===x.s.round)return false;
 if(revive&&x.s[other(e.team)].field.some(v=>v.lane===e.lane&&ruleFor(v).op==='blockRevive'&&active(x,other(e.team),v)))return false;
 return true;
}
function remakeCleanse(u){if(u.bonus<0)u.bonus=0;if(u.powerShift<0)u.powerShift=0;if(u.multiplier<1)u.multiplier=1;if(u.copyOffset<0)u.copyOffset=0;if(u.reviveOffset<0)u.reviveOffset=0;}
function remakeUnsilence(x,u){delete u.silencedJogadas;delete u.silencedOwnerEnd;u.silenceExemptStamp=x.s.silenceStartedBy||null;}
function remakeDraw(x,e,n=1){const r=x.r[e.owner];while(n--&&r?.deck?.length)r.hand.push(r.deck.shift());}
function remakeNext(x,e,extra){event(x,'remake',e.team,e.owner,null,{...e,...extra,op:'remake',selection:undefined});}
function remakeOptions(x,e){const t=e.team,en=other(t),u=x.s[t].field.find(v=>v.uid===e.uid),r=e.rule||ruleFor(u),op=r.op;
 if(e.phase==='finish')return [option('confirm','Continuar a partida')];
 if(e.phase==='lane'){const v=x.s[e.targetTeam].field.find(v=>v.uid===e.targetUid);return v?[0,1,2].filter(l=>l!==v.lane&&room(x,e.targetTeam,l)).map(l=>option(l,'Fileira '+(l+1))):[];}
 if(e.phase==='order')return (e.remaining||[]).map((id,i)=>option(i,'Próxima: '+C[id]?.name,id));
 if(e.phase==='draft')return x.r[e.owner].deck.slice(0,r.count).map((id,i)=>option(i,C[id]?.name||id,id));
 if(e.phase==='shiva'){const targetTeam=e.targetTeam,list=x.s[targetTeam].field.filter(v=>v.uid!==e.uid&&!remakeBlocked(x,targetTeam,v,t,'destroy')),min=Math.min(Infinity,...list.map(v=>power(x,targetTeam,v)));return unitOptions(x,targetTeam,v=>list.includes(v)&&power(x,targetTeam,v)===min);}
 if(op==='choice'&&!e.phase)return [...(x.r[e.owner].deck.length?[option('draw','Comprar 1 carta')]:[]),...(rowUnits(x,t,e.lane).some(v=>v.uid!==e.uid)?[option('buff','Conceder +3 de poder')]:[])];
 if(op==='draft')return null;
 if(op==='reorder')return null;
 if(op==='recover'||op==='reviveQuiet'||op==='lockGrave'){
  const targetTeam=op==='lockGrave'?en:t;
  const list=x.s[targetTeam].grave.filter(g=>C[g.cardId]&&g.owner=== (op==='lockGrave'?g.owner:e.owner)&&remakeGraveAllowed(x,e,g,op==='reviveQuiet')&&!C[g.cardId].specialOnly&&(!r.kind||C[g.cardId].kind===r.kind)&&(!r.kinds||r.kinds.includes(C[g.cardId].kind))&&(!r.faction||C[g.cardId].faction===r.faction)&&(!r.max||C[g.cardId].power<=r.max)&&(op!=='reviveQuiet'||C[g.cardId].kind==='unit')&&(op!=='lockGrave'||C[g.cardId].kind==='unit')).map(g=>option(g.uid,C[g.cardId].name,g.cardId));return r.optional&&list.length?[...list,option('skip','Concluir')]:list;
 }
 if(['equipmentDestroy','equipmentReturn'].includes(op)){const list=x.s[en].field.flatMap(v=>remakeBlocked(x,en,v,t,'equipment')?[]:(v.equipment||[]).map((id,i)=>option(v.uid+':'+i,C[id]?.name+' · '+C[v.cardId]?.name,id)));return list.length?list:null;}
 const auto=['drawCompany','clones','wave','waveBoth','cleanseAll','graveDraw','shiva','grow'];if(auto.includes(op))return null;
 let targetTeam=['destroy','reduce','drainGrave','purge','silence','moveEnemy','steal'].includes(op)?en:t;
 if(op==='copyPower')return ['player_one','player_two'].flatMap(team=>unitOptions(x,team,v=>v.uid!==u.uid&&!remakeBlocked(x,team,v,t,'power')).map(o=>({...o,value:team+':'+o.value})));
 if(op==='moveSelf')return [option(u.uid,'Mover '+C[u.cardId].name,u.cardId),option('skip','Permanecer na fileira')];
 if(op==='drawMove'&&!e.phase)return null;
 if(op==='drawBuff'&&!e.phase)return null;
 if(op==='unsilenceDraw'&&!x.s[t].field.some(v=>v!==u&&!active(x,t,v)))return null;
 if(op==='sacrificeHunt'&&e.phase==='hunt')targetTeam=en;
 if(op==='steal'&&r.losing&&rowUnits(x,t,e.lane).reduce((n,v)=>n+power(x,t,v),0)>=rowUnits(x,en,e.lane).reduce((n,v)=>n+power(x,en,v),0))return [];
 const blockedKind=['moveEnemy'].includes(op)?'move':op==='steal'?'steal':['destroy','sacrificeHunt'].includes(op)?'destroy':['reduce','drainGrave','purge'].includes(op)?'reduce':'power';
 const choices=unitOptions(x,targetTeam,v=>v.uid!==e.uid&&!(e.chosen||[]).includes(v.uid)&&(!r.opposite||v.lane===e.lane)&&(!r.faction||C[identity(v)]?.faction===r.faction)&&(!r.max||power(x,targetTeam,v)<=r.max)&&!remakeBlocked(x,targetTeam,v,t,blockedKind)&&(
  (op==='rally'?v.lane!==e.lane:targetTeam===t&&!['moveAlly','drawMove','unsilenceDraw'].includes(op)?v.lane===e.lane:true))&&
  (op!=='sacrificeHunt'||e.phase!=='hunt'||power(x,targetTeam,v)<=e.wanted)&&
  (op!=='unsilenceDraw'||!active(x,t,v))&&
  (!['moveEnemy','moveAlly','drawMove'].includes(op)||[0,1,2].some(l=>l!==v.lane&&room(x,targetTeam,l)))&&
  (op!=='rally'||room(x,t,e.lane))&&
  (op!=='steal'||room(x,t,e.lane)));
 return r.optional&&choices.length?[...choices,option('skip','Concluir sem escolher')]:choices;
}
function remakeResolve(x,e){if(e.phase==='finish')return;const t=e.team,en=other(t),u=x.s[t].field.find(v=>v.uid===e.uid),r=e.rule||ruleFor(u),op=r.op,selected=e.selection,res=x.r[e.owner];
 const ally=x.s[t].field.find(v=>v.uid===selected),enemy=x.s[en].field.find(v=>v.uid===selected),target=enemy||ally;
 const follow=extra=>remakeNext(x,e,{rule:r,...extra});
 if(selected==='skip')return;
 if(e.phase==='lane'){const v=x.s[e.targetTeam].field.find(v=>v.uid===e.targetUid),l=Number(selected);if(v&&v.lane!==l&&room(x,e.targetTeam,l)&&!remakeBlocked(x,e.targetTeam,v,t,'move')){v.lane=l;if(r.amount&&(!r.faction||C[identity(v)]?.faction===r.faction))change(x,e.targetTeam,v,t,r.amount);}return;}
 if(e.phase==='order'){const remaining=[...e.remaining],id=remaining.splice(Number(selected),1)[0],ordered=[...(e.ordered||[]),id];if(remaining.length)follow({phase:'order',remaining,ordered});else{if(e.destination==='top')res.deck.unshift(...ordered);else res.deck.push(...ordered);if(e.drawAfter)remakeDraw(x,e);}return;}
 if(e.phase==='draft'){const top=res.deck.splice(0,r.count),chosen=top.splice(Number(selected),1)[0];if(chosen)res.hand.push(chosen);if(top.length)follow({phase:'order',remaining:top,ordered:[],destination:'bottom'});return;}
 if(e.phase==='shiva'){const v=x.s[e.targetTeam].field.find(v=>v.uid===selected);if(v)graveUnit(x,e.targetTeam,v,true,t);if(e.targetTeam===t)remakeShiva(x,e,en);return;}
 switch(op){
 case 'draft':follow({phase:'draft'});break;
 case 'reorder':{const top=res.deck.splice(0,r.count);if(top.length)follow({phase:'order',remaining:top,ordered:[],destination:'top',drawAfter:true});break;}
 case 'choice':if(!e.phase){if(selected==='draw')remakeDraw(x,e);else follow({phase:'buff',rule:{op:'buff',amount:3}});}break;
 case 'buff':if(ally)change(x,t,ally,t,r.amount);break;
 case 'recover':case 'reviveQuiet':case 'lockGrave':{const team=op==='lockGrave'?en:t,g=x.s[team].grave.find(g=>g.uid===selected);if(!g||!remakeGraveAllowed(x,e,g,op==='reviveQuiet'))break;
  if(op==='lockGrave'){g.lockedRound=x.s.round;if((e.chosen||[]).length+1<r.count)follow({chosen:[...(e.chosen||[]),g.uid]});break;}
  if(op==='reviveQuiet'&&!room(x,t,e.lane))break;
  x.s[team].grave=x.s[team].grave.filter(v=>v!==g);syncGrave(x.s[team]);if(op==='recover')res.hand.push(g.cardId);else spawn(x,g.cardId,t,e.owner,e.lane,0,true);break;}
 case 'drawCompany':remakeDraw(x,e);if(rowUnits(x,t,e.lane).some(v=>v!==u&&C[identity(v)]?.faction===r.faction))change(x,t,u,t,r.amount);break;
 case 'drawBuff':if(!e.phase){remakeDraw(x,e);follow({phase:'buff'});}else if(ally)change(x,t,ally,t,r.amount);break;
 case 'drawMove':if(!e.phase){remakeDraw(x,e);follow({phase:'move'});}else if(ally)follow({phase:'lane',targetTeam:t,targetUid:ally.uid});break;
 case 'moveAlly':case 'moveSelf':case 'moveEnemy':{const v=op==='moveEnemy'?enemy:ally;if(v&&!remakeBlocked(x,op==='moveEnemy'?en:t,v,t,'move'))follow({phase:'lane',targetTeam:op==='moveEnemy'?en:t,targetUid:v.uid});break;}
 case 'rally':if(ally&&ally.lane!==e.lane&&room(x,t,e.lane)){ally.lane=e.lane;change(x,t,ally,t,r.amount);}break;
 case 'bounce':if(ally){x.s[t].field=x.s[t].field.filter(v=>v!==ally);res.hand.push(origin(ally));for(const id of ally.equipment||[])x.s[t].grave.push({uid:uid(),cardId:id,owner:ally.equipmentOwners?.[id]||ally.playedBy,progress:0});syncGrave(x.s[t]);change(x,t,u,t,r.amount);}break;
 case 'steal':if(enemy&&!remakeBlocked(x,en,enemy,t,'steal')&&room(x,t,e.lane)){x.s[en].field=x.s[en].field.filter(v=>v!==enemy);enemy.lane=e.lane;enemy.playedBy=e.owner;x.s[t].field.push(enemy);visual(x,'hearts',t,[enemy.uid]);}break;
 case 'reduce':case 'drainGrave':if(enemy){const n=op==='drainGrave'?x.s[en].grave.filter(g=>C[g.cardId]?.kind==='unit').length:r.amount;change(x,en,enemy,t,-n);if(op==='reduce'&&(e.chosen||[]).length+1<(r.count||1))follow({chosen:[...(e.chosen||[]),selected]});}break;
 case 'wave':for(const v of rowUnits(x,en,r.fixedLane??e.lane))change(x,en,v,t,-r.amount);break;
 case 'waveBoth':for(const team of [t,en])for(const v of rowUnits(x,team,e.lane))if(v!==u)change(x,team,v,t,-r.amount);break;
 case 'destroy':if(enemy){const id=enemy.uid;graveUnit(x,en,enemy,true,t);if((r.costOnAttempt||!x.s[en].field.some(v=>v.uid===id))&&r.selfCost)change(x,t,u,t,-r.selfCost);}break;
 case 'sacrificeHunt':if(e.phase==='hunt'){if(enemy)graveUnit(x,en,enemy,true,t);}else if(ally){const wanted=power(x,t,ally);graveUnit(x,t,ally,true,t);if(!x.s[t].field.includes(ally))follow({phase:'hunt',wanted});}break;
 case 'sacrificeBuff':case 'sacrificeFeed':if(ally){const wanted=power(x,t,ally),victims=[...rowUnits(x,t,e.lane)];graveUnit(x,t,ally,true,t);if(!x.s[t].field.includes(ally)){if(op==='sacrificeFeed')change(x,t,u,t,Math.floor(wanted/2));else for(const v of victims)if(v!==ally&&x.s[t].field.includes(v))change(x,t,v,t,r.amount);}}break;
 case 'copyPower':{const split=String(selected).indexOf(':'),team=String(selected).slice(0,split),id=String(selected).slice(split+1),v=x.s[team]?.field.find(v=>v.uid===id);if(v)u.powerShift=(u.powerShift||0)+power(x,team,v)-power(x,t,u);break;}
 case 'swap':if(ally){const a=power(x,t,u),b=power(x,t,ally);u.powerShift=(u.powerShift||0)+b-a;ally.powerShift=(ally.powerShift||0)+a-b;}break;
 case 'purge':if(enemy&&!remakeBlocked(x,en,enemy,t,'reduce')){enemy.mutedEquipment=[...(enemy.equipment||[]),...(enemy.copiedEquipment||[])];enemy.bonus=Math.min(0,enemy.bonus||0);enemy.multiplier=Math.min(1,enemy.multiplier||1);enemy.powerShift=Math.min(0,enemy.powerShift||0);enemy.copyOffset=Math.min(0,enemy.copyOffset||0);enemy.reviveOffset=Math.min(0,enemy.reviveOffset||0);enemy.progress=0;}break;
 case 'cleanse':if(ally){remakeCleanse(ally);if(r.amount)change(x,t,ally,t,r.amount);if((e.chosen||[]).length+1<(r.count||1))follow({chosen:[...(e.chosen||[]),selected]});}break;
 case 'cleanseAll':for(const v of rowUnits(x,t,e.lane))if(v!==u&&C[identity(v)]?.faction===r.faction){remakeCleanse(v);remakeUnsilence(x,v);}break;
 case 'unsilenceDraw':if(ally)remakeUnsilence(x,ally);else remakeDraw(x,e);break;
 case 'silence':if(enemy&&!remakeBlocked(x,en,enemy,t,'silence')){if(r.ownerEnd)enemy.silencedOwnerEnd=true;else enemy.silencedJogadas=r.turns;enemy.silencedStamp=e.owner+':'+(res.turnsTaken||0);}break;
 case 'guard':if(ally)ally.guardOwner=e.owner;break;
 case 'equipmentDestroy':case 'equipmentReturn':{if(!selected){if(r.fallback)change(x,t,u,t,r.fallback);break;}const split=selected.lastIndexOf(':'),v=x.s[en].field.find(v=>v.uid===selected.slice(0,split)),i=Number(selected.slice(split+1));if(!v||remakeBlocked(x,en,v,t,'equipment'))break;const id=v.equipment.splice(i,1)[0];if(!id)break;if(op==='equipmentReturn'){const gearOwner=v.equipmentOwners?.[id]||v.playedBy;const owner=x.r[gearOwner]?gearOwner:Object.keys(x.r).find(owner=>x.r[owner].team===en);x.r[owner].hand.push(id);remakeDraw(x,e);}else{x.s[en].grave.push({uid:uid(),cardId:id,owner:v.equipmentOwners?.[id]||v.playedBy,progress:0});syncGrave(x.s[en]);}break;}
 case 'clones':for(let i=0;i<r.count&&room(x,t,e.lane);i++){const v=spawn(x,'clone-macaco',t,e.owner,e.lane,0,true);v.token=true;}break;
 case 'graveDraw':{const n=x.s[t].grave.filter(g=>C[g.cardId]?.kind==='unit').length;if(n)remakeDraw(x,e);if(n>=r.count)change(x,t,u,t,r.amount);break;}
 case 'shiva':remakeShiva(x,e,t);break;
 }
 reconcile(x);
}
function remakeShiva(x,e,team){const list=x.s[team].field.filter(v=>v.uid!==e.uid&&!remakeBlocked(x,team,v,e.team,'destroy')),min=Math.min(Infinity,...list.map(v=>power(x,team,v))),ties=list.filter(v=>power(x,team,v)===min);if(!ties.length){if(team===e.team)remakeShiva(x,e,other(team));return;}remakeNext(x,e,{rule:e.rule||ruleFor(x.s[e.team].field.find(v=>v.uid===e.uid)),phase:'shiva',targetTeam:team,choiceActor:ties[0].playedBy});}
function remakeStart(x,owner){for(const t of teams)for(const u of x.s[t].field)if(u.guardOwner===owner)delete u.guardOwner;}
function remakeEnd(x,owner){const res=x.r[owner],t=res.team,stamp=owner+':'+(res.turnsTaken||0);
 for(const u of x.s[t].field){const r=ruleFor(u);if(u.playedBy===owner&&active(x,t,u)&&r.op==='grow'&&(!r.company||rowUnits(x,t,u.lane).length>1)&&(!r.climate||x.s.sharedZones.climate))change(x,t,u,t,r.amount);}
 for(const team of teams)for(const u of x.s[team].field){if(u.silencedOwnerEnd&&u.playedBy===owner)delete u.silencedOwnerEnd;if(u.silencedJogadas&&u.silencedStamp!==stamp){u.silencedJogadas--;if(!u.silencedJogadas)delete u.silencedStamp;}}
}
