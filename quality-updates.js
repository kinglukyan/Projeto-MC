(() => {
 'use strict';
 const $=s=>document.querySelector(s),el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const normalize=s=>String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('pt-BR');
 const catalog=()=>window.MythicCardData?.()||[],counts=()=>window.MythicCollectionCopies||{},api=()=>window.MythicOnline;
 const safe=p=>window.MythicSecurity?.assetUrl?.(p)||'';
 function preview(select,container){if(!select||!container)return;const c=catalog().find(c=>c.id===select.value);container.replaceChildren();if(!c)return;if(c.art){const img=el('img');img.src=safe(c.art);img.alt=c.name;img.loading='lazy';container.append(img);}container.append(el('strong','',c.name),el('small','',`${Number(counts()[c.id])||0} cópia(s) na coleção`));}
 function fill(select,rows,placeholder){if(!select)return;const old=select.value,next=JSON.stringify(rows);if(select.dataset.optionsKey===next)return;select.dataset.optionsKey=next;select.replaceChildren(new Option(placeholder,''),...rows.map(([id,text])=>new Option(text,id)));if(rows.some(([id])=>id===old))select.value=old;}
 function collection(){
  const cards=catalog().filter(c=>!c.specialOnly&&!c.previewOnly&&Number(counts()[c.id])>0).sort((a,b)=>a.name.localeCompare(b.name,'pt-BR'));
  fill($('#gift-card-id'),cards.filter(c=>Number(counts()[c.id])>1).map(c=>[c.id,`${c.name} · ${Number(counts()[c.id])-1} disponível(is)`]),'Escolha uma carta para presentear');
  fill($('#expedition-card-id'),cards.map(c=>[c.id,`${c.name} · ${Number(counts()[c.id])} cópia(s)`]),'Escolha uma carta da coleção');
  preview($('#expedition-card-id'),$('#expedition-card-preview'));preview($('#gift-card-id'),$('#gift-card-preview'));giftState();
 }
 function status(form,text){let node=form.querySelector('.eligibility-status');if(!node){node=el('p','eligibility-status');node.setAttribute('role','status');form.append(node);}node.textContent=text;}
 function canGift(kind){const form=$(kind==='card'?'#friend-card-gift-form':'#friend-gift-form');if(!form||!api()?.isConnected?.()||form.dataset.sending==='true')return false;const friend=$(kind==='card'?'#gift-card-friend-select':'#gift-friend-select')?.value;if(!friend)return false;if(kind==='card')return Number(counts()[$('#gift-card-id')?.value])>1;const n=Number($('#gift-coins')?.value),balance=Number(($('#profile-coins')?.textContent||'0').replace(/[^\d]/g,''));return Number.isInteger(n)&&n>=1&&n<=Math.min(500,balance);}
 function giftState(){for(const kind of ['coins','card']){const form=$(kind==='card'?'#friend-card-gift-form':'#friend-gift-form');if(!form)continue;const submit=form.querySelector('button[type=submit],button:not([type])');submit.disabled=!canGift(kind);const friends=$(kind==='card'?'#gift-card-friend-select':'#gift-friend-select');status(form,friends?.options.length<=1?'Adicione um amigo para enviar presentes.':kind==='card'&&!$('#gift-card-id')?.value?'Selecione uma carta com cópia extra. Você mantém ao menos uma.':kind==='coins'&&!canGift(kind)?'Escolha um amigo e uma quantidade que caiba no seu saldo.':'');}}
 function publishOptions(){const decks=window.MythicPresentation?.read?.().decks||[];fill($('#community-deck-select'),decks.map((d,i)=>[String(i),`${d.name||'Baralho '+(i+1)} · ${Object.values(d.cards||{}).reduce((s,n)=>s+Number(n),0)} cartas`]),'Escolha um baralho salvo');}
 function preparePublish(){const index=Number($('#community-deck-select')?.value),decks=window.MythicPresentation?.read?.().decks||[];if(!$('#community-deck-select')?.value||!Number.isInteger(index)||!decks[index]){window.MythicPresentation?.notify?.('Escolha um baralho salvo.');return false;}const d=decks[index];$('#community-deck-code').value=JSON.stringify(d.cards||{});return true;}
 window.MythicQuality={canGift,preparePublish,refresh:collection};
 const connectionMessage=message=>/failed to fetch|networkerror|network request|load failed|fetch failed|conexão.*interrompida|verifique sua internet/i.test(String(message));
 window.MythicConnection={
  friendly:message=>connectionMessage(message)?'A conexão foi interrompida. Verifique sua internet e tente novamente.':String(message||''),
  decorate(toast,message){if(!connectionMessage(message))return false;const retry=el('button','toast-retry','Tentar novamente');retry.type='button';retry.onclick=async()=>{retry.disabled=true;retry.textContent='Reconectando…';try{await api()?.retryConnection?.();toast.classList.remove('show');}catch{retry.disabled=false;retry.textContent='Tentar novamente';}};toast.append(retry);return true;}
 };
 $('#community-deck-select')?.addEventListener('change',()=>{const d=window.MythicPresentation?.read?.().decks?.[Number($('#community-deck-select').value)];if(d){$('#community-deck-title').value=d.name||'';preparePublish();}});
 for(const id of ['#gift-friend-select','#gift-card-friend-select','#gift-coins','#gift-card-id'])$(id)?.addEventListener('input',()=>{giftState();preview($('#gift-card-id'),$('#gift-card-preview'));});
 const giftForm=$('#friend-card-gift-form');if(giftForm){const p=el('div','owned-card-preview');p.id='gift-card-preview';giftForm.querySelector('label:last-of-type')?.after(p);}
 $('#expedition-card-id')?.addEventListener('change',()=>preview($('#expedition-card-id'),$('#expedition-card-preview')));
 for(const name of ['mythic-profile-loaded','mythic-lobby-friends','mythic-deck-saved','mythic-concept-profile'])window.addEventListener(name,()=>{collection();publishOptions();});
 window.addEventListener('mythic-account-signed-out',()=>{for(const s of ['#expedition-card-id','#gift-card-id','#community-deck-select'])fill($(s),[],'Entre na conta para selecionar');giftState();});
 // Collapse navigation by its own controls, so listeners and ARIA state stay in sync.
 window.addEventListener('mythic-view-changed',()=>{for(const id of ['#friends-menu-toggle','#missions-menu-toggle','#deck-menu-toggle']){const n=$(id);if(n?.getAttribute('aria-expanded')==='true')n.click();}publishOptions();});

 // Preserve the hand rule for regular games; explain free practice separately.
 const handRule=$('#player-hand')?.parentElement?.querySelector('p');const originalHandRule=handRule?.textContent;
 window.addEventListener('mythic-practice-state',e=>{if(handRule)handRule.textContent=e.detail?'Teste livre: todas as cartas começam na mão. Use o laboratório para reservar compras, avançar turnos e montar situações.':originalHandRule;});

 // Diagnose loading failures by showing the character itself, never an empty banner.
 const banner=$('.concept-story-banner');let bannerKey='';
 function bannerFallback(){if(!banner)return;const id=banner.dataset.customBanner||banner.dataset.hero;if(!id||bannerKey===id)return;bannerKey=id;const art=window.MythicUniverseBanners?.[id],node=banner.querySelector('.universe-banner-art'),c=catalog().find(c=>c.id===id);if(!node||!art?.atlas)return;const probe=new Image();probe.onerror=()=>{if(bannerKey!==id||!c)return;node.style.backgroundImage=`url("${safe(c.hologram||c.art)}")`;node.style.backgroundSize='contain';node.style.backgroundPosition='right center';banner.dataset.bannerFormat='portrait';};probe.src=safe(art.atlas);}
 if(banner)new MutationObserver(bannerFallback).observe(banner,{attributes:true,attributeFilter:['data-custom-banner','data-hero']});bannerFallback();

 const footer=$('#mythic-public-home .hall-version')||el('footer','hall-version');footer.textContent=`Mythic Clash · Versão ${window.MythicRelease?.version||'2026.10.21'} · ${String(window.MythicRelease?.id||'').slice(0,8)}`;$('#mythic-public-home')?.append(footer);
 collection();publishOptions();
})();

