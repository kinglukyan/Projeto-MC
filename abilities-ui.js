(() => {
'use strict';let openId=null,revealId=null;
function close(){document.getElementById('ability-choice-dialog')?.remove();openId=null;}
function modal(title){const d=document.createElement('dialog');d.id='ability-choice-dialog';d.className='ability-choice-dialog';const h=document.createElement('h2');h.textContent=title;h.id='ability-choice-title';d.setAttribute('aria-labelledby',h.id);d.append(h);const list=document.createElement('div');list.className='ability-choices';d.append(list);return [d,list];}
function button(option,cards,callback){const b=document.createElement('button');b.type='button';const c=cards[option.cardId];if(c?.art){const img=document.createElement('img');img.src=c.art;img.alt='';b.append(img);}const text=document.createElement('span');text.textContent=option.label;b.append(text);b.onclick=()=>callback(option.value);return b;}
window.MythicAbilitiesUI={
 sync(duel,cards,choose){
  const p=duel?.pendingEffect,me=duel?.online?window.MythicOnline?.userId?.():'player';
  if(!p||p.actor!==me){if(openId)close();return;}
  if(openId===p.id){for(const b of document.querySelectorAll('#ability-choice-dialog button'))b.disabled=false;return;}close();openId=p.id;
  const [d,list]=modal(p.title||'Escolha o alvo');d.addEventListener('cancel',event=>event.preventDefault());
  const info=document.createElement('p');info.textContent='Resolva esta habilidade para concluir a jogada.';d.insertBefore(info,list);
  if(p.event.op==='foresight'){const top=cards[duel.player.deck[0]];if(top){const peek=document.createElement('div');peek.className='ability-peek';const image=document.createElement('img');image.src=top.art||'assets/card-back.svg';image.alt='Topo do seu baralho: '+top.name;peek.append(image);const name=document.createElement('strong');name.textContent=top.name;peek.append(name);d.insertBefore(peek,list);}}
  for(const option of p.options){list.append(button(option,cards,value=>{for(const b of list.querySelectorAll('button'))b.disabled=true;choose({type:'resolve_effect',choice_id:p.id,choice_value:value});}));}
  document.body.append(d);d.showModal();
 },
 reveal(duel,cards){const r=duel?.player?.privateEffects;if(!r?.id||r.id===revealId||!r.cards?.length||duel.pendingEffect)return;try{if(sessionStorage.getItem('mythic-reveal:'+r.id))return;sessionStorage.setItem('mythic-reveal:'+r.id,'1');}catch{}revealId=r.id;close();const [d,list]=modal('Olho de Hórus — cartas reveladas');for(const id of r.cards)list.append(button({cardId:id,label:cards[id]?.name||id},cards,()=>{}));const done=document.createElement('button');done.type='button';done.className='ability-choice-done';done.textContent='Continuar';done.onclick=()=>d.close();d.append(done);d.addEventListener('close',()=>d.remove());document.body.append(d);d.showModal();},
 close
};
})();
