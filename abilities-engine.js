(() => {
'use strict';
const D=window.MythicAbilitiesData,C=Object.fromEntries(D.cards.map(c=>[c.id,c]));
const teams=['player_one','player_two'],other=t=>t==='player_one'?'player_two':'player_one';
const uid=()=>crypto.randomUUID(),copy=x=>JSON.parse(JSON.stringify(x));
const random=n=>{if(n<1)return 0;const a=new Uint32Array(1),limit=Math.floor(4294967296/n)*n;do{crypto.getRandomValues(a);}while(a[0]>=limit);return a[0]%n;};
const shuffled=a=>{a=[...a];for(let i=a.length-1;i>0;i--){const j=random(i+1);[a[i],a[j]]=[a[j],a[i]];}return a;};
const ability=u=>u.copiedAbilityId||u.cardId,live=s=>s.silenceTurns!==undefined?Number(s.silenceTurns)<=0:Number(s.round||1)>Number(s.silenceUntilRound||0);
const vampire=id=>String(id||'').startsWith('vampir')||id==='dracula';
const origin=u=>u.eclipseOriginalCardId||u.sourceCardId||(u.cardId==='lukyan-rei-de-todos'?'lukyan':u.cardId);
function init(x){const s=x.s;s.effectQueue=s.effectQueue||[];s.sharedZones=s.sharedZones||{};s.zoneOwners=s.zoneOwners||{};for(const t of teams){const a=s[t];a.field=a.field||[];a.underworld=a.underworld||[];a.grave=a.grave||a.underworld.map((id,i)=>({uid:'legacy:'+t+':'+i,cardId:id,owner:x.legacyOwners?.[t]||null,progress:0}));for(const u of a.field){u.uid=u.uid||uid();u.bonus=Number(u.bonus)||0;u.lane=Number(u.lane)||0;u.multiplier=Number(u.multiplier)||1;u.equipment=u.equipment||[];u.playedBy=u.playedBy||x.legacyOwners?.[t]||null;}syncGrave(a);}return x;}
function syncGrave(a){a.underworld=a.grave.map(g=>g.cardId);}
const identity=u=>u.copiedFrom||u.cardId;
function shield(x,t,lane){return x.s[t].field.some(u=>u.lane===lane&&ability(u)==='heimdall'&&!localSilence(x,u)&&(live(x.s)||x.s.silenceTeam===other(t)||(u.silenceExemptStamp&&u.silenceExemptStamp===x.s.silenceStartedBy)));}
function globalActive(x,t,u){return live(x.s)||(u?.silenceExemptStamp&&u.silenceExemptStamp===x.s.silenceStartedBy)||Boolean(u&&x.s.silenceTeam===other(t)&&shield(x,t,u.lane));}
function protectedRow(x,t,lane,from){return from!==t&&shield(x,t,lane);}
function active(x,t,u){return !localSilence(x,u)&&globalActive(x,t,u);}
function enabledEvent(x,e){const u=x.s[e.team]?.field.find(v=>v.uid===e.uid);return u?active(x,e.team,u):live(x.s)||Boolean(e.shielded&&shield(x,e.team,e.lane))||e.op==='equip'&&x.s[e.team].field.some(v=>active(x,e.team,v));}
const gravePower=g=>Number.isFinite(g.deathPower)?g.deathPower:Number(C[g.cardId]?.power)||0;

// Character expansion: all choices use the normal authoritative effect queue.
const remakeRules=window.MythicRemakeRules||D.remakeRules||{};
const ruleFor=u=>remakeRules[ability(u)]||{};
const rowUnits=(x,t,l)=>x.s[t].field.filter(v=>v.lane===l);
const room=(x,t,l)=>rowUnits(x,t,l).length<Number(x.s.rowCapacity||Number.MAX_SAFE_INTEGER);
function localSilence(x,u){return Boolean(u&&((u.silencedJogadas||0)>0||u.silencedOwnerEnd));}
function remakeBonus(x,t,u){const r=ruleFor(u),c=C[identity(u)],row=rowUnits(x,t,u.lane);let b=0;
 if(active(x,t,u)&&r.op==='company'&&row.filter(v=>v!==u&&C[identity(v)]?.faction===r.faction).length>=r.count)b+=r.amount;
 if(active(x,t,u)&&r.op==='graveGrowth')b+=Math.floor(x.s[t].grave.filter(g=>g.owner===u.playedBy&&C[g.cardId]?.kind==='unit').length/r.every);
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
  const list=x.s[targetTeam].grave.filter(g=>C[g.cardId]&&!window.MythicAvailability?.isDisabled(g.cardId)&&g.owner=== (op==='lockGrave'?g.owner:e.owner)&&remakeGraveAllowed(x,e,g,op==='reviveQuiet')&&!C[g.cardId].specialOnly&&(!r.kind||C[g.cardId].kind===r.kind)&&(!r.kinds||r.kinds.includes(C[g.cardId].kind))&&(!r.faction||C[g.cardId].faction===r.faction)&&(!r.max||C[g.cardId].power<=r.max)&&(op!=='reviveQuiet'||C[g.cardId].kind==='unit')&&(op!=='lockGrave'||C[g.cardId].kind==='unit')).map(g=>option(g.uid,C[g.cardId].name,g.cardId));return r.optional&&list.length?[...list,option('skip','Concluir')]:list;
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
  x.s[team].grave=x.s[team].grave.filter(v=>v!==g);syncGrave(x.s[team]);if(op==='recover')res.hand.push(g.cardId);else {const raised=spawn(x,g.cardId,t,e.owner,e.lane,0,true);if(raised?.uid&&g.rebornRound===x.s.round)for(const key of ['rebornOnce','savedOnce','mourningUsed'])if(g[key])raised[key]=true;}break;}
 case 'drawCompany':remakeDraw(x,e);if(rowUnits(x,t,e.lane).some(v=>v!==u&&C[identity(v)]?.faction===r.faction))change(x,t,u,t,r.amount);break;
 case 'drawBuff':if(!e.phase){remakeDraw(x,e);follow({phase:'buff'});}else if(ally)change(x,t,ally,t,r.amount);break;
 case 'drawMove':if(!e.phase){remakeDraw(x,e);follow({phase:'move'});}else if(ally)follow({phase:'lane',targetTeam:t,targetUid:ally.uid});break;
 case 'moveAlly':case 'moveSelf':case 'moveEnemy':{const v=op==='moveEnemy'?enemy:ally;if(v&&!remakeBlocked(x,op==='moveEnemy'?en:t,v,t,'move'))follow({phase:'lane',targetTeam:op==='moveEnemy'?en:t,targetUid:v.uid});break;}
 case 'rally':if(ally&&ally.lane!==e.lane&&room(x,t,e.lane)){ally.lane=e.lane;change(x,t,ally,t,r.amount);}break;
 case 'bounce':if(ally){x.s[t].field=x.s[t].field.filter(v=>v!==ally);res.hand.push(origin(ally));for(const id of ally.equipment||[])x.s[t].grave.push({uid:uid(),cardId:id,owner:ally.equipmentOwners?.[id]||ally.playedBy,progress:0});syncGrave(x.s[t]);change(x,t,u,t,r.amount);}break;
 case 'steal':if(enemy&&!remakeBlocked(x,en,enemy,t,'steal')&&room(x,t,e.lane)){x.s[en].field=x.s[en].field.filter(v=>v!==enemy);enemy.lane=e.lane;enemy.playedBy=e.owner;x.s[t].field.push(enemy);visual(x,'hearts',t,[enemy.uid]);}break;
 case 'reduce':case 'drainGrave':if(enemy){const n=op==='drainGrave'?x.s[en].grave.filter(g=>g.owner===enemy.playedBy&&C[g.cardId]?.kind==='unit').length:r.amount;change(x,en,enemy,t,-n);if(op==='reduce'&&(e.chosen||[]).length+1<(r.count||1))follow({chosen:[...(e.chosen||[]),selected]});}break;
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
 case 'graveDraw':{const n=x.s[t].grave.filter(g=>g.owner===e.owner&&C[g.cardId]?.kind==='unit').length;if(n)remakeDraw(x,e);if(n>=r.count)change(x,t,u,t,r.amount);break;}
 case 'shiva':remakeShiva(x,e,t);break;
 }
 reconcile(x);
}
function remakeShiva(x,e,team){const list=x.s[team].field.filter(v=>v.uid!==e.uid&&!remakeBlocked(x,team,v,e.team,'destroy')),min=Math.min(Infinity,...list.map(v=>power(x,team,v))),ties=list.filter(v=>power(x,team,v)===min);if(!ties.length){if(team===e.team)remakeShiva(x,e,other(team));return;}remakeNext(x,e,{rule:e.rule||ruleFor(x.s[e.team].field.find(v=>v.uid===e.uid)),phase:'shiva',targetTeam:team,choiceActor:ties[0].playedBy});}
function remakeStart(x,owner){for(const t of teams)for(const u of x.s[t].field)if(u.guardOwner===owner)delete u.guardOwner;}
function remakeEnd(x,owner){const res=x.r[owner],t=res.team,stamp=owner+':'+(res.turnsTaken||0);
 for(const u of x.s[t].field){const r=ruleFor(u);if(u.playedBy===owner&&active(x,t,u)&&r.op==='grow'&&(!r.company||rowUnits(x,t,u.lane).length>1)&&(!r.climate||x.s.sharedZones.climate))change(x,t,u,t,r.amount);}
 for(const team of teams)for(const u of x.s[team].field){if(u.guardOwner===owner)delete u.guardOwner;if(u.silencedOwnerEnd&&u.playedBy===owner)delete u.silencedOwnerEnd;if(u.silencedJogadas&&u.silencedStamp!==stamp){u.silencedJogadas--;if(!u.silencedJogadas)delete u.silencedStamp;}}
}