// Detailed state changes are recorded for the post-match screen only. No private
// hand/deck contents enter this recorder, and it never adds messages during play.
(() => {
 const states=new Map(),records=new Map();
 const publicState=(d,power)=>({round:d.round,fields:Object.fromEntries(['player','enemy'].map(t=>[t,(d[t]?.field||[]).map(u=>({uid:u.uid,power:power(t,u),cardId:u.copiedFrom||u.cardId,source:u.cardId,lane:u.lane,equipment:[...(u.equipment||[])],bonus:u.bonus||0,powerShift:u.powerShift||0,silenced:Boolean(u.silencedJogadas||u.silencedOwnerEnd),savedOnce:Boolean(u.savedOnce),guardOwner:u.guardOwner||null}))])),graves:Object.fromEntries(['player','enemy'].map(t=>[t,(d[t]?.underworld||[]).slice()]))});
 function capture(d,power){if(!d||d.online)return;const id=d.localMatchId;if(!id)return;const next=publicState(d,power),prior=states.get(id);if(JSON.stringify(prior)===JSON.stringify(next))return;const list=records.get(id)||[];if(prior){const lookup=new Map((window.MythicCardData?.()||[]).map(c=>[c.id,c.name]));for(const side of ['player','enemy']){const old=new Map(prior.fields[side].map(u=>[u.uid,u])),fresh=new Map(next.fields[side].map(u=>[u.uid,u]));for(const u of next.fields[side]){const before=old.get(u.uid),name=lookup.get(u.cardId)||u.cardId,enemy=side==='player'?'enemy':'player',stolen=prior.fields[enemy].some(v=>v.uid===u.uid);let changes=[];if(!before)changes.push(stolen?'roubada para este lado':prior.graves[side].includes(u.source)?'recuperada do Submundo':'entrou em campo');else{if(before.lane!==u.lane)changes.push(`movida da fileira ${before.lane+1} para ${u.lane+1}`);if(before.cardId!==u.cardId)changes.push(`copiou ${name}`);if(before.power!==u.power)changes.push(`poder: ${before.power} → ${u.power}`);if(JSON.stringify(before.equipment)!==JSON.stringify(u.equipment))changes.push(`equipamentos: ${u.equipment.map(i=>lookup.get(i)||i).join(', ')||'nenhum'}`);if(before.silenced!==u.silenced)changes.push(u.silenced?'habilidade silenciada':'habilidade restaurada');if(!before.savedOnce&&u.savedOnce)changes.push('proteção contra destruição consumida');if(before.guardOwner!==u.guardOwner)changes.push(u.guardOwner?'proteção temporária recebida':'proteção temporária encerrada');}if(changes.length)list.push({round:d.round,side,text:`${name}: ${changes.join('; ')}.`});}for(const u of prior.fields[side])if(!fresh.has(u.uid)&&!next.fields[side==='player'?'enemy':'player'].some(v=>v.uid===u.uid)){list.push({round:d.round,side,text:`${lookup.get(u.cardId)||u.cardId}: ${next.graves[side].includes(u.source)?'enviada ao Submundo':'saiu do campo'}.`});}}}states.set(id,next);records.set(id,list.slice(-2000));}
 window.MythicEffectReport={capture,read:id=>records.get(id)||[],clear(){states.clear();records.clear();}};
 window.addEventListener('mythic-account-signed-out',()=>window.MythicEffectReport.clear());
})();
