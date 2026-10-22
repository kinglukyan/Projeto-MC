(() => {
 'use strict';
 const box=document.createElement('aside');box.className='atlas-lesson-panel';box.hidden=true;box.setAttribute('aria-label','Guia da Grécia');
 const heading=document.createElement('strong'),copy=document.createElement('p'),close=document.createElement('button'),open=document.createElement('button');
 heading.textContent='GUIA DA GRÉCIA';close.type=open.type='button';close.className='button button-secondary';close.textContent='Entendi';open.className='button button-secondary atlas-lesson-open';open.textContent='Dica do desafio';open.hidden=true;box.append(heading,copy,close);document.body.append(box,open);
 let node=null,run=null,active=false;const dismissed=new Set();
 function paint(){const visible=active&&!document.querySelector('#view-duel')?.hidden;box.hidden=!visible||dismissed.has(run);open.hidden=!visible||!dismissed.has(run);}
 close.onclick=()=>{dismissed.add(run);paint();};open.onclick=()=>{dismissed.delete(run);paint();};
 window.MythicAtlasLesson={set(n,id){node=n;run=id;},sync(duel){active=!!(duel.guardianCampaign?.region==='greece'&&!duel.finished&&node?.lesson);if(active){heading.textContent=`GUIA DA GRÉCIA · DESAFIO ${node.stage}`;copy.textContent=duel.pendingEffect?'Sua carta pede uma escolha. Leia o efeito e selecione um dos alvos permitidos na janela de habilidade.':duel.round>1&&node.stage<=5?'Um novo Round começou: a pontuação é independente. Preserve suas Trixx e use as cartas restantes para vencer este Round.':node.lesson;}paint();}};
 window.addEventListener('mythic-view-changed',paint);window.addEventListener('mythic-account-signed-out',()=>{active=false;node=null;run=null;dismissed.clear();paint();});
})();
