/* Runs before the first paint. Stored data only chooses a loading cover,
   never authenticates the account or grants access to a saved screen. */
(() => {
 'use strict';
 let pending=false,screen=null,timeout=null,releasing=null;
 try{
  for(let i=0;i<localStorage.length;i++){
   const name=localStorage.key(i);if(!/^sb-.+-auth-token$/.test(name))continue;
   let session,record;try{session=JSON.parse(localStorage.getItem(name));const id=session?.user?.id;if(!id)continue;record=JSON.parse(localStorage.getItem('mythic-last-screen:'+id));if(record?.uid!==id)continue;}catch{continue;}
   const age=Date.now()-Number(record?.at);
   if(record?.inGame===true&&age>=0&&age<30*86400000){pending=true;break;}
  }
 }catch{}
 if(pending)document.documentElement.classList.add('session-restore-pending');
 function mount(){
  if(!pending||screen||!document.body)return;
  screen=document.createElement('section');screen.id='session-startup-screen';screen.setAttribute('role','status');screen.setAttribute('aria-live','polite');
  const star=document.createElement('span');star.className='session-startup-star';star.textContent='✦';star.setAttribute('aria-hidden','true');
  const brand=document.createElement('strong');brand.textContent='MYTHIC CLASH';
  const copy=document.createElement('p');copy.textContent='Retomando sua jornada…';screen.append(star,brand,copy);document.body.append(screen);
 }
 async function release(publicOnly=false){
  if(!pending)return;if(releasing)return releasing;
  releasing=(async()=>{if(publicOnly!==true)await window.MythicStartup?.stylesReady;await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));pending=false;clearTimeout(timeout);document.documentElement.classList.remove('session-restore-pending');screen?.remove();screen=null;window.dispatchEvent(new Event('mythic-session-screen-ready'));})();return releasing;
 }
 function stalled(){
  if(!pending)return;mount();if(!screen)return;
  screen.querySelector('p').textContent='A recuperação está demorando. Confira sua conexão e tente novamente.';
  const actions=document.createElement('div'),retry=document.createElement('button'),home=document.createElement('button');
  retry.type=home.type='button';retry.textContent='Tentar novamente';retry.onclick=()=>location.reload();
  home.textContent='Ir para o início';home.onclick=()=>{window.dispatchEvent(new Event('mythic-session-restore-cancelled'));window.MythicPortal?.showHome?.();release(true);};actions.append(retry,home);screen.append(actions);
 }
 window.MythicSessionStartup={get pending(){return pending;},release};
 if(pending){if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mount,{once:true});else mount();timeout=setTimeout(stalled,15000);}
 window.addEventListener('mythic-session-changed',event=>{if(event.detail?.connected===false)release();});
 window.addEventListener('mythic-account-signed-out',release);
 window.addEventListener('mythic-welcome-ready',event=>{if(event.detail?.stage&&event.detail.stage!=='completed')release();});
})();
