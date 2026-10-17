(() => {
 'use strict';
 const $=s=>document.querySelector(s), reduce=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
 let rects=new Map(),portraits=new Map(),seen=new Set(),matchKey=null,last=null,transitionUntil=0,playUntil=0,root=null;
 const center=r=>({x:r.left+r.width/2,y:r.top+r.height/2});
 function layer(){if(!root){root=document.createElement('div');root.id='combat-effects';root.setAttribute('aria-hidden','true');document.body.append(root);}return root;}
 function effect(cls,point,text='',duration=900){const e=document.createElement('span');e.className='combat-fx '+cls;e.textContent=text;e.style.left=point.x+'px';e.style.top=point.y+'px';layer().append(e);setTimeout(()=>e.remove(),duration);return e;}
 function sideKey(duel,team){return team===(duel.myTeam||'player_one')?'player':'enemy';}
 function teamRect(duel,team){return $('#'+sideKey(duel,team)+'-field')?.getBoundingClientRect();}
 function capture(){rects=new Map();portraits=new Map();document.querySelectorAll('[data-unit-uid]').forEach(e=>{rects.set(e.dataset.unitUid,e.getBoundingClientRect());portraits.set(e.dataset.unitUid,e.querySelector('img')?.src);});}
 function targets(e,duel){return (e.targets||[]).map(id=>rects.get(id)||document.querySelector('[data-unit-uid="'+CSS.escape(id)+'"]')?.getBoundingClientRect()).filter(Boolean);}
 function burst(r,duel,team,star=false){const p=center(r),dest=$(sideKey(duel,team)==='player'?'#underworld-pile':'#enemy-underworld')?.getBoundingClientRect(),end=dest?center(dest):p;effect(star?'fx-star-burst':'fx-card-burst',p,star?'✦':'',900);if(reduce())return;
  for(let i=0;i<(matchMedia('(max-width:600px)').matches?10:18);i++){const part=effect('fx-particle'+(star?' star-shard':''),p,'',1300),angle=Math.PI*2*i/18,dist=25+Math.random()*60;part.animate([{transform:'translate(-50%,-50%) scale(1)',opacity:1},{transform:`translate(${Math.cos(angle)*dist}px,${Math.sin(angle)*dist}px) scale(.8)`,opacity:1,offset:.32},{transform:`translate(${end.x-p.x}px,${end.y-p.y}px) scale(.12)`,opacity:0}],{duration:1100,delay:i*9,easing:'ease-in',fill:'forwards'});}
 }
 function showEvent(e,duel){const rs=targets(e,duel),area=teamRect(duel,e.team),p=area?center(area):{x:innerWidth/2,y:innerHeight/2};
  if(e.kind==='lightning')rs.forEach((r,i)=>setTimeout(()=>{const q=center(r),bolt=effect('fx-lightning',q,'',950);bolt.style.height=Math.max(130,q.y)+'px';effect('fx-impact',q,'',700);},i*160));
  if(e.kind==='arrows')rs.forEach((r,i)=>setTimeout(()=>{const q=center(r),arrow=effect('fx-arrow',q,'',850);arrow.animate([{transform:'translate(-180px,-230px) rotate(-38deg)',opacity:0},{transform:'translate(0,0) rotate(-38deg)',opacity:1,offset:.55},{transform:'translate(0,0) rotate(-38deg)',opacity:0}],{duration:700,fill:'forwards'});effect('fx-impact',q,'',800);},i*110));
  if(e.kind==='hearts'){for(let i=0;i<(reduce()?1:9);i++){const q=rs[0]?center(rs[0]):p;const h=effect('fx-heart',{x:q.x+(i%3-1)*24,y:q.y},'♥',1450);h.style.animationDelay=i*50+'ms';}}
  if(e.kind==='water'&&area){const w=effect('fx-wave',{x:area.left,y:area.top},'',1500);w.style.width=area.width+'px';w.style.height=area.height+'px';}
  if(e.kind==='petrify'&&area){const field=$('#'+sideKey(duel,e.team)+'-field');field?.classList.add('medusa-casting');setTimeout(()=>field?.classList.remove('medusa-casting'),1800);effect('fx-stone-flash',p,'',1100);}
  if(e.kind==='destroy'){for(const id of e.targets||[]){const r=rects.get(id),src=portraits.get(id);if(r&&src){const ghost=effect('fx-victim',center(r),'',900),image=document.createElement('img');image.src=src;image.alt='';ghost.style.width=r.width+'px';ghost.style.height=r.height+'px';ghost.append(image);}}rs.forEach((r,i)=>setTimeout(()=>burst(r,duel,e.team),e.delay||350+i*70));}
 }
 function roundBanner(duel,previous){const winner=duel.roundSummary?.winner||(duel.player.trixx<previous.playerStars?'enemy':duel.enemy.trixx<previous.enemyStars?'player':null),name=winner==='player'||winner===duel.myTeam||winner==='player_one'&&!duel.myTeam?(duel.playerTeamName||duel.playerName||window.MythicOnline?.playerName?.()||'Você'):(duel.opponentName||'Guardião');
  const d=document.createElement('div');d.className='round-transition';d.setAttribute('role','status');d.setAttribute('aria-live','assertive');const title=document.createElement('h2');title.textContent=winner?name+' ganhou essa rodada':'A rodada terminou empatada';const small=document.createElement('p');small.textContent='Rodada '+previous.round;d.append(small,title);document.body.append(d);transitionUntil=Date.now()+2000;setTimeout(()=>{if(!d.isConnected)return;title.textContent='Vamos pra próxima';small.textContent='Prepare suas cartas';},1100);setTimeout(()=>{d.remove();transitionUntil=0;},2000);
 }
 window.MythicCombatFX={
  before(duel){capture();},
  sync(duel){const key=duel.onlineMatchId||duel.localMatchId||'guardian';if(key!==matchKey){matchKey=key;seen=new Set((duel.visualEvents||[]).map(e=>e.id));last=null;root?.replaceChildren();}
   for(const e of duel.visualEvents||[]){if(seen.has(e.id))continue;seen.add(e.id);showEvent(e,duel);playUntil=Math.max(playUntil,Date.now()+1400);}if(seen.size>300){seen=new Set((duel.visualEvents||[]).map(e=>e.id));}
   const petrified=duel.rulesState?.petrifiedTeams||{},mine=duel.myTeam||'player_one',other=mine==='player_one'?'player_two':'player_one';$('#player-field')?.classList.toggle('medusa-petrified',Boolean(duel.player.skipNextTurn||petrified[mine]));$('#enemy-field')?.classList.toggle('medusa-petrified',Boolean(duel.enemy.skipNextTurn||petrified[other]));
   if(last){for(const who of ['player','enemy']){const old=last[who+'Stars'],now=duel[who].trixx;if(now<old){const meter=$('#'+who+'-trixx'),star=meter?.children[now];if(star)burst(star.getBoundingClientRect(),duel,who===(duel.myTeam||'player_one')?'player_one':who==='player'?(duel.myTeam||'player_one'):(duel.myTeam==='player_two'?'player_one':'player_two'),true);}}
    if(duel.round>last.round)roundBanner(duel,last);
   }last={round:duel.round,playerStars:duel.player.trixx,enemyStars:duel.enemy.trixx};
  },
  isBusy:()=>Date.now()<Math.max(transitionUntil,playUntil),
  isTransitioning:()=>Date.now()<transitionUntil,
  clear(){root?.replaceChildren();document.querySelectorAll('.round-transition').forEach(e=>e.remove());last=null;matchKey=null;transitionUntil=playUntil=0;seen.clear();}
 };
 document.addEventListener('visibilitychange',()=>{if(document.hidden){root?.replaceChildren();document.querySelectorAll('.round-transition').forEach(e=>e.remove());}});
})();