function terrainBonus(id,c){for(const r of D.terrain[id]||[]){if(r.ids&&!r.ids.includes(c.id))continue;if(r.faction&&r.faction!==c.faction)continue;if(r.excludeIds?.includes(c.id))continue;if(r.tagsAny&&!r.tagsAny.some(v=>(c.tags||[]).includes(v)))continue;return r.bonus;}return 0;}
function power(x,t,u,depth=0){const s=x.s,a=s[t],c=C[identity(u)]||{power:0},id=ability(u);let p=Number(c.power)||0;if(!globalActive(x,t,u))return Number(C[u.cardId]?.power)||0;const own=active(x,t,u);
 p=Number.isFinite(u.copiedBasePower)?u.copiedBasePower:p;p+=Number(u.bonus)||0;p+=remakeBonus(x,t,u);if(own&&id==='lukyan'&&a.field.some(v=>v.uid!==u.uid&&v.lane===u.lane))p+=3;if(id==='hercules')p+=Math.min(12,Number(u.progress)||0);
 for(const equipment of (u.equipmentMuted?[]:[...(u.equipment||[]),...(u.copiedEquipment||[])]).filter(id=>!(u.mutedEquipment||[]).includes(id))){const r=D.equipment[equipment];if(r&&(r.ids?r.ids.includes(identity(u)):r.faction===c.faction))p+=r.bonus;}
 if(own&&['soldado-esparta','guardiao-nordico'].includes(id)){const count=a.field.filter(v=>identity(v)===id&&v.uid!==u.uid&&v.lane===u.lane).length;p*=2**count;}
 if(own&&id==='lobo-alfa')p+=2*a.field.filter(v=>identity(v)==='lobo-beta'&&v.lane===u.lane).length;
 p+=2*a.field.filter(v=>v!==u&&ability(v)==='athena'&&active(x,t,v)&&v.lane===u.lane).length;
 if(own&&id==='lobo-omega'&&depth===0&&a.field.filter(v=>v.lane===u.lane).length===1){const enemy=x.s[other(t)].field.filter(v=>v.lane===u.lane).reduce((n,v)=>n+power(x,other(t),v,1),0);if(enemy>p)p+=8;}
 if(own&&id==='mulher')p*=2**a.field.filter(v=>identity(v)==='homem'&&v.lane===u.lane).length;
 if(own&&id==='homem')p*=2**a.field.filter(v=>v.uid!==u.uid&&identity(v)==='homem'&&v.lane===u.lane).length;
 p*=(Number(u.multiplier)||1)*2**a.field.filter(v=>ability(v)==='apolo'&&active(x,t,v)&&v.lane===u.lane).length;
 if(!protectedRow(x,t,u.lane,s.zoneOwners.local||t)&&D.locations[s.sharedZones.local]===c.faction)p+=2;
 if(!protectedRow(x,t,u.lane,s.zoneOwners.terrain||t))p+=terrainBonus(s.sharedZones.terrain,c);
 if(c.faction==='Grécia')p+=Number(a.greekAura)||0;if(c.faction==='Nórdicos')p+=Number(a.norseAura)||0;
 if(own&&id==='lukyan-rei-de-todos')p+=Math.max(0,a.field.length-1);
 if(!protectedRow(x,t,u.lane,s.zoneOwners.climate||t)){const climate=s.sharedZones.climate;if(climate==='eclipse-lunar'){if(['lobo-alfa','lobo-beta','lobo-omega','artemis'].includes(identity(u))||vampire(identity(u)))p*=2;if(['apolo','ra'].includes(identity(u)))p=Math.floor(p/2);}if(climate==='eclipse-solar'){if(['apolo','ra'].includes(identity(u)))p*=2;if(identity(u)==='artemis')p=Math.floor(p/2);}}
 p=Math.max(0,Math.floor(p+(Number(u.powerShift)||0)));
 p=Math.max(0,Math.floor(p+(Number(u.copyOffset)||0)+(Number(u.reviveOffset)||0)));
 return p;
}
function note(x,text){x.s.log=[text,...(x.s.log||[])].slice(0,30);}
function event(x,op,t,owner,u,extra={}){x.s.effectQueue.push({op,team:t,owner,uid:u?.uid,lane:u?.lane||0,shielded:Boolean(u&&active(x,t,u)&&shield(x,t,u.lane)),...extra});}
function visual(x,kind,team,targets=[],extra={}){x.s.visualEvents=[...(x.s.visualEvents||[]),{id:uid(),kind,team,targets,round:x.s.round,...extra}].slice(-80);}
function graveUnit(x,t,u,killed=true,from=x.s.remakeSource||other(t)){if(killed&&!remakeBeforeDestroy(x,t,u,from))return;if(u.token){const wasLive=active(x,t,u);x.s[t].field=x.s[t].field.filter(v=>v!==u);if(killed)visual(x,'destroy',t,[u.uid]);remakeAfterDestroy(x,t,u,wasLive,killed);return;}if(killed)visual(x,'destroy',t,[u.uid]);const a=x.s[t],p=power(x,t,u),wasLive=active(x,t,u);a.field=a.field.filter(v=>v.uid!==u.uid);a.grave.push({uid:uid(),cardId:origin(u),owner:u.playedBy,progress:u.progress||0,deathPower:p,rebornOnce:Boolean(u.rebornOnce),savedOnce:Boolean(u.savedOnce),mourningUsed:Boolean(u.mourningUsed),rebornRound:x.s.round});for(const id of u.equipment||[])a.grave.push({uid:uid(),cardId:id,owner:u.equipmentOwners?.[id]||u.playedBy,progress:0});syncGrave(a);if(killed&&wasLive&&ability(u)==='osiris')event(x,'osiris',t,u.playedBy,null,{lane:u.lane,shielded:shield(x,t,u.lane)});remakeAfterDestroy(x,t,u,wasLive,killed);}
function killMany(x,t,units){for(const u of [...units])if(x.s[t].field.some(v=>v.uid===u.uid))graveUnit(x,t,u);}
function reconcile(x){const climate=x.s.sharedZones.climate;for(const t of teams)for(const u of [...x.s[t].field]){const enabled=globalActive(x,t,u);if(u.greekBonusLane!==undefined&&(u.greekBonusLane!==u.lane||u.greekBonusTeam!==t)){u.bonus-=u.greekBonusAmount||0;delete u.greekBonusLane;delete u.greekBonusAmount;delete u.greekBonusTeam;}
 if(enabled&&u.cardId==='lukyan'&&u.equipment.includes('excalibur')){if(active(x,t,u)&&x.s[t].field.some(v=>v.uid!==u.uid&&v.lane===u.lane))u.bonus+=3;u.sourceCardId='lukyan';u.cardId='lukyan-rei-de-todos';}
 const original=C[u.eclipseOriginalCardId]?u.eclipseOriginalCardId:u.cardId,climateActive=enabled&&!protectedRow(x,t,u.lane,x.s.zoneOwners.climate||t);
 if(climateActive&&climate==='eclipse-solar'&&vampire(original)){graveUnit(x,t,u);continue;}
 const form=window.MythicEclipseForms.formFor(original,climateActive?climate:null,C[original]);
 if(form!==u.cardId){u.cardId=form;delete u.copiedAbilityId;delete u.copiedPower;}
 if(form!==original)u.eclipseOriginalCardId=original;else delete u.eclipseOriginalCardId;
 }}

