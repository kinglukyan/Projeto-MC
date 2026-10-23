/* release-stamp.js */
window.MythicRelease=Object.freeze({id:"f45ac4042e76e0b89ab2",version:"2026.10.23.8"});

;
/* browser-compat.js */
/* Capability based fallbacks; no browser-name sniffing. */
(() => {
 'use strict';
 const root=document.documentElement;
 if(!Array.prototype.at)Object.defineProperty(Array.prototype,'at',{value:function(index){index=Math.trunc(Number(index)||0);return this[index<0?this.length+index:index];},configurable:true,writable:true});
 if(!window.requestIdleCallback)window.requestIdleCallback=(callback,options)=>setTimeout(()=>callback({didTimeout:true,timeRemaining:()=>0}),Math.min(options?.timeout||50,50));
 if(!window.cancelIdleCallback)window.cancelIdleCallback=clearTimeout;
 if(window.crypto&&!crypto.randomUUID&&crypto.getRandomValues)crypto.randomUUID=()=>{const a=crypto.getRandomValues(new Uint8Array(16));a[6]=(a[6]&15)|64;a[8]=(a[8]&63)|128;const h=[...a].map(n=>n.toString(16).padStart(2,'0')).join('');return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20)}`;};
 let popover=false;try{document.createElement('div').matches(':popover-open');popover=typeof HTMLElement.prototype.showPopover==='function';}catch{}
 if(!popover){const matches=Element.prototype.matches;Element.prototype.matches=function(selector){if(selector===':popover-open')return this.hasAttribute('data-compat-popover-open');return matches.call(this,selector);};HTMLElement.prototype.showPopover=function(){this.hidden=false;this.setAttribute('data-compat-popover-open','');};HTMLElement.prototype.hidePopover=function(){this.removeAttribute('data-compat-popover-open');};root.classList.add('compat-popover');}
 const dialogPrototype=window.HTMLDialogElement?.prototype||HTMLElement.prototype;
 if(!dialogPrototype.showModal){const focus=new WeakMap(),covers=new WeakMap();root.classList.add('compat-dialog');dialogPrototype.showModal=function(){if(this.tagName!=='DIALOG'||this.hasAttribute('open'))return;focus.set(this,document.activeElement);const cover=document.createElement('div');cover.className='compat-dialog-cover';cover.onclick=()=>this.dispatchEvent(new MouseEvent('click',{bubbles:true}));document.body.append(cover);covers.set(this,cover);this.setAttribute('open','');this.setAttribute('aria-modal','true');this.setAttribute('role','dialog');(this.querySelector('[autofocus],button,input,select,textarea,a[href]')||this).focus();};dialogPrototype.close=function(value=''){if(this.tagName!=='DIALOG')return;this.returnValue=value;this.removeAttribute('open');covers.get(this)?.remove();covers.delete(this);this.dispatchEvent(new Event('close'));focus.get(this)?.focus?.({preventScroll:true});};document.addEventListener('keydown',event=>{const dialogs=[...document.querySelectorAll('dialog[open]')],d=dialogs.at(-1);if(!d)return;if(event.key==='Escape'){const cancel=new Event('cancel',{cancelable:true});if(d.dispatchEvent(cancel))d.close();event.preventDefault();}else if(event.key==='Tab'){const items=[...d.querySelectorAll('button,input,select,textarea,a[href],[tabindex]')].filter(n=>!n.disabled&&n.tabIndex>=0&&!n.hidden);if(!items.length){event.preventDefault();return;}if(event.shiftKey&&document.activeElement===items[0]){event.preventDefault();items.at(-1).focus();}else if(!event.shiftKey&&document.activeElement===items.at(-1)){event.preventDefault();items[0].focus();}}});}
 const viewport=()=>root.style.setProperty('--mythic-vh',`${(window.visualViewport?.height||innerHeight)*.01}px`);viewport();window.addEventListener('resize',viewport,{passive:true});window.visualViewport?.addEventListener('resize',viewport,{passive:true});
 const reduced=matchMedia('(prefers-reduced-motion: reduce)');root.classList.toggle('low-effects',reduced.matches||Boolean(navigator.connection?.saveData)||(navigator.deviceMemory||8)<=2);
})();

;
/* session-startup.js */
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

;
/* entry-startup.js */
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

;