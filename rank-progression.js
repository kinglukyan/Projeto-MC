(() => {
 'use strict';
 const tiers=[
  {name:'Aprendiz de Herói',slug:'aprendiz-de-heroi',base:1000,step:20},
  {name:'Escudeiro',slug:'escudeiro',base:1100,step:30},
  {name:'Herói',slug:'heroi',base:1250,step:40},
  {name:'Lenda',slug:'lenda',base:1450,step:50},
  {name:'Semideus',slug:'semideus',base:1700},
  {name:'Deus',slug:'deus',base:2000},
  {name:'Convergente',slug:'convergente',base:2400}
 ];
 function from(value){const rating=Math.max(1000,Number(value)||1000);let index=0;for(let i=0;i<tiers.length;i++)if(rating>=tiers[i].base)index=i;
  const tier=tiers[index],next=tiers[index+1]||null,kind=index<4?'stars':'points',stars=kind==='stars'?Math.min(4,Math.max(0,Math.floor((rating-tier.base)/tier.step))):null;
  return {rating,index,name:tier.name,slug:tier.slug,emblem:'assets/identity-v2/'+tier.slug+'.webp',kind,stars,points:kind==='points'?rating:null,next:next?.name||null,nextPoints:kind==='points'?next?.base||null:null};
 }
 const label=value=>{const p=from(value);return p.kind==='stars'?p.stars+'/5 estrelas Strix':p.points.toLocaleString('pt-BR')+' pontos';};
 window.MythicRank={from,label,tiers};
 let latest=null,section,emblem,name,amount,stars,copy,fill,milestone,trail,trailIndex=-1;
 const el=(tag,cls,text)=>{const n=document.createElement(tag);n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 function paint(){if(!section)return;section.hidden=window.queueGameMode!=='ranked';if(section.hidden)return;
  const p=latest||window.MythicOnline?.rankProgress?.();section.setAttribute('aria-busy',String(!p));
  if(!p){name.textContent='Carregando seu rank…';emblem.removeAttribute('src');amount.textContent='';stars.hidden=true;copy.textContent='';milestone.textContent='';fill.style.width='0%';return;}
  emblem.src=p.emblem;emblem.alt='Insígnia '+p.name;name.textContent=p.name;amount.textContent=p.kind==='stars'?p.stars+' de 5 estrelas Strix':p.points.toLocaleString('pt-BR')+' pontos';
  stars.hidden=p.kind!=='stars';stars.setAttribute('aria-label',p.stars+' de 5 estrelas Strix');
  [...stars.children].forEach((n,i)=>n.classList.toggle('earned',i<p.stars));
  copy.textContent=p.kind==='stars'?'+1 estrela por vitória · −1 por derrota. '+(p.index===0?'Com zero estrelas, você permanece em Aprendiz.':'Perdeu com zero estrelas? Volta ao rank anterior com quatro.'):'+25 pontos por vitória · −25 por derrota. A partir de Semideus, sua posição é decidida pelos pontos.';
  const progress=p.kind==='stars'?p.stars/5:p.nextPoints?(p.points-tiers[p.index].base)/(p.nextPoints-tiers[p.index].base):1;
  fill.style.width=Math.max(0,Math.min(100,progress*100))+'%';
  milestone.textContent=p.next?(p.kind==='stars'?'Complete 5 estrelas para chegar a '+p.next:p.nextPoints.toLocaleString('pt-BR')+' pontos para chegar a '+p.next):'Você alcançou o último rank da trilha.';
  [...trail.children].forEach((n,i)=>{n.classList.toggle('current',i===p.index);n.classList.toggle('completed',i<p.index);if(i===p.index)n.setAttribute('aria-current','step');else n.removeAttribute('aria-current');n.querySelector('.rank-trail-state').textContent=i===p.index?'SEU RANK':i<p.index?'SUPERADO':'PRÓXIMO';});
  if(trailIndex!==p.index){trailIndex=p.index;requestAnimationFrame(()=>{const item=trail.children[p.index];if(item)trail.scrollLeft+=item.getBoundingClientRect().left-trail.getBoundingClientRect().left-(trail.clientWidth-item.clientWidth)/2;});}
 }
 window.addEventListener('mythic-concept-profile',event=>{latest=event.detail?.rankProgress||null;paint();});
 window.addEventListener('mythic-account-signed-out',()=>{latest=null;paint();});
 document.addEventListener('DOMContentLoaded',()=>{
  const room=document.querySelector('#view-queue');if(!room)return;
  section=el('section','ranked-journey');section.id='ranked-journey';section.hidden=true;section.setAttribute('aria-label','Sua progressão ranqueada');
  const summary=el('div','ranked-summary');emblem=el('img','ranked-emblem');emblem.width=96;emblem.height=96;
  const identity=el('div','ranked-identity');identity.append(el('small','ranked-kicker','SEU RANK ATUAL'));name=el('h2','');identity.append(name);amount=el('b','ranked-amount');identity.append(amount);
  stars=el('div','ranked-strix');stars.setAttribute('role','img');
  for(let i=0;i<5;i++){const star=el('span','');star.setAttribute('aria-hidden','true');star.innerHTML='<svg viewBox="0 0 24 24"><path d="M12 1.8 14.8 9.2 22.2 12 14.8 14.8 12 22.2 9.2 14.8 1.8 12 9.2 9.2Z"/></svg>';stars.append(star);}
  identity.append(stars);const rules=el('div','ranked-rules');copy=el('p','');rules.append(copy);milestone=el('p','ranked-milestone');rules.append(milestone);const bar=el('div','ranked-progress');bar.setAttribute('aria-hidden','true');fill=el('i','');bar.append(fill);rules.append(bar);summary.append(emblem,identity,rules);
  const heading=el('div','ranked-trail-heading');heading.append(el('h3','','Sua trilha de ranks'),el('span','','5 Strix por rank até Lenda'));
  trail=el('ol','ranked-trail');trail.setAttribute('aria-label','Trilha de ranks');
  tiers.forEach((tier,index)=>{const item=el('li',''),icon=el('img','');icon.src='assets/identity-v2/'+tier.slug+'.webp';icon.alt='';icon.loading='lazy';icon.width=70;icon.height=70;item.append(el('small','rank-trail-state','PRÓXIMO'),icon,el('b','',tier.name),el('span','',index<4?'5 estrelas Strix':tier.base.toLocaleString('pt-BR')+'+ pontos'));trail.append(item);});
  const note=el('p','ranked-note','As estrelas Strix indicam sua progressão no rank. Elas são separadas das duas estrelas de cada equipe durante um duelo.');
  section.append(summary,heading,trail,note);room.querySelector('.page-heading').after(section);
  const observer=new MutationObserver(paint);observer.observe(room,{attributes:true,attributeFilter:['hidden','class']});observer.observe(document.querySelector('#queue-heading'),{childList:true,characterData:true,subtree:true});paint();
 });
})();
