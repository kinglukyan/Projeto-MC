(() => {
 'use strict';
 const $=s=>document.querySelector(s),api=()=>window.MythicOnline;
 let room=null,busy=false,requesting=false,inboxBusy=false,incoming=null,choice=null,slot=2,openedMatch=null,restoreUser=null,revision=0,lastRoomId=null;
 const dialog=$('#custom-role-dialog'),popup=$('#custom-invitation');
 const request=(name,args={})=>api().portalRequest(name,args);
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 function status(text){$('#sandbox-result').textContent=text||'';}
 function avatar(node,icon,name){node.replaceChildren();const src=api()?.avatarAsset?.(icon);if(src){const img=el('img');img.src=src;img.alt='';node.append(img);}else node.textContent=(name||'MC').slice(0,2);}
 function front(show){
  if(!show&&popup.matches(':popover-open'))popup.hidePopover();
  popup.hidden=!show;
  if(show&&popup.showPopover&&!popup.matches(':popover-open'))popup.showPopover();
  if(show)requestAnimationFrame(place);
 }
 function paint(){
  const host=room?.host_id===api()?.userId?.(),members=room?.members||[];
  $('#sandbox-form button').disabled=busy;$('#sandbox-join-form button').disabled=busy;
  $('#custom-entry').hidden=Boolean(room);$('#custom-lobby').hidden=!room;
  $('#view-custom').classList.toggle('has-custom-room',Boolean(room));
  if(!room)return;
  $('#custom-room-code').textContent=room.code;
  $('#custom-rules-summary').textContent=`Até ${room.rules.max_cards} cartas · ${room.rules.starting_hand} na mão · ${room.rules.turn_seconds}s por turno`;
  const a=members.filter(m=>m.slot%2===1).length,b=members.filter(m=>m.slot%2===0).length,returned=members.every(m=>m.ready!==false),balanced=a===b&&(a===1||a===2),ready=balanced&&returned;
  $('#custom-room-format').textContent=balanced?(a===1?'1 × 1':'2 × 2'):'Formando equipes';
  for(let n=1;n<=4;n++){
   const card=$(`[data-custom-slot="${n}"]`),m=members.find(m=>m.slot===n);card.replaceChildren();card.classList.toggle('filled',Boolean(m));
   const label=el('small','',m?.id===room.host_id?'ANFITRIÃO':`JOGADOR ${n%2===1?(n+1)/2:n/2}`);card.append(label);
   if(m){const icon=el('span','lobby-avatar');avatar(icon,m.icon,m.name);card.append(icon,el('b','',m.name),el('span','',m.ready===false?'Lendo o resumo da partida':window.MythicRank?.from?.(m.rating)?.name||'Aprendiz de Herói'));}
   else{const plus=el('button','custom-add-seat','+');plus.type='button';plus.disabled=!host||busy;plus.setAttribute('aria-label',`Convidar para o lado ${n%2===1?1:2}, vaga ${n>2?2:1}`);plus.addEventListener('click',()=>{slot=n;window.dispatchEvent(new CustomEvent('mythic-lobby-picker',{detail:{context:'custom',slot:n}}));});card.append(plus,el('b','','Vaga livre'),el('span','',host?'Convide um amigo':'Aguardando convite'));}
  }
  $('#custom-observer').textContent=room.observer?`Observando: ${room.observer.name}`:'Uma vaga de observador disponível';
  const start=$('#custom-start');start.hidden=!host;start.disabled=busy||window.MythicDeckEditor?.isSelecting?.()||!ready||room.status!=='open';start.textContent=busy?'Aguarde…':ready?`Começar ${a===1?'1 × 1':'2 × 2'}`:'Aguardando equipes';
  $('#custom-wait-message').textContent=!returned?'Aguardando todos voltarem do resumo da partida.':host?(ready?'As equipes estão prontas. Você pode iniciar ou convidar mais amigos.':'Preencha os dois lados com a mesma quantidade de jogadores.'):'Aguarde o anfitrião iniciar a partida.';
  $('#custom-leave').textContent=host?'Encerrar sala':'Sair da sala';$('#custom-leave').disabled=busy;
 }
 async function act(fn){if(busy)return;busy=true;paint();try{await fn();}catch(e){status(e.message);}finally{busy=false;paint();}}
 function enter(next){room=next;revision++;status('');paint();document.querySelector('[data-view="custom"]')?.click();}
 async function refresh(){
  if(!room||requesting||document.hidden)return;requesting=true;const id=room.id,version=revision;
  try{
   const next=await request('custom_room_snapshot',{p_room_id:id});if(room?.id!==id||version!==revision)return;
   if(next.status==='closed'){room=null;revision++;paint();status('O anfitrião encerrou a sala.');return;}
   room=next;paint();
   if(next.status==='playing'&&next.match_id&&openedMatch!==next.match_id){
    openedMatch=next.match_id;lastRoomId=next.id;
    if(next.observer?.id===api().userId())await api().watchCustomMatch(next.match_id);
    else await api().openMatch(next.match_id);
    room=null;revision++;paint();
   }
  }catch(e){status(e.message);}finally{requesting=false;}
 }
 function choose(code,invitation=null){
  if(!api()?.requireLogin?.())return;
  choice={code:code.trim().toUpperCase(),invitation};
  $('#custom-role-code').textContent=choice.code;$('#custom-role-status').textContent='';
  if(!dialog.open)dialog.showModal();
 }
 for(const role of ['player','observer'])$(`[data-custom-role="${role}"]`).addEventListener('click',async()=>{
  if(busy||!choice)return;busy=true;dialog.querySelectorAll('[data-custom-role]').forEach(b=>b.disabled=true);
  const chosen=choice;
  try{const next=await request('custom_room_join',{p_code:chosen.code,p_role:role,p_invitation_id:chosen.invitation});dialog.close();incoming=null;front(false);enter(next);}
  catch(e){$('#custom-role-status').textContent=e.message;}
  finally{busy=false;dialog.querySelectorAll('[data-custom-role]').forEach(b=>b.disabled=false);paint();}
 });
 $('#custom-role-close').addEventListener('click',()=>{if(!busy)dialog.close();});dialog.addEventListener('cancel',e=>{if(busy)e.preventDefault();});
 $('#sandbox-form').addEventListener('submit',e=>{e.preventDefault();if(!api()?.requireLogin?.())return;act(async()=>{enter(await request('custom_room_create',{p_rules:{max_cards:Number($('#custom-max-cards').value),starting_hand:Number($('#custom-starting-hand').value),turn_seconds:Number($('#custom-turn-seconds').value)}}));});});
 $('#sandbox-join-form').addEventListener('submit',e=>{e.preventDefault();choose($('#sandbox-code').value);});
 $('#custom-start').addEventListener('click',()=>act(async()=>{if(window.MythicDeckEditor?.isSelecting?.())throw Error('Aguarde o salvamento do baralho.');await request('custom_room_start',{p_room_id:room.id});await refresh();}));
 $('#custom-leave').addEventListener('click',()=>act(async()=>{await request('custom_room_leave',{p_room_id:room.id});room=null;revision++;status('');}));
 $('#custom-copy-code').addEventListener('click',async()=>{try{await navigator.clipboard.writeText(room.code);status('Código copiado.');}catch{status(`Código da sala: ${room.code}`);}});
 async function pollInbox(){
  if(inboxBusy||document.hidden||!api()?.userId?.())return;inboxBusy=true;const uid=api().userId();
  try{
   const next=await request('custom_room_inbox');if(uid!==api()?.userId?.())return;
   incoming=next;if(!next){front(false);return;}
   $('#custom-inviter-name').textContent=next.name;avatar($('#custom-inviter-avatar'),next.icon,next.name);
   $('#custom-invitation-copy').textContent=`Convidou você para uma sala personalizada, no lado ${next.slot%2===1?1:2}.`;
   front(true);
  }catch{ /* Nova migração pode ainda não ter sido publicada. Não interromper outras telas. */ }
  finally{inboxBusy=false;}
 }
 $('#custom-invitation-accept').addEventListener('click',()=>{if(incoming){const i=incoming;front(false);choose(i.code,i.id);}});
 $('#custom-invitation-decline').addEventListener('click',async()=>{if(!incoming)return;const id=incoming.id;try{await request('custom_room_decline',{p_invitation_id:id});incoming=null;front(false);}catch(e){$('#custom-invitation-copy').textContent=e.message;}});
 async function restore(){
  const uid=api()?.userId?.();if(!uid||restoreUser===uid)return;restoreUser=uid;const version=revision;
  try{const next=await request('custom_room_current');if(uid!==api()?.userId?.()||version!==revision)return;room=next;revision++;paint();}
  catch{restoreUser=null;}pollInbox();
 }
 window.MythicCustomLobby={choose,roomForMatch:id=>openedMatch===id?lastRoomId:null,returnToRoom:async id=>{const rid=id||lastRoomId;if(!rid){document.querySelector('[data-view="custom"]')?.click();return;}const next=await request('custom_room_return',{p_room_id:rid});openedMatch=null;lastRoomId=rid;enter(next);},openFriends:()=>{slot=room?.members?.find(m=>m.slot===2)?3:2;window.dispatchEvent(new CustomEvent('mythic-lobby-picker',{detail:{context:'custom',slot}}));},invite:async(friendId,targetSlot=slot)=>{
  if(!room||room.host_id!==api()?.userId?.())return{error:'Crie uma sala antes de convidar.'};
  try{await request('custom_room_invite',{p_room_id:room.id,p_friend_id:friendId,p_slot:targetSlot});status('Convite enviado. Aguardando seu amigo aceitar.');return{status:'sent'};}catch(e){return{error:e.message};}
 }};
 window.addEventListener('mythic-deck-selection-state',paint);window.addEventListener('mythic-profile-loaded',restore);window.addEventListener('mythic-concept-profile',restore);
 window.addEventListener('mythic-account-signed-out',()=>{room=null;incoming=null;choice=null;restoreUser=null;lastRoomId=null;openedMatch=null;revision++;if(dialog.open)dialog.close();front(false);paint();});
 document.querySelectorAll('[data-view="custom"]').forEach(b=>b.addEventListener('click',()=>{restore();refresh();}));
 // Convite não modal na camada superior, reposicionável mesmo sobre painéis com transform.
 let drag=null,position=null;const grip=$('#custom-invitation-grip');
 function place(){if(popup.hidden)return;const v=window.visualViewport,w=v?.width||innerWidth,h=v?.height||innerHeight,x=v?.offsetLeft||0,y=v?.offsetTop||0,b=popup.getBoundingClientRect();position=position||{x:x+w-b.width-12,y:y+96};position.x=Math.max(x+12,Math.min(position.x,x+w-b.width-12));position.y=Math.max(y+12,Math.min(position.y,y+h-b.height-12));popup.style.left=position.x+'px';popup.style.top=position.y+'px';}
 grip.addEventListener('pointerdown',e=>{if(e.button!==0)return;place();drag={id:e.pointerId,x:e.clientX,y:e.clientY,px:position.x,py:position.y};grip.setPointerCapture(e.pointerId);});
 grip.addEventListener('pointermove',e=>{if(drag?.id!==e.pointerId)return;position={x:drag.px+e.clientX-drag.x,y:drag.py+e.clientY-drag.y};place();});
 for(const event of ['pointerup','pointercancel','lostpointercapture'])grip.addEventListener(event,()=>drag=null);
 grip.addEventListener('keydown',e=>{const d={ArrowLeft:[-12,0],ArrowRight:[12,0],ArrowUp:[0,-12],ArrowDown:[0,12]}[e.key];if(!d)return;e.preventDefault();place();position.x+=d[0];position.y+=d[1];place();});
 popup.addEventListener('toggle',e=>{if(e.newState==='open')requestAnimationFrame(place);});window.addEventListener('resize',place);window.visualViewport?.addEventListener('resize',place);window.visualViewport?.addEventListener('scroll',place);
 document.addEventListener('visibilitychange',()=>{if(!document.hidden){restore();refresh();pollInbox();}});
 setInterval(()=>{refresh();if(!dialog.open)pollInbox();},5000);restore();paint();
})();
