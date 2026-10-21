(() => {
 'use strict';
 const api=()=>window.MythicOnline,game=()=>window.MythicGame?.current?.()||{},key=id=>'mythic-last-screen:'+id;
 const allowed=new Set(['arena','decks','collection','lore','guilds','community-decks','custom','queue','guardian','profile','friends','store','settings','duel','admin','tournaments']);
 let uid=null,saved=null,done=false,working=false,revision=0,epoch=0,timer=null,scrollTimer=null,banner=null,restoredScroll=null,explicitLogin=false;
 function capture(){
  const next=api()?.userId?.();if(next===uid)return;uid=next;done=false;working=false;revision++;epoch++;
  try{saved=uid?JSON.parse(localStorage.getItem(key(uid))):null;}catch{saved=null;}
  if(saved?.uid!==uid)saved=null;
  // A report is a finished screen, never a resumable battle.
  if(saved?.view==='match-report')saved={...saved,view:'arena',matchId:null,scroll:0};
 }
 function persist(){
  capture();if(!uid||!api()?.profileReady?.()||window.MythicWelcome?.getStage?.()!=='completed'||working||window.MythicSessionStartup?.pending)return;
  const current=game(),finished=current.finished||current.view==='match-report',view=finished?'arena':allowed.has(current.view)?current.view:'arena';
  const record={uid,view,scroll:finished?0:Math.max(0,Math.round(scrollY)),inGame:!document.body.classList.contains('public-home-open'),matchId:view==='duel'&&!finished?current.matchId||null:null,at:Date.now()};
  try{localStorage.setItem(key(uid),JSON.stringify(record));}catch{}
 }
 function offer(text){
  if(!banner){banner=document.createElement('aside');banner.className='resume-banner';banner.setAttribute('role','status');document.body.append(banner);}
  banner.replaceChildren(document.createTextNode(text));const retry=document.createElement('button');retry.type='button';retry.textContent='Retomar partida';retry.onclick=()=>{done=false;attempt(true);};banner.append(retry);banner.hidden=false;
 }
 function restoreView(record,nav,owner){
  if(!record?.inGame||revision!==nav||game().local)return;
  let view=record.view==='direct'?'custom':record.view;
  if(!allowed.has(view)||view==='duel'||view==='admin'&&!api().isAdmin())view='arena';
  if(view==='queue')api().openQueueLobby(localStorage.getItem('mythic-last-queue-mode:'+owner)||'normal');
  window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view}}));
  if(view===record.view)restoredScroll={owner,scroll:Number(record.scroll)||0};
  if(view===record.view)setTimeout(()=>{if(owner===api()?.userId?.())window.scrollTo({top:Math.min(Number(record.scroll)||0,Math.max(0,document.documentElement.scrollHeight-innerHeight)),behavior:'auto'});},200);
 }
 async function finishStartup(record,owner){
  if(!window.MythicSessionStartup?.pending||owner!==api()?.userId?.())return;
  const inGame=record?.inGame||api()?.activeMatchId?.()||api()?.getQueueState?.().active||game().local;
  if(inGame&&!await window.MythicPortal?.enterGame?.())return;
  await window.MythicStartup?.stylesReady;if(owner!==api()?.userId?.())return;
  if(restoredScroll?.owner===owner){const top=restoredScroll.scroll;await new Promise(resolve=>requestAnimationFrame(()=>{window.scrollTo({top:Math.min(top,Math.max(0,document.documentElement.scrollHeight-innerHeight)),behavior:'instant'});resolve();}));restoredScroll=null;}
  await window.MythicSessionStartup.release();persist();
 }
 async function attempt(force=false){
  capture();if(!uid||(done&&!force)||working||!api()?.profileReady?.())return;
  if(window.MythicWelcome?.getStage?.()!=='completed'||window.MythicWelcome?.isOpen?.()){
   clearTimeout(timer);if(!window.MythicWelcome?.getStage?.()||window.MythicWelcome.getStage()==='idle')timer=setTimeout(()=>attempt(),600);return;
  }
  if(explicitLogin){explicitLogin=false;done=true;saved=null;working=true;const who=uid,version=epoch;try{const ready=await window.MythicPortal?.enterGame?.();if(ready&&who===api()?.userId?.()&&version===epoch)window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:'arena'}}));}finally{if(who===api()?.userId?.()&&version===epoch){working=false;persist();}}return;}
  if(api().activeMatchId?.()){done=true;await finishStartup(saved,uid);persist();return;}
  working=true;const owner=uid,token=epoch,nav=revision,record=saved&&Date.now()-Number(saved.at)<30*86400000?saved:null;
  const current=()=>owner===api()?.userId?.()&&token===epoch;
  try{
   // A null hint also makes older versions of the RPC return active matches only.
   const result=await api().portalRequest('resume_my_game',{p_match_id:null});if(!current())return;done=true;
   if(result?.matchId&&result.status==='active'){
    if(!force&&revision!==nav&&record?.matchId!==result.matchId){offer('Você tem uma partida em andamento.');return;}
    if(result.roomId)window.MythicCustomLobby?.attachMatch?.(result.matchId,result.roomId);
    const opened=await api().openMatch(result.matchId);if(!current())return;
    if(opened&&api().activeMatchId?.()===result.matchId){if(banner)banner.hidden=true;return;}
    // It may have ended between lookup and opening. Continue to a normal screen.
   }
   if(!force&&revision!==nav&&record?.view==='duel'){restoreView(record,nav,owner);return;}
   if(await window.MythicGuardianCampaign?.resumeSaved?.(record)){if(banner)banner.hidden=true;return;}if(!current())return;
   await api().resumeSavedQueue?.();if(!current())return;
   if(api().activeMatchId?.()||api().getQueueState?.().active){if(banner)banner.hidden=true;return;}
   if(window.MythicGame?.resumeLocalDuel?.()){if(banner)banner.hidden=true;return;}
   restoreView(record,nav,owner);if(banner)banner.hidden=true;
  }catch{
   if(!current())return;done=false;
   if(record?.matchId&&record.view==='duel')offer('Não foi possível consultar sua partida em andamento. Tente retomar novamente.');
   else restoreView(record,nav,owner);
  }finally{if(current()){try{await finishStartup(record,owner);}finally{working=false;if(done)persist();}}}
 }
 window.addEventListener('mythic-view-changed',()=>{revision++;persist();});
 window.addEventListener('mythic-online-match',()=>{done=true;setTimeout(persist,0);});
 window.addEventListener('mythic-profile-loaded',()=>{capture();attempt();});
 window.addEventListener('mythic-welcome-ready',()=>attempt());
 window.addEventListener('mythic-welcome-closed',()=>setTimeout(()=>attempt(),150));
 window.addEventListener('mythic-explicit-login',()=>{explicitLogin=true;saved=null;done=false;revision++;epoch++;});
 window.addEventListener('pagehide',persist);
 window.addEventListener('scroll',()=>{clearTimeout(scrollTimer);scrollTimer=setTimeout(persist,300);},{passive:true});
 window.addEventListener('online',()=>{if(!api()?.activeMatchId?.())attempt(true);});
 window.addEventListener('mythic-account-signed-out',()=>{uid=null;saved=null;done=false;working=false;explicitLogin=false;revision++;epoch++;clearTimeout(timer);if(banner)banner.hidden=true;});
 window.addEventListener('mythic-session-restore-cancelled',()=>{done=true;working=false;revision++;epoch++;restoredScroll=null;clearTimeout(timer);});
 const bodyObserver=new MutationObserver(()=>{if(!working)persist();});bodyObserver.observe(document.body,{attributes:true,attributeFilter:['class']});capture();attempt();
})();
