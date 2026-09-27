(() => {
  const $ = selector => document.querySelector(selector);
  const config = window.MYTHIC_SUPABASE_CONFIG || {};
  const configured = Boolean(config.url && config.publishableKey);
  let supabase = null, session = null, profile = null, activeFriend = null, activeMatchId = null, actionPending = false, adminAuthorized = false, adminPlayers = [], adminCatalog = [], adminGifts = [], adminLore = [];
  let messageChannel = null, inviteChannel = null, queueChannel = null, gameChannel = null, queueTimeout = null, queueSeconds = 0, queueTicker = null, storeItems = [], ownedItems = new Set();
  const escapeHTML = value => String(value).replace(/[&<>"']/g, char => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[char]));
  const notify = message => { const toast=$("#toast"); if(!toast)return; toast.textContent=message; toast.classList.add("show"); setTimeout(()=>toast.classList.remove("show"),2800); };
  const showAuthMessage = message => { $("#auth-message").textContent=message||""; };
  const requireLogin = () => { if(session)return true; if(configured)$("#account-gate").hidden=false; else notify("Conecte o Supabase para usar os recursos online."); return false; };
  const displayError = error => {
    const message=String(error?.message||"");
    if(/email rate limit exceeded|over_email_send_rate_limit|over_email_rate_limit/i.test(message))return "O Supabase limitou temporariamente o envio de e-mails de cadastro. Aguarde ou configure um SMTP próprio no painel do Supabase.";
    return message||"Não foi possível concluir. Tente novamente.";
  };

  if(!configured){
    $("#connection-status-text").textContent="Supabase sem configuração";
  } else if(!window.supabase?.createClient){
    $("#connection-status-text").textContent="Biblioteca indisponível";
  } else {
    supabase=window.supabase.createClient(config.url,config.publishableKey);
    $("#connection-status-text").textContent="Conectando";
    loadPublicLore();loadPublicAnnouncement();supabase.auth.getSession().then(({data})=>setSession(data.session));
    supabase.auth.onAuthStateChange((_event,nextSession)=>setTimeout(()=>setSession(nextSession),0));
  }

  function setSession(nextSession){
    session=nextSession; const gate=$("#account-gate");
    if(!configured){gate.hidden=true;return;}
    gate.hidden=Boolean(session);
    $("#connection-status-text").textContent=session?"Online":"Entre na conta";
    if(session){loadProfile();loadFriends();listenForInvites();loadAdminAccess();}else{profile=null;adminAuthorized=false;$("#admin-nav").hidden=true;loadStore();activeFriend=null;cleanupChannels();$("#sidebar-player-name").textContent="Visitante";$("#sidebar-player-rank").textContent="Perfil local";$("#sidebar-player-record").textContent="0 vitórias · 0 derrotas";$("#sidebar-player-code").textContent="Código: —";$("#profile-email").textContent="Entre para ver os dados da conta.";}
  }

  function cleanupChannels(){
    if(messageChannel)supabase.removeChannel(messageChannel);
    if(inviteChannel)supabase.removeChannel(inviteChannel);
    if(queueChannel)supabase.removeChannel(queueChannel);
    if(gameChannel)supabase.removeChannel(gameChannel);
    messageChannel=inviteChannel=queueChannel=gameChannel=null;activeMatchId=null;
  }

  const rankForRating=rating=>rating<1100?"Aprendiz de Herói":rating<1250?"Escudeiro":rating<1450?"Herói":rating<1700?"Lenda":rating<2000?"Semideus":rating<2400?"Deus":"Convergente";
  function paintProgression(){if(!profile)return;const level=Math.floor((profile.xp||0)/100)+1,within=(profile.xp||0)%100;$("#profile-level").textContent=level;$("#profile-xp-label").textContent=`${within} / 100 XP`;$("#profile-xp").value=within;$("#profile-coins").textContent=profile.mythic_coins||0;$("#store-coins").textContent=profile.mythic_coins||0;}
  async function loadHistory(){if(!session)return;const {data,error}=await supabase.from("match_history").select("opponent_name,mode,outcome,player_points,opponent_points,xp_earned,coins_earned,completed_at").eq("player_id",session.user.id).order("completed_at",{ascending:false}).limit(20);const list=$("#match-history-list");if(error){list.innerHTML='<p>Histórico indisponível. Atualize a migração de progressão.</p>';return;}$("#history-summary").textContent=`${data.length} ${data.length===1?"partida":"partidas"}`;list.innerHTML=data.length?data.map(match=>`<article class="history-row ${escapeHTML(match.outcome)}"><span><b>${match.outcome==="victory"?"Vitória":match.outcome==="defeat"?"Derrota":"Empate"}</b><small>${escapeHTML(match.opponent_name)} · ${escapeHTML(({guardian:"Guardião",ranked:"Ranqueada",normal:"Normal",friend:"X1"})[match.mode]||match.mode)} · ${new Date(match.completed_at).toLocaleDateString("pt-BR")}</small></span><span>${match.player_points} × ${match.opponent_points}</span><small>+${match.xp_earned} XP · +${match.coins_earned} MC</small></article>`).join(""):'<p>Suas partidas concluídas aparecerão aqui.</p>';}
  async function loadStore(){if(!supabase)return;const [{data:catalog,error},{data:inventory}]=await Promise.all([supabase.from("shop_catalog").select("item_id,title,description,kind,price,asset_path").eq("active",true).order("price"),session?supabase.from("player_inventory").select("item_id"):Promise.resolve({data:[]})]);if(error){$("#store-grid").innerHTML='<p class="empty-state">A loja fica disponível após aplicar a migração de progressão.</p>';return;}storeItems=catalog||[];ownedItems=new Set((inventory||[]).map(item=>item.item_id));renderStore();}
  function renderStore(){const grid=$("#store-grid");grid.innerHTML=storeItems.map(item=>{const owned=ownedItems.has(item.item_id),repeatable=item.kind==="card",equipped=profile?.equipped_avatar===item.item_id||profile?.equipped_battlefield===item.item_id||profile?.equipped_hand===item.item_id;return `<article class="store-item panel"><div class="store-item-art">${item.asset_path?.endsWith(".svg")?`<img src="${escapeHTML(item.asset_path)}" alt="">`:item.asset_path?.endsWith(".png")?`<img src="${escapeHTML(item.asset_path)}" alt="">`:"✦"}</div><small>${escapeHTML(item.kind.toUpperCase())}</small><h3>${escapeHTML(item.title)}</h3><p>${escapeHTML(item.description)}</p><button class="button ${owned?"button-secondary":"button-primary"}" data-store-action="${repeatable?"buy":owned?"equip":"buy"}" data-item-id="${escapeHTML(item.item_id)}" ${equipped?"disabled":""}>${equipped?"Equipado":owned&&!repeatable?"Equipar":`✦ ${item.price} MC`}</button></article>`;}).join("");}
  async function loadCardCopies(){if(!session)return;const {data,error}=await supabase.from("player_card_copies").select("card_id,copies").eq("player_id",session.user.id);if(error)return;window.MythicCollectionCopies=Object.fromEntries((data||[]).map(item=>[item.card_id,3+item.copies]));window.MythicRefreshDeck?.();window.MythicRefreshCollection?.();}
  async function loadProfile(){
    if(!session)return;
    let {data,error}=await supabase.from("profiles").select("id,display_name,nickname,phone,age,friend_code,rating_points,wins,losses,settings,xp,mythic_coins,tutorial_completed,equipped_avatar,equipped_battlefield,equipped_hand").eq("id",session.user.id).maybeSingle();
    let expansionReady=!error;if(error){const legacy=await supabase.from("profiles").select("id,display_name,friend_code,rating_points,wins,losses,settings").eq("id",session.user.id).maybeSingle();data=legacy.data;error=legacy.error;if(error){notify(displayError(error));return;}}
    profile={xp:0,mythic_coins:0,tutorial_completed:false,equipped_avatar:"default",equipped_battlefield:"battle-forest",equipped_hand:"hand-heaven",...data,expansionReady};if(!profile)return;profile.nickname=profile.nickname||profile.display_name;
    const name=profile.nickname,initials=name.trim().split(/\s+/).slice(0,2).map(part=>part[0]).join("").toUpperCase();
    $("#sidebar-player-name").textContent=name;$("#sidebar-player-rank").textContent=rankForRating(profile.rating_points);$("#sidebar-player-record").textContent=`${profile.wins} vitórias · ${profile.losses} derrotas`;$("#sidebar-player-code").textContent=`Código: ${profile.friend_code}`;
    const avatarAsset=profile.equipped_avatar==="ares-helm"?"assets/ares-helm.svg":null;$("#sidebar-avatar").innerHTML=avatarAsset?`<img src="${avatarAsset}" alt="Capacete de Ares">`:escapeHTML(initials);$("#profile-avatar").innerHTML=avatarAsset?`<img src="${avatarAsset}" alt="Capacete de Ares">`:escapeHTML(initials);$("#profile-display-name").textContent=name;const battlefieldAsset=profile.equipped_battlefield==="battle-mud"?"assets/battlefield-mud.png":"assets/battlefield-forest.png",handAsset=profile.equipped_hand==="hand-forest"?"assets/battlefield-forest.png":"assets/hand-heaven.png";if(battlefieldAsset)document.documentElement.style.setProperty("--battlefield-texture",`url("${battlefieldAsset}")`);if(handAsset)document.documentElement.style.setProperty("--hand-texture",`url("${handAsset}")`);
    $("#profile-name-input").value=name;$("#profile-phone-input").value=profile.phone||"";$("#profile-age-input").value=profile.age||"";$("#profile-email").textContent=session.user.email||"E-mail não disponível";$("#profile-friend-code").textContent=profile.friend_code;
    $("#profile-rating").textContent=profile.rating_points;$("#profile-rank").textContent=rankForRating(profile.rating_points);$("#profile-wins").textContent=profile.wins;$("#profile-losses").textContent=profile.losses;$("#my-friend-code").textContent=profile.friend_code;paintProgression();
    const settings=profile.settings||{};let localVolume=null;try{localVolume=localStorage.getItem("mythic-clash-music-volume");}catch{}const savedVolume=settings.volume??(localVolume===null?42:Number(localVolume)),initialVolume=Number.isFinite(Number(savedVolume))?Math.max(0,Math.min(100,Number(savedVolume))):42;$("#setting-music").checked=settings.music!==false;$("#setting-effects").checked=settings.effects!==false;$("#setting-notifications").checked=settings.notifications!==false;$("#setting-volume").value=initialVolume;$("#setting-volume-value").value=`${initialVolume}%`;try{localStorage.setItem("mythic-clash-music-volume",String(initialVolume));}catch{}window.dispatchEvent(new CustomEvent("mythic-volume-loaded",{detail:{volume:initialVolume}}));
    if(profile.tutorial_completed)localStorage.setItem("mythic-clash-tutorial-complete","true");window.dispatchEvent(new CustomEvent("mythic-profile-loaded"));
    loadSavedDecks().then(hasSaved=>{if(!hasSaved)loadCloudDeck();});loadHistory();loadStore();loadCardCopies();
  }

  async function loadPublicLore(){if(!supabase)return;const {data,error}=await supabase.from("card_lore").select("card_id,story,theme_url");if(!error)window.MythicApplyLore?.(data||[]);}
  async function loadPublicAnnouncement(){if(!supabase)return;const {data,error}=await supabase.from("game_announcements").select("title,body,active").eq("id","main").maybeSingle();const box=$("#game-announcement");if(error||!data?.active){box.hidden=true;return;}$("#game-announcement-title").textContent=data.title;$("#game-announcement-body").textContent=data.body;box.hidden=false;}
  async function loadAdminAccess(){if(!session||!supabase){adminAuthorized=false;$("#admin-nav").hidden=true;return;}const {data,error}=await supabase.rpc("is_site_admin");adminAuthorized=!error&&data===true;$("#admin-nav").hidden=!adminAuthorized;if(adminAuthorized)loadAdminDashboard();}
  async function loadAdminDashboard(){if(!adminAuthorized||!session)return;$("#admin-status").textContent="Carregando dados administrativos…";const results=await Promise.all([supabase.from("shop_catalog").select("item_id,title,description,kind,price,asset_path,card_id,active").order("title"),supabase.from("redeem_codes").select("code,reward_type,reward_amount,item_id,card_id,max_uses,uses,active,expires_at,created_at").order("created_at",{ascending:false}).limit(80),supabase.rpc("admin_list_players"),supabase.from("game_announcements").select("title,body,active").eq("id","main").maybeSingle(),supabase.from("card_lore").select("card_id,story,theme_url")]);const [catalog,gifts,players,announcement,lore]=results;const errors=[catalog.error,gifts.error,players.error,announcement.error,lore.error].filter(Boolean);$("#admin-status").textContent=errors.length?"Algumas informações não carregaram. Verifique se a migração administrativa foi aplicada.":"Acesso administrativo ativo.";adminCatalog=catalog.data||[];adminGifts=gifts.data||[];adminPlayers=players.data||[];adminLore=lore.data||[];renderAdminCatalog();renderAdminGifts();renderAdminPlayers();if(announcement.data){$("#admin-announcement-title").value=announcement.data.title||"";$("#admin-announcement-body").value=announcement.data.body||"";$("#admin-announcement-active").checked=announcement.data.active;}loadAdminLoreEditor();}
  function renderAdminCatalog(){
    $("#admin-shop-list").innerHTML=adminCatalog.map(item=>`<tr><td>${escapeHTML(item.title)}<small>${escapeHTML(item.item_id)}</small></td><td>${escapeHTML(item.kind)}</td><td>${item.price} MC</td><td>${item.active?"Ativo":"Oculto"}</td><td><button type="button" class="text-link" data-admin-edit-item="${escapeHTML(item.item_id)}">Editar</button> <button type="button" class="text-link" data-admin-toggle-item="${escapeHTML(item.item_id)}">${item.active?"Ocultar":"Ativar"}</button></td></tr>`).join("")||'<tr><td colspan="5">Nenhum item cadastrado.</td></tr>';
  }
  function renderAdminGifts(){$("#admin-gift-list").innerHTML=adminGifts.map(gift=>`<tr><td>${escapeHTML(gift.code)}</td><td>${escapeHTML(gift.reward_type)} ${gift.reward_type==="coins"?`${gift.reward_amount} MC`:escapeHTML(gift.item_id||gift.card_id||"")}</td><td>${gift.uses}/${gift.max_uses}</td><td>${gift.active?"Ativo":"Inativo"} <button type="button" class="text-link" data-admin-toggle-gift="${escapeHTML(gift.code)}">${gift.active?"Desativar":"Ativar"}</button></td></tr>`).join("")||'<tr><td colspan="4">Nenhum código criado.</td></tr>';}
  function renderAdminPlayers(){$("#admin-player-list").innerHTML=adminPlayers.map(player=>`<tr><td>${escapeHTML(player.nickname||"Lenda")}</td><td>${escapeHTML(player.email||"")}</td><td>${Math.floor((player.xp||0)/100)+1}</td><td>${player.mythic_coins||0}</td></tr>`).join("")||'<tr><td colspan="4">Nenhum jogador encontrado.</td></tr>';$("#admin-player-select").innerHTML='<option value="">Escolha um jogador</option>'+adminPlayers.map(player=>`<option value="${player.user_id}">${escapeHTML(player.nickname||"Lenda")} · ${escapeHTML(player.email||"")}</option>`).join("");}
  function loadAdminLoreEditor(){const id=$("#admin-lore-card").value,row=adminLore.find(item=>item.card_id===id);$("#admin-lore-text").value=(row?.story||[]).join("\n\n");$("#admin-lore-theme").value=row?.theme_url||"";}
  function adminGuard(){if(!session||!adminAuthorized){notify("Acesso administrativo restrito.");return false;}return true;}
  async function openAdmin(){if(!adminGuard())return;await loadAdminDashboard();}
  async function loadSavedDecks(){if(!session)return false;const {data,error}=await supabase.from("player_saved_decks").select("slot,name,card_counts").eq("player_id",session.user.id).order("slot");if(error)return false;if(data?.length){window.MythicLocalDeckSlots?.set(data.map(row=>({slot:row.slot,name:row.name,cards:row.card_counts})));return true;}return false;}
  async function saveNamedDeck(index,name,cardCounts){if(!session)return;const {error}=await supabase.from("player_saved_decks").upsert({player_id:session.user.id,slot:index+1,name,card_counts:cardCounts,updated_at:new Date().toISOString()},{onConflict:"player_id,slot"});if(error)notify("Não foi possível salvar este deck na conta: "+displayError(error));}

  async function loadCloudDeck(){
    if(!session)return;
    const {data,error}=await supabase.from("player_decks").select("card_counts").eq("player_id",session.user.id).maybeSingle();
    if(error){notify(displayError(error));return;}
    if(data?.card_counts)window.MythicLocalDeck?.set(data.card_counts);
    else saveDeckCounts(window.MythicLocalDeck?.get()||{});
  }

  async function saveDeckCounts(cardCounts){
    if(!session||!cardCounts)return;
    const {error}=await supabase.from("player_decks").upsert({player_id:session.user.id,card_counts:cardCounts,updated_at:new Date().toISOString()},{onConflict:"player_id"});
    if(error)notify("Não foi possível sincronizar o baralho: "+displayError(error));
  }

  async function loadFriends(){
    if(!session)return;
    const {data,error}=await supabase.rpc("list_my_friends");
    if(error){$("#friends-list").innerHTML=`<p class="empty-state">${escapeHTML(displayError(error))}</p>`;return;}
    if(!data?.length){$("#friends-list").innerHTML='<p class="empty-state">Nenhum amigo ainda. Busque alguém pelo código acima.</p>';return;}
    $("#friends-list").innerHTML=data.map(friend=>{
      if(friend.request_status==="pending"&&friend.incoming)return `<article class="friend-list-card"><span class="friend-avatar">${escapeHTML(friend.display_name.slice(0,1).toUpperCase())}</span><span><b>${escapeHTML(friend.display_name)}</b><small>Pedido de amizade · ${escapeHTML(friend.friend_code)}</small></span><button class="button button-primary" data-accept-friend="${friend.friendship_id}">Aceitar</button></article>`;
      if(friend.request_status==="pending")return `<article class="friend-list-card"><span class="friend-avatar">${escapeHTML(friend.display_name.slice(0,1).toUpperCase())}</span><span><b>${escapeHTML(friend.display_name)}</b><small>Pedido enviado · ${escapeHTML(friend.friend_code)}</small></span><i>PENDENTE</i></article>`;
      return `<button class="friend-list-card friend-open-chat" data-chat-id="${friend.friendship_id}" data-friend-id="${friend.friend_id}" data-friend-name="${escapeHTML(friend.display_name)}"><span class="friend-avatar">${escapeHTML(friend.display_name.slice(0,1).toUpperCase())}</span><span><b>${escapeHTML(friend.display_name)}</b><small>${friend.rating_points} pontos · ${escapeHTML(friend.friend_code)}</small></span><i>ABRIR CHAT →</i></button>`;
    }).join("");
  }

  async function searchFriend(code){
    if(!requireLogin())return;
    const result=$("#friend-search-result");result.textContent="Procurando jogador…";
    const {data,error}=await supabase.rpc("find_player_by_friend_code",{p_code:code});
    if(error){result.textContent=displayError(error);return;}
    const found=data?.[0];if(!found){result.textContent="Nenhum jogador encontrado com esse código.";return;}
    if(found.id===session.user.id){result.textContent="Esse é o seu próprio código.";return;}
    result.innerHTML=`<span>${escapeHTML(found.display_name)} · ${found.rating_points} pontos</span> <button type="button" class="button button-secondary" data-add-friend="${escapeHTML(found.friend_code)}">Enviar pedido</button>`;
  }

  async function openChat(friendshipId,friendId,friendName){
    if(messageChannel)supabase.removeChannel(messageChannel);
    activeFriend={friendshipId,friendId,friendName};$("#chat-friend-name").textContent=friendName;
    $("#friend-message-input").disabled=false;$("#friend-message-form button").disabled=false;$("#friend-messages").innerHTML="";
    const {data,error}=await supabase.from("friend_messages").select("id,sender_id,body,created_at").eq("friendship_id",friendshipId).order("created_at",{ascending:true}).limit(100);
    if(error){$("#friend-messages").innerHTML=`<p class="empty-state">${escapeHTML(displayError(error))}</p>`;return;}
    data.forEach(renderMessage);
    messageChannel=supabase.channel(`chat-${friendshipId}`).on("postgres_changes",{event:"INSERT",schema:"public",table:"friend_messages",filter:`friendship_id=eq.${friendshipId}`},payload=>renderMessage(payload.new)).subscribe();
  }

  function renderMessage(message){
    const list=$("#friend-messages");if(list.querySelector(".empty-state"))list.innerHTML="";
    const item=document.createElement("article");item.className="friend-message"+(message.sender_id===session?.user.id?" own":"");
    const body=document.createElement("p");body.textContent=message.body;const time=document.createElement("small");time.textContent=new Date(message.created_at).toLocaleTimeString("pt-BR",{hour:"2-digit",minute:"2-digit"});item.append(body,time);list.append(item);list.scrollTop=list.scrollHeight;
  }

  function listenForInvites(){
    if(inviteChannel)supabase.removeChannel(inviteChannel);
    inviteChannel=supabase.channel(`invites-${session.user.id}`).on("postgres_changes",{event:"UPDATE",schema:"public",table:"game_invites",filter:`host_id=eq.${session.user.id}`},payload=>{if(payload.new.status==="accepted"&&payload.new.match_id){notify("Seu desafio foi aceito. Abrindo a partida…");loadOnlineMatch(payload.new.match_id);}}).subscribe();
  }

  async function loadOnlineMatch(matchId){
    if(!session||!matchId)return;
    clearInterval(queueTicker);queueTicker=null;activeMatchId=matchId;$("#queue-status").hidden=true;
    const {data,error}=await supabase.rpc("get_online_match",{p_match_id:matchId});
    if(error){notify("Não foi possível abrir a partida: "+displayError(error));return;}
    const match=data?.match;if(!match){notify("Partida não encontrada para esta conta.");return;}
    if(gameChannel)supabase.removeChannel(gameChannel);
    gameChannel=supabase.channel(`game-${matchId}`).on("postgres_changes",{event:"UPDATE",schema:"public",table:"game_matches",filter:`id=eq.${matchId}`},()=>refreshOnlineMatch(matchId)).subscribe();
    window.dispatchEvent(new CustomEvent("mythic-online-match",{detail:{match,userId:session.user.id,opponentName:data.opponent_name}}));
  }

  async function refreshOnlineMatch(matchId){
    if(!session||activeMatchId!==matchId)return;
    const {data,error}=await supabase.rpc("get_online_match",{p_match_id:matchId});
    if(!error&&data?.match)window.dispatchEvent(new CustomEvent("mythic-online-match",{detail:{match:data.match,userId:session.user.id,opponentName:data.opponent_name}}));
  }

  async function submitAction(action){
    if(!session||!activeMatchId||actionPending)return;
    actionPending=true;const button=$("#end-turn");button.disabled=true;
    const {error}=await supabase.rpc("submit_game_action",{p_match_id:activeMatchId,p_action:action});
    actionPending=false;
    if(error){notify(displayError(error));refreshOnlineMatch(activeMatchId);return;}
    await refreshOnlineMatch(activeMatchId);
  }

  function leaveMatch(){if(gameChannel)supabase.removeChannel(gameChannel);gameChannel=null;activeMatchId=null;actionPending=false;}

  async function startQueue(mode){
    if(!requireLogin())return;
    $("#queue-status").hidden=false;queueSeconds=0;clearInterval(queueTicker);$("#queue-status-text").textContent=mode==="ranked"?"Procurando adversário da sua faixa · 00:00":"Procurando jogador · 00:00";queueTicker=setInterval(()=>{queueSeconds++;const elapsed=`${String(Math.floor(queueSeconds/60)).padStart(2,"0")}:${String(queueSeconds%60).padStart(2,"0")}`;$("#queue-status-text").textContent=(mode==="ranked"?"Procurando adversário da sua faixa":"Procurando jogador")+` · ${elapsed}`;},1000);
    const {data,error}=await supabase.rpc("join_matchmaking",{p_mode:mode});
    if(error){clearInterval(queueTicker);queueTicker=null;$("#queue-status-text").textContent=displayError(error);return;}
    const entry=Array.isArray(data)?data[0]:data;
    if(entry?.queue_status==="matched"){
      $("#queue-status-text").textContent=`Oponente encontrado. Sala ${entry.match_id.slice(0,8)} criada; carregando partida…`;
      $("#cancel-queue").hidden=true;
      notify("Partida encontrada. Abrindo a arena…");loadOnlineMatch(entry.match_id);
      return;
    }
    $("#cancel-queue").hidden=false;
    queueChannel=supabase.channel(`queue-${session.user.id}`).on("postgres_changes",{event:"UPDATE",schema:"public",table:"matchmaking_queue",filter:`user_id=eq.${session.user.id}`},payload=>{
      if(payload.new.status==="matched"){$("#queue-status-text").textContent="Oponente encontrado. Conectando à partida…";$("#cancel-queue").hidden=true;notify("Partida encontrada. Abrindo a arena…");loadOnlineMatch(payload.new.match_id);}
    }).subscribe();
  }

  async function cancelQueue(){clearInterval(queueTicker);queueTicker=null;if(!session)return;await supabase.rpc("cancel_matchmaking");if(queueChannel)supabase.removeChannel(queueChannel);queueChannel=null;$("#queue-status").hidden=true;$("#cancel-queue").hidden=false;}

  document.addEventListener("click",async event=>{
    const authSwitch=event.target.closest("[data-auth-switch]");if(authSwitch){const signup=authSwitch.dataset.authSwitch==="signup";$("#sign-in-form").hidden=signup;$("#sign-up-form").hidden=!signup;$("#auth-heading").textContent=signup?"Crie sua conta de jogador.":"Sua próxima lenda começa aqui.";showAuthMessage("");return;}
    if(event.target.closest("[data-open-challenge]")){$("#challenge-panel").hidden=false;return;}
    if(event.target.closest("[data-close-challenge]")){$("#challenge-panel").hidden=true;return;}
    const add=event.target.closest("[data-add-friend]");if(add&&requireLogin()){const {error}=await supabase.rpc("request_friend",{p_friend_code:add.dataset.addFriend});$("#friend-search-result").textContent=error?displayError(error):"Pedido enviado. Se o jogador já tinha enviado um pedido, vocês agora são amigos.";if(!error)loadFriends();return;}
    const accept=event.target.closest("[data-accept-friend]");if(accept&&requireLogin()){const {error}=await supabase.rpc("respond_friend_request",{p_friendship_id:accept.dataset.acceptFriend,p_accept:true});if(error)notify(displayError(error));else loadFriends();return;}
    const chat=event.target.closest("[data-chat-id]");if(chat&&requireLogin()){openChat(chat.dataset.chatId,chat.dataset.friendId,chat.dataset.friendName);return;}
    const storeAction=event.target.closest("[data-store-action]");if(storeAction&&requireLogin()){const id=storeAction.dataset.itemId;storeAction.disabled=true;const {error}=storeAction.dataset.storeAction==="buy"?await supabase.rpc("purchase_shop_item",{p_item_id:id}):await supabase.rpc("equip_shop_item",{p_item_id:id});if(error)notify(displayError(error));else{notify(storeAction.dataset.storeAction==="buy"?"Item comprado.":"Item equipado.");await loadProfile();}return;}
  });

  $("#sign-in-form").addEventListener("submit",async event=>{event.preventDefault();if(!supabase){showAuthMessage(configured?"A biblioteca do Supabase não carregou. Atualize a página e verifique a internet.":"Configure a URL e a chave pública do Supabase para ativar o login.");return;}showAuthMessage("Entrando…");const {error}=await supabase.auth.signInWithPassword({email:$("#sign-in-email").value.trim(),password:$("#sign-in-password").value});showAuthMessage(error?displayError(error):"");});
  $("#sign-up-form").addEventListener("submit",async event=>{event.preventDefault();if(!supabase){showAuthMessage(configured?"A biblioteca do Supabase não carregou. Atualize a página e verifique a internet.":"Configure o Supabase para criar sua conta.");return;}showAuthMessage("Criando conta…");const nickname=$("#sign-up-name").value.trim(),phone=$("#sign-up-phone").value.trim(),age=Number($("#sign-up-age").value);const {data,error}=await supabase.auth.signUp({email:$("#sign-up-email").value.trim(),password:$("#sign-up-password").value,options:{data:{nickname,display_name:nickname,phone,age},emailRedirectTo:location.origin+location.pathname}});showAuthMessage(error?displayError(error):data.session?"Conta criada!":"Confira seu e-mail para confirmar a conta.");});
  $("#sign-out").addEventListener("click",async()=>{if(supabase)await supabase.auth.signOut();});
  $("#friend-search-form").addEventListener("submit",event=>{event.preventDefault();searchFriend($("#friend-search-code").value.trim());});
  $("#refresh-friends").addEventListener("click",loadFriends);
  $("#copy-friend-code").addEventListener("click",async()=>{if(!profile)return notify("Entre para ver seu código de amigo.");try{await navigator.clipboard.writeText(profile.friend_code);notify("Código copiado.");}catch{notify("Seu código é "+profile.friend_code);}});
  $("#copy-profile-friend-code").addEventListener("click",async()=>{if(!profile)return notify("Entre para ver seu código de amigo.");try{await navigator.clipboard.writeText(profile.friend_code);notify("Código copiado.");}catch{notify("Seu código é "+profile.friend_code);}});
  $("#friend-message-form").addEventListener("submit",async event=>{event.preventDefault();if(!activeFriend||!session)return;const input=$("#friend-message-input"),body=input.value.trim();if(!body)return;input.value="";const {error}=await supabase.from("friend_messages").insert({friendship_id:activeFriend.friendshipId,sender_id:session.user.id,body});if(error){input.value=body;notify(displayError(error));}});
  $("#profile-edit-form").addEventListener("submit",async event=>{event.preventDefault();if(!session)return requireLogin();const name=$("#profile-name-input").value.trim(),phone=$("#profile-phone-input").value.trim(),age=$("#profile-age-input").value?Number($("#profile-age-input").value):null;const {error}=await supabase.from("profiles").update({display_name:name,nickname:name,phone,age}).eq("id",session.user.id);$("#profile-save-status").textContent=error?displayError(error):"Perfil atualizado.";if(!error)loadProfile();});
  $("#settings-form").addEventListener("submit",async event=>{event.preventDefault();if(!session)return requireLogin();const volume=Number($("#setting-volume").value);try{localStorage.setItem("mythic-clash-music-volume",String(volume));}catch{}window.dispatchEvent(new CustomEvent("mythic-volume-loaded",{detail:{volume}}));const settings={...(profile?.settings||{}),music:$("#setting-music").checked,effects:$("#setting-effects").checked,notifications:$("#setting-notifications").checked,volume};const {error}=await supabase.from("profiles").update({settings}).eq("id",session.user.id);$("#settings-save-status").textContent=error?displayError(error):"Preferências salvas.";if(!error){profile.settings=settings;const toggle=$("#music-toggle"),currentlyOn=toggle.getAttribute("aria-pressed")==="true";if(currentlyOn!==settings.music)toggle.click();}});
  $("#redeem-code-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const code=$("#redeem-code").value.trim().toUpperCase();$("#redeem-result").textContent="Validando código…";const {data,error}=await supabase.rpc("claim_gift_code",{p_code:code});$("#redeem-result").textContent=error?displayError(error):"Presente resgatado!";if(!error){$("#redeem-code").value="";await loadProfile();}});
  $("#setting-volume").addEventListener("input",event=>{const volume=Number(event.target.value);$("#setting-volume-value").value=`${volume}%`;try{localStorage.setItem("mythic-clash-music-volume",String(volume));}catch{}window.dispatchEvent(new CustomEvent("mythic-volume-loaded",{detail:{volume}}));});
  $("#admin-announcement-form").addEventListener("submit",async event=>{event.preventDefault();if(!adminGuard())return;const row={id:"main",title:$("#admin-announcement-title").value.trim(),body:$("#admin-announcement-body").value.trim(),active:$("#admin-announcement-active").checked,updated_at:new Date().toISOString()};const {error}=await supabase.from("game_announcements").upsert(row,{onConflict:"id"});$("#admin-announcement-status").textContent=error?displayError(error):"Comunicado salvo.";if(!error)loadPublicAnnouncement();});
  $("#admin-shop-form").addEventListener("submit",async event=>{event.preventDefault();if(!adminGuard())return;const item={item_id:$("#admin-item-id").value.trim().toLowerCase(),title:$("#admin-item-title").value.trim(),description:$("#admin-item-description").value.trim(),kind:$("#admin-item-kind").value,price:Number($("#admin-item-price").value),asset_path:$("#admin-item-asset").value.trim(),card_id:$("#admin-item-card").value.trim()||null,active:true};const {error}=await supabase.from("shop_catalog").upsert(item,{onConflict:"item_id"});$("#admin-shop-status").textContent=error?displayError(error):"Item salvo no catálogo.";if(!error){event.target.reset();$("#admin-item-price").value="100";await loadAdminDashboard();await loadStore();}});
  $("#admin-gift-form").addEventListener("submit",async event=>{event.preventDefault();if(!adminGuard())return;const date=$("#admin-gift-expiry").value;const gift={code:$("#admin-gift-code").value.trim().toUpperCase(),reward_type:$("#admin-gift-type").value,reward_amount:Number($("#admin-gift-amount").value)||0,item_id:$("#admin-gift-item").value.trim()||null,card_id:$("#admin-gift-card").value.trim()||null,max_uses:Number($("#admin-gift-uses").value),active:true,expires_at:date?new Date(date).toISOString():null};const {error}=await supabase.from("redeem_codes").insert(gift);$("#admin-gift-status").textContent=error?displayError(error):"Código criado e pronto para compartilhar.";if(!error){event.target.reset();$("#admin-gift-amount").value="100";$("#admin-gift-uses").value="1";await loadAdminDashboard();}});
  $("#admin-reward-form").addEventListener("submit",async event=>{event.preventDefault();if(!adminGuard())return;const {error}=await supabase.rpc("admin_adjust_player_rewards",{p_user_id:$("#admin-player-select").value,p_coins_delta:Number($("#admin-coins-delta").value),p_xp_delta:Number($("#admin-xp-delta").value)});$("#admin-reward-status").textContent=error?displayError(error):"Recompensas atualizadas e registradas.";if(!error){$("#admin-coins-delta").value="0";$("#admin-xp-delta").value="0";await loadAdminDashboard();}});
  $("#admin-lore-card").addEventListener("change",loadAdminLoreEditor);
  $("#admin-lore-form").addEventListener("submit",async event=>{event.preventDefault();if(!adminGuard())return;const story=$("#admin-lore-text").value.split(/\n\s*\n/).map(part=>part.trim()).filter(Boolean),theme=$("#admin-lore-theme").value.trim()||null,row={card_id:$("#admin-lore-card").value,story,theme_url:theme,updated_at:new Date().toISOString()};const {error}=await supabase.from("card_lore").upsert(row,{onConflict:"card_id"});$("#admin-lore-status").textContent=error?displayError(error):"História e trilha tema salvas.";if(!error){await loadPublicLore();const {data}=await supabase.from("card_lore").select("card_id,story,theme_url");adminLore=data||[];loadAdminLoreEditor();}});
  document.addEventListener("click",async event=>{const edit=event.target.closest("[data-admin-edit-item]");if(edit){const item=adminCatalog.find(row=>row.item_id===edit.dataset.adminEditItem);if(!item)return;$("#admin-item-id").value=item.item_id;$("#admin-item-title").value=item.title;$("#admin-item-description").value=item.description;$("#admin-item-kind").value=item.kind;$("#admin-item-price").value=item.price;$("#admin-item-asset").value=item.asset_path;$("#admin-item-card").value=item.card_id||"";$("#admin-item-title").focus();return;}const toggle=event.target.closest("[data-admin-toggle-item]");if(toggle&&adminGuard()){const item=adminCatalog.find(row=>row.item_id===toggle.dataset.adminToggleItem);const {error}=await supabase.from("shop_catalog").update({active:!item.active}).eq("item_id",item.item_id);if(error)notify(displayError(error));else{await loadAdminDashboard();await loadStore();}return;}const gift=event.target.closest("[data-admin-toggle-gift]");if(gift&&adminGuard()){const item=adminGifts.find(row=>row.code===gift.dataset.adminToggleGift);const {error}=await supabase.from("redeem_codes").update({active:!item.active}).eq("code",item.code);if(error)notify(displayError(error));else loadAdminDashboard();}});
  $("#enable-notifications").addEventListener("click",async()=>{const status=$("#device-feature-status");if(!("Notification" in window)){status.textContent="Este navegador não oferece notificações.";return;}const result=await Notification.requestPermission();status.textContent=result==="granted"?"Notificações ativadas neste aparelho.":"Permissão de notificações não concedida.";if(result==="granted")new Notification("Mythic Clash",{body:"Avisos deste aparelho foram ativados enquanto o jogo estiver aberto."});});
  $("#enable-biometrics").addEventListener("click",()=>{$("#device-feature-status").textContent=window.PublicKeyCredential?"Este aparelho oferece biometria, mas o acesso seguro por passkey ainda precisa da validação de credenciais no servidor.":"Este navegador não oferece passkey/biometria.";});
  $("#cancel-queue").addEventListener("click",cancelQueue);
  $("#create-invite-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const friendCode=$("#invite-friend-code").value.trim().toUpperCase()||null;const {data,error}=await supabase.rpc("create_game_invite",{p_mode:"friend",p_invited_friend_code:friendCode});if(error){$("#created-invite-code").textContent=displayError(error);return;}const invite=Array.isArray(data)?data[0]:data;$("#created-invite-code").textContent=`Código do desafio: ${invite.invite_code} · válido por 15 minutos`;});
  $("#join-invite-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const {data,error}=await supabase.rpc("join_game_invite",{p_code:$("#join-invite-code").value.trim().toUpperCase()});const match=Array.isArray(data)?data[0]:data;$("#joined-invite-status").textContent=error?displayError(error):`Desafio aceito. Abrindo partida…`;if(!error&&match?.match_id)loadOnlineMatch(match.match_id);});
  window.MythicOnline={saveDeckCounts,saveNamedDeck,isConnected:()=>Boolean(session),isAdmin:()=>adminAuthorized,openAdmin,submitAction,leaveMatch,startQueue,tutorialCompleted:()=>profile?(profile.expansionReady?Boolean(profile.tutorial_completed):localStorage.getItem("mythic-clash-tutorial-complete")==="true"):false,isTutorialComplete:()=>Boolean(profile?.tutorial_completed),completeTutorial:async()=>{if(!session)return;const {error}=await supabase.rpc("complete_tutorial_once");if(error){notify("Tutorial concluído, mas a recompensa precisa da migração de progressão.");return;}await loadProfile();},recordGuardianMatch:async(matchId,outcome,playerPoints,opponentPoints)=>{if(!session)return;const {error}=await supabase.rpc("record_guardian_match",{p_match_id:matchId,p_outcome:outcome,p_player_points:playerPoints,p_opponent_points:opponentPoints});if(error)notify(displayError(error));else{await loadProfile();}},refreshProfile:loadProfile};
})();