function spawn(x,id,t,owner,lane,progress=0,quiet=false){if(window.MythicAvailability?.isDisabled(id))return x;const c=C[id];if(!c||(c.specialOnly&&!(quiet&&c.token)))throw Error('Esta carta especial não pode ser jogada diretamente.');
 if(c.kind==='unit'){const u={uid:uid(),cardId:id,playedBy:owner,lane,slot:x.s[t].field.length,bonus:0,multiplier:1,equipment:[],progress};x.s[t].field.push(u);visual(x,'enter',t,[u.uid],{sourceCardId:id});reconcile(x);if(!quiet&&active(x,t,u)&&x.s[t].field.includes(u))for(const op of D.entries[ability(u)]||[])event(x,op,t,owner,u);return u;}
 if(c.kind==='equipment'){visual(x,'enter',t,[],{sourceCardId:id});if(live(x.s)||x.s[t].field.some(v=>active(x,t,v)))event(x,'equip',t,owner,null,{cardId:id,lane});return;}
 const zone=c.kind==='location'?'local':c.kind==='terrain'?'terrain':'climate';if(!window.MythicZoneRules.canReplace(c,C[x.s.sharedZones[zone]]))throw Error('Somente Clima/Evento pode substituir o Clima/Evento ativo.');x.s.zoneOwners[zone]=t;
 visual(x,'enter',t,[],{sourceCardId:id});if(id==='eclipse'){const result=random(2)?'eclipse-solar':'eclipse-lunar';x.s.sharedZones.climate=result;x.s.eclipseReveal={id:uid(),outcome:result,round:x.s.round};}else x.s.sharedZones[zone]=id;reconcile(x);
}
const option=(value,label,cardId)=>({value:String(value),label,cardId});
function unitOptions(x,t,filter=()=>true){return x.s[t].field.filter(filter).map(u=>option(u.uid,(C[u.cardId]?.name||u.cardId)+' · '+power(x,t,u)+' poder · Fileira '+(u.lane+1),u.cardId));}
function eligibleGrave(x,e,g){if(!remakeGraveAllowed(x,e,g))return false;if(window.MythicAvailability?.isDisabled(g.cardId))return false;const c=C[g.cardId];if(!c||c.specialOnly||g.owner!==e.owner)return false;if(e.op==='revive'&&c.kind!=='unit')return false;if(e.op==='revive_cost'&&(c.power||0)>2)return false;if(e.op==='anubis_revive'&&(c.kind!=='unit'||gravePower(g)!==e.wantedPower))return false;if(c.kind==='unit')return true;if(c.kind==='equipment')return x.s[e.team].field.some(u=>canEquip(g.cardId,u));return window.MythicZoneRules.canReplace(c,C[x.s.sharedZones[c.kind==='location'?'local':c.kind==='terrain'?'terrain':'climate']]);}
function canEquip(id,u){const r=D.equipment[id];return Boolean(r&&![...(u.equipment||[]),...(u.copiedEquipment||[])].includes(id)&&(r.ids?r.ids.includes(identity(u)):C[identity(u)]?.faction===r.faction));}
function options(x,e){const a=x.s[e.team],enemy=other(e.team);switch(e.op){
 case 'remake':return remakeOptions(x,e);
 case 'revive':case 'revive_cost':case 'anubis_revive':return [...a.grave.filter(g=>eligibleGrave(x,e,g)).map(g=>option(g.uid,C[g.cardId].name+(e.op==='anubis_revive'?' · '+gravePower(g)+' poder no Submundo':''),g.cardId)),option('skip','Não ressuscitar')];
 case 'copy':return unitOptions(x,enemy,u=>!protectedRow(x,enemy,u.lane,e.team));
 case 'steal':return [...unitOptions(x,enemy,u=>!remakeBlocked(x,enemy,u,e.team,'steal')&&power(x,enemy,u)<5),option('skip','Não roubar')];
 case 'anubis':return unitOptions(x,enemy,u=>!remakeBlocked(x,enemy,u,e.team,'destroy'));
 case 'destroy_strongest':{const max=Math.max(-1,...x.s[enemy].field.filter(u=>!remakeBlocked(x,enemy,u,e.team,'destroy')).map(u=>power(x,enemy,u)));return unitOptions(x,enemy,u=>!remakeBlocked(x,enemy,u,e.team,'destroy')&&power(x,enemy,u)===max);}
 case 'move':return [...unitOptions(x,e.team,u=>u.uid!==e.uid),option('skip','Não mover')];
 case 'move_lane':return [0,1,2].filter(l=>l!==e.fromLane).map(l=>option(l,'Mover para a fileira '+(l+1)));
 case 'rally':{const list=a.field.filter(u=>u.lane!==e.lane);const min=Math.min(Infinity,...list.map(u=>power(x,e.team,u)));return unitOptions(x,e.team,u=>u.lane!==e.lane&&power(x,e.team,u)===min);}
 case 'shuffle_lane':return [0,1,2].map(l=>option(l,'Embaralhar poderes da fileira '+(l+1)));
 case 'improve':return unitOptions(x,e.team,u=>u.equipment.length>0);
 case 'equip':return unitOptions(x,e.team,u=>globalActive(x,e.team,u)&&canEquip(e.cardId,u));
 case 'foresight':return (x.r[e.owner]?.deck||[]).length?[option('discard','Descartar o topo e ganhar +2 na soma'),option('keep','Manter a carta no topo')]:[];
 default:return null;
}}
function change(x,t,u,from,amount,mult=1){if(!u||protectedRow(x,t,u.lane,from)||(amount<0&&remakeBlocked(x,t,u,from,'reduce')))return;u.bonus+=amount;u.multiplier*=mult;}
function resolve(x,e){const s=x.s,t=e.team,a=s[t],en=other(t),b=s[en],u=a.field.find(v=>v.uid===e.uid),res=x.r[e.owner],selected=e.selection;if(["revive","revive_cost","anubis_revive"].includes(e.op)&&a.grave.some(g=>g.uid===selected&&window.MythicAvailability?.isDisabled(g.cardId)))return x;
 if(!enabledEvent(x,e))return;
 if(e.op!=='osiris'&&!['equip','anubis_revive','move_lane','remake'].includes(e.op)&&!u)return;
 if(e.op==='remake'){remakeResolve(x,e);reconcile(x);return;}
 if(e.op==='steal'&&remakeBlocked(x,en,b.field.find(v=>v.uid===selected),t,'steal'))return;
 switch(e.op){
 case 'copy':{const target=b.field.find(v=>v.uid===selected);if(!target||protectedRow(x,en,target.lane,t))return;const snapshot=power(x,en,target);u.copiedBasePower=Number.isFinite(target.copiedBasePower)?target.copiedBasePower:Number(C[identity(target)]?.power)||0;u.bonus=Number(target.bonus)||0;u.multiplier=Number(target.multiplier)||1;u.progress=Number(target.progress)||0;u.powerShift=Number(target.powerShift)||0;u.copiedEquipment=[...(target.equipment||[]),...(target.copiedEquipment||[])];u.mutedEquipment=[...(target.mutedEquipment||[])];u.copiedAbilityId=ability(target);u.copiedFrom=identity(target);delete u.copyOffset;delete u.copiedPower;u.copyOffset=snapshot-power(x,t,u);u.copiedPower=snapshot;if(u.copiedAbilityId!=='loki')for(const op of D.entries[u.copiedAbilityId]||[])event(x,op,t,e.owner,u);note(x,'Loki copiou '+C[target.cardId].name+'.');break;}
 case 'revive':case 'revive_cost':case 'anubis_revive':{if(selected==='skip')break;const g=a.grave.find(v=>v.uid===selected);if(!g||!eligibleGrave(x,e,g))throw Error('Essa carta não pode ser ressuscitada.');a.grave=a.grave.filter(v=>v.uid!==g.uid);syncGrave(a);const raised=spawn(x,g.cardId,t,e.owner,e.lane,g.progress||0);if(raised?.uid&&g.rebornRound===x.s.round)for(const key of ['rebornOnce','savedOnce','mourningUsed'])if(g[key])raised[key]=true;if(e.op==='anubis_revive'&&raised)raised.reviveOffset=e.wantedPower-power(x,t,raised);note(x,C[g.cardId].name+' voltou do próprio Submundo para o campo.');break;}
 case 'steal':{if(selected==='skip')break;visual(x,'hearts',en,[selected]);const target=b.field.find(v=>v.uid===selected);if(!target||protectedRow(x,en,target.lane,t)||power(x,en,target)>=5)throw Error('Alvo fora da regra de Afrodite.');b.field=b.field.filter(v=>v.uid!==selected);target.playedBy=e.owner;target.uid=uid();a.field.push(target);note(x,'Afrodite roubou '+C[target.cardId].name+'.');break;}
 case 'anubis':{const target=b.field.find(v=>v.uid===selected);if(!target||protectedRow(x,en,target.lane,t))return;const wanted=power(x,en,target);graveUnit(x,en,target);if(x.s[en].field.some(v=>v.uid===target.uid))break;event(x,'anubis_revive',t,e.owner,u,{wantedPower:wanted});break;}
 case 'destroy_strongest':killMany(x,en,b.field.filter(v=>v.uid===selected&&!protectedRow(x,en,v.lane,t)));break;
 case 'destroy_two':{const victims=shuffled(b.field.filter(v=>!remakeBlocked(x,en,v,t,'destroy'))).slice(0,2);visual(x,'lightning',en,victims.map(v=>v.uid));killMany(x,en,victims);break;}
 case 'hunt_monsters':for(const team of teams){const victims=[...s[team].field].filter(v=>(C[identity(v)]?.tags||[]).includes('monstro')&&!remakeBlocked(x,team,v,t,'destroy')).sort((v,w)=>power(x,team,w)-power(x,team,v)).slice(0,2);visual(x,'arrows',team,victims.map(v=>v.uid));killMany(x,team,victims);}break;
 case 'petrify':{visual(x,'petrify',en,b.field.map(v=>v.uid));const actors=Object.entries(x.r).filter(([,v])=>v.team===en);for(const [,actor] of actors)actor.skipNextTurn=true;break;}
 case 'tsunami':visual(x,'water',en,b.field.filter(v=>v.lane===0).map(v=>v.uid));for(const v of b.field.filter(v=>v.lane===0))change(x,en,v,t,-2);break;
 case 'move':{if(selected==='skip')break;const target=a.field.find(v=>v.uid===selected);if(target)event(x,'move_lane',t,e.owner,null,{targetUid:target.uid,fromLane:target.lane,lane:e.lane,shielded:e.shielded});break;}
 case 'move_lane':{const target=a.field.find(v=>v.uid===e.targetUid);if(target)target.lane=Number(selected);break;}
 case 'rally':{const target=a.field.find(v=>v.uid===selected);if(target)target.lane=e.lane;break;}
 case 'shuffle_lane':{const lane=Number(selected),list=[];for(const team of teams)for(const v of s[team].field)if(v.lane===lane&&!protectedRow(x,team,lane,t))list.push([team,v,power(x,team,v)]);const values=shuffled(list.map(v=>v[2]));list.forEach(([team,v,p],i)=>{if(values[i]>=p||!remakeBlocked(x,team,v,t,'reduce'))v.powerShift=(v.powerShift||0)+values[i]-p;});break;}
 case 'improve':change(x,t,a.field.find(v=>v.uid===selected),t,3);break;
 case 'equip':{const target=a.field.find(v=>v.uid===selected);if(!target||!canEquip(e.cardId,target))throw Error('Equipamento incompatível.');target.equipment.push(e.cardId);target.equipmentOwners={...(target.equipmentOwners||{}),[e.cardId]:e.owner};target.mutedEquipment=(target.mutedEquipment||[]).filter(id=>id!==e.cardId);reconcile(x);break;}
 case 'schedule_foresight':u.odinReady=true;break;
 case 'foresight':if(selected==='discard'&&res.deck.length){const id=res.deck.shift();a.grave.push({uid:uid(),cardId:id,owner:e.owner,progress:0});syncGrave(a);a.roundScoreBonus=(a.roundScoreBonus||0)+2;}break;
 case 'reveal':{const hands=Object.entries(x.r).filter(([,v])=>v.team===en).flatMap(([owner,v])=>v.hand.map(id=>({owner,cardId:id})));res.privateEffects={id:uid(),kind:'reveal',cards:shuffled(hands).slice(0,2).map(v=>v.cardId)};break;}
 case 'steal_hand':{
  const enemies=Object.entries(x.r).filter(([,v])=>v.team===en);let pool=[];let zone='hand';
  for(const source of ['hand','deck']){pool=enemies.flatMap(([owner,v])=>(v[source]||[]).map((id,i)=>({owner,id,i})));if(pool.length){zone=source;break;}}
  if(pool.length){const target=pool[random(pool.length)];x.r[target.owner][zone].splice(target.i,1);res.hand.push(target.id);}
  else {const grave=b.grave.filter(g=>!C[g.cardId]?.specialOnly&&C[g.cardId]&&remakeGraveAllowed(x,e,g,false));if(grave.length){const target=grave[random(grave.length)];b.grave=b.grave.filter(g=>g.uid!==target.uid);syncGrave(b);res.hand.push(target.cardId);}}
  break;}
 case 'silence':s.silenceTurns=3;s.silenceTeam=t;s.silenceStartedBy=e.owner+':'+(res.turnsTaken||0);s.silenceUntilRound=0;s.effectQueue=s.effectQueue.filter(next=>enabledEvent(x,next));note(x,'Dionísio silenciou os efeitos pelas próximas 3 jogadas.');break;
 case 'double_lane':break; // Apolo is a continuous aura, evaluated by power().
 case 'war_buff':for(const v of a.field.filter(v=>v.lane===e.lane)){const c=C[v.cardId];if((c.tags||[]).includes('espartano')||v.cardId==='leonidas')change(x,t,v,t,2);else if(c.faction==='Grécia')change(x,t,v,t,1);}break;
 case 'crowd_bonus':break; // Recalculated continuously by power().
 case 'alone_bonus':if(a.field.filter(v=>v.lane===u.lane).length===1)change(x,t,u,t,3);break;
 case 'ally_bonus':if(a.field.some(v=>v!==u&&v.lane===u.lane))change(x,t,u,t,2);break;
 case 'greek_bonus':{const amount=a.field.filter(v=>v!==u&&v.lane===u.lane&&C[identity(v)]?.faction==='Grécia'&&(C[identity(v)].characterClass==='Herói'||(C[identity(v)].tags||[]).some(tag=>['heroi','soldado','espartano'].includes(tag)))).length;change(x,t,u,t,amount);u.greekBonusLane=u.lane;u.greekBonusTeam=t;u.greekBonusAmount=amount;break;}
 case 'monster_bonus':if(teams.some(team=>s[team].field.some(v=>C[v.cardId]?.faction==='Monstros')))change(x,t,u,t,3);break;
 case 'summon_betas':{const ids=res.hand.filter(id=>id==='lobo-beta');res.hand=res.hand.filter(id=>id!=='lobo-beta');for(const id of ids)spawn(x,id,t,e.owner,e.lane);break;}
 case 'osiris':if(a.field.length){const target=a.field[random(a.field.length)];change(x,t,target,t,0,2);}break;
 }
 reconcile(x);
}
function drain(x,auto=false){let n=0;while(x.s.effectQueue.length&&!x.s.pendingEffect){if(++n>256)throw Error('A sequência de habilidades excedeu o limite.');const e=x.s.effectQueue.shift();if(!enabledEvent(x,e))continue;const list=options(x,e);if(list&&e.selection===undefined){if(!list.length)continue;if(auto)e.selection=list[0].value;else{x.s.pendingEffect={id:uid(),actor:e.choiceActor||e.owner,event:e,options:list,title:titles[e.op]||'Escolha o alvo'};break;}}x.s.remakeSource=e.team;resolve(x,e);delete x.s.remakeSource;}return x;}
const titles={revive:'Hades: escolha uma unidade do seu Submundo',revive_cost:'Ísis: ressuscitar carta de até 2 de poder',anubis:'Anúbis: escolha uma unidade inimiga',anubis_revive:'Anúbis: recuperar carta de mesmo poder',steal:'Afrodite: escolha um inimigo com menos de 5 de poder',copy:'Loki: escolha qual inimigo copiar',move:'Hermes: escolha outro aliado',move_lane:'Hermes: escolha a nova fileira',rally:'Ragnar: reunir o aliado de menor poder',shuffle_lane:'Seth: escolha a fileira',improve:'Hefestos: escolha um aliado equipado',equip:'Escolha quem receberá o equipamento',foresight:'Odin: observar o topo do baralho',destroy_strongest:'Thor: escolha o inimigo de maior poder'};
function action(x,owner,a,auto=false){if(a.type==='play'&&window.MythicAvailability?.isDisabled(a.card_id))throw Error('Esta carta está temporariamente pausada.');init(x);reconcile(x);const res=x.r[owner],t=res?.team;if(!res||!teams.includes(t))throw Error('Invocador inválido.');if(a.type==='resolve_effect'){const pending=x.s.pendingEffect;if(!pending||pending.actor!==owner||pending.id!==a.choice_id)throw Error('Esta escolha não está mais disponível.');if(!pending.options.some(v=>v.value===String(a.choice_value)))throw Error('Escolha inválida.');delete x.s.pendingEffect;x.s.effectQueue.unshift({...pending.event,selection:String(a.choice_value)});return drain(x,auto);}
 if(x.s.pendingEffect)throw Error('Resolva a habilidade pendente antes de jogar.');if(res.playedThisTurn||res.passed||res.skipNextTurn)throw Error('Não é possível jogar neste turno.');const c=C[a.card_id],i=res.hand.indexOf(a.card_id);if(!c||c.specialOnly||i<0)throw Error('Carta indisponível.');const lane=Number.isInteger(a.lane)?Math.max(0,Math.min(2,a.lane)):0;
 if(c.kind==='equipment'&&!x.s[t].field.some(u=>canEquip(c.id,u)))throw Error('Não há um aliado compatível para este equipamento.');
 res.hand.splice(i,1);spawn(x,c.id,t,owner,lane);res.playedThisTurn=true;note(x,c.name+' entrou em jogo.');return drain(x,auto);
}
function turnStart(x,owner,auto=false){init(x);remakeStart(x,owner);reconcile(x);const t=x.r[owner]?.team;if(!t||x.r[owner].skipNextTurn)return x;for(const u of x.s[t].field){if(u.playedBy===owner&&u.odinReady){delete u.odinReady;event(x,'foresight',t,owner,u);}}x.s.abilityPhase='turn_start';drain(x,auto);if(!x.s.pendingEffect)delete x.s.abilityPhase;return x;}
function turnEnd(x,owner){init(x);const res=x.r[owner];if(!res)return x;const stamp=String(x.s.round)+':'+(res.turnsTaken||0);x.s.endedTurns=x.s.endedTurns||{};if(x.s.endedTurns[owner]===stamp)return x;x.s.endedTurns[owner]=stamp;const t=res.team;
 for(const u of [...x.s[t].field]){if(u.playedBy!==owner||!active(x,t,u))continue;if(ability(u)==='ra')for(const v of x.s[t].field)if(v.lane===u.lane&&C[identity(v)]?.faction==='Egípcios')change(x,t,v,t,1);if(ability(u)==='hercules')u.progress=Math.min(12,(u.progress||0)+1);}
 remakeEnd(x,owner);
 if(Number(x.s.silenceTurns)>0&&x.s.silenceStartedBy!==owner+':'+(res.turnsTaken||0)){x.s.silenceTurns--;if(!x.s.silenceTurns){delete x.s.silenceTeam;note(x,'O silêncio de Dionísio terminou.');}}reconcile(x);return x;
}
function roundEnd(x){init(x);x.s.endEffectsRound=x.s.round;}
function clearRound(x){init(x);for(const t of teams){for(const u of [...x.s[t].field])graveUnit(x,t,u,false);x.s[t].roundScoreBonus=0;}x.s.sharedZones={local:null,terrain:null,climate:null};x.s.effectQueue=[];delete x.s.pendingEffect;delete x.s.abilityPhase;x.s.silenceUntilRound=0;x.s.silenceTurns=0;delete x.s.silenceTeam;delete x.s.silenceStartedBy;x.s.endedTurns={};x.s.zoneOwners={};delete x.s.eclipseReveal;for(const t of teams){for(const g of x.s[t].grave){g.progress=0;delete g.lockedRound;delete g.rebornOnce;delete g.rebornRound;delete g.savedOnce;delete g.mourningUsed;}x.s[t].greekAura=0;x.s[t].norseAura=0;}for(const res of Object.values(x.r)){res.skipNextTurn=false;delete res.privateEffects;}}
function score(x,t){return Math.max(0,x.s[t].field.reduce((n,u)=>n+power(x,t,u),0)+(live(x.s)?Number(x.s[t].roundScoreBonus)||0:0));}
window.MythicAbilities={C,D,init,reconcile,power,score,action,drain,turnStart,turnEnd,roundEnd,clearRound,identity,protectedRow,active,live,canEquip,origin,copy,destroyUnit(x,t,id){const unit=x.s[t]?.field.find(u=>u.uid===id);if(unit)graveUnit(x,t,unit);return drain(x);}};
})();
