(() => {
 'use strict';

 const known=new WeakSet();let scheduled=false;
 function enhance(){scheduled=false;for(const select of document.querySelectorAll('select')){if(known.has(select)||select.closest('.visual-deck-picker')||select.multiple)continue;if(!/deck|baralho/i.test(select.id+' '+select.name+' '+select.className+' '+(select.closest('label')?.textContent||'')))continue;const decks=window.MythicPresentation?.read?.().decks||[];if(!select.options.length||![...select.options].every(o=>o.disabled||o.value===''||/^\d+$/.test(o.value)&&Number(o.value)<decks.length))continue;known.add(select);const parent=select.parentNode,after=select.nextSibling;if(parent)parent.insertBefore(window.MythicDeckPicker.create(select),after);}}
 // The picker moves the original select; preserve its form, id and change handlers.
 function queue(){if(!scheduled){scheduled=true;requestAnimationFrame(enhance);}}
 new MutationObserver(queue).observe(document.body,{childList:true,subtree:true});window.addEventListener('mythic-deck-saved',queue);window.addEventListener('mythic-profile-loaded',queue);queue();
})();
