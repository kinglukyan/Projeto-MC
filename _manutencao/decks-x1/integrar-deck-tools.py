from pathlib import Path
root=Path('outputs/Mythic-Clash-Completo')
def change(name,a,b):
 p=root/name;s=p.read_text(encoding='utf-8-sig')
 if a not in s:raise ValueError('Missing '+name+' '+a[:70])
 p.write_text(s.replace(a,b),encoding='utf-8')
change('app.js','name:String(slot.name||`Deck ${index+1}`).slice(0,24),cards:', 'name:String(slot.name||`Deck ${index+1}`).slice(0,24),iconKey:slot.iconKey||"convergencia",iconColor:slot.iconColor||"#44305E",cards:')
change('app.js','name:String(row.name||`Deck ${index+1}`).slice(0,24),cards:', 'name:String(row.name||`Deck ${index+1}`).slice(0,24),iconKey:row.iconKey||"convergencia",iconColor:row.iconColor||"#44305E",cards:')
change('app.js','({name:deck.name,cards:{...(index===activeDeckSlot?deckCounts:deck.cards)}})', '({...deck,name:deck.name,cards:{...(index===activeDeckSlot?deckCounts:deck.cards)}})')
change('app.js','deckSlots[slot]={name:title,cards:{...deckCounts}};', 'deckSlots[slot]={...deckSlots[slot],name:title,cards:{...deckCounts}};')
change('app.js','    isSelecting:()=>lobbyDeckSelecting,','''    personalize:async({slot,name,iconKey,iconColor,userId})=>{
      const viewer=window.MythicOnline?.userId?.();
      if(!viewer||viewer!==userId||!Number.isInteger(slot)||!deckSlots[slot])throw Error('A conta ou o baralho mudou. Abra novamente.');
      if(window.MythicDeckBuilder?.isOpen?.()||lobbyDeckSelecting)throw Error('Conclua a edição ou troca de baralho antes de personalizar.');
      const result=await window.MythicOnline.saveDeckPersonalization(slot,name,iconKey,iconColor);
      if(viewer!==window.MythicOnline?.userId?.()||!deckSlots[slot])throw Error('A conta mudou durante o salvamento.');
      deckSlots[slot]={...deckSlots[slot],name:result.name,iconKey:result.iconKey,iconColor:result.iconColor};
      persistDeckSlots();renderDeckSlots();window.dispatchEvent(new CustomEvent('mythic-deck-saved',{detail:{slot}}));
    },
    isSelecting:()=>lobbyDeckSelecting,''')
change('online.js','.select("slot,name,card_counts").eq("player_id",session.user.id)','.select("*").eq("player_id",session.user.id)')
change('online.js','({slot:row.slot,name:row.name,cards:row.card_counts})','({slot:row.slot,name:row.name,cards:row.card_counts,iconKey:row.icon_key,iconColor:row.icon_color})')
change('online.js','  async function saveBuilderDeck(index,name,counts){','''  async function saveDeckPersonalization(index,name,iconKey,iconColor){
    if(!session)throw Error('Entre na conta para personalizar.');
    return enqueueDeckWrite(async uid=>{const {data,error}=await supabase.rpc('personalize_deck',{p_slot:index+1,p_name:name,p_icon:iconKey,p_color:iconColor});
      if(error)throw Error(/PGRST202|42883/.test(String(error.code))?'Aplique o SQL 042 para salvar ícones e cores na conta.':displayError(error));
      if(session?.user?.id!==uid)throw Error('A conta mudou.');return data;
    });
  }
  async function saveBuilderDeck(index,name,counts){''')
change('online.js','saveNamedDeck,saveBuilderDeck,deleteBuilderDeck,','saveNamedDeck,saveBuilderDeck,deleteBuilderDeck,saveDeckPersonalization,createDirectInvite,')
# Existing X1 creation paths share the same busy guards and status event.
change('online.js','  async function sendInviteAction(action){','''  let directInviteBusy=false;
  async function createDirectInvite(friendCode=null){
    if(!requireLogin())throw Error('Entre na conta para desafiar um amigo.');
    if(directInviteBusy)throw Error('Aguarde o envio do convite.');
    if(window.MythicDeckEditor?.isSelecting?.()||window.MythicDeckBuilder?.isOpen?.())throw Error('Conclua a seleção e o salvamento do baralho.');
    if(floatingQueueState.active||activeMatchId)throw Error('Saia da fila ou da partida antes de desafiar.');
    directInviteBusy=true;const uid=session.user.id;
    try{const {data,error}=await supabase.rpc('create_game_invite',{p_mode:'friend',p_invited_friend_code:friendCode});if(error)throw Error(displayError(error));if(session?.user?.id!==uid)throw Error('A conta mudou.');const invite=Array.isArray(data)?data[0]:data;window.dispatchEvent(new CustomEvent('mythic-direct-created',{detail:{code:invite?.invite_code,friendCode}}));return invite;}
    finally{directInviteBusy=false;}
  }
  async function sendInviteAction(action){''')
