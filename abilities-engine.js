(() => {
'use strict';
const D=window.MythicAbilitiesData,C=Object.fromEntries(D.cards.map(c=>[c.id,c]));
const teams=['player_one','player_two'],other=t=>t==='player_one'?'player_two':'player_one';
const uid=()=>crypto.randomUUID(),copy=x=>JSON.parse(JSON.stringify(x));
const random=n=>{if(n<1)return 0;const a=new Uint32Array(1),limit=Math.floor(4294967296/n)*n;do{crypto.getRandomValues(a);}while(a[0]>=limit);return a[0]%n;};
const shuffled=a=>{a=[...a];for(let i=a.length-1;i>0;i--){const j=random(i+1);[a[i],a[j]]=[a[j],a[i]];}return a;};
const ability=u=>u.copiedAbilityId||u.cardId,live=s=>Number(s.round||1)>Number(s.silenceUntilRound||0);
const vampire=id=>String(id||'').startsWith('vampir')||id==='dracula';
const origin=u=>u.eclipseOriginalCardId||u.sourceCardId||(u.cardId==='lukyan-rei-de-todos'?'lukyan':u.cardId);
function init(x){const s=x.s;s.effectQueue=s.effectQueue||[];s.sharedZones=s.sharedZones||{};s.zoneOwners=s.zoneOwners||{};for(const t of teams){const a=s[t];a.field=a.field||[];a.underworld=a.underworld||[];a.grave=a.grave||a.underworld.map((id,i)=>({uid:'legacy:'+t+':'+i,cardId:id,owner:x.legacyOwners?.[t]||null,progress:0}));for(const u of a.field){u.uid=u.uid||uid();u.bonus=Number(u.bonus)||0;u.lane=Number(u.lane)||0;u.multiplier=Number(u.multiplier)||1;u.equipment=u.equipment||[];u.playedBy=u.playedBy||x.legacyOwners?.[t]||null;}syncGrave(a);}return x;}
function syncGrave(a){a.underworld=a.grave.map(g=>g.cardId);}
function protectedRow(x,t,lane,from){return live(x.s)&&from!==t&&x.s[t].field.some(u=>u.lane===lane&&ability(u)==='heimdall');}
function terrainBonus(id,c){for(const r of D.terrain[id]||[]){if(r.ids&&!r.ids.includes(c.id))continue;if(r.faction&&r.faction!==c.faction)continue;if(r.excludeIds?.includes(c.id))continue;if(r.tagsAny&&!r.tagsAny.some(v=>(c.tags||[]).includes(v)))continue;return r.bonus;}return 0;}
function power(x,t,u,depth=0){const s=x.s,a=s[t],c=C[u.cardId]||{power:0},id=ability(u);let p=Number(c.power)||0;if(!live(s))return p;
 p=Number.isFinite(u.copiedPower)?u.copiedPower:p;p+=Number(u.bonus)||0;if(id==='hercules')p+=Math.min(12,Number(u.progress)||0);
 for(const equipment of u.equipment||[]){const r=D.equipment[equipment];if(r&&(r.ids?r.ids.includes(u.cardId):r.faction===c.faction))p+=r.bonus;}
 if(id==='soldado-esparta'){const count=a.field.filter(v=>v.cardId==='soldado-esparta'&&v!==u).length;p*=2**count;}
 if(id==='lobo-alfa')p+=2*a.field.filter(v=>v.cardId==='lobo-beta').length;
 p+=2*a.field.filter(v=>v!==u&&ability(v)==='athena'&&v.lane===u.lane).length;
 if(id==='lobo-omega'&&depth===0&&a.field.filter(v=>v.lane===u.lane).length===1){const enemy=x.s[other(t)].field.filter(v=>v.lane===u.lane).reduce((n,v)=>n+power(x,other(t),v,1),0);if(enemy>p)p+=8;}
 if(id==='mulher')p*=2**a.field.filter(v=>v.cardId==='homem').length;
 if(id==='homem')p*=2**a.field.filter(v=>v!==u&&v.cardId==='homem').length;
 p*=Number(u.multiplier)||1;
 if(!protectedRow(x,t,u.lane,s.zoneOwners.local||t)&&D.locations[s.sharedZones.local]===c.faction)p+=2;
 if(!protectedRow(x,t,u.lane,s.zoneOwners.terrain||t))p+=terrainBonus(s.sharedZones.terrain,c);
 if(c.faction==='Grécia')p+=Number(a.greekAura)||0;if(c.faction==='Nórdicos')p+=Number(a.norseAura)||0;
 if(id==='lukyan-rei-de-todos')p*=2**Math.max(0,a.field.length-1);
 if(!protectedRow(x,t,u.lane,s.zoneOwners.climate||t)){const climate=s.sharedZones.climate;if(climate==='eclipse-lunar'){if(['lobo-alfa','lobo-beta','lobo-omega','artemis'].includes(u.cardId)||vampire(u.cardId))p*=2;if(['apolo','ra'].includes(u.cardId))p=Math.floor(p/2);}if(climate==='eclipse-solar'){if(['apolo','ra'].includes(u.cardId))p*=2;if(u.cardId==='artemis')p=Math.floor(p/2);}}
 p=Math.max(0,Math.floor(p+(Number(u.powerShift)||0)));
 if(id==='guardiao-nordico'&&a.field.some(v=>v!==u&&v.uid!==u.uid&&v.cardId==='guardiao-nordico'&&v.lane===u.lane))p*=2;
 return p;
}
function note(x,text){x.s.log=[text,...(x.s.log||[])].slice(0,30);}
function event(x,op,t,owner,u,extra={}){x.s.effectQueue.push({op,team:t,owner,uid:u?.uid,lane:u?.lane||0,...extra});}
function visual(x,kind,team,targets=[],extra={}){x.s.visualEvents=[...(x.s.visualEvents||[]),{id:uid(),kind,team,targets,round:x.s.round,...extra}].slice(-80);}
function graveUnit(x,t,u,killed=true){if(killed)visual(x,'destroy',t,[u.uid]);const a=x.s[t],p=power(x,t,u),wasLive=live(x.s);a.field=a.field.filter(v=>v.uid!==u.uid);a.grave.push({uid:uid(),cardId:origin(u),owner:u.playedBy,progress:u.progress||0,deathPower:p});for(const id of u.equipment||[])a.grave.push({uid:uid(),cardId:id,owner:u.playedBy,progress:0});syncGrave(a);if(killed&&wasLive&&ability(u)==='osiris')event(x,'osiris',t,u.playedBy,null);}
function killMany(x,t,units){for(const u of [...units])if(x.s[t].field.some(v=>v.uid===u.uid))graveUnit(x,t,u);}
function reconcile(x){if(!live(x.s))return;for(const t of teams){for(const u of [...x.s[t].field]){if(u.cardId==='lukyan'&&u.equipment.includes('excalibur')){u.sourceCardId='lukyan';u.cardId='lukyan-rei-de-todos';}
 if(x.s.sharedZones.climate!=='eclipse-solar'){if(u.eclipseOriginalCardId){u.cardId=u.eclipseOriginalCardId;delete u.eclipseOriginalCardId;}continue;}if(vampire(u.cardId)){graveUnit(x,t,u);continue;}if(protectedRow(x,t,u.lane,x.s.zoneOwners.climate||t))continue;const form={'lobo-alfa':'mulher','lobo-beta':'homem','lobo-omega':'homem'}[u.cardId];if(form){u.eclipseOriginalCardId=u.cardId;u.cardId=form;delete u.copiedAbilityId;delete u.copiedPower;}}
}}
function spawn(x,id,t,owner,lane,progress=0){const c=C[id];if(!c||c.specialOnly)throw Error('Esta carta especial não pode ser jogada diretamente.');
 if(c.kind==='unit'){const u={uid:uid(),cardId:id,playedBy:owner,lane,slot:x.s[t].field.length,bonus:0,multiplier:1,equipment:[],progress};x.s[t].field.push(u);visual(x,'enter',t,[u.uid],{sourceCardId:id});reconcile(x);if(live(x.s)&&x.s[t].field.includes(u))for(const op of D.entries[ability(u)]||[])event(x,op,t,owner,u);return u;}
 if(c.kind==='equipment'){visual(x,'enter',t,[],{sourceCardId:id});if(live(x.s))event(x,'equip',t,owner,null,{cardId:id,lane});return;}
 const zone=c.kind==='location'?'local':c.kind==='terrain'?'terrain':'climate';if(!window.MythicZoneRules.canReplace(c,C[x.s.sharedZones[zone]]))throw Error('Somente Clima/Evento pode substituir o Clima/Evento ativo.');x.s.zoneOwners[zone]=t;
 visual(x,'enter',t,[],{sourceCardId:id});if(id==='eclipse'){const result=random(2)?'eclipse-solar':'eclipse-lunar';x.s.sharedZones.climate=result;x.s.eclipseReveal={id:uid(),outcome:result,round:x.s.round};}else x.s.sharedZones[zone]=id;reconcile(x);
}
const option=(value,label,cardId)=>({value:String(value),label,cardId});
function unitOptions(x,t,filter=()=>true){return x.s[t].field.filter(filter).map(u=>option(u.uid,(C[u.cardId]?.name||u.cardId)+' · '+power(x,t,u)+' poder · Fileira '+(u.lane+1),u.cardId));}
function eligibleGrave(x,e,g){const c=C[g.cardId];if(!c||c.specialOnly||g.owner!==e.owner)return false;if(e.op==='revive_cost'&&(c.power||0)>2)return false;if(e.op==='anubis_revive'&&(c.power||0)!==e.wantedPower)return false;if(c.kind==='unit')return true;if(c.kind==='equipment')return x.s[e.team].field.some(u=>canEquip(g.cardId,u));return window.MythicZoneRules.canReplace(c,C[x.s.sharedZones[c.kind==='location'?'local':c.kind==='terrain'?'terrain':'climate']]);}
function canEquip(id,u){const r=D.equipment[id];return Boolean(r&&(r.ids?r.ids.includes(u.cardId):C[u.cardId]?.faction===r.faction));}
function options(x,e){const a=x.s[e.team],enemy=other(e.team);switch(e.op){
 case 'revive':case 'revive_cost':case 'anubis_revive':return [...a.grave.filter(g=>eligibleGrave(x,e,g)).map(g=>option(g.uid,C[g.cardId].name,g.cardId)),option('skip','Não ressuscitar')];
 case 'copy':return unitOptions(x,enemy);
 case 'steal':return [...unitOptions(x,enemy,u=>power(x,enemy,u)<5),option('skip','Não roubar')];
 case 'anubis':return unitOptions(x,enemy,u=>power(x,enemy,u)<=3);
 case 'destroy_strongest':{const max=Math.max(-1,...x.s[enemy].field.map(u=>power(x,enemy,u)));return unitOptions(x,enemy,u=>power(x,enemy,u)===max);}
 case 'move':return [...unitOptions(x,e.team,u=>u.uid!==e.uid),option('skip','Não mover')];
 case 'move_lane':return [0,1,2].filter(l=>l!==e.fromLane).map(l=>option(l,'Mover para a fileira '+(l+1)));
 case 'rally':{const list=a.field.filter(u=>u.lane!==e.lane);const min=Math.min(Infinity,...list.map(u=>power(x,e.team,u)));return unitOptions(x,e.team,u=>u.lane!==e.lane&&power(x,e.team,u)===min);}
 case 'shuffle_lane':return [0,1,2].map(l=>option(l,'Embaralhar poderes da fileira '+(l+1)));
 case 'improve':return unitOptions(x,e.team,u=>u.equipment.length>0);
 case 'equip':return unitOptions(x,e.team,u=>canEquip(e.cardId,u));
 case 'foresight':return (x.r[e.owner]?.deck||[]).length?[option('discard','Descartar o topo e ganhar +2 na soma'),option('keep','Manter a carta no topo')]:[];
 default:return null;
}}
function change(x,t,u,from,amount,mult=1){if(!u||protectedRow(x,t,u.lane,from))return;u.bonus+=amount;u.multiplier*=mult;}
function resolve(x,e){const s=x.s,t=e.team,a=s[t],en=other(t),b=s[en],u=a.field.find(v=>v.uid===e.uid),res=x.r[e.owner],selected=e.selection;
 if(!live(s))return;
 if(e.op!=='osiris'&&!['equip','anubis_revive','move_lane'].includes(e.op)&&!u)return;
 switch(e.op){
 case 'copy':{const target=b.field.find(v=>v.uid===selected);if(!target)return;u.copiedPower=power(x,en,target);u.copiedAbilityId=ability(target);u.copiedFrom=target.cardId;if(u.copiedAbilityId!=='loki')for(const op of D.entries[u.copiedAbilityId]||[])event(x,op,t,e.owner,u);note(x,'Loki copiou '+C[target.cardId].name+'.');break;}
 case 'revive':case 'revive_cost':case 'anubis_revive':{if(selected==='skip')break;const g=a.grave.find(v=>v.uid===selected);if(!g||!eligibleGrave(x,e,g))throw Error('Essa carta não pode ser ressuscitada.');a.grave=a.grave.filter(v=>v.uid!==g.uid);syncGrave(a);spawn(x,g.cardId,t,e.owner,e.lane,g.progress||0);note(x,C[g.cardId].name+' voltou do próprio Submundo para o campo.');break;}
 case 'steal':{if(selected==='skip')break;visual(x,'hearts',en,[selected]);const target=b.field.find(v=>v.uid===selected);if(!target||power(x,en,target)>=5)throw Error('Alvo fora da regra de Afrodite.');b.field=b.field.filter(v=>v.uid!==selected);target.playedBy=e.owner;target.uid=uid();a.field.push(target);note(x,'Afrodite roubou '+C[target.cardId].name+'.');break;}
 case 'anubis':{const target=b.field.find(v=>v.uid===selected);if(!target)return;const wanted=power(x,en,target);graveUnit(x,en,target);event(x,'anubis_revive',t,e.owner,u,{wantedPower:wanted});break;}
 case 'destroy_strongest':killMany(x,en,b.field.filter(v=>v.uid===selected));break;
 case 'destroy_two':{const victims=[...b.field].sort((v,w)=>power(x,en,w)-power(x,en,v)).slice(0,2);visual(x,'lightning',en,victims.map(v=>v.uid));killMany(x,en,victims);break;}
 case 'hunt_monsters':for(const team of teams){const victims=[...s[team].field].filter(v=>(C[v.cardId]?.tags||[]).includes('monstro')).sort((v,w)=>power(x,team,w)-power(x,team,v)).slice(0,2);visual(x,'arrows',team,victims.map(v=>v.uid));killMany(x,team,victims);}break;
 case 'petrify':{visual(x,'petrify',en,b.field.map(v=>v.uid));const actors=Object.entries(x.r).filter(([,v])=>v.team===en);const target=actors.find(([,v])=>!v.passed)||actors[0];if(target)target[1].skipNextTurn=true;break;}
 case 'tsunami':visual(x,'water',en,b.field.filter(v=>v.lane===0).map(v=>v.uid));for(const v of b.field.filter(v=>v.lane===0))change(x,en,v,t,-2);break;
 case 'move':{if(selected==='skip')break;const target=a.field.find(v=>v.uid===selected);if(target)event(x,'move_lane',t,e.owner,null,{targetUid:target.uid,fromLane:target.lane});break;}
 case 'move_lane':{const target=a.field.find(v=>v.uid===e.targetUid);if(target)target.lane=Number(selected);break;}
 case 'rally':{const target=a.field.find(v=>v.uid===selected);if(target)target.lane=e.lane;break;}
 case 'shuffle_lane':{const lane=Number(selected),list=[];for(const team of teams)for(const v of s[team].field)if(v.lane===lane&&!protectedRow(x,team,lane,t))list.push([team,v,power(x,team,v)]);const values=shuffled(list.map(v=>v[2]));list.forEach(([team,v,p],i)=>v.powerShift=(v.powerShift||0)+values[i]-p);break;}
 case 'improve':change(x,t,a.field.find(v=>v.uid===selected),t,3);break;
 case 'equip':{const target=a.field.find(v=>v.uid===selected);if(!target||!canEquip(e.cardId,target))throw Error('Equipamento incompatível.');target.equipment.push(e.cardId);reconcile(x);break;}
 case 'schedule_foresight':u.odinReady=true;break;
 case 'foresight':if(selected==='discard'&&res.deck.length){const id=res.deck.shift();a.grave.push({uid:uid(),cardId:id,owner:e.owner,progress:0});syncGrave(a);a.roundScoreBonus=(a.roundScoreBonus||0)+2;}break;
 case 'reveal':{const hands=Object.entries(x.r).filter(([,v])=>v.team===en).flatMap(([owner,v])=>v.hand.map(id=>({owner,cardId:id})));res.privateEffects={id:uid(),kind:'reveal',cards:shuffled(hands).slice(0,2).map(v=>v.cardId)};break;}
 case 'steal_hand':{const hands=Object.entries(x.r).filter(([,v])=>v.team===en).flatMap(([owner,v])=>v.hand.map((id,i)=>({owner,id,i})));if(hands.length){const target=hands[random(hands.length)];x.r[target.owner].hand.splice(target.i,1);res.hand.push(target.id);}break;}
 case 'silence':s.silenceUntilRound=Number(s.round)+2;for(const team of teams){for(const v of s[team].field){if(v.eclipseOriginalCardId){v.cardId=v.eclipseOriginalCardId;delete v.eclipseOriginalCardId;}}}for(const v of Object.values(x.r))v.skipNextTurn=false;s.effectQueue=[];note(x,'Dionísio desativou os efeitos até o fim da rodada '+s.silenceUntilRound+'.');break;
 case 'double_lane':for(const v of a.field.filter(v=>v.lane===e.lane))change(x,t,v,t,0,2);break;
 case 'war_buff':for(const v of a.field){const c=C[v.cardId];if((c.tags||[]).includes('espartano')||v.cardId==='leonidas')change(x,t,v,t,2);else if(c.faction==='Grécia')change(x,t,v,t,1);}break;
 case 'crowd_bonus':if(a.field.some(v=>v!==u&&v.lane===u.lane))change(x,t,u,t,3);break;
 case 'alone_bonus':if(a.field.filter(v=>v.lane===u.lane).length===1)change(x,t,u,t,3);break;
 case 'ally_bonus':if(a.field.some(v=>v!==u&&v.lane===u.lane))change(x,t,u,t,2);break;
 case 'greek_bonus':change(x,t,u,t,a.field.filter(v=>v!==u&&v.lane===u.lane&&C[v.cardId]?.faction==='Grécia'&&(C[v.cardId].tags||[]).some(tag=>['heroi','soldado','espartano'].includes(tag))).length);break;
 case 'monster_bonus':if(teams.some(team=>s[team].field.some(v=>C[v.cardId]?.faction==='Monstros')))change(x,t,u,t,3);break;
 case 'summon_betas':{const ids=res.hand.filter(id=>id==='lobo-beta');res.hand=res.hand.filter(id=>id!=='lobo-beta');for(const id of ids)spawn(x,id,t,e.owner,e.lane);break;}
 case 'osiris':if(a.field.length){const target=a.field[random(a.field.length)];change(x,t,target,t,0,2);}break;
 }
 reconcile(x);
}
function drain(x,auto=false){let n=0;while(x.s.effectQueue.length&&!x.s.pendingEffect){if(++n>256)throw Error('A sequência de habilidades excedeu o limite.');const e=x.s.effectQueue.shift();if(!live(x.s))continue;const list=options(x,e);if(list&&e.selection===undefined){if(!list.length)continue;if(auto)e.selection=list[0].value;else{x.s.pendingEffect={id:uid(),actor:e.owner,event:e,options:list,title:titles[e.op]||'Escolha o alvo'};break;}}resolve(x,e);}return x;}
const titles={revive:'Hades: escolha uma carta do seu Submundo',revive_cost:'Ísis: ressuscitar carta de até 2 de poder',anubis:'Anúbis: escolha um inimigo de até 3 de poder',anubis_revive:'Anúbis: recuperar carta de mesmo poder',steal:'Afrodite: escolha um inimigo com menos de 5 de poder',copy:'Loki: escolha qual inimigo copiar',move:'Hermes: escolha outro aliado',move_lane:'Hermes: escolha a nova fileira',rally:'Ragnar: reunir o aliado de menor poder',shuffle_lane:'Seth: escolha a fileira',improve:'Hefestos: escolha um aliado equipado',equip:'Escolha quem receberá o equipamento',foresight:'Odin: observar o topo do baralho',destroy_strongest:'Thor: escolha o inimigo de maior poder'};
function action(x,owner,a,auto=false){init(x);const res=x.r[owner],t=res?.team;if(!res||!teams.includes(t))throw Error('Invocador inválido.');if(a.type==='resolve_effect'){const pending=x.s.pendingEffect;if(!pending||pending.actor!==owner||pending.id!==a.choice_id)throw Error('Esta escolha não está mais disponível.');if(!pending.options.some(v=>v.value===String(a.choice_value)))throw Error('Escolha inválida.');delete x.s.pendingEffect;x.s.effectQueue.unshift({...pending.event,selection:String(a.choice_value)});return drain(x,auto);}
 if(x.s.pendingEffect)throw Error('Resolva a habilidade pendente antes de jogar.');if(res.playedThisTurn||res.passed||res.skipNextTurn)throw Error('Não é possível jogar neste turno.');const c=C[a.card_id],i=res.hand.indexOf(a.card_id);if(!c||c.specialOnly||i<0)throw Error('Carta indisponível.');const lane=Number.isInteger(a.lane)?Math.max(0,Math.min(2,a.lane)):0;
 if(c.kind==='equipment'&&!x.s[t].field.some(u=>canEquip(c.id,u)))throw Error('Não há um aliado compatível para este equipamento.');
 res.hand.splice(i,1);spawn(x,c.id,t,owner,lane);res.playedThisTurn=true;note(x,c.name+' entrou em jogo.');return drain(x,auto);
}
function turnStart(x,owner,auto=false){init(x);const t=x.r[owner]?.team;if(!t||x.r[owner].skipNextTurn)return x;for(const u of x.s[t].field){if(u.playedBy===owner&&u.odinReady){delete u.odinReady;event(x,'foresight',t,owner,u);}}x.s.abilityPhase='turn_start';drain(x,auto);if(!x.s.pendingEffect)delete x.s.abilityPhase;return x;}
function roundEnd(x){init(x);if(x.s.endEffectsRound===x.s.round)return;x.s.endEffectsRound=x.s.round;if(live(x.s))for(const t of teams){const a=x.s[t];for(const u of [...a.field]){if(ability(u)==='ra')for(const v of a.field)if(C[v.cardId]?.faction==='Egípcios')change(x,t,v,t,1);if(ability(u)==='hercules')u.progress=Math.min(12,(u.progress||0)+1);}}}
function clearRound(x){init(x);for(const t of teams){for(const u of [...x.s[t].field])graveUnit(x,t,u,false);x.s[t].roundScoreBonus=0;}x.s.effectQueue=[];delete x.s.pendingEffect;delete x.s.abilityPhase;x.s.silenceUntilRound=0;x.s.zoneOwners={};delete x.s.eclipseReveal;for(const t of teams){for(const g of x.s[t].grave)g.progress=0;x.s[t].greekAura=0;x.s[t].norseAura=0;}for(const res of Object.values(x.r)){res.skipNextTurn=false;delete res.privateEffects;}}
function score(x,t){return Math.max(0,x.s[t].field.reduce((n,u)=>n+power(x,t,u),0)+(live(x.s)?Number(x.s[t].roundScoreBonus)||0:0));}
window.MythicAbilities={C,D,init,power,score,action,drain,turnStart,roundEnd,clearRound,live,canEquip,origin,copy};
})();
