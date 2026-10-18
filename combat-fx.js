(() => {
 'use strict';
 const $=s=>document.querySelector(s),reduce=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
 let rects=new Map(),portraits=new Map(),seen=new Set(),matchKey=null,last=null,transitionUntil=0,playUntil=0,root=null,generation=0;
 const timers=new Set(),center=r=>({x:r.left+r.width/2,y:r.top+r.height/2});
 const wait=(fn,ms)=>{const token=generation,id=setTimeout(()=>{timers.delete(id);if(token===generation)fn();},Math.max(0,ms));timers.add(id);return id;};
 function layer(){if(!root){root=document.createElement('div');root.id='combat-effects';root.setAttribute('aria-hidden','true');document.body.append(root);}return root;}
 function effect(cls,point,text='',duration=900){const e=document.createElement('span');e.className='combat-fx '+cls;e.textContent=text;e.style.left=point.x+'px';e.style.top=point.y+'px';layer().append(e);wait(()=>e.remove(),duration);return e;}
 const sideKey=(d,t)=>t===(d.myTeam||'player_one')?'player':'enemy';
 const teamFor=(d,side)=>side==='player'?(d.myTeam||'player_one'):(d.myTeam==='player_two'?'player_one':'player_two');
 function capture(){rects=new Map();portraits=new Map();document.querySelectorAll('[data-unit-uid]').forEach(e=>{rects.set(e.dataset.unitUid,e.getBoundingClientRect());portraits.set(e.dataset.unitUid,e.querySelector('img')?.src);});}
 function fieldUnits(d){return ['player','enemy'].flatMap(side=>(d[side]?.field||[]).map(u=>({...u,team:teamFor(d,side)})));}
 function pendingSource(d,units,cards){const p=d.pendingEffect;if(!p)return null;if(p.event?.cardId)return p.event.cardId;const unit=units.find(u=>u.uid===p.event?.uid);if(unit)return unit.cardId;const title=String(p.title||'').toLocaleLowerCase('pt-BR');return cards.find(c=>title.startsWith(c.name?.toLocaleLowerCase('pt-BR')+':'))?.id||null;}
 const sources={lightning:'zeus',arrows:'artemis',hearts:'afrodite',water:'poseidon',petrify:'medusa'};
 const themes={zeus:'lightning',thor:'lightning',medusa:'stone',afrodite:'love',poseidon:'ocean',artemis:'moon',hades:'underworld',isis:'life',anubis:'underworld',osiris:'life',loki:'illusion',odin:'runes',horus:'sun',ra:'sun',apolo:'sun',dionisio:'wine',seth:'sand'};
 function portrait(card){const e=document.createElement('section');e.className='ability-cinematic';e.dataset.theme=themes[card.id]||'runes';e.setAttribute('role','status');e.setAttribute('aria-label',card.name+' — '+card.abilityTitle);
  const glow=document.createElement('i');glow.className='ability-cinematic-aura';const img=document.createElement('img');img.src=window.MythicSecurity.assetUrl(card.hologram||card.art);img.alt='';img.className='ability-cinematic-hero';img.decoding='async';const copy=document.createElement('div');copy.className='ability-cinematic-copy';const name=document.createElement('small');name.textContent=card.name;const title=document.createElement('h2');title.textContent=card.abilityTitle||'Habilidade ativada';copy.append(name,title);e.append(glow,img,copy);
  for(let i=0;i<(reduce()?0:12);i++){const spark=document.createElement('i');spark.className='ability-cinematic-spark';spark.style.setProperty('--i',i);e.append(spark);}layer().append(e);wait(()=>e.remove(),reduce()?550:1200);
 }
 function burst(r,d,t,star=false){const p=center(r),dest=$(sideKey(d,t)==='player'?'#underworld-pile':'#enemy-underworld')?.getBoundingClientRect(),end=dest?center(dest):p;effect(star?'fx-star-burst':'fx-card-burst',p,star?'✦':'',900);if(reduce())return;
  const count=matchMedia('(max-width:600px)').matches?12:22;
  for(let i=0;i<count;i++){const part=effect('fx-particle'+(star?' star-shard':''),p,'',1400),angle=Math.PI*2*i/count,dist=25+Math.random()*60;part.animate([{transform:'translate(-50%,-50%) scale(1)',opacity:1},{transform:`translate(${Math.cos(angle)*dist}px,${Math.sin(angle)*dist}px) scale(.8)`,opacity:1,offset:.32},{transform:`translate(${end.x-p.x}px,${end.y-p.y}px) scale(.12)`,opacity:0}],{duration:1100,delay:i*9,easing:'ease-in',fill:'forwards'});}
 }
 function ghost(id,batch){const r=batch.rects.get(id),src=batch.portraits.get(id);if(!r||!src)return null;const g=effect('fx-victim fx-victim-waiting',center(r),'',30000),img=document.createElement('img');img.src=src;img.alt='';g.style.width=r.width+'px';g.style.height=r.height+'px';g.append(img);return g;}
 function showEvent(e,d,batch,ghosts){const rs=(e.targets||[]).map(id=>batch.rects.get(id)).filter(Boolean),area=$('#'+sideKey(d,e.team)+'-field')?.getBoundingClientRect(),p=area?center(area):{x:innerWidth/2,y:innerHeight/2};
  if(e.kind==='lightning')rs.forEach((r,i)=>wait(()=>{const q=center(r),bolt=effect('fx-lightning',q,'',950);bolt.style.height=Math.max(130,q.y)+'px';effect('fx-impact',q,'',700);},i*160));
  if(e.kind==='arrows')rs.forEach((r,i)=>wait(()=>{const q=center(r),arrow=effect('fx-arrow',q,'',850);if(!reduce())arrow.animate([{transform:'translate(-180px,-230px) rotate(-38deg)',opacity:0},{transform:'translate(0,0) rotate(-38deg)',opacity:1,offset:.55},{transform:'translate(0,0) rotate(-38deg)',opacity:0}],{duration:700,fill:'forwards'});effect('fx-impact',q,'',800);},i*110));
  if(e.kind==='hearts')for(let i=0;i<(reduce()?1:9);i++){const q=rs[0]?center(rs[0]):p,h=effect('fx-heart',{x:q.x+(i%3-1)*24,y:q.y},'♥',1450);h.style.animationDelay=i*50+'ms';}
  if(e.kind==='water'&&area){const w=effect('fx-wave',{x:area.left,y:area.top},'',1500);w.style.width=area.width+'px';w.style.height=area.height+'px';}
  if(e.kind==='petrify'&&area){const field=$('#'+sideKey(d,e.team)+'-field');field?.classList.add('medusa-casting');wait(()=>field?.classList.remove('medusa-casting'),1800);effect('fx-stone-flash',p,'',1100);}
  if(e.kind==='destroy')for(const [i,id] of (e.targets||[]).entries()){const g=ghosts.get(id),r=batch.rects.get(id);if(g){g.classList.remove('fx-victim-waiting');wait(()=>g.remove(),900);}if(r)wait(()=>burst(r,d,e.team),350+i*70);}
 }
 function roundBanner(d,previous){const winner=d.roundSummary?.winner||(d.player.trixx<previous.playerStars?'enemy':d.enemy.trixx<previous.enemyStars?'player':null),mine=winner==='player'||winner===(d.myTeam||'player_one'),name=mine?(d.playerTeamName||d.playerName||window.MythicOnline?.playerName?.()||'Você'):(d.opponentName||'Guardião');
  const e=document.createElement('div');e.className='round-transition';e.setAttribute('role','status');const title=document.createElement('h2');title.textContent=winner?name+' ganhou essa rodada':'A rodada terminou empatada';const small=document.createElement('p');small.textContent='Rodada '+previous.round;e.append(small,title);document.body.append(e);transitionUntil=Date.now()+2000;wait(()=>{title.textContent='Vamos pra próxima';small.textContent='Prepare suas cartas';},1100);wait(()=>{e.remove();transitionUntil=0;window.MythicGame?.refreshBattle?.();},2000);
 }
 function finishUI(){if(Date.now()<playUntil){wait(finishUI,playUntil-Date.now()+20);return;}window.MythicGame?.refreshBattle?.();}
 function reset(){generation++;for(const id of timers)clearTimeout(id);timers.clear();root?.replaceChildren();document.querySelectorAll('.round-transition').forEach(e=>e.remove());document.querySelectorAll('.medusa-casting').forEach(e=>e.classList.remove('medusa-casting'));last=null;matchKey=null;transitionUntil=playUntil=0;seen.clear();}
 window.MythicCombatFX={
  before(){capture();},
  sync(d){const key=d.onlineMatchId||d.localMatchId||'guardian',cards=window.MythicCardData?.()||[],units=fieldUnits(d),pending=pendingSource(d,units,cards);
   if(key!==matchKey){reset();matchKey=key;seen=new Set((d.visualEvents||[]).map(e=>e.id));}
   const events=(d.visualEvents||[]).filter(e=>!seen.has(e.id));events.forEach(e=>seen.add(e.id));if(seen.size>300)seen=new Set((d.visualEvents||[]).map(e=>e.id));
   // Freeze positions now: another render must not move the targets of this cast.
   const batch={rects:new Map(rects),portraits:new Map(portraits)},cues=[];
   const add=id=>{const card=cards.find(c=>c.id===id);if(card?.abilityTitle&&!cues.some(c=>c.id===id))cues.push(card);};
   if(last){const resolved=last.pendingId&&last.pendingId!==d.pendingEffect?.id;if(resolved)add(last.pendingCard);for(const e of events)if(!resolved||!last.pendingCard)add(e.sourceCardId||sources[e.kind]);
    if(last.round===d.round&&!resolved)for(const u of units){if(last.units.some(old=>old.uid===u.uid)||u.cardId===pending)continue;if(Number(d.round)>Number(d.silenceUntilRound||0))add(u.cardId);}
    for(const u of units){const old=last.units.find(v=>v.uid===u.uid);if(old&&u.copiedAbilityId!==old.copiedAbilityId&&u.copiedAbilityId)add('loki');if(old&&u.cardId!==old.cardId)add(u.cardId);}
    for(const e of events)if(e.kind==='destroy'&&(e.targets||[]).some(id=>last.units.find(u=>u.uid===id)?.cardId==='osiris'))add('osiris');
   }
   const ghosts=new Map();for(const e of events)if(e.kind==='destroy')for(const id of e.targets||[])if(!ghosts.has(id))ghosts.set(id,ghost(id,batch));
   if(events.length||cues.length){const start=Math.max(0,playUntil-Date.now(),window.MythicEclipseUI?.isRevealing()?3200:0),intro=reduce()?450:1250;cues.forEach((card,i)=>wait(()=>portrait(card),start+i*intro));const impact=start+cues.length*intro;for(const e of events)wait(()=>showEvent(e,d,batch,ghosts),impact);playUntil=Date.now()+impact+(events.length?1800:200);wait(finishUI,playUntil-Date.now()+20);}
   const petrified=d.rulesState?.petrifiedTeams||{},mine=d.myTeam||'player_one',other=mine==='player_one'?'player_two':'player_one';$('#player-field')?.classList.toggle('medusa-petrified',Boolean(d.player.skipNextTurn||petrified[mine]));$('#enemy-field')?.classList.toggle('medusa-petrified',Boolean(d.enemy.skipNextTurn||petrified[other]));
   if(last){for(const side of ['player','enemy'])if(d[side].trixx<last[side+'Stars']){const meter=$('#'+side+'-trixx'),star=meter?.children[d[side].trixx];if(star)burst(star.getBoundingClientRect(),d,teamFor(d,side),true);}if(d.round>last.round)roundBanner(d,last);}
   last={round:d.round,playerStars:d.player.trixx,enemyStars:d.enemy.trixx,units,pendingId:d.pendingEffect?.id,pendingCard:pending};
  },
  isBusy:()=>Date.now()<Math.max(transitionUntil,playUntil),isTransitioning:()=>Date.now()<transitionUntil,clear:reset
 };
 document.addEventListener('visibilitychange',()=>{if(document.hidden)reset();else window.MythicGame?.refreshBattle?.();});
})();
