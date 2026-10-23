(() => {
 'use strict';
 const $=s=>document.querySelector(s),reduce=()=>window.MythicMatchPresentation?.reduced?.()||matchMedia('(prefers-reduced-motion:reduce)').matches;
 let rects=new Map(),portraits=new Map(),seen=new Set(),matchKey=null,last=null,transitionUntil=0,playUntil=0,root=null,generation=0;
 let fieldSnapshot=null,heldFields=null,fieldHoldUntil=0,scoreSnapshot=null,heldScores=null,timeline=Promise.resolve(),pendingBatches=0;
 const activeArrivals=new Map(),activeMorphs=new Map(),timers=new Set(),center=r=>({x:r.left+r.width/2,y:r.top+r.height/2});
 const wait=(fn,ms)=>{const token=generation,id=setTimeout(()=>{timers.delete(id);if(token===generation)fn();},Math.max(0,ms));timers.add(id);return id;};
 function layer(){if(!root){root=document.createElement('div');root.id='combat-effects';root.setAttribute('aria-hidden','true');document.body.append(root);}return root;}
 function effect(cls,point,text='',duration=900){const e=document.createElement('span');e.className='combat-fx '+cls;e.textContent=text;e.style.left=point.x+'px';e.style.top=point.y+'px';layer().append(e);wait(()=>e.remove(),duration);return e;}
 const sideKey=(d,t)=>t===(d.myTeam||'player_one')?'player':'enemy';
 const teamFor=(d,side)=>side==='player'?(d.myTeam||'player_one'):(d.myTeam==='player_two'?'player_one':'player_two');
 function unitEffectsActive(d,u){const a=window.MythicAbilities;if(!a)return true;const state={...d,[teamFor(d,'player')]:d.player,[teamFor(d,'enemy')]:d.enemy};return a.active({s:state},u.team,u)&&!a.protectedRow({s:state},u.team,u.lane,d.zoneOwners?.climate||u.team);}
 function capture(){scoreSnapshot=Object.fromEntries(["player","enemy"].map(key=>{const n=$("#"+key+"-score");return [key,n?{value:n.textContent,label:n.parentElement.lastElementChild.textContent}:null];}));fieldSnapshot={player:$('#player-field')?.innerHTML,enemy:$('#enemy-field')?.innerHTML};rects=new Map();portraits=new Map();document.querySelectorAll('[data-unit-uid]').forEach(e=>{const r=e.getBoundingClientRect(),prior=rects.get(e.dataset.unitUid);if(!r.width||!r.height||(prior&&prior.width*prior.height>r.width*r.height))return;rects.set(e.dataset.unitUid,r);portraits.set(e.dataset.unitUid,e.querySelector('img')?.src);});}
 function fieldUnits(d){return ['player','enemy'].flatMap(side=>(d[side]?.field||[]).map(u=>({...u,team:teamFor(d,side)})));}
 function pendingSource(d,units,cards){const p=d.pendingEffect;if(!p)return null;if(p.event?.cardId)return p.event.cardId;const unit=units.find(u=>u.uid===p.event?.uid);if(unit)return unit.cardId;const title=String(p.title||'').toLocaleLowerCase('pt-BR');return cards.find(c=>title.startsWith(c.name?.toLocaleLowerCase('pt-BR')+':'))?.id||null;}
 const sources={lightning:'zeus',arrows:'artemis',hearts:'afrodite',water:'poseidon',petrify:'medusa'};
 const themes={zeus:'lightning',thor:'lightning',medusa:'stone',afrodite:'love',poseidon:'ocean',artemis:'moon',hades:'underworld',isis:'life',anubis:'underworld',osiris:'life',loki:'illusion',odin:'runes',horus:'sun',ra:'sun',apolo:'sun',dionisio:'wine',seth:'sand'};
 async function portrait(card){
  const stamp=generation,duration=reduce()?300:2200,e=document.createElement('section');e.className='ability-cinematic';e.dataset.theme=themes[card.id]||'runes';e.setAttribute('role','status');e.setAttribute('aria-label',card.name+' — '+(card.abilityTitle||'Entra em campo'));
  const glow=document.createElement('i');glow.className='ability-cinematic-aura';const img=document.createElement('img');img.src=window.MythicSecurity.assetUrl(card.hologram||card.art);img.alt='';img.className='ability-cinematic-hero';img.decoding='async';const copy=document.createElement('div');copy.className='ability-cinematic-copy';const name=document.createElement('small');name.textContent=card.name;const title=document.createElement('h2');title.textContent=card.abilityTitle||'Entra em campo';copy.append(name,title);e.append(glow,img,copy);
  if(!img.complete||!img.naturalWidth){try{await Promise.race([img.decode(),new Promise((_,reject)=>setTimeout(()=>reject(Error('image timeout')),900))]);}catch{img.hidden=true;}}
  if(stamp!==generation)return;layer().append(e);await new Promise(resolve=>wait(resolve,duration));e.remove();
 }
 function syncArrivals(){
  const now=Date.now();
  document.querySelectorAll('[data-unit-uid]').forEach(node=>{
   const arrival=activeArrivals.get(node.dataset.unitUid),waiting=Boolean(arrival&&!arrival.started),running=Boolean(arrival?.started&&now<arrival.end),wasRunning=node.classList.contains('unit-field-arriving');
   node.classList.toggle('unit-arrival-pending',waiting);
   node.classList.toggle('unit-field-arriving',running);
   if(running){if(!wasRunning){node.style.setProperty('--unit-arrival-duration',arrival.duration+'ms');node.style.setProperty('--unit-arrival-delay',Math.min(0,arrival.started-now)+'ms');}
    if(node.matches('.battle-mini-card')&&!node.querySelector('.unit-arrival-label')){const label=document.createElement('span');label.className='ability-arrival-effect unit-arrival-label';label.textContent='✦ ENTRADA EM CAMPO';node.append(label);}
   }else{node.style.removeProperty('--unit-arrival-duration');node.style.removeProperty('--unit-arrival-delay');node.querySelector('.unit-arrival-label')?.remove();}
  });
 }
 function stageArrival(uid,delay){
  const duration=reduce()?350:1700,arrival={duration,started:0,end:0};
  activeArrivals.set(uid,arrival);
  // Hide in the same render that inserts the unit, before the browser paints it.
  syncArrivals();
  const begin=()=>{if(activeArrivals.get(uid)!==arrival)return;arrival.started=Date.now();arrival.end=arrival.started+duration;syncArrivals();
   wait(()=>{if(activeArrivals.get(uid)!==arrival)return;activeArrivals.delete(uid);syncArrivals();},duration);
  };if(delay!==null)wait(begin,delay);return begin;
 }
 function burst(r,d,t,star=false){const p=center(r),dest=$(sideKey(d,t)==='player'?'#underworld-pile':'#enemy-underworld')?.getBoundingClientRect(),end=dest?center(dest):p;effect(star?'fx-star-burst':'fx-card-burst',p,star?'✦':'',900);if(reduce())return;
  const count=matchMedia('(max-width:600px)').matches?12:22;
  for(let i=0;i<count;i++){const part=effect('fx-particle'+(star?' star-shard':''),p,'',1400),angle=Math.PI*2*i/count,dist=25+Math.random()*60;part.animate([{transform:'translate(-50%,-50%) scale(1)',opacity:1},{transform:`translate(${Math.cos(angle)*dist}px,${Math.sin(angle)*dist}px) scale(.8)`,opacity:1,offset:.32},{transform:`translate(${end.x-p.x}px,${end.y-p.y}px) scale(.12)`,opacity:0}],{duration:1100,delay:i*9,easing:'ease-in',fill:'forwards'});}
 }
 function ghost(id,batch){const r=batch.rects.get(id),src=batch.portraits.get(id);if(!r||!src)return null;const g=effect('fx-victim fx-victim-waiting',center(r),'',30000),img=document.createElement('img');img.src=src;img.alt='';g.style.width=r.width+'px';g.style.height=r.height+'px';g.append(img);return g;}
 function showEvent(e,d,batch,ghosts){if(!['player_one','player_two'].includes(e.team))return;const rs=(e.targets||[]).map(id=>batch.rects.get(id)).filter(Boolean),area=$('#'+sideKey(d,e.team)+'-field')?.getBoundingClientRect(),p=area?center(area):{x:innerWidth/2,y:innerHeight/2};
  if(reduce()){for(const r of rs.length?rs:[area].filter(Boolean))effect('fx-impact',center(r),'',250);for(const id of e.targets||[])ghosts.get(id)?.remove();return;}
  if(e.kind==='lightning')rs.forEach((r,i)=>wait(()=>{const q=center(r),size=Math.max(160,Math.min(420,q.y+80));window.MythicPaintedFX?.sheet(layer(),'lightning',{left:q.x-size/2,top:q.y-size*.9,width:size,height:size},1100);effect('fx-impact',q,'',700);},i*160));
  if(e.kind==='arrows')rs.forEach((r,i)=>wait(()=>{const q=center(r),arrow=effect('fx-arrow',q,'',850);if(!reduce())arrow.animate([{transform:'translate(-180px,-230px) rotate(-38deg)',opacity:0},{transform:'translate(0,0) rotate(-38deg)',opacity:1,offset:.55},{transform:'translate(0,0) rotate(-38deg)',opacity:0}],{duration:700,fill:'forwards'});effect('fx-impact',q,'',800);},i*110));
  if(e.kind==='hearts'){const q=rs[0]?center(rs[0]):p;window.MythicPaintedFX?.sheet(layer(),'hearts',{left:q.x-95,top:q.y-125,width:190,height:190},1500);}
  if(e.kind==='water'&&area){const field=$('#'+sideKey(d,e.team)+'-field'),lane=field?.querySelector('[data-lane-index="0"]')?.getBoundingClientRect()||area,h=Math.max(100,lane.height);window.MythicPaintedFX?.sheet(layer(),'water',{left:lane.left,top:lane.top-h*.1,width:lane.width,height:h*1.15},950);}
  if(e.kind==='petrify'&&area){const field=$('#'+sideKey(d,e.team)+'-field');field?.classList.add('medusa-casting');wait(()=>field?.classList.remove('medusa-casting'),1800);effect('fx-stone-flash',p,'',1100);}
  if(e.kind==='destroy')for(const [i,id] of (e.targets||[]).entries()){const g=ghosts.get(id),r=batch.rects.get(id);if(g){g.classList.remove('fx-victim-waiting');wait(()=>g.remove(),900);}if(r)wait(()=>burst(r,d,e.team),350+i*70);}
 }
 function roundBanner(d,previous){const winner=d.roundSummary?.winner||(d.player.trixx<previous.playerStars?'enemy':d.enemy.trixx<previous.enemyStars?'player':null),mine=winner==='player'||winner===(d.myTeam||'player_one'),name=mine?(d.playerTeamName||d.playerName||window.MythicOnline?.playerName?.()||'Você'):(d.opponentName||'Guardião');
  const e=document.createElement('div');e.className='round-transition';e.setAttribute('role','status');const title=document.createElement('h2');title.textContent=winner?name+' venceu este Round':'O Round terminou empatado';const small=document.createElement('p');small.textContent='Round '+previous.round;e.append(small,title);document.body.append(e);transitionUntil=Date.now()+(reduce()?450:2000);wait(()=>{title.textContent='Vamos pra próxima';small.textContent='Prepare suas cartas';},reduce()?200:1100);wait(()=>{e.remove();transitionUntil=0;window.MythicGame?.refreshBattle?.();},reduce()?450:2000);
 }
 function holdCharmFields(snapshot,until){
  if(!snapshot||typeof snapshot.player!=='string'||typeof snapshot.enemy!=='string')return;
  if(!heldFields)heldFields=snapshot;fieldHoldUntil=Math.max(fieldHoldUntil,until);const deadline=fieldHoldUntil;
  wait(()=>{if(deadline!==fieldHoldUntil)return;heldFields=null;fieldHoldUntil=0;window.MythicGame?.refreshBattle?.();},deadline-Date.now());
 }
 function showHeldFields(){if(!heldFields||Date.now()>=fieldHoldUntil)return;for(const side of ['player','enemy']){const field=$('#'+side+'-field');if(field)field.innerHTML=heldFields[side];}}
 function finishUI(){if(Date.now()<playUntil){wait(finishUI,playUntil-Date.now()+20);return;}window.MythicGame?.refreshBattle?.();}
 function reset(){heldScores=null;window.MythicMatchPresentation?.cancelVisual?.();timeline=Promise.resolve();pendingBatches=0;activeArrivals.clear();syncArrivals();heldFields=null;fieldHoldUntil=0;generation++;for(const id of timers)clearTimeout(id);timers.clear();root?.replaceChildren();document.querySelectorAll('.round-transition').forEach(e=>e.remove());document.querySelectorAll('.medusa-casting').forEach(e=>e.classList.remove('medusa-casting'));last=null;matchKey=null;transitionUntil=playUntil=0;seen.clear();activeMorphs.clear();document.querySelectorAll(".unit-morphing").forEach(n=>n.classList.remove("unit-morphing"));}
 window.MythicCombatFX={
  before(){capture();},
  sync(d){const key=d.onlineMatchId||d.localMatchId||'guardian',cards=window.MythicCardData?.()||[],units=fieldUnits(d),pending=pendingSource(d,units,cards);
   if(key!==matchKey){reset();matchKey=key;seen=new Set((d.visualEvents||[]).map(e=>e.id));}
   const events=(d.visualEvents||[]).filter(e=>!seen.has(e.id));events.forEach(e=>seen.add(e.id));if(seen.size>300)seen=new Set((d.visualEvents||[]).map(e=>e.id));
   // Freeze positions now: another render must not move the targets of this cast.
   const batch={rects:new Map(rects),portraits:new Map(portraits),fields:fieldSnapshot,scores:scoreSnapshot};document.querySelectorAll('[data-unit-uid]').forEach(node=>{const r=node.getBoundingClientRect();if(r.width&&r.height&&!batch.rects.has(node.dataset.unitUid)){batch.rects.set(node.dataset.unitUid,r);batch.portraits.set(node.dataset.unitUid,node.querySelector('img')?.src);}});const cues=[],morphs=[];
   const add=(id,castKey=null)=>{const card=cards.find(c=>c.id===id);if(card&&!cues.some(c=>castKey?c.castKey===castKey:c.id===id))cues.push({...card,abilityTitle:card.abilityTitle||'Entra em campo',castKey});};
   for(const e of events){const name={water:'water',lightning:'lightning',hearts:'hearts'}[e.kind];if(name)window.MythicPaintedFX?.preload(name);}const entries=events.filter(e=>e.kind==='enter');for(const e of entries)if(!e.quiet)add(e.sourceCardId||units.find(u=>(e.targets||[]).includes(u.uid))?.cardId,e.id);
   if(last){const resolved=last.pendingId&&last.pendingId!==d.pendingEffect?.id;/* A chained choice is part of the same cast, not another activation. */for(const e of events)if(!resolved||!last.pendingCard)add(e.sourceCardId||sources[e.kind]);
    if(last.round===d.round&&!resolved)for(const u of units){if(last.units.some(old=>old.uid===u.uid)||entries.some(e=>(e.targets||[]).includes(u.uid)))continue;if(!events.some(e=>e.kind==='hearts')&&unitEffectsActive(d,u))add(u.cardId);}
    for(const u of units){const entered=entries.find(e=>(e.targets||[]).includes(u.uid)),old=last.units.find(v=>v.uid===u.uid)||(entered&&entered.sourceCardId!==u.cardId?{cardId:entered.sourceCardId}:null);if(old&&u.copiedAbilityId!==old.copiedAbilityId&&u.copiedAbilityId)add('loki');if(old&&u.cardId!==old.cardId){add(u.cardId,'transform:'+u.cardId);const card=cards.find(c=>c.id===u.cardId),before=cards.find(c=>c.id===old.cardId),node=document.querySelector('[data-unit-uid="'+CSS.escape(u.uid)+'"]');if(node&&card&&(/^lobo-/.test(old.cardId)||/^lobo-/.test(u.cardId))){const r=node.getBoundingClientRect(),h=Math.max(160,r.height*2.4),box={left:r.left+r.width/2-h*.4,top:r.top+r.height*.5-h,width:h*.8,height:h};morphs.push({before,card,box,uid:u.uid,lunar:/^lobo-/.test(u.cardId)});}}}
    for(const e of events)if(e.kind==='destroy'&&(e.targets||[]).some(id=>last.units.find(u=>u.uid===id)?.cardId==='osiris'))add('osiris');
   }
   // Keep the pre-draw field visible until the Eclipse announces its outcome.
   if(last&&last.round===d.round&&events.some(e=>e.kind==='enter'&&e.sourceCardId==='eclipse')){
    const delay=window.MythicEclipseUI?.outcomeRemaining?.()||0;if(delay)holdCharmFields(batch.fields,Date.now()+delay);
   }
   const ghosts=new Map();for(const e of events)if(e.kind==='destroy')for(const id of e.targets||[])if(!ghosts.has(id))ghosts.set(id,ghost(id,batch));
   if(events.length||cues.length||morphs.length){
    const token=generation,arrivals=[],arriving=new Set();for(const entry of entries)for(const id of entry.targets||[]){if(!units.some(u=>u.uid===id)||arriving.has(id))continue;arriving.add(id);arrivals.push(stageArrival(id,null));}
    const resources=[...cues.map(c=>c.hologram||c.art),...units.filter(u=>arriving.has(u.uid)).map(u=>cards.find(c=>c.id===u.cardId)?.hologram)].filter(Boolean);
    if(!heldScores&&last)heldScores=batch.scores;pendingBatches++;playUntil=Math.max(Date.now(),playUntil)+cues.length*(reduce()?300:2200)+(arrivals.length?(reduce()?350:1700):0)+2500;
    timeline=timeline.catch(()=>{}).then(async()=>{
     if(token!==generation)return;const trace=window.MythicMatchPresentation?.begin('Sequência visual',false);
     try{
      await Promise.all(resources.map(src=>window.MythicMatchPresentation?.preload(src)));if(token!==generation)return;
      await new Promise(resolve=>requestAnimationFrame(resolve));const flight=window.MythicMatchPresentation?.flightRemaining?.()||0;if(flight)await new Promise(resolve=>wait(resolve,flight));if(token!==generation)return;
      const eclipse=window.MythicEclipseUI?.isRevealing()?window.MythicEclipseUI.remaining?.()||0:0;if(eclipse)await new Promise(resolve=>wait(resolve,eclipse));
      for(const card of cues){if(token!==generation)return;await portrait(card);}if(token!==generation)return;
      for(const begin of arrivals)begin();if(arrivals.length)await new Promise(resolve=>wait(resolve,reduce()?350:1700));if(token!==generation)return;
      for(const m of morphs){const ends=Date.now()+1850;if(!reduce()){activeMorphs.set(m.uid,ends);document.querySelector('[data-unit-uid="'+CSS.escape(m.uid)+'"]')?.classList.add('unit-morphing');window.MythicPaintedFX?.transform(layer(),m.before,m.card,m.box,m.lunar,0,d.sharedZones?.climate==='eclipse-lunar',d.sharedZones?.climate==='eclipse-solar');}}
      if(morphs.length){await new Promise(resolve=>wait(resolve,reduce()?350:1850));for(const m of morphs){activeMorphs.delete(m.uid);document.querySelector('[data-unit-uid="'+CSS.escape(m.uid)+'"]')?.classList.remove('unit-morphing');}}if(token!==generation)return;
      document.querySelectorAll('[data-unit-uid]').forEach(n=>{const r=n.getBoundingClientRect();if(r.width&&r.height)batch.rects.set(n.dataset.unitUid,r);});
      if(last&&events.some(e=>e.kind==='hearts'))holdCharmFields(batch.fields,Date.now()+1500);
      for(const e of events)showEvent(e,d,batch,ghosts);
      if(events.some(e=>e.kind!=='enter'))await new Promise(resolve=>wait(resolve,reduce()?350:1500));
     }catch{if(token===generation){for(const id of arriving)activeArrivals.delete(id);syncArrivals();}}finally{window.MythicMatchPresentation?.end(trace);if(token===generation){pendingBatches=Math.max(0,pendingBatches-1);if(!pendingBatches){heldScores=null;playUntil=0;window.MythicGame?.refreshBattle?.();}}}
    });
   }
   document.querySelectorAll('[data-unit-uid]').forEach(node=>{node.classList.toggle('unit-morphing',(activeMorphs.get(node.dataset.unitUid)||0)>Date.now());const u=units.find(v=>v.uid===node.dataset.unitUid),night=u&&/^lobo-/.test(u.cardId);node.classList.toggle('lunar-empowered',Boolean(night&&d.sharedZones?.climate==='eclipse-lunar'&&unitEffectsActive(d,u)));});
   document.querySelectorAll('.companion-stack').forEach(pile=>pile.classList.toggle('lunar-formation',Boolean(pile.querySelector('.lunar-empowered'))));
   const petrified=d.rulesState?.petrifiedTeams||{},mine=d.myTeam||'player_one',other=mine==='player_one'?'player_two':'player_one';$('#player-field')?.classList.toggle('medusa-petrified',Boolean(d.player.skipNextTurn||petrified[mine]));$('#enemy-field')?.classList.toggle('medusa-petrified',Boolean(d.enemy.skipNextTurn||petrified[other]));
   if(last){for(const side of ['player','enemy'])if(d[side].trixx<last[side+'Stars']){const meter=$('#'+side+'-trixx'),star=meter?.children[d[side].trixx];if(star)burst(star.getBoundingClientRect(),d,teamFor(d,side),true);}if(d.round>last.round){const previous=last,stamp=generation;timeline=timeline.catch(()=>{}).then(()=>{if(stamp===generation){roundBanner(d,previous);window.MythicGame?.refreshBattle?.();}});}}
   if(pendingBatches&&heldScores)for(const [key,value]of Object.entries(heldScores)){const n=$("#"+key+"-score");if(n&&value){n.textContent=value.value;n.parentElement.lastElementChild.textContent=value.label;}}
   showHeldFields();syncArrivals();
   last={round:d.round,playerStars:d.player.trixx,enemyStars:d.enemy.trixx,units,pendingId:d.pendingEffect?.id,pendingCard:pending};
  },
  isBusy:()=>pendingBatches>0||Date.now()<Math.max(transitionUntil,playUntil),isTransitioning:()=>Date.now()<transitionUntil,clear:reset
 };
 document.addEventListener('visibilitychange',()=>{if(document.hidden)reset();else window.MythicGame?.refreshBattle?.();});
})();
