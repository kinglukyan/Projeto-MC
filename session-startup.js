/* Same loading presentation as match entry. Holds are tied to actual data work. */
(() => {
 'use strict';
 const tasks=new Map([['boot','PREPARANDO O HALL DE ENTRADA']]);let screen=null,serial=0,timeout=null;
 document.documentElement.classList.add('mythic-data-loading');
 let restore=false;
 try{for(let i=0;i<localStorage.length;i++){const key=localStorage.key(i);if(!/^sb-.+-auth-token$/.test(key))continue;const session=JSON.parse(localStorage.getItem(key)),id=session?.user?.id;if(!id)continue;const record=JSON.parse(localStorage.getItem('mythic-last-screen:'+id)||'null');if(record?.uid===id&&record.inGame&&Date.now()-Number(record.at)<30*86400000){restore=true;break;}}}catch{}
 if(restore)tasks.set('restore','RECUPERANDO SUA SESSÃO E SUA TELA');
 function mount(){if(!document.body)return null;screen=document.querySelector('#loading-screen');if(!screen){screen=document.createElement('section');screen.id='loading-screen';screen.className='loading-screen';screen.innerHTML='<span class="loading-emblem" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M12 2.5 14.5 9.5 21.5 12 14.5 14.5 12 21.5 9.5 14.5 2.5 12 9.5 9.5Z"/></svg></span><span class="loading-title">MYTHIC <b>CLASH</b></span><span class="loading-caption"></span><span class="loading-track" aria-hidden="true"><i></i></span>';document.body.append(screen);}screen.setAttribute('role','status');screen.setAttribute('aria-live','polite');return screen;}
 function slow(message){if(!tasks.size)return;mount();const caption=screen?.querySelector('.loading-caption');if(caption)caption.textContent=typeof message==='string'?message:'A CONEXÃO ESTÁ DEMORANDO. SEUS DADOS CONTINUAM SALVOS.';let retry=screen?.querySelector('.loading-retry');if(!retry&&screen){retry=document.createElement('button');retry.className='loading-retry';retry.type='button';retry.textContent='Tentar novamente';retry.onclick=()=>location.reload();screen.append(retry);}}
 function paint(){const id=++serial;if(tasks.size){document.documentElement.classList.add('mythic-data-loading');mount();if(screen){screen.hidden=false;screen.classList.remove('is-hidden');screen.setAttribute('aria-hidden','false');screen.querySelector('.loading-caption').textContent=[...tasks.values()].at(-1);screen.querySelector('.loading-retry')?.remove();}document.body?.setAttribute('aria-busy','true');clearTimeout(timeout);timeout=setTimeout(slow,20000);}else{clearTimeout(timeout);requestAnimationFrame(()=>requestAnimationFrame(()=>{if(id!==serial||tasks.size)return;document.documentElement.classList.remove('mythic-data-loading');document.body?.removeAttribute('aria-busy');if(screen){screen.classList.add('is-hidden');screen.setAttribute('aria-hidden','true');screen.hidden=true;}window.dispatchEvent(new Event('mythic-loading-ready'));}));}}
 function begin(key,label){tasks.set(key,label||'CARREGANDO DADOS');paint();return ()=>end(key);}
 function end(key){tasks.delete(key);paint();}
 async function release(publicOnly=false){if(publicOnly!==true)await window.MythicStartup?.stylesReady;end('restore');window.dispatchEvent(new Event('mythic-session-screen-ready'));}
 window.MythicLoading={begin,end,get pending(){return tasks.size>0;},get tasks(){return [...tasks.keys()];}};
 window.MythicSessionStartup={get pending(){return tasks.has('restore');},release};
 document.addEventListener('DOMContentLoaded',async()=>{paint();await window.MythicStartup?.stylesReady;end('boot');},{once:true});
 window.addEventListener('mythic-session-changed',e=>{if(!e.detail?.connected)end('restore');});
 window.addEventListener('mythic-account-signed-out',()=>{end('restore');end('account-entry');end('auth');});
 window.addEventListener('mythic-welcome-ready',e=>{if(e.detail?.stage&&e.detail.stage!=='completed')end('restore');});
 window.addEventListener('mythic-profile-error',()=>slow('NÃO FOI POSSÍVEL CARREGAR SEUS DADOS. TENTE NOVAMENTE.'));
 window.addEventListener('error',e=>{if(e.target?.tagName==='SCRIPT'&&/game-runtime/.test(e.target.src))slow();},true);
})();
