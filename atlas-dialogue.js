(() => {
 'use strict';
 const data=window.MythicAtlasDialogueData;if(!data)return;
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const safe=path=>window.MythicSecurity?.assetUrl?.(path)||path;
 const reduced=()=>window.matchMedia('(prefers-reduced-motion: reduce)').matches;
 let active=null;
 function clearTimers(scene){clearTimeout(scene.textTimer);clearTimeout(scene.reactionTimer);scene.textTimer=scene.reactionTimer=null;}
 function finish(value=false){
  const scene=active;if(!scene)return;active=null;clearTimers(scene);scene.observer?.disconnect();scene.resolve?.(value);scene.resolve=null;
  scene.dialog.close();scene.dialog.remove();
  if(scene.previous?.isConnected&&!scene.previous.disabled&&scene.previous.getClientRects().length)scene.previous.focus({preventScroll:true});
 }
 function eligible(node){return node?.region==='greece'&&Number(node.chapter)===0&&!!data.characters[node.opponent];}
 function play(node,options={}){
  const character=data.characters[node?.opponent],post=options.mode==='outcome';if(!character||!post&&!eligible(node))return Promise.resolve(true);
  if(active?.loading)return Promise.resolve(false);finish();
  return new Promise(resolve=>{
   const dialog=el('dialog','atlas-conversation');dialog.setAttribute('aria-labelledby','atlas-conversation-name');dialog.setAttribute('aria-describedby','atlas-conversation-summary');
   const scene={dialog,resolve,previous:document.activeElement,character,options,loading:false,writing:false,textTimer:null,reactionTimer:null};active=scene;
   const valid=()=>active===scene&&(options.isValid?.()??true);
   dialog.style.setProperty('--atlas-talk-frame',`${1000*data.frameHold/data.fps}ms`);
   if(options.background)dialog.style.setProperty('--atlas-conversation-scene',`url("${safe(options.background)}")`);
   dialog.dataset.expression='normal';dialog.dataset.speaking='false';
   const header=el('header','atlas-conversation-header'),place=el('span','',character.location),exit=el('button','atlas-conversation-exit','×');exit.type='button';exit.setAttribute('aria-label',post?'Continuar para o resumo':'Voltar sem iniciar a partida');header.append(place,exit);
   const summary=el('p','atlas-conversation-sr',post?'Ouça '+character.name+' após o duelo.':'Converse com '+character.name+' e escolha suas respostas. A partida começa após a última resposta.');summary.id='atlas-conversation-summary';
   const figure=el('figure','atlas-conversation-portrait');figure.setAttribute('role','img');figure.setAttribute('aria-label',character.description);
   const images=[],image=src=>{const i=new Image();i.src=safe(src);i.decoding='async';i.loading='eager';i.alt='';i.draggable=false;images.push(i);return i;};
   if(character.sheet){
    const sprite=el('div','atlas-conversation-sprite');figure.append(sprite);image(character.sheet);
    for(const [expression,[col,row]] of Object.entries(character.cells)){
     const frame=el('span','atlas-conversation-frame atlas-conversation-sheet is-'+expression);frame.style.backgroundImage=`url("${safe(character.sheet)}")`;frame.style.backgroundPosition=`${col*50}% ${row*100}%`;sprite.append(frame);
    }
    scene.observer=new ResizeObserver(()=>{const size=Math.max(0,Math.min(figure.clientWidth,figure.clientHeight));sprite.style.width=size+'px';sprite.style.height=size+'px';});scene.observer.observe(figure);
   }else for(const [expression,path] of Object.entries(character.images)){const i=image(path);i.className='atlas-conversation-frame is-'+expression;figure.append(i);}
   const bubble=el('section','atlas-conversation-bubble'),eyebrow=el('small','atlas-conversation-kicker',post?(options.outcome==='victory'?'APÓS SUA VITÓRIA':'APÓS O DUELO'):'ENCONTRO NO ATLAS'),name=el('h2','',character.name);name.id='atlas-conversation-name';
   const reply=el('p','atlas-conversation-reply');reply.hidden=true;
   const line=el('p','atlas-conversation-line');line.setAttribute('aria-hidden','true');
   const accessible=el('p','atlas-conversation-sr');accessible.setAttribute('role','status');accessible.setAttribute('aria-live','polite');accessible.setAttribute('aria-atomic','true');
   const complete=el('button','atlas-conversation-complete','Mostrar fala completa');complete.type='button';complete.hidden=true;
   const choices=el('div','atlas-conversation-choices');choices.setAttribute('role','group');choices.setAttribute('aria-label',post?'Continuar após o duelo':'Escolha sua resposta');
   const caption=el('p','atlas-conversation-caption');bubble.append(eyebrow,name,reply,line,accessible,complete,choices,caption);dialog.append(header,summary,figure,bubble);document.body.append(dialog);
   function beginDuel(){
    if(!valid()){if(active===scene)finish();return;}
    if(document.hidden){scene.reactionTimer=setTimeout(beginDuel,200);return;}
    scene.loading=true;clearTimers(scene);exit.disabled=true;choices.replaceChildren();complete.hidden=true;dialog.dataset.speaking='false';caption.textContent='Preparando o duelo…';caption.setAttribute('role','status');dialog.setAttribute('aria-busy','true');scene.resolve?.(true);scene.resolve=null;
   }
   function showChoices(){
    if(!valid()){if(active===scene)finish();return;}clearTimeout(scene.textTimer);scene.writing=false;dialog.dataset.speaking='false';dialog.dataset.expression=scene.utterance.expression||'normal';complete.hidden=true;line.textContent=scene.utterance.text;choices.replaceChildren();
    if(post){const b=el('button','atlas-conversation-choice','Ver resumo da partida');b.type='button';b.onclick=()=>finish(true);choices.append(b);caption.textContent='Sua recompensa já foi registrada.';return;}
    if(scene.utterance.duel){caption.textContent='O duelo vai começar.';scene.reactionTimer=setTimeout(beginDuel,data.reactionHoldMs);return;}
    for(const [index,choice] of scene.utterance.choices.entries()){
     const b=el('button','atlas-conversation-choice'),number=el('span','',String(index+1));number.setAttribute('aria-hidden','true');b.type='button';b.append(number,el('span','',choice.text));b.onclick=()=>{if(!valid()||scene.writing||scene.loading)return;reply.hidden=false;reply.textContent=choice.text==='Continuar'?'':'Você: '+choice.text;reply.hidden=!reply.textContent;speak(character.script[choice.next]);};choices.append(b);
    }
    caption.textContent='Escolha uma resposta para continuar.';
   }
   function speak(utterance){
    if(!utterance){finish();return;}clearTimers(scene);scene.utterance=utterance;scene.writing=true;scene.characters=Array.from(utterance.text);scene.position=0;choices.replaceChildren();complete.hidden=false;line.textContent='';accessible.textContent=utterance.text;dialog.dataset.narration=String(!!utterance.narration);dialog.dataset.expression=utterance.narration?(utterance.expression||'normal'):'normal';dialog.dataset.speaking=String(!utterance.narration);caption.textContent=utterance.narration?'':character.name+' está falando…';
    if(reduced()){showChoices();return;}
    function tick(){if(!valid()){if(active===scene)finish();return;}if(document.hidden){scene.textTimer=setTimeout(tick,150);return;}scene.position++;line.textContent=scene.characters.slice(0,scene.position).join('');if(scene.position>=scene.characters.length)showChoices();else scene.textTimer=setTimeout(tick,data.textCharacterMs);}
    tick();
   }
   complete.onclick=()=>{if(scene.writing){clearTimeout(scene.textTimer);showChoices();choices.querySelector('button')?.focus();}};
   exit.onclick=()=>{if(!scene.loading)finish(post);};dialog.addEventListener('cancel',e=>{e.preventDefault();if(!scene.loading)finish(post);});dialog.addEventListener('close',()=>{if(active===scene)finish(post);});
   dialog.addEventListener('keydown',e=>{if(!scene.writing&&!scene.loading&&/^[1-9]$/.test(e.key)){const b=choices.children[Number(e.key)-1];if(b){e.preventDefault();b.click();}}});
   const load=i=>i.decode?i.decode():new Promise((done,fail)=>{if(i.complete)return i.naturalWidth?done():fail();i.onload=done;i.onerror=fail;});
   async function prepare(){
    dialog.setAttribute('aria-busy','true');choices.replaceChildren();line.textContent=character.name+' se aproxima…';caption.textContent='Carregando o encontro…';
    try{await Promise.all(images.map(load));if(!valid()){if(active===scene)finish();return;}dialog.removeAttribute('aria-busy');speak(post?character.outcomes[options.outcome]:character.script.opening);}
    catch{if(!valid())return;dialog.removeAttribute('aria-busy');line.textContent='Não foi possível carregar as imagens de '+character.name+'.';accessible.textContent=line.textContent;caption.textContent=post?'O resultado da partida está salvo.':'Sua partida ainda não foi iniciada.';const retry=el('button','atlas-conversation-choice','Tentar novamente');retry.type='button';retry.onclick=()=>{for(const i of images){const src=i.src;i.removeAttribute('src');i.src=src;}prepare();};choices.append(retry);if(post){const skip=el('button','atlas-conversation-choice','Ir para o resumo');skip.type='button';skip.onclick=()=>finish(true);choices.append(skip);}}
   }
   dialog.showModal();exit.focus({preventScroll:true});prepare();
  });
 }
 function outcome(node,result,options={}){if(!eligible(node)||!data.characters[node.opponent]?.outcomes?.[result])return Promise.resolve(true);return play(node,{...options,mode:'outcome',outcome:result});}
 window.addEventListener('mythic-account-signed-out',()=>finish());
 window.addEventListener('mythic-view-changed',e=>{if(!active)return;const allowed=active.options.mode==='outcome'?['duel']:['guardian'];if(!allowed.includes(e.detail?.view))finish();});
 window.MythicAtlasDialogue={play,outcome,finish:()=>finish(),has:eligible};
})();
