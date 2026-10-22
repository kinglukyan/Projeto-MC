(() => {
 'use strict';
 const $=s=>document.querySelector(s),$$=s=>[...document.querySelectorAll(s)];
 const make=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const picture=(src,cls='',alt='')=>{const n=make('img',cls);n.src=window.MythicSecurity.assetUrl(src,'assets/card-back.svg');n.alt=alt;n.loading='lazy';n.decoding='async';return n;};
 const button=(text,action,cls='button button-secondary')=>{const n=make('button',cls,text);n.type='button';if(action)n.addEventListener('click',action);return n;};
 const panel=(title,cls='')=>{const n=make('section','epic-panel '+cls);if(title)n.append(make('h2','',title));return n;};
 const empty=(root,text)=>root.append(make('p','empty-state',text));
 const data=()=>window.MythicPresentation?.read()||{cards:[],decks:[],activeSlot:0};
 const model={deckSelectionStatus:"",profile:null,deckStats:[],community:[],authors:{},guild:null,previewSlot:0};
 const rankAsset=value=>'assets/identity-v2/'+(value<1100?'aprendiz-de-heroi':value<1250?'escudeiro':value<1450?'heroi':value<1700?'lenda':value<2000?'semideus':value<2400?'deus':'convergente')+'.webp';
 const fan=(counts,cls='')=>{const n=make('div','concept-card-fan '+cls),catalog=data().cards;const cards=Object.entries(counts||{}).filter(([,v])=>Number(v)>0).map(([id])=>catalog.find(c=>c.id===id)).filter(Boolean).sort((a,b)=>Number(b.power)-Number(a.power));for(const card of cards.slice(0,3))n.append(picture(card.art,'',card.name));if(!cards.length)n.append(picture('assets/card-back.svg'));return n;};
 const setHeading=(id,title,subtitle)=>{const root=$(id);if(!root)return;const h=root.querySelector(':scope>.page-heading h1'),p=root.querySelector(':scope>.page-heading>div>p:last-child');if(h)h.textContent=title;if(p)p.textContent=subtitle;};
 document.body.classList.add('concept-ui');

 // Account header is separate from the preserved sidebar and battle.
 const account=make('div','concept-account-bar'),avatar=make('span','concept-account-avatar','MC'),identity=make('div','concept-account-name'),accountName=make('b','','Sua lenda'),accountLevel=make('small','','Entre na sua conta'),xp=make('progress'),balance=make('span','concept-account-coins');xp.max=100;xp.value=0;identity.append(accountName,accountLevel,xp);balance.append(make('span','concept-coin','MC'));const coins=make('b','','—');balance.append(coins);account.append(avatar,identity,balance);$('.main-content>.topbar').after(account);
 const syncAccount=()=>{const p=model.profile;accountName.textContent=p?.name||'Sua lenda';accountLevel.textContent=p?`Nível ${p.level} · ${p.rank}`:'Entre na sua conta';xp.value=Number(p?.xp||0)%100;coins.textContent=p?Number(p.coins||0).toLocaleString('pt-BR'):'—';avatar.replaceChildren();if(p?.avatar)avatar.append(picture(p.avatar));else avatar.textContent=(p?.name||'MC').slice(0,2).toUpperCase();$$('.concept-queue-avatar.self').forEach(n=>{n.replaceChildren();if(p?.avatar)n.append(picture(p.avatar));else n.textContent=(p?.name||'MC').slice(0,2).toUpperCase();});};
 const syncAccountVisibility=()=>{account.hidden=document.body.classList.contains('duel-fullscreen');};new MutationObserver(syncAccountVisibility).observe(document.body,{attributes:true,attributeFilter:['class']});syncAccountVisibility();

 // Arena: keep the live mode buttons and their event handlers.
 const modeAssets={bot:'guardian',normal:'normal',ranked:'ranked',friend:'x1',custom:'custom'};
 $$('#view-arena .arena-mode-card').forEach(card=>{const img=card.querySelector('img');if(img)img.src=card.dataset.mode==='tournament'?'assets/mode-tournament.webp':`assets/concept-ui/mode-${modeAssets[card.dataset.mode]}.png`;});
 const arenaLayout=$('#view-arena .arena-layout'),activeDeck=$('#view-arena .arena-active-deck'),featured=$('#view-arena .featured-panel');
 if(arenaLayout&&activeDeck){$('#view-arena .home-lower').append(featured);arenaLayout.append(activeDeck);const minis=make('div','concept-mini-decks');minis.id='concept-arena-decks';activeDeck.querySelector('header').after(minis);}
 if(featured){featured.querySelector('.featured-card-button img')?.classList.add('concept-feature-art');}
 setHeading('#view-arena','A ARENA TE ESPERA','Escolha seu próximo desafio.');

 // Deck gallery wraps, rather than replaces, the existing editor.
 setHeading('#view-decks','MEUS BARALHOS','Forje sua estratégia e escolha as lendas que irão para a Arena.');
 const deckView=$('#view-decks'),deckHeading=deckView.querySelector('.page-heading');
 window.MythicSelectedPracticeDeck=()=>({...data().decks[model.previewSlot]?.cards});
 window.MythicOpenSelectedDeckBuilder=()=>{const select=$('#deck-slot-select');select.value=String(model.previewSlot);select.dispatchEvent(new Event('change',{bubbles:true}));window.MythicDeckBuilder?.open();};
 function createDeck(){
  if(!window.MythicOnline?.isConnected?.()){window.MythicOnline?.requireLogin?.();return;}
  if(!window.MythicOnline.profileReady?.()){window.MythicPresentation?.notify('Aguarde o carregamento da sua coleção.');return;}
  const state=data(),emptyIndex=state.decks.findIndex(deck=>!Object.values(deck.cards||{}).some(n=>Number(n)>0));
  if(emptyIndex>=0){const select=$('#deck-slot-select');select.value=String(emptyIndex);select.dispatchEvent(new Event('change',{bubbles:true}));}
  else{if($('#new-deck').disabled){window.MythicPresentation?.notify('Você já tem 7 baralhos. Exclua um para liberar espaço.');return;}$('#new-deck').click();}
  model.previewSlot=data().activeSlot;window.MythicDeckBuilder?.open();
 }
 const deleteDialog=make('dialog','db-exit deck-delete-modal');deleteDialog.setAttribute('aria-labelledby','deck-delete-title');
 const deleteTitle=make('h2','','Excluir baralho?');deleteTitle.id='deck-delete-title';const deleteCopy=make('p'),deleteError=make('p','deck-delete-error');deleteError.setAttribute('role','status');const deleteActions=make('div');
 let deleting=false,deleteTarget=null;
 const deleteCancel=button('Cancelar',()=>deleteDialog.close(),'db-button db-secondary');
 const deleteConfirm=button('Excluir baralho',async()=>{
  if(deleting||deleteTarget===null)return;deleting=true;deleteCancel.disabled=true;deleteConfirm.disabled=true;deleteConfirm.textContent='Excluindo…';deleteError.textContent='';
  try{await window.MythicDeckEditor.remove(deleteTarget);model.previewSlot=data().activeSlot;deleteDialog.close();drawDecks();window.MythicPresentation?.notify('Baralho excluído. Suas cartas continuam na coleção.');}
  catch(error){deleteError.textContent=error.message||'Não foi possível excluir o baralho.';}
  finally{deleting=false;deleteCancel.disabled=false;deleteConfirm.disabled=false;deleteConfirm.textContent='Excluir baralho';}
 },'db-button deck-delete-confirm');
 deleteActions.append(deleteCancel,deleteConfirm);deleteDialog.append(deleteTitle,deleteCopy,deleteError,deleteActions);document.body.append(deleteDialog);
 deleteDialog.addEventListener('cancel',event=>{if(deleting)event.preventDefault();});
 function requestDeleteDeck(index){const deck=data().decks[index];if(!deck)return;deleteTarget=index;deleteCopy.textContent=`Excluir “${deck.name}”? As cartas continuam na sua coleção. Só a montagem do baralho será apagada.`;deleteError.textContent='';deleteDialog.showModal();deleteCancel.focus();}
 const deckTools=make('div','concept-deck-tools'),deckSearch=make('input');deckSearch.type='search';deckSearch.placeholder='Buscar baralhos…';deckSearch.setAttribute('aria-label','Buscar baralhos');const deckSort=make('select');deckSort.setAttribute('aria-label','Ordenar baralhos');deckSort.append(new Option('Ordem dos decks','default'),new Option('Nome','name'),new Option('Mais cartas','count'));deckTools.append(deckSearch,deckSort);deckHeading.after(deckTools);
 const deckLayout=make('div','concept-deck-layout'),deckGallery=make('div','concept-deck-gallery'),deckDetail=panel('','concept-deck-detail');deckLayout.append(deckGallery,deckDetail);deckTools.after(deckLayout);
 const editor=make('div','concept-deck-editor');editor.hidden=true;editor.setAttribute('aria-hidden','true');for(const n of [...deckView.querySelectorAll(':scope>.deck-summary,:scope>#deck-card-list,:scope>#deck-save-status')])editor.append(n);deckView.append(editor);
 async function copyCode(value){try{await navigator.clipboard.writeText(value);window.MythicPresentation?.notify('Código copiado.');}catch{window.MythicPresentation?.notify('Não foi possível copiar. Permita acesso à área de transferência.');}}
 function drawDecks(){
  const state=data();if(!state.decks.length)return;
  if(!state.decks[model.previewSlot])model.previewSlot=state.activeSlot;
  const query=deckSearch.value.trim().toLocaleLowerCase('pt-BR'),total=d=>Object.values(d.cards||{}).reduce((s,v)=>s+Number(v||0),0);
  const rows=state.decks.map((d,i)=>({...d,index:i})).filter(d=>total(d)>0&&d.name.toLocaleLowerCase('pt-BR').includes(query));if(deckSort.value==='name')rows.sort((a,b)=>a.name.localeCompare(b.name));if(deckSort.value==='count')rows.sort((a,b)=>total(b)-total(a));
  deckGallery.replaceChildren();
  for(const deck of rows){const card=button('',()=>{model.previewSlot=deck.index;drawDecks();},'concept-deck-tile');card.setAttribute('aria-pressed',String(model.previewSlot===deck.index));const cover=state.cards.find(c=>deck.cards[c.id]>0&&c.art);if(cover&&/^(assets\/|https?:\/\/)/.test(cover.art))card.style.setProperty('--deck-art',`url(${JSON.stringify(cover.art)})`);if(deck.index===state.activeSlot)card.append(make('span','concept-deck-active','ATIVO'));card.append(window.MythicDeckIdentity.badge(deck),fan(deck.cards),make('b','',deck.name),make('small','',`${total(deck)} cartas`));deckGallery.append(card);}
  const emptyIndex=state.decks.findIndex(deck=>total(deck)===0);
  if(emptyIndex>=0||state.decks.length<(window.MythicDeckLimits?.slots||7)){const slot=button('',createDeck,'concept-deck-tile concept-deck-empty');slot.setAttribute('aria-label','Criar baralho no construtor');const plus=make('span','concept-deck-plus','+');plus.setAttribute('aria-hidden','true');slot.append(plus,make('b','','Criar baralho'),make('small','','Abrir modo construtor'));deckGallery.append(slot);}
  if(!rows.length&&query)empty(deckGallery,'Nenhum baralho com esse nome.');
  const selected=state.decks[model.previewSlot],entries=state.cards.filter(c=>selected.cards[c.id]>0),units=entries.filter(c=>c.kind==='unit').reduce((s,c)=>s+Number(selected.cards[c.id]),0),all=total(selected);
  deckDetail.replaceChildren(window.MythicDeckIdentity.badge(selected,'deck-emblem-large'),make('h2','',selected.name),make('p','concept-hero-subtitle','Seu próximo duelo começa com uma boa estratégia.'),fan(selected.cards));
  const metrics=make('div','concept-deck-metrics');for(const [n,label]of [[all,'cartas'],[units,'personagens'],[all-units,'especiais']]){const box=make('span');box.append(make('b','',String(n)),make('small','',label));metrics.append(box);}deckDetail.append(metrics,button('Avaliar baralho',()=>window.MythicDeckEvaluator.open(selected.cards,state.cards,selected.name),'button button-primary'));
  const stats=model.deckStats.find(d=>d.name===selected.name);if(stats)deckDetail.append(make('p','concept-deck-stat',`${stats.win_rate||0}% de vitórias · ${stats.games||0} partidas registradas`));
  deckDetail.append(button(model.previewSlot===state.activeSlot?'Baralho ativo':'Usar este baralho',()=>{const select=$('#deck-slot-select');select.value=String(model.previewSlot);select.dispatchEvent(new Event('change',{bubbles:true}));drawDecks();},'button button-primary'),button('Editar baralho',()=>{const select=$('#deck-slot-select');select.value=String(model.previewSlot);select.dispatchEvent(new Event('change',{bubbles:true}));window.MythicDeckBuilder?.open();}),button('Excluir baralho',()=>requestDeleteDeck(model.previewSlot),'button concept-deck-delete'));
  const mini=$('#concept-arena-decks');if(mini){mini.replaceChildren();state.decks.slice(0,3).forEach((deck,i)=>{const n=button('',()=>{const select=$('#arena-deck-select');select.value=String(i);select.dispatchEvent(new Event('change',{bubbles:true}));},'concept-mini-deck');n.setAttribute('aria-pressed',String(i===state.activeSlot));n.append(window.MythicDeckIdentity.badge(deck),fan(deck.cards),make('b','',deck.name),make('small','',`${total(deck)} cartas`));mini.append(n);});}
  $$('.concept-queue-deck').forEach(root=>{
   const active=state.decks[state.activeSlot],change=make('div','queue-deck-picker'),label=make('label'),select=make('select');
   label.append(make('span','','Escolher baralho'));select.setAttribute('aria-label','Baralho para esta partida');
   const limits=window.MythicDeckLimits||{min:14,max:35};for(const [slot,deck]of state.decks.entries()){const size=total(deck),option=new Option(`${deck.name} · ${size} cartas`,String(slot));option.disabled=size<limits.min||size>limits.max;select.append(option);}select.value=String(state.activeSlot);
   const locked=Boolean(window.MythicOnline?.getQueueState?.().active||window.MythicOnline?.activeMatchId?.()||window.MythicDeckEditor?.isSelecting?.());select.disabled=locked;
   select.addEventListener('change',async()=>{const slot=Number(select.value);model.deckSelectionStatus='Salvando seleção…';try{await window.MythicDeckEditor.select(slot);model.deckSelectionStatus='Baralho selecionado e salvo na sua conta.';}catch(error){model.deckSelectionStatus=error.message;}drawDecks();});
   label.append(select);const feedback=make('p','queue-deck-picker-status',window.MythicDeckEditor?.isSelecting?.()?'Salvando seleção…':window.MythicOnline?.getQueueState?.().active?'Saia da fila para trocar de baralho.':model.deckSelectionStatus||'Troque o baralho sem sair da sala.');feedback.setAttribute('role','status');
   change.append(label,feedback,button('Editar meus baralhos',()=>window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:'decks'}})),'queue-deck-edit'));
   if(!root.classList.contains('queue-room-deck')){root.replaceChildren(window.MythicDeckIdentity.badge(active),make('h3','',`Meu baralho · ${active.name}`),fan(active.cards),change);return;}
   const heading=make('header','queue-room-deck-heading');heading.append(make('small','','SEU BARALHO SELECIONADO'),make('h2','',active.name));
   const metrics=make('div','concept-deck-metrics'),counts=active.cards||{},catalog=new Map(state.cards.map(card=>[card.id,card]));let units=0;const factions=new Map();
   for(const [id,raw]of Object.entries(counts)){const count=Number(raw)||0;if(count<=0)continue;const card=catalog.get(id);if(card?.kind==='unit')units+=count;if(card?.faction)factions.set(card.faction,(factions.get(card.faction)||0)+count);}
   const size=total(active);for(const [value,label]of [[size,'cartas'],[units,'unidades'],[size-units,'especiais']]){const metric=make('span');metric.append(make('b','',String(value)),make('small','',label));metrics.append(metric);}
   const composition=make('div','queue-room-factions');composition.setAttribute('aria-label','Facções do baralho');for(const [name,count]of [...factions].sort((a,b)=>b[1]-a[1]))composition.append(make('span','',`${name} · ${count}`));
   const identity=window.MythicDeckIdentity.badge(active,'deck-emblem-large');heading.prepend(identity);change.append(button('Avaliar este baralho',()=>window.MythicDeckEvaluator.open(counts,state.cards,active.name),'queue-deck-edit'));root.replaceChildren(heading,fan(counts,'queue-room-fan'),metrics,composition,change);
  });
 }
 window.MythicDeckGallery={refresh:()=>drawDecks()};deckSearch.addEventListener('input',drawDecks);deckSort.addEventListener('change',drawDecks);
 let deckFrame=0;const queueDecks=()=>{if(deckFrame)return;deckFrame=requestAnimationFrame(()=>{deckFrame=0;drawDecks();});};for(const name of ['mythic-deck-selection-state','mythic-queue-state','mythic-deck-saved','mythic-deck-deleted'])window.addEventListener(name,queueDecks);new MutationObserver(queueDecks).observe($('#deck-slot-select'),{childList:true});new MutationObserver(queueDecks).observe($('#deck-card-list'),{childList:true});

 // Collection: a real selected-card preview alongside the existing grid.
 const collection=$('#view-collection'),collectionGrid=$('#collection-grid'),collectionLayout=make('div','concept-collection-layout'),collectionPreview=panel('','concept-collection-preview');collectionGrid.before(collectionLayout);collectionLayout.append(collectionGrid,collectionPreview);
 let selectedCard=null;
 function previewCard(id){const card=data().cards.find(c=>c.id===id&&c.owned>0);if(!card)return;collectionPreview.hidden=false;selectedCard=id;collectionPreview.replaceChildren(picture(card.art,'',card.name),make('h2','',card.name),make('p','concept-collection-quantity',`${card.subtype||card.type} · ${card.faction} · ${card.power||0} poder · ${card.previewOnly?"Em preparação":card.owned+" cópias"}`),make('h3','',card.abilityTitle||'Habilidade'),make('p','',card.ability||''),button(card.previewOnly?'Carta em preparação':'Adicionar ao baralho',()=>window.MythicPresentation?.addCard(id),'button button-primary'),button('Ampliar carta',()=>window.MythicPresentation?.inspectCard(id)),button('Ver história',()=>{window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:'lore'}}));openLore(id);}));if(window.MythicAvailability?.isDisabled(id)){const note=make('p','collection-paused-note','Temporariamente pausada: '+(window.MythicAvailability.reason(id)||'Em revisão.'));collectionPreview.append(note);collectionPreview.querySelector('.button-primary').disabled=true;}}
 window.addEventListener('mythic-availability-updated',()=>{if(selectedCard)previewCard(selectedCard);});
 collectionGrid.addEventListener('click',event=>{const target=event.target.closest('[data-card]');if(!target)return;event.stopPropagation();previewCard(target.dataset.card);},true);
 new MutationObserver(()=>{const available=[...collectionGrid.querySelectorAll('[data-card]')].map(node=>node.dataset.card);const next=available.includes(selectedCard)?selectedCard:available[0];if(next)previewCard(next);else{selectedCard=null;collectionPreview.replaceChildren();collectionPreview.hidden=true;}}).observe(collectionGrid,{childList:true});

 // Universe: reuse the full story, audio and HQ nodes in a two-column reader.
 setHeading('#view-lore','O LIVRO DOS MUNDOS','Histórias dos personagens e da Convergência.');
 const universeCharacter=card=>card?.kind==='unit'&&!card.specialOnly;
 const arenaRules=$('#view-lore .rules-overview');if(arenaRules)$('#view-settings').append(arenaRules);
 const lore=$('#view-lore'),loreList=lore.querySelector('.lore-stories'),loreLayout=make('div','concept-lore-layout'),reader=panel('','concept-lore-reader'),loreModal=$('#lore-detail-backdrop');loreList.before(loreLayout);loreLayout.append(loreList,reader);reader.append(loreModal);loreModal.querySelector('[role="dialog"]').removeAttribute('aria-modal');loreModal.querySelector('[role="dialog"]').setAttribute('role','region');
 const starAsset='assets/concept-ui/convergence-star.svg';
 const convergence={id:'convergence',name:'A Convergência',faction:'O início de todas as lendas',abilityTitle:'Quando os mundos se encontram',story:[
  'Antes que os heróis dividissem a mesma arena, cada mundo guardava suas próprias lendas. Deuses reinavam sobre seus domínios, monstros habitavam as fronteiras do desconhecido e mortais construíam seus destinos sob o olhar das estrelas.',
  'Então, uma luz atravessou o firmamento. Fronteiras que pareciam eternas se abriram, aproximando terras, eras e mitologias. A esse encontro de mundos deu-se o nome de Convergência.',
  'Entre templos antigos e cidades suspensas sobre as águas, forças antes separadas passaram a se encontrar. Algumas buscaram alianças. Outras trouxeram para esse novo horizonte suas rivalidades, ambições e segredos.',
  'Agora, cada carta guarda uma parte dessa jornada. Na Arena, deuses, heróis e criaturas se reúnem sob a mesma estrela — e cada duelo escreve mais uma página da Convergência.'
 ]};
 const heroCutouts={'soldado-esparta':'spartan','medusa':'medusa','poseidon':'poseidon','zeus':'zeus','hades':'hades'};
 const storyCharacter=card=>card.id==='convergence'?starAsset:card.hologram||card.sourceArtUrl|| (heroCutouts[card.id]?`assets/holograms/${heroCutouts[card.id]}-hologram.png`:card.art)||starAsset;
 let previewStory='convergence';
 const storyAudio=$('#lore-theme-audio');
 storyAudio.addEventListener('play',()=>{$('#menu-music')?.pause();$('#battle-music')?.pause();});storyAudio.addEventListener('ended',()=>window.dispatchEvent(new Event('mythic-lore-theme-ended')));
 const storyText=make('article','universe-story-text');storyText.hidden=true;
 const storyPreview=make('section','concept-story-banner'),bannerFigure=picture(starAsset,'concept-story-character'),bannerCopy=make('div','concept-story-banner-copy'),bannerKicker=make('small'),bannerTitle=make('h2'),bannerSubtitle=make('p'),bannerAction=button('Descobrir a história',()=>openLore(previewStory),'button button-primary');bannerCopy.append(bannerKicker,bannerTitle,bannerSubtitle,bannerAction);storyPreview.append(bannerFigure,bannerCopy);reader.prepend(storyPreview);storyPreview.append(storyText);
 const convergenceStory=make('article','concept-convergence-story');convergenceStory.hidden=true;convergenceStory.append(picture(starAsset,'concept-convergence-star','Estrela da Convergência'),make('small','','A ORIGEM DOS MUNDOS'),make('h2','',convergence.name),make('p','concept-convergence-subtitle',convergence.abilityTitle));for(const paragraph of convergence.story)convergenceStory.append(make('p','concept-story-paragraph',paragraph));reader.append(convergenceStory);
 const convergenceEntry=button('',()=>openLore('convergence'),'concept-convergence-entry');convergenceEntry.append(picture(starAsset,'',''),make('span'));convergenceEntry.querySelector('span').append(make('small','','A PRIMEIRA HISTÓRIA'),make('b','','A Convergência'),make('small','','A origem dos mundos'));loreList.querySelector('#lore-story-list').before(convergenceEntry);
 function showLorePreview(id){const card=id==='convergence'?convergence:data().cards.find(c=>c.id===id&&universeCharacter(c));if(!card)return;storyAudio.pause();previewStory=id;window.MythicArcaneUpgrade?.heroBanner(storyPreview,card);window.MythicPaintUniverseBanner?.(storyPreview,id);reader.dataset.mode='preview';storyText.hidden=true;loreModal.hidden=true;bannerAction.hidden=false;storyPreview.hidden=false;convergenceStory.hidden=true;bannerFigure.src=storyCharacter(card);bannerFigure.alt=card.name;storyPreview.classList.toggle('convergence',id==='convergence');bannerKicker.textContent=id==='convergence'?'ONDE TUDO COMEÇOU':card.faction;bannerTitle.textContent=card.name;bannerSubtitle.textContent=card.abilityTitle||'Uma lenda espera para ser descoberta.';bannerAction.textContent=id==='convergence'?'Conhecer a Convergência':'Ler história do personagem';}
 function openLore(id){const card=id==='convergence'?convergence:data().cards.find(c=>c.id===id&&universeCharacter(c));if(!card)return;showLorePreview(id);reader.dataset.mode='reading';storyPreview.hidden=false;convergenceStory.hidden=true;bannerAction.hidden=true;storyText.hidden=false;storyAudio.pause();loreModal.append(storyAudio);storyText.replaceChildren();
  const entry=window.MythicWorldLore?.[id];storyText.append(make('small','story-origin',entry?.origin||(id==='convergence'?'HISTÓRIA ORIGINAL · MYTHIC CLASH':'UNIVERSO MYTHIC CLASH')));
  for(const paragraph of (card.customStory?card.story:entry?.story)||card.story||[])if(!/^Habilidade|^.* · Facção|^Companheiro original/.test(paragraph))storyText.append(make('p','',paragraph));
  if(!(card.customStory?card.story:entry?.story)?.some(p=>p.length>150))storyText.prepend(make('p','story-pending','História em preparação. Confira a habilidade e conheça as outras lendas do Universo.'));
  if(entry?.sources?.length){const links=make('p','story-sources');links.append(make('small','','Referências: '));for(const source of entry.sources){const a=make('a','',source.title);a.href=window.MythicSecurity.assetUrl(source.url);a.target='_blank';a.rel='noopener noreferrer';links.append(a,document.createTextNode(' '));}storyText.append(links);}
  const audio=storyAudio;audio.pause();audio.removeAttribute('src');if(card.themeUrl){audio.src=window.MythicSecurity.assetUrl(card.themeUrl);const area=make('div','universe-story-audio');area.append(make('small','','Trilha do personagem'),audio);storyText.append(area);audio.currentTime=0;audio.volume=Math.max(0,Math.min(1,Number($("#setting-volume")?.value??42)/100));if($("#music-toggle")?.getAttribute("aria-pressed")!=="false")audio.play().catch(()=>{});}
  const comicArea=make('section','universe-comic-area');comicArea.append(make('h3','','História em quadrinhos'));
  if(card.comicUrl){const link=make('a','button button-secondary','Ler HQ do personagem');link.href=window.MythicSecurity.assetUrl(card.comicUrl);link.target='_blank';link.rel='noopener noreferrer';comicArea.append(link);}else comicArea.append(make('p','','Em breve, uma nova forma de acompanhar esta lenda.'));
  storyText.append(comicArea);

  convergenceEntry.setAttribute('aria-current',String(id==='convergence'));$$('#lore-story-list .lore-story-card').forEach(row=>row.classList.toggle('selected',row.dataset.storyId===id));if(matchMedia('(max-width:900px)').matches)storyPreview.scrollIntoView({behavior:'smooth',block:'start'});
 }
 storyPreview.addEventListener('click',event=>{if(!event.target.closest('a,audio,button,.universe-story-text')&&reader.dataset.mode!=='reading')openLore(previewStory);});
 function decorateStories(){for(const row of $$('#lore-story-list .lore-story-card')){const id=row.querySelector('[data-story-card]')?.dataset.storyCard,card=data().cards.find(c=>c.id===id);if(!card)continue;row.dataset.storyId=id;const art=row.querySelector('.lore-story-art');if(art){if(art.dataset.customBanner!==id){art.replaceChildren();window.MythicPaintUniverseBanner?.(art,id);}art.removeAttribute('aria-hidden');}if(row.dataset.bannerReady)continue;row.dataset.bannerReady='true';}}

 $('#lore-story-list').addEventListener('click',event=>{const row=event.target.closest('.lore-story-card');if(!row?.dataset.storyId)return;event.preventDefault();event.stopImmediatePropagation();openLore(row.dataset.storyId);},true);

 const storyList=$('#lore-story-list');const loreSearch=make('input','universe-search');loreSearch.type='search';loreSearch.placeholder='Buscar personagem…';loreSearch.setAttribute('aria-label','Buscar personagem no Universo');storyList.before(loreSearch);loreSearch.addEventListener('input',()=>{const q=loreSearch.value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('pt-BR');for(const row of storyList.children){const c=data().cards.find(c=>c.id===row.dataset.storyId);row.classList.toggle('search-hidden',!String(c?.name||row.textContent).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('pt-BR').includes(q));}});
 const previewFrom=e=>{const row=e.target.closest('.lore-story-card');if(!row?.dataset.storyId)return;if(previewStory!==row.dataset.storyId)showLorePreview(row.dataset.storyId);};
 storyList.addEventListener('pointerover',previewFrom);storyList.addEventListener('focusin',previewFrom);
 storyList.addEventListener('pointerdown',e=>{if(e.pointerType==='touch')previewFrom(e);});
 decorateStories();showLorePreview('convergence');
 const loreFilters=make('nav','concept-lore-filters');loreFilters.setAttribute('aria-label','Filtrar histórias por facção');loreLayout.before(loreFilters);
 function filterStories(faction){$$('#lore-story-list .lore-story-card').forEach(row=>{const id=row.querySelector('[data-story-card]')?.dataset.storyCard,c=data().cards.find(c=>c.id===id);row.hidden=faction!=='Todas'&&c?.faction!==faction;});}
 let loreFaction='Todas';for(const name of ['Todas',...new Set(data().cards.filter(universeCharacter).map(c=>c.faction))]){const tab=button(name,()=>{loreFaction=name;$$('.concept-lore-filters button').forEach(n=>n.setAttribute('aria-pressed',String(n===tab)));filterStories(name);});tab.setAttribute('aria-pressed',String(name==='Todas'));loreFilters.append(tab);}
 new MutationObserver(()=>{decorateStories();filterStories(loreFaction);}).observe($('#lore-story-list'),{childList:true});
 new MutationObserver(()=>{if(lore.hidden)storyAudio.pause();}).observe(lore,{attributes:true,attributeFilter:['hidden']});

 // Guild: use real membership, weekly missions and wars, with no invented totals.
 const guildView=$('#view-guilds'),guildOld=guildView.querySelector('.community-grid'),guildBanner=make('section','epic-panel concept-guild-banner'),guildCrest=picture('assets/concept-ui/mode-ranked.png'),guildIdentity=make('div'),guildTitle=make('h2','','Sua guilda'),guildDescription=make('p','','Una forças e construa sua lenda.'),guildInfo=make('small','','');guildIdentity.append(guildTitle,guildDescription,guildInfo);guildBanner.append(guildCrest,guildIdentity);guildOld.before(guildBanner);
 const guildColumns=make('div','concept-guild-columns'),membersPanel=panel('MEMBROS'),guildMembers=make('div','concept-guild-members'),weeklyPanel=panel('MISSÕES DA GUILDA'),warsPanel=panel('GUERRAS DE GUILDAS'),warArt=make('div','concept-guild-wars-art');warArt.append(picture('assets/concept-ui/mode-x1.png'));membersPanel.append(guildMembers);weeklyPanel.append($('#guild-weekly-list'));warsPanel.append(warArt,$('#guild-war-list'),$('#guild-war-form'));guildColumns.append(membersPanel,weeklyPanel,warsPanel);guildBanner.after(guildColumns);const guildManage=make('details','concept-guild-manage epic-panel');guildManage.append(make('summary','','Criar, entrar ou consultar sua guilda'),guildOld);guildBanner.after(guildManage);guildManage.open=true;empty(guildMembers,'Os membros aparecerão ao carregar sua guilda.');

 // Missions remain a floating dialog. Enrich the existing live mission entries.
 const missionSource=$('#community-missions'),path=make('div','concept-mission-path');missionSource.closest('.community-card').before(path);
 function decorateMissions(){
  const rows=[...missionSource.querySelectorAll('.mission-step')];path.replaceChildren();let activeFound=false;
  for(const [index,row]of rows.entries()){
   if(index<7){const done=row.classList.contains('complete'),active=!done&&!activeFound;if(active)activeFound=true;const node=make('div','concept-mission-node'+(done?' complete':active?' current':''));node.append(make('span','',done?'✓':row.classList.contains('locked')?'◇':String(index+1)),make('small','',row.querySelector('b')?.textContent||`Etapa ${index+1}`));path.append(node);}
   if(row.dataset.conceptDecorated)continue;row.dataset.conceptDecorated='true';const info=row.querySelector(':scope>span');if(!info)continue;row.prepend(picture(data().cards.find(c=>c.id===['soldado-esparta','poseidon','zeus','medusa','hades'][index%5])?.art,'concept-mission-thumb'));
   const progress=info.textContent.match(/·\s*(\d+)\/(\d+)\s*·/);if(progress){const meter=make('progress','concept-mission-meter');meter.max=Number(progress[2])||1;meter.value=Number(progress[1]);meter.setAttribute('aria-label',info.querySelector('b')?.textContent||'Progresso da missão');info.append(meter);}
  }
  path.hidden=!rows.length;
 }
 new MutationObserver(decorateMissions).observe(missionSource,{childList:true,subtree:true});
 new MutationObserver(()=>{$$('#expedition-list .community-row').forEach(row=>{if(row.dataset.conceptDecorated)return;row.dataset.conceptDecorated='true';const c=data().cards.find(c=>c.id===row.querySelector('b')?.textContent);if(c){row.prepend(picture(c.art,'concept-expedition-art',c.name));row.querySelector('b').textContent=c.name;}});}).observe($('#expedition-list'),{childList:true});

 // Community deck browser: thumbnails reflect encoded cards, never invented decks.
 const communityView=$('#view-community-decks'),communityList=$('#community-deck-list'),publishForm=$('#community-deck-form'),publishDetails=make('details','concept-publish-form');publishDetails.append(make('summary','','Publicar seu baralho'),publishForm);communityList.before(publishDetails);
 const communityTools=make('div','concept-community-header'),communitySearch=make('input'),communitySort=make('select');communitySearch.type='search';communitySearch.placeholder='Buscar decks…';communitySearch.setAttribute('aria-label','Buscar decks da comunidade');communitySort.append(new Option('Mais recentes','recent'),new Option('Mais curtidos','votes'));communitySort.setAttribute('aria-label','Ordenação');communityTools.append(communitySearch,communitySort);communityList.before(communityTools);
 function decodeCards(code){try{const parsed=JSON.parse(code);return parsed.cards||parsed;}catch{return {};}}
 function drawCommunity(){let rows=model.community.filter(r=>(r.title+' '+(r.description||'')).toLocaleLowerCase('pt-BR').includes(communitySearch.value.toLocaleLowerCase('pt-BR')));if(communitySort.value==='votes')rows=[...rows].sort((a,b)=>b.votes-a.votes);communityList.replaceChildren();for(const row of rows){const counts=decodeCards(row.deck_code),article=make('article','concept-community-deck'),banner=make('div','concept-community-banner'),c=data().cards.find(c=>Number(counts[c.id])>0&&c.art);if(c&&/^(assets\/|https?:\/\/)/.test(c.art))banner.style.setProperty('--deck-art',`url(${JSON.stringify(c.art)})`);banner.append(make('h3','',row.title));const footer=make('div','concept-community-footer'),author=model.authors[row.player_id];footer.append(make('span','',author?.nickname||author?.display_name||'Jogador da comunidade'),button(`✦ ${row.votes} · Votar`,null),button('Copiar código',()=>copyCode(row.deck_code)));footer.querySelector('button').dataset.voteDeck=row.id;article.append(banner,fan(counts),make('p','',row.description||'Uma estratégia compartilhada pela comunidade.'),footer);communityList.append(article);}if(!rows.length)empty(communityList,'Nenhum deck publicado neste filtro.');}
 communitySearch.addEventListener('input',drawCommunity);communitySort.addEventListener('change',drawCommunity);

 // Store previews reflect the current category and real catalog products.
 const shopArea=$('#store-product-area'),showcase=make('div','concept-shop-showcase'),shopHero=make('section','epic-panel concept-shop-hero'),shopCopy=make('div'),shopTitle=make('h2','','Tesouros da Convergência'),shopText=make('p','','Escolha um item para conhecer seus detalhes.'),shopAction=button('Ver itens',null,'button button-primary'),shopImage=picture('assets/card-back.svg'),shopPreview=panel('PRÉVIA DO ITEM','concept-shop-preview'),shopPreviewImage=picture('assets/card-back.svg'),shopPreviewText=make('p','','');shopCopy.append(shopTitle,shopText,shopAction);shopHero.append(shopCopy,shopImage);shopPreview.append(shopPreviewImage,shopPreviewText);showcase.append(shopHero,shopPreview);shopArea.prepend(showcase);
 const shopInspect=button('Ampliar carta e ver habilidade',null,'button button-secondary');shopInspect.hidden=true;shopCopy.append(shopInspect);
 let selectedShop=null;
 function inspectShopCard(){const id=selectedShop?.dataset.shopCardId;if(id)window.MythicPresentation?.inspectCard(id);}
 shopInspect.addEventListener('click',inspectShopCard);
 shopImage.addEventListener('click',inspectShopCard);shopPreviewImage.addEventListener('click',inspectShopCard);
 function selectShop(card){shopInspect.hidden=!card?.dataset.shopCardId;showcase.dataset.shopKind=card?.dataset.shopKind||'';if(!card){selectedShop=null;shopTitle.textContent='Tesouros da Convergência';shopText.textContent='Não há itens nesta categoria.';shopImage.src=shopPreviewImage.src='assets/card-back.svg';shopPreviewText.textContent='';shopAction.disabled=true;shopAction.textContent='Sem itens';return;}selectedShop=card;const img=card.querySelector('.store-item-art img'),title=card.querySelector('h3'),desc=card.querySelector('p'),action=card.querySelector('[data-store-action]');shopTitle.textContent=title?.textContent||'Item';shopText.textContent=desc?.textContent||'';shopImage.src=shopPreviewImage.src=img?.src||'assets/card-back.svg';shopPreviewText.textContent=title?.textContent||'';shopAction.textContent=action?.textContent||'Ver detalhes';shopAction.disabled=Boolean(action?.disabled);}
 shopAction.addEventListener('click',()=>{if(selectedShop)selectedShop.querySelector('[data-store-action]')?.click();else $('#store-grid').scrollIntoView({block:'start',behavior:'smooth'});});
 new MutationObserver(()=>selectShop($('#store-grid .store-item'))).observe($('#store-grid'),{childList:true});$('#store-grid').addEventListener('click',event=>{if(event.target.closest('[data-store-action]'))return;const item=event.target.closest('.store-item');if(!item)return;selectShop(item);if(item.dataset.shopKind==='card')inspectShopCard();});

 // Queue / custom rooms: retain seats, privacy rules and all live controls.
 const queueDeck=make('section','epic-panel concept-queue-deck queue-room-deck'),queueSetup=$('#view-queue .queue-setup-panel'),queueRoom=make('div','queue-room-layout');queueSetup.before(queueRoom);queueRoom.append(queueSetup,queueDeck);
 $('#view-custom .custom-page-heading>img').src='assets/concept-ui/mode-custom.png';
 const customDeck=make('section','epic-panel concept-queue-deck');$('#view-custom .custom-room-panel').after(customDeck);


 // Settings: group current working controls, not mock controls from the concept.
 setHeading('#view-settings','PREFERÊNCIAS DO JOGADOR','Ajuste sua experiência na Arena.');
 const settings=$('#settings-form'),audioGroup=panel('ÁUDIO','concept-settings-group'),accountGroup=panel('CONTA E NOTIFICAÇÕES','concept-settings-group'),settingsFooter=make('div','concept-settings-footer');
 for(const id of ['setting-music','setting-volume','setting-effects']){const node=$('#'+id)?.closest('label');if(node)audioGroup.append(node);}
 for(const id of ['setting-notifications','enable-notifications','enable-biometrics','device-feature-status']){const node=$('#'+id);if(node)accountGroup.append(node.closest('label')||node);}
 for(const node of [...settings.children])settingsFooter.append(node);settings.append(audioGroup,accountGroup,settingsFooter);

 // Admin category tabs preserve the authorization gate and original forms.
 setHeading('#view-admin','PAINEL DA CONVERGÊNCIA','Gerencie os recursos da Arena com acesso administrativo.');
 const adminGrid=$('#view-admin .admin-grid'),adminTabs=make('div','concept-admin-tabs');adminTabs.setAttribute('role','tablist');adminTabs.setAttribute('aria-label','Áreas administrativas');adminGrid.before(adminTabs);
 const adminGroups={Jogadores:['admin-reward-form'],Cartas:['admin-card-form'],Loja:['admin-shop-form'],Universo:['admin-lore-form'],Torneios:['tournament-create-form'],Recompensas:['admin-gift-form'],Comunicados:['admin-announcement-form']};
 const cards=[...adminGrid.children],groupFor=card=>Object.entries(adminGroups).find(([,ids])=>ids.some(id=>card.querySelector('#'+id)))?.[0]||'Cartas';
 const adminTournaments=panel('TORNEIOS E CHAVES','concept-admin-tournaments');adminTournaments.hidden=true;adminGrid.append(adminTournaments);
 for(const label of Object.keys(adminGroups)){const tab=button(label,()=>{cards.forEach(card=>card.hidden=groupFor(card)!==label);adminTournaments.hidden=label!=='Torneios';[...adminTabs.children].forEach(n=>n.setAttribute('aria-selected',String(n===tab)));});tab.setAttribute('role','tab');tab.setAttribute('aria-selected','false');adminTabs.append(tab);}
 adminTabs.firstElementChild?.click();
 function syncTournaments(){const heading=make('h2','','TORNEIOS E CHAVES');adminTournaments.replaceChildren(heading);for(const id of ['tournament-list','tournament-round-list']){const source=$('#'+id);const clone=source.cloneNode(true);clone.removeAttribute('id');clone.querySelectorAll('[id]').forEach(n=>n.removeAttribute('id'));adminTournaments.append(clone);}}
 for(const id of ['tournament-list','tournament-round-list'])new MutationObserver(syncTournaments).observe($('#'+id),{childList:true});syncTournaments();

 // Read-only presentation feeds; existing RPCs still own game state and rewards.
 window.addEventListener('mythic-concept-profile',event=>{model.profile=event.detail;syncAccount();});
 window.addEventListener('mythic-concept-analytics',event=>{model.deckStats=event.detail?.top_decks||[];drawDecks();});
 window.addEventListener('mythic-concept-community',event=>{model.community=event.detail?.decks||[];model.authors=event.detail?.authors||{};drawCommunity();});
 window.addEventListener('mythic-concept-guild',event=>{const d=event.detail||{};model.guild=d.guild;guildTitle.textContent=d.guild?.name||'Una forças na Arena';guildDescription.textContent=d.guild?.description||'Crie uma guilda ou entre usando um código de convite.';guildInfo.textContent=d.guild?`${d.members?.length||0} membros · Código ${d.guild.invite_code}`:'';guildMembers.replaceChildren();for(const member of d.members||[]){const row=make('article','concept-guild-member'),p=member.profile||{};row.append(picture(member.avatar||'assets/app-icon.svg'),make('span'));row.querySelector('span').append(make('b','',p.nickname||p.display_name||'Membro'),make('small','',({leader:'Líder',officer:'Oficial',member:'Membro'})[member.role]||'Membro'));row.append(picture(rankAsset(Number(p.rating_points)||1000),'concept-member-rank'));guildMembers.append(row);}if(!d.guild)empty(guildMembers,'Entre em uma guilda para reunir seus aliados.');else if(!d.members?.length)empty(guildMembers,'A lista de membros ainda não pôde ser carregada.');});
 window.addEventListener('mythic-account-signed-out',()=>{model.profile=null;model.deckStats=[];model.community=[];model.authors={};syncAccount();drawCommunity();guildMembers.replaceChildren();guildTitle.textContent='Sua guilda';guildInfo.textContent='';});
 drawDecks();const first=data().cards.find(c=>c.id==='medusa')||data().cards[0];if(first)previewCard(first.id);decorateMissions();selectShop($('#store-grid .store-item'));syncAccount();
 window.MythicPresentation?.refresh?.();
})();
