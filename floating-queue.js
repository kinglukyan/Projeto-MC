(() => {
 'use strict';
 const node=(tag,cls,text)=>{const n=document.createElement(tag);n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const panel=node('aside','floating-queue');panel.hidden=true;panel.setAttribute('aria-label','Busca de partida');
 const grip=node('button','floating-queue-grip');grip.type='button';grip.setAttribute('aria-label','Mover janela da fila. Use as setas do teclado ou arraste.');
 const dot=node('i','floating-queue-dot'),heading=node('span','','Buscando partida'),handle=node('span','floating-queue-handle','⠿');handle.setAttribute('aria-hidden','true');grip.append(dot,heading,handle);
 const info=node('div','floating-queue-info'),mode=node('span','floating-queue-mode'),time=node('b','floating-queue-time','00:00');time.setAttribute('aria-label','Tempo em fila');
 info.append(mode,time);const status=node('p','floating-queue-status');status.setAttribute('role','status');
 const actions=node('div','floating-queue-actions'),back=node('button','floating-queue-back','Voltar à sala'),cancel=node('button','floating-queue-cancel','Sair da fila');
 back.type=cancel.type='button';actions.append(back,cancel);panel.append(grip,info,status,actions);document.body.append(panel);
 let state={active:false},ticker=null,position=null,drag=null,leaving=false,positionOwner=null;
 const key=()=>{const uid=window.MythicOnline?.userId?.();return uid?'mythic-queue-position:'+uid:null;};
 function viewport(){const v=window.visualViewport;return {left:v?.offsetLeft||0,top:v?.offsetTop||0,width:v?.width||innerWidth,height:v?.height||innerHeight};}
 function place(){if(panel.hidden)return;const v=viewport(),r=panel.getBoundingClientRect(),gap=12;
  const p=position||{x:v.left+v.width-r.width-gap,y:v.top+v.height-r.height-24};
  position={x:Math.max(v.left+gap,Math.min(p.x,v.left+v.width-r.width-gap)),y:Math.max(v.top+gap,Math.min(p.y,v.top+v.height-r.height-gap))};
  panel.style.left=position.x+'px';panel.style.top=position.y+'px';
 }
 function savePosition(){try{const id=key();if(id&&position)localStorage.setItem(id,JSON.stringify(position));}catch{}}
 function tick(){if(!state.active)return;const seconds=state.startedAt?Math.max(0,Math.floor((Date.now()-state.startedAt)/1000)):0;time.textContent=String(Math.floor(seconds/60)).padStart(2,'0')+':'+String(seconds%60).padStart(2,'0');}
 function render(next){state=next||{active:false};panel.hidden=!state.active;clearInterval(ticker);ticker=null;
  if(!state.active){drag=null;leaving=false;panel.classList.remove('dragging');return;}
  const owner=key();if(owner!==positionOwner){positionOwner=owner;position=null;try{const p=JSON.parse(localStorage.getItem(owner));if(Number.isFinite(p?.x)&&Number.isFinite(p?.y))position=p;}catch{}}
  mode.textContent=(state.mode==='ranked'?'Ranqueada':'Normal')+' · '+(state.format==='duo'?'2 × 2':'1 × 1');
  heading.textContent=state.phase==='inviting'?'Aguardando parceiro':state.phase==='joining'?'Entrando na fila':'Buscando partida';
  status.textContent=state.phase==='inviting'?'O tempo começa quando sua dupla for formada.':state.phase==='joining'?'Confirmando sua entrada…':'Pode explorar o jogo. Avisaremos quando encontrar.';
  cancel.disabled=leaving||state.phase==='joining';cancel.textContent=leaving?'Saindo…':'Sair da fila';
  tick();if(state.phase==='queued')ticker=setInterval(tick,1000);requestAnimationFrame(place);
 }
 back.addEventListener('click',()=>{
  const current=window.MythicOnline?.getQueueState?.();if(!current?.active)return;
  window.MythicOnline?.openQueueLobby?.(current.mode);
  window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:'queue'}}));

  document.querySelector('#view-queue')?.scrollIntoView({block:'start',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
 });
 cancel.addEventListener('click',async()=>{if(leaving||state.phase==='joining')return;leaving=true;cancel.disabled=true;cancel.textContent='Saindo…';try{await window.MythicOnline?.cancelQueue?.();}finally{leaving=false;render(window.MythicOnline?.getQueueState?.());}});
 grip.addEventListener('pointerdown',event=>{if(event.button!==0||!event.isPrimary)return;place();drag={id:event.pointerId,x:event.clientX,y:event.clientY,startX:position.x,startY:position.y};grip.setPointerCapture(event.pointerId);panel.classList.add('dragging');});
 grip.addEventListener('pointermove',event=>{if(drag?.id!==event.pointerId)return;position={x:drag.startX+event.clientX-drag.x,y:drag.startY+event.clientY-drag.y};place();});
 const end=event=>{if(drag?.id!==event.pointerId)return;drag=null;panel.classList.remove('dragging');if(grip.hasPointerCapture(event.pointerId))grip.releasePointerCapture(event.pointerId);savePosition();};
 grip.addEventListener('pointerup',end);grip.addEventListener('pointercancel',end);grip.addEventListener('lostpointercapture',()=>{drag=null;panel.classList.remove('dragging');});
 grip.addEventListener('keydown',event=>{const moves={ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]},m=moves[event.key];if(!m)return;event.preventDefault();place();const distance=event.shiftKey?1:12;position={x:position.x+m[0]*distance,y:position.y+m[1]*distance};place();savePosition();});
 window.addEventListener('mythic-queue-state',event=>render(event.detail));
 window.addEventListener('mythic-account-signed-out',()=>{position=null;positionOwner=null;render(null);});
 window.addEventListener('resize',place);window.visualViewport?.addEventListener('resize',place);window.visualViewport?.addEventListener('scroll',place);
 document.addEventListener('visibilitychange',()=>{if(!document.hidden){tick();place();}});
 render(window.MythicOnline?.getQueueState?.());
})();
