(() => {
 'use strict';
 const data=window.MythicAtlasDialogueData;if(!data)return;
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const reduced=()=>window.matchMedia('(prefers-reduced-motion: reduce)').matches;
 let active=null;
 function clearTimers(scene){clearTimeout(scene.textTimer);clearTimeout(scene.reactionTimer);scene.textTimer=scene.reactionTimer=null;}
 function finish(){
  const scene=active;if(!scene)return;active=null;clearTimers(scene);scene.resolve?.(false);scene.resolve=null;
  scene.dialog.close();scene.dialog.remove();
  if(scene.previous?.isConnected&&!scene.previous.disabled&&scene.previous.getClientRects().length)scene.previous.focus({preventScroll:true});
 }
 function play(node,options={}){
  const character=data.characters[node?.opponent];if(!character)return Promise.resolve(true);
  if(active?.loading)return Promise.resolve(false);finish();
  return new Promise(resolve=>{
   const dialog=el('dialog','atlas-conversation');dialog.setAttribute('aria-labelledby','atlas-conversation-name');dialog.setAttribute('aria-describedby','atlas-conversation-summary');
   const scene={dialog,resolve,previous:document.activeElement,character,options,node,loading:false,writing:false,stage:'opening',textTimer:null,reactionTimer:null,ready:false};active=scene;
   const safe=path=>window.MythicSecurity?.assetUrl?.(path)||path;
   dialog.style.setProperty('--atlas-talk-frame',`${1000*data.frameHold/data.fps}ms`);
   if(options.background)dialog.style.setProperty('--atlas-conversation-scene',`url("${safe(options.background)}")`);
   dialog.dataset.expression='normal';dialog.dataset.speaking='false';
   const header=el('header','atlas-conversation-header'),place=el('span','',character.location),exit=el('button','atlas-conversation-exit','×');exit.type='button';exit.setAttribute('aria-label','Voltar sem iniciar a partida');header.append(place,exit);
   const summary=el('p','atlas-conversation-sr','Converse com Aquiles e escolha suas respostas. A partida começa após a última resposta.');summary.id='atlas-conversation-summary';
   const figure=el('figure','atlas-conversation-portrait');figure.setAttribute('role','img');figure.setAttribute('aria-label','Aquiles, de armadura dourada, elmo de crista vermelha e cabelos loiros.');
   const images=[];for(const [expression,path] of Object.entries(character.images)){const img=el('img','atlas-conversation-frame is-'+expression);img.src=safe(path);img.alt='';img.decoding='async';img.loading='eager';img.draggable=false;figure.append(img);images.push(img);}
   const bubble=el('section','atlas-conversation-bubble'),eyebrow=el('small','atlas-conversation-kicker','ENCONTRO NO ATLAS'),name=el('h2','',character.name);name.id='atlas-conversation-name';
   const reply=el('p','atlas-conversation-reply');reply.hidden=true;
   const line=el('p','atlas-conversation-line');line.setAttribute('aria-hidden','true');
   const accessible=el('p','atlas-conversation-sr');accessible.setAttribute('role','status');accessible.setAttribute('aria-live','polite');accessible.setAttribute('aria-atomic','true');
   const complete=el('button','atlas-conversation-complete','Mostrar fala completa');complete.type='button';complete.hidden=true;
   const choices=el('div','atlas-conversation-choices');choices.setAttribute('role','group');choices.setAttribute('aria-label','Escolha sua resposta');
   const caption=el('p','atlas-conversation-caption','Sua resposta conduz este encontro.');bubble.append(eyebrow,name,reply,line,accessible,complete,choices,caption);dialog.append(header,summary,figure,bubble);document.body.append(dialog);
   const valid=()=>active===scene&&(options.isValid?.()??true);
   function showChoices(){
    if(!valid()){if(active===scene)finish();return;}scene.writing=false;dialog.dataset.speaking='false';complete.hidden=true;line.textContent=scene.utterance.text;choices.replaceChildren();
    scene.utterance.choices.forEach((choice,index)=>{const button=el('button','atlas-conversation-choice'),number=el('span','',String(index+1)),text=el('span','',choice.text);number.setAttribute('aria-hidden','true');button.type='button';button.append(number,text);button.onclick=()=>answer(choice);choices.append(button);});
    caption.textContent='Escolha uma resposta para continuar.';
   }
   function speak(utterance){
    clearTimers(scene);scene.utterance=utterance;scene.writing=true;scene.characters=Array.from(utterance.text);scene.position=0;choices.replaceChildren();complete.hidden=false;line.textContent='';accessible.textContent=utterance.text;dialog.dataset.expression='normal';dialog.dataset.speaking='true';caption.textContent='Aquiles está falando…';
    if(reduced()){showChoices();return;}
    function tick(){if(!valid()){if(active===scene)finish();return;}if(document.hidden){scene.textTimer=setTimeout(tick,150);return;}scene.position++;line.textContent=scene.characters.slice(0,scene.position).join('');if(scene.position>=scene.characters.length)showChoices();else scene.textTimer=setTimeout(tick,data.textCharacterMs);}
    tick();
   }
   function beginDuel(){
    if(!valid()){if(active===scene)finish();return;}if(document.hidden){scene.ready=true;return;}scene.ready=false;scene.loading=true;clearTimers(scene);exit.disabled=true;choices.replaceChildren();complete.hidden=true;dialog.dataset.speaking='false';caption.textContent='Preparando o duelo…';caption.setAttribute('role','status');dialog.setAttribute('aria-busy','true');scene.resolve?.(true);scene.resolve=null;
   }
   function answer(choice){
    if(!valid()||scene.writing||scene.loading||scene.stage==='reaction')return;
    reply.hidden=false;reply.textContent='Você: '+choice.text;
    if(scene.stage==='opening'){scene.stage='question';speak(character.question);return;}
    scene.stage='reaction';clearTimers(scene);choices.replaceChildren();dialog.dataset.speaking='false';dialog.dataset.expression=choice.expression;figure.setAttribute('aria-label',choice.reaction);line.textContent=choice.reaction;accessible.textContent=choice.reaction;caption.textContent='O duelo vai começar.';scene.reactionTimer=setTimeout(beginDuel,data.reactionHoldMs);
   }
   complete.onclick=()=>{if(scene.writing){clearTimeout(scene.textTimer);showChoices();choices.querySelector('button')?.focus();}};
   exit.onclick=()=>{if(!scene.loading)finish();};dialog.addEventListener('cancel',e=>{e.preventDefault();if(!scene.loading)finish();});dialog.addEventListener('close',()=>{if(active===scene)finish();});
   dialog.showModal();exit.focus({preventScroll:true});line.textContent='Aquiles se aproxima…';caption.textContent='Carregando o encontro…';dialog.setAttribute('aria-busy','true');
   const load=img=>img.decode?img.decode():new Promise((done,fail)=>{if(img.complete)return img.naturalWidth?done():fail();img.onload=done;img.onerror=fail;});
   async function prepare(){
    dialog.setAttribute('aria-busy','true');choices.replaceChildren();line.textContent='Aquiles se aproxima…';caption.textContent='Carregando o encontro…';
    try{await Promise.all(images.map(load));if(!valid()){if(active===scene)finish();return;}dialog.removeAttribute('aria-busy');speak(character.opening);}
    catch{if(!valid())return;dialog.removeAttribute('aria-busy');line.textContent='Não foi possível carregar as imagens de Aquiles.';accessible.textContent=line.textContent;caption.textContent='Sua partida ainda não foi iniciada.';const retry=el('button','atlas-conversation-choice','Tentar novamente');retry.type='button';retry.onclick=()=>{for(const img of images){const src=img.src;img.removeAttribute('src');img.src=src;}prepare();};choices.append(retry);}
   }
   prepare();
  });
 }
 document.addEventListener('visibilitychange',()=>{if(active?.ready&&!document.hidden){const scene=active;scene.reactionTimer=setTimeout(()=>{if(active===scene&&scene.options.isValid?.()!==false){scene.loading=true;scene.dialog.dataset.speaking='false';scene.dialog.setAttribute('aria-busy','true');scene.dialog.querySelector('.atlas-conversation-exit').disabled=true;scene.dialog.querySelector('.atlas-conversation-caption').textContent='Preparando o duelo…';scene.resolve?.(true);scene.resolve=null;scene.ready=false;}else if(active===scene)finish();},0);}});
 window.addEventListener('mythic-account-signed-out',finish);
 window.addEventListener('mythic-view-changed',e=>{if(e.detail?.view!=='guardian')finish();});
 window.MythicAtlasDialogue={play,finish,has:node=>!!data.characters[node?.opponent]};
})();
