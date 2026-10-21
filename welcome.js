(() => {
 'use strict';
 const PACK=window.MythicEntryMedia?.optimized?.['assets/onboarding/starter-pack.png']||'assets/onboarding/starter-pack.png',BACK='assets/card-back.svg';
 const paths=[
  {id:'Grécia',name:'Mitologia Grega',image:'assets/card-badges/gregos-v3.png',scene:'assets/onboarding/greek-realm.webp',text:'O Olimpo, seus heróis e formações lendárias.',tone:'greek'},
  {id:'Nórdicos',name:'Mitologia Nórdica',image:'assets/card-badges/nordicos-v3.png',scene:'assets/onboarding/norse-realm.webp',text:'Runas, guerreiros e o poder dos Nove Reinos.',tone:'norse'},
  {id:'Egípcios',name:'Mitologia Egípcia',image:'assets/card-badges/egipcios-v3.png',scene:'assets/onboarding/egyptian-realm.webp',text:'Os deuses antigos e os mistérios do Nilo.',tone:'egypt'},
  {id:'Alyns',name:'Reino de Alyn',image:'assets/card-badges/alyns-v3.png',scene:'assets/onboarding/public-citadel.webp',text:'Lukyan, Butter e o início de uma lenda original.',tone:'alyn'}
 ];
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const button=(text,fn,cls='welcome-button')=>{const n=el('button',cls,text);n.type='button';n.addEventListener('click',fn);return n;};
 const picture=(src,alt='',cls='',full=false)=>{const n=el('img',cls);n.src=window.MythicSecurity.assetUrl(full?src:window.MythicEntryMedia?.byArt?.[src]||src);n.alt=alt;n.draggable=false;n.decoding=cls==='welcome-faction-emblem'?'sync':'async';return n;};
 const reduced=()=>matchMedia('(prefers-reduced-motion: reduce)').matches;
 let collectionRefresh=null,beginRequest=null;
 let root=null,stage=null,heading=null,subheading=null,actions=null,message=null,rail=null,user=null,receipt=null,chosen=null,phase='idle',generation=0,busy=false,animations=new Set(),previousFocus=null,inspector=null,packReady=Promise.resolve();
 const catalog=()=>window.MythicCardData?.()||window.MythicAbilitiesData?.cards||[];
 const current=token=>token===generation&&Boolean(user);
 function ensure(){
  if(root)return;
  root=el('dialog','welcome-dialog');root.id='mythic-welcome';root.setAttribute('aria-labelledby','welcome-heading');
  const shell=el('div','welcome-shell'),top=el('header','welcome-header'),brand=el('div','welcome-brand');brand.append(el('span','','✦'),el('b','','MYTHIC CLASH'));
  top.append(brand,button('Sair da conta',()=>window.MythicOnline?.signOut?.(),'welcome-signout'));
  rail=el('nav','welcome-rail');rail.setAttribute('aria-label','Etapas da sua jornada');
  for(const text of ['Boas-vindas','Sua mitologia','Seu primeiro pacote'])rail.append(el('span','',text));
  const copy=el('div','welcome-copy');heading=el('h1');heading.id='welcome-heading';heading.tabIndex=-1;subheading=el('p');copy.append(heading,subheading);
  stage=el('section','welcome-stage');stage.setAttribute('aria-label','Sua jornada');
  message=el('p','welcome-message');message.setAttribute('role','status');message.setAttribute('aria-live','polite');
  actions=el('footer','welcome-actions');shell.append(top,rail,copy,stage,message,actions);root.append(shell);document.body.append(root);
  root.addEventListener('cancel',event=>{event.preventDefault();if(phase==='opening')revealNow();});
 }
 function stopAnimations(){for(const a of animations)a.cancel();animations.clear();}
 function show(){ensure();if(!root.open){previousFocus=document.activeElement;root.showModal();document.body.classList.add('welcome-open');}}
 function close(){const wasOpen=Boolean(root?.open);stopAnimations();inspector?.close();if(root?.open)root.close();document.body.classList.remove('welcome-open');if(previousFocus?.isConnected)previousFocus.focus({preventScroll:true});if(wasOpen)window.dispatchEvent(new Event('mythic-welcome-closed'));}
 function reset(){collectionRefresh=null;beginRequest=null;generation++;user=null;receipt=null;chosen=null;phase='idle';busy=false;close();}
 function screen(name,title,copy,step){show();stopAnimations();phase=name;root.dataset.phase=name;heading.textContent=title;subheading.textContent=copy;stage.replaceChildren();actions.replaceChildren();message.textContent='';Array.from(rail.children).forEach((n,i)=>{n.classList.toggle('is-current',i===step);n.classList.toggle('is-done',i<step);if(i===step)n.setAttribute('aria-current','step');else n.removeAttribute('aria-current');});heading.focus({preventScroll:true});}
 function preload(src){return new Promise(resolve=>{const img=new Image();let done=false;const finish=()=>{if(done)return;done=true;clearTimeout(timer);resolve();};const timer=setTimeout(finish,8000);img.onload=finish;img.onerror=finish;img.src=src;if(img.complete)finish();});}
 function intro(){
  screen('welcome','Bem-vindo à Convergência'+(user.name?', '+user.name:'')+'.','Sua lenda começa com um presente. Escolha uma mitologia, descubra suas cartas e prepare seu primeiro baralho.',0);
  const visual=el('div','welcome-intro-visual');visual.append(el('div','welcome-orbit'),picture(PACK,'Seu primeiro pacotinho de Mythic Clash','welcome-intro-pack'));
  const facts=el('div','welcome-gifts');for(const [value,label] of [['14','cartas para começar'],['2','ícones de perfil'],['1','nova jornada']]){const item=el('div');item.append(el('strong','',value),el('span','',label));facts.append(item);}stage.append(visual,facts);
  actions.append(button('Começar minha jornada →',chooseScreen));packReady=preload(PACK);
 }
 function chooseScreen(){
  screen('choice','Qual mitologia desperta sua curiosidade?','A sua escolha favorece as cartas do pacote. Um ícone será dessa mitologia e o outro será de uma mitologia diferente — ambos sorteados.',1);
  const grid=el('div','welcome-mythologies'),proceed=button('Receber meu pacote →',claim);proceed.disabled=!chosen;
  for(const path of paths){const option=button('',()=>{chosen=path.id;for(const n of grid.children){const selected=n.dataset.mythology===chosen;n.setAttribute('aria-pressed',String(selected));}proceed.disabled=false;},'welcome-mythology '+path.tone);option.dataset.mythology=path.id;option.style.setProperty('--faction-scene','url("'+window.MythicSecurity.assetUrl(path.scene)+'")');option.setAttribute('aria-pressed',String(chosen===path.id));
   option.append(picture(path.image,'Símbolo de '+path.name,'welcome-faction-emblem'),el('strong','',path.name),el('span','welcome-myth-description',path.text),el('small','welcome-myth-selected','✦ Escolhida'));grid.append(option);
  }
  stage.append(grid);actions.append(button('Voltar',intro,'welcome-secondary'),proceed);
 }
 async function claim(){
  if(busy||!chosen)return;const token=generation;busy=true;for(const b of actions.querySelectorAll('button'))b.disabled=true;for(const b of stage.querySelectorAll('button'))b.disabled=true;message.textContent='Preparando seu presente…';
  try{const data=await window.MythicOnline.openStarterPack(chosen);if(!current(token))return;receipt=data;if(data.stage==='completed'){phase='completed';close();window.dispatchEvent(new CustomEvent('mythic-welcome-ready',{detail:{userId:user.id,stage:'completed'}}));return;}if(data.stage!=='granted'||data.card_ids?.length!==14||data.icon_ids?.length!==2)throw Error('Seu pacote ainda não ficou pronto. Tente novamente.');
   collectionRefresh=window.MythicOnline.refreshProfile().then(()=>true,()=>false);if(!current(token))return;packScreen();
  }catch(error){if(current(token)){message.textContent=error.message||'Não foi possível preparar seu pacote. Tente novamente.';for(const b of actions.querySelectorAll('button'))b.disabled=false;for(const b of stage.querySelectorAll('button'))b.disabled=false;}}
  finally{if(current(token))busy=false;}
 }
 function cards(){const lookup=new Map(catalog().map(c=>[c.id,c]));return (receipt?.card_ids||[]).map(id=>lookup.get(id)||{id,name:id,art:BACK,ability:'',faction:''});}
 function packScreen(){
  screen('pack','Um começo digno de uma lenda.','Seu pacote de '+(receipt.mythology||'Mythic Clash')+' está pronto. Toque para abrir e conhecer suas 14 cartas.',2);
  const portal=el('div','welcome-pack-portal'),pack=button('',openPack,'welcome-sealed-pack');pack.setAttribute('aria-label','Abrir seu pacotinho de cartas');pack.append(picture(PACK,'Pacotinho de Mythic Clash'));
  pack.querySelector('img').onerror=()=>{pack.replaceChildren(picture(BACK,'Pacotinho de Mythic Clash'));};portal.append(el('div','welcome-pack-halo'),pack,el('span','welcome-pack-caption','Toque no pacotinho para abrir'));stage.append(portal);actions.append(button('Abrir pacotinho ✦',openPack));
  packReady=Promise.all([preload(PACK),preload(BACK)]);for(const c of cards().slice(0,3))preload(window.MythicEntryMedia?.byArt?.[c.art]||c.art||BACK);
 }
 function animate(node,frames,options){const a=node.animate(frames,{fill:'forwards',...options});animations.add(a);a.finished.catch(()=>{}).finally(()=>animations.delete(a));return a;}
 function sound(){
  if(reduced()||document.querySelector('#setting-effects')?.checked===false)return;
  try{const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)return;const ctx=new Audio();const gain=ctx.createGain();gain.gain.value=.035;gain.connect(ctx.destination);for(const [i,freq] of [330,495,660,990].entries()){const o=ctx.createOscillator(),g=ctx.createGain();o.type='sine';o.frequency.value=freq;g.gain.setValueAtTime(0,ctx.currentTime+i*.1);g.gain.linearRampToValueAtTime(1,ctx.currentTime+i*.1+.03);g.gain.exponentialRampToValueAtTime(.001,ctx.currentTime+i*.1+.6);o.connect(g);g.connect(gain);o.start(ctx.currentTime+i*.1);o.stop(ctx.currentTime+i*.1+.65);}setTimeout(()=>ctx.close().catch(()=>{}),1500);}catch{}
 }
 function fanPosition(index,count){const narrow=matchMedia('(max-width:700px)').matches;const per=narrow?7:count,row=narrow?Math.floor(index/per):0,offset=(index%per)-(Math.min(per,count-row*per)-1)/2;const available=Math.min(innerWidth-50,1220),width=narrow?Math.min(82,(innerWidth-48)/4.2):Math.min(142,available/8),spread=narrow?(available-width*1.8)/(per-1):Math.min(80,(available-width*1.8)/(count-1));return {x:offset*spread,y:row*(width*1.45+35)+Math.abs(offset)*Math.abs(offset)*(narrow?1.8:1.35),angle:offset*(narrow?5:3.4),width,row};}
 function setPosition(node,index){const p=fanPosition(index,cards().length);node.style.setProperty('--card-width',p.width+'px');node.style.setProperty('--fan-x',p.x+'px');node.style.setProperty('--fan-y',p.y+'px');node.style.setProperty('--fan-angle',p.angle+'deg');node.style.zIndex=String(20+index);return p;}
 function makeCards(){
  const fan=el('div','welcome-card-fan');cards().forEach((card,index)=>{const n=button('',()=>inspect(card),'welcome-reward-card');n.disabled=true;n.setAttribute('aria-label','Ampliar '+card.name);n.dataset.index=index;setPosition(n,index);const flipper=el('span','welcome-card-flipper'),back=el('span','welcome-card-back'),front=el('span','welcome-card-front');back.append(picture(BACK,''));const image=picture(card.art||BACK,card.name);image.onerror=()=>{image.onerror=null;image.src=BACK;front.append(el('b','welcome-card-fallback',card.name));};front.append(image);flipper.append(back,front);n.append(flipper);fan.append(n);});return fan;
 }
 async function openPack(){
  if(busy||phase!=='pack')return;busy=true;const token=generation;for(const b of root.querySelectorAll('button:not(.welcome-signout)'))b.disabled=true;message.textContent='Suas cartas estão chegando…';await Promise.race([packReady,new Promise(resolve=>setTimeout(resolve,500))]);if(!current(token)||phase!=='pack')return;
  screen('opening','O destino está em suas mãos.','14 cartas. Uma nova estratégia esperando por você.',2);busy=true;stage.append(makeCards());actions.append(button('Pular animação',revealNow,'welcome-secondary'));
  const pack=el('div','welcome-opening-pack'),body=el('div','welcome-pack-body'),cap=el('div','welcome-pack-cap');body.append(picture(PACK,''));cap.append(picture(PACK,''));pack.append(body,cap);stage.append(pack);
  const spark=el('div','welcome-reveal-flash');stage.append(spark);sound();
  if(reduced()){revealNow();return;}
  animate(cap,[{transform:'translate(0,0) rotate(0)',opacity:1},{transform:'translate(-95px,-180px) rotate(-22deg)',opacity:0}],{duration:950,easing:'cubic-bezier(.15,.7,.15,1)'});
  animate(body,[{transform:'translateY(0) scale(1)',opacity:1},{transform:'translateY(25px) scale(1)',opacity:1,offset:.35},{transform:'translateY(175px) scale(.8)',opacity:0}],{duration:1550,easing:'ease-in'});
  animate(spark,[{opacity:0,transform:'translate(-50%,-50%) scale(.4)'},{opacity:1,offset:.3},{opacity:0,transform:'translate(-50%,-50%) scale(1.7)'}],{duration:1700});
  const nodes=Array.from(stage.querySelectorAll('.welcome-reward-card'));const rise=nodes.map((node,i)=>animate(node,[{opacity:0,transform:'translate(-50%,70px) scale(.6)'},{opacity:1,transform:'translate(calc(-50% + '+((i-6.5)*4)+'px),-95px) scale(1)'}],{duration:1100,delay:400+i*23,easing:'cubic-bezier(.16,.7,.2,1)'}).finished.catch(()=>{}));
  await Promise.all(rise);if(!current(token)||phase!=='opening')return;
  const turns=[];for(const [i,node] of nodes.entries()){const p=setPosition(node,i);turns.push(animate(node.querySelector('.welcome-card-flipper'),[{transform:'rotateY(0)'},{transform:'rotateY(180deg)'}],{duration:850,easing:'cubic-bezier(.2,.7,.2,1)'}).finished.catch(()=>{}));turns.push(animate(node,[{transform:'translate(calc(-50% + '+((i-6.5)*4)+'px),-95px) scale(1)',opacity:1},{transform:`translate(calc(-50% + ${p.x}px),${p.y}px) rotate(${p.angle}deg) scale(1)`,opacity:1}],{duration:1100,easing:'cubic-bezier(.2,.75,.2,1)'}).finished.catch(()=>{}));}
  await Promise.all(turns);if(current(token)&&phase==='opening')revealNow();
 }
 function iconData(id){const avatar=window.MythicChibiAvatars?.avatars?.find?.(a=>a.id===id);const src=window.MythicOnline?.avatarAsset?.(id);return {name:avatar?.name||catalog().find(c=>'chibi-'+c.id===id)?.name||'Ícone de perfil',asset:src,avatar};}
 function revealNow(){
  if(!receipt||!['opening','revealed'].includes(phase))return;stopAnimations();phase='revealed';root.dataset.phase='revealed';busy=false;heading.textContent='Sua coleção começa aqui.';subheading.textContent='Estas cartas já são suas. Toque em uma para conhecer a habilidade e monte seu primeiro baralho.';stage.querySelector('.welcome-opening-pack')?.remove();stage.querySelector('.welcome-reveal-flash')?.remove();
  for(const [i,node] of Array.from(stage.querySelectorAll('.welcome-reward-card')).entries()){setPosition(node,i);node.classList.add('is-revealed');node.disabled=false;node.style.opacity='1';}
  stage.querySelector('.welcome-earned-icons')?.remove();const icons=el('div','welcome-earned-icons');for(const [i,id] of (receipt.icon_ids||[]).entries()){const item=el('div','welcome-earned-icon'),a=iconData(id);if(a.avatar){const frame=el('span','welcome-earned-avatar');frame.setAttribute('role','img');frame.setAttribute('aria-label',a.name);frame.style.backgroundImage='url("'+window.MythicSecurity.assetUrl(a.avatar.asset.split('#')[0])+'")';frame.style.backgroundPosition=(a.avatar.col*50)+'% '+(a.avatar.row*100)+'%';item.append(frame);}else if(a.asset)item.append(picture(a.asset,a.name));item.append(el('span','',a.name),el('small','',i===0?'Da sua mitologia':'De outra mitologia'));icons.append(item);}stage.append(icons);actions.replaceChildren(button('Montar deck →',finish));message.textContent='14 cartas e 2 ícones adicionados à sua conta.';actions.scrollIntoView({block:'nearest',behavior:reduced()?'auto':'smooth'});
 }
 let inspectIndex=0,swipe=null;
 function inspect(card){
  if(phase!=='revealed')return;
  if(!inspector){
   inspector=el('dialog','welcome-inspector welcome-fan-inspector');inspector.setAttribute('aria-label','Cartas recebidas ampliadas');document.body.append(inspector);
   inspector.addEventListener('click',e=>{if(e.target===inspector)inspector.close();});
   inspector.addEventListener('keydown',e=>{if(e.key==='ArrowRight'||e.key==='ArrowLeft'){e.preventDefault();moveInspect(e.key==='ArrowRight'?1:-1);}});
  }
  inspectIndex=Math.max(0,cards().findIndex(c=>c.id===card.id));renderInspect();if(!inspector.open)inspector.showModal();
 }
 function moveInspect(delta){inspectIndex=Math.max(0,Math.min(cards().length-1,inspectIndex+delta));renderInspect();}
 function renderInspect(){
  const all=cards(),selected=all[inspectIndex],fan=el('div','welcome-large-fan');fan.setAttribute('aria-label','Arraste para os lados ou escolha uma carta vizinha');
  for(let i=Math.max(0,inspectIndex-2);i<=Math.min(all.length-1,inspectIndex+2);i++){
   const c=all[i],d=i-inspectIndex,n=button('',()=>{if(inspector._dragged)return;inspectIndex=i;renderInspect();},'welcome-large-card');n.style.setProperty('--offset',d);n.dataset.selected=String(!d);n.setAttribute('aria-label',c.name);n.setAttribute('aria-pressed',String(!d));n.append(picture(c.art||BACK,c.name,'',d===0));fan.append(n);
  }
  fan.addEventListener('pointerdown',e=>{if(e.button!==0)return;inspector._dragged=false;swipe={x:e.clientX,y:e.clientY,id:e.pointerId};const capture=e.target.closest('button')||fan;capture.setPointerCapture(e.pointerId);});
  fan.addEventListener('pointermove',e=>{if(swipe&&Math.abs(e.clientX-swipe.x)>12)inspector._dragged=true;});
  fan.addEventListener('pointerup',e=>{if(!swipe||swipe.id!==e.pointerId)return;const dx=e.clientX-swipe.x,dy=e.clientY-swipe.y;swipe=null;if(Math.abs(dx)>45&&Math.abs(dx)>Math.abs(dy)){inspector._dragged=true;moveInspect(dx<0?1:-1);setTimeout(()=>{inspector._dragged=false;},0);}});
  fan.addEventListener('pointercancel',()=>{swipe=null;});
  const controls=el('div','welcome-inspector-controls'),prev=button('← Anterior',()=>moveInspect(-1)),next=button('Próxima →',()=>moveInspect(1));prev.disabled=inspectIndex===0;next.disabled=inspectIndex===all.length-1;controls.append(prev,el('span','',`${inspectIndex+1} / ${all.length}`),next);
  const copy=el('div','welcome-inspector-copy');copy.setAttribute('aria-live','polite');copy.append(el('h2','',selected.name),el('h3','',selected.abilityTitle||'Habilidade'),el('p','',selected.ability||''));
  inspector.replaceChildren(button('Fechar ×',()=>inspector.close(),'welcome-inspector-close'),fan,controls,copy);inspector.scrollLeft=0;if(inspector.open)fan.querySelector("[data-selected=true]")?.focus({preventScroll:true});
 }
 async function finish(){
  if(busy)return;busy=true;const token=generation;actions.querySelector('button').disabled=true;message.textContent='Preparando seu construtor…';
  try{await window.MythicOnline.completeWelcome();if(!collectionRefresh||!await collectionRefresh)await window.MythicOnline.refreshProfile();if(!current(token))return;phase='completed';close();window.dispatchEvent(new CustomEvent('mythic-open-view',{detail:{view:'decks'}}));requestAnimationFrame(()=>window.MythicDeckBuilder?.open());}
  catch(error){if(current(token)){message.textContent=error.message||'Não foi possível abrir o construtor. Tente novamente.';actions.querySelector('button').disabled=false;}}finally{if(current(token))busy=false;}
 }
 function begin(account){
  if(!account?.id)return Promise.resolve(null);
  if(user?.id===account.id&&phase!=='error')return beginRequest||Promise.resolve(receipt);
  reset();user={id:account.id,name:account.user_metadata?.nickname||account.user_metadata?.display_name||''};phase='checking';const token=generation;
  beginRequest=(async()=>{
   try{
    const data=await window.MythicOnline.getWelcomeState();if(!current(token))return null;
    if(!['welcome','granted','completed'].includes(data?.stage))throw Error('Não foi possível confirmar a etapa da sua conta.');
    receipt=data;
    if(data.stage==='completed'){phase='completed';close();}
    else if(data.stage==='granted'){chosen=data.mythology;packScreen();}
    else intro();
    window.dispatchEvent(new CustomEvent('mythic-welcome-ready',{detail:{userId:user.id,stage:data.stage}}));return data;
   }catch(error){
    if(!current(token))return null;phase='error';close();
    window.MythicPresentation?.notify?.('Não foi possível confirmar sua entrada. Clique em Jogar para tentar novamente.');return null;
   }finally{if(current(token))beginRequest=null;}
  })();return beginRequest;
 }
 window.addEventListener('resize',()=>{if(phase==='revealed')for(const [i,node] of Array.from(stage.querySelectorAll('.welcome-reward-card')).entries())setPosition(node,i);});
 window.addEventListener('mythic-account-signed-out',reset);
 window.MythicWelcome={begin,reset,getStage:()=>phase,isOpen:()=>Boolean(root?.open)};
})();
