(() => {
 'use strict';
 const top=document.querySelector('.topbar-right');if(top&&!document.querySelector('#topbar-replay')){const b=document.createElement('button');b.type='button';b.id='topbar-replay';b.className='icon-button';b.title='Meus replays';b.setAttribute('aria-label','Abrir meus replays');b.textContent='▷';b.onclick=()=>{window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:'profile'}}));requestAnimationFrame(()=>{const tab=[...document.querySelectorAll('.legend-tabs button')].find(b=>b.textContent==='Replays');tab?.click();});};top.prepend(b);}
 const known=new WeakSet();let scheduled=false;
 function enhance(){scheduled=false;for(const select of document.querySelectorAll('select')){if(known.has(select)||select.closest('.visual-deck-picker')||select.multiple)continue;if(!/deck|baralho/i.test(select.id+' '+select.name+' '+select.className+' '+(select.closest('label')?.textContent||'')))continue;const decks=window.MythicPresentation?.read?.().decks||[];if(!select.options.length||![...select.options].every(o=>o.disabled||o.value===''||/^\d+$/.test(o.value)&&Number(o.value)<decks.length))continue;known.add(select);const parent=select.parentNode,after=select.nextSibling;if(parent)parent.insertBefore(window.MythicDeckPicker.create(select),after);}}
 // The picker moves the original select; preserve its form, id and change handlers.
 function queue(){if(!scheduled){scheduled=true;requestAnimationFrame(enhance);}}
 new MutationObserver(queue).observe(document.body,{childList:true,subtree:true});window.addEventListener('mythic-deck-saved',queue);window.addEventListener('mythic-profile-loaded',queue);queue();
})();
