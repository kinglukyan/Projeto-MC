(() => {
 'use strict';
 const atlases={water:'tsunami',lightning:'lightning',hearts:'hearts',lunar:'lunar-morph',solar:'solar-morph'};
 const cache=new Map();
 function preload(name){if(!cache.has(name)){const image=new Image();image.decoding='async';image.src='assets/vfx/'+atlases[name]+'.png';cache.set(name,image);}return cache.get(name);}
 function sheet(host,name,rect,duration=1500){if(!atlases[name])return;preload(name);const node=document.createElement('span');node.className='painted-vfx painted-vfx-'+name;node.style.cssText=`left:${rect.left}px;top:${rect.top}px;width:${rect.width}px;height:${rect.height}px;--vfx-duration:${duration}ms;background-image:url('assets/vfx/${atlases[name]}.png')`;host.append(node);
  // Each quadrant is a real painted frame. Discrete positions prevent atlas bleed.
  const reduced=matchMedia('(prefers-reduced-motion:reduce)').matches;const frames=reduced?Array(5).fill('0% 100%'):['0% 0%','100% 0%','0% 100%','100% 100%','100% 100%'];node.animate(frames.map((position,i)=>({backgroundPosition:position,offset:i/4})),{duration,fill:'forwards',easing:'steps(1,end)'});
  const fade=node.animate(reduced?[{opacity:1},{opacity:0}]:[{opacity:0,transform:'scale(.85)'},{opacity:1,transform:'scale(1)',offset:.18},{opacity:1,offset:.75},{opacity:0,transform:'scale(1.08)'}],{duration,fill:'forwards'});fade.onfinish=()=>node.remove();return node;
 }
 function transform(host,oldCard,newCard,rect,lunar,delay=0,empowered=false){preload(lunar?'lunar':'solar');const el=document.createElement('div');el.className='wolf-morph morph-waiting';el.style.cssText=`left:${rect.left}px;top:${rect.top}px;width:${rect.width}px;height:${rect.height}px`;
  for(const [card,cls] of [[oldCard,'morph-before'],[newCard,'morph-after']]){if(!card)continue;const img=document.createElement('img');img.src=window.MythicSecurity.assetUrl(card.hologram||card.art);img.alt='';img.className=cls;el.append(img);}host.append(el);setTimeout(()=>{if(!el.isConnected)return;el.classList.remove('morph-waiting');sheet(host,lunar?'lunar':'solar',rect,1800);},delay);const title=document.createElement('b');title.textContent=lunar?(empowered?'A FERA DESPERTA · PODER ×2':'A FORMA LOBISOMEM RETORNA'):'O SOL REVELA A FORMA HUMANA';el.append(title);setTimeout(()=>el.remove(),delay+1850);return el;
 }
 window.MythicPaintedFX={sheet,transform,preload};
})();
