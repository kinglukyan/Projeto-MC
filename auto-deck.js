(() => {
 'use strict';
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;},rule=id=>window.MythicRemakeRules?.[id]||{},sum=o=>Object.values(o).reduce((a,b)=>a+b,0);
 const gear={mjolnir:c=>c.id==='thor','raio-de-zeus':c=>c.id==='zeus','olho-que-tudo-ve':c=>['horus','ra','osiris'].includes(c.id),excalibur:c=>['rei-arthur','lukyan'].includes(c.id),'runas-nordicas':c=>c.kind==='unit'&&c.faction==='Nórdicos'};
 const control=new Set(['destroy','reduce','wave','waveBoth','steal','silence','purge','equipmentDestroy','moveEnemy']),draw=new Set(['draft','drawCompany','drawBuff','drawMove','choice','unsilenceDraw','reorder']);
 let dialog=null,proposal=null,busy=false,token=0,source=null;
 function ensure(){if(dialog)return;dialog=el('dialog','auto-deck-dialog');dialog.setAttribute('aria-labelledby','auto-deck-title');dialog.innerHTML='<header><div><small>UMA BASE PARA SUA ESTRATÉGIA</small><h2 id="auto-deck-title">Sugerir um baralho</h2></div><button type="button" class="deck-dialog-close" aria-label="Fechar">×</button></header><p>Usa apenas cartas disponíveis da sua coleção. Você pode revisar, editar e salvar depois.</p><div class="auto-deck-settings"><label>Tamanho<select name="size"><option>14</option><option selected>20</option><option>25</option><option>30</option><option>35</option></select></label><label>Priorizar facção<select name="faction"></select></label><label>Estilo<select name="style"><option value="balanced">Equilibrado</option><option value="synergy">Sinergias</option><option value="control">Controle</option></select></label></div><p role="status"></p><div class="auto-deck-result"></div><footer><button type="button" class="button button-secondary" data-generate>Gerar sugestão</button><button type="button" class="button button-secondary" data-evaluate disabled>Avaliar sugestão</button><button type="button" class="button button-primary" data-use disabled>Usar no construtor</button></footer>';document.body.append(dialog);dialog.querySelector('.deck-dialog-close').onclick=()=>dialog.close();dialog.addEventListener('close',()=>{token++;busy=false;proposal=null;});dialog.querySelector('[data-generate]').onclick=generate;dialog.querySelector('[data-evaluate]').onclick=()=>{if(proposal)window.MythicDeckEvaluator.open(proposal,source.cards,'Baralho sugerido');};dialog.querySelector('[data-use]').onclick=()=>{if(proposal){try{window.MythicDeckBuilder.applySuggestion(proposal);dialog.close();window.MythicPresentation.notify('Sugestão colocada na mesa. Revise e salve quando quiser.');}catch(error){dialog.querySelector('[role=status]').textContent=error.message;}}};}
 function lock(){for(const n of dialog.querySelectorAll('select,[data-generate]'))n.disabled=busy;for(const n of dialog.querySelectorAll('[data-use],[data-evaluate]'))n.disabled=busy||!proposal;}
 async function generate(){if(busy)return;busy=true;proposal=null;lock();const run=++token,owner=source.userId,status=dialog.querySelector('[role=status]'),faction=dialog.querySelector('[name=faction]').value,style=dialog.querySelector('[name=style]').value;
  const pool=source.cards.filter(c=>c.owned>0&&!c.specialOnly&&!c.previewOnly&&!window.MythicAvailability?.isDisabled(c.id)),available=pool.reduce((a,c)=>a+Math.floor(c.owned),0),size=Math.min(Number(dialog.querySelector('[name=size]').value),available),counts={};
  if(size<14){status.textContent='Você precisa de pelo menos 14 cartas disponíveis na coleção.';busy=false;lock();return;}
  const totalUnits=()=>pool.filter(c=>c.kind==='unit').reduce((a,c)=>a+(counts[c.id]||0),0),base=c=>Number(c.power||0)+(faction!=='all'&&c.faction===faction?3:0)+(draw.has(rule(c.id).op)?2:0)+(control.has(rule(c.id).op)?(style==='control'?4:1.5):0);
  const candidates=pool.slice().sort((a,b)=>base(b)-base(a));
  status.textContent='Combinando unidades e apoios da sua coleção…';await new Promise(r=>setTimeout(r,20));
  for(let step=0;step<size;step++){
   if(run!==token||owner!==window.MythicOnline?.userId?.())return;
   const units=totalUnits(),neededUnits=Math.min(Math.ceil(size*.7),pool.filter(c=>c.kind==='unit').reduce((n,c)=>n+c.owned,0)),unitSlotsLeft=neededUnits-units;
   let best=null,bestValue=-Infinity;
   for(const c of candidates){if((counts[c.id]||0)>=Math.floor(c.owned))continue;if(c.kind!=='unit'&&size-step<=unitSlotsLeft)continue;
    if(gear[c.id]){const holders=pool.filter(x=>gear[c.id](x)).reduce((n,x)=>n+(counts[x.id]||0),0);if(holders<=(counts[c.id]||0))continue;}
    const trial={...counts,[c.id]:(counts[c.id]||0)+1},evaluation=window.MythicDeckEvaluator.analyze(trial,source.cards);let value=evaluation.score*(style==='synergy'?1.25:1)+base(c)*1.5;
    if(c.kind==='unit'&&units<neededUnits)value+=6;if(c.kind!=='unit'&&step-units>=Math.floor(size*.3))value-=16;
    if(['soldado-esparta','guardiao-nordico','lobo-beta','homem','mulher'].includes(c.id)&&(counts[c.id]||0)>0)value+=4;
    if(c.id==='lobo-alfa'&&(counts['lobo-beta']||0)>0)value+=4;
    if(c.id==='artemis'&&pool.some(x=>x.faction==='Monstros'&&counts[x.id]>0))value-=8;
    if(value>bestValue){bestValue=value;best=c;}
   }
   // A limited starter collection may require a normally conditional card.
   if(!best)best=candidates.find(c=>(counts[c.id]||0)<Math.floor(c.owned));if(!best)break;counts[best.id]=(counts[best.id]||0)+1;
   if(step%3===0){status.textContent=`Organizando ${step+1} de ${size} cartas…`;await new Promise(r=>setTimeout(r,0));}
  }
  if(run!==token)return;proposal=counts;busy=false;lock();const result=dialog.querySelector('.auto-deck-result');result.replaceChildren();const score=window.MythicDeckEvaluator.analyze(counts,source.cards);result.append(el('h3','',`${sum(counts)} cartas · composição ${score.score}/100`));for(const [id,n]of Object.entries(counts)){const c=pool.find(c=>c.id===id),row=el('div','auto-deck-card');row.append(el('b','',`${n} × ${c.name}`),el('span','',`${c.faction} · ${c.kind==='unit'?c.power+' poder':c.type||c.kind}`));result.append(row);}status.textContent=(size<Number(dialog.querySelector('[name=size]').value)?'Ajustei o tamanho às cartas que você possui. ':'')+'A sugestão é uma base, não uma garantia de vitória. Avalie as dependências e ajuste antes de salvar.';
 }
 function open(){if(!window.MythicDeckBuilder?.isOpen?.()){window.MythicOpenSelectedDeckBuilder?.();}if(!window.MythicDeckBuilder?.isOpen?.())return;source=window.MythicDeckEditor.read();ensure();const select=dialog.querySelector('[name=faction]');select.replaceChildren(new Option('Automática / misturar','all'),...[...new Set(source.cards.filter(c=>c.owned>0&&c.kind==='unit').map(c=>c.faction))].map(f=>new Option(f,f)));proposal=null;dialog.querySelector('.auto-deck-result').replaceChildren();dialog.querySelector('[role=status]').textContent='Escolha suas preferências e gere uma sugestão.';busy=false;lock();dialog.showModal();}
 window.MythicAutoDeck={open};
 const tools=document.querySelector('#view-decks .page-heading');if(tools){const b=el('button','button button-secondary','Sugerir deck');b.type='button';b.onclick=open;tools.append(b);}
 window.addEventListener('mythic-account-signed-out',()=>dialog?.close());window.addEventListener('mythic-profile-loaded',()=>{if(dialog?.open&&source?.userId!==window.MythicOnline?.userId?.())dialog.close();});
})();
