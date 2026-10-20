(() => {
 'use strict';
 const clamp=(v,a=0,b=1)=>Math.min(b,Math.max(a,v)),total=c=>Object.values(c).reduce((n,v)=>n+v,0);
 const gear={mjolnir:['thor'],'runas-nordicas':c=>c.kind==='unit'&&c.faction==='Nórdicos','raio-de-zeus':['zeus'],'olho-que-tudo-ve':['horus','ra','osiris'],excalibur:['rei-arthur','lukyan']};
 const factions={grecia:'Grécia',asgard:'Nórdicos',egito:'Egípcios'};
 const terrainTargets={
  'campo-troia':c=>['aquiles','athena','ares'].includes(c.id),yggdrasil:c=>c.id==='odin',
  'alto-egito':c=>c.kind==='unit'&&c.faction==='Egípcios','baixo-egito':c=>c.kind==='unit'&&c.faction==='Egípcios',
  bifrost:c=>c.kind==='unit'&&c.faction==='Nórdicos'&&c.id!=='loki',
  esparta:c=>c.id==='ares'||(c.tags||[]).includes('espartano'),
  'labirinto-dedalos':c=>c.id==='minotauro'||c.faction==='Grécia'&&(c.characterClass==='Monstro'||(c.tags||[]).includes('monstro')),
  nilfheim:c=>c.id==='loki'||(c.tags||[]).includes('gigante')
 };
 const controlOps=new Set(['destroy','reduce','wave','waveBoth','shiva','steal','silence','moveEnemy','equipmentDestroy','equipmentReturn','purge','lockGrave','blockRevive','swap','sacrificeHunt']);
 const drawOps=new Set(['draft','drawCompany','drawBuff','unsilenceDraw','drawMove','choice','graveDraw','reorder']);
 const recoverOps=new Set(['recover','reviveQuiet','rebirth','guard','protectDestroy','protectReduction','saveOnce','protectMove','cleanse','cleanseAll']);
 const allyOps=new Set(['aura','occupiedAura','company','drawCompany','drawBuff','protectDestroy','protectReduction','cleanseAll','rally','equipmentAura','bounce']);
 const controlIds=new Set(['medusa','poseidon','zeus','anubis','artemis','thor','ares','seth','loki','butter','dionisio']);
 const recoveryIds=new Set(['hades','isis','osiris','thor','beowulf','heimdall']);
 const drawIds=new Set(['hermes','horus','butter']);
 function choose(n,k){if(k<0||k>n)return 0;let value=1;for(let i=1;i<=Math.min(k,n-k);i++)value=value*(n-i+1)/i;return value;}
 function none(n,k,hand){return n>0?choose(n-k,Math.min(n,hand))/choose(n,Math.min(n,hand)):1;}
 function supportChance(n,a,b,min=1,overlap=false){if(!n)return 0;const h=Math.min(5,n),den=choose(n,h);let p=0;for(let i=1;i<=Math.min(a,h);i++)for(let j=0;j<=Math.min(b,h-i);j++)if(j+(overlap?i-1:0)>=min)p+=choose(a,i)*choose(b,j)*choose(n-a-b,h-i-j)/den;return clamp(p);}
 function two(n,k,hand=5){if(!n)return 0;hand=Math.min(n,hand);return clamp(1-none(n,k,hand)-k*choose(n-k,hand-1)/choose(n,hand));}
 function analyze(raw,catalog){
  const map=new Map(catalog.map(c=>[c.id,c])),rules=window.MythicRemakeRules||window.MythicAbilitiesData?.remakeRules||{},counts={},invalid=[],warnings=[],combos=[],needs=[],dependent=[];
  for(const [id,v] of Object.entries(raw||{})){const n=Number(v);if(!Number.isInteger(n)||n<0||n>35){invalid.push('Quantidade inválida em '+(map.get(id)?.name||id));continue;}if(!n)continue;counts[id]=n;const c=map.get(id);if(!c){invalid.push('Carta não reconhecida: '+id);continue;}if(c.specialOnly||c.previewOnly)invalid.push(c.name+' não pode entrar no baralho.');if(typeof c.owned==='number'&&n>c.owned)invalid.push(c.name+': você não possui todas essas cópias.');if(window.MythicAvailability?.isDisabled(id))invalid.push(c.name+' está temporariamente pausada.');}
  const n=total(counts),entries=Object.keys(counts).map(id=>map.get(id)).filter(Boolean),units=entries.filter(c=>c.kind==='unit'),unitCount=units.reduce((s,c)=>s+counts[c.id],0),specials=n-unitCount;
  if(n<14||n>35)invalid.unshift('Use de 14 a 35 cartas.');
  const fac={};for(const c of units)fac[c.faction]=(fac[c.faction]||0)+counts[c.id];
  const countWhere=(filter,exclude)=>entries.reduce((s,c)=>s+(filter(c)?Math.max(0,counts[c.id]-(c.id===exclude?1:0)):0),0);
  const eligible=(c,r,source)=>c.kind===(r.kind||'unit')&&(!r.faction||c.faction===r.faction)&&(!r.max||Number(c.power)<=r.max)&&c.id!==source;
  let synergy=0,dependency=0,unsupported=0;
  function require(source,predicate,label,min=1,row=true){const targets=entries.filter(c=>predicate(c)&&(counts[c.id]-(c.id===source.id?1:0))>0),copies=countWhere(predicate,source.id),sourceCopies=counts[source.id],ratio=clamp(copies/Math.max(min,3));dependent.push(source.id);dependency+=sourceCopies;synergy+=sourceCopies*ratio;if(copies<min){unsupported+=sourceCopies;warnings.push({title:source.name+' sem apoio suficiente',text:`${label} Seu deck tem ${copies} cópia(s) compatível(is); precisa de pelo menos ${min}.`});needs.push({source:source.id,predicate,label});}else{const overlap=predicate(source),others=countWhere(x=>x.id!==source.id&&predicate(x)),probability=supportChance(n,sourceCopies,others,min,overlap);combos.push({source:source.name,target:targets.slice(0,3).map(c=>c.name).join(', '),text:label+(row?' Organize essas cartas na mesma fileira.':''),probability:copies>0?probability:0});}return copies;}
  for(const c of entries){const r=rules[c.id]||{};
   if(gear[c.id]){const g=gear[c.id];require(c,x=>Array.isArray(g)?g.includes(x.id):g(x),'Precisa de um portador permitido pela habilidade.',1,false);continue;}
   if(['soldado-esparta','guardiao-nordico','homem','mulher','lobo-beta'].includes(c.id)){require(c,x=>x.id===c.id,c.id==='lobo-beta'?'Reúne outros Betas da mão ao invocar.':'Cópias da mesma unidade ativam o bônus.',1,c.id!=='lobo-beta');continue;}
   if(c.id==='lobo-alfa'){require(c,x=>x.id==='lobo-beta','Cada Beta aliado na fileira fortalece o Alfa.');continue;}
   if(['athena','apolo','lukyan','aquiles','afrodite'].includes(c.id)){require(c,x=>x.kind==='unit','O bônus depende de aliados na fileira.');continue;}
   if(c.id==='lobo-omega'){require(c,x=>x.kind==='unit'&&x.faction==='Monstros','Precisa de outro Monstro para ativar seu bônus.');continue;}
   if(terrainTargets[c.id]){require(c,terrainTargets[c.id],'Fortalece os alvos específicos descritos neste Terreno.',1,false);continue;}
   if(factions[c.id]){require(c,x=>x.kind==='unit'&&x.faction===factions[c.id],'Apoia unidades da facção correspondente.',1,false);continue;}
   if(c.id==='hades'||c.id==='isis'){require(c,x=>x.kind==='unit'&&(c.id!=='isis'||Number(x.cost||0)<=2),'O alvo precisa estar no seu Submundo; é uma opção para etapas posteriores.',1,false);continue;}
   if(r.op==='recover'||r.op==='reviveQuiet'){require(c,x=>(r.kinds?r.kinds.includes(x.kind):x.kind===(r.kind||'unit'))&&(!r.faction||x.faction===r.faction)&&(!r.max||Number(x.power)<=r.max),'Precisa de um alvo compatível no seu Submundo.',1,false);continue;}
   if(allyOps.has(r.op)){require(c,x=>x.kind==='unit'&&(!r.faction||x.faction===r.faction),r.faction?'Combina com aliados da facção '+r.faction+'.':'Combina com outras unidades aliadas.',r.op==='company'?r.count||1:1);if(r.op==='equipmentAura')require(c,x=>x.kind==='equipment','Seu bônus também precisa de equipamentos.',1,false);continue;}
   if(r.op==='grow'&&r.climate){require(c,x=>['event','climate'].includes(x.kind),'Precisa de um Clima ativo para crescer.',1,false);}
   if(['graveGrowth','graveDraw','sacrificeBuff','sacrificeFeed','sacrificeHunt','mourning'].includes(r.op)){require(c,x=>x.kind==='unit','Usa aliados ou unidades que chegam ao Submundo.',1,false);}
  }
  const controls=entries.filter(c=>controlIds.has(c.id)||controlOps.has(rules[c.id]?.op)),draws=entries.filter(c=>drawIds.has(c.id)||drawOps.has(rules[c.id]?.op)),recovery=entries.filter(c=>recoveryIds.has(c.id)||recoverOps.has(rules[c.id]?.op)),qty=list=>list.reduce((s,c)=>s+counts[c.id],0);
  const ratio=unitCount/Math.max(1,n),pUnits=two(n,unitCount),supported=dependency?clamp(1-unsupported/dependency):1;
  const metrics=[{name:'Consistência',max:25,value:Math.round(25*(.65*pUnits+.35*clamp(ratio/.65))),text:`${Math.round(pUnits*100)}% de chance de ter pelo menos 2 unidades nas primeiras ${Math.min(5,n)} cartas.`},
   {name:'Sinergia',max:30,value:Math.round(30*(dependency ? .5*supported+.5*synergy/dependency:0.55)),text:dependency?`${dependency-unsupported} de ${dependency} cópias dependentes possuem apoio mínimo no deck.`:'Sem dependências explícitas; a composição aposta em efeitos autônomos.'},
   {name:'Autonomia',max:20,value:Math.round(20*clamp((unitCount-unsupported)/Math.max(1,n)/.65)),text:`${unitCount} unidades; ${unsupported} cópia(s) com dependência sem apoio.`},
   {name:'Respostas',max:15,value:Math.round(15*clamp(qty(controls)/Math.max(2,n*.15))),text:`${qty(controls)} carta(s) capazes de interferir no plano inimigo.`},
   {name:'Fôlego',max:10,value:Math.round(10*clamp((qty(draws)+qty(recovery)*.6)/Math.max(2,n*.14))),text:`${qty(draws)} carta(s) de acesso/informação e ${qty(recovery)} de recuperação/proteção.`}];
  let score=metrics.reduce((s,m)=>s+m.value,0);if(!n||!unitCount)score=0;
  if(ratio<.55)warnings.push({title:'Poucas unidades para pontuar',text:`${Math.round(ratio*100)}% do baralho é composto por unidades. Muitas especiais podem deixar sua mão sem quem colocar em campo.`});
  if(!controls.length)warnings.push({title:'Poucas ferramentas de resposta',text:'O deck não possui efeitos de controle reconhecidos. Considere uma resposta a buffs, equipamentos ou ameaças inimigas.'});
  if(!draws.length)warnings.push({title:'Acesso às peças depende da compra normal',text:'Não há compra, busca, informação de mão ou ordenação reconhecida. Combinações específicas podem demorar a aparecer.'});
  if(entries.some(c=>c.id==='eclipse')&&entries.some(c=>['lobo-alfa','lobo-beta','lobo-omega','homem','mulher'].includes(c.id)))warnings.push({title:'Eclipse tem dois resultados',text:'A sinergia lunar depende de um sorteio de 50%. O Solar também precisa caber no seu plano; o Clima afeta ambos os lados.'});
  if(entries.some(c=>c.id==='artemis')&&units.some(c=>c.faction==='Monstros'))warnings.push({title:'Artemis também atinge seus Monstros',text:'A destruição afeta os dois lados. Planeje a ordem das jogadas e as proteções.'});
  if(entries.some(c=>['grecia','asgard','egito'].includes(c.id)))warnings.push({title:'Local compartilhado',text:'O bônus de facção também beneficia unidades inimigas compatíveis.'});
  if(entries.some(c=>c.id==='mesopotamica-nergal'))warnings.push({title:'Nergal reduz os dois lados',text:'O efeito também atinge seus aliados na fileira. Considere proteções e a ordem da invocação.'});
  const suggestions=[];for(const need of needs){const options=catalog.filter(c=>c.owned>0&&!c.previewOnly&&!c.specialOnly&&(counts[c.id]||0)<c.owned&&!window.MythicAvailability?.isDisabled(c.id)&&need.predicate(c)).slice(0,3);for(const c of options)if(!suggestions.some(s=>s.id===c.id))suggestions.push({id:c.id,name:c.name,text:'Pode apoiar '+map.get(need.source).name+'.'});}
  if(!controls.length)for(const c of catalog.filter(c=>c.owned>0&&!counts[c.id]&&!c.previewOnly&&!c.specialOnly&&!window.MythicAvailability?.isDisabled(c.id)&&(controlIds.has(c.id)||controlOps.has(rules[c.id]?.op))).slice(0,2))if(!suggestions.some(s=>s.id===c.id))suggestions.push({id:c.id,name:c.name,text:'Acrescenta uma opção de resposta.'});
  return {version:1,score,valid:!invalid.length,invalid,metrics,warnings,combos:combos.sort((a,b)=>b.probability-a.probability).slice(0,10),suggestions:suggestions.slice(0,6),n,unitCount,specials,fac,avgPower:unitCount?units.reduce((s,c)=>s+Number(c.power||0)*counts[c.id],0)/unitCount:0};
 }
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 let dialog,previous,viewer;
 function open(counts,catalog,name='Seu baralho'){
  const result=analyze(counts,catalog);viewer=window.MythicOnline?.userId?.();if(!dialog){dialog=el('dialog','deck-evaluator');document.body.append(dialog);dialog.setAttribute('aria-labelledby','deck-eval-title');dialog.addEventListener('close',()=>previous?.isConnected&&previous.focus());}previous=document.activeElement;dialog.replaceChildren();
  const head=el('header'),title=el('div');title.append(el('small','','AVALIADOR DE DECK'),el('h2','',name));title.querySelector('h2').id='deck-eval-title';const close=el('button','deck-dialog-close','×');close.type='button';close.setAttribute('aria-label','Fechar avaliação');close.onclick=()=>dialog.close();head.append(title,close);dialog.append(head);
  const hero=el('section','deck-eval-hero'),score=el('strong','deck-eval-score',result.valid?String(result.score):'!'),summary=el('div');summary.append(el('h3','',result.valid?(result.score>=80?'Plano bem apoiado':result.score>=60?'Boa base para ajustar':'Há espaço para melhorar'):'Revise a montagem'),el('p','',`${result.n} cartas · ${result.unitCount} unidades · ${result.specials} especiais · poder base médio ${result.avgPower.toFixed(1)}`),el('small','',result.valid?'Índice de composição: '+result.score+'/100':'O índice só é liberado para um baralho válido.'));hero.append(score,summary);dialog.append(hero);
  const metricGrid=el('section','deck-eval-metrics');for(const m of result.metrics){const item=el('article');item.append(el('h3','',m.name+' · '+m.value+'/'+m.max));const meter=el('meter');meter.min=0;meter.max=m.max;meter.value=m.value;meter.setAttribute('aria-label',m.name);item.append(meter,el('p','',m.text));metricGrid.append(item);}dialog.append(metricGrid);
  function section(heading,items,render,empty){const s=el('section','deck-eval-section');s.append(el('h3','',heading));if(!items.length)s.append(el('p','',empty));else for(const i of items){const a=el('article');render(a,i);s.append(a);}dialog.append(s);}
  section('Revisar antes de jogar',result.invalid,(a,i)=>a.append(el('p','',i)),'Montagem válida para os limites e a coleção disponíveis.');
  section('Combinações encontradas',result.combos,(a,c)=>{a.append(el('b','',c.source+' + '+c.target),el('p','',c.text),el('small','',`${Math.round(c.probability*100)}% de reunir as duas peças nas primeiras ${Math.min(5,result.n)} cartas. Isso não garante a ativação do efeito.`));},'Nenhuma combinação explícita reconhecida nesta montagem.');
  section('Pontos de atenção',result.warnings,(a,w)=>a.append(el('b','',w.title),el('p','',w.text)),'Nenhum conflito conhecido encontrado.');
  section('Opções da sua coleção',result.suggestions,(a,s)=>{a.append(el('b','',s.name),el('p','',s.text));const b=el('button','button button-secondary','Ver carta');b.type='button';b.onclick=()=>{if(window.MythicDeckBuilder?.isOpen?.())return;dialog.close();window.MythicPresentation?.inspectCard(s.id);};if(!window.MythicDeckBuilder?.isOpen?.())a.append(b);},'Sem sugestão específica de carta disponível para as dependências detectadas.');
  const details=el('details'),caption=el('summary','','Como a análise é feita');details.append(caption,el('p','','A nota combina consistência (25), sinergia (30), autonomia (20), respostas (15) e fôlego (10). As probabilidades consideram compra sem reposição, cinco cartas iniciais e nenhuma busca ou troca. Auras e combos de fileira exigem posicionamento; ressurreições exigem um Submundo preparado. Não usamos curva de mana: o jogo permite uma carta por turno. Esta análise não simula o adversário nem prevê taxa de vitória. Cartas com efeitos ainda não mapeados podem precisar de revisão manual.'));dialog.append(details);dialog.showModal();
 }
 window.MythicDeckEvaluator={analyze,open};
 window.addEventListener('mythic-account-signed-out',()=>dialog?.close());
 window.addEventListener('mythic-profile-loaded',()=>{if(viewer!==window.MythicOnline?.userId?.())dialog?.close();});
})();
