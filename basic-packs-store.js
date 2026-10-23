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
  if(viewer?.dialog.open||!uid()||!receipt?.cards?.length)return;const who=uid(),d=dialog(receipt.name+' · Abrir pacote','basic-pack-opening');d.dataset.packOwner=who;d.querySelector('header button').textContent='Continuar depois';
  const stage=el('div','basic-pack-opening-stage'),packet=el('button','basic-pack-large'),foil=img(receipt.front,receipt.name,false),strip=img(receipt.front,'',false);packet.type='button';packet.disabled=true;packet.setAttribute('aria-label','Abrir pacote de '+receipt.name);foil.className='basic-pack-large-body';strip.className='basic-pack-tear';packet.append(foil,strip);stage.append(packet);
  const reveal=el('div','basic-pack-reveal'),art=img(receipt.cards[Math.min(receipt.revealed_count,receipt.cards.length-1)].art,'',false),cardName=el('h3'),counter=el('p'),badge=el('span','pack-card-badge'),hint=el('p','basic-pack-open-hint','Preparando as imagens do pacote…'),controls=el('div','basic-pack-opening-controls'),feedback=el('p'),progress=el('progress','pack-load-progress'),summary=el('section','pack-summary'),delivery=el('p','pack-delivery');progress.max=receipt.cards.length;progress.value=0;feedback.setAttribute('role','status');counter.setAttribute('aria-live','polite');reveal.append(art,cardName,badge,counter);reveal.hidden=summary.hidden=true;stage.append(reveal);d.append(delivery,stage,hint,progress,feedback,controls,summary);
  delivery.textContent=receipt.test_mode?'MODO TESTE · Nenhuma cobrança, carta ou registro contábil.':'Compra confirmada · Cartas recebidas na coleção · Abertura visual';
  const preference=el('label','pack-motion-setting'),reducedInput=el('input');reducedInput.type='checkbox';reducedInput.checked=window.MythicMatchPresentation?.reduced?.()||matchMedia('(prefers-reduced-motion:reduce)').matches;preference.append(reducedInput,el('span','','Animação reduzida'));d.insertBefore(preference,stage);
  const scene={dialog:d,owner:who,purchase:receipt,timer:null,busy:false,ready:false,images:new Map(),epoch:0};viewer=scene;const valid=()=>viewer===scene&&d.open&&who===uid();
  if(receipt.test_mode&&receipt.duplicate_cards===undefined)receipt.duplicate_cards=window.MythicCollectionCopies?receipt.cards.filter(c=>Number(window.MythicCollectionCopies[c.id]||0)>0).map(c=>c.id):null;
  const duplicates=Array.isArray(receipt.duplicate_cards)?new Set(receipt.duplicate_cards):null;
  function label(c){return duplicates?(duplicates.has(c.id)?'Repetida · +1 cópia':'Nova · +1 cópia'):'1 cópia recebida';}
  function updateReceipt(result){if(who!==uid())return;revision++;scene.purchase=result;if(!receipt.test_mode){pending=pending.filter(p=>p.id!==result.id);if(!result.opened_at)pending.unshift(result);}draw();}
  function finish(){if(!valid())return;stage.hidden=true;summary.hidden=false;controls.replaceChildren(button('Concluir',()=>d.close(),true));summary.replaceChildren(el('h3','',receipt.test_mode?'Resumo da simulação':'Resumo do pacote'),el('p','',receipt.cards.length+' cartas · uma cópia de cada'+(duplicates?' · '+duplicates.size+' repetidas':'')));const grid=el('div','basic-pack-contents');for(const c of receipt.cards){const item=el('article');item.append(img(c.art,c.name),el('b','',c.name),el('small','',receipt.test_mode?'Simulação · '+label(c):label(c)));grid.append(item);}summary.append(grid);hint.textContent=receipt.test_mode?'Nenhum saldo ou item foi alterado.':'Abertura concluída. Todas as cartas já estão na sua coleção.';feedback.textContent='';progress.hidden=true;}
  async function saveProgress(all=false){if(!valid()||scene.busy)return;scene.busy=true;const selected=scene.purchase;controls.querySelectorAll('button').forEach(b=>b.disabled=true);feedback.textContent='Confirmando progresso da abertura…';
   try{const count=all?selected.cards.length:selected.revealed_count+1,result=receipt.test_mode?{...selected,revealed_count:count,opened_at:count===selected.cards.length?new Date().toISOString():null}:await rpc(all?'reveal_all_basic_pack_cards':'reveal_basic_pack_card',{p_purchase_id:selected.id,p_expected_count:selected.revealed_count});if(who!==uid())return;updateReceipt(result);if(!valid())return;feedback.textContent='';if(result.opened_at)finish();else await showCard();}
   catch(e){if(valid()){feedback.textContent=e.message+' Seu pacote continua salvo. Você pode tentar novamente ou continuar depois.';controls.querySelectorAll('button').forEach(b=>b.disabled=false);}}
   finally{scene.busy=false;}
  }
  async function showCard(){if(!valid())return;if(scene.purchase.opened_at||scene.purchase.revealed_count>=scene.purchase.cards.length){finish();return;}const i=scene.purchase.revealed_count,c=scene.purchase.cards[i],ticket=++scene.epoch;packet.hidden=true;reveal.hidden=false;controls.replaceChildren();reveal.classList.remove('is-dealing');art.hidden=false;art.src=safe(c.art);art.alt=c.name;cardName.textContent=c.name;counter.textContent=`Carta ${i+1} de ${scene.purchase.cards.length}`;badge.textContent=label(c);hint.textContent=receipt.test_mode?'Simulação: esta carta não será entregue.':'A carta já foi recebida. O botão abaixo guarda apenas o progresso da abertura.';
   try{await Promise.race([art.decode(),new Promise((_,reject)=>setTimeout(()=>reject(Error('timeout')),1800))]);}catch{if(valid()){art.hidden=true;feedback.textContent='A imagem não carregou. A carta continua na coleção e você pode seguir.';}}
   if(!valid()||ticket!==scene.epoch)return;reveal.classList.toggle('pack-reduced',reducedInput.checked);requestAnimationFrame(()=>{if(valid())reveal.classList.add('is-dealing');});controls.append(button(i===scene.purchase.cards.length-1?'Guardar e concluir':'Guardar e revelar próxima',()=>saveProgress(false),true),button('Revelar todas',()=>saveProgress(true)));
  }
  async function tear(){if(!valid()||scene.busy||!scene.ready)return;scene.busy=true;packet.disabled=true;controls.replaceChildren();hint.textContent='Abrindo seu pacote…';d.classList.add('is-opening');d.classList.toggle('pack-reduced',reducedInput.checked);scene.timer=setTimeout(()=>{scene.busy=false;showCard();},reducedInput.checked?0:1500);}
  packet.onclick=tear;art.onerror=()=>{if(valid())feedback.textContent='A imagem não carregou. Você pode continuar a abertura.';};
  async function prepare(){let at=0,done=0,failed=0;const worker=async()=>{while(valid()&&at<receipt.cards.length){const c=receipt.cards[at++];let ok=false;try{ok=await window.MythicMatchPresentation.preload(c.art);}catch{}if(!ok)failed++;done++;if(valid()){progress.value=done;hint.textContent='Preparando cartas: '+Math.round(done/receipt.cards.length*100)+'%';}}};await Promise.all(Array.from({length:4},worker));if(!valid())return;scene.ready=true;progress.hidden=true;packet.disabled=false;if(failed)feedback.textContent='Algumas imagens não carregaram. A abertura pode continuar.';if(receipt.opened_at)finish();else if(receipt.revealed_count)showCard();else{hint.textContent='Toque ou clique no pacote para romper o selo.';controls.append(button('Abrir pacote',tear,true));}}
  prepare();d.addEventListener('close',()=>{scene.epoch++;clearTimeout(scene.timer);if(viewer===scene)viewer=null;if(who===uid())load(true);},{once:true});
 }
 window.MythicPacksStore={setCategory(category){active=category==='packs';root.hidden=!active;if(active){draw();load();}},refresh:()=>load(true)};
 window.addEventListener('mythic-view-changed',e=>{if(e.detail?.view==='store')load(true);else document.querySelectorAll('.basic-pack-dialog').forEach(d=>d.close());});
 window.addEventListener('mythic-profile-loaded',()=>{if(owner&&owner!==uid()){epoch++;ready=false;pending=[];loading=false;balance=0;document.querySelectorAll('.basic-pack-dialog').forEach(d=>d.close());}if(!view.hidden)load(true);});
 window.addEventListener('mythic-account-signed-out',()=>{epoch++;owner=null;ready=false;loading=false;buying=false;balance=0;pending=[];attempt=null;document.querySelectorAll('.basic-pack-dialog').forEach(d=>d.close());draw();});
 draw();if(!view.hidden)load();
})();
