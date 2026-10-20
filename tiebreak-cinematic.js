(() => {
 'use strict';
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const button=(text,fn)=>{const n=el('button','button button-primary',text);n.type='button';n.addEventListener('click',fn);return n;};
 const art=id=>(window.MythicCardData?.()||[]).find(c=>c.id===id)?.art||'assets/card-back.svg';
 const image=(src,alt='')=>{const n=el('img');n.src=window.MythicSecurity.assetUrl(src);n.alt=alt;n.draggable=false;return n;};
 let dialog,stage,actions,kicker,title,subtitle,history,skip,activeKey=null,generation=0,fast=false,timers=new Map(),continueStep=null;
 function pause(ms){return new Promise(resolve=>{const handle=setTimeout(()=>{timers.delete(handle);resolve();},fast?25:ms);timers.set(handle,resolve);});}
 function flush(){for(const [h,resolve] of timers){clearTimeout(h);resolve();}timers.clear();}
 function close(){generation++;flush();continueStep?.();continueStep=null;activeKey=null;if(dialog?.open)dialog.close();document.body.classList.remove('tiebreak-open');}
 function ensure(){
  if(dialog)return;dialog=el('dialog','tb-cinematic');dialog.setAttribute('aria-labelledby','tb-title');
  const shell=el('section','tb-shell'),top=el('header','tb-heading');kicker=el('p','eyebrow');title=el('h1');title.id='tb-title';subtitle=el('p','tb-subtitle');subtitle.setAttribute('role','status');top.append(kicker,title,subtitle);
  stage=el('div','tb-stage');history=el('ol','tb-history');history.setAttribute('aria-label','Histórico das puxadas');actions=el('footer','tb-actions');
  skip=button('Reduzir animações',()=>{fast=true;dialog.classList.add('tb-reduced');flush();});skip.className='tb-skip';
  shell.append(skip,top,history,stage,actions);dialog.append(shell);document.body.append(dialog);dialog.addEventListener('cancel',e=>e.preventDefault());
 }
 function finalAction(){actions.replaceChildren(button('Ver resumo da partida',()=>{close();document.querySelector('#tie-break-continue')?.click();}));}
 function nextAction(text){return new Promise(resolve=>{continueStep=resolve;actions.replaceChildren(button(text,()=>{continueStep=null;actions.replaceChildren();resolve();}));});}
 function setHeading(head,copy){title.textContent=head;subtitle.textContent=copy;}
 function side(name,cardId,sideKey){
  const panel=el('article','tb-contender '+sideKey),label=el('h2','',name),stack=el('div','tb-card-stack');
  for(let i=0;i<2;i++){const back=image('assets/card-back.svg');back.className='tb-ghost tb-ghost-'+i;stack.append(back);}
  const flip=el('div','tb-flip'),back=image('assets/card-back.svg','Carta virada'),front=image(art(cardId),'Unidade sorteada');back.className='tb-back';front.className='tb-front';flip.append(back,front);stack.append(flip);const meter=el('b','tb-power'),power=el('span','tb-power-value','?');meter.append(power);panel.append(label,stack,meter);return {panel,power,flip};
 }
 function drawHistory(draw){const item=el('li'),n=el('small','',String(draw.round)),a=image(art(draw.player_one)),b=image(art(draw.player_two));item.append(n,a,el('b','',`${draw.player_one_power} × ${draw.player_two_power}`),b);item.title=draw.player_one_power===draw.player_two_power?'Empate':'Puxada decisiva';history.append(item);}
 function chime(won){if(document.querySelector('#setting-effects')?.checked===false)return;try{const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)return;const ctx=new Audio();[0,120,240].forEach((delay,i)=>{const osc=ctx.createOscillator(),gain=ctx.createGain(),at=ctx.currentTime+delay/1000;osc.type='sine';osc.frequency.value=(won?440:220)*[1,1.25,1.5][i];gain.gain.setValueAtTime(.03,at);gain.gain.exponentialRampToValueAtTime(.0001,at+.6);osc.connect(gain);gain.connect(ctx.destination);osc.start(at);osc.stop(at+.6);});setTimeout(()=>ctx.close(),1300);}catch{}}
 async function present(data,token){
  const own=data.my_side||'player_one',names={player_one:data.player_one_name||'Invocador',player_two:data.player_two_name||'Oponente'};
  const images=[...(data.draws||[]).flatMap(d=>[art(d.player_one),art(d.player_two)]),'assets/eclipse/eclipse.png','assets/eclipse/eclipse-lunar.png','assets/eclipse/eclipse-solar.png'];
  await Promise.race([Promise.all(images.map(src=>{const img=new Image();img.src=window.MythicSecurity.assetUrl(src);return img.decode().catch(()=>{});})),pause(3500)]);if(token!==generation)return;
  for(const draw of data.draws||[]){
   kicker.textContent=`PUXADA ${draw.round} DE 5`;setHeading('DESEMPATE','Unidades sorteadas dos baralhos · O menor poder base vence');
   const left=side(names.player_one,draw.player_one,'player_one'),right=side(names.player_two,draw.player_two,'player_two'),versus=el('div','tb-comparison','✦');stage.className='tb-stage tb-duel';stage.replaceChildren(left.panel,versus,right.panel);
   await pause(650);if(token!==generation)return;left.flip.classList.add('tb-turned');right.flip.classList.add('tb-turned');
   await pause(650);if(token!==generation)return;left.power.textContent=draw.player_one_power;right.power.textContent=draw.player_two_power;
   const tied=draw.player_one_power===draw.player_two_power;versus.textContent=tied?'=':draw.player_one_power<draw.player_two_power?'<':'>';
   if(!tied){const winner=draw.player_one_power<draw.player_two_power?'player_one':'player_two';(winner==='player_one'?left:right).panel.classList.add('tb-winner');subtitle.textContent=names[winner]+' vence a puxada';}
   else subtitle.textContent='Empate na puxada · O destino continua em aberto';drawHistory(draw);
   await pause(tied?1800:1400);if(token!==generation)return;
  }
  if(data.eclipse){
   kicker.textContent='A DECISÃO DO ECLIPSE';setHeading(data.empty_pool?'O ECLIPSE DECIDIRÁ':'CINCO PUXADAS. CINCO EMPATES.','Cada lado recebeu uma face do Eclipse. A revelação tem 50% de chance para cada resultado.');
   const assignment=el('div','tb-assignments');for(const key of ['player_one','player_two']){const lunar=key===data.lunar_side,panel=el('article','tb-assignment '+key);panel.append(el('h2','',names[key]),image('assets/eclipse/eclipse-'+(lunar?'lunar':'solar')+'.png',lunar?'Eclipse Lunar atribuído':'Eclipse Solar atribuído'),el('b','',lunar?'LUNAR ATRIBUÍDO':'SOLAR ATRIBUÍDO'));assignment.append(panel);}
   stage.className='tb-stage';stage.replaceChildren(assignment);await nextAction('Iniciar revelação ✦');if(token!==generation)return;
   setHeading('SOL OU LUA?','50% LUNAR · 50% SOLAR');const reveal=el('div','tb-eclipse'),vortex=image('assets/identity-v2/eclipse-vortex.webp');vortex.className='tb-vortex';
   const orbit=el('div','eclipse-orbit');orbit.append(el('i'),el('i'),el('div','eclipse-orb'));
   const card=image('assets/eclipse/eclipse.png','Eclipse aguardando sorteio');card.className='tb-eclipse-card';reveal.append(vortex,orbit,card);stage.replaceChildren(reveal);
   await pause(2200);if(token!==generation)return;
   reveal.classList.add('tb-celestial-revealed');reveal.dataset.result=data.eclipse;card.src=window.MythicSecurity.assetUrl('assets/eclipse/'+data.eclipse+'.png');card.alt=data.eclipse==='eclipse-lunar'?'Eclipse Lunar sorteado':'Eclipse Solar sorteado';
   setHeading(data.eclipse==='eclipse-lunar'?'ECLIPSE LUNAR':'ECLIPSE SOLAR','A face revelada decide a partida');await pause(1000);if(token!==generation)return;
   const label=el('div','tb-assigned-labels');for(const key of ['player_one','player_two'])label.append(el('span',key===data.winner_side?'tb-victor-label':'',names[key]+' · '+(key===data.lunar_side?'LUNAR':'SOLAR')));stage.append(label);
  }
  const won=data.winner_side===own;dialog.dataset.result=won?'victory':'defeat';subtitle.textContent=names[data.winner_side]+' VENCEU A PARTIDA';subtitle.classList.add('tb-victory-text');chime(won);skip.hidden=true;window.dispatchEvent(new CustomEvent("mythic-tiebreak-resolved",{detail:{...data,my_side:own}}));finalAction();window.MythicOnline?.refreshProfile?.();
 }
 async function open(key,request){
  if(activeKey===key&&dialog?.open)return;close();ensure();activeKey=key;fast=matchMedia('(prefers-reduced-motion: reduce)').matches;const token=generation;
  dialog.className='tb-cinematic'+(fast?' tb-reduced':'');delete dialog.dataset.result;skip.hidden=false;history.replaceChildren();actions.replaceChildren();stage.replaceChildren();subtitle.classList.remove('tb-victory-text');kicker.textContent='O DESTINO DA ARENA';setHeading('PREPARANDO O DESEMPATE','Confirmando o sorteio…');
  dialog.showModal();document.body.classList.add('tiebreak-open');document.querySelector('#match-result-banner').hidden=true;
  try{const data=await request();if(token!==generation)return;if(data?.version!==2||!data.winner_side)throw Error('Aplique o SQL 030 para ativar o novo desempate.');await present(data,token);}
  catch(e){if(token!==generation)return;setHeading('NÃO FOI POSSÍVEL CARREGAR',e.message);actions.replaceChildren(button('Tentar novamente',()=>{activeKey=null;open(key,request);}),button('Ver resumo da partida',()=>{close();document.querySelector('#tie-break-continue')?.click();}));skip.hidden=true;}
 }
 window.MythicTieBreak={openCampaign:data=>open('campaign:'+data.match_id,()=>Promise.resolve(data)),openOnline:id=>open('online:'+id,()=>window.MythicOnline.portalRequest('get_tiebreak_state',{p_match_id:id})),openGuardian:({id,points,cards})=>open('guardian:'+id,()=>window.MythicOnline.portalRequest('resolve_guardian_tiebreak',{p_match_id:id,p_points:points,p_cards:cards})),close};
 window.addEventListener('mythic-account-signed-out',close);window.addEventListener('mythic-session-changed',close);
})();
