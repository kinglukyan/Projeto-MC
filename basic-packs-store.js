(() => {
 'use strict';
 const view=document.querySelector('#view-store');if(!view)return;
 const api=()=>window.MythicOnline,uid=()=>api()?.userId?.(),rpc=(n,args={})=>api().portalRequest(n,args),safe=s=>window.MythicSecurity.assetUrl(s),coin='assets/currency/trixx-coins.webp';
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const img=(path,alt='',lazy=true)=>{const n=el('img');n.src=safe(path);n.alt=alt;n.decoding='async';n.loading=lazy?'lazy':'eager';n.draggable=false;return n;};
 const button=(text,fn,primary=false)=>{const b=el('button','button '+(primary?'button-primary':'button-secondary'),text);b.type='button';b.onclick=fn;return b;};
 const fmt=n=>Number(n||0).toLocaleString('pt-BR'),notify=t=>window.MythicPresentation?.notify?.(t);
 let owner=null,epoch=0,revision=0,loading=false,ready=false,active=false,buying=false,viewer=null,balance=0,pending=[],catalog=window.MythicBasicPacksData||[],attempt=null;
 const root=el('section','basic-pack-shop');root.id='store-pack-area';root.hidden=true;const heading=el('header'),status=el('p','basic-pack-status'),pendingBox=el('section','basic-pack-pending'),grid=el('div','basic-pack-grid');status.setAttribute('role','status');heading.append(el('small','eyebrow','EDIÇÃO INICIAL'),el('h2','','Pacotinhos de cartas'),el('p','','Todas as cartas atuais de cada mitologia em um pacote básico. Uma cópia de cada carta, sem sorteio. Novos lançamentos pertencerão a outras edições.'));root.append(heading,status,pendingBox,grid);view.append(root);
 function cost(value){const n=el('span','trixx-price');n.append(img(coin,'',false),el('b','',fmt(value)+' Trixx Coins'));return n;}
 function dialog(title,cls=''){
  const d=el('dialog','basic-pack-dialog '+cls),header=el('header'),close=button('Fechar',()=>d.close());d.setAttribute('aria-label',title);header.append(el('h2','',title),close);d.append(header);document.body.append(d);d.addEventListener('close',()=>d.remove(),{once:true});d.showModal();return d;
 }
 function cardsList(pack){const list=el('div','basic-pack-contents');for(const c of pack.cards){const item=el('article');item.append(img(c.art,c.name),el('b','',c.name),el('small','','1 cópia'));list.append(item);}return list;}
 function showContents(pack){const d=dialog(pack.name+' · '+pack.edition);d.append(el('p','',`${pack.cards.length} cartas garantidas. Uma cópia de cada, inclusive das que você já possui. A lista desta edição é fixa.`),cardsList(pack));}
 function draw(){
  grid.replaceChildren();pendingBox.replaceChildren();
  if(pending.length){pendingBox.append(el('h3','','Seus pacotes para abrir'));for(const p of pending){const row=el('article'),copy=el('div');copy.append(el('b','',p.name+' · '+p.edition),el('small','',`${p.revealed_count} / ${p.cards.length} cartas reveladas · já adquirido`));row.append(img(p.front,'',true),copy,button('Continuar abertura',()=>openPack(p),true));pendingBox.append(row);}}
  pendingBox.hidden=!pending.length;
  for(const p of catalog){
   const card=el('article','basic-pack-product panel'),showcase=button('',()=>showContents(p));showcase.className='basic-pack-showcase';showcase.setAttribute('aria-label','Ver as '+p.cards.length+' cartas do pacote '+p.name);
   const back=img(p.back,'Verso do pacote '+p.name),front=img(p.front,'Frente do pacote '+p.name);back.className='basic-pack-back';front.className='basic-pack-front';showcase.append(back,front);
   card.append(showcase,el('small','eyebrow',p.edition),el('h3','',p.name),el('p','',p.cards.length+' cartas · 1 cópia de cada'),cost(p.price),button('Ver todas as cartas',()=>showContents(p)));
   const owned=window.MythicStoreControl?.isTesting()?null:pending.find(x=>x.pack_id===p.id),buy=button(owned?'Abrir pacote adquirido':window.MythicStoreControl?.isTesting()?'Testar pacote':'Comprar pacote',()=>owned?openPack(owned):confirmPurchase(p),true);buy.disabled=!ready||buying;card.append(buy);grid.append(card);
  }
 }
 async function load(force=false){
  const who=uid();if(!who){ready=false;balance=0;pending=[];draw();status.textContent='Entre na conta para acessar os pacotes.';return;}
  if(loading)return;loading=true;const token=epoch,seenRevision=revision;status.textContent='Carregando pacotes e saldo…';
  try{const d=await rpc('get_basic_pack_shop');if(token!==epoch||who!==uid()||seenRevision!==revision)return;owner=who;catalog=d.catalog;pending=d.pending;balance=d.balance;ready=true;status.textContent='';draw();}
  catch(e){if(token===epoch&&who===uid()&&seenRevision===revision){ready=false;status.replaceChildren(el('span','','Não foi possível carregar os pacotes. '),button('Tentar novamente',()=>load(true)));draw();}}
  finally{if(token===epoch)loading=false;}
 }
 function attemptKey(who){return 'mythic-basic-pack-request:'+who;}
 function readAttempt(who){try{const saved=JSON.parse(localStorage.getItem(attemptKey(who)));if(saved&&saved.owner===who&&typeof saved.id==='string')return saved;}catch{}return attempt?.owner===who?attempt:null;}
 function saveAttempt(a){attempt=a;try{localStorage.setItem(attemptKey(a.owner),JSON.stringify(a));}catch{}}
 function clearAttempt(who){attempt=null;try{localStorage.removeItem(attemptKey(who));}catch{}}
 function confirmPurchase(pack){
  if(!ready||buying||!uid())return;const who=uid(),testIntent=Boolean(window.MythicStoreControl?.isTesting()),d=dialog('Comprar pacote de '+pack.name,'basic-pack-confirm');d.dataset.packOwner=who;
  const hero=el('div','basic-pack-confirm-hero');hero.append(img(pack.front,pack.name,false));const terms=el('div');terms.append(el('h3','',pack.edition),cost(pack.price),el('p','',testIntent?'Simulação de abertura. Nenhuma carta será entregue.':`${pack.cards.length} cartas garantidas. Você receberá uma cópia de cada carta desta edição.`),el('p','',`Seu saldo: ${fmt(balance)} Trixx Coins.`));
  if(window.MythicStoreControl?.isTesting())terms.append(el('p','basic-pack-notice','Modo teste: nenhuma cobrança ou entrega de cartas.'));const feedback=el('p');feedback.setAttribute('role','status');const confirm=button(window.MythicStoreControl?.isTesting()?'Testar abertura':balance>=pack.price?'Confirmar compra':'Saldo insuficiente',async()=>{
   if(buying||who!==uid()||!d.open)return;buying=true;confirm.disabled=true;feedback.textContent='Confirmando sua compra…';
   let request=readAttempt(who);if(!request||request.pack!==pack.id){request={owner:who,pack:pack.id,id:crypto.randomUUID()};saveAttempt(request);}
   try{const result=await rpc('buy_basic_pack_checked',{p_pack_id:pack.id,p_request_id:request.id,p_expected_price:pack.price,p_test_mode:testIntent});if(who!==uid())return;clearAttempt(who);revision++;balance=result.balance;const revealNow=d.open&&!view.hidden;d.close();ready=true;if(!result.test_mode)pending=[result.purchase,...pending.filter(x=>x.id!==result.purchase.id)].filter(x=>!x.opened_at);draw();if(revealNow)openPack(result.purchase);else notify(result.test_mode?'Simulação encerrada.':'Pacote adquirido! Você pode abri-lo na loja.');if(!result.test_mode)Promise.resolve(api().refreshProfile?.()).catch(()=>{});window.MythicStoreControl?.refresh();}
   catch(e){if(who===uid()&&d.isConnected){feedback.textContent=e.message;confirm.disabled=false;}}
   finally{buying=false;if(who===uid())draw();}
  },true);confirm.disabled=balance<pack.price&&!window.MythicStoreControl?.isTesting();
  if(balance<pack.price&&!window.MythicStoreControl?.isTesting())terms.append(el('p','basic-pack-notice','As recargas de Trixx Coins serão disponibilizadas em breve.'));
  terms.append(feedback,confirm);hero.append(terms);d.append(hero);
 }
 function openPack(receipt){
  if(viewer?.dialog.open||!uid()||!receipt?.cards?.length)return;const who=uid(),d=dialog(receipt.name+' · Abrir pacote','basic-pack-opening');d.dataset.packOwner=who;
  d.querySelector('header button').textContent='Continuar depois';const stage=el('div','basic-pack-opening-stage'),packet=el('div','basic-pack-large'),foil=img(receipt.front,receipt.name,false),strip=img(receipt.front,'',false);foil.className='basic-pack-large-body';strip.className='basic-pack-tear';packet.append(foil,strip);stage.append(packet);
  const reveal=el('div','basic-pack-reveal'),art=img(receipt.cards[Math.min(receipt.revealed_count,receipt.cards.length-1)].art,'',false),cardName=el('h3'),counter=el('p'),hint=el('p','basic-pack-open-hint',receipt.revealed_count?'Continue revelando suas cartas.':'Toque em “Abrir pacote” para romper o selo.'),controls=el('div','basic-pack-opening-controls'),feedback=el('p');feedback.setAttribute('role','status');counter.setAttribute('aria-live','polite');reveal.append(art,cardName,counter);reveal.hidden=true;stage.append(reveal);d.append(stage,hint,feedback,controls);
  const scene={dialog:d,owner:who,purchase:receipt,timer:null,busy:false};viewer=scene;const valid=()=>viewer===scene&&d.open&&who===uid();
  function showCard(){
   if(!valid())return;packet.hidden=true;reveal.hidden=false;controls.replaceChildren();hint.textContent=receipt.test_mode?'Simulação: esta carta não será adicionada à coleção.':'Uma cópia desta carta já está disponível na sua coleção.';
   const i=scene.purchase.revealed_count;
   if(i>=scene.purchase.cards.length){reveal.hidden=true;hint.textContent=receipt.test_mode?'Simulação concluída, sem cobrança ou entrega.':'Todas as cartas foram adicionadas à sua coleção!';controls.append(button('Concluir',()=>d.close(),true));return;}
   const c=scene.purchase.cards[i];art.src=safe(c.art);art.alt=c.name;cardName.textContent=c.name;counter.textContent=`Carta ${i+1} de ${scene.purchase.cards.length}`;reveal.classList.remove('is-dealing');requestAnimationFrame(()=>requestAnimationFrame(()=>{if(valid())reveal.classList.add('is-dealing');}));
   const next=button(receipt.test_mode?(i===scene.purchase.cards.length-1?'Concluir teste':'Revelar próxima'):i===scene.purchase.cards.length-1?'Guardar e concluir':'Guardar e revelar próxima',async()=>{
    if(!valid()||scene.busy)return;scene.busy=true;next.disabled=true;feedback.textContent=receipt.test_mode?'Revelando…':'Guardando progresso…';
    try{const result=receipt.test_mode?{...scene.purchase,revealed_count:scene.purchase.revealed_count+1,opened_at:scene.purchase.revealed_count+1===scene.purchase.cards.length?new Date().toISOString():null}:await rpc('reveal_basic_pack_card',{p_purchase_id:scene.purchase.id,p_expected_count:scene.purchase.revealed_count});if(!valid())return;revision++;scene.purchase=result;feedback.textContent='';if(!receipt.test_mode){pending=pending.filter(p=>p.id!==result.id);if(!result.opened_at)pending.unshift(result);}draw();if(result.opened_at){reveal.hidden=true;hint.textContent=receipt.test_mode?'Simulação concluída, sem cobrança ou entrega.':'Pacote aberto! Todas as cartas estão na sua coleção.';controls.replaceChildren(button('Concluir',()=>d.close(),true));}else showCard();}
    catch(e){if(valid()){feedback.textContent=e.message;next.disabled=false;}}
    finally{scene.busy=false;}
   },true);controls.append(next);
  }
  async function tear(){
   if(!valid()||scene.busy)return;scene.busy=true;controls.replaceChildren();hint.textContent='Abrindo seu pacote…';
   try{await art.decode?.();}catch{}
   if(!valid())return;d.classList.add('is-opening');
   const reduced=window.matchMedia('(prefers-reduced-motion: reduce)').matches;
   scene.timer=setTimeout(()=>{scene.busy=false;showCard();},reduced?0:1500);
  }
  art.onerror=()=>{if(valid())feedback.textContent='A imagem desta carta não carregou. Você pode continuar a abertura.';};
  if(receipt.opened_at)showCard();else if(receipt.revealed_count)showCard();else controls.append(button('Abrir pacote',tear,true));
  d.addEventListener('close',()=>{clearTimeout(scene.timer);if(viewer===scene)viewer=null;if(who===uid())load(true);},{once:true});
 }
 window.MythicPacksStore={setCategory(category){active=category==='packs';root.hidden=!active;if(active){draw();load();}},refresh:()=>load(true)};
 window.addEventListener('mythic-view-changed',e=>{if(e.detail?.view==='store')load(true);else document.querySelectorAll('.basic-pack-dialog').forEach(d=>d.close());});
 window.addEventListener('mythic-profile-loaded',()=>{if(owner&&owner!==uid()){epoch++;ready=false;pending=[];loading=false;balance=0;document.querySelectorAll('.basic-pack-dialog').forEach(d=>d.close());}if(!view.hidden)load(true);});
 window.addEventListener('mythic-account-signed-out',()=>{epoch++;owner=null;ready=false;loading=false;buying=false;balance=0;pending=[];attempt=null;document.querySelectorAll('.basic-pack-dialog').forEach(d=>d.close());draw();});
 draw();if(!view.hidden)load();
})();
