(() => {
 'use strict';let openId=null,revealId=null,submitting=null;
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 function close(){document.querySelectorAll('.ability-source-active,.ability-target-active').forEach(n=>n.classList.remove('ability-source-active','ability-target-active'));document.getElementById('ability-choice-dialog')?.remove();openId=null;}
 function modal(title){const d=el('dialog','ability-choice-dialog');d.id='ability-choice-dialog';const h=el('h2','',title);h.id='ability-choice-title';d.setAttribute('aria-labelledby',h.id);const list=el('div','ability-choices');d.append(h,list);return [d,list];}
 function cardFor(option,cards,pending){const index=Number(option.value),id=option.cardId||option.card_id||((pending?.event?.remaining||[])[index])||option.value;const fallback=(window.MythicAbilitiesData?.cards||[]).find(c=>c.id===id),known=cards[id]||fallback;return known?{...fallback,...known,art:known.art||fallback?.art||option.cardArt,name:known.name||option.cardName}:option.cardName?{id,name:option.cardName,art:option.cardArt}:null;}
 function instruction(p){const e=p.event||{},op=e.rule?.op||e.op;
  if(e.phase==='draft')return 'Escolha a carta que vai para sua mão. Em seguida, escolha a ordem das restantes no fundo do baralho.';
  if(e.phase==='order')return `Escolha a próxima carta na ordem ${e.destination==='bottom'?'do fundo':'do topo'} do seu baralho. As cartas serão colocadas na sequência que você selecionar.`;
  if(e.phase==='lane'||e.op==='move_lane')return 'Escolha a fileira que receberá a unidade selecionada.';
  if(op==='choice'&&!e.phase)return 'Escolha qual efeito deseja usar. Se escolher o bônus de poder, você selecionará o aliado em seguida.';
  if(op==='recover')return 'Escolha a carta do seu Submundo que voltará para sua mão.';
  if(op==='copyPower')return 'Escolha de qual unidade o poder será copiado. Confira a equipe e a fileira antes de confirmar.';
  return 'Escolha uma das opções abaixo para resolver esta habilidade e concluir a jogada.';
 }
 function button(option,cards,callback,pending=null,duel=null){
  const b=el('button','ability-choice-option');b.type='button';const c=cardFor(option,cards,pending);
  if(c?.art){const img=el('img');img.src=window.MythicSecurity?.assetUrl?.(c.art)||c.art;img.alt=c.name;img.decoding='async';img.loading='eager';b.append(img);}
  b.append(el('strong','',option.label||c?.name||'Escolher esta opção'));
  const target=['player','enemy'].flatMap(side=>(duel?.[side]?.field||[]).map(u=>({u,side}))).find(({u})=>u.uid===option.value||String(option.value).endsWith(':'+u.uid));
  if(target)b.append(el('small','ability-option-location',`${target.side==='player'?'Sua equipe':'Adversário'} · Fileira ${Number(target.u.lane)+1}`));
  if(c){b.append(el('small','ability-option-meta',`${c.faction||''}${c.kind==='unit'?' · '+c.power+' de poder':''}`));if(c.abilityTitle)b.append(el('span','ability-option-title',c.abilityTitle));if(c.ability)b.append(el('small','ability-option-ability',c.ability));}
  b.onclick=()=>callback(option.value);return b;
 }
 window.MythicAbilitiesUI={
  sync(duel,cards,choose){
   if(duel?.finished){close();return;}if(window.MythicEclipseUI?.isRevealing()||window.MythicCombatFX?.isBusy()){if(openId)close();return;}
   const p=duel?.pendingEffect,me=duel?.practice?p?.actor:duel?.online?window.MythicOnline?.userId?.():'player';
   if(!p||p.actor!==me){if(openId)close();return;}
   if(openId===p.id){for(const b of document.querySelectorAll('#ability-choice-dialog button'))b.disabled=submitting===p.id||(b.dataset.confirm==='true'&&!b.dataset.selected);return;}
   close();openId=p.id;const [d,list]=modal(p.title||'Escolha da habilidade');d.addEventListener('cancel',e=>e.preventDefault());
   const info=el('p','ability-choice-instruction',instruction(p));info.setAttribute('role','status');d.insertBefore(info,list);
   const source=(duel.player.field||[]).concat(duel.enemy.field||[]).find(u=>u.uid===p.event?.uid);const sourceCard=cards[p.event?.cardId||source?.copiedAbilityId||source?.cardId];if(sourceCard)d.insertBefore(el('p','ability-choice-source',sourceCard.name+' · '+(sourceCard.abilityTitle||'Habilidade')),info);
   if(p.event?.op==='foresight'){const top=cards[duel.practice&&p.actor==='enemy'?duel.enemy.deck[0]:duel.player.deck[0]];if(top){const peek=el('div','ability-peek'),img=el('img');img.src=top.art||'assets/card-back.svg';img.alt='Topo do seu baralho: '+top.name;peek.append(img,el('strong','',top.name));d.insertBefore(peek,list);}}
   if(source?.uid)document.querySelectorAll('[data-unit-uid="'+CSS.escape(source.uid)+'"]').forEach(n=>n.classList.add('ability-source-active'));
   let selected=null;const preview=el('p','ability-selected-preview','Selecione uma opção para conferir antes de confirmar.'),confirm=el('button','button button-primary','Confirmar escolha');confirm.type='button';confirm.disabled=true;confirm.dataset.confirm='true';
   for(const option of p.options||[]){const b=button(option,cards,value=>{selected=String(value);for(const n of list.children)n.setAttribute('aria-pressed',String(n===b));confirm.disabled=false;confirm.dataset.selected='true';preview.textContent='Sua escolha: '+(option.label||cardFor(option,cards,p)?.name||String(value));document.querySelectorAll('.ability-target-active').forEach(n=>n.classList.remove('ability-target-active'));for(const n of document.querySelectorAll('[data-unit-uid]'))if(n.dataset.unitUid===selected||selected.endsWith(':'+n.dataset.unitUid))n.classList.add('ability-target-active');},p,duel);b.setAttribute('aria-pressed','false');list.append(b);}
   confirm.onclick=async()=>{if(selected===null||submitting===p.id)return;submitting=p.id;for(const b of d.querySelectorAll('button'))b.disabled=true;info.textContent='Confirmando sua escolha…';try{const result=await choose({type:'resolve_effect',choice_id:p.id,choice_value:selected});if(result===false&&d.isConnected)info.textContent='A escolha não foi confirmada. Você pode tentar novamente.';}catch(error){if(d.isConnected)info.textContent=error?.message||'Não foi possível confirmar a escolha.';}finally{if(submitting===p.id)submitting=null;if(d.isConnected)for(const b of d.querySelectorAll('button'))b.disabled=false;}};
   d.append(preview,confirm);
   document.body.append(d);d.showModal();list.querySelector('button')?.focus({preventScroll:true});
  },
  reveal(duel,cards){if(duel?.finished||window.MythicCombatFX?.isBusy()||window.MythicEclipseUI?.isRevealing())return;const r=duel?.player?.privateEffects;if(!r?.id||r.id===revealId||!r.cards?.length||duel.pendingEffect)return;try{if(sessionStorage.getItem('mythic-reveal:'+r.id))return;sessionStorage.setItem('mythic-reveal:'+r.id,'1');}catch{}revealId=r.id;close();const[d,list]=modal('Olho de Hórus — cartas reveladas');for(const id of r.cards)list.append(button({cardId:id,label:cards[id]?.name||id},cards,()=>{}));const done=el('button','ability-choice-done','Continuar');done.type='button';done.onclick=()=>d.close();d.append(done);d.addEventListener('close',()=>d.remove());document.body.append(d);d.showModal();},close
 };
})();
