(() => {
 'use strict';
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const user=()=>window.MythicOnline?.userId?.(),key=()=>`mythic-video-replays:${user()||'guest'}`;
 const enabled=()=>{try{return !!user()&&localStorage.getItem(key())==='true';}catch{return false;}};
 const supported=!!(navigator.mediaDevices?.getDisplayMedia&&window.MediaRecorder&&window.indexedDB);
 let stream=null,recorder=null,session=null,pending=false,last=null,dbPromise=null,objectURL=null,writing=Promise.resolve(),libraryEpoch=0;
 const attempted=new Set();
 function db(){if(!dbPromise)dbPromise=new Promise((resolve,reject)=>{const request=indexedDB.open('mythic-video-replays',1);request.onupgradeneeded=()=>{const d=request.result;d.createObjectStore('videos',{keyPath:'id'});d.createObjectStore('chunks',{keyPath:['id','index']});};request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);});return dbPromise;}
 async function store(name,mode,work){const database=await db();return new Promise((resolve,reject)=>{const tx=database.transaction(name,mode);let result;try{result=work(tx.objectStore(name));}catch(error){tx.abort();reject(error);return;}tx.oncomplete=()=>resolve(result?.result);tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error||Error('Armazenamento interrompido.'));});}
 const status=el('p','video-replay-status');status.setAttribute('role','status');
 const settings=el('section','panel video-replay-settings');settings.append(el('h2','','Replays em vídeo'));
 const label=el('label','setting-row'),copy=el('span');copy.append(el('b','','Gravar minhas partidas'),el('small','','Ative e autorize a captura desta aba. Os vídeos ficam neste navegador e podem ser baixados no perfil.'));
 const toggle=el('input');toggle.type='checkbox';toggle.disabled=!supported;label.append(copy,toggle);settings.append(label);
 const authorize=el('button','button button-secondary','Autorizar captura desta aba');authorize.type='button';
 settings.append(authorize,status,el('small','','O navegador pede autorização novamente quando a captura termina. Atualizar ou fechar a página interrompe o vídeo. O áudio depende do navegador e da opção escolhida na autorização.'));
 const settingsForm=document.querySelector('#settings-form');settings.classList.add('concept-settings-group');settingsForm?.querySelector('.concept-settings-group')?.after(settings);
 const libraryButton=el('button','button button-secondary','Abrir meus replays');libraryButton.type='button';libraryButton.onclick=()=>{window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:'profile'}}));requestAnimationFrame(()=>[...document.querySelectorAll('.legend-tabs button')].find(b=>b.textContent==='Replays')?.click());};settings.append(libraryButton);
 const bar=el('div','video-replay-bar'),recordButton=el('button','button button-secondary','Autorizar gravação'),stop=el('button','button button-secondary','Parar e salvar vídeo'),indicator=el('span','','● Gravando replay');recordButton.type=stop.type='button';bar.append(indicator,recordButton,stop);bar.hidden=true;document.body.append(bar);
 const legacy=document.querySelector('.profile-replays');if(legacy)for(const child of legacy.children)child.hidden=true;
 const library=el('section','video-replay-library');library.append(el('h2','','Replays em vídeo'),el('p','','Gravações desta conta salvas neste navegador. Baixe os vídeos para guardar uma cópia.'));
 const list=el('div'),player=el('video');player.controls=true;player.playsInline=true;player.preload='metadata';player.hidden=true;library.append(list,player);legacy?.append(library);
 function info(message){status.textContent=message;}
 function release(){const active=stream;stream=null;active?.getTracks().forEach(t=>t.stop());}
 function paint(){toggle.checked=enabled();authorize.disabled=!supported||!user()||pending||!!recorder;authorize.textContent=stream?'Captura autorizada nesta sessão':'Autorizar captura desta aba';bar.hidden=!enabled()||!last||last.finished||document.querySelector('#view-duel')?.hidden;indicator.hidden=!recorder;recordButton.hidden=!!recorder;recordButton.disabled=pending||!supported;stop.hidden=!recorder;if(!supported)info('A gravação de tela não está disponível neste navegador.');}
 async function request(){
  if(pending||!enabled()||!supported||stream)return;pending=true;paint();const owner=user();
  try{const capture=await navigator.mediaDevices.getDisplayMedia({video:{frameRate:{ideal:30,max:30},displaySurface:'browser'},audio:true,preferCurrentTab:true});if(owner!==user()||!enabled()){capture.getTracks().forEach(t=>t.stop());return;}stream=capture;stream.getVideoTracks()[0].addEventListener('ended',()=>finish('Captura encerrada'));info('Captura autorizada. A gravação começa ao entrar na partida.');if(last&&!last.finished&&!document.querySelector('#view-duel')?.hidden)start();}
  catch(error){info(error.name==='NotAllowedError'?'Captura não autorizada. Você pode continuar jogando sem gravar.':'Não foi possível iniciar a captura. Tente autorizar novamente.');}
  finally{pending=false;paint();}
 }
 async function start(){
  if(recorder||!stream||!last||last.finished||!enabled()||session)return;
  const mime=['video/webm;codecs=vp9,opus','video/webm;codecs=vp8,opus','video/webm','video/mp4'].find(type=>MediaRecorder.isTypeSupported(type));
  const meta={id:crypto.randomUUID(),owner:user(),matchId:last.id,title:`${last.mode} · ${new Date().toLocaleString('pt-BR')}`,startedAt:Date.now(),endedAt:null,mime:mime||'',bytes:0,parts:0,status:'recording'};
  const captured=stream;
  try{const video=new MediaRecorder(captured,{...(mime?{mimeType:mime}:{}),videoBitsPerSecond:3500000});session=meta;recorder=video;meta.mime=video.mimeType||mime;await store('videos','readwrite',table=>table.put({...meta}));if(meta.owner!==user()||!enabled()||!stream||session!==meta){recorder=null;session=null;release();paint();return;}
   video.ondataavailable=e=>{if(!e.data.size)return;const index=meta.parts++;meta.bytes+=e.data.size;writing=writing.then(async()=>{await store('chunks','readwrite',table=>table.put({id:meta.id,index,blob:e.data}));await store('videos','readwrite',table=>table.put({...meta}));}).catch(()=>{info('Sem espaço para continuar. Libere espaço ou baixe as gravações já salvas.');finish('Gravação interrompida por falta de espaço');});if(meta.bytes>512*1024*1024)finish('Limite de 512 MB atingido. A parte gravada foi salva.');};
   video.onerror=()=>finish('Gravação interrompida pelo navegador');video.onstop=()=>{meta.endedAt=Date.now();meta.status='saved';writing=writing.then(()=>store('videos','readwrite',table=>table.put({...meta}))).then(()=>{if(meta.owner===user())renderLibrary();}).catch(()=>info('Não foi possível confirmar o salvamento. Confira os vídeos no perfil.'));if(session===meta){session=null;recorder=null;}paint();};
   video.start(5000);attempted.add(last.id);info('Replay sendo gravado.');paint();
  }catch{recorder=null;session=null;release();info('Não foi possível gravar neste navegador. A partida pode continuar normalmente.');paint();}
 }
 function finish(message='Vídeo salvo no perfil'){
  if(recorder&&recorder.state!=='inactive'){try{recorder.stop();}catch{}}release();if(message)info(message);paint();
 }
 function sync(duel){const id=duel.onlineMatchId||duel.localMatchId||duel.startedAt;if(!id)return;const mode=duel.guardianCampaign?'Atlas':duel.practice?'Teste':duel.onlineMode==='ranked'?'Ranqueada':duel.onlineMode==='friend'?'Personalizada':duel.online?'Normal':'Guardião';if(last&&last.id!==String(id)&&recorder)finish();last={id:String(id),finished:!!duel.finished,mode};if(last.finished){if(recorder)finish();}else if(enabled()&&stream&&!recorder&&!attempted.has(last.id))start();paint();}
 async function renderLibrary(){
  const epoch=++libraryEpoch;player.pause();player.removeAttribute('src');player.hidden=true;if(objectURL){URL.revokeObjectURL(objectURL);objectURL=null;}const owner=user();list.replaceChildren();if(!owner){list.append(el('p','','Entre na conta para ver seus vídeos.'));return;}if(!supported){list.append(el('p','','Este navegador não oferece gravação de tela.'));return;}
  try{const rows=(await store('videos','readonly',table=>table.getAll())).filter(row=>row.owner===owner).sort((a,b)=>b.startedAt-a.startedAt);if(owner!==user()||epoch!==libraryEpoch)return;if(!rows.length)list.append(el('p','','Nenhum vídeo gravado. Ative a gravação nas configurações antes da próxima partida.'));
   for(const row of rows){const item=el('article','community-row'),text=el('span');text.append(el('b','',row.title),el('small','',`${(row.bytes/1048576).toFixed(1)} MB${row.status==='recording'?' · gravação em andamento ou interrompida':''}`));item.append(text);
    async function blob(){await writing;const parts=await store('chunks','readonly',table=>table.getAll(IDBKeyRange.bound([row.id,0],[row.id,Number.MAX_SAFE_INTEGER])));if(user()!==owner)throw Error('Conta alterada');return new Blob(parts.sort((a,b)=>a.index-b.index).map(p=>p.blob),{type:row.mime});}
    const play=el('button','button button-secondary','Assistir'),download=el('button','button button-secondary','Baixar'),remove=el('button','button button-secondary','Excluir');for(const b of [play,download,remove])b.type='button';
    play.onclick=async()=>{try{const data=await blob();if(!data.size)return;if(objectURL)URL.revokeObjectURL(objectURL);objectURL=URL.createObjectURL(data);player.src=objectURL;player.hidden=false;player.play().catch(()=>{});}catch{info('Não foi possível abrir este vídeo.');}};
    download.onclick=async()=>{try{const data=await blob(),url=URL.createObjectURL(data),link=el('a');link.href=url;link.download=`Mythic-Clash-${new Date(row.startedAt).toISOString().replace(/[:.]/g,'-')}.${row.mime.includes('mp4')?'mp4':'webm'}`;link.click();setTimeout(()=>URL.revokeObjectURL(url),30000);}catch{info('Não foi possível baixar este vídeo.');}};
    remove.disabled=session?.id===row.id;remove.onclick=async()=>{try{await store('chunks','readwrite',table=>table.delete(IDBKeyRange.bound([row.id,0],[row.id,Number.MAX_SAFE_INTEGER])));await store('videos','readwrite',table=>table.delete(row.id));renderLibrary();}catch{info('Não foi possível excluir este vídeo.');}};item.append(play,download,remove);list.append(item);
   }
  }catch{list.append(el('p','','O navegador bloqueou o armazenamento de vídeos. Verifique as permissões e o espaço disponível.'));}
 }
 toggle.onchange=()=>{try{localStorage.setItem(key(),String(toggle.checked));}catch{info('O navegador bloqueou esta preferência.');}if(toggle.checked)request();else finish('Gravação desativada.');paint();};
 authorize.onclick=request;recordButton.onclick=request;stop.onclick=()=>finish();
 window.addEventListener('mythic-view-changed',e=>{if(recorder?.state==='recording'&&e.detail?.view!=='duel')recorder.pause();else if(recorder?.state==='paused'&&e.detail?.view==='duel')recorder.resume();if(e.detail?.view==='profile')renderLibrary();paint();});
 window.addEventListener('mythic-account-signed-out',()=>{finish();last=null;attempted.clear();paint();renderLibrary();});
 window.addEventListener('mythic-profile-loaded',()=>{if(session&&session.owner!==user())finish();paint();});
 window.addEventListener('pagehide',()=>finish(''));window.MythicVideoReplay={sync,stop:finish};paint();
})();
