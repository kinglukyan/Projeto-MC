(() => {
  'use strict';
  const MIN=14,MAX=35,$=s=>document.querySelector(s);
  const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const norm=value=>String(value||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  const image=card=>/^(assets\/|https:\/\/)/.test(card?.art||'')?card.art:'assets/card-back.svg';
  const sum=counts=>Object.values(counts).reduce((n,v)=>n+Number(v||0),0);
  const clean=counts=>Object.fromEntries(Object.entries(counts||{}).filter(([,n])=>Number(n)>0).map(([id,n])=>[id,Number(n)]));
  const signature=deck=>JSON.stringify({name:deck.name.trim(),counts:Object.entries(clean(deck.counts)).sort(([a],[b])=>a.localeCompare(b))});
  const icons={back:'<path d="m14 5-7 7 7 7M7 12h14"/>',close:'<path d="m6 6 12 12M18 6 6 18"/>',save:'<path d="M5 3h12l4 4v14H3V3h2Zm2 0v6h10V3M7 21v-8h10v8"/>',undo:'<path d="m8 5-5 5 5 5M3 10h10a7 7 0 0 1 7 7"/>',trash:'<path d="M3 6h18M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7M14 10v7"/>',search:'<circle cx="10" cy="10" r="6"/><path d="m15 15 6 6"/>',grip:'<path d="M9 5h.01M15 5h.01M9 12h.01M15 12h.01M9 19h.01M15 19h.01"/>'};
  const icon=name=>`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name]||''}</svg>`;
  let root=null,zoom=null,exitDialog=null,state=null,selectedId=null,faction='all',kind='all',query='',undo=[],busy=false,previousFocus=null,drag=null,ghost=null,messageTimer=0,pendingDrag=null,holdTimer=0,suppressClickUntil=0;
  const read=()=>window.MythicDeckEditor?.read();
  const catalog=()=>read()?.cards||[];
  const cardFor=id=>catalog().find(card=>card.id===id);
  const owned=card=>card&&!card.specialOnly&&!card.previewOnly?Math.max(0,Number(card.owned)||0):0;
  const dirty=()=>state&&signature(state)!==state.baseline;
  const draftKey=()=>state?`mythic-builder-draft:${state.userId}:${state.slot}`:null;
  function remember(){try{if(state&&dirty())sessionStorage.setItem(draftKey(),JSON.stringify({name:state.name,counts:state.counts,baseline:state.baseline}));else if(state)sessionStorage.removeItem(draftKey());}catch{}}
  function message(text='',sticky=false){clearTimeout(messageTimer);if(!root)return;root.querySelector('#db-message').textContent=text;if(text&&!sticky)messageTimer=setTimeout(()=>{if(root)root.querySelector('#db-message').textContent='';},3800);}
  function checkpoint(){undo.push({name:state.name,counts:{...state.counts}});if(undo.length>50)undo.shift();}
  function ensure(){
    if(root)return;
    root=document.createElement('dialog');root.id='deck-builder';root.className='db-dialog';root.setAttribute('aria-labelledby','db-title');
    root.innerHTML=`<div class="db-shell">
      <header class="db-header"><button type="button" class="db-plain db-back" data-action="exit">${icon('back')}<span>Voltar aos decks</span></button><h1 id="db-title">CONSTRUTOR DE DECKS</h1><label class="db-name"><span class="db-sr">Nome do baralho</span><input id="db-name" maxlength="24" autocomplete="off" placeholder="Nome do baralho"></label><span class="db-dirty" hidden>Não salvo</span><button type="button" class="db-plain db-close" data-action="exit" aria-label="Fechar construtor">${icon('close')}</button></header>
      <main class="db-workspace"><section class="db-preview" aria-label="Carta selecionada"><button type="button" class="db-preview-art" data-action="zoom" aria-label="Ampliar carta selecionada"><img id="db-preview-image" alt="" decoding="async" draggable="false"></button><div class="db-preview-copy"><strong id="db-preview-name"></strong><p id="db-preview-meta"></p><p id="db-preview-ability"></p><button type="button" class="db-button db-add-selected" data-action="add-selected">Adicionar à mesa <b>+</b></button></div></section>
      <section class="db-table" data-db-drop="table" aria-labelledby="db-table-title"><header class="db-table-header"><div><h2 id="db-table-title">SEU BARALHO</h2><p id="db-composition"></p></div><div class="db-size"><strong id="db-total">0 / 35 <small>CARTAS</small></strong><span id="db-validity"></span></div><p class="db-limits">Mínimo 14 · Máximo 35</p></header><div id="db-progress" class="db-progress" role="progressbar" aria-valuemin="0" aria-valuemax="35" aria-label="Cartas na mesa"></div><div class="db-table-scroll"><div id="db-table-grid" class="db-table-grid"></div></div><p id="db-message" class="db-message" aria-live="polite"></p></section></main>
      <section class="db-collection" data-db-drop="collection" aria-labelledby="db-collection-title"><header class="db-collection-toolbar"><h2 id="db-collection-title">SUA COLEÇÃO</h2><label class="db-search">${icon('search')}<input id="db-search" type="search" placeholder="Buscar carta…" aria-label="Buscar carta na coleção"></label><div id="db-factions" class="db-factions" aria-label="Filtrar por facção"></div><select id="db-kind" aria-label="Filtrar tipo"><option value="all">Todos os tipos</option><option value="unit">Personagens</option><option value="special">Especiais</option></select><button type="button" class="db-plain db-mobile-preview" data-action="zoom">Ampliar selecionada</button></header><div id="db-collection-belt" class="db-collection-belt"></div><p class="db-help">Segure uma carta para arrastar até a mesa ou use +. Para retirar, use − ou arraste de volta à coleção.</p></section>
      <footer class="db-footer"><button type="button" class="db-button db-secondary" data-action="clear">${icon('trash')}<span>Limpar mesa</span></button><button type="button" class="db-button db-secondary" data-action="undo">${icon('undo')}<span>Desfazer</span></button><button type="button" class="db-button db-secondary" data-action="suggest">Sugerir deck</button><button type="button" class="db-button db-secondary" data-action="evaluate">Avaliar deck</button><span id="db-save-note" class="db-save-note">Selecione de 14 a 35 cartas.</span><button type="button" class="db-button db-primary" data-action="save">${icon('save')}<span>Salvar baralho</span></button></footer>
    </div>`;
    document.body.append(root);
    zoom=document.createElement('dialog');zoom.className='db-zoom';zoom.setAttribute('aria-label','Carta ampliada');zoom.innerHTML=`<button type="button" class="db-plain db-zoom-close" aria-label="Fechar carta ampliada">${icon('close')}</button><img alt="" decoding="async"><div><h2></h2><p class="db-zoom-meta"></p><h3></h3><p class="db-zoom-ability"></p></div>`;document.body.append(zoom);
    zoom.querySelector('button').addEventListener('click',()=>zoom.close());zoom.addEventListener('click',event=>{event.stopPropagation();if(event.target===zoom)zoom.close();});
    exitDialog=document.createElement('dialog');exitDialog.className='db-exit';exitDialog.setAttribute('aria-labelledby','db-exit-title');exitDialog.innerHTML='<h2 id="db-exit-title">Deseja salvar o deck?</h2><p>Há alterações não salvas. Você pode salvar antes de sair.</p><div><button type="button" class="db-button" data-exit="continue">Continuar editando</button><button type="button" class="db-button db-secondary" data-exit="discard">Sair sem salvar</button><button type="button" class="db-button db-primary" data-exit="save">Salvar e sair</button></div>';document.body.append(exitDialog);
    exitDialog.addEventListener('click',event=>{event.stopPropagation();const action=event.target.closest('[data-exit]')?.dataset.exit;if(!action)return;if(action==='continue')exitDialog.close();else if(action==='discard'){exitDialog.close();close(true);}else{exitDialog.close();save();}});
    root.addEventListener('cancel',event=>{event.preventDefault();requestClose();});
    root.addEventListener('click',onClick);
    root.querySelector('#db-search').addEventListener('input',event=>{query=norm(event.target.value);renderCollection();});
    root.querySelector('#db-kind').addEventListener('change',event=>{kind=event.target.value;renderCollection();});
    root.querySelector('#db-name').addEventListener('input',event=>{if(!busy){state.name=event.target.value;remember();renderStatus();}});
    root.addEventListener('dragstart',event=>{if(event.target.closest('.db-card-art,.db-preview-art'))event.preventDefault();});
    root.addEventListener('contextmenu',event=>{if(drag||pendingDrag)event.preventDefault();});
    root.addEventListener('pointerdown',event=>{
      const handle=event.target.closest('[data-drag-handle],.db-card-art,.db-preview-art'),item=handle?.closest('[data-source][data-card]');
      if(!item||busy||event.button!==0||!event.isPrimary)return;
      clearDrag();
      pendingDrag={id:item.dataset.card,source:item.dataset.source,pointer:event.pointerId,type:event.pointerType,x:event.clientX,y:event.clientY,lastX:event.clientX,lastY:event.clientY,scroll:handle.closest('.db-collection-belt,.db-table-scroll')};
      if(handle.hasAttribute('data-drag-handle')){event.preventDefault();startPointerDrag();}
      else holdTimer=setTimeout(startPointerDrag,300);
    });
    root.addEventListener('pointermove',event=>{
      if(pendingDrag?.pointer!==event.pointerId&&drag?.pointer!==event.pointerId)return;
      if(pendingDrag){
        const p=pendingDrag,dx=event.clientX-p.lastX,dy=event.clientY-p.lastY;p.lastX=event.clientX;p.lastY=event.clientY;
        const distance=Math.hypot(event.clientX-p.x,event.clientY-p.y);
        if(p.mode==='scroll'){event.preventDefault();if(p.scroll){p.scroll.scrollLeft-=dx;p.scroll.scrollTop-=dy;}return;}
        if(distance>8){if(p.type==='touch'){clearTimeout(holdTimer);p.mode='scroll';suppressClickUntil=performance.now()+500;root.setPointerCapture(event.pointerId);if(p.scroll){p.scroll.scrollLeft-=dx;p.scroll.scrollTop-=dy;}event.preventDefault();return;}startPointerDrag();}
      }
      if(drag?.pointer!==event.pointerId)return;
      event.preventDefault();moveGhost(event);markDrop(document.elementFromPoint(event.clientX,event.clientY)?.closest('[data-db-drop]'));
    });
    root.addEventListener('pointerup',event=>{
      if(pendingDrag?.pointer!==event.pointerId&&drag?.pointer!==event.pointerId)return;
      if(drag?.pointer===event.pointerId){event.preventDefault();suppressClickUntil=performance.now()+500;dropOn(document.elementFromPoint(event.clientX,event.clientY)?.closest('[data-db-drop]'));}
      else if(pendingDrag?.mode==='scroll')suppressClickUntil=performance.now()+500;
      clearDrag();
    });
    root.addEventListener('pointercancel',clearDrag);
    window.addEventListener('blur',clearDrag);
    root.addEventListener('keydown',event=>{
      if((event.ctrlKey||event.metaKey)&&event.key.toLowerCase()==='s'){event.preventDefault();save();}
      if((event.ctrlKey||event.metaKey)&&event.key.toLowerCase()==='z'&&!event.target.matches('input,select,textarea')){event.preventDefault();undoChange();}
    });
  }
  function startPointerDrag(){
    clearTimeout(holdTimer);if(!pendingDrag||busy||!root?.open)return;
    const p=pendingDrag,card=cardFor(p.id);
    if(!card||p.source==='collection'&&(state.counts[p.id]||0)>=owned(card)){clearDrag();message('Todas as cópias dessa carta já estão na mesa.');return;}
    drag={id:p.id,source:p.source,pointer:p.pointer};pendingDrag=null;
    root.setPointerCapture(p.pointer);suppressClickUntil=performance.now()+500;
    ghost=document.createElement('img');ghost.className='db-drag-ghost';ghost.src=image(card);ghost.alt='';root.append(ghost);
    moveGhost({clientX:p.lastX,clientY:p.lastY});root.classList.add('db-dragging');
  }
  function moveGhost(event){if(ghost){ghost.style.left=`${event.clientX}px`;ghost.style.top=`${event.clientY}px`;}}
  function markDrop(target){root.querySelectorAll('[data-db-drop]').forEach(node=>node.classList.toggle('db-drop-ready',node===target));}
  function clearDrag(){clearTimeout(holdTimer);const pointer=drag?.pointer??pendingDrag?.pointer;pendingDrag=null;if(pointer!==undefined&&root?.hasPointerCapture(pointer))root.releasePointerCapture(pointer);drag=null;ghost?.remove();ghost=null;root?.classList.remove('db-dragging');if(root)markDrop(null);}
  function dropOn(target){if(!drag||!target||busy)return;if(target.dataset.dbDrop==='table'&&drag.source==='collection')change(drag.id,1);else if(target.dataset.dbDrop==='collection'&&drag.source==='table')change(drag.id,-1);}
  function thumb(card,source){return `<article class="db-card ${selectedId===card.id?'db-selected':''} ${source==='collection'&&owned(card)<=(state.counts[card.id]||0)?'db-used':''}" data-card="${escape(card.id)}" data-source="${source}"><button type="button" class="db-card-art" data-action="select" draggable="false" aria-label="Selecionar ${escape(card.name)}"><img src="${escape(image(card))}" alt="${escape(card.name)}" loading="lazy" decoding="async" draggable="false"><span class="db-card-quantity">${source==='table'?(window.MythicAvailability?.isDisabled(card.id)?'Pausada · ':'')+state.counts[card.id]+'×':Math.max(0,owned(card)-(state.counts[card.id]||0))+' livres'}</span></button><div class="db-card-controls">${source==='table'?`<button type="button" data-action="remove" aria-label="Retirar ${escape(card.name)}" ${busy?'disabled':''}>−</button><span>${state.counts[card.id]}</span>`:`<button type="button" data-drag-handle aria-label="Arrastar ${escape(card.name)}">${icon('grip')}</button>`}<button type="button" data-action="add" aria-label="Adicionar ${escape(card.name)}" ${busy||window.MythicAvailability?.isDisabled(card.id)||sum(state.counts)>=MAX||(state.counts[card.id]||0)>=owned(card)?'disabled':''}>+</button></div></article>`;}
  function renderTable(){
    const cards=catalog(),map=new Map(cards.map(c=>[c.id,c]));
    root.querySelector('#db-table-grid').innerHTML=Object.keys(state.counts).filter(id=>state.counts[id]>0&&map.has(id)).map(id=>thumb(map.get(id),'table')).join('')+(sum(state.counts)<MAX?'<div class="db-empty-slot" aria-hidden="true"><span>+</span><small>Solte uma carta aqui</small></div>':'');
  }
  function renderCollection(){
    if(!state||!root.open)return;
    const belt=root.querySelector('#db-collection-belt'),left=belt.scrollLeft;
    const cards=catalog().filter(c=>!window.MythicAvailability?.isDisabled(c.id)&&owned(c)>(state.counts[c.id]||0)&&(faction==='all'||c.faction===faction)&&(kind==='all'||(kind==='unit'?c.kind==='unit':c.kind!=='unit'))&&(!query||norm(`${c.name} ${c.faction} ${c.ability} ${c.type}`).includes(query)));
    belt.innerHTML=cards.length?cards.map(card=>thumb(card,'collection')).join(''):'<p class="db-empty">Nenhuma cópia disponível neste filtro. Retire uma carta da mesa para disponibilizá-la aqui.</p>';belt.scrollLeft=left;
  }
  function renderPreview(){
    const card=cardFor(selectedId),img=root.querySelector('#db-preview-image'),art=root.querySelector('.db-preview-art');
    art.dataset.card=card?.id||'';art.dataset.source='collection';
    if(card){if(img.getAttribute('src')!==image(card))img.src=image(card);img.alt=card.name;root.querySelector('#db-preview-name').textContent=card.name;root.querySelector('#db-preview-meta').textContent=`${card.subtype||card.type} · ${card.faction} · ${card.power||0} poder`;root.querySelector('#db-preview-ability').textContent=card.ability||'';}
    else{img.removeAttribute('src');img.alt='';root.querySelector('#db-preview-name').textContent='Selecione uma carta';root.querySelector('#db-preview-meta').textContent='';root.querySelector('#db-preview-ability').textContent='Sua coleção aparece abaixo.';}
    const add=root.querySelector('[data-action="add-selected"]');add.disabled=busy||!card||window.MythicAvailability?.isDisabled(card?.id)||sum(state.counts)>=MAX||(state.counts[card?.id]||0)>=owned(card);
    root.querySelector('.db-mobile-preview').disabled=!card;
  }
  function validate(){return Object.entries(state.counts).every(([id,n])=>Number.isInteger(n)&&n>=0&&n<=owned(cardFor(id)));}
  function renderStatus(){
    const total=sum(state.counts),valid=total>=MIN&&total<=MAX&&validate();
    root.querySelector('#db-total').innerHTML=`${total} / 35 <small>CARTAS</small>`;
    const status=root.querySelector('#db-validity');status.classList.toggle('is-ready',valid);status.textContent=valid?'✓ Baralho pronto':!validate()?'Revise sua coleção':total<MIN?`Faltam ${MIN-total} cartas`:'Limite excedido';
    const units=catalog().filter(c=>c.kind==='unit').reduce((n,c)=>n+(state.counts[c.id]||0),0);root.querySelector('#db-composition').textContent=`${units} personagens · ${total-units} especiais`;
    const progress=root.querySelector('#db-progress');progress.setAttribute('aria-valuenow',String(total));progress.innerHTML=Array.from({length:MAX},(_,i)=>`<i class="${i<total?'is-filled':''} ${i===MIN-1?'db-minimum':''}"></i>`).join('');
    root.querySelector('[data-action="save"]').disabled=busy||!valid;root.querySelector('[data-action="save"] span').textContent=busy?'Salvando…':'Salvar baralho';
    root.querySelector('[data-action="undo"]').disabled=busy||!undo.length;root.querySelector('[data-action="clear"]').disabled=busy||!total;
    root.querySelector('#db-name').disabled=busy;root.querySelector('.db-dirty').hidden=!dirty();
    root.querySelector('#db-save-note').textContent=busy?'Aguarde a confirmação da sua conta.':valid?'Pronto para salvar na sua conta.':`Use de ${MIN} a ${MAX} cartas da sua coleção.`;
  }
  function render(){
    if(!state||!root.open)return;
    const focused=document.activeElement,item=focused?.closest('[data-card]'),action=focused?.dataset.action,source=item?.dataset.source,id=item?.dataset.card;
    renderTable();renderCollection();renderPreview();renderStatus();
    if(id&&action){const candidate=[...root.querySelectorAll('[data-card]')].find(n=>n.dataset.card===id&&n.dataset.source===source);candidate?.querySelector(`[data-action="${action}"]`)?.focus({preventScroll:true});}
  }
  function change(id,delta){
    if(delta>0&&window.MythicAvailability?.isDisabled(id)){message("Esta carta está temporariamente pausada.");return;}
    if(busy||!state)return;const card=cardFor(id),old=state.counts[id]||0,next=old+delta;
    if(delta>0&&sum(state.counts)>=MAX){message('O baralho aceita no máximo 35 cartas.');return;}
    if(!card||next<0||next>owned(card)){message('Você já usou todas as cópias disponíveis dessa carta.');return;}
    checkpoint();if(next)state.counts[id]=next;else delete state.counts[id];selectedId=id;remember();render();
  }
  function undoChange(){if(!busy&&undo.length){const prior=undo.pop();state.name=prior.name;state.counts={...prior.counts};root.querySelector('#db-name').value=state.name;remember();render();}}
  function enlarge(){if(!root?.open||!state||exitDialog?.open||zoom?.open)return;const card=cardFor(selectedId);if(!card)return;zoom.querySelector('img').src=image(card);zoom.querySelector('img').alt=card.name;zoom.querySelector('h2').textContent=card.name;zoom.querySelector('.db-zoom-meta').textContent=`${card.subtype||card.type} · ${card.faction} · ${card.power||0} poder`;zoom.querySelector('h3').textContent=card.abilityTitle||'Habilidade';zoom.querySelector('.db-zoom-ability').textContent=card.ability||'';zoom.showModal();}
  function onClick(event){
    event.stopPropagation();
    if(event.target.closest('[data-action="suggest"]')){if(!busy)window.MythicAutoDeck?.open();return;}
    if(event.target.closest('[data-action="evaluate"]')){if(state)window.MythicDeckEvaluator?.open(state.counts,catalog(),state.name||'Edição atual');return;}
    if(event.target.closest('[data-action="exit"]')){event.preventDefault();requestClose();return;}
    if(event.detail!==0&&performance.now()<suppressClickUntil){event.preventDefault();return;}
    const filter=event.target.closest('[data-faction]');if(filter){faction=filter.dataset.faction;root.querySelectorAll('[data-faction]').forEach(n=>n.setAttribute('aria-pressed',String(n===filter)));renderCollection();return;}
    const control=event.target.closest('[data-action]');if(!control)return;
    const action=control.dataset.action,id=control.closest('[data-card]')?.dataset.card;
    if(action==='exit'){requestClose();return;}if(busy)return;
    if(action==='select'){selectedId=id;renderPreview();root.querySelectorAll('[data-card]').forEach(n=>n.classList.toggle('db-selected',n.dataset.card===id));}
    else if(action==='add')change(id,1);else if(action==='remove')change(id,-1);else if(action==='add-selected'&&selectedId)change(selectedId,1);
    else if(action==='zoom')enlarge();else if(action==='undo')undoChange();else if(action==='clear'){checkpoint();state.counts={};remember();render();message('Mesa limpa. Use Desfazer para recuperar as cartas.');}else if(action==='save')save();
  }
  async function save(){
    if(state&&window.MythicAvailability?.checkDeck(state.counts)===false)return;
    if(busy||!state)return;
    if(!validate()||sum(state.counts)<MIN||sum(state.counts)>MAX){message('Revise o baralho: são necessárias de 14 a 35 cartas válidas.',true);return;}
    busy=true;clearDrag();render();message('Salvando o baralho na sua conta…',true);
    try{
      await window.MythicDeckEditor.commit({slot:state.slot,name:state.name,counts:{...state.counts},userId:state.userId});
      if(!state)return;try{sessionStorage.removeItem(draftKey());}catch{}
      busy=false;close(false);window.MythicPresentation?.notify('Baralho salvo na sua conta.');
    }catch(error){busy=false;if(state){message(error.message||'Não foi possível salvar. Suas alterações continuam na mesa.',true);render();}}
  }
  function requestClose(){if(!root?.open||!state)return;clearDrag();if(busy){message('Aguarde a confirmação do salvamento.');return;}if(zoom?.open)zoom.close();if(dirty()){exitDialog.querySelector('[data-exit="save"]').disabled=!validate()||sum(state.counts)<MIN||sum(state.counts)>MAX;if(!exitDialog.open)exitDialog.showModal();}else close(false);}
  function close(discard=false){
    if(!root)return;if(discard&&state){try{sessionStorage.removeItem(draftKey());}catch{}}
    clearDrag();zoom?.close();exitDialog?.close();root.close();document.body.classList.remove('deck-builder-open');state=null;undo=[];busy=false;
    if(previousFocus?.isConnected)previousFocus.focus({preventScroll:true});else $('#deck-builder-entry')?.focus({preventScroll:true});
  }
  function open(){
    if(root?.open)return;
    if(!window.MythicOnline?.isConnected?.()){window.MythicOnline?.requireLogin?.();return;}
    if(!window.MythicOnline.profileReady?.()){window.MythicPresentation?.notify('Aguarde o carregamento da sua coleção.');return;}
    const source=read();if(!source)return;ensure();previousFocus=document.activeElement;
    state={slot:source.slot,name:source.name,counts:clean(source.counts),userId:source.userId};state.baseline=signature(state);undo=[];busy=false;query='';faction='all';kind='all';
    let recovered=false;try{const saved=JSON.parse(sessionStorage.getItem(draftKey())||'null');if(saved?.baseline===state.baseline){state.name=String(saved.name||source.name).slice(0,24);state.counts=clean(saved.counts);recovered=true;}}catch{}
    selectedId=Object.keys(state.counts).find(id=>cardFor(id))||source.cards.find(c=>owned(c)>0)?.id||null;
    root.querySelector('#db-name').value=state.name;root.querySelector('#db-search').value='';root.querySelector('#db-kind').value='all';
    const factions=[...new Set(source.cards.filter(c=>owned(c)>0).map(c=>c.faction))];root.querySelector('#db-factions').innerHTML=[['all','Todas'],...factions.map(f=>[f,f])].map(([value,label])=>`<button type="button" data-faction="${escape(value)}" aria-pressed="${value==='all'}">${escape(label)}</button>`).join('');
    document.body.classList.add('deck-builder-open');root.showModal();render();root.querySelector('.db-back').focus();if(recovered)message('Sua edição anterior foi recuperada.');
  }
  window.MythicDeckBuilder={open,applySuggestion:counts=>{if(!root?.open||!state||busy)throw Error('Abra o construtor antes de usar a sugestão.');const n=sum(counts);if(n<MIN||n>MAX||!Object.entries(counts).every(([id,n])=>Number.isInteger(n)&&n>0&&n<=owned(cardFor(id))&&!window.MythicAvailability?.isDisabled(id)))throw Error('A coleção mudou. Gere novamente a sugestão.');checkpoint();state.counts={...counts};remember();render();},close:()=>requestClose(),isOpen:()=>Boolean(root?.open)};
  const deckView=$('#view-decks');if(deckView){const entry=document.createElement('button');entry.id='deck-builder-entry';entry.className='button button-primary';entry.type='button';entry.innerHTML='<span aria-hidden="true">✦</span> Modo Construtor';entry.addEventListener('click',()=>{if(window.MythicOpenSelectedDeckBuilder)window.MythicOpenSelectedDeckBuilder();else open();});deckView.querySelector('.page-heading')?.append(entry);}
  window.addEventListener('mythic-account-signed-out',()=>{if(root?.open)close(true);});
  window.addEventListener('mythic-profile-loaded',()=>{if(root?.open&&state?.userId!==window.MythicOnline?.userId?.())close(true);});
  window.addEventListener('mythic-inventory-loaded',()=>{if(root?.open){if(!validate())message('Sua coleção mudou. Revise as cópias destacadas antes de salvar.',true);render();}});
})();
