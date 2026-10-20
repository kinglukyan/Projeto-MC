(() => {
 'use strict';
 let queued=null,ready=false,noticeTimer=0,fontsLoaded=false;
 function loadFonts(){if(fontsLoaded||!document.body||document.body.classList.contains('public-home-open')||window.MythicWelcome?.isOpen?.())return;fontsLoaded=true;const link=document.createElement('link');link.rel='stylesheet';link.href=sheet()?.dataset.fonts||'game-fonts.css';document.head.append(link);}
 const sheet=()=>document.querySelector('#mythic-game-styles');
 let resolveStyles;const stylesReady=new Promise(resolve=>resolveStyles=resolve);
 function styles(){const link=sheet();if(!link){setTimeout(styles,20);return;}const apply=()=>{link.media='all';ready=true;resolveStyles();window.dispatchEvent(new Event('mythic-styles-ready'));};if(link.sheet)apply();else{link.addEventListener('load',apply,{once:true});link.addEventListener('error',()=>message('Não foi possível carregar a interface. Confira sua conexão e tente novamente.',true),{once:true});}}
 function message(text,retry=false){if(!document.body)return;let n=document.querySelector('#startup-status');if(!n){n=document.createElement('p');n.id='startup-status';n.className='startup-status';n.setAttribute('role','status');document.body.prepend(n);}n.replaceChildren(document.createTextNode(text));n.hidden=!text;if(retry){const b=document.createElement('button');b.type='button';b.textContent='Tentar novamente';b.onclick=()=>location.reload();n.append(b);}}
 async function open(mode){if(window.MythicPortal?.openAuth){await stylesReady;clearTimeout(noticeTimer);message('');window.MythicPortal.openAuth(mode);queued=null;return;}queued=mode;message('Preparando seu acesso… Você já pode explorar o hall.');clearTimeout(noticeTimer);noticeTimer=setTimeout(()=>{if(queued)message('O acesso está levando mais tempo que o esperado. Confira sua conexão ou tente novamente.',true);},12000);}
 document.addEventListener('click',event=>{const control=event.target.closest('[data-entry-auth]');if(!control)return;event.preventDefault();open(control.dataset.entryAuth);});
 function onReady(){if(!queued&&['#login','#criar-conta'].includes(location.hash))queued=location.hash==='#login'?'signin':'signup';if(queued)open(queued);new MutationObserver(loadFonts).observe(document.body,{attributes:true,attributeFilter:['class']});loadFonts();}
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',onReady,{once:true});else onReady();
 window.addEventListener('mythic-welcome-closed',loadFonts);
 window.MythicStartup={stylesReady,get stylesLoaded(){return ready;},deferBackground(node,src){node.dataset.entryBackground=src;if(!window.IntersectionObserver){node.style.backgroundImage=`url("${src}")`;return;}const observer=new IntersectionObserver(entries=>{for(const e of entries)if(e.isIntersecting){node.style.backgroundImage=`url("${node.dataset.entryBackground}")`;observer.disconnect();}},{rootMargin:'180px'});observer.observe(node);}};
 styles();
})();
