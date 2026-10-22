(() => {
 'use strict';
 const sidebar=document.querySelector('.app-shell>.sidebar');
 const main=document.querySelector('.app-shell>.main-content');
 const topbar=main?.querySelector(':scope>.topbar');
 if(!sidebar||!main||!topbar)return;

 // Keep the actual navigation nodes, their IDs, listeners and live player data.
 const scroll=document.createElement('div');
 scroll.className='arcane-nav-scroll';
 scroll.setAttribute('aria-label','Menu principal');
 const groups=[...sidebar.querySelectorAll(':scope>.nav-group')];
 if(groups.length){groups[0].before(scroll);groups.forEach(group=>scroll.append(group));}
 sidebar.id=sidebar.id||'mythic-sidebar';
 sidebar.setAttribute('aria-label','Navegação Mythic Clash');

 const symbols={
  arena:'<path d="m5 3 6 6-2 2-6-6V3h2Zm14 0-6 6 2 2 6-6V3h-2ZM4 15l5 5m-6 0 5-5m7 0 5 5m-5 0 5-5M9 12l-3 4m9-4 3 4M9 9l6 6m0-6-6 6"/>',
  cards:'<path d="M7 4H3v15h4M11 3l10 3-4 16-10-3 4-16Z"/><path d="m14 8 .8 2.8 2.7.8-2.7.8-.8 2.8-.8-2.8-2.7-.8 2.7-.8.8-2.8Z"/>',
  friends:'<circle cx="8" cy="7" r="3"/><circle cx="17" cy="8" r="2.5"/><path d="M2 21v-3a6 6 0 0 1 12 0v3H2Zm13-8a5 5 0 0 1 7 4.6V21h-5"/>',
  guild:'<path d="M4 3h16v4l-2 1v13l-6-3-6 3V8L4 7V3Z"/><path d="M8 3v3m8-3v3m-4 6 .6 2.1 2.1.6-2.1.6-.6 2.1-.6-2.1-2.1-.6 2.1-.6.6-2.1Z"/>',
  missions:'<path d="M7 3h14a3 3 0 0 0-3 3v12a3 3 0 0 1-3 3H3a3 3 0 0 0 3-3V6a3 3 0 0 1 3-3Zm-4 18a3 3 0 0 1 0-6h12a3 3 0 0 0 0 6M10 8h5m-5 4h5"/>',
  community:'<path d="m6 4-4 2 3 15 4-1M9 2l11 2-3 18-11-2L9 2Z"/><circle cx="13" cy="10" r="2"/><path d="M9 17v-1a3.5 3.5 0 0 1 7 0v1"/>',
  lore:'<path d="M12 5C8 2 4 3 2 4v16c4-2 7-1 10 1 3-2 6-3 10-1V4c-2-1-6-2-10 1Zm0 0v16"/><path d="m6 8 1 2 2 1-2 1-1 2-1-2-2-1 2-1 1-2Zm11 0 1 2 2 1-2 1-1 2-1-2-2-1 2-1 1-2Z"/>',
  store:'<ellipse cx="8" cy="5" rx="6" ry="2.5"/><path d="M2 5v4c0 3 12 3 12 0V5M2 9v4c0 2 5 3 8 2m-8-2v4c0 2 5 3 8 2"/><ellipse cx="17" cy="14" rx="5" ry="2.5"/><path d="M12 14v5c0 3 10 3 10 0v-5"/>',
  settings:'<path d="m10 2-.5 3-2 .9-2.5-1.5-2 3.4L5.1 10v3l-2.6 2.2 2 3.4L7 17l2 .9.5 3.1h4l.5-3.1 2-.9 2.5 1.6 2-3.4-2.6-2.2v-3l2.6-2.2-2-3.4L16 5.9l-2-.9-.5-3h-3.5Z"/><circle cx="11.5" cy="11.5" r="3.5"/>',
  admin:'<path d="m12 2 8 4v6c0 5-8 10-8 10S4 17 4 12V6l8-4Z"/><path d="m12 7 1 3 3 1-3 1-1 3-1-3-3-1 3-1 1-3Z"/>'
 };
 const iconSvg=key=>`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">${symbols[key]}</svg>`;
 const iconTargets={
  '.nav-item[data-view="arena"]':'arena','#deck-menu-toggle':'cards','#friends-menu-toggle':'friends',
  '.nav-item[data-view="guilds"]':'guild','#missions-menu-toggle':'missions',
  '.nav-item[data-view="community-decks"]':'community','.nav-item[data-view="lore"]':'lore',
  '.nav-item[data-view="store"]':'store','.nav-item[data-view="settings"]':'settings','#admin-nav':'admin'
 };
 for(const [selector,key]of Object.entries(iconTargets)){
  const icon=sidebar.querySelector(selector)?.querySelector('.nav-icon');
  if(icon)icon.innerHTML=iconSvg(key);
 }

 const toggle=document.createElement('button');
 toggle.type='button';toggle.className='arcane-menu-button';toggle.id='arcane-menu-toggle';
 toggle.setAttribute('aria-label','Abrir menu de navegação');
 toggle.setAttribute('aria-controls',sidebar.id);toggle.setAttribute('aria-expanded','false');
 toggle.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16"/></svg><span>Menu</span>';
 topbar.prepend(toggle);

 const close=document.createElement('button');
 close.type='button';close.className='arcane-menu-close';close.setAttribute('aria-label','Fechar menu de navegação');close.textContent='×';
 sidebar.append(close);
 const backdrop=document.createElement('button');
 backdrop.type='button';backdrop.className='arcane-menu-backdrop';backdrop.tabIndex=-1;backdrop.hidden=true;
 backdrop.setAttribute('aria-label','Fechar menu de navegação');
 document.body.append(backdrop);
 document.body.classList.add('arcane-sidebar');

 const compact=window.matchMedia('(max-width: 960px)');
 let opened=false,scrollY=0,mainWasInert=false;
 function setOpen(value,{restoreFocus=true,navigation=false}={}){
  const next=Boolean(value&&compact.matches&&!document.body.classList.contains('duel-fullscreen'));
  if(next===opened)return;
  opened=next;
  if(next){
   scrollY=window.scrollY;mainWasInert=main.inert;
   document.body.style.setProperty('--arcane-scroll-top',`${-scrollY}px`);
   sidebar.inert=false;main.inert=true;backdrop.hidden=false;
   document.body.classList.add('arcane-menu-open');
   toggle.setAttribute('aria-expanded','true');toggle.setAttribute('aria-label','Fechar menu de navegação');
   sidebar.setAttribute('role','dialog');sidebar.setAttribute('aria-modal','true');sidebar.removeAttribute('aria-hidden');
   close.focus({preventScroll:true});
  }else{
   const focusInside=sidebar.contains(document.activeElement);
   main.inert=mainWasInert;
   document.body.classList.remove('arcane-menu-open');document.body.style.removeProperty('--arcane-scroll-top');
   backdrop.hidden=true;toggle.setAttribute('aria-expanded','false');toggle.setAttribute('aria-label','Abrir menu de navegação');
   sidebar.removeAttribute('role');sidebar.removeAttribute('aria-modal');
   window.scrollTo({top:navigation?0:scrollY,behavior:'instant'});
   if(restoreFocus&&compact.matches&&!document.body.classList.contains('duel-fullscreen'))toggle.focus({preventScroll:true});
   else if(focusInside)document.activeElement.blur();
   sidebar.inert=compact.matches;
   if(compact.matches)sidebar.setAttribute('aria-hidden','true');else sidebar.removeAttribute('aria-hidden');
  }
 }
 function syncSize(){
  if(opened)setOpen(false);
  sidebar.inert=compact.matches;
  if(compact.matches)sidebar.setAttribute('aria-hidden','true');else sidebar.removeAttribute('aria-hidden');
 }
 // Edge swipe leaves normal page scrolling untouched until horizontal intent is clear.
 let swipe=null;
 document.addEventListener('touchstart',e=>{if(!compact.matches||e.touches.length!==1||document.querySelector('dialog[open]')||document.body.classList.contains('duel-fullscreen'))return;const t=e.touches[0];if(opened||t.clientX<=28)swipe={x:t.clientX,y:t.clientY,open:opened,horizontal:false};},{passive:true});
 document.addEventListener('touchmove',e=>{if(!swipe||e.touches.length!==1)return;const t=e.touches[0],dx=t.clientX-swipe.x,dy=t.clientY-swipe.y;if(!swipe.horizontal&&Math.abs(dy)>18&&Math.abs(dy)>Math.abs(dx)){swipe=null;return;}if(Math.abs(dx)>20&&Math.abs(dx)>Math.abs(dy)*1.4){swipe.horizontal=true;if(e.cancelable)e.preventDefault();if(!swipe.open&&dx>65){setOpen(true);swipe=null;}else if(swipe.open&&dx< -65){setOpen(false);swipe=null;}}},{passive:false});
 document.addEventListener('touchend',()=>{swipe=null;},{passive:true});document.addEventListener('touchcancel',()=>{swipe=null;},{passive:true});
 toggle.addEventListener('click',()=>setOpen(!opened));
 close.addEventListener('click',()=>setOpen(false));
 backdrop.addEventListener('click',()=>setOpen(false));
 compact.addEventListener('change',syncSize);
 syncSize();

 sidebar.addEventListener('click',event=>{
  if(event.target.closest('.brand')){
   event.preventDefault();window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:'arena'}}));
  }
  // Expandable deck/friend/mission groups stay open for choosing their actions.
  if(event.target.closest('[data-view],[data-friend-panel],.missions-preview-item,.missions-more,.brand')){
   queueMicrotask(()=>setOpen(false,{restoreFocus:true,navigation:true}));
  }
 });
 window.addEventListener('mythic-open-view',()=>{if(opened)setOpen(false,{restoreFocus:false,navigation:true});});
 document.addEventListener('keydown',event=>{
  if(!opened)return;
  if(event.key==='Escape'){event.preventDefault();event.stopPropagation();setOpen(false);return;}
  if(event.key!=='Tab')return;
  const targets=[...sidebar.querySelectorAll('button:not(:disabled),a[href],[tabindex="0"]')].filter(n=>n.getClientRects().length&&!n.closest('[hidden]'));
  if(!targets.length){event.preventDefault();close.focus();return;}
  const first=targets[0],last=targets[targets.length-1];
  if(event.shiftKey&&(document.activeElement===first||!sidebar.contains(document.activeElement))){event.preventDefault();last.focus();}
  else if(!event.shiftKey&&(document.activeElement===last||!sidebar.contains(document.activeElement))){event.preventDefault();first.focus();}
 },true);
 new MutationObserver(()=>{
  if(opened&&document.body.classList.contains('duel-fullscreen'))setOpen(false,{restoreFocus:false,navigation:true});
 }).observe(document.body,{attributes:true,attributeFilter:['class']});

 function syncCurrent(){
  for(const item of sidebar.querySelectorAll('.nav-item[data-view]')){
   if(item.classList.contains('active'))item.setAttribute('aria-current','page');else item.removeAttribute('aria-current');
  }
 }
 new MutationObserver(syncCurrent).observe(scroll,{subtree:true,attributes:true,attributeFilter:['class']});
 syncCurrent();
})();
