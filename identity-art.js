(() => {
 'use strict';
 const medals=['first-step','first-victory','ten-wins','fifty-wins','hundred-wins','twenty-five','hundred-games','ranked-ten','friend-ten','guardian-ten'];
 const titles=['traveler','initiate','victor','veteran','ranked-champion','duelist','conqueror','immortal'];
 const catalog=new Map();
 function decorate(node,row){if(!row||node.dataset.honorArt===row.id)return;const list=row.kind==='medal'?medals:titles,index=list.indexOf(row.id);if(index<0)return;const cols=row.kind==='medal'?5:4;node.textContent='';node.classList.add('painted-honor');node.dataset.honorArt=row.id;node.style.backgroundImage=`url('assets/identity-v2/${row.kind==='medal'?'medal':'title'}-atlas.webp')`;node.style.backgroundSize=`${cols*100}% 200%`;node.style.backgroundPosition=`${index%cols/(cols-1)*100}% ${Math.floor(index/cols)*100}%`;node.setAttribute('role','img');node.setAttribute('aria-label',row.name);}
 function paint(){
  for(const n of document.querySelectorAll('.honor-card'))decorate(n.querySelector('.honor-emblem'),catalog.get(n.querySelector('b')?.textContent));
  for(const n of document.querySelectorAll('.featured-medal'))decorate(n,catalog.get(n.title));
  for(const n of document.querySelectorAll('.equipped-honor-title,.sidebar-honor-title,.friend-honors>b')){const row=catalog.get(n.textContent),index=titles.indexOf(row?.id);if(index>=0){n.classList.add('painted-title-label');n.style.setProperty('--honor-x',index%4/3*100+'%');n.style.setProperty('--honor-y',Math.floor(index/4)*100+'%');}else n.classList.remove('painted-title-label');}
 }
 window.addEventListener('mythic-honors-loaded',e=>{for(const row of e.detail?.data?.catalog||[])catalog.set(row.name,row);paint();});
 document.addEventListener('DOMContentLoaded',()=>{
  for(const img of document.querySelectorAll('img[src*="assets/ranks/"]'))img.src=img.getAttribute('src').replace('assets/ranks/','assets/identity-v2/').replace(/\.svg(?:\?.*)?$/,'.webp');
  for(const img of document.querySelectorAll('img[src*="currency/mythic-coins.svg"]'))img.src='assets/identity-v2/coin.webp';
  let queued=false;const observer=new MutationObserver(()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;paint();});});
  for(const node of document.querySelectorAll('.honor-grid,.featured-medals,.friend-honors'))observer.observe(node,{childList:true,subtree:true});
  paint();
 });
})();
