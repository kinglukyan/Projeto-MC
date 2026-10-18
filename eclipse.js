(() => {
'use strict';
const data={"cards": [{"id": "eclipse", "name": "Eclipse", "type": "Clima", "kind": "event", "faction": "Universal", "symbol": "◉", "power": 0, "cost": null, "glow": "rgba(242,158,63,.5)", "art": "assets/eclipse/eclipse.png", "abilityTitle": "Destino Celestial", "ability": "Ao jogar na área de Clima/Evento, sorteia Eclipse Lunar ou Solar, com 50% de chance para cada. O resultado afeta os dois lados até o fim da rodada.", "previewOnly": false, "specialOnly": false, "story": ["Eclipse · Clima/Evento.", "Ao jogar na área de Clima/Evento, sorteia Eclipse Lunar ou Solar, com 50% de chance para cada. O resultado afeta os dois lados até o fim da rodada.", "O efeito vale para as cartas já em campo e para as que entrarem depois, nos dois lados. Local e Terreno continuam ativos."]}, {"id": "eclipse-lunar", "name": "Eclipse Lunar", "type": "Clima", "kind": "event", "faction": "Universal", "symbol": "◉", "power": 0, "cost": null, "glow": "rgba(199,65,65,.5)", "art": "assets/eclipse/eclipse-lunar.png", "abilityTitle": "Destino Celestial", "ability": "Mulher e Homem da facção Monstros assumem as formas Alfa e Beta. Lobisomens transformados pelo Solar recuperam sua forma original. Dobra o poder dos lobisomens, vampiros e de Ártemis; Apolo e Rá perdem metade, arredondada para baixo.", "previewOnly": false, "specialOnly": true, "story": ["Eclipse Lunar · Clima/Evento.", "Dobra o poder dos lobisomens, vampiros e de Ártemis. Apolo e Rá perdem metade do poder, arredondada para baixo.", "O efeito vale para as cartas já em campo e para as que entrarem depois, nos dois lados. Local e Terreno continuam ativos.", "Esta é uma forma sorteada do Eclipse e não pode entrar no baralho ou na mão."]}, {"id": "eclipse-solar", "name": "Eclipse Solar", "type": "Clima", "kind": "event", "faction": "Universal", "symbol": "◉", "power": 0, "cost": null, "glow": "rgba(242,158,63,.5)", "art": "assets/eclipse/eclipse-solar.png", "abilityTitle": "Destino Celestial", "ability": "Dobra o poder de Apolo e Rá. Vampiros vão ao Submundo; lobisomens Beta e Omega viram Homem, e Alfa vira Mulher. Ártemis perde metade do poder, arredondada para baixo.", "previewOnly": false, "specialOnly": true, "story": ["Eclipse Solar · Clima/Evento.", "Dobra o poder de Apolo e Rá. Vampiros vão ao Submundo; lobisomens Beta e Omega viram Homem, e Alfa vira Mulher. Ártemis perde metade do poder, arredondada para baixo.", "O efeito vale para as cartas já em campo e para as que entrarem depois, nos dois lados. Local e Terreno continuam ativos.", "Esta é uma forma sorteada do Eclipse e não pode entrar no baralho ou na mão."]}], "solarForms": {"lobo-beta": "homem", "lobo-omega": "homem", "lobo-alfa": "mulher"}, "sunIds": ["apolo", "ra"], "nightIds": ["lobo-alfa", "lobo-beta", "lobo-omega"], "rounding": "floor", "chance": {"lunar": 0.5, "solar": 0.5}, "lunarForms": {"mulher": "lobo-alfa", "homem": "lobo-beta"}};
window.MythicEclipseCards=data.cards;
const isVampire=id=>/^vampir/.test(id||'')||id==='dracula';
const isNight=id=>data.nightIds.includes(id)||isVampire(id);
window.MythicEclipseRules={
 isVampire,isNight,
 roll(){const value=new Uint32Array(1);crypto.getRandomValues(value);return value[0]%2===0?'eclipse-lunar':'eclipse-solar';},
 applySide(side,climate){
  const catalog=window.MythicAbilitiesData?.cards||window.MythicCardData?.()||data.cards;
  const kept=[];side.underworld=side.underworld||[];
  for(const unit of side.field||[]){const original=unit.eclipseOriginalCardId||unit.cardId;
   if(climate==='eclipse-solar'&&isVampire(original)){side.underworld.push(original);continue;}
   const card=catalog.find(c=>c.id===original),form=window.MythicEclipseForms.formFor(original,climate,card);
   unit.cardId=form;if(form!==original)unit.eclipseOriginalCardId=original;else delete unit.eclipseOriginalCardId;kept.push(unit);
  }side.field=kept;
 },
 power(side,unit,power,climate){
  if(unit.cardId==='mulher')power*=2**side.field.filter(other=>other.cardId==='homem').length;
  if(unit.cardId==='homem')power*=2**Math.max(0,side.field.filter(other=>other.cardId==='homem').length-1);
  if(climate==='eclipse-lunar'){
   if(isNight(unit.cardId)||unit.cardId==='artemis')power*=2;
   if(data.sunIds.includes(unit.cardId))power=Math.floor(power/2);
  }else if(climate==='eclipse-solar'){
   if(data.sunIds.includes(unit.cardId))power*=2;
   if(unit.cardId==='artemis')power=Math.floor(power/2);
  }return Math.max(0,power);
 }
};
let activeReveal=null,cleanupTimer=null,resolveTimer=null;
const seen=new Set();
function seenBefore(id){if(seen.has(id))return true;seen.add(id);try{const key='mythic-eclipse-reveal:'+id;if(sessionStorage.getItem(key))return true;sessionStorage.setItem(key,'1');}catch{}return false;}
function closeReveal(){clearTimeout(cleanupTimer);clearTimeout(resolveTimer);const wasOpen=Boolean(activeReveal);activeReveal?.remove();activeReveal=null;if(wasOpen)window.MythicGame?.refreshBattle?.();}
function reveal(event){
 if(!event?.id||!['eclipse-lunar','eclipse-solar'].includes(event.outcome)||seenBefore(event.id))return;
 if(activeReveal){clearTimeout(cleanupTimer);clearTimeout(resolveTimer);activeReveal.remove();activeReveal=null;}const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
 const panel=document.createElement('section');panel.className='eclipse-reveal';panel.dataset.outcome=event.outcome;panel.setAttribute('role','status');panel.setAttribute('aria-live','polite');panel.setAttribute('aria-label','Sorteio do Eclipse');
 panel.innerHTML='<div class="eclipse-reveal-vignette"></div><div class="eclipse-reveal-copy"><p>O DESTINO DA ARENA</p><h2>Sol ou Lua?</h2><span>50% LUNAR · 50% SOLAR</span></div><div class="eclipse-orbit"><i></i><i></i><div class="eclipse-orb"></div></div><div class="eclipse-fates"></div><div class="eclipse-result" aria-live="polite"></div><button type="button" class="eclipse-skip">Pular animação</button>';
 const fates=panel.querySelector('.eclipse-fates');
 for(const card of data.cards.slice(1)){const figure=document.createElement('figure');figure.className='eclipse-fate';figure.dataset.card=card.id;const img=document.createElement('img');img.src=card.art;img.alt=card.name;const caption=document.createElement('figcaption');caption.textContent=card.name;figure.append(img,caption);fates.append(figure);}
 const resolve=()=>{panel.classList.add('resolved');panel.querySelector('h2').textContent=event.outcome==='eclipse-lunar'?'A Lua domina a arena':'O Sol domina a arena';panel.querySelector('.eclipse-result').textContent=data.cards.find(c=>c.id===event.outcome).ability;};
 panel.querySelector('button').onclick=()=>{resolve();clearTimeout(resolveTimer);clearTimeout(cleanupTimer);cleanupTimer=setTimeout(closeReveal,650);};
 document.body.append(panel);activeReveal=panel;
 if(reduced){panel.classList.add('reduced');resolve();}else resolveTimer=setTimeout(resolve,1300);
 cleanupTimer=setTimeout(closeReveal,reduced?1800:3200);
}
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&activeReveal)closeReveal();});
window.MythicEclipseUI={
 isRevealing:()=>Boolean(activeReveal),
 close:closeReveal,
 sync(duel){
  const board=document.querySelector('#view-duel .battle-board');if(!board)return;
  const climate=duel?.sharedZones?.climate;
  if(['eclipse-lunar','eclipse-solar'].includes(climate)){
   board.dataset.eclipse=climate.endsWith('lunar')?'lunar':'solar';
   let badge=board.querySelector('.eclipse-map-badge');if(!badge){badge=document.createElement('div');badge.className='eclipse-map-badge';board.append(badge);}
   badge.textContent=climate==='eclipse-lunar'?'☾ ECLIPSE LUNAR':'☀ ECLIPSE SOLAR';
   if(!board.querySelector('.eclipse-map-particles')){const particles=document.createElement('div');particles.className='eclipse-map-particles';particles.setAttribute('aria-hidden','true');for(let i=0;i<16;i++){const mote=document.createElement('i');mote.style.cssText='--i:'+i+';left:'+((i*37)%100)+'%;top:'+((i*19)%100)+'%';particles.append(mote);}board.append(particles);}
  }else{delete board.dataset.eclipse;board.querySelector('.eclipse-map-badge')?.remove();board.querySelector('.eclipse-map-particles')?.remove();}
  const match=duel?.onlineMatchId||duel?.localMatchId||'guardian',key=match+':'+duel?.round+':'+climate;
  if(!document.hidden&&['eclipse-lunar','eclipse-solar'].includes(climate)){
   // Older matches may not contain eclipseReveal. Derive a stable event, never reroll.
   const event=duel?.eclipseReveal?.outcome===climate?duel.eclipseReveal:{id:key,outcome:climate};
   reveal(event);
  }
 }
};
})();
