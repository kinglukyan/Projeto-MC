(() => {
 'use strict';
 let popup=null,anchor=null;
 function close(){popup?.remove();popup=null;if(anchor)anchor.setAttribute('aria-expanded','false');anchor=null;}
 function create(select){
  const box=document.createElement('div');box.className='visual-deck-picker';
  const trigger=document.createElement('button');trigger.type='button';trigger.className='visual-deck-trigger';trigger.setAttribute('aria-haspopup','listbox');trigger.setAttribute('aria-expanded','false');trigger.setAttribute('aria-label','Escolher baralho');
  function content(target,index,label){const deck=window.MythicPresentation?.read?.().decks?.[Number(index)]||{};target.replaceChildren(window.MythicDeckIdentity.badge(deck),document.createTextNode(label));}
  function sync(){const option=select.selectedOptions[0];content(trigger,select.value,option?.textContent||'Escolha seu baralho');trigger.disabled=select.disabled;}
  trigger.onclick=()=>{
   if(popup){const same=anchor===trigger;close();if(same)return;}
   popup=document.createElement('div');popup.className='visual-deck-options';popup.setAttribute('role','listbox');popup.setAttribute('aria-label','Seus baralhos');anchor=trigger;trigger.setAttribute('aria-expanded','true');
   for(const option of select.options){const item=document.createElement('button');item.type='button';item.setAttribute('role','option');item.setAttribute('aria-selected',String(option.selected));item.disabled=option.disabled;content(item,option.value,option.textContent);item.onclick=()=>{select.value=option.value;close();sync();select.dispatchEvent(new Event('change',{bubbles:true}));trigger.focus();};popup.append(item);}
   document.body.append(popup);const r=trigger.getBoundingClientRect(),height=Math.min(320,popup.scrollHeight,innerHeight-24),top=innerHeight-r.bottom>height+12?r.bottom+6:Math.max(8,r.top-height-6);popup.style.cssText=`position:fixed;left:${Math.max(8,Math.min(r.left,innerWidth-Math.min(r.width,innerWidth-16)-8))}px;top:${top}px;width:${Math.min(Math.max(r.width,240),innerWidth-16)}px;max-height:${height}px`;
   (popup.querySelector('[aria-selected=true]')||popup.querySelector('button'))?.focus();
   popup.onkeydown=e=>{const items=[...popup.querySelectorAll('button:not(:disabled)')],index=items.indexOf(document.activeElement);if(e.key==='Escape'){close();trigger.focus();}else if(['ArrowDown','ArrowUp','Home','End'].includes(e.key)){e.preventDefault();items[e.key==='Home'?0:e.key==='End'?items.length-1:(index+(e.key==='ArrowDown'?1:-1)+items.length)%items.length]?.focus();}else if(e.key==='Tab')close();};
  };
  select.hidden=true;select.addEventListener('change',sync);new MutationObserver(sync).observe(select,{attributes:true,childList:true,subtree:true,attributeFilter:['disabled','selected']});box.append(select,trigger);sync();return box;
 }
 document.addEventListener('pointerdown',e=>{if(popup&&!popup.contains(e.target)&&!anchor?.contains(e.target))close();});
 window.addEventListener('resize',close);document.addEventListener('scroll',e=>{if(popup&&!popup.contains(e.target))close();},true);
 window.addEventListener('mythic-view-changed',close);window.addEventListener('mythic-account-signed-out',close);window.addEventListener('mythic-deck-saved',close);window.addEventListener('mythic-deck-deleted',close);
 window.MythicDeckPicker={create};
})();
