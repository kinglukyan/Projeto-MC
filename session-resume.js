(() => {
 'use strict';
 const api=()=>window.MythicOnline,game=()=>window.MythicGame?.current?.()||{},key=uid=>'mythic-last-screen:'+uid;
 const allowed=new Set(['arena','decks','collection','lore','guilds','community-decks','custom','queue','guardian','profile','friends','store','settings','duel','match-report','admin']);
 let uid=null,saved=null,done=false,working=false,revision=0,timer=null,scrollTimer=null,banner=null;
 function capture(){const next=api()?.userId?.();if(next===uid)return;uid=next;done=false;working=false;revision++;try{saved=uid?JSON.parse(localStorage.getItem(key(uid))):null;}catch{saved=null;}if(saved?.uid!==uid)saved=null;}
 function persist(){capture();if(!uid||!api()?.profileReady?.()||window.MythicWelcome?.getStage?.()!=='completed'||working)return;const current=game(),record={uid,view:allowed.has(current.view)?current.view:'arena',scroll:Math.max(0,Math.round(scrollY)),inGame:!document.body.classList.contains('public-home-open'),matchId:current.matchId||null,at:Date.now()};if(record.view!=='duel'&&record.view!=='match-report')record.matchId=null;try{localStorage.setItem(key(uid),JSON.stringify(record));}catch{}}
 function offer(text){if(!banner){banner=document.createElement('aside');banner.className='resume-banner';banner.setAttribute('role','status');document.body.append(banner);}banner.replaceChildren(document.createTextNode(text));const retry=document.createElement('button');retry.type='button';retry.textContent='Tentar retomar';retry.onclick=()=>{done=false;attempt(true);};banner.append(retry);banner.hidden=false;}
 async function attempt(force=false){capture();if(!uid||done||working||!api()?.profileReady?.())return;
  if(window.MythicWelcome?.getStage?.()!=='completed'||window.MythicWelcome?.isOpen?.()){clearTimeout(timer);if(!window.MythicWelcome?.getStage?.()||window.MythicWelcome.getStage()==='idle')timer=setTimeout(()=>attempt(),600);return;}
  if(api().activeMatchId?.()){done=true;persist();return;}
  working=true;const owner=uid,nav=revision,record=saved&&Date.now()-Number(saved.at)<30*86400000?saved:null;
  try{const result=await api().portalRequest('resume_my_game',{p_match_id:/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(record?.matchId||'')?record.matchId:null});if(owner!==api()?.userId?.())return;done=true;
   if(result?.matchId){if(!force&&revision!==nav&&record?.matchId!==result.matchId){offer('Você tem uma partida para retomar.');return;}if(result.roomId)window.MythicCustomLobby?.attachMatch?.(result.matchId,result.roomId);if(result.status!=='active'&&record?.view==='match-report')window.MythicGame.resumeAsReport();await api().openMatch(result.matchId);if(api().activeMatchId?.()!==result.matchId)throw Error('Não foi possível abrir a partida.');if(banner)banner.hidden=true;return;}
   await api().resumeSavedQueue?.();if(api().activeMatchId?.())return;
   if(record?.inGame&&revision===nav&&!game().local){let view=record.view==='direct'?'custom':record.view;if(!allowed.has(view)||['duel','match-report'].includes(view)||view==='admin'&&!api().isAdmin())view='arena';if(view==='queue')api().openQueueLobby(localStorage.getItem('mythic-last-queue-mode:'+owner)||'normal');window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view}}));setTimeout(()=>{if(owner===api()?.userId?.())window.scrollTo({top:Math.min(Number(record.scroll)||0,document.documentElement.scrollHeight-innerHeight),behavior:'auto'});},200);}
   if(banner)banner.hidden=true;
  }catch{done=false;if(record?.matchId)offer('Não foi possível confirmar sua partida. Seu progresso online permanece no servidor.');else if(record?.inGame&&revision===nav&&!game().local&&allowed.has(record.view)&&!['duel','match-report','admin'].includes(record.view))window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:record.view}}));}
  finally{if(owner===uid){working=false;if(done)persist();}}
 }
 window.addEventListener('mythic-view-changed',()=>{revision++;persist();});window.addEventListener('mythic-online-match',()=>{done=true;setTimeout(persist,0);});
 window.addEventListener('mythic-profile-loaded',()=>{capture();attempt();});window.addEventListener('mythic-welcome-closed',()=>setTimeout(()=>attempt(),150));
 window.addEventListener('pagehide',persist);window.addEventListener('scroll',()=>{clearTimeout(scrollTimer);scrollTimer=setTimeout(persist,300);},{passive:true});
 window.addEventListener('online',()=>{if(!api()?.activeMatchId?.())attempt(true);});
 window.addEventListener('mythic-account-signed-out',()=>{uid=null;saved=null;done=false;working=false;revision++;clearTimeout(timer);if(banner)banner.hidden=true;});
 const bodyObserver=new MutationObserver(()=>{if(!working)persist();});bodyObserver.observe(document.body,{attributes:true,attributeFilter:['class']});capture();attempt();
})();