p=root/'online.js';s=p.read_text(encoding='utf-8');a=s.index('    if(action==="x1"){');b=s.index('\n    else if(action===',a);s=s[:a]+'''    if(action==="x1"){try{await createDirectInvite(friend.friend_code);status.textContent=`Desafio X1 enviado para ${friend.display_name}.`;$('#invite-flow-backdrop').hidden=true;window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:'direct'}}));}catch(error){status.textContent=error.message;}}'''+s[b:];a=s.index('  $("#create-invite-form").addEventListener');b=s.index('\n  $("#join-invite-form")',a);s=s[:a]+'''  $('#create-invite-form').addEventListener('submit',async event=>{event.preventDefault();const button=event.currentTarget.querySelector('button[type=submit]');button.disabled=true;try{const invite=await createDirectInvite($('#invite-friend-code').value.trim().toUpperCase()||null);$('#created-invite-code').textContent=`Código: ${invite.invite_code} · válido por 15 minutos`;}catch(error){$('#created-invite-code').textContent=error.message;}finally{button.disabled=false;}});'''+s[b:];p.write_text(s,encoding='utf-8')
change('concept-theme.js',"card.append(fan(deck.cards),make('b','',deck.name)","card.append(window.MythicDeckIdentity.badge(deck),fan(deck.cards),make('b','',deck.name)")
change('concept-theme.js',"deckDetail.replaceChildren(make('h2','',selected.name)","deckDetail.replaceChildren(window.MythicDeckIdentity.badge(selected,'deck-emblem-large'),make('h2','',selected.name)")
change('concept-theme.js',"deckDetail.append(metrics);", "deckDetail.append(metrics,button('Personalizar deck',()=>window.MythicDeckIdentity.open(model.previewSlot)),button('Avaliar baralho',()=>window.MythicDeckEvaluator.open(selected.cards,state.cards,selected.name),'button button-primary'));")
change('concept-theme.js',"n.append(fan(deck.cards),make('b','',deck.name)","n.append(window.MythicDeckIdentity.badge(deck),fan(deck.cards),make('b','',deck.name)")
change('concept-theme.js',"root.replaceChildren(make('h3','',`Meu baralho · ${active.name}`),fan(active.cards),change)","root.replaceChildren(window.MythicDeckIdentity.badge(active),make('h3','',`Meu baralho · ${active.name}`),fan(active.cards),change)")
change('concept-theme.js',"root.replaceChildren(heading,fan(counts,'queue-room-fan'),metrics,composition,change);", "const identity=window.MythicDeckIdentity.badge(active,'deck-emblem-large');heading.prepend(identity);change.append(button('Avaliar este baralho',()=>window.MythicDeckEvaluator.open(counts,state.cards,active.name),'queue-deck-edit'));root.replaceChildren(heading,fan(counts,'queue-room-fan'),metrics,composition,change);")
change('concept-theme.js',"deckSearch.addEventListener('input',drawDecks);", "window.MythicDeckGallery={refresh:()=>drawDecks()};deckSearch.addEventListener('input',drawDecks);")
change('deck-builder.js','<span id="db-save-note" class="db-save-note">','<button type="button" class="db-button db-secondary" data-action="evaluate">Avaliar deck</button><span id="db-save-note" class="db-save-note">')
change('deck-builder.js',"    event.stopPropagation();\n    if(event.target.closest", "    event.stopPropagation();\n    if(event.target.closest('[data-action=\"evaluate\"]')){if(state)window.MythicDeckEvaluator?.open(state.counts,catalog(),state.name||'Edição atual');return;}\n    if(event.target.closest")
# A shared friend picker, with the direct challenge as an additional context.
change('convergence-lobby.js',"pickerContext=event?.detail?.context==='custom'?'custom':'queue';", "pickerContext=['custom','direct'].includes(event?.detail?.context)?event.detail.context:'queue';")
change('convergence-lobby.js',"const result=pickerContext==='custom'?await window.MythicCustomLobby.invite", "const result=pickerContext==='direct'?await window.MythicDirectLobby.invite(friend):pickerContext==='custom'?await window.MythicCustomLobby.invite")
# Enable modules before their gallery consumers and keep direct DOM setup last.
p=root/'index.html';s=p.read_text(encoding='utf-8');pos=s.index('  <script src="concept-theme.js');s=s[:pos]+'  <script src="deck-identity.js" defer></script>\n  <script src="deck-evaluator.js" defer></script>\n'+s[pos:];s=s.replace('</head>','  <link rel="stylesheet" href="deck-tools.css">\n</head>');s=s.replace('</body>','  <script src="direct-lobby.js" defer></script>\n</body>');p.write_text(s,encoding='utf-8')
print('Interfaces de deck integradas')
