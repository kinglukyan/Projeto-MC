(() => {
  const $ = selector => document.querySelector(selector);
  const safeUrl=window.MythicSecurity.assetUrl;
  const config = window.MYTHIC_SUPABASE_CONFIG || {};
  const configured = Boolean(config.url && config.publishableKey);
  let matchFallbackTicker=null,lastMatchSnapshot="",actionSequence=0,forceNextMatchRender=false;const matchRefreshes=new Map();
  let deckLoadedFor=null, profileRequest=0, accountReady=false, profileRefresh=Promise.resolve();
  let supabase = null, session = null, profile = null, activeFriend = null, activeMatchId = null, pendingFriendInviteCode = null, actionPending = false, adminAuthorized = false, adminPlayers = [], adminCatalog = [], adminGifts = [], adminLore = [], adminCardSourceUrl = null, adminCardPreviewUrl = null, adminCardPreviewToken = 0, tutorialSyncPending = false;
  let customRoomTicker=null,customRoomId=null,customRoomInviteCode=null,customSpectatorMatchId=null,duoQueueChannel=null,duoQueueTicker=null,pendingDuoPartyId=null,activeDuoPartyId=null,pendingDuoMode=null;
  let messageChannel = null, inviteChannel = null, queueChannel = null, gameChannel = null, queueTimeout = null, queueSeconds = 0, queueTicker = null, spectatorTicker=null,spectatorMatchId=null,tieBreakTicker=null,replayCurrent=null,replayTicker=null,storeItems = [], ownedItems = new Set(), activeStoreCategory = "icons";
  let matchSessionTimer=null;
  let lobbyParty=null,lobbyTicker=null,lobbyEpoch=0,lobbyBusy=false;
  let floatingQueueState={active:false},queueRequest=0,queueCancelling=false;
  function setQueueState(update){
    if(!update)floatingQueueState={active:false};
    else{
      const same=floatingQueueState.active&&floatingQueueState.format===update.format&&(!update.partyId||floatingQueueState.partyId===update.partyId);
      const startedAt=update.phase==='queued'?(same&&floatingQueueState.phase==='queued'?floatingQueueState.startedAt:Date.now()):null;
      floatingQueueState={...(same?floatingQueueState:{}),...update,active:true,startedAt};
    }
    window.dispatchEvent(new CustomEvent('mythic-queue-state',{detail:{...floatingQueueState}}));
  }
  const escapeHTML = value => String(value).replace(/[&<>"']/g, char => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[char]));
  const notify = message => { const toast=$("#toast"); if(!toast)return; toast.textContent=message; toast.classList.add("show"); setTimeout(()=>toast.classList.remove("show"),2800); };
  const showAuthMessage = message => { $("#auth-message").textContent=message||""; };
  const showLogin = () => { const gate=$("#account-gate"); if(gate)gate.hidden=false; };
  const requireLogin = () => { if(session)return true; showLogin(); if(!configured)showAuthMessage("A autenticação ainda não foi configurada neste ambiente."); return false; };
  const displayError = error => {
    const message=String(error?.message||"");
    if(/refresh_invite_sessions|touch_match_session/.test(message)&&/function|schema|cache/i.test(message))return "Os convites precisam da atualização 036 no servidor.";
    if(/get_duo_lobby|start_duo_lobby_queue|leave_duo_lobby/.test(message)&&/function|schema|cache/i.test(message))return "A sala precisa da atualização 035 no servidor.";
    if(/banned|temporarily suspended/i.test(message))return "Esta conta está temporariamente suspensa.";
    if(/email rate limit exceeded|over_email_send_rate_limit|over_email_rate_limit/i.test(message))return "O Supabase limitou temporariamente o envio de e-mails de cadastro. Aguarde ou configure um SMTP próprio no painel do Supabase.";
    return message||"Não foi possível concluir. Tente novamente.";
  };

  const cardLoreSelect="card_id,story,theme_url,comic_url,card_name,ability_title,ability_text,art_url,source_art_url,faction,power,badge_key";

  if(!configured){
    $("#connection-status-text").textContent="Supabase sem configuração";
  } else if(!window.supabase?.createClient){
    $("#connection-status-text").textContent="Biblioteca indisponível";
  } else {
    supabase=window.supabase.createClient(config.url,config.publishableKey);
    $("#connection-status-text").textContent="Conectando";
    loadPublicLore();loadPublicAnnouncement();supabase.auth.getSession().then(({data})=>setSession(data.session)).catch(()=>{setSession(null);showAuthMessage("Não foi possível recuperar a sessão. Tente entrar novamente.");});
    supabase.auth.onAuthStateChange((_event,nextSession)=>setTimeout(()=>setSession(nextSession),0));
  }

  function setSession(nextSession){
    if(session?.user?.id&&session.user.id===nextSession?.user?.id){session=nextSession;return;}
    const changed=session?.user?.id!==nextSession?.user?.id;
    session=nextSession;window.dispatchEvent(new CustomEvent("mythic-session-changed",{detail:{connected:Boolean(session)}}));
    if(changed){window.MythicWelcome?.reset();activeFriend=null;adminPlayers=[];adminGifts=[];adminCatalog=[];adminLore=[];for(const id of ["#friend-chat-window","#friend-profile-backdrop","#friend-challenge-inbox"])if($(id))$(id).hidden=true;for(const id of ["#friend-messages","#friend-gift-inbox","#admin-player-list","#admin-gift-list"])$(id)?.replaceChildren();if($("#friend-profile-backdrop"))$("#friend-profile-backdrop").dataset.playerId="";window.MythicGame?.resetAccountView?.();profileRefresh=Promise.resolve();cleanupChannels();cachedFriends=[];friendPage=0;$("#friends-list").replaceChildren();$("#friend-pending-list").replaceChildren();profileRequest++;deckLoadedFor=null;profile=null;accountReady=false;adminAuthorized=false;window.MythicCollectionCopies={};window.MythicResetAccountDeck?.();ownedItems=new Set();window.MythicRefreshCollection?.();window.dispatchEvent(new CustomEvent("mythic-profile-loaded"));}
    $("#admin-nav").hidden=true; const gate=$("#account-gate");
    if(!configured){gate.hidden=false;$("#connection-status-text").textContent="Entre na conta";$("#auth-description").textContent="Entre ou crie uma conta para acessar o jogo.";$("#auth-message").textContent="A autenticação ainda não foi configurada neste ambiente.";return;}
    gate.hidden=Boolean(session);
    $("#connection-status-text").textContent=session?"Online":"Entre na conta";
    $("#auth-description").textContent="Entre ou crie uma conta para acessar o jogo.";
    if(session){window.MythicPortal?.checkAccess?.().then(ok=>{if(ok)window.MythicWelcome?.begin(session.user);});startPresence();loadProfile().catch(()=>{});loadCommunityHub().catch(()=>{});loadFriends();loadIncomingFriendInvite();listenForInvites();loadAdminAccess();if(new URLSearchParams(location.search).has("replay"))setTimeout(()=>document.querySelector('[data-view="profile"]')?.click(),0);}else{profile=null;emitConceptProfile();adminAuthorized=false;$("#admin-nav").hidden=true;if($("#friend-challenge-inbox"))$("#friend-challenge-inbox").hidden=true;pendingFriendInviteCode=null;loadStore().catch(()=>{});activeFriend=null;cleanupChannels();$("#sidebar-player-name").textContent="Entre na sua conta";$("#sidebar-player-rank").textContent="Perfil indisponível";$("#profile-display-name").textContent="Entre na sua conta";$("#sidebar-rank-emblem").src=rankEmblem(1000);$("#sidebar-player-record").textContent="";$("#sidebar-player-code").textContent="";$("#profile-email").textContent="Entre na sua conta para abrir o perfil.";$("#auth-message").textContent="";renderLocalHistory();}
  }

  function cleanupChannels(){
    queueRequest++;queueCancelling=false;setQueueState(null);clearInterval(lobbyTicker);lobbyTicker=null;lobbyEpoch++;lobbyParty=null;lobbyBusy=false;emitLobby();
    clearInterval(matchSessionTimer);matchSessionTimer=null;
    stopPresence();
    for(const ticker of [queueTicker,queueTimeout,customRoomTicker,spectatorTicker,tieBreakTicker,replayTicker,matchFallbackTicker])clearInterval(ticker);
    queueTicker=queueTimeout=customRoomTicker=spectatorTicker=tieBreakTicker=replayTicker=matchFallbackTicker=null;
    spectatorMatchId=customRoomId=customRoomInviteCode=customSpectatorMatchId=null;replayCurrent=null;matchRefreshes.clear();lastMatchSnapshot="";forceNextMatchRender=false;actionSequence++;actionPending=false;

    if(messageChannel)supabase.removeChannel(messageChannel);
    if(inviteChannel)supabase.removeChannel(inviteChannel);
    if(duoQueueChannel)supabase.removeChannel(duoQueueChannel);
    if(duoQueueTicker)clearInterval(duoQueueTicker);duoQueueTicker=null;
    if(queueChannel)supabase.removeChannel(queueChannel);
    if(gameChannel)supabase.removeChannel(gameChannel);
    messageChannel=inviteChannel=queueChannel=gameChannel=duoQueueChannel=null;activeMatchId=null;activeDuoPartyId=null;pendingDuoPartyId=null;
  }

  const rankForRating=rating=>window.MythicRank.from(rating).name;
  const rankEmblem=rating=>`assets/identity-v2/${({"Aprendiz de Herói":"aprendiz-de-heroi","Escudeiro":"escudeiro","Herói":"heroi","Lenda":"lenda","Semideus":"semideus","Deus":"deus","Convergente":"convergente"})[rankForRating(rating)]}.webp`;
  function paintProgression(){if(!profile)return;const xp=Number(profile.xp)||0,level=Math.max(profile.tutorial_completed?2:1,Math.floor(xp/100)+1),within=xp%100;$("#profile-level").textContent=level;$("#profile-xp-label").textContent=`${within} / 100 XP`;$("#profile-xp").value=within;$("#profile-coins").textContent=profile.mythic_coins||0;$("#store-coins").textContent=profile.mythic_coins||0;}
  let historyRows=[];
  function renderHistory(data){historyRows=(data||[]).slice(0,100);const mode=$("#history-mode-filter")?.value||"all",period=$("#history-period-filter")?.value||"all",cutoff=period==="all"?0:Date.now()-Number(period)*86400000,rows=historyRows.filter(match=>(mode==="all"||match.mode===mode)&&(new Date(match.completed_at).getTime()>=cutoff)),list=$("#match-history-list"),arena=$("#arena-recent-matches");if($("#history-summary"))$("#history-summary").textContent=`${rows.length} ${rows.length===1?"partida":"partidas"}`;const wins=rows.filter(match=>match.outcome==="victory").length,losses=rows.filter(match=>match.outcome==="defeat").length,played=rows.length;if($("#arena-stat-played"))$("#arena-stat-played").textContent=played;$("#arena-stat-wins").textContent=wins;$("#arena-stat-losses").textContent=losses;$("#arena-stat-winrate").textContent=played?`${Math.round(wins/played*100)}%`:"—";const html=rows.length?rows.slice(0,5).map(match=>`<article class="arena-history-row ${escapeHTML(match.outcome)}"><span><b>${match.outcome==="victory"?"Vitória":match.outcome==="defeat"?"Derrota":"Empate"}</b><small>${escapeHTML(match.opponent_name)} · ${escapeHTML(({guardian:"Guardião",ranked:"Ranqueada",normal:"Normal",friend:"X1"})[match.mode]||match.mode)} · ${new Date(match.completed_at).toLocaleDateString("pt-BR")}</small></span><b>${match.player_points} × ${match.opponent_points}</b></article>`).join(""):'<p>Suas partidas concluídas aparecerão aqui.</p>';if(list)list.innerHTML=rows.length?rows.map(match=>`<article class="history-row ${escapeHTML(match.outcome)}"><span><b>${match.outcome==="victory"?"Vitória":match.outcome==="defeat"?"Derrota":"Empate"}</b><small>${escapeHTML(match.opponent_name)} · ${escapeHTML(({guardian:"Guardião",ranked:"Ranqueada",normal:"Normal",friend:"X1"})[match.mode]||match.mode)} · ${new Date(match.completed_at).toLocaleDateString("pt-BR")}</small></span><span>${match.player_points} × ${match.opponent_points}</span><small>+${match.xp_earned} XP · +${match.coins_earned} MC</small></article>`).join(""):'<p>Nenhuma partida neste filtro.</p>';if(arena)arena.innerHTML=html;window.dispatchEvent(new CustomEvent("mythic-profile-history",{detail:{rows}}));}
  function renderLocalHistory(){let rows=[];try{rows=JSON.parse(localStorage.getItem("mythic-clash-local-history:"+(session?.user?.id||"offline"))||"[]");}catch{}renderHistory(rows);}
  async function loadHistory(){const uid=session?.user?.id;if(!session){renderLocalHistory();return;}const {data,error}=await supabase.from("match_history").select("opponent_name,mode,outcome,player_points,opponent_points,xp_earned,coins_earned,completed_at").eq("player_id",uid).order("completed_at",{ascending:false}).limit(100);if(uid!==session?.user?.id)return;if(error){$("#match-history-list").innerHTML='<p>Histórico indisponível. Atualize a migração de progressão.</p>';renderLocalHistory();return;}renderHistory(data||[]);}
  const profileCardNames={"soldado-esparta":"Soldado de Esparta",athena:"Atena, Guardiã","lobo-alfa":"Lobisomem Alfa","guardiao-nordico":"Guardião Nórdico",mjolnir:"Mjölnir","runas-nordicas":"Runas Nórdicas",grecia:"Grécia",eclipse:"Eclipse","campo-troia":"Campo de Troia",medusa:"Medusa",poseidon:"Poseidon",zeus:"Zeus",hades:"Hades"};
  const profileCardArt={"soldado-esparta":"assets/soldado-esparta-sem-pontas-azuis.png",medusa:"assets/medusa-full.png",poseidon:"assets/poseidon-full.png",zeus:"assets/zeus-full.png",hades:"assets/hades-full.png"};
  for(const card of window.MythicCardData?.()||[]){profileCardNames[card.id]=card.name;if(card.art)profileCardArt[card.id]=card.art;}
  for(const selector of ['#admin-lore-card','#admin-card-id']){const select=$(selector);if(!select)continue;for(const card of window.MythicCardData?.()||[]){const option=[...select.options].find(item=>item.value===card.id);if(option)option.textContent=card.name;else select.add(new Option(card.name,card.id));}}
  const profileModeNames={guardian:"Guardião",normal:"Normal",ranked:"Ranqueada",friend:"X1"};
  function renderAnalyticsInto(stats,ids){
    const summary=$(ids.summary),cards=$(ids.cards),decks=$(ids.decks),modes=$(ids.modes),recent=ids.recent?$(ids.recent):null;
    const values=stats?.stats||{},matches=Number(values.matches)||0,wins=Number(values.victories)||0,losses=Number(values.defeats)||0,rate=Number(values.win_rate)||0;
    if(summary)summary.innerHTML=[["PARTIDAS",matches],["VITÓRIAS",wins],["APROVEITAMENTO",`${rate}%`],["DERROTAS",losses]].map(([label,value])=>`<article><small>${label}</small><b>${value}</b></article>`).join("");
    if(cards){const rows=stats?.top_cards||[],max=Math.max(1,...rows.map(row=>Number(row.plays)||0));cards.innerHTML=rows.length?rows.map(row=>{const art=profileCardArt[row.card_id];return `<article class="profile-usage-row"><span class="profile-usage-art">${art?`<img src="${escapeHTML(safeUrl(art))}" alt="">`:"✦"}</span><span class="profile-usage-copy"><b>${escapeHTML(profileCardNames[row.card_id]||row.card_id)}</b><span class="profile-usage-meter"><i style="width:${Math.max(5,Number(row.plays)/max*100)}%"></i></span></span><small>${Number(row.plays)}×</small></article>`;}).join(""):'<p class="profile-analytics-empty">As cartas jogadas aparecerão aqui após partidas online.</p>';}
    if(decks){const rows=stats?.top_decks||[];decks.innerHTML=rows.length?rows.map(row=>`<article class="profile-deck-usage"><span><b>${escapeHTML(row.name||"Deck")}</b><small>${Number(row.games)||0} partidas · ${Number(row.victories)||0} vitórias</small></span><strong>${Number(row.win_rate)||0}%</strong></article>`).join(""):'<p class="profile-analytics-empty">Os decks usados em partidas online aparecerão aqui.</p>';}
    if(modes){const rows=stats?.modes||{};modes.innerHTML=Object.entries(profileModeNames).map(([key,label])=>{const row=rows[key]||{};return `<article class="profile-mode-row"><b>${label}</b><span>${Number(row.matches)||0} partidas</span><small>${Number(row.victories)||0} vitórias</small></article>`;}).join("");}
    if(recent){const rows=stats?.recent_matches||[];recent.innerHTML=rows.length?rows.map(row=>`<article class="friend-recent-match ${escapeHTML(row.outcome)}"><span><b>${row.outcome==="victory"?"Vitória":row.outcome==="defeat"?"Derrota":"Empate"}</b><small>${escapeHTML(row.opponent||"Oponente")} · ${escapeHTML(profileModeNames[row.mode]||row.mode)}</small></span><strong>${Number(row.player_points)||0} × ${Number(row.opponent_points)||0}</strong></article>`).join(""):'<p class="profile-analytics-empty">Nenhuma partida registrada.</p>';}
  }
  async function loadProfileAnalytics(playerId=session?.user?.id,prefix="profile"){
    if(!playerId||!supabase)return;const friend=prefix==="friend-profile";
    const ids=friend?{summary:"#friend-profile-summary",cards:"#friend-profile-top-cards",decks:"#friend-profile-top-decks",modes:"#friend-profile-mode-stats",recent:"#friend-profile-recent"}:{summary:"#profile-analytics-summary",cards:"#profile-top-cards",decks:"#profile-top-decks",modes:"#profile-mode-stats",recent:null};
    const {data,error}=await supabase.rpc("get_player_profile_stats",{p_player_id:playerId});
    if(prefix==="profile"&&playerId!==session?.user?.id)return null;if(friend&&$("#friend-profile-backdrop").dataset.playerId!==playerId)return null;
    if(error){for(const key of ["cards","decks","modes","recent"]){if(ids[key]&&$(ids[key]))$(ids[key]).innerHTML='<p class="profile-analytics-empty">Estatísticas indisponíveis. A migração de perfil precisa ser aplicada no banco.</p>'; }return null;}
    renderAnalyticsInto(data,ids);if(prefix==="profile"&&playerId===session?.user.id)window.dispatchEvent(new CustomEvent("mythic-concept-analytics",{detail:data}));return data;
  }
  async function loadPlayerHonors(playerId=session?.user?.id){
    if(!session||!supabase||!playerId)return null;
    const viewer=session.user.id;
    try{const {data,error}=await supabase.rpc("get_player_honors",{p_player_id:playerId});
      if(session?.user?.id!==viewer)return null;
      window.dispatchEvent(new CustomEvent("mythic-honors-loaded",{detail:{playerId,data,error:error?displayError(error):null}}));return error?null:data;
    }catch(error){if(session?.user?.id===viewer)window.dispatchEvent(new CustomEvent("mythic-honors-loaded",{detail:{playerId,data:null,error:String(error)}}));return null;}
  }
  async function equipPlayerHonors(title,medals){
    if(!session||!supabase)throw new Error("Entre na sua conta.");
    const userId=session.user.id;
    const {data,error}=await supabase.rpc("equip_player_honors",{p_title:title,p_medals:medals});
    if(error)throw new Error(displayError(error));
    if(session?.user?.id!==userId)return null;
    window.dispatchEvent(new CustomEvent("mythic-honors-loaded",{detail:{playerId:userId,data}}));return data;
  }
  async function signOutAccount(){
    if(!supabase)return;
    const buttons=[...document.querySelectorAll('[data-sign-out],#sign-out')];buttons.forEach(b=>b.disabled=true);
    try{const {error}=await supabase.auth.signOut({scope:"local"});if(error){notify(displayError(error));return;}
      setSession(null);document.querySelectorAll('dialog[open]').forEach(d=>d.close());
      window.dispatchEvent(new CustomEvent("mythic-account-signed-out"));
    }catch(error){notify("Não foi possível sair. Tente novamente.");}finally{buttons.forEach(b=>b.disabled=false);}
  }
  document.addEventListener("click",event=>{if(event.target.closest('[data-sign-out]'))signOutAccount();});
  async function openFriendProfile(friend){
    $("#friend-profile-backdrop").dataset.playerId=friend.friend_id;window.dispatchEvent(new CustomEvent("mythic-honors-loaded",{detail:{playerId:friend.friend_id,data:null}}));loadPlayerHonors(friend.friend_id);
    $("#friend-profile-backdrop").hidden=false;$("#friend-profile-name").textContent=friend.display_name;$("#friend-profile-rank").textContent=`${rankForRating(friend.rating_points||1000)} · ${window.MythicRank.label(friend.rating_points)}`;$("#friend-profile-rank-emblem").src=rankEmblem(friend.rating_points||1000);
    const avatar=resolveAvatarAsset(friend.equipped_avatar);$("#friend-profile-avatar").innerHTML=avatar?`<img src="${escapeHTML(avatar)}" alt="">`:escapeHTML(friend.display_name.slice(0,2).toUpperCase());
    for(const id of ["#friend-profile-summary","#friend-profile-top-cards","#friend-profile-top-decks","#friend-profile-mode-stats","#friend-profile-recent"])$(id).innerHTML='<p class="profile-analytics-empty">Carregando dados do perfil…</p>';
    const data=await loadProfileAnalytics(friend.friend_id,"friend-profile");if(!data)return;
    const player=data.profile||{};$("#friend-profile-name").textContent=player.display_name||friend.display_name;$("#friend-profile-rank").textContent=`${rankForRating(player.rating_points||1000)} · ${window.MythicRank.label(player.rating_points)} · Nível ${player.level||1}`;$("#friend-profile-rank-emblem").src=rankEmblem(player.rating_points||1000);
    const friendAvatar=resolveAvatarAsset(player.equipped_avatar);$("#friend-profile-avatar").innerHTML=friendAvatar?`<img src="${escapeHTML(friendAvatar)}" alt="">`:escapeHTML((player.display_name||friend.display_name).slice(0,2).toUpperCase());
  }

  document.addEventListener("mythic-missions-refresh",()=>{loadCommunityHub().catch(()=>notify("Não foi possível atualizar as missões. Tente novamente."));});
  let communityRequest=null,communityRequestUser=null;
  function loadCommunityHub(){
    if(communityRequest&&communityRequestUser===session?.user?.id)return communityRequest;
    const pending=fetchCommunityHub();communityRequest=pending;communityRequestUser=session?.user?.id;
    pending.finally(()=>{if(communityRequest===pending)communityRequest=null;}).catch(()=>{});
    return pending;
  }
  async function fetchCommunityHub(){if(!session||!supabase)return;const uid=session.user.id;
    const [missions,claims,history]=await Promise.all([supabase.from("missions").select("mission_id,title,description,target_count,reward_xp,reward_coins,mode,chapter").eq("active",true).order("chapter"),supabase.from("mission_claims").select("mission_id").eq("player_id",uid),supabase.from("match_history").select("mode,outcome").eq("player_id",uid)]);
    if(uid!==session?.user?.id)return;const done=new Set((claims.data||[]).map(row=>row.mission_id)),matches=history.data||[];if(missions.error){$("#community-missions").innerHTML=`<p>${escapeHTML(displayError(missions.error))}</p>`;}else{const rows=missions.data||[],current=rows.find(row=>!done.has(row.mission_id)),openChapter=current?.chapter||Number.MAX_SAFE_INTEGER;$("#community-missions").innerHTML=rows.map(mission=>{const progress=mission.mission_id==="first-victory"?matches.filter(row=>row.outcome==="victory").length:matches.filter(row=>(!mission.mode||row.mode===mission.mode)&&(!["chapter-4","chapter-5","chapter-6"].includes(mission.mission_id)||row.outcome==="victory")).length,complete=done.has(mission.mission_id),unlocked=complete||mission.chapter<=openChapter,ready=unlocked&&progress>=mission.target_count&&!complete;return `<article class="community-row mission-step ${complete?"complete":""} ${unlocked?"":"locked"}"><span><b>Etapa ${mission.chapter} · ${escapeHTML(mission.title)}</b><small>${escapeHTML(mission.description)} · ${Math.min(progress,mission.target_count)}/${mission.target_count} · ${mission.reward_xp} XP + ${mission.reward_coins} MC</small></span><button class="button ${ready?"button-primary":"button-secondary"}" data-claim-mission="${escapeHTML(mission.mission_id)}" ${ready?"":"disabled"}>${complete?"Concluída":unlocked?"Resgatar":"Bloqueada"}</button></article>`;}).join("")||"<p>Sem missões ativas.</p>";}
    const [expeditions,guildMembership,tournaments,decks,meta,cardMeta,liveMatches,replays,replayMatches]=await Promise.all([supabase.from("player_expeditions").select("id,card_id,duration_hours,ends_at,reward_coins,claimed_at").eq("player_id",uid).order("started_at",{ascending:false}).limit(8),supabase.from("guild_members").select("guild_id,role,guilds(name,invite_code,description)").eq("player_id",uid).maybeSingle(),supabase.from("player_tournaments").select("id,title,format,starts_at,status,host_id").in("status",["registration","in_progress"]).order("starts_at").limit(20),supabase.from("community_decks").select("id,player_id,title,deck_code,description,created_at").order("created_at",{ascending:false}).limit(20),supabase.from("public_match_meta").select("mode,matches,victories,defeats,draws"),supabase.from("public_card_meta").select("card_id,card_type,plays,matches,wins,win_rate").order("plays",{ascending:false}).limit(12),supabase.rpc("list_friend_active_matches"),supabase.from("game_replays").select("id,match_id,title,is_public,created_at").or(`owner_id.eq.${uid},is_public.eq.true`).order("created_at",{ascending:false}).limit(20),supabase.from("match_history").select("match_id,opponent_name,mode,completed_at").eq("player_id",uid).not("match_id","is",null).order("completed_at",{ascending:false}).limit(20)]);
    if(uid!==session?.user?.id)return;$("#expedition-list").innerHTML=(expeditions.data||[]).map(item=>{const ready=new Date(item.ends_at)<=new Date(),claimed=Boolean(item.claimed_at);return `<article class="community-row"><span><b>${escapeHTML(item.card_id)}</b><small>${item.duration_hours}h · recompensa ${item.reward_coins} MC</small></span><button class="button button-secondary" data-claim-expedition="${item.id}" ${ready&&!claimed?"":"disabled"}>${claimed?"Resgatada":ready?"Resgatar":"Em andamento"}</button></article>`;}).join("")||"<p>Nenhuma expedição ativa.</p>";
    const guild=guildMembership.data?.guilds,guildId=guildMembership.data?.guild_id;$("#guild-list").innerHTML=guild?`<article class="community-row"><span><b>${escapeHTML(guild.name)}</b><small>${escapeHTML(guild.description||"Guilda Mythic")} · convite ${escapeHTML(guild.invite_code)} · ${escapeHTML(guildMembership.data.role)}</small></span></article>`:"<p>Você ainda não faz parte de uma guilda.</p>";
    if(guildId){const [weekly,wars,allGuilds]=await Promise.all([supabase.from("guild_weekly_missions").select("id,title,target,progress,reward_coins,week_start").eq("guild_id",guildId).order("week_start",{ascending:false}).limit(4),supabase.from("guild_wars").select("id,guild_one,guild_two,score_one,score_two,ends_at,status").or(`guild_one.eq.${guildId},guild_two.eq.${guildId}`).order("starts_at",{ascending:false}).limit(5),supabase.from("guilds").select("id,name").neq("id",guildId).limit(20)]);if(uid!==session?.user?.id)return;$("#guild-weekly-list").innerHTML=(weekly.data||[]).map(item=>`<article class="community-row"><span><b>${escapeHTML(item.title)}</b><small>${item.progress}/${item.target} partidas · +${item.reward_coins} MC por membro · semana ${item.week_start}</small></span><button class="button button-secondary" data-claim-guild-mission="${item.id}" ${item.progress>=item.target?"":"disabled"}>Resgatar</button></article>`).join("")||"<p>Missão semanal: complete partidas PvP para encher a barra da guilda.</p>";$("#guild-war-list").innerHTML=(wars.data||[]).map(war=>`<article class="community-row"><span><b>Guerra · ${war.score_one} × ${war.score_two}</b><small>Termina ${new Date(war.ends_at).toLocaleDateString("pt-BR")}</small></span></article>`).join("")||"<p>Sem guerras ativas.</p>";const warForm=$("#guild-war-form");warForm.hidden=guildMembership.data.role==="member";const enemySelect=$("#guild-war-opponent");enemySelect.replaceChildren(new Option("Escolha a guilda rival",""),...(allGuilds.data||[]).map(item=>new Option(item.name,item.id)));}else{$("#guild-weekly-list").innerHTML="<p>Entre em uma guilda para participar de missões semanais.</p>";$("#guild-war-list").replaceChildren();$("#guild-war-form").hidden=true;}
    const rounds=await supabase.from("player_tournament_rounds").select("id,tournament_id,round_number,player_one,player_two,winner_id,match_id,status").order("round_number").limit(200);if(uid!==session?.user?.id)return;$("#tournament-list").innerHTML=(tournaments.data||[]).map(item=>`<article class="community-row"><span><b>${escapeHTML(item.title)}</b><small>${item.format==="swiss"?"Suíço":"Mata-mata"} · ${new Date(item.starts_at).toLocaleString("pt-BR")}</small></span>${item.status==="registration"?`<button class="button button-secondary" data-enter-tournament="${item.id}">Inscrever-se</button>${item.host_id===uid?`<button class="button button-primary" data-create-bracket="${item.id}">Gerar chave</button>`:""}`:item.host_id===uid?`<button class="button button-secondary" data-advance-bracket="${item.id}">Avançar chave</button>`:""}</article>`).join("")||"<p>Nenhum torneio aberto.</p>";$("#tournament-round-list").innerHTML=(rounds.data||[]).map(row=>{const isPlayer=uid===row.player_one||uid===row.player_two;return `<article class="community-row"><span><b>Rodada ${row.round_number} · ${String(row.player_one||"—").slice(0,8)} × ${String(row.player_two||"—").slice(0,8)}</b><small>${row.status==="completed"?`Vencedor ${String(row.winner_id||"Empate").slice(0,8)}`:row.status==="bye"?"Avança por bye":row.status==="active"?"Partida em andamento":"Aguardando partida"}</small></span>${isPlayer&&row.status==="pending"?`<button class="button button-primary" data-start-tournament-match="${row.id}">Iniciar duelo</button>`:isPlayer&&row.status==="active"?`<button class="button button-secondary" data-open-tournament-match="${row.match_id}">Retomar duelo</button>`:""}</article>`;}).join("")||"<p>A chave será exibida após o organizador iniciar o torneio.</p>";
    const voteIds=(decks.data||[]).map(item=>item.id),voteCount={};
    if(voteIds.length){const votes=await supabase.rpc("get_community_deck_votes",{p_deck_ids:voteIds});if(!votes.error)for(const row of votes.data||[])voteCount[row.deck_id]=Number(row.votes)||0;else{const legacy=await supabase.from("community_deck_votes").select("deck_id").in("deck_id",voteIds).limit(10000);for(const row of legacy.data||[])voteCount[row.deck_id]=(voteCount[row.deck_id]||0)+1;}}
    if(uid!==session?.user?.id)return;emitConceptHub(guild,guildId,decks.data||[],voteCount).catch(()=>{});$("#community-deck-list").innerHTML=(decks.data||[]).map(item=>`<article class="community-row"><span><b>${escapeHTML(item.title)}</b><small>${escapeHTML(item.description||"Estratégia da comunidade")} · ${voteCount[item.id]||0} votos</small></span><button class="button button-secondary" data-vote-deck="${item.id}">Dar voto</button></article>`).join("")||"<p>Nenhum deck publicado ainda.</p>";
    const modeMeta=meta.error?`<p>${escapeHTML(displayError(meta.error))}</p>`:(meta.data||[]).map(row=>`<article class="community-row"><span><b>${escapeHTML(({guardian:"Guardião",ranked:"Ranqueada",normal:"Normal",friend:"X1"})[row.mode]||row.mode)}</b><small>${row.matches} partidas · ${row.victories} vitórias · ${row.defeats} derrotas · ${row.draws} empates</small></span></article>`).join("");const cardMetaRows=cardMeta.error?`<p>${escapeHTML(displayError(cardMeta.error))}</p>`:(cardMeta.data||[]).map(row=>`<article class="community-row"><span><b>${escapeHTML(row.card_id)}</b><small>${row.plays} jogadas · presente em ${row.matches} partidas · ${row.wins} vitórias · ${Number(row.win_rate).toLocaleString("pt-BR")}% de vitórias</small></span></article>`).join("");$("#public-meta-stats").innerHTML=`<h3>Resultados por modo</h3>${modeMeta||"<p>Ainda não há partidas concluídas.</p>"}<h3>Cartas mais usadas</h3>${cardMetaRows||"<p>As estatísticas de cartas aparecem conforme novas partidas online são jogadas.</p>"}`;
    $("#friend-live-matches").innerHTML=liveMatches.error?"<p>Partidas de amigos indisponíveis.</p>":(liveMatches.data||[]).map(match=>`<article class="community-row"><span><b>${escapeHTML(match.friend_name)} × ${escapeHTML(match.opponent_name)}</b><small>${escapeHTML(match.mode)} · atraso de 60 segundos</small></span><button class="button button-secondary" data-watch-match="${match.match_id}">Assistir</button></article>`).join("")||"<p>Nenhum amigo está jogando agora.</p>";
    const matchSelect=$("#replay-match-select");if(matchSelect)matchSelect.innerHTML='<option value="">Escolha uma partida</option>'+(replayMatches.data||[]).filter(row=>row.match_id).map(row=>`<option value="${row.match_id}">${escapeHTML(row.opponent_name)} · ${new Date(row.completed_at).toLocaleDateString("pt-BR")} · ${escapeHTML(row.mode)}</option>`).join("");
    $("#replay-list").innerHTML=replays.error?"<p>Replays indisponíveis.</p>":(replays.data||[]).map(row=>`<article class="community-row"><span><b>${escapeHTML(row.title)}</b><small>${new Date(row.created_at).toLocaleDateString("pt-BR")} · ${row.is_public?"Compartilhável":"Privado"}</small></span><button class="button button-secondary" data-open-replay="${row.id}">Abrir replay</button></article>`).join("")||"<p>Salve um replay após concluir uma partida online.</p>";
  }
  function renderReplayFrame(index){if(!replayCurrent?.events?.length)return;const max=replayCurrent.events.length-1,position=Math.max(0,Math.min(max,index)),entry=replayCurrent.events[position],state=entry?.state||{},totals=state.totalPoints||{},round=state.round||"—";$("#replay-timeline").max=String(max);$("#replay-timeline").value=String(position);$("#replay-frame").innerHTML=`<b>Momento ${position+1} de ${max+1} · Rodada ${escapeHTML(round)}</b><p>Placar: ${Number(totals.player_one)||0} × ${Number(totals.player_two)||0}</p><small>${entry.captured_at?new Date(entry.captured_at).toLocaleString("pt-BR"):"Registro da partida"}</small><ol>${(state.log||[]).slice(-5).map(line=>`<li>${escapeHTML(line)}</li>`).join("")}</ol>`;}
  async function openReplay(id){const {data,error}=await supabase.from("game_replays").select("id,title,events,is_public").eq("id",id).maybeSingle();if(error||!data){notify(error?displayError(error):"Replay não encontrado.");return;}replayCurrent=data;$("#replay-viewer-title").textContent=data.title;$("#replay-share").textContent=data.is_public?"Tornar privado":"Ativar compartilhamento";$("#replay-viewer").hidden=false;$("#replay-viewer").dataset.replayId=data.id;renderReplayFrame(0);}
  async function watchFriendMatch(id){spectatorMatchId=id;clearInterval(spectatorTicker);$("#spectator-board").hidden=false;$("#spectator-board").textContent="Solicitando acesso à transmissão atrasada…";const {error}=await supabase.rpc("request_match_spectator",{p_match_id:id,p_delay_seconds:60});if(error){$("#spectator-board").textContent=displayError(error);return;}const art={"soldado-esparta":"assets/soldado-esparta-sem-pontas-azuis.png",athena:"assets/card-back.svg","lobo-alfa":"assets/card-back.svg","guardiao-nordico":"assets/card-back.svg",medusa:"assets/medusa-full.png",poseidon:"assets/poseidon-full.png",zeus:"assets/zeus-full.png",hades:"assets/hades-full.png"},names={"soldado-esparta":"Soldado de Esparta",athena:"Atena, Guardiã","lobo-alfa":"Lobisomem Alfa","guardiao-nordico":"Guardião Nórdico",medusa:"Medusa",poseidon:"Poseidon",zeus:"Zeus",hades:"Hades"};for(const card of window.MythicCardData?.()||[]){names[card.id]=card.name;if(card.art)art[card.id]=card.art;}const cards=side=>(side?.field||[]).map(unit=>`<article class="spectator-card"><img src="${art[unit.cardId]||"assets/card-back.svg"}" alt=""><span>${escapeHTML(names[unit.cardId]||unit.cardId)}</span><b>${Number(unit.bonus)||0}+</b></article>`).join("")||"<small>Campo vazio</small>";const refresh=async()=>{const {data,error:readError}=await supabase.rpc("get_delayed_spectator_snapshot",{p_match_id:id});if(readError){$("#spectator-board").textContent=displayError(readError);clearInterval(spectatorTicker);return;}const state=data?.state;if(!state){$("#spectator-board").textContent="A transmissão aparecerá após o atraso de segurança.";return;}const totals=state.totalPoints||{},one=state.player_one||{},two=state.player_two||{};$("#spectator-board").innerHTML=`<header class="spectator-score"><b>Rodada ${Number(state.round)||1}</b><span><em>${Number(totals.player_one)||0}</em> × <em>${Number(totals.player_two)||0}</em></span><small>Transmissão com 60 segundos de atraso</small></header><div class="spectator-fields"><section><b>Invocador 1 · ${Number(one.trixx)||0} Trixx</b><div>${cards(one)}</div></section><span class="spectator-vs"><img src="assets/vs-emblem.png" alt="VS"></span><section><b>Invocador 2 · ${Number(two.trixx)||0} Trixx</b><div>${cards(two)}</div></section></div><div class="spectator-zones">Local: ${escapeHTML(state.sharedZones?.local||"vazio")} · Terreno: ${escapeHTML(state.sharedZones?.terrain||"vazio")} · Clima: ${escapeHTML(state.sharedZones?.climate||"vazio")}</div><ol>${(state.log||[]).slice(-6).map(line=>`<li>${escapeHTML(line)}</li>`).join("")}</ol>`;};await refresh();spectatorTicker=setInterval(refresh,10000);}
  const tiebreakNames={"soldado-esparta":"Soldado de Esparta",athena:"Atena, Guardiã","lobo-alfa":"Lobisomem Alfa","guardiao-nordico":"Guardião Nórdico",medusa:"Medusa"};
  async function loadTieBreak(matchId){clearInterval(tieBreakTicker);if(!session||activeMatchId!==matchId)return;return window.MythicTieBreak?.openOnline(matchId);}
  window.addEventListener("mythic-history-updated",()=>{if(!session)renderLocalHistory();});
  $("#history-mode-filter")?.addEventListener("change",()=>renderHistory(historyRows));$("#history-period-filter")?.addEventListener("change",()=>renderHistory(historyRows));
  if(!configured)renderLocalHistory();
  async function loadStore(){
    if(!supabase)return;const uid=session?.user?.id;
    const [catalog,inventory]=await Promise.all([
      supabase.from("shop_catalog").select("item_id,title,description,kind,price,asset_path,card_id").eq("active",true).order("price"),
      uid?supabase.from("player_inventory").select("item_id").eq("player_id",uid):Promise.resolve({data:[]})]);
    if(session?.user?.id!==uid)return;
    if(catalog.error||inventory.error)throw new Error(displayError(catalog.error||inventory.error));
    storeItems=(catalog.data||[]).filter(item=>item.item_id!=="ares-helm").map(item=>({...item,asset_path:safeUrl(item.asset_path)}));ownedItems=new Set((inventory.data||[]).map(item=>item.item_id));
    renderStore();paintProfileAvatars();renderAvatarPicker();
  }
  function resolveAvatarAsset(id){if(id==="ares-helm")return null;const chibi=window.MythicChibiAvatars?.avatars.find(a=>a.id===id);if(chibi)return chibi.asset;if(id==="guardian")return "assets/mode-guardian.png";const fixed={"spartan-chibi":"assets/spartan-chibi.svg"};if(fixed[id])return fixed[id];const item=storeItems.find(entry=>entry.item_id===id&&entry.kind==="avatar");if(!item?.asset_path||item.asset_path.includes(".."))return null;return item.asset_path.startsWith("assets/")||item.asset_path.startsWith("https://")?item.asset_path:null;}
  function paintProfileAvatars(){if(!profile)return;emitConceptProfile();const name=profile.nickname||profile.display_name||"Lenda",initials=name.trim().split(/\s+/).slice(0,2).map(part=>part[0]).join("").toUpperCase(),asset=resolveAvatarAsset(profile.equipped_avatar),html=asset?`<img src="${escapeHTML(asset)}" alt="Ícone de ${escapeHTML(name)}">`:escapeHTML(initials);$("#sidebar-avatar").innerHTML=html;$("#profile-avatar").innerHTML=html;}
  function renderStore(){const categories={icons:{kicker:"ROSTOS DA CONVERGÊNCIA",title:"Ícones de perfil",copy:"Escolha a imagem que representará você antes de cada batalha.",items:storeItems.filter(item=>item.kind==="avatar").sort((a,b)=>Number(b.item_id==="spartan-chibi")-Number(a.item_id==="spartan-chibi")),empty:"Novos ícones de perfil chegarão em breve."},cards:{kicker:"COLEÇÃO DE CARTAS",title:"Cartas",copy:"Adicione novas cartas à sua coleção para montar seus baralhos.",items:storeItems.filter(item=>item.kind==="card"&&!window.MythicAvailability?.isDisabled(item.card_id)),empty:"Novas cartas chegarão em breve."},appearances:{kicker:"PERSONALIZE SUA ARENA",title:"Aparências",copy:"Personalize o campo de batalha e a apresentação da sua mão.",items:storeItems.filter(item=>["battlefield","hand"].includes(item.kind)),empty:"Novas aparências chegarão em breve."}};const category=categories[activeStoreCategory]||categories.icons;document.querySelectorAll("[data-store-category]").forEach(button=>button.setAttribute("aria-pressed",String(button.dataset.storeCategory===activeStoreCategory)));$("#store-product-area").hidden=activeStoreCategory==="redeem";$("#store-redeem-area").hidden=activeStoreCategory!=="redeem";if(activeStoreCategory==="redeem")return;$("#store-section-kicker").textContent=category.kicker;$("#store-section-title").textContent=category.title;$("#store-section-copy").textContent=category.copy;$("#store-grid").classList.toggle("store-icon-grid",activeStoreCategory==="icons");$("#store-grid").innerHTML=category.items.map(item=>{const owned=ownedItems.has(item.item_id)||(item.kind==="card"&&Number(window.MythicCollectionCopies?.[item.card_id])>0),equipped=profile?.equipped_avatar===item.item_id||profile?.equipped_battlefield===item.item_id||profile?.equipped_hand===item.item_id,asset=/\.(?:svg|png|webp|jpe?g)(?:#|$)/.test(item.asset_path||"")?`<img loading="lazy" decoding="async" src="${escapeHTML(item.asset_path)}" alt="">`:"✦";return `<article class="store-item panel ${owned?"store-item-owned":""}" data-shop-kind="${escapeHTML(item.kind)}" data-shop-card-id="${escapeHTML(item.card_id||"")}">${owned?'<span class="store-owned-badge"><span aria-hidden="true">✓</span> Você já tem</span>':""}<div class="store-item-art">${item.kind==="card"&&item.card_id?`<button type="button" class="store-card-preview" aria-label="Ampliar ${escapeHTML(item.title)} e ver informações">${asset}</button>`:asset}</div><small>${escapeHTML(item.kind.toUpperCase())}</small><h3>${escapeHTML(item.title)}</h3><p>${escapeHTML(item.description)}</p><button class="button ${owned?"button-secondary":"button-primary"}" data-store-action="${owned?"equip":"buy"}" data-item-id="${escapeHTML(item.item_id)}" ${equipped||(owned&&item.kind==="card")?"disabled":""}>${owned&&item.kind==="card"?"Na sua coleção":equipped?"Equipado":owned?"Equipar":`<img class="mythic-coin-icon" src="assets/identity-v2/coin.webp" alt="">${item.price===0?"Resgatar ícone":item.price+" Mythic Coins"}`}</button></article>`;}).join("")||`<p class="empty-state">${category.empty}</p>`;}
  function renderAvatarPicker(){const options=$("#profile-avatar-options"),ownedAvatars=storeItems.filter(item=>item.kind==="avatar"&&ownedItems.has(item.item_id));if(profile?.equipped_avatar&&profile.equipped_avatar!=="ares-helm"&&!ownedAvatars.some(item=>item.item_id===profile.equipped_avatar))ownedAvatars.unshift({item_id:profile.equipped_avatar,title:profile.equipped_avatar==="default"?"Ícone Mythic Clash":"Ícone equipado",asset_path:resolveAvatarAsset(profile.equipped_avatar)});options.innerHTML=ownedAvatars.map(item=>{const equipped=profile?.equipped_avatar===item.item_id,asset=resolveAvatarAsset(item.item_id);return `<button class="avatar-picker-option ${equipped?"equipped":""}" type="button" data-profile-avatar="${escapeHTML(item.item_id)}" ${equipped?"disabled":""}><span>${asset?`<img src="${escapeHTML(asset)}" alt="">`:escapeHTML((profile?.nickname||"MC").slice(0,2).toUpperCase())}</span><b>${escapeHTML(item.title)}</b><small>${equipped?"Equipado":"Usar ícone"}</small></button>`;}).join("")||'<p class="empty-state">Você ainda não tem ícones extras. Visite a loja para escolher um.</p>';}
  async function loadCardCopies(){
    const uid=session?.user?.id;if(!uid)return;
    const {data,error}=await supabase.from("player_card_copies").select("card_id,copies").eq("player_id",uid);
    if(session?.user?.id!==uid)return;
    if(error)throw new Error(displayError(error));
    window.MythicCollectionCopies=Object.fromEntries((window.MythicCardData?.()||[]).map(card=>[card.id,0]));
    for(const item of data||[])window.MythicCollectionCopies[item.card_id]=Math.max(0,Number(item.copies)||0);
    window.MythicRefreshDeck?.();window.MythicRefreshCollection?.();renderStore();
  }
  function emitConceptProfile(){
    const detail=profile&&session?{name:profile.nickname||profile.display_name,level:Math.max(profile.tutorial_completed?2:1,Math.floor(Number(profile.xp||0)/100)+1),rank:rankForRating(profile.rating_points||1000),rankProgress:window.MythicRank.from(profile.rating_points),xp:Number(profile.xp||0),coins:Number(profile.mythic_coins||0),avatar:resolveAvatarAsset(profile.equipped_avatar)}:null;
    window.dispatchEvent(new CustomEvent("mythic-concept-profile",{detail}));
  }
  async function emitConceptHub(guild,guildId,decks,voteCount){
    const userId=session?.user.id;if(!userId)return;
    const membership=guildId?await supabase.from("guild_members").select("player_id,role").eq("guild_id",guildId):{data:[]};
    const members=membership.data||[],ids=[...new Set([...members.map(row=>row.player_id),...decks.map(row=>row.player_id)])];
    let players={data:[]};
    if(ids.length){players=await supabase.rpc("get_public_player_cosmetics",{p_ids:ids.slice(0,200)});if(players.error)players=await supabase.from("profiles").select("id,display_name,rating_points").in("id",ids);}
    if(session?.user.id!==userId)return;
    const authors=Object.fromEntries((players.data||[]).map(row=>[row.id,row]));
    window.dispatchEvent(new CustomEvent("mythic-concept-community",{detail:{decks:decks.map(row=>({...row,votes:voteCount[row.id]||0})),authors}}));
    window.dispatchEvent(new CustomEvent("mythic-concept-guild",{detail:{guild:guild?{...guild,id:guildId}:null,members:members.map(row=>({...row,profile:authors[row.player_id]||null,avatar:resolveAvatarAsset(authors[row.player_id]?.equipped_avatar)}))}}));
  }
  function reportProfileLoadError(error){
    for(const selector of ["#view-arena","#view-collection","#view-store"]){
      const view=$(selector);if(!view)continue;
      let message=view.querySelector("[data-profile-load-error]");
      if(!error){message?.remove();continue;}
      if(!message){
        message=document.createElement("section");message.dataset.profileLoadError="true";message.className="panel";message.setAttribute("role","alert");message.style.cssText="padding:16px;margin:0 0 18px;border:1px solid #bb9ada;";
        const text=document.createElement("p"),detail=document.createElement("small"),retry=document.createElement("button");
        text.textContent="Não foi possível carregar seus itens. Seus itens continuam salvos na conta.";
        detail.dataset.profileErrorDetail="true";detail.style.cssText="display:block;margin:8px 0;overflow-wrap:anywhere";
        retry.type="button";retry.className="button button-secondary";retry.textContent="Tentar novamente";
        retry.addEventListener("click",async()=>{retry.disabled=true;try{await loadProfile();}catch{}finally{retry.disabled=false;}});
        message.append(text,detail,retry);view.prepend(message);
      }
      message.querySelector("[data-profile-error-detail]").textContent=displayError(error);
    }
  }
  function loadProfile(){
    const uid=session?.user?.id;
    const next=profileRefresh.catch(()=>{}).then(()=>{if(uid===session?.user?.id)return fetchProfile();}).catch(error=>{if(uid===session?.user?.id)reportProfileLoadError(error);throw error;});
    profileRefresh=next;return next;
  }
  async function fetchProfile(){
    if(!session)return;
    const uid=session.user.id,request=++profileRequest;
    const entitlementRequest=Promise.resolve(supabase.rpc("sync_player_entitlements")).catch(error=>({error}));
    let {data,error}=await supabase.from("profiles").select("id,display_name,nickname,phone,age,friend_code,rating_points,wins,losses,settings,xp,mythic_coins,tutorial_completed,equipped_avatar,equipped_battlefield,equipped_hand").eq("id",session.user.id).maybeSingle();
    let expansionReady=!error;if(error){const legacy=await supabase.from("profiles").select("id,display_name,friend_code,rating_points,wins,losses,settings").eq("id",session.user.id).maybeSingle();data=legacy.data;error=legacy.error;if(error){notify(displayError(error));return;}}
    if(session?.user?.id!==uid||request!==profileRequest||!data)return;
    profile={xp:0,mythic_coins:0,tutorial_completed:false,equipped_avatar:"default",equipped_battlefield:"battle-forest",equipped_hand:"hand-heaven",...data,expansionReady};if(!profile)return;profile.nickname=profile.nickname||profile.display_name;
    const name=profile.nickname,initials=name.trim().split(/\s+/).slice(0,2).map(part=>part[0]).join("").toUpperCase();
    $("#sidebar-player-name").textContent=name;$("#sidebar-player-rank").textContent=rankForRating(profile.rating_points);$("#sidebar-rank-emblem").src=rankEmblem(profile.rating_points);$("#sidebar-player-record").textContent=`${profile.wins} vitórias · ${profile.losses} derrotas`;$("#sidebar-player-code").textContent=`Código: ${profile.friend_code}`;
    paintProfileAvatars();$("#profile-display-name").textContent=name;const battlefieldAsset=profile.equipped_battlefield==="battle-mud"?"assets/battlefield-mud.png":"assets/battlefield-forest.png",handAsset=profile.equipped_hand==="hand-forest"?"assets/battlefield-forest.png":"assets/hand-heaven.png";if(battlefieldAsset)document.documentElement.style.setProperty("--battlefield-texture",`url("${battlefieldAsset}")`);if(handAsset)document.documentElement.style.setProperty("--hand-texture",`url("${handAsset}")`);
    $("#profile-name-input").value=name;$("#profile-phone-input").value=profile.phone||"";$("#profile-age-input").value=profile.age||"";$("#profile-email").textContent=session.user.email||"E-mail não disponível";$("#profile-friend-code").textContent=profile.friend_code;
    $("#profile-rating").textContent=window.MythicRank.label(profile.rating_points);$("#profile-rank").textContent=rankForRating(profile.rating_points);$("#profile-rank-emblem").src=rankEmblem(profile.rating_points);$("#profile-rank-emblem").alt=`Insígnia ${rankForRating(profile.rating_points)}`;if($("#profile-wins"))$("#profile-wins").textContent=profile.wins;if($("#profile-losses"))$("#profile-losses").textContent=profile.losses;$("#my-friend-code").textContent=profile.friend_code;paintProgression();
    const settings=profile.settings||{};let localVolume=null;try{localVolume=localStorage.getItem("mythic-clash-music-volume");}catch{}const savedVolume=settings.volume??(localVolume===null?42:Number(localVolume)),initialVolume=Number.isFinite(Number(savedVolume))?Math.max(0,Math.min(100,Number(savedVolume))):42;$("#setting-music").checked=settings.music!==false;$("#setting-effects").checked=settings.effects!==false;$("#setting-notifications").checked=settings.notifications!==false;$("#setting-volume").value=initialVolume;$("#setting-volume-value").value=`${initialVolume}%`;try{localStorage.setItem("mythic-clash-music-volume",String(initialVolume));}catch{}window.dispatchEvent(new CustomEvent("mythic-volume-loaded",{detail:{volume:initialVolume}}));
    try{localStorage.setItem(`mythic-tutorial:${uid}`,String(Boolean(profile.tutorial_completed||Number(profile.xp||0)>=100)));}catch{}
    emitConceptProfile();
    try{
      const entitlement=await entitlementRequest;
      if(session?.user?.id!==uid||request!==profileRequest)return;
      // Profile information is already visible; inventory still waits for grants.
      await Promise.all([loadStore(),loadCardCopies()]);
      if(session?.user?.id!==uid||request!==profileRequest)return;
      if(deckLoadedFor!==uid){const hasSaved=await loadSavedDecks();if(!hasSaved)await loadCloudDeck();if(session?.user?.id===uid)deckLoadedFor=uid;}
      if(session?.user?.id!==uid||request!==profileRequest)return;
      accountReady=true;reportProfileLoadError(entitlement.error||null);
      window.dispatchEvent(new CustomEvent("mythic-profile-loaded"));
      window.dispatchEvent(new CustomEvent("mythic-inventory-loaded"));
    }catch(error){notify("Não foi possível atualizar seus itens: "+displayError(error));throw error;}
    loadHistory();loadProfileAnalytics(uid,"profile");loadPlayerHonors();

  }

  const cardBadgeStyles={"Grécia":{key:"greece",color:"#245b89",asset:"assets/card-badges/gregos-v3.png"},"Nórdicos":{key:"norse",color:"#865bb2",asset:"assets/card-badges/nordicos-v3.png"},"Egípcios":{key:"egypt",color:"#d3a52a",asset:"assets/card-badges/egipcios-v3.png"},"Celtas":{key:"celtic",color:"#37844d",asset:"assets/card-badges/celtas-v3.png"},"Monstros":{key:"monster",color:"#171719",asset:"assets/card-badges/monstros-v3.png"},"Alyns":{key:"alyans",color:"#b83240",asset:"assets/card-badges/alyns-v3.png"}};
  Object.assign(cardBadgeStyles,{"Japonesa":{"key":"japanese","color":"#C94832","asset":"assets/card-badges/remake-japanese.png"},"Chinesa":{"key":"chinese","color":"#18734B","asset":"assets/card-badges/remake-chinese.png"},"Brasil":{"key":"brasil","color":"#147D52","asset":"assets/card-badges/remake-brasil.png"},"Asteca":{"key":"aztec","color":"#087F8C","asset":"assets/card-badges/remake-aztec.png"},"Hindu":{"key":"hindu","color":"#B96308","asset":"assets/card-badges/remake-hindu.png"},"Mesopotâmica":{"key":"mesopotamian","color":"#414A9C","asset":"assets/card-badges/remake-mesopotamian.png"}});
  async function loadPublicLore(){if(!supabase)return;const {data,error}=await supabase.from("card_lore").select(cardLoreSelect);if(!error){window.MythicApplyLore?.(data||[]);for(const card of window.MythicCardData?.()||[]){profileCardNames[card.id]=card.name;profileCardArt[card.id]=safeUrl(card.art);}}}
  async function loadPublicAnnouncement(){
    if(!supabase)return;
    const {data,error}=await supabase.from("game_announcements").select("title,body,active").eq("id","main").maybeSingle();
    const box=$("#game-announcement");
    if(error||!data?.active)box.hidden=true;
    else{box.hidden=false;$("#game-announcement-title").textContent=data.title;$("#game-announcement-body").textContent=data.body;}
    window.dispatchEvent(new CustomEvent('mythic-public-announcement',{detail:{announcement:!error&&data?.active?data:null,unavailable:Boolean(error)}}));
  }
  async function loadAdminAccess(){
    const requestedUserId=session?.user?.id;
    adminAuthorized=false;$("#admin-nav").hidden=true;
    if(!requestedUserId||!supabase)return;
    const {data,error}=await supabase.rpc("is_site_admin");
    const sameUser=session?.user?.id===requestedUserId;
    adminAuthorized=sameUser&&!error&&data===true;$("#admin-nav").hidden=!adminAuthorized;
    window.dispatchEvent(new CustomEvent("mythic-profile-loaded"));
    if(adminAuthorized)loadAdminDashboard();
  }
  async function loadAdminDashboard(){if(!adminAuthorized||!session)return;const uid=session.user.id;$("#admin-status").textContent="Carregando dados administrativos…";const results=await Promise.all([supabase.from("shop_catalog").select("item_id,title,description,kind,price,asset_path,card_id,active").order("title"),supabase.from("redeem_codes").select("code,reward_type,reward_amount,item_id,card_id,max_uses,uses,active,expires_at,created_at").order("created_at",{ascending:false}).limit(80),supabase.rpc("admin_list_players"),supabase.from("game_announcements").select("title,body,active").eq("id","main").maybeSingle(),supabase.from("card_lore").select(cardLoreSelect)]);if(uid!==session?.user?.id||!adminAuthorized)return;const [catalog,gifts,players,announcement,lore]=results;const errors=[catalog.error,gifts.error,players.error,announcement.error,lore.error].filter(Boolean);$("#admin-status").textContent=players.error?`Não foi possível carregar jogadores: ${displayError(players.error)}`:errors.length?"Algumas informações não carregaram. Verifique a configuração das migrações administrativas.":"Acesso administrativo ativo.";adminCatalog=catalog.data||[];adminGifts=gifts.data||[];adminPlayers=players.data||[];adminLore=lore.data||[];renderAdminCatalog();renderAdminGifts();renderAdminPlayers();if(announcement.data){$("#admin-announcement-title").value=announcement.data.title||"";$("#admin-announcement-body").value=announcement.data.body||"";$("#admin-announcement-active").checked=announcement.data.active;}loadAdminLoreEditor();loadAdminCardEditor();}
  function renderAdminCatalog(){
    $("#admin-shop-list").innerHTML=adminCatalog.map(item=>`<tr><td>${escapeHTML(item.title)}<small>${escapeHTML(item.item_id)}</small></td><td>${escapeHTML(item.kind)}</td><td>${item.price} MC</td><td>${item.active?"Ativo":"Oculto"}</td><td><button type="button" class="text-link" data-admin-edit-item="${escapeHTML(item.item_id)}">Editar</button> <button type="button" class="text-link" data-admin-toggle-item="${escapeHTML(item.item_id)}">${item.active?"Ocultar":"Ativar"}</button></td></tr>`).join("")||'<tr><td colspan="5">Nenhum item cadastrado.</td></tr>';
  }
  function renderAdminGifts(){$("#admin-gift-list").innerHTML=adminGifts.map(gift=>`<tr><td>${escapeHTML(gift.code)}</td><td>${escapeHTML(gift.reward_type)} ${gift.reward_type==="coins"?`${gift.reward_amount} MC`:escapeHTML(gift.item_id||gift.card_id||"")}</td><td>${gift.uses}/${gift.max_uses}</td><td>${gift.active?"Ativo":"Inativo"} <button type="button" class="text-link" data-admin-toggle-gift="${escapeHTML(gift.code)}">${gift.active?"Desativar":"Ativar"}</button></td></tr>`).join("")||'<tr><td colspan="4">Nenhum código criado.</td></tr>';}
  function renderAdminPlayers(){$("#admin-player-list").innerHTML=adminPlayers.map(player=>`<tr><td>${escapeHTML(player.nickname||"Lenda")}</td><td>${escapeHTML(player.email||"")}</td><td>${Math.floor((player.xp||0)/100)+1}</td><td>${player.mythic_coins||0}</td></tr>`).join("")||'<tr><td colspan="4">Nenhum jogador encontrado.</td></tr>';$("#admin-player-select").innerHTML='<option value="">Escolha um jogador</option>'+adminPlayers.map(player=>`<option value="${player.user_id}">${escapeHTML(player.nickname||"Lenda")} · ${escapeHTML(player.email||"")}</option>`).join("");}
  function loadAdminLoreEditor(){const id=$("#admin-lore-card").value,row=adminLore.find(item=>item.card_id===id);$("#admin-lore-text").value=(row?.story||[]).join("\n\n");$("#admin-lore-theme").value=row?.theme_url||"";}
  function loadEditorImage(url){return new Promise((resolve,reject)=>{const image=new Image();image.crossOrigin="anonymous";image.onload=()=>resolve(image);image.onerror=()=>reject(new Error("Não foi possível abrir a imagem da carta."));image.src=url;});}
  function cardEditorValue(selector){return $(selector).value.trim();}
  function adminCardBase(id){const card=window.MythicCardData?.().find(item=>item.id===id);if(card)return id==="medusa"?{...card,art:"assets/medusa-illustration.png"}:card;return id==="modelo-em-branco"?{id,name:"Nova Carta",abilityTitle:"Habilidade",type:"Personagem",faction:"Grécia",power:0,ability:"Escreva aqui o efeito desta carta.",art:null}:null;}
  function loadAdminCardEditor(){const id=$("#admin-card-id").value,base=adminCardBase(id),row=adminLore.find(item=>item.card_id===id);if(!base)return;$("#admin-card-name").value=row?.card_name||base.name;$("#admin-card-title").value=row?.ability_title||base.abilityTitle||"Habilidade";$("#admin-card-ability").value=row?.ability_text||base.ability;const faction=cardBadgeStyles[row?.faction]?row.faction:cardBadgeStyles[base.faction]?base.faction:"Grécia";$("#admin-card-faction").value=faction;$("#admin-card-power").value=Number.isInteger(row?.power)?row.power:base.power;$("#admin-card-image").value="";adminCardSourceUrl=row?.source_art_url||base.art||null;if(adminCardPreviewUrl)URL.revokeObjectURL(adminCardPreviewUrl);adminCardPreviewUrl=null;drawAdminCardPreview();}
  function roundRect(ctx,x,y,w,h,r){ctx.beginPath();ctx.moveTo(x+r,y);ctx.arcTo(x+w,y,x+w,y+h,r);ctx.arcTo(x+w,y+h,x,y+h,r);ctx.arcTo(x,y+h,x,y,r);ctx.arcTo(x,y,x+w,y,r);ctx.closePath();}
  function drawCover(ctx,image,x,y,w,h){const scale=Math.max(w/image.width,h/image.height),sw=w/scale,sh=h/scale,sx=(image.width-sw)/2,sy=(image.height-sh)/2;ctx.drawImage(image,sx,sy,sw,sh,x,y,w,h);}
  function wrapCardText(ctx,text,x,y,maxWidth,lineHeight,maxLines){const words=String(text).split(/\s+/),lines=[];let line="";for(const word of words){const candidate=line?`${line} ${word}`:word;if(ctx.measureText(candidate).width>maxWidth&&line){lines.push(line);line=word;}else line=candidate;}if(line)lines.push(line);const visible=lines.slice(0,maxLines);if(lines.length>maxLines){let last=visible[maxLines-1];while(last.length&&ctx.measureText(`${last}…`).width>maxWidth)last=last.slice(0,-1);visible[maxLines-1]=`${last}…`;}visible.forEach((part,index)=>ctx.fillText(part,x,y+index*lineHeight));}
  async function drawAdminCardPreview(){
    const token=++adminCardPreviewToken,canvas=$("#admin-card-preview"),ctx=canvas.getContext("2d"),faction=cardEditorValue("#admin-card-faction"),style=cardBadgeStyles[faction]||cardBadgeStyles["Grécia"],id=$("#admin-card-id").value,base=adminCardBase(id);
    if(!ctx||!base)return;
    const name=cardEditorValue("#admin-card-name")||base.name,title=cardEditorValue("#admin-card-title")||"Habilidade",ability=cardEditorValue("#admin-card-ability")||base.ability,power=Math.max(0,Math.min(99,Number($("#admin-card-power").value)||0));
    try{
      const shell=await loadEditorImage("assets/soldado-esparta-sem-pontas-azuis.png"),sourceUrl=adminCardPreviewUrl||adminCardSourceUrl||base.art||null,source=sourceUrl?await loadEditorImage(sourceUrl):null,icon=await loadEditorImage(style.asset);
      if(token!==adminCardPreviewToken)return;
      ctx.setTransform(1,0,0,1,0,0);ctx.clearRect(0,0,canvas.width,canvas.height);ctx.setTransform(2,0,0,2,0,0);
      ctx.drawImage(shell,0,0,750,1050);
      ctx.save();roundRect(ctx,80,202,590,455,13);ctx.clip();if(sourceUrl)drawCover(ctx,source,80,202,590,455);else{const artFill=ctx.createLinearGradient(80,202,670,657);artFill.addColorStop(0,"#e9dcc0");artFill.addColorStop(.52,"#d8c49b");artFill.addColorStop(1,"#c8ad78");ctx.fillStyle=artFill;ctx.fillRect(80,202,590,455);ctx.strokeStyle="rgba(111,76,39,.28)";ctx.lineWidth=2;ctx.strokeRect(91,213,568,433);ctx.textAlign="center";ctx.textBaseline="middle";ctx.fillStyle="#a9803f";ctx.font="54px Georgia,serif";ctx.fillText("✦",375,397);ctx.fillStyle="#785a35";ctx.font="bold 18px Arial,sans-serif";ctx.fillText("SUA ILUSTRAÇÃO",375,447);ctx.font="13px Arial,sans-serif";ctx.fillText("adicione uma imagem para preencher este espaço",375,476);}ctx.restore();
      roundRect(ctx,76,198,598,463,14);ctx.lineWidth=8;ctx.strokeStyle="#d5a94d";ctx.stroke();
      ctx.fillStyle="#f1e4c9";ctx.fillRect(218,108,322,68);ctx.textAlign="center";ctx.textBaseline="middle";ctx.fillStyle="#3d281c";let nameSize=29;ctx.font=`bold ${nameSize}px Georgia,serif`;while(ctx.measureText(name.toLocaleUpperCase("pt-BR")).width>310&&nameSize>16){nameSize--;ctx.font=`bold ${nameSize}px Georgia,serif`;}ctx.fillText(name.toLocaleUpperCase("pt-BR"),379,135,310);ctx.fillStyle="#913d32";ctx.font="bold 12px Arial,sans-serif";ctx.fillText(`${base.type.toLocaleUpperCase("pt-BR")} · ${faction.toLocaleUpperCase("pt-BR")}`,379,165,305);
      for(const [cx,cy,r] of [[155,145,47],[595,145,47]]){ctx.beginPath();ctx.arc(cx,cy,r,0,Math.PI*2);ctx.fillStyle=style.color;ctx.fill();ctx.lineWidth=5;ctx.strokeStyle="#fff";ctx.stroke();}ctx.drawImage(icon,123,113,64,64);ctx.fillStyle="#fff";ctx.textAlign="center";ctx.textBaseline="middle";ctx.font="bold 49px Georgia,serif";ctx.fillText(String(power),595,139);ctx.font="bold 10px Arial,sans-serif";ctx.fillText("PODER",595,169);
      // Repaint the complete text panel so the old text baked into the base card cannot show through.
      roundRect(ctx,64,672,622,211,17);ctx.fillStyle="#281815";ctx.fill();ctx.lineWidth=4;ctx.strokeStyle="#d5a94d";ctx.stroke();ctx.textAlign="center";ctx.textBaseline="middle";ctx.fillStyle="#f1c65c";let titleSize=27;ctx.font=`bold ${titleSize}px Georgia,serif`;while(ctx.measureText(title.toLocaleUpperCase("pt-BR")).width>560&&titleSize>16){titleSize--;ctx.font=`bold ${titleSize}px Georgia,serif`;}ctx.fillText(title.toLocaleUpperCase("pt-BR"),375,710,560);ctx.beginPath();ctx.moveTo(97,738);ctx.lineTo(653,738);ctx.lineWidth=1.5;ctx.strokeStyle="#c59b4a";ctx.stroke();ctx.fillStyle="#f0e8d9";ctx.font="17px Arial,sans-serif";wrapCardText(ctx,ability,375,769,540,22,3);roundRect(ctx,222,833,306,36,18);ctx.fillStyle="#87342f";ctx.fill();ctx.lineWidth=2;ctx.strokeStyle="#d5a94d";ctx.stroke();ctx.fillStyle="#fff0d2";ctx.font="bold 13px Arial,sans-serif";ctx.fillText("HABILIDADE",375,851);
      ctx.fillStyle="#efe2c7";ctx.fillRect(145,932,460,46);ctx.fillStyle="#72502d";ctx.font="bold 13px Arial,sans-serif";ctx.fillText(`FACÇÃO ${faction.toLocaleUpperCase("pt-BR")}`,375,957);
    }catch(error){if(token===adminCardPreviewToken)$("#admin-card-status").textContent=error.message;}
  }
  async function downloadAdminCard(){
    const status=$("#admin-card-status"),button=$("#admin-card-download");if(!adminGuard())return;button.disabled=true;
    try{await drawAdminCardPreview();const canvas=$("#admin-card-preview"),blob=await new Promise((resolve,reject)=>canvas.toBlob(file=>file?resolve(file):reject(new Error("Não foi possível gerar o PNG.")),"image/png"));const url=URL.createObjectURL(blob),link=document.createElement("a"),name=cardEditorValue("#admin-card-name").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/^-|-$/g,"")||"nova-carta";link.href=url;link.download=`mythic-clash-${name}-1500x2100.png`;document.body.append(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);status.textContent="PNG em alta resolução baixado (1500 × 2100).";}catch(error){status.textContent=error.message||"Não foi possível baixar a carta.";}finally{button.disabled=false;}
  }
  function adminGuard(){if(!session||!adminAuthorized){notify("Acesso administrativo restrito.");return false;}return true;}
  async function openAdmin(){if(!adminGuard())return;await loadAdminDashboard();}
  async function loadSavedDecks(){if(!session)return false;const uid=session.user.id;const {data,error}=await supabase.from("player_saved_decks").select("*").eq("player_id",session.user.id).order("slot");if(error)return false;if(session?.user?.id!==uid)return false;if(data?.length){window.MythicLocalDeckSlots?.set(data.map(row=>({slot:row.slot,name:row.name,cards:row.card_counts,iconKey:row.icon_key,iconColor:row.icon_color})));return true;}return false;}
  let deckWriteQueue=Promise.resolve();
  function enqueueDeckWrite(action){const uid=session?.user?.id;const result=deckWriteQueue.catch(()=>{}).then(()=>{if(!uid||session?.user?.id!==uid)return false;return action(uid);});deckWriteQueue=result;return result;}
  function saveNamedDeck(index,name,cardCounts){if(!session)return Promise.resolve(false);return enqueueDeckWrite(async uid=>{const {error}=await supabase.from("player_saved_decks").upsert({player_id:uid,slot:index+1,name,card_counts:cardCounts,updated_at:new Date().toISOString()},{onConflict:"player_id,slot"});if(error)notify("Não foi possível salvar este deck na conta: "+displayError(error));return !error;});}
  async function saveDeckPersonalization(index,name,iconKey,iconColor){
    if(!session)throw Error('Entre na conta para personalizar.');
    return enqueueDeckWrite(async uid=>{const {data,error}=await supabase.rpc('personalize_deck',{p_slot:index+1,p_name:name,p_icon:iconKey,p_color:iconColor});
      if(error)throw Error(/PGRST202|42883/.test(String(error.code))?'A personalização ainda não está disponível no servidor. Avise a administração.':displayError(error));
      if(session?.user?.id!==uid)throw Error('A conta mudou.');return data;
    });
  }
  async function saveBuilderDeck(index,name,counts){
    if(!session)throw new Error("Entre na conta para salvar o baralho.");
    const saved=await enqueueDeckWrite(async uid=>{
      const {data,error}=await supabase.rpc("save_builder_deck",{p_slot:index+1,p_name:name,p_cards:counts});
      if(error)throw new Error(/PGRST202|42883/.test(String(error.code))?"Aplique os SQLs 015 a 017 no Supabase para salvar baralhos nos sete slots.":displayError(error));
      if(session?.user?.id!==uid)throw new Error("A conta mudou durante o salvamento.");return data;
    });
    if(!saved)throw new Error("Não foi possível salvar nesta conta.");return saved;
  }
  async function deleteBuilderDeck(index,activeIndex,decks){
    if(!session)throw new Error("Entre na conta para excluir o baralho.");
    const result=await enqueueDeckWrite(async uid=>{
      const {data,error}=await supabase.rpc("delete_builder_deck",{p_slot:index+1,p_active_slot:activeIndex+1,p_decks:decks});
      if(error)throw new Error(/PGRST202|42883/.test(String(error.code))?"Aplique o SQL 016 no Supabase para excluir baralhos.":displayError(error));
      if(session?.user?.id!==uid)throw new Error("A conta mudou durante a exclusão.");return data;
    });
    if(!result?.decks?.length||!Number.isInteger(result.activeSlot)||!result.decks[result.activeSlot])throw new Error("Não foi possível confirmar a exclusão do baralho.");
    return result;
  }

  async function loadCloudDeck(){
    if(!session)return;
    const uid=session.user.id;const {data,error}=await supabase.from("player_decks").select("card_counts").eq("player_id",session.user.id).maybeSingle();
    if(error){notify(displayError(error));return;}
    if(session?.user?.id!==uid)return;
    if(data?.card_counts)window.MythicLocalDeck?.set(data.card_counts);
    else saveDeckCounts(window.MythicLocalDeck?.get()||{});
  }

  function saveDeckCounts(cardCounts){
    if(!session||!cardCounts)return Promise.resolve(false);
    return enqueueDeckWrite(async uid=>{const {error}=await supabase.from("player_decks").upsert({player_id:uid,card_counts:cardCounts,updated_at:new Date().toISOString()},{onConflict:"player_id"});if(error)notify("Não foi possível sincronizar o baralho: "+displayError(error));return !error;});
  }

  let cachedFriends=[],friendPage=0,activeFriendActions=null,friendActionsPlaceholder=null;
  function closeFriendActions(){if(!activeFriendActions)return;activeFriendActions.hidden=true;activeFriendActions.classList.remove("friend-actions-floating");if(friendActionsPlaceholder?.parentNode)friendActionsPlaceholder.replaceWith(activeFriendActions);else activeFriendActions.remove();friendActionsPlaceholder=null;activeFriendActions=null;$("#friend-menu-scrim").hidden=true;}
  function toggleFriendActions(button){const card=button.closest(".friend-card"),actions=card?.querySelector(".friend-card-actions");if(!actions)return;if(actions===activeFriendActions){closeFriendActions();return;}closeFriendActions();friendActionsPlaceholder=document.createComment("friend actions");actions.before(friendActionsPlaceholder);activeFriendActions=actions;document.body.append(actions);actions.classList.add("friend-actions-floating");actions.hidden=false;$("#friend-menu-scrim").hidden=false;}
  let presenceTimer=null,presenceActivity=Date.now(),presenceStates=new Map(),presenceBusy=false,presenceUser=null,presenceStamp=0,presenceLast='';
  const presenceClient=crypto.randomUUID();
  function presenceLabel(id){const status=Date.now()-presenceStamp>90000?'offline':presenceStates.get(id)||'offline';return `<span class="friend-presence" data-status="${status}" data-presence-id="${escapeHTML(id)}"><i></i>${status==='online'?'Online':status==='away'?'Ausente':'Offline'}</span>`;}
  async function syncPresence(){if(!session||!supabase||presenceBusy)return;const uid=session.user.id;presenceBusy=true;const status=!navigator.onLine?'offline':document.hidden||Date.now()-presenceActivity>180000?'away':'online';presenceLast=status;
   try{await supabase.rpc('touch_player_presence',{p_client_id:presenceClient,p_status:status});const {data,error}=await supabase.rpc('get_friend_presence');if(uid!==session?.user?.id)return;if(!error){presenceStates=new Map((data||[]).map(row=>[row.friend_id,['online','away'].includes(row.status)?row.status:'offline']));presenceStamp=Date.now();}document.querySelectorAll('[data-presence-id]').forEach(node=>{const holder=document.createElement('span');holder.innerHTML=presenceLabel(node.dataset.presenceId);node.replaceWith(holder.firstElementChild);});window.dispatchEvent(new CustomEvent("mythic-lobby-friends"));}catch{}finally{presenceBusy=false;}}
  function startPresence(){if(presenceUser===session?.user?.id&&presenceTimer)return;clearInterval(presenceTimer);presenceUser=session?.user?.id;presenceStates.clear();presenceStamp=0;presenceActivity=Date.now();presenceLast='';syncPresence();presenceTimer=setInterval(syncPresence,30000);}
  function stopPresence(){clearInterval(presenceTimer);presenceTimer=null;presenceUser=null;presenceStates.clear();presenceStamp=0;}
  for(const type of ['pointerdown','keydown','pointermove'])document.addEventListener(type,()=>{presenceActivity=Date.now();if(session&&presenceLast==='away'&&!document.hidden)syncPresence();},{passive:true});
  document.addEventListener('visibilitychange',()=>{if(session)syncPresence();});window.addEventListener('online',syncPresence);window.addEventListener('offline',syncPresence);
  window.addEventListener('pagehide',()=>{if(session)supabase.rpc('touch_player_presence',{p_client_id:presenceClient,p_status:'offline'}).then(()=>{}).catch(()=>{});});
  function renderFriendLists(){
    const accepted=cachedFriends.filter(friend=>friend.request_status==="accepted"),pending=cachedFriends.filter(friend=>friend.request_status==="pending");
    const pageCount=Math.max(1,Math.ceil(accepted.length/5));friendPage=Math.min(friendPage,pageCount-1);
    const visible=accepted.slice(friendPage*5,friendPage*5+5);
    $("#friends-page-label").textContent=accepted.length?`${friendPage*5+1}–${Math.min((friendPage+1)*5,accepted.length)} de ${accepted.length}`:"Nenhum amigo";
    $("#friends-page-next").hidden=accepted.length<=5;$("#friends-page-next").textContent=friendPage>=pageCount-1?"‹":"›";$("#friends-page-next").setAttribute("aria-label",friendPage>=pageCount-1?"Voltar aos amigos anteriores":"Mostrar mais amigos");
    $("#friends-list").innerHTML=visible.map(friend=>`<article class="friend-list-card friend-card"><button type="button" class="friend-select" data-select-friend="${escapeHTML(friend.friendship_id)}"><span class="friend-avatar">${resolveAvatarAsset(friend.equipped_avatar)?`<img src="${escapeHTML(resolveAvatarAsset(friend.equipped_avatar))}" alt="Ícone de ${escapeHTML(friend.display_name)}" decoding="async">`:escapeHTML(friend.display_name.slice(0,1).toUpperCase())}</span><span class="friend-card-identity"><b>${escapeHTML(friend.display_name)}</b><small>${escapeHTML(rankForRating(friend.rating_points||1000))}</small>${presenceLabel(friend.friend_id)}</span><img class="friend-rank-emblem" src="${escapeHTML(rankEmblem(friend.rating_points||1000))}" alt="Rank ${escapeHTML(rankForRating(friend.rating_points||1000))}"></button><div class="friend-card-actions" data-friend-actions="${escapeHTML(friend.friendship_id)}" hidden><button type="button" class="button button-primary" data-challenge-friend-code="${escapeHTML(friend.friend_code)}" data-challenge-friend-name="${escapeHTML(friend.display_name)}">Convidar</button><button type="button" class="button button-secondary" data-watch-friend-name="${escapeHTML(friend.display_name)}">Assistir</button><button type="button" class="button button-secondary" data-chat-id="${escapeHTML(friend.friendship_id)}" data-friend-id="${escapeHTML(friend.friend_id)}" data-friend-name="${escapeHTML(friend.display_name)}">Conversar</button><button type="button" class="button button-secondary" data-friend-profile="${escapeHTML(friend.friend_id)}">Ver perfil</button></div><output class="friend-challenge-result" aria-live="polite"></output></article>`).join("")||'<p class="empty-state">Nenhum amigo ainda. Use “Solicitar amigo” para encontrar alguém.</p>';
    $("#friend-pending-count").textContent=String(pending.length);$("#friend-pending-count").hidden=!pending.length;
    $("#friend-pending-list").innerHTML=pending.map(friend=>friend.incoming?`<article class="friend-list-card"><span class="friend-avatar">${escapeHTML(friend.display_name.slice(0,1).toUpperCase())}</span><span><b>${escapeHTML(friend.display_name)}</b><small>Quer adicionar você · ${escapeHTML(friend.friend_code)}</small></span><button class="button button-primary" data-accept-friend="${escapeHTML(friend.friendship_id)}">Aceitar</button></article>`:`<article class="friend-list-card"><span class="friend-avatar">${escapeHTML(friend.display_name.slice(0,1).toUpperCase())}</span><span><b>${escapeHTML(friend.display_name)}</b><small>Pedido enviado · ${escapeHTML(friend.friend_code)}</small></span><i>PENDENTE</i></article>`).join("")||'<p class="empty-state">Nenhum pedido pendente.</p>';
  }
  async function loadFriends(){
    if(!session)return;const uid=session.user.id;
    let {data,error}=await supabase.rpc("list_my_friends_with_icons");
    if(error&&/PGRST202|42883/.test(String(error.code)))({data,error}=await supabase.rpc("list_my_friends"));
    if(uid!==session?.user?.id)return;
    if(error){$("#friends-list").innerHTML=`<p class="empty-state">${escapeHTML(displayError(error))}</p>`;return;}
    cachedFriends=data||[];const accepted=cachedFriends.filter(friend=>friend.request_status==="accepted"),giftSelect=$("#gift-friend-select"),cardGiftSelect=$("#gift-card-friend-select");
    if(giftSelect)giftSelect.innerHTML='<option value="">Escolha um amigo</option>'+accepted.map(friend=>`<option value="${escapeHTML(friend.friend_id)}">${escapeHTML(friend.display_name)}</option>`).join("");if(cardGiftSelect)cardGiftSelect.innerHTML='<option value="">Escolha um amigo</option>'+accepted.map(friend=>`<option value="${escapeHTML(friend.friend_id)}">${escapeHTML(friend.display_name)}</option>`).join("");
    if(accepted.length){const ids=accepted.map(friend=>friend.friendship_id),[messages,matches]=await Promise.all([supabase.from("friend_messages").select("friendship_id,sender_id,created_at").in("friendship_id",ids).order("created_at",{ascending:false}).limit(500),supabase.from("match_history").select("opponent_name,completed_at").eq("player_id",session.user.id).order("completed_at",{ascending:false}).limit(300)]);const activity=new Map();for(const f of accepted)activity.set(f.friendship_id,{count:0,last:0});for(const m of messages.data||[]){const stats=activity.get(m.friendship_id);if(stats){stats.count++;stats.last=Math.max(stats.last,Date.parse(m.created_at)||0);}}for(const match of matches.data||[]){const f=accepted.find(item=>item.display_name.toLocaleLowerCase()===String(match.opponent_name||"").toLocaleLowerCase());if(f){const stats=activity.get(f.friendship_id);stats.count+=2;stats.last=Math.max(stats.last,Date.parse(match.completed_at)||0);}}accepted.sort((a,b)=>{const x=activity.get(a.friendship_id),y=activity.get(b.friendship_id);return y.count-x.count||y.last-x.last;});}
    if(uid!==session?.user?.id)return;renderFriendLists();loadGiftInbox();window.dispatchEvent(new CustomEvent("mythic-lobby-friends"));
  }

  async function loadGiftInbox(){if(!session)return;const uid=session.user.id;const [coins,cards]=await Promise.all([supabase.from("friend_gifts").select("id,sender_id,coins,note,created_at").eq("receiver_id",uid).is("claimed_at",null).order("created_at",{ascending:false}).limit(10),supabase.from("friend_card_gifts").select("id,sender_id,card_id,created_at").eq("receiver_id",uid).is("claimed_at",null).order("created_at",{ascending:false}).limit(10)]),box=$("#friend-gift-inbox");if(!box||uid!==session?.user?.id)return;if(coins.error){box.innerHTML='<small>PRESENTES RECEBIDOS</small><p>Atualize a migração de presentes para usar este recurso.</p>';return;}const cardNames={"soldado-esparta":"Soldado de Esparta",athena:"Atena, Guardiã","lobo-alfa":"Lobisomem Alfa","guardiao-nordico":"Guardião Nórdico",medusa:"Medusa",poseidon:"Poseidon",zeus:"Zeus",hades:"Hades"},coinRows=(coins.data||[]).map(gift=>`<article class="community-row"><span><b>${gift.coins} MC · de ${escapeHTML(gift.sender_id.slice(0,8))}</b><small>${escapeHTML(gift.note||"Um presente Mythic para você.")}</small></span><button class="button button-primary" data-claim-friend-gift="${gift.id}">Resgatar</button></article>`),cardRows=(cards.data||[]).map(gift=>`<article class="community-row"><span><b>${escapeHTML(profileCardNames[gift.card_id]||cardNames[gift.card_id]||gift.card_id)}</b><small>Carta de ${escapeHTML(gift.sender_id.slice(0,8))}</small></span><button class="button button-primary" data-claim-friend-card-gift="${gift.id}">Resgatar carta</button></article>`);box.innerHTML='<small>PRESENTES RECEBIDOS</small>'+(coinRows.concat(cardRows).join("")||'<p>Nenhum presente aguardando.</p>');}

  function showIncomingFriendInvite(code){if(!code)return;pendingFriendInviteCode=code;$("#friend-challenge-inbox-copy").textContent="Um amigo desafiou você. Aceite para entrar na partida X1.";$("#friend-challenge-inbox").hidden=false;notify("Você recebeu um desafio de um amigo.");}
  async function loadIncomingFriendInvite(){if(!session)return;const uid=session.user.id;const {data,error}=await supabase.from("game_invites").select("code,created_at").eq("invited_user_id",uid).eq("status","waiting").gt("expires_at",new Date().toISOString()).order("created_at",{ascending:false}).limit(1);if(uid===session?.user?.id&&!error&&data?.[0])showIncomingFriendInvite(data[0].code);}
  function openInviteFlow(friendId=null,context="friend"){if(!requireLogin())return;if(context==="room"){window.MythicCustomLobby?.openFriends();return;}if(context==="queue"){window.dispatchEvent(new CustomEvent("mythic-lobby-picker"));return;}closeFriendActions();const friends=cachedFriends.filter(friend=>friend.request_status==="accepted");$("#invite-flow-friend").innerHTML=friends.map(friend=>`<option value="${escapeHTML(friend.friend_id)}">${escapeHTML(friend.display_name)}</option>`).join("");$("#invite-flow-status").textContent=friends.length?"":"Adicione um amigo para enviar convites.";$("#invite-flow-friend").disabled=!friends.length;if(friendId&&friends.some(friend=>friend.friend_id===friendId))$("#invite-flow-friend").value=friendId;$("#invite-flow-title").textContent=context==="room"?"Convide para sua sala":context==="queue"?"Forme sua dupla":"Escolha como jogar";const roomContext=context==="room",queueContext=context==="queue";document.querySelector('[data-invite-action="x1"]').hidden=roomContext||queueContext;document.querySelectorAll('[data-invite-action^="duo-"]').forEach(button=>button.hidden=roomContext);$("#invite-room-action").hidden=!(customRoomId&&customRoomInviteCode&&(context==="friend"||roomContext));document.querySelectorAll("[data-invite-action]").forEach(button=>button.disabled=!friends.length);$("#invite-flow-backdrop").hidden=false;}
  let directInviteBusy=false;
  async function createDirectInvite(friendCode=null){
    if(!requireLogin())throw Error('Entre na conta para desafiar um amigo.');
    if(directInviteBusy)throw Error('Aguarde o envio do convite.');
    if(window.MythicDeckEditor?.isSelecting?.()||window.MythicDeckBuilder?.isOpen?.())throw Error('Conclua a seleção e o salvamento do baralho.');
    if(floatingQueueState.active||activeMatchId)throw Error('Saia da fila ou da partida antes de desafiar.');
    directInviteBusy=true;const uid=session.user.id;
    try{const {data,error}=await supabase.rpc('create_game_invite',{p_mode:'friend',p_invited_friend_code:friendCode});if(error)throw Error(displayError(error));if(session?.user?.id!==uid)throw Error('A conta mudou.');const invite=Array.isArray(data)?data[0]:data;window.dispatchEvent(new CustomEvent('mythic-direct-created',{detail:{code:invite?.invite_code,friendCode}}));return invite;}
    finally{directInviteBusy=false;}
  }
  async function sendInviteAction(action){if(!requireLogin())return;const friend=cachedFriends.find(item=>item.friend_id===$("#invite-flow-friend").value&&item.request_status==="accepted");if(!friend){$("#invite-flow-status").textContent="Escolha um amigo da sua lista.";return;}const status=$("#invite-flow-status");status.textContent="Enviando convite…";document.querySelectorAll("[data-invite-action]").forEach(button=>button.disabled=true);
    if(action==="x1"){try{await createDirectInvite(friend.friend_code);status.textContent=`Desafio X1 enviado para ${friend.display_name}.`;$('#invite-flow-backdrop').hidden=true;window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:'direct'}}));}catch(error){status.textContent=error.message;}}
    else if(action==="duo-normal"||action==="duo-ranked"){
      openQueueLobby(action==="duo-ranked"?"ranked":"normal");
      window.dispatchEvent(new CustomEvent("mythic-open-view",{detail:{view:"queue"}}));
      $("#invite-flow-backdrop").hidden=true;
      const result=await startDuoQueue(window.queueGameMode,friend.friend_code);
      if(result?.error)notify(result.error);
    }
    else if(action==="room"){if(!customRoomId||!customRoomInviteCode){status.textContent="Crie uma sala personalizada antes de convidar.";}else{const {error}=await supabase.from("friend_messages").insert({friendship_id:friend.friendship_id,sender_id:session.user.id,body:`__MYTHIC_SANDBOX_INVITE__:${customRoomInviteCode}`});if(error)status.textContent=displayError(error);else{status.textContent=`Convite da sala enviado para ${friend.display_name}.`;notify(`Convite da sala enviado para ${friend.display_name}.`);}}}
    document.querySelectorAll("[data-invite-action]").forEach(button=>button.disabled=false);
  }
  async function challengeFriend(button){const friend=cachedFriends.find(item=>item.friend_code===button.dataset.challengeFriendCode);openInviteFlow(friend?.friend_id||null,"friend");}
  async function joinSandboxInvite(code){window.MythicCustomLobby?.choose(code);}
  async function acceptFriendInvite(){if(!requireLogin()||!pendingFriendInviteCode)return;if(window.MythicDeckEditor?.isSelecting?.()||window.MythicDeckBuilder?.isOpen?.()){notify("Conclua a seleção do seu baralho antes de aceitar.");return;}const button=$("#accept-friend-challenge"),code=pendingFriendInviteCode;button.disabled=true;const {data,error}=await supabase.rpc("join_game_invite",{p_code:code}),match=Array.isArray(data)?data[0]:data;if(error){notify(displayError(error));button.disabled=false;await loadIncomingFriendInvite();return;}pendingFriendInviteCode=null;if($("#friend-challenge-inbox"))$("#friend-challenge-inbox").hidden=true;button.disabled=false;if(match?.match_id)loadOnlineMatch(match.match_id);}

  async function searchFriend(code){
    if(!requireLogin())return;
    const result=$("#friend-search-result");result.textContent="Procurando jogador…";
    const {data,error}=await supabase.rpc("find_player_by_friend_code",{p_code:code});
    if(error){result.textContent=displayError(error);return;}
    const found=data?.[0];if(!found){result.textContent="Nenhum jogador encontrado com esse código.";return;}
    if(found.id===session.user.id){result.textContent="Esse é o seu próprio código.";return;}
    result.innerHTML=`<span><img class="friend-rank-emblem" src="${escapeHTML(rankEmblem(found.rating_points||1000))}" alt="">${escapeHTML(found.display_name)} · ${escapeHTML(rankForRating(found.rating_points||1000))} · ${escapeHTML(window.MythicRank.label(found.rating_points))}</span> <button type="button" class="button button-secondary" data-add-friend="${escapeHTML(found.friend_code)}">Enviar pedido</button>`;
  }

  async function openChat(friendshipId,friendId,friendName){
    if(!requireLogin())return;const uid=session.user.id;
    if(messageChannel)supabase.removeChannel(messageChannel);
    activeFriend={friendshipId,friendId,friendName};const thread=activeFriend;$("#friend-chat-window").hidden=false;$("#chat-friend-name").textContent=friendName;$("#watch-selected-friend").hidden=false;$("#watch-selected-friend").dataset.friendName=friendName;
    $("#friend-message-input").disabled=false;$("#friend-message-form button").disabled=false;$("#friend-messages").innerHTML="";
    const {data,error}=await supabase.from("friend_messages").select("id,sender_id,body,created_at").eq("friendship_id",friendshipId).order("created_at",{ascending:false}).limit(100);
    if(uid!==session?.user?.id||activeFriend!==thread)return;
    if(error){$("#friend-messages").innerHTML=`<p class="empty-state">${escapeHTML(displayError(error))}</p>`;return;}
    (data||[]).reverse().forEach(renderMessage);
    messageChannel=supabase.channel(`chat-${friendshipId}`).on("postgres_changes",{event:"INSERT",schema:"public",table:"friend_messages",filter:`friendship_id=eq.${friendshipId}`},payload=>{if(uid===session?.user?.id&&activeFriend===thread)renderMessage(payload.new);}).subscribe();
  }

  function renderMessage(message){
    const list=$("#friend-messages");if(message.id&&list.querySelector(`[data-message-id="${CSS.escape(message.id)}"]`))return;if(list.querySelector(".empty-state"))list.innerHTML="";
    const item=document.createElement("article");if(message.id)item.dataset.messageId=message.id;item.className="friend-message"+(message.sender_id===session?.user.id?" own":"");
    const body=document.createElement("p"),roomInvite=String(message.body||"").match(/^__MYTHIC_SANDBOX_INVITE__:([A-Z0-9]{6,8})$/);body.textContent=roomInvite?"Convite para uma sala personalizada":"";if(roomInvite){const join=document.createElement("button");join.type="button";join.className="button button-secondary";join.dataset.joinSandboxInvite=roomInvite[1];join.textContent=`Entrar na sala · ${roomInvite[1]}`;item.append(body,join);}else{body.textContent=message.body;item.append(body);}const time=document.createElement("small");time.textContent=new Date(message.created_at).toLocaleTimeString("pt-BR",{hour:"2-digit",minute:"2-digit"});item.append(time);list.append(item);while(list.children.length>200)list.firstElementChild.remove();list.scrollTop=list.scrollHeight;
  }

  function listenForInvites(){
    if(inviteChannel)supabase.removeChannel(inviteChannel);
    inviteChannel=supabase.channel(`invites-${session.user.id}`).on("postgres_changes",{event:"UPDATE",schema:"public",table:"game_invites",filter:`host_id=eq.${session.user.id}`},payload=>{if(payload.new.status==="accepted"&&payload.new.match_id){notify("Seu desafio foi aceito. Abrindo a partida…");loadOnlineMatch(payload.new.match_id);}}).on("postgres_changes",{event:"INSERT",schema:"public",table:"game_invites",filter:`invited_user_id=eq.${session.user.id}`},payload=>{if(payload.new.status==="waiting")showIncomingFriendInvite(payload.new.code);}).on("postgres_changes",{event:"UPDATE",schema:"public",table:"game_invites",filter:`invited_user_id=eq.${session.user.id}`},payload=>{if(payload.new.code===pendingFriendInviteCode&&payload.new.status!=="waiting"){pendingFriendInviteCode=null;$('#friend-challenge-inbox').hidden=true;}}).subscribe();
    listenForDuoQueue();
  }

  async function pollDuoQueue(){
    if(!session||!activeDuoPartyId)return;
    const uid=session.user.id,partyId=activeDuoPartyId;
    const {data,error}=await supabase.rpc("try_match_duo_queue",{p_party_id:partyId});
    if(session?.user?.id!==uid||activeDuoPartyId!==partyId||error)return;
    const result=typeof data==='string'?JSON.parse(data):data;
    if(result?.status==='matched'&&result.match_id){activeDuoPartyId=null;clearInterval(duoQueueTicker);duoQueueTicker=null;if(activeMatchId!==result.match_id)loadOnlineMatch(result.match_id);}
    else if(result?.status==='cancelled'){activeDuoPartyId=null;clearInterval(duoQueueTicker);duoQueueTicker=null;setQueueState(null);$("#queue-status").hidden=true;}
  }

  function startDuoQueuePolling(){if(duoQueueTicker)return;pollDuoQueue();duoQueueTicker=setInterval(pollDuoQueue,5000);}
  function touchMatchSession(){
    if(!session||!supabase||(!activeMatchId&&!(floatingQueueState.active&&floatingQueueState.format==='solo'&&floatingQueueState.phase==='queued')))return;
    supabase.rpc('touch_match_session',{p_match_id:activeMatchId,p_queue:Boolean(floatingQueueState.active&&floatingQueueState.format==='solo'&&floatingQueueState.phase==='queued')}).then(()=>{}).catch(()=>{});
  }
  function keepMatchSession(){if(!matchSessionTimer)matchSessionTimer=setInterval(touchMatchSession,20000);touchMatchSession();}
  function emitLobby(){window.dispatchEvent(new CustomEvent('mythic-lobby-state',{detail:{party:lobbyParty,busy:lobbyBusy,userId:session?.user?.id||null}}));}
  function lobbyFriends(){return cachedFriends.filter(f=>f.request_status==='accepted').map(f=>({...f,presence:Date.now()-presenceStamp>90000?'offline':presenceStates.get(f.friend_id)||'offline'}));}
  async function refreshLobby(){
    if(!session)return;const uid=session.user.id,epoch=++lobbyEpoch;
    const {data,error}=await supabase.rpc('get_duo_lobby');
    if(uid!==session?.user?.id||epoch!==lobbyEpoch)return;
    if(error)return;
    lobbyParty=data||null;
    if(lobbyParty&&lobbyParty.status!=='matched'){window.queueGameMode=lobbyParty.mode;$("#queue-heading").textContent=lobbyParty.mode==='ranked'?'Convergência ranqueada':'Convergência normal';}
    pendingDuoPartyId=lobbyParty?.status==='inviting'&&lobbyParty.partner_id===uid?lobbyParty.id:null;
    pendingDuoMode=lobbyParty?.mode||null;
    activeDuoPartyId=lobbyParty&&(lobbyParty.status!=='inviting'||lobbyParty.host_id===uid)?lobbyParty.id:null;
    if(lobbyParty?.status==='queued'){
      setQueueState({format:'duo',mode:lobbyParty.mode,phase:'queued',partyId:lobbyParty.id});
      startDuoQueuePolling();
    }else{
      clearInterval(duoQueueTicker);duoQueueTicker=null;
      if(floatingQueueState.format==='duo'&&!lobbyBusy)setQueueState(null);
    }
    emitLobby();
    if(lobbyParty?.status==='matched'&&lobbyParty.match_id&&activeMatchId!==lobbyParty.match_id)loadOnlineMatch(lobbyParty.match_id);
  }
  function openQueueLobby(mode){
    window.queueGameMode=lobbyParty?.mode||(['normal','ranked'].includes(mode)?mode:'normal');
    $("#queue-heading").textContent=window.queueGameMode==='ranked'?'Convergência ranqueada':'Convergência normal';
    $("#queue-setup-status").textContent='';emitLobby();if(session)refreshLobby();
  }
  function listenForDuoQueue(){
    if(duoQueueChannel)supabase.removeChannel(duoQueueChannel);
    clearInterval(lobbyTicker);clearInterval(duoQueueTicker);duoQueueTicker=null;
    if(!session)return;const uid=session.user.id;
    const update=()=>{if(session?.user?.id===uid)refreshLobby();};
    duoQueueChannel=supabase.channel('lobby-'+uid)
      .on('postgres_changes',{event:'*',schema:'public',table:'duo_queue_parties',filter:'host_id=eq.'+uid},update)
      .on('postgres_changes',{event:'*',schema:'public',table:'duo_queue_parties',filter:'partner_id=eq.'+uid},update)
      .subscribe(status=>{if(status==='SUBSCRIBED')update();});
    update();lobbyTicker=setInterval(()=>{if(!document.hidden)update();},5000);
  }

  async function loadOnlineMatch(matchId){
    if(!session||!matchId)return;const uid=session.user.id;
    clearInterval(matchFallbackTicker);lastMatchSnapshot="";forceNextMatchRender=false;actionSequence++;actionPending=false;
    setQueueState(null);queueRequest++;clearInterval(queueTicker);queueTicker=null;clearInterval(duoQueueTicker);duoQueueTicker=null;lobbyParty=null;emitLobby();activeMatchId=matchId;$("#queue-status").hidden=true;
    const {data,error}=await supabase.rpc("get_online_match",{p_match_id:matchId});
    if(session?.user?.id!==uid||activeMatchId!==matchId)return;
    if(error){notify("Não foi possível abrir a partida: "+displayError(error));activeMatchId=null;return;}
    const match=data?.match;if(!match){notify("Partida não encontrada para esta conta.");activeMatchId=null;return;}keepMatchSession();
    if(gameChannel)supabase.removeChannel(gameChannel);
    gameChannel=supabase.channel(`game-${matchId}`).on("postgres_changes",{event:"UPDATE",schema:"public",table:"match_update_signals",filter:`match_id=eq.${matchId}`},()=>refreshOnlineMatch(matchId).catch(()=>{})).subscribe();
    matchFallbackTicker=setInterval(()=>{if(!document.hidden&&activeMatchId===matchId)refreshOnlineMatch(matchId).catch(()=>{});},8000);
    lastMatchSnapshot=JSON.stringify(data);
    window.dispatchEvent(new CustomEvent("mythic-online-match",{detail:{match,userId:session.user.id,playerName:profile?.nickname||profile?.display_name||"Você",playerIcon:profile?.equipped_avatar||"default",playerRating:profile?.rating_points||1000,opponentName:data.opponent_name,teammateName:data.teammate_name||null,participants:data.participants||[],myTeam:data.my_team||null,mySeat:data.my_seat||1,teamSize:data.team_size||1,opponentIcon:data.opponent_icon||"default",opponentRating:data.opponent_rating||1000}}));
  }

  function refreshOnlineMatch(matchId){
    if(!session||!matchId||activeMatchId!==matchId)return Promise.resolve();
    const key=session.user.id+":"+matchId;if(matchRefreshes.has(key))return matchRefreshes.get(key);
    const task=fetchOnlineMatch(matchId).finally(()=>{if(matchRefreshes.get(key)===task)matchRefreshes.delete(key);});matchRefreshes.set(key,task);return task;
  }
  async function fetchOnlineMatch(matchId){
    if(!session||activeMatchId!==matchId)return;const uid=session.user.id;
    const {data,error}=await supabase.rpc("get_online_match",{p_match_id:matchId});
    if(uid!==session?.user?.id||activeMatchId!==matchId)return;
    const snapshot=JSON.stringify(data);if(error||!data?.match||snapshot===lastMatchSnapshot&&!forceNextMatchRender)return;forceNextMatchRender=false;lastMatchSnapshot=snapshot;
    if(!error&&data?.match)window.dispatchEvent(new CustomEvent("mythic-online-match",{detail:{match:data.match,userId:session.user.id,playerName:profile?.nickname||profile?.display_name||"Você",playerIcon:profile?.equipped_avatar||"default",playerRating:profile?.rating_points||1000,opponentName:data.opponent_name,teammateName:data.teammate_name||null,participants:data.participants||[],myTeam:data.my_team||null,mySeat:data.my_seat||1,teamSize:data.team_size||1,opponentIcon:data.opponent_icon||"default",opponentRating:data.opponent_rating||1000}}));
  }

  async function submitAction(action){
    if(!session||!activeMatchId||actionPending)return;
    const uid=session.user.id,matchId=activeMatchId,actionId=++actionSequence,wasDisabled=$("#end-turn").disabled;actionPending=true;$("#end-turn").disabled=true;
    try{const wireAction={...action,request_id:action.request_id||crypto.randomUUID()};const {data,error}=await supabase.rpc("submit_game_action",{p_match_id:matchId,p_action:wireAction});if(uid!==session?.user?.id||activeMatchId!==matchId)return;const result=Array.isArray(data)?data[0]:data;if(error)notify(displayError(error));else if(result?.state?._securityError)notify(result.state._securityError.message||"Ação rejeitada pelo servidor.");}
    catch(error){if(uid===session?.user?.id&&activeMatchId===matchId)notify(displayError(error));}
    finally{if(actionId===actionSequence){if(uid===session?.user?.id&&activeMatchId===matchId){const prior=lastMatchSnapshot;forceNextMatchRender=true;await refreshOnlineMatch(matchId).catch(()=>{});if(actionId===actionSequence&&prior===lastMatchSnapshot)$("#end-turn").disabled=wasDisabled;}if(actionId===actionSequence)actionPending=false;}}
  }

  async function expireTurn(){if(!session||!activeMatchId)return;const {error}=await supabase.rpc("expire_game_turns");if(error)notify(displayError(error));else await refreshOnlineMatch(activeMatchId);}

  function leaveMatch(){clearInterval(matchFallbackTicker);matchFallbackTicker=null;lastMatchSnapshot="";matchRefreshes.clear();actionSequence++;if(gameChannel)supabase.removeChannel(gameChannel);gameChannel=null;activeMatchId=null;actionPending=false;}

  document.addEventListener("visibilitychange",()=>{if(!document.hidden&&activeMatchId)refreshOnlineMatch(activeMatchId).catch(()=>{});});

  async function startQueue(mode){
    if(!requireLogin()||floatingQueueState.active)return;if(window.MythicDeckEditor?.isSelecting?.()){notify("Aguarde o salvamento do baralho antes de entrar na fila.");return;}
    const uid=session.user.id,request=++queueRequest;
    $("#queue-setup-status").textContent='';
    setQueueState({format:'solo',mode,phase:'joining'});
    $("#queue-status").hidden=false;
    $("#queue-status-text").textContent="Entrando na fila…";
    try{
      const {data,error}=await supabase.rpc("join_matchmaking",{p_mode:mode});
      if(session?.user?.id!==uid||request!==queueRequest)return;
      if(error)throw error;
      const entry=Array.isArray(data)?data[0]:data;
      if(entry?.queue_status==='matched'){
        $("#queue-status-text").textContent="Oponente encontrado. Abrindo a partida…";
        notify("Partida encontrada. Abrindo a arena…");loadOnlineMatch(entry.match_id);return;
      }
      if(entry?.queue_status!=='waiting')throw Error('Não foi possível confirmar a entrada na fila.');
      setQueueState({format:'solo',mode,phase:'queued'});keepMatchSession();
      clearInterval(queueTicker);
      const tick=()=>{const seconds=Math.max(0,Math.floor((Date.now()-floatingQueueState.startedAt)/1000));$("#queue-status-text").textContent=(mode==='ranked'?"Procurando adversário da sua faixa":"Procurando jogador")+` · ${String(Math.floor(seconds/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')}`;};
      tick();queueTicker=setInterval(tick,1000);
      if(queueChannel)supabase.removeChannel(queueChannel);
      const check=row=>{if(session?.user?.id!==uid||request!==queueRequest)return;if(row?.status==='matched'&&row.match_id){notify("Partida encontrada. Abrindo a arena…");loadOnlineMatch(row.match_id);}else if(row?.status==='cancelled'){clearInterval(queueTicker);queueTicker=null;setQueueState(null);$("#queue-status").hidden=true;}};
      queueChannel=supabase.channel(`queue-${uid}`).on("postgres_changes",{event:"UPDATE",schema:"public",table:"matchmaking_queue",filter:`user_id=eq.${uid}`},payload=>check(payload.new)).subscribe(status=>{
        if(status==='SUBSCRIBED')supabase.from('matchmaking_queue').select('status,match_id').eq('user_id',uid).maybeSingle().then(({data})=>check(data));
      });
    }catch(error){if(session?.user?.id!==uid||request!==queueRequest)return;clearInterval(queueTicker);queueTicker=null;setQueueState(null);$("#queue-status-text").textContent=displayError(error);$("#queue-setup-status").textContent=displayError(error);}
  }

  async function startDuoQueue(mode,partnerCode){
    if(!requireLogin())return{error:'Entre na sua conta para convidar.'};
    if(lobbyBusy||floatingQueueState.active||lobbyParty)return{error:'Saia da sala ou fila atual antes de enviar outro convite.'};
    const uid=session.user.id;lobbyBusy=true;emitLobby();
    try{
      const capability=await supabase.rpc('get_duo_lobby');
      if(uid!==session?.user?.id)return{error:'A conta foi alterada.'};
      if(capability.error)throw capability.error;
      if(capability.data){await refreshLobby();return{error:'Você já tem uma sala ou convite em andamento.'};}
      const refreshed=await supabase.rpc('refresh_invite_sessions',{p_friend_code:partnerCode});
      if(uid!==session?.user?.id)return{error:'A conta foi alterada.'};
      if(refreshed.error)throw refreshed.error;
      const {data,error}=await supabase.rpc('create_duo_queue',{p_mode:mode,p_partner_code:partnerCode});
      if(uid!==session?.user?.id)return{error:'A conta foi alterada.'};
      if(error)throw error;
      const row=Array.isArray(data)?data[0]:data;
      if(!row?.party_id)throw Error('Não foi possível confirmar o convite.');
      await refreshLobby();return{partyId:row.party_id,partnerName:row.partner_name};
    }catch(error){
      let recovery=null;try{const d=JSON.parse(error?.details||'null');if(d?.kind==='self_queue')recovery={kind:'self_queue'};else if(d?.kind==='self_match'&&/^[0-9a-f-]{36}$/i.test(d.match_id||''))recovery={kind:'self_match',matchId:d.match_id};}catch{}
      return{error:displayError(error),recovery};
    }
    finally{if(uid===session?.user?.id){lobbyBusy=false;emitLobby();}}
  }
  async function respondDuoInvite(accept){
    if(!requireLogin()||!pendingDuoPartyId||lobbyBusy)return{error:'Convite indisponível.'};
    const id=pendingDuoPartyId,uid=session.user.id;lobbyBusy=true;emitLobby();
    try{
      const {data,error}=await supabase.rpc('respond_duo_queue_invite',{p_party_id:id,p_accept:accept});
      if(uid!==session?.user?.id)return{error:'A conta foi alterada.'};if(error)throw error;
      pendingDuoPartyId=null;await refreshLobby();
      if(accept&&data?.status==='ready'){
        openQueueLobby(lobbyParty?.mode);window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:'queue'}}));
      }
      return data;
    }catch(error){return{error:displayError(error)};}
    finally{if(uid===session?.user?.id){lobbyBusy=false;emitLobby();}}
  }
  async function convergeLobby(){
    if(!requireLogin()||lobbyBusy||floatingQueueState.active)return;if(window.MythicDeckEditor?.isSelecting?.()){notify("Aguarde o salvamento do baralho antes de convergir.");return;}
    if(!lobbyParty){await startQueue(window.queueGameMode||'normal');return;}
    if(lobbyParty.host_id!==session.user.id||lobbyParty.status!=='ready')return;
    const uid=session.user.id;lobbyBusy=true;emitLobby();
    setQueueState({format:'duo',mode:lobbyParty.mode,phase:'joining',partyId:lobbyParty.id});
    try{
      const {data,error}=await supabase.rpc('start_duo_lobby_queue',{p_party_id:lobbyParty.id});
      if(uid!==session?.user?.id)return;if(error)throw error;
      if(data?.status==='matched'&&data.match_id)await loadOnlineMatch(data.match_id);
      else await refreshLobby();
    }catch(error){if(uid===session?.user?.id){setQueueState(null);notify(displayError(error));}}
    finally{if(uid===session?.user?.id){lobbyBusy=false;emitLobby();}}
  }
  async function leaveLobby(){
    if(!session||lobbyBusy)return{error:'Aguarde a ação atual terminar.'};
    if(floatingQueueState.active)return{error:'Cancele a busca antes de sair da sala.'};
    const uid=session.user.id;lobbyBusy=true;emitLobby();
    try{const {error}=await supabase.rpc('leave_duo_lobby');if(uid!==session?.user?.id)return;if(error)throw error;await refreshLobby();return{status:'left'};}
    catch(error){return{error:displayError(error)};}
    finally{if(uid===session?.user?.id){lobbyBusy=false;emitLobby();}}
  }

  async function cancelQueue(){
    if(!session||queueCancelling||floatingQueueState.phase==='joining')return false;
    const uid=session.user.id,partyId=activeDuoPartyId||floatingQueueState.partyId,isDuo=floatingQueueState.format==='duo'||Boolean(partyId);queueCancelling=true;
    try{
      const name=isDuo?'cancel_duo_queue':'cancel_matchmaking';
      const {error}=await supabase.rpc(name);if(error)throw error;
      if(session?.user?.id!==uid)return false;
      const result=isDuo&&partyId?await supabase.from('duo_queue_parties').select('status,match_id').eq('id',partyId).maybeSingle():await supabase.from('matchmaking_queue').select('status,match_id').eq('user_id',uid).maybeSingle();
      if(session?.user?.id!==uid)return false;
      if(result.error)throw result.error;
      if(result.data?.status==='matched'&&result.data.match_id){
        if(activeMatchId!==result.data.match_id){notify('A partida já foi encontrada. Abrindo a arena…');loadOnlineMatch(result.data.match_id);}
        return true;
      }
      queueRequest++;clearInterval(queueTicker);queueTicker=null;clearInterval(duoQueueTicker);duoQueueTicker=null;activeDuoPartyId=null;
      if(queueChannel)supabase.removeChannel(queueChannel);queueChannel=null;
      setQueueState(null);$("#queue-status").hidden=true;
      if(isDuo)await refreshLobby();notify('Você saiu da fila.');return true;
    }catch(error){if(session?.user?.id===uid)notify('Não foi possível sair da fila: '+displayError(error));return false;}
    finally{if(session?.user?.id===uid)queueCancelling=false;}
  }

  document.addEventListener("click",async event=>{
    if(event.target.id==="friend-menu-scrim"){closeFriendActions();return;}
    if(event.target.closest("#invite-flow-close")||event.target.id==="invite-flow-backdrop"){$("#invite-flow-backdrop").hidden=true;return;}
    const inviteOpen=event.target.closest("[data-invite-open]");if(inviteOpen){openInviteFlow(null,inviteOpen.dataset.inviteOpen);return;}
    const inviteAction=event.target.closest("[data-invite-action]");if(inviteAction){await sendInviteAction(inviteAction.dataset.inviteAction);return;}
    const sandboxInvite=event.target.closest("[data-join-sandbox-invite]");if(sandboxInvite){await joinSandboxInvite(sandboxInvite.dataset.joinSandboxInvite);return;}
    if(event.target.closest("#accept-friend-challenge")){acceptFriendInvite();return;}
    if(event.target.closest("#profile-change-avatar")){if(!requireLogin())return;renderAvatarPicker();$("#profile-avatar-picker").hidden=false;return;}
    if(event.target.closest("#profile-avatar-close")||event.target.id==="profile-avatar-picker"){$("#profile-avatar-picker").hidden=true;return;}
    if(event.target.closest("#profile-avatar-shop")){activeStoreCategory="icons";renderStore();$("#profile-avatar-picker").hidden=true;document.querySelector('.nav-item[data-view="store"]')?.click();return;}
    const avatarChoice=event.target.closest("[data-profile-avatar]");if(avatarChoice&&requireLogin()){const id=avatarChoice.dataset.profileAvatar;avatarChoice.disabled=true;const {error}=await supabase.rpc("equip_shop_item",{p_item_id:id});if(error){notify(displayError(error));avatarChoice.disabled=false;}else{$("#profile-avatar-picker").hidden=true;notify("Ícone de perfil atualizado.");await loadProfile();}return;}
    const storeCategory=event.target.closest("[data-store-category]");if(storeCategory){activeStoreCategory=storeCategory.dataset.storeCategory;renderStore();return;}
    const authSwitch=event.target.closest("[data-auth-switch]");if(authSwitch){const signup=authSwitch.dataset.authSwitch==="signup";$("#sign-in-form").hidden=signup;$("#sign-up-form").hidden=!signup;$("#auth-heading").textContent=signup?"Crie sua conta de jogador.":"Sua próxima lenda começa aqui.";showAuthMessage("");return;}
    if(event.target.closest("[data-open-challenge]")){$("#challenge-panel").hidden=false;return;}
    if(event.target.closest("[data-close-challenge]")){$("#challenge-panel").hidden=true;return;}
    const add=event.target.closest("[data-add-friend]");if(add&&requireLogin()){const {error}=await supabase.rpc("request_friend",{p_friend_code:add.dataset.addFriend});$("#friend-search-result").textContent=error?displayError(error):"Pedido enviado. Se o jogador já tinha enviado um pedido, vocês agora são amigos.";if(!error)loadFriends();return;}
    const accept=event.target.closest("[data-accept-friend]");if(accept&&requireLogin()){const {error}=await supabase.rpc("respond_friend_request",{p_friendship_id:accept.dataset.acceptFriend,p_accept:true});if(error)notify(displayError(error));else loadFriends();return;}
    const friendToggle=event.target.closest("#friends-menu-toggle");if(friendToggle){const submenu=$("#friends-submenu"),open=submenu.hidden;submenu.hidden=!open;friendToggle.setAttribute("aria-expanded",String(open));friendToggle.classList.toggle("active",open);if(open&&session)loadFriends();return;}
    const friendPanel=event.target.closest("[data-friend-panel]");if(friendPanel){if(!requireLogin())return;const panel=friendPanel.dataset.friendPanel;const pending=panel==="pending",gifts=panel==="gifts";$("#friend-action-title").textContent=pending?"Pedidos pendentes":gifts?"Presentes entre amigos":"Solicitar amizade";$("#friend-action-request").hidden=pending||gifts;$("#friend-action-pending").hidden=!pending;$("#friend-action-gifts").hidden=!gifts;$("#friend-action-backdrop").hidden=false;if(pending||gifts)loadFriends();return;}
    if(event.target.closest("#friend-action-close")||event.target.id==="friend-action-backdrop"){$("#friend-action-backdrop").hidden=true;return;}
    if(event.target.closest("#friend-chat-close")){$("#friend-chat-window").hidden=true;return;}
    if(event.target.closest("#friends-page-next")){const accepted=cachedFriends.filter(friend=>friend.request_status==="accepted"),count=Math.ceil(accepted.length/5);friendPage=friendPage>=count-1?Math.max(0,friendPage-1):friendPage+1;renderFriendLists();return;}
    const selected=event.target.closest("[data-select-friend]");if(selected){toggleFriendActions(selected);return;}
    const profileButton=event.target.closest("[data-friend-profile]");if(profileButton){closeFriendActions();const friend=cachedFriends.find(item=>item.friend_id===profileButton.dataset.friendProfile);if(friend)openFriendProfile(friend);return;}
    if(event.target.closest("#friend-profile-close")||event.target.id==="friend-profile-backdrop"){$("#friend-profile-backdrop").hidden=true;return;}
    if(event.target.closest("#friends-spectator-close")){$("#friends-spectator-panel").hidden=true;clearInterval(spectatorTicker);return;}
    const challenge=event.target.closest("[data-challenge-friend-code]");if(challenge){challengeFriend(challenge);return;}
    const chat=event.target.closest("[data-chat-id]");if(chat&&requireLogin()){closeFriendActions();openChat(chat.dataset.chatId,chat.dataset.friendId,chat.dataset.friendName);return;}
    const storeAction=event.target.closest("[data-store-action]");if(storeAction&&requireLogin()){const id=storeAction.dataset.itemId;storeAction.disabled=true;const {error}=storeAction.dataset.storeAction==="buy"?await supabase.rpc("purchase_shop_item",{p_item_id:id}):await supabase.rpc("equip_shop_item",{p_item_id:id});if(error){storeAction.disabled=false;notify(displayError(error));}else{try{await loadProfile();notify(storeAction.dataset.storeAction==="buy"?"Item comprado e adicionado à coleção.":"Item equipado.");}catch{storeAction.disabled=false;notify("Item salvo na conta. Atualize a página para carregar seus itens.");}}return;}
  });

  $("#sign-in-form").addEventListener("submit",async event=>{event.preventDefault();if(!supabase){showAuthMessage(configured?"A biblioteca do Supabase não carregou. Atualize a página e verifique a internet.":"Configure a URL e a chave pública do Supabase para ativar o login.");return;}showAuthMessage("Entrando…");const {error}=await supabase.auth.signInWithPassword({email:$("#sign-in-email").value.trim(),password:$("#sign-in-password").value});showAuthMessage(error?displayError(error):"");});
  $("#sign-up-form").addEventListener("submit",async event=>{event.preventDefault();if(!supabase){showAuthMessage(configured?"A biblioteca do Supabase não carregou. Atualize a página e verifique a internet.":"Configure o Supabase para criar sua conta.");return;}showAuthMessage("Criando conta…");const nickname=$("#sign-up-name").value.trim(),phone=$("#sign-up-phone").value.trim(),age=Number($("#sign-up-age").value);const {data,error}=await supabase.auth.signUp({email:$("#sign-up-email").value.trim(),password:$("#sign-up-password").value,options:{data:{nickname,display_name:nickname,phone,age},emailRedirectTo:location.origin+location.pathname}});showAuthMessage(error?displayError(error):data.session?"Conta criada!":"Confira seu e-mail para confirmar a conta.");});
  $("#sign-out").addEventListener("click",signOutAccount);
  $("#friend-search-form").addEventListener("submit",event=>{event.preventDefault();searchFriend($("#friend-search-code").value.trim());});
  $("#copy-friend-code").addEventListener("click",async()=>{if(!profile)return notify("Entre para ver seu código de amigo.");try{await navigator.clipboard.writeText(profile.friend_code);notify("Código copiado.");}catch{notify("Seu código é "+profile.friend_code);}});
  $("#copy-profile-friend-code").addEventListener("click",async()=>{if(!profile)return notify("Entre para ver seu código de amigo.");try{await navigator.clipboard.writeText(profile.friend_code);notify("Código copiado.");}catch{notify("Seu código é "+profile.friend_code);}});
  $("#friend-message-form").addEventListener("submit",async event=>{event.preventDefault();if(!activeFriend||!session)return;const input=$("#friend-message-input"),body=input.value.trim();if(!body)return;input.value="";const {error}=await supabase.from("friend_messages").insert({friendship_id:activeFriend.friendshipId,sender_id:session.user.id,body});if(error){input.value=body;notify(displayError(error));}});
  $("#profile-edit-form").addEventListener("submit",async event=>{event.preventDefault();if(!session)return requireLogin();const name=$("#profile-name-input").value.trim(),phone=$("#profile-phone-input").value.trim(),age=$("#profile-age-input").value?Number($("#profile-age-input").value):null;const {error}=await supabase.from("profiles").update({display_name:name,nickname:name,phone,age}).eq("id",session.user.id);$("#profile-save-status").textContent=error?displayError(error):"Perfil atualizado.";if(!error)loadProfile();});
  $("#settings-form").addEventListener("submit",async event=>{event.preventDefault();if(!session)return requireLogin();const volume=Number($("#setting-volume").value);try{localStorage.setItem("mythic-clash-music-volume",String(volume));}catch{}window.dispatchEvent(new CustomEvent("mythic-volume-loaded",{detail:{volume}}));const settings={...(profile?.settings||{}),music:$("#setting-music").checked,effects:$("#setting-effects").checked,notifications:$("#setting-notifications").checked,volume};const {error}=await supabase.from("profiles").update({settings}).eq("id",session.user.id);$("#settings-save-status").textContent=error?displayError(error):"Preferências salvas.";if(!error){profile.settings=settings;const toggle=$("#music-toggle"),currentlyOn=toggle.getAttribute("aria-pressed")==="true";if(currentlyOn!==settings.music)toggle.click();}});
  $("#redeem-code-form").addEventListener("submit",async event=>{
    event.preventDefault();if(!requireLogin())return;
    const form=event.currentTarget,button=form.querySelector('button[type="submit"]')||form.querySelector('button'),uid=session.user.id;
    if(form.dataset.pending)return;form.dataset.pending="true";if(button)button.disabled=true;
    const result=$("#redeem-result");let claimed=false;
    try{
      result.textContent="Validando código…";
      const {error}=await supabase.rpc("claim_gift_code",{p_code:$("#redeem-code").value.trim().toUpperCase()});
      if(error)throw error;claimed=true;
      if(session?.user?.id!==uid)return;
      $("#redeem-code").value="";result.textContent="Presente resgatado. Atualizando sua coleção…";
      await loadProfile();if(session?.user?.id!==uid)return;
      result.textContent="Presente resgatado! Sua coleção e seu saldo já estão atualizados.";
    }catch(error){result.textContent=claimed?"Presente salvo na conta. Não foi possível atualizar a tela agora; tente atualizar a página.":displayError(error);}
    finally{delete form.dataset.pending;if(button)button.disabled=false;}
  });
  $("#guild-create-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const {error}=await supabase.rpc("create_guild",{p_name:$("#guild-name").value.trim(),p_description:$("#guild-description").value.trim()});if(error)notify(displayError(error));else{event.target.reset();await loadCommunityHub();notify("Guilda criada. Compartilhe o código com seus amigos.");}});
  $("#guild-join-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const {error}=await supabase.rpc("join_guild",{p_invite_code:$("#guild-code").value.trim().toUpperCase()});if(error)notify(displayError(error));else{event.target.reset();await loadCommunityHub();notify("Você entrou para a guilda.");}});
  $("#guild-war-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const {error}=await supabase.rpc("create_guild_war",{p_opponent_guild:$("#guild-war-opponent").value});if(error)notify(displayError(error));else{event.target.reset();await loadCommunityHub();notify("Guerra de guildas iniciada por sete dias.");}});
  $("#tournament-create-form").addEventListener("submit",async event=>{event.preventDefault();if(!adminGuard())return;const {error}=await supabase.rpc("create_player_tournament",{p_title:$("#tournament-title").value.trim(),p_format:$("#tournament-format").value,p_starts_at:new Date($("#tournament-start").value).toISOString()});if(error)notify(displayError(error));else{event.target.reset();await loadCommunityHub();notify("Torneio criado. As inscrições estão abertas.");}});
  $("#expedition-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const {error}=await supabase.rpc("start_player_expedition",{p_card_id:$("#expedition-card-id").value.trim(),p_duration:Number($("#expedition-duration").value)});if(error)notify(displayError(error));else{event.target.reset();await loadProfile();await loadCommunityHub();notify("Expedição iniciada. Volte quando o tempo acabar para resgatar as MC.");}});
  $("#community-deck-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const {error}=await supabase.rpc("publish_community_deck",{p_title:$("#community-deck-title").value.trim(),p_deck_code:$("#community-deck-code").value.trim(),p_description:$("#community-deck-description").value.trim()});if(error)notify(displayError(error));else{event.target.reset();await loadCommunityHub();notify("Deck publicado na comunidade.");}});
  $("#replay-save-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const matchId=$("#replay-match-select").value,{error}=await supabase.rpc("save_match_replay",{p_match_id:matchId,p_title:$("#replay-title").value.trim(),p_events:[],p_public:false});if(error)notify(displayError(error));else{notify("Replay salvo. Abra-o para avançar pelos momentos registrados.");await loadCommunityHub();}});
  $("#replay-timeline").addEventListener("input",event=>renderReplayFrame(Number(event.target.value)));
  $("#replay-play").addEventListener("click",()=>{if(replayTicker){clearInterval(replayTicker);replayTicker=null;$("#replay-play").textContent="▶ Reproduzir";return;}$("#replay-play").textContent="Ⅱ Pausar";replayTicker=setInterval(()=>{const slider=$("#replay-timeline"),next=Number(slider.value)+1;if(next>Number(slider.max)){clearInterval(replayTicker);replayTicker=null;$("#replay-play").textContent="▶ Reproduzir";return;}renderReplayFrame(next);},1000);});
  $("#replay-share").addEventListener("click",async()=>{const id=$("#replay-viewer").dataset.replayId;if(!id)return;const makePublic=!replayCurrent?.is_public,{error}=await supabase.rpc("set_replay_public",{p_replay_id:id,p_public:makePublic});if(error){notify(displayError(error));return;}if(makePublic){const link=`${location.origin}${location.pathname}?replay=${id}`;try{await navigator.clipboard.writeText(link);notify("Replay público. Link copiado.");}catch{notify("Replay público. Copie o endereço da barra do navegador.");}}else notify("Replay voltou a ficar privado.");await openReplay(id);await loadCommunityHub();});
  document.querySelectorAll('[data-view="arena"],[data-view="guilds"],[data-view="missions"],[data-view="community-decks"],[data-view="profile"]').forEach(button=>button.addEventListener("click",()=>{setTimeout(loadCommunityHub,0);const shared=new URLSearchParams(location.search).get("replay");if(shared&&button.dataset.view==="profile")setTimeout(()=>openReplay(shared),500);}));
  document.addEventListener("click",async event=>{const watch=event.target.closest("[data-watch-match]");if(watch){watchFriendMatch(watch.dataset.watchMatch);return;}const friendWatch=event.target.closest("[data-watch-friend-name]")||event.target.closest("#watch-selected-friend");if(friendWatch){if(!requireLogin())return;closeFriendActions();const name=friendWatch.dataset.friendName||activeFriend?.friendName,{data,error}=await supabase.rpc("list_friend_active_matches");if(error){notify(displayError(error));return;}const match=(data||[]).find(row=>row.friend_name===name);if(!match){notify(`${name||"Este amigo"} não está em uma partida assistível agora.`);return;}$("#friends-spectator-panel").hidden=false;setTimeout(()=>watchFriendMatch(match.match_id),100);return;}const open=event.target.closest("[data-open-replay]");if(open)openReplay(open.dataset.openReplay);});
  document.addEventListener("click",async event=>{const bracket=event.target.closest("[data-create-bracket]");if(bracket){bracket.disabled=true;const {error}=await supabase.rpc("create_tournament_bracket",{p_tournament_id:bracket.dataset.createBracket});if(error){notify(displayError(error));bracket.disabled=false;}else{notify("Chave criada. Os jogadores já podem iniciar os duelos da primeira rodada.");await loadCommunityHub();}return;}const advance=event.target.closest("[data-advance-bracket]");if(advance){advance.disabled=true;const {data,error}=await supabase.rpc("advance_tournament_bracket",{p_tournament_id:advance.dataset.advanceBracket});if(error){notify(displayError(error));advance.disabled=false;}else{notify(data===0?"Torneio concluído!":"Nova rodada criada.");await loadCommunityHub();}return;}const tournamentMatch=event.target.closest("[data-start-tournament-match]");if(tournamentMatch){tournamentMatch.disabled=true;const {data,error}=await supabase.rpc("start_tournament_match",{p_round_id:tournamentMatch.dataset.startTournamentMatch});if(error){notify(displayError(error));tournamentMatch.disabled=false;}else await loadOnlineMatch(data);return;}const resume=event.target.closest("[data-open-tournament-match]");if(resume){loadOnlineMatch(resume.dataset.openTournamentMatch);return;}const mission=event.target.closest("[data-claim-guild-mission]");if(mission){mission.disabled=true;const {error}=await supabase.rpc("claim_guild_weekly_reward",{p_mission_id:mission.dataset.claimGuildMission});if(error)notify(displayError(error));else{await loadProfile();notify("Recompensa semanal da guilda resgatada.");}await loadCommunityHub();}});
  document.addEventListener("click",async event=>{const choice=event.target.closest("[data-tiebreak-card]");if(!choice)return;const matchId=window.MythicOnline?.activeMatchId?.();if(!matchId){notify("A partida não está mais disponível nesta tela.");return;}choice.disabled=true;const {data,error}=await supabase.rpc("submit_tiebreak_card",{p_match_id:matchId,p_card_id:choice.dataset.tiebreakCard});if(error){notify(displayError(error));choice.disabled=false;return;}if(data?.resolved){if(data.winner_id)await loadProfile();window.MythicGame?.resolveOnlineTieBreak?.(data.winner_id,data.cards,true);}else await loadTieBreak(matchId);});
  $("#friend-gift-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const {error}=await supabase.rpc("send_friend_gift",{p_receiver:$("#gift-friend-select").value,p_coins:Number($("#gift-coins").value),p_note:$("#gift-note").value.trim()});if(error)notify(displayError(error));else{event.target.reset();await loadProfile();notify("Presente enviado ao seu amigo.");}});
  $("#friend-card-gift-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;const {error}=await supabase.rpc("send_friend_card_gift",{p_receiver:$("#gift-card-friend-select").value,p_card_id:$("#gift-card-id").value});if(error)notify(displayError(error));else{event.target.reset();await loadProfile();notify("Carta enviada. Você precisa manter ao menos uma cópia.");}});
  document.addEventListener("click",async event=>{const cardGift=event.target.closest("[data-claim-friend-card-gift]");if(cardGift){cardGift.disabled=true;const {error}=await supabase.rpc("claim_friend_card_gift",{p_gift_id:cardGift.dataset.claimFriendCardGift});if(error)notify(displayError(error));else notify("Carta adicionada à sua coleção.");await loadProfile();await loadGiftInbox();return;}const gift=event.target.closest("[data-claim-friend-gift]");if(gift){gift.disabled=true;const {error}=await supabase.rpc("claim_friend_gift",{p_gift_id:gift.dataset.claimFriendGift});if(error)notify(displayError(error));else{await loadProfile();notify("Mythic Coins adicionadas ao seu saldo.");}await loadGiftInbox();return;}const claim=event.target.closest("[data-claim-mission]");if(claim){claim.disabled=true;const {error}=await supabase.rpc("claim_mission",{p_mission_id:claim.dataset.claimMission});if(error)notify(displayError(error));else{await loadProfile();notify("Missão concluída: XP e MC adicionados.");}await loadCommunityHub();return;}const expedition=event.target.closest("[data-claim-expedition]");if(expedition){expedition.disabled=true;const {error}=await supabase.rpc("claim_player_expedition",{p_expedition_id:expedition.dataset.claimExpedition});if(error)notify(displayError(error));else{await loadProfile();notify("Recompensa da expedição resgatada.");}await loadCommunityHub();return;}const enter=event.target.closest("[data-enter-tournament]");if(enter){enter.disabled=true;const {error}=await supabase.rpc("enter_player_tournament",{p_tournament_id:enter.dataset.enterTournament});if(error)notify(displayError(error));else notify("Inscrição confirmada.");await loadCommunityHub();return;}const vote=event.target.closest("[data-vote-deck]");if(vote){vote.disabled=true;const {error}=await supabase.rpc("vote_community_deck",{p_deck_id:vote.dataset.voteDeck});if(error)notify(displayError(error));else notify("Voto registrado.");await loadCommunityHub();}});
  $("#setting-volume").addEventListener("input",event=>{const volume=Number(event.target.value);$("#setting-volume-value").value=`${volume}%`;try{localStorage.setItem("mythic-clash-music-volume",String(volume));}catch{}window.dispatchEvent(new CustomEvent("mythic-volume-loaded",{detail:{volume}}));});
  $("#admin-announcement-form").addEventListener("submit",async event=>{event.preventDefault();if(!adminGuard())return;const row={id:"main",title:$("#admin-announcement-title").value.trim(),body:$("#admin-announcement-body").value.trim(),active:$("#admin-announcement-active").checked,updated_at:new Date().toISOString()};const {error}=await supabase.from("game_announcements").upsert(row,{onConflict:"id"});$("#admin-announcement-status").textContent=error?displayError(error):"Comunicado salvo.";if(!error)loadPublicAnnouncement();});
  $("#admin-shop-form").addEventListener("submit",async event=>{event.preventDefault();if(!adminGuard())return;const item={item_id:$("#admin-item-id").value.trim().toLowerCase(),title:$("#admin-item-title").value.trim(),description:$("#admin-item-description").value.trim(),kind:$("#admin-item-kind").value,price:Number($("#admin-item-price").value),asset_path:$("#admin-item-asset").value.trim(),card_id:$("#admin-item-card").value.trim()||null,active:true};const {error}=await supabase.from("shop_catalog").upsert(item,{onConflict:"item_id"});$("#admin-shop-status").textContent=error?displayError(error):"Item salvo no catálogo.";if(!error){event.target.reset();$("#admin-item-price").value="100";await loadAdminDashboard();await loadProfile();}});
  $("#admin-gift-form").addEventListener("submit",async event=>{event.preventDefault();if(!adminGuard())return;const date=$("#admin-gift-expiry").value;const gift={code:$("#admin-gift-code").value.trim().toUpperCase(),reward_type:$("#admin-gift-type").value,reward_amount:Number($("#admin-gift-amount").value)||0,item_id:$("#admin-gift-item").value.trim()||null,card_id:$("#admin-gift-card").value.trim()||null,max_uses:Number($("#admin-gift-uses").value),active:true,expires_at:date?new Date(date).toISOString():null};const {error}=await supabase.from("redeem_codes").insert(gift);$("#admin-gift-status").textContent=error?displayError(error):"Código criado e pronto para compartilhar.";if(!error){event.target.reset();$("#admin-gift-amount").value="100";$("#admin-gift-uses").value="1";await loadAdminDashboard();}});
  $("#admin-reward-form").addEventListener("submit",async event=>{event.preventDefault();if(!adminGuard())return;const {error}=await supabase.rpc("admin_adjust_player_rewards",{p_user_id:$("#admin-player-select").value,p_coins_delta:Number($("#admin-coins-delta").value),p_xp_delta:Number($("#admin-xp-delta").value)});$("#admin-reward-status").textContent=error?displayError(error):"Recompensas atualizadas e registradas.";if(!error){$("#admin-coins-delta").value="0";$("#admin-xp-delta").value="0";await loadAdminDashboard();}});
  $("#admin-lore-card").addEventListener("change",loadAdminLoreEditor);
  $("#admin-card-id").addEventListener("change",loadAdminCardEditor);
  ["#admin-card-name","#admin-card-title","#admin-card-ability","#admin-card-faction","#admin-card-power"].forEach(selector=>$(selector).addEventListener("input",drawAdminCardPreview));$("#admin-card-faction").addEventListener("change",drawAdminCardPreview);
  $("#admin-card-image").addEventListener("change",event=>{const file=event.target.files?.[0];if(!file)return;if(!["image/png","image/jpeg","image/webp"].includes(file.type)||file.size>5*1024*1024){event.target.value="";$("#admin-card-status").textContent="Use PNG, JPG ou WebP de até 5 MB.";return;}adminCardSourceUrl=null;if(adminCardPreviewUrl)URL.revokeObjectURL(adminCardPreviewUrl);adminCardPreviewUrl=URL.createObjectURL(file);$("#admin-card-status").textContent="Imagem carregada na prévia.";drawAdminCardPreview();});
  $("#admin-card-download").addEventListener("click",downloadAdminCard);
  $("#admin-lore-comic").addEventListener("change",event=>{const file=event.target.files?.[0];if(file&&(file.size>50*1024*1024||!(["application/pdf","image/png","image/jpeg","image/webp"].includes(file.type)))){event.target.value="";$("#admin-lore-status").textContent="Escolha PDF, PNG, JPG ou WebP de até 50 MB.";}});
  $("#admin-lore-form").addEventListener("submit",async event=>{event.preventDefault();if(!adminGuard())return;const cardId=$("#admin-lore-card").value,file=$("#admin-lore-comic").files?.[0];let comicUrl=adminLore.find(item=>item.card_id===cardId)?.comic_url||null;$("#admin-lore-status").textContent=file?"Enviando HQ…":"Salvando história e trilha…";if(file){const safeName=file.name.replace(/[^a-zA-Z0-9._-]/g,"-").slice(-100),path=`${cardId}/${Date.now()}-${safeName}`,{data:uploaded,error:uploadError}=await supabase.storage.from("mythic-comics").upload(path,file,{contentType:file.type,upsert:false});if(uploadError){$("#admin-lore-status").textContent=displayError(uploadError);return;}comicUrl=supabase.storage.from("mythic-comics").getPublicUrl(uploaded.path).data.publicUrl;}const story=$("#admin-lore-text").value.split(/\n\s*\n/).map(part=>part.trim()).filter(Boolean),theme=$("#admin-lore-theme").value.trim()||null,row={card_id:cardId,story,theme_url:theme,comic_url:comicUrl,updated_at:new Date().toISOString()};const {error}=await supabase.from("card_lore").upsert(row,{onConflict:"card_id"});$("#admin-lore-status").textContent=error?displayError(error):"História, trilha e HQ salvas.";if(!error){$("#admin-lore-comic").value="";await loadPublicLore();await loadProfile();const {data}=await supabase.from("card_lore").select(cardLoreSelect);adminLore=data||[];loadAdminLoreEditor();}});
  document.addEventListener("click",async event=>{const edit=event.target.closest("[data-admin-edit-item]");if(edit){const item=adminCatalog.find(row=>row.item_id===edit.dataset.adminEditItem);if(!item)return;$("#admin-item-id").value=item.item_id;$("#admin-item-title").value=item.title;$("#admin-item-description").value=item.description;$("#admin-item-kind").value=item.kind;$("#admin-item-price").value=item.price;$("#admin-item-asset").value=item.asset_path;$("#admin-item-card").value=item.card_id||"";$("#admin-item-title").focus();return;}const toggle=event.target.closest("[data-admin-toggle-item]");if(toggle&&adminGuard()){const item=adminCatalog.find(row=>row.item_id===toggle.dataset.adminToggleItem);const {error}=await supabase.from("shop_catalog").update({active:!item.active}).eq("item_id",item.item_id);if(error)notify(displayError(error));else{await loadAdminDashboard();await loadProfile();}return;}const gift=event.target.closest("[data-admin-toggle-gift]");if(gift&&adminGuard()){const item=adminGifts.find(row=>row.code===gift.dataset.adminToggleGift);const {error}=await supabase.from("redeem_codes").update({active:!item.active}).eq("code",item.code);if(error)notify(displayError(error));else loadAdminDashboard();}});
  $("#enable-notifications").addEventListener("click",async()=>{const status=$("#device-feature-status");if(!("Notification" in window)){status.textContent="Este navegador não oferece notificações.";return;}const result=await Notification.requestPermission();status.textContent=result==="granted"?"Notificações ativadas neste aparelho.":"Permissão de notificações não concedida.";if(result==="granted")new Notification("Mythic Clash",{body:"Avisos deste aparelho foram ativados enquanto o jogo estiver aberto."});});
  $("#enable-biometrics").addEventListener("click",()=>{$("#device-feature-status").textContent=window.PublicKeyCredential?"Este aparelho oferece biometria, mas o acesso seguro por passkey ainda precisa da validação de credenciais no servidor.":"Este navegador não oferece passkey/biometria.";});
  $("#cancel-queue").addEventListener("click",cancelQueue);
  $('#create-invite-form').addEventListener('submit',async event=>{event.preventDefault();const button=event.currentTarget.querySelector('button[type=submit]');button.disabled=true;try{const invite=await createDirectInvite($('#invite-friend-code').value.trim().toUpperCase()||null);$('#created-invite-code').textContent=`Código: ${invite.invite_code} · válido por 15 minutos`;}catch(error){$('#created-invite-code').textContent=error.message;}finally{button.disabled=false;}});
  $("#join-invite-form").addEventListener("submit",async event=>{event.preventDefault();if(!requireLogin())return;if(window.MythicDeckEditor?.isSelecting?.()||window.MythicDeckBuilder?.isOpen?.()){notify("Conclua a seleção do baralho antes de entrar.");return;}const {data,error}=await supabase.rpc("join_game_invite",{p_code:$("#join-invite-code").value.trim().toUpperCase()});const match=Array.isArray(data)?data[0]:data;$("#joined-invite-status").textContent=error?displayError(error):`Desafio aceito. Abrindo partida…`;if(!error&&match?.match_id)loadOnlineMatch(match.match_id);});
  async function findFriendByCode(code){if(!requireLogin())return null;await loadFriends();const {data,error}=await supabase.rpc("find_player_by_friend_code",{p_code:code});if(error){notify(displayError(error));return null;}const player=Array.isArray(data)?data[0]:data;if(!player||!cachedFriends.some(friend=>friend.request_status==="accepted"&&friend.friend_id===player.id)){notify("Esse jogador ainda não está na sua lista de amigos.");return null;}return player;}
  async function welcomeRequest(name,args={}){if(!session||!supabase)throw Error("Entre na conta para continuar.");const uid=session.user.id;const {data,error}=await supabase.rpc(name,args);if(session?.user?.id!==uid)throw Error("A conta mudou. Entre novamente.");if(error)throw Error(/PGRST202|42883/.test(String(error.code))?"As boas-vindas estão temporariamente indisponíveis. Tente novamente em instantes.":displayError(error));return data;}
  async function openStarterPack(mythology){const data=await welcomeRequest("open_starter_pack",{p_mythology:mythology});deckLoadedFor=null;return data;}
  async function portalRequest(name,args={}){if(!supabase)throw Error('A conexão não está disponível.');const uid=session?.user?.id;const {data,error}=await supabase.rpc(name,args);if(uid!==session?.user?.id)throw Error('A conta foi alterada.');if(error)throw Error(displayError(error));return data;}
  window.MythicOnline={watchCustomMatch:async id=>{document.querySelector('[data-view="friends"]')?.click();$("#friends-spectator-panel").hidden=false;await watchFriendMatch(id);},refreshAdminAccess:loadAdminAccess,portalRequest,account:()=>session?.user||null,getWelcomeState:()=>welcomeRequest("get_welcome_state"),openStarterPack,completeWelcome:()=>welcomeRequest("complete_welcome"),refreshPresentation:()=>{emitConceptProfile();if(session){loadProfileAnalytics(session.user.id,"profile");loadCommunityHub().catch(()=>{});}},loadHonors:loadPlayerHonors,equipHonors:equipPlayerHonors,signOut:signOutAccount,saveDeckCounts,saveNamedDeck,saveBuilderDeck,deleteBuilderDeck,saveDeckPersonalization,createDirectInvite,isConnected:()=>Boolean(session),showLogin,requireLogin,userId:()=>session?.user?.id||null,activeMatchId:()=>activeMatchId,openMatch:loadOnlineMatch,isAdmin:()=>adminAuthorized,openAdmin,submitAction,expireTurn,loadTieBreak,leaveMatch,startQueue,startDuoQueue,respondDuoInvite,cancelQueue,convergeLobby,leaveLobby,openQueueLobby,refreshLobby,lobbyFriends,loadLobbyFriends:async()=>{await loadFriends();await syncPresence();return lobbyFriends();},getLobbyState:()=>({party:lobbyParty,busy:lobbyBusy,userId:session?.user?.id||null}),getQueueState:()=>({...floatingQueueState}),rankProgress:()=>profile&&session?window.MythicRank.from(profile.rating_points):null,findFriendByCode,profileReady:()=>accountReady,pvpUnlocked:()=>Boolean(adminAuthorized||profile?.tutorial_completed||Number(profile?.xp||0)>=100),tutorialCompleted:()=>Boolean(adminAuthorized||profile?.tutorial_completed||Number(profile?.xp||0)>=100),isTutorialComplete:()=>Boolean(profile?.tutorial_completed),completeTutorial:async()=>{if(!session)return false;const {data,error}=await supabase.rpc("complete_tutorial_once");if(!error){await loadProfile();if(profile?.tutorial_completed||Number(profile?.xp||0)>=100){try{localStorage.setItem("mythic-clash-tutorial-complete","true");localStorage.setItem("mythic-clash-level","2");}catch{}return true;}notify("Tutorial registrado, mas o perfil ainda não recebeu o nível 2. Atualize a migração de progressão no Supabase.");return false;}notify("Não foi possível registrar o tutorial. Tente novamente após verificar a atualização do banco.");return false;},recordGuardianMatch:async(matchId,outcome,playerPoints,opponentPoints)=>{if(!session)return;const {error}=await supabase.rpc("record_guardian_match",{p_match_id:matchId,p_outcome:outcome,p_player_points:playerPoints,p_opponent_points:opponentPoints});if(error)notify(displayError(error));else{await loadProfile();}},refreshProfile:loadProfile};
  window.addEventListener("mythic-availability-updated",()=>{if(storeItems.length)renderStore();});
  window.MythicOnline.loadPublicNews=loadPublicAnnouncement;window.MythicOnline.avatarAsset=resolveAvatarAsset;window.MythicOnline.playerName=()=>profile?.nickname||profile?.display_name||"Você";window.MythicOnline.playerIcon=()=>profile?.equipped_avatar||"default";window.MythicOnline.playerRating=()=>profile?.rating_points||1000;
})();

