(() => {
  const $ = selector => document.querySelector(selector);
  const config = window.MYTHIC_SUPABASE_CONFIG || {};
  const configured = Boolean(config.url && config.publishableKey);
  let supabase = null, session = null, profile = null, activeFriend = null, activeMatchId = null, actionPending = false;
  let messageChannel = null, inviteChannel = null, queueChannel = null, gameChannel = null, queueTimeout = null;
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
    $("#account-status-title").textContent="Recursos online";
    $("#account-status-caption").textContent="URL/chave pública não configurada";
  } else if(!window.supabase?.createClient){
    $("#connection-status-text").textContent="Biblioteca indisponível";
    $("#account-status-title").textContent="Supabase aguardando conexão";
    $("#account-status-caption").textContent="Verifique a conexão com a internet";
  } else {
    supabase=window.supabase.createClient(config.url,config.publishableKey);
    $("#connection-status-text").textContent="Conectando";
    supabase.auth.getSession().then(({data})=>setSession(data.session));
    supabase.auth.onAuthStateChange((_event,nextSession)=>setTimeout(()=>setSession(nextSession),0));
  }

  function setSession(nextSession){
    session=nextSession; const gate=$("#account-gate");
    if(!configured){gate.hidden=true;return;}
    gate.hidden=Boolean(session);
    $("#connection-status-text").textContent=session?"Online":"Entre na conta";
    $("#account-status-title").textContent=session?"Conta conectada":"Entre na sua conta";
    $("#account-status-caption").textContent=session?"Perfil e amigos sincronizados":"Use seu e-mail e senha";
    if(session){loadProfile();loadFriends();listenForInvites();}else{profile=null;activeFriend=null;cleanupChannels();$("#sidebar-player-name").textContent="Visitante";$("#sidebar-player-rank").textContent="Convidado";$("#profile-email").textContent="Entre para conectar sua conta.";}
  }

  function cleanupChannels(){
    if(messageChannel)supabase.removeChannel(messageChannel);
    if(inviteChannel)supabase.removeChannel(inviteChannel);
    if(queueChannel)supabase.removeChannel(queueChannel);
    if(gameChannel)supabase.removeChannel(gameChannel);
    messageChannel=inviteChannel=queueChannel=gameChannel=null;activeMatchId=null;
  }

  async function loadProfile(){
    if(!session)return;
    const {data,error}=await supabase.from("profiles").select("id,display_name,friend_code,rating_points,wins,losses,settings").eq("id",session.user.id).maybeSingle();
    if(error){notify(displayError(error));return;}
    profile=data;if(!profile)return;
    const initials=profile.display_name.trim().split(/\s+/).slice(0,2).map(part=>part[0]).join("").toUpperCase();
    $("#sidebar-player-name").textContent=profile.display_name;$("#sidebar-player-rank").textContent=`${profile.rating_points} de classificação`;
    $("#sidebar-avatar").textContent=initials;$("#profile-avatar").textContent=initials;$("#profile-display-name").textContent=profile.display_name;
    $("#profile-name-input").value=profile.display_name;$("#profile-email").textContent=session.user.email||"Conta conectada";
    $("#profile-rating").textContent=profile.rating_points;$("#profile-wins").textContent=profile.wins;$("#profile-losses").textContent=profile.losses;
    $("#my-friend-code").textContent=profile.friend_code;
    const settings=profile.settings||{};$("#setting-music").checked=settings.music!==false;$("#setting-effects").checked=settings.effects!==false;$("#setting-notifications").checked=settings.notifications!==false;
    loadCloudDeck();
  }

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
    activeMatchId=matchId;$("#queue-status").hidden=true;
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
    $("#queue-status").hidden=false;$("#queue-status-text").textContent=mode==="ranked"?"Procurando adversário da sua faixa…":"Procurando jogador…";
    const {data,error}=await supabase.rpc("join_matchmaking",{p_mode:mode});
    if(error){$("#queue-status-text").textContent=displayError(error);return;}
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

  async function cancelQueue(){if(!session)return;await supabase.rpc("cancel_matchmaking");if(queueChannel)supabase.removeChannel(queueChannel);queueChannel=null;$("#queue-status").hidden=true;$("#cancel-queue").hidden=false;}

  document.addEventListener("click",async event=>{
    const authSwitch=event.target.closest("[data-auth-switch]");if(authSwitch){const signup=authSwitch.dataset.authSwitch==="signup";$("#sign-in-form").hidden=signup;$("#sign-up-form").hidden=!signup;$("#auth-heading").textContent=signup?"Crie sua conta de jogador.":"Sua próxima lenda começa aqui.";showAuthMessage("");return;}
    if(event.target.closest("[data-open-challenge]")){$("#challenge-panel").hidden=false;return;}
    if(event.target.closest("[data-close-challenge]")){$("#challenge-panel").hidden=true;return;}
    const add=event.target.closest("[data-add-friend]");if(add&&requireLogin()){const {error}=await supabase.rpc("request_friend",{p_friend_code:add.dataset.addFriend});$("#friend-search-result").textContent=error?displayError(error):"Pedido enviado. Se o jogador já tinha enviado um pedido, vocês agora são amigos.";if(!error)loadFriends();return;}
    const accept=event.target.closest("[data-accept-friend]");if(accept&&requireLogin()){const {error}=await supabase.rpc("respond_friend_request",{p_friendship_id:accept.dataset.acceptFriend,p_accept:true});if(error)notify(displayError(error));else loadFriends();return;}
    const chat=event.target.closest("[data-chat-id]");if(chat&&requireLogin()){openChat(chat.dataset.chatId,chat.dataset.friendId,chat.dataset.friendName);return;}
    const mode=event.target.closest("[data-online-mode]");if(mode)startQueue(mode.dataset.onlineMode);
  });

  $("#sign-in-form").addEventListener("submit",async event=>{event.preventDefault();if(!supabase){showAuthMessage(configured?"A biblioteca do Supabase não carregou. Atualize a página e verifique a internet.":"Configure a URL e a chave pública do Supabase para ativar o login.");return;}showAuthMessage("Entrando…");const {error}=await supabase.auth.signInWithPassword({email:$("#sign-in-email").value.trim(),password:$("#sign-in-password").value});showAuthMessage(error?displayError(error):"");});
  $("#sign-up-form").addEventListener("submit",async event=>{event.preventDefault();if(!supabase){showAuthMessage(configured?"A biblioteca do Supabase não carregou. Atualize a página e verifique a internet.":"Configure o Supabase para criar sua conta.");return;}showAuthMessage("Criando conta…");const {data,error}=await supabase.auth.signUp({email:$("#sign-up-email").value.trim(),password:$("#sign-up-password").value,options:{data:{display_name:$("#sign-up-name").value.trim()},emailRedirectTo:location.origin+location.pathname}});showAuthMessage(error?displayError(error):data.session?"Conta criada!":"Confira seu e-mail para confirmar a conta.");});
  $("#sign-out").addEventListener("click",async()=>{if(supabase)await supabase.auth.signOut();});
  $("#friend-search-form").addEventListener("submit",event=>{event.preventDefault();searchFriend($("#friend-search-code").value.trim());});
  $("#refresh-friends").addEventListener("click",loadFriends);
  $("#copy-friend-code").addEventListener("click",async()=>{if(!profile)return notify("Entre para ver seu código de amigo.");try{await navigator.clipboard.writeText(profile.friend_code);notify("Código copiado.");}catch{notify("Seu código é "+profile.friend_code);}});
  $("#friend-message-form").addEventListener("submit",async event=>{event.preventDefault();if(!activeFriend||!session)return;const input=$("#friend-message-input"),body=input.value.trim();if(!body)return;input.value="";const {error}=await supabase.from("friend_messages").insert({friendship_id:activeFriend.friendshipId,sender_id:session.user.id,body});if(error){input.value=body;notify(displayError(error));}});
  $("#profile-edit-form").addEventListener("submit",async event=>{event.preventDefault();if(!session)return requireLogin();const name=$("#profile-name-input").value.trim();const {error}=await supabase.from("profiles").update({display_name:name}).eq("id",session.user.id);$("#profile-save-status").textContent=error?displayError(error):"Perfil atualizado.";if(!error)loadProfile();});
  $("#settings-form").addEventListener("submit",async event=>{event.preventDefault();if(!session)return requireLogin();const settings={...(profile?.settings||{}),music:$("#setting-music").checked,effects:$("#setting-effects").checked,notifications:$("#setting-notifications").checked};const {error}=await supabase.from("profiles").update({settings}).eq("id",session.user.id);$("#settings-save-status").textContent=error?displayError(error):"Preferências salvas.";if(!error){profile.settings=settings;const toggle=$("#music-toggle"),currentlyOn=toggle.getAttribute("aria-pressed")==="true";if(currentlyOn!==settings.music)toggle.click();}});
  $("#cancel-queue").addEventListener("click",cancelQueue);
  $("#create-invite-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const friendCode=$("#invite-friend-code").value.trim().toUpperCase()||null;const {data,error}=await supabase.rpc("create_game_invite",{p_mode:"friend",p_invited_friend_code:friendCode});if(error){$("#created-invite-code").textContent=displayError(error);return;}const invite=Array.isArray(data)?data[0]:data;$("#created-invite-code").textContent=`Código do desafio: ${invite.invite_code} · válido por 15 minutos`;});
  $("#join-invite-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const {data,error}=await supabase.rpc("join_game_invite",{p_code:$("#join-invite-code").value.trim().toUpperCase()});const match=Array.isArray(data)?data[0]:data;$("#joined-invite-status").textContent=error?displayError(error):`Desafio aceito. Abrindo partida…`;if(!error&&match?.match_id)loadOnlineMatch(match.match_id);});
  window.MythicOnline={saveDeckCounts,isConnected:()=>Boolean(session),submitAction,leaveMatch};
})();
