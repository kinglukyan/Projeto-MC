(() => {
 'use strict';
 const $=s=>document.querySelector(s),api=()=>window.MythicOnline;
 const dialog=$('#lobby-friends-dialog'),popup=$('#lobby-invitation');
 if(!dialog||!popup)return;
 let state=api()?.getLobbyState?.()||{},queue=api()?.getQueueState?.()||{active:false},friends=[],sending=false,inviteId=null,returnFocus=null,position=null,drag=null;
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 // Usar os mesmos nomes e emblemas de elo do restante do jogo.
 const rankNames=['Aprendiz de Herói','Escudeiro','Herói','Lenda','Semideus','Deus','Convergente'];
 function rankName(value){const p=window.MythicRank?.from?.(Number(value)||1000);return p?.name||p?.rank||rankNames[p?.index]||'Aprendiz de Herói';}
 function avatar(node,icon,name){node.replaceChildren();const source=api()?.avatarAsset?.(icon||'default');if(source){const image=el('img');image.src=source;image.alt='';node.append(image);}else node.textContent=(name||'MC').slice(0,2).toUpperCase();}
 function member(id){return state.party?.members?.find(m=>m.id===id);}
 function paint(){
  const p=state.party,uid=api()?.userId?.(),self={id:uid,name:api()?.playerName?.()||'Você',icon:api()?.playerIcon?.(),rating:api()?.playerRating?.()},incoming=p?.status==='inviting'&&p.partner_id===uid;
  const inRoom=p&&!incoming,other=inRoom?member(p.host_id===uid?p.partner_id:p.host_id):null,isHost=!inRoom||p.host_id===uid;
  avatar($('#lobby-self-avatar'),self.icon,self.name);$('#queue-self-name').textContent=self.name;
  $('#lobby-self-rank').textContent=rankName(self.rating);$('#lobby-self>small').textContent=isHost?'ANFITRIÃO':'VOCÊ';
  $('#lobby-add-friend').hidden=Boolean(inRoom);$('#lobby-add-friend').disabled=queue.active||state.busy||incoming;
  $('#lobby-partner').hidden=!inRoom;
  if(inRoom){avatar($('#lobby-partner-avatar'),other?.icon,other?.name);$('#lobby-partner-name').textContent=other?.name||'Aliado';$('#lobby-partner-rank').textContent=rankName(other?.rating);$('#lobby-partner-label').textContent=p.status==='inviting'?'CONVITE ENVIADO':isHost?'JOGADOR 2':'ANFITRIÃO';}
  const joined=inRoom&&p.status!=='inviting';$('#lobby-format').textContent=joined?'Dupla · 2 × 2':'Solo · 1 × 1';
  $('#lobby-message').textContent=incoming?'Você recebeu um convite para uma sala.':p?.status==='inviting'?'Aguardando seu amigo aceitar o convite…':joined?(isHost?'Dupla formada. Convirjam quando estiverem prontos.':'Sala pronta. Aguarde o anfitrião convergir.'):'Sua jornada pode começar solo ou ao lado de um amigo.';
  $('#lobby-leave').textContent=p?.status==='inviting'?'Cancelar convite':isHost?'Desfazer dupla':'Sair da sala';$('#lobby-leave').disabled=state.busy||queue.active;
  const button=$('#queue-join');button.disabled=Boolean(queue.active||state.busy||incoming||(inRoom&&(!isHost||p.status!=='ready')));
  $('#converge-label').textContent=queue.active?(queue.phase==='queued'?'Em convergência':'Conectando…'):state.busy?'Aguarde…':inRoom&&!isHost?'Aguardando anfitrião':'Convergir';
  const queued=queue.active&&queue.phase==='queued';$('#converge-action').classList.toggle('is-queued',Boolean(queued));$('#converge-clock').hidden=!queued;$('#cancel-queue').hidden=!queued;
  $('#lobby-friends-status').textContent=sending?'Enviando convite…':$('#lobby-friends-status').textContent;
  if(incoming){
    const host=member(p.host_id);avatar($('#lobby-inviter-avatar'),host?.icon,host?.name);
    $('#lobby-invitation-title').textContent=host?.name||'Seu amigo';$('#lobby-inviter-rank').textContent=rankName(host?.rating);
    $('#lobby-invitation-copy').textContent=(p.mode==='ranked'?'Ranqueada':'Normal')+' · convidou você para a sala. A busca começa quando o anfitrião convergir.';
    if(inviteId!==p.id){inviteId=p.id;$('#lobby-invitation-status').textContent='';position=null;}
    popup.hidden=false;$('#accept-duo-invite').disabled=$('#decline-duo-invite').disabled=Boolean(state.busy);
    requestAnimationFrame(place);
  }else{popup.hidden=true;inviteId=null;drag=null;}
  tick();
 }
 function tick(){const n=queue.startedAt?Math.max(0,Math.floor((Date.now()-queue.startedAt)/1000)):0;$('#converge-clock').textContent=String(Math.floor(n/60)).padStart(2,'0')+':'+String(n%60).padStart(2,'0');}
 function drawFriends(){
  const text=$('#lobby-friends-search').value.trim().toLocaleLowerCase('pt-BR'),weight={online:0,away:1,offline:2},list=$('#lobby-friends-list');list.replaceChildren();
  const sorted=friends.filter(f=>f.display_name.toLocaleLowerCase('pt-BR').includes(text)).sort((a,b)=>(weight[a.presence]??2)-(weight[b.presence]??2)||a.display_name.localeCompare(b.display_name,'pt-BR'));
  for(const friend of sorted){
    const row=el('article','lobby-friend'),icon=el('span','lobby-avatar');avatar(icon,friend.equipped_avatar,friend.display_name);
    const copy=el('div','lobby-friend-copy'),status=el('small','lobby-friend-presence',friend.presence==='online'?'Online':friend.presence==='away'?'Ausente':'Offline');status.dataset.status=friend.presence;
    const elo=el('span','lobby-friend-elo',rankName(friend.rating_points)),progress=window.MythicRank?.from?.(friend.rating_points);if(progress?.emblem){const badge=el('img');badge.src=progress.emblem;badge.alt='';elo.prepend(badge);}copy.append(el('b','',friend.display_name),elo,status);
    const invite=el('button','button button-secondary','Convidar');invite.type='button';invite.disabled=sending;invite.setAttribute('aria-label','Convidar '+friend.display_name);invite.addEventListener('click',async()=>{
      if(sending)return;sending=true;$('#lobby-friends-status').textContent='Enviando convite…';drawFriends();
      try{const result=await api().startDuoQueue(window.queueGameMode||'normal',friend.friend_code);if(!result)throw Error('Conexão indisponível.');if(result?.error)$('#lobby-friends-status').textContent=result.error;else dialog.close();}
      catch{ $('#lobby-friends-status').textContent='Não foi possível enviar. Tente novamente.'; }
      finally{sending=false;drawFriends();}
    });row.append(icon,copy,invite);list.append(row);
  }
  if(!sorted.length)list.append(el('p','empty-state',text?'Nenhum amigo com esse nick.':'Sua lista de amigos ainda está vazia.'));
 }
 async function openFriends(){
  if(!api()?.requireLogin?.())return;if(queue.active||state.party||state.busy)return;
  returnFocus=document.activeElement;$('#lobby-friends-search').value='';$('#lobby-friends-status').textContent='Carregando amigos…';
  friends=api().lobbyFriends();drawFriends();if(!dialog.open)dialog.showModal();
  try{friends=await api().loadLobbyFriends();$('#lobby-friends-status').textContent='Online primeiro. Você também pode convidar amigos offline.';drawFriends();}
  catch{ $('#lobby-friends-status').textContent='Não foi possível atualizar os amigos. Tente novamente.'; }
 }
 $('#lobby-add-friend').addEventListener('click',openFriends);$('#lobby-friends-close').addEventListener('click',()=>dialog.close());
 dialog.addEventListener('close',()=>returnFocus?.focus?.());dialog.addEventListener('click',e=>{if(e.target===dialog){const b=dialog.getBoundingClientRect();if(e.clientX<b.left||e.clientX>b.right||e.clientY<b.top||e.clientY>b.bottom)dialog.close();}});
 $('#lobby-friends-search').addEventListener('input',drawFriends);
 $('#queue-join').addEventListener('click',()=>api()?.convergeLobby?.());
 $('#lobby-leave').addEventListener('click',async()=>{const result=await api()?.leaveLobby?.();if(result?.error)$('#queue-setup-status').textContent=result.error;});
 for(const [id,accept] of [['#accept-duo-invite',true],['#decline-duo-invite',false]])$(id).addEventListener('click',async()=>{const result=await api()?.respondDuoInvite?.(accept);if(result?.error)$('#lobby-invitation-status').textContent=result.error;else if(result?.status==='expired')$('#queue-setup-status').textContent='Esse convite expirou. Peça um novo convite.';});
 function viewBounds(){const v=window.visualViewport;return{left:v?.offsetLeft||0,top:v?.offsetTop||0,width:v?.width||innerWidth,height:v?.height||innerHeight};}
 function place(){if(popup.hidden)return;const v=viewBounds(),b=popup.getBoundingClientRect(),gap=12;position=position||{x:v.left+v.width-b.width-gap,y:v.top+100};position.x=Math.max(v.left+gap,Math.min(position.x,v.left+v.width-b.width-gap));position.y=Math.max(v.top+gap,Math.min(position.y,v.top+v.height-b.height-gap));popup.style.left=position.x+'px';popup.style.top=position.y+'px';}
 const grip=$('#lobby-invitation-grip');grip.addEventListener('pointerdown',e=>{if(e.button!==0||!e.isPrimary)return;place();drag={id:e.pointerId,x:e.clientX,y:e.clientY,px:position.x,py:position.y};grip.setPointerCapture(e.pointerId);});grip.addEventListener('pointermove',e=>{if(drag?.id!==e.pointerId)return;position={x:drag.px+e.clientX-drag.x,y:drag.py+e.clientY-drag.y};place();});
 for(const type of ['pointerup','pointercancel','lostpointercapture'])grip.addEventListener(type,()=>drag=null);
 grip.addEventListener('keydown',e=>{const d={ArrowLeft:[-12,0],ArrowRight:[12,0],ArrowUp:[0,-12],ArrowDown:[0,12]}[e.key];if(!d)return;e.preventDefault();place();position.x+=d[0];position.y+=d[1];place();});
 window.addEventListener('resize',place);window.visualViewport?.addEventListener('resize',place);window.visualViewport?.addEventListener('scroll',place);
 window.addEventListener('mythic-lobby-state',e=>{state=e.detail;paint();});window.addEventListener('mythic-queue-state',e=>{queue=e.detail;paint();});window.addEventListener('mythic-profile-loaded',paint);window.addEventListener('mythic-concept-profile',paint);
 window.addEventListener('mythic-lobby-friends',()=>{friends=api()?.lobbyFriends?.()||[];if(dialog.open)drawFriends();});window.addEventListener('mythic-lobby-picker',openFriends);
 window.addEventListener('mythic-account-signed-out',()=>{state={};queue={active:false};friends=[];if(dialog.open)dialog.close();paint();});
 document.addEventListener('visibilitychange',()=>{if(!document.hidden){tick();api()?.refreshLobby?.();}});
 setInterval(tick,1000);paint();
})();
