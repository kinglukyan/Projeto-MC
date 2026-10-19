(() => {
 'use strict';
 const root=document.querySelector('#view-match-report');if(!root)return;
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const button=(text,fn)=>{const n=el('button','button button-primary',text);n.type='button';n.addEventListener('click',fn);return n;};
 let report=null,returnAction=null,generation=0,loading=false,leaving=false;
 const modeName={ranked:'Ranqueada',normal:'Normal',custom:'Personalizada',friend:'Desafio',guardian:'Guardião da Arena',tutorial:'Tutorial',practice:'Teste de baralho'};
 const number=n=>Number(n||0).toLocaleString('pt-BR',{maximumFractionDigits:2});
 function duration(value){if(value===null||value===undefined||!Number.isFinite(Number(value)))return '—';const s=Math.max(0,Math.floor(value)),h=Math.floor(s/3600),m=Math.floor(s/60)%60;return(h?`${h}h `:'')+`${m}min ${String(s%60).padStart(2,'0')}s`;}
 function mine(){return report.my_team||'player_one';}
 function teamOf(id){return report.participants.find(p=>p.id===id)?.team;}
 function teamName(team){return report.participants.filter(p=>p.team===team).map(p=>p.name).join(' + ')||'Equipe';}
 function metric(label,value,note){const n=el('article','report-metric');n.append(el('span','',label),el('strong','',value));if(note)n.append(el('small','',note));return n;}
 function draw(){
  if(!report)return;root.replaceChildren();const own=mine(),other=own==='player_one'?'player_two':'player_one';
  const header=el('header','report-header'),copy=el('div'),outcome={victory:'Vitória',defeat:'Derrota',draw:'Empate',abandoned:'Partida encerrada',practice:'Teste encerrado'}[report.outcome]||'Partida encerrada';
  copy.append(el('p','eyebrow','RELATÓRIO DA PARTIDA'),el('h1','',outcome),el('p','report-mode',`${modeName[report.mode]||'Duelo'} · ${report.mode==='practice'?'Laboratório de combos':report.team_size===2?'2 × 2':'1 × 1'}`));
  const back=button(leaving?'Voltando…':report.mode==='practice'?'Voltar aos baralhos':'Voltar à sala',async()=>{if(leaving)return;leaving=true;draw();try{await returnAction(report);generation++;report=null;root.replaceChildren();}catch(e){leaving=false;draw();root.prepend(el('p','report-status',e.message));}});back.disabled=leaving||loading;
  header.append(copy,back);root.append(header);
  const board=el('section','panel report-scoreboard');board.setAttribute('aria-label','Resultado por Rounds');
  for(const team of [own,other]){const side=el('div','report-team'),avatars=el('div','report-avatars');for(const p of report.participants.filter(p=>p.team===team)){const icon=el('span','lobby-avatar'),src=window.MythicOnline?.avatarAsset?.(p.icon);if(src){const img=el('img');img.src=src;img.alt='';icon.append(img);}else icon.textContent=p.name.slice(0,2);avatars.append(icon);}side.append(avatars,el('h2','',teamName(team)),el('strong','report-round-wins',number(report.round_wins?.[team])),el('small','','Rounds vencidos'));board.append(side);}
  const scoreNote=el('p','report-score-note','Cada Round é independente. O resultado considera as vitórias em Rounds e, quando necessário, o desempate.');board.append(scoreNote);root.append(board);
  const ownCards=report.cards===null?null:report.cards.filter(c=>teamOf(c.actor_id)===own).reduce((s,c)=>s+Number(c.count),0),enemyCards=report.cards===null?null:report.cards.filter(c=>teamOf(c.actor_id)===other).reduce((s,c)=>s+Number(c.count),0),allActions=report.actions===null?null:report.actions.reduce((s,a)=>s+Number(a.actions),0);
  const metrics=el('section','report-metrics');metrics.append(metric('Duração',duration(report.duration_seconds)),metric('Cartas jogadas · seu lado',ownCards===null?'—':number(ownCards)),metric('Cartas jogadas · adversário',enemyCards===null?'—':number(enemyCards)),metric('Ações confirmadas',allActions===null?'—':number(allActions),'Jogadas, passes e decisões de habilidade'));
  if(report.rewards){metrics.append(metric('XP recebido',number(report.rewards.xp)),metric('Mythic Coins recebidas',number(report.rewards.coins)));}root.append(metrics);
  const state=el('p','report-status',loading?'Buscando os dados oficiais da partida…':report.complete_tracking?'':'Alguns dados não estão disponíveis nesta partida. O registro completo vale para partidas iniciadas com a atualização do relatório.');state.setAttribute('role','status');root.append(state);
  const columns=el('div','report-columns'),roundPanel=el('section','panel report-rounds');roundPanel.append(el('h2','','Pontos por Round'));
  if(report.rounds.length){const table=el('table'),caption=el('caption','sr-only','Pontuação individual de cada Round'),head=el('thead'),row=el('tr');for(const name of ['Round','Seu lado','Adversário','Resultado']){const th=el('th','',name);th.scope='col';row.append(th);}head.append(row);const body=el('tbody');for(const r of report.rounds){const a=Number(r[own]||0),b=Number(r[other]||0),line=el('tr');for(const val of [String(r.round),number(a),number(b),r.in_progress?'Em campo':a===b?'Empate':a>b?'Vitória':'Derrota'])line.append(el('td','',val));body.append(line);}table.append(caption,head,body);roundPanel.append(table);}else roundPanel.append(el('p','','Nenhum Round concluído foi registrado.'));
  const details=el('section','panel report-details');details.append(el('h2','','Dados do duelo'));const dl=el('dl');for(const [label,value]of [['Formato',report.team_size===2?'2 × 2':'1 × 1'],['Início',report.started_at?new Date(report.started_at).toLocaleString('pt-BR'):'Não disponível'],['Fim',report.finished_at?new Date(report.finished_at).toLocaleString('pt-BR'):'Não disponível'],['Identificador',report.id]]){dl.append(el('dt','',label),el('dd','',value||'—'));}details.append(dl);if(report.tiebreak){details.append(el('h3','','Desempate'),el('p','',report.tiebreak.eclipse?`Decidido pelo ${report.tiebreak.eclipse==='eclipse-lunar'?'Eclipse Lunar':'Eclipse Solar'}.`:`Decidido na puxada de unidades${report.tiebreak.draws?.length?` após ${report.tiebreak.draws.length} tentativa(s)`:''}.`));}columns.append(roundPanel,details);root.append(columns);
  const cardsPanel=el('section','panel report-cards');cardsPanel.append(el('h2','','Cartas jogadas'));
  if(report.cards===null)cardsPanel.append(el('p','','O detalhamento das jogadas não está disponível.'));
  else if(!report.cards.length)cardsPanel.append(el('p','','Nenhuma carta foi jogada no período registrado.'));
  else{const catalog=new Map((window.MythicCardData?.()||[]).map(c=>[c.id,c]));for(const p of report.participants){const played=report.cards.filter(c=>c.actor_id===p.id);if(!played.length)continue;const group=el('section','report-card-group');group.append(el('h3','',p.name+(p.team===own?' · seu lado':' · adversário')));const list=el('ul','report-card-list');for(const entry of played){const card=catalog.get(entry.card_id),item=el('li');if(card?.art){const img=el('img');img.src=window.MythicSecurity.assetUrl(card.art);img.alt='';img.loading='lazy';item.append(img);}const text=el('span');text.append(el('b','',card?.name||entry.card_id),el('small','',card?.type||'Carta'));item.append(text,el('strong','',`× ${number(entry.count)}`));list.append(item);}group.append(list);cardsPanel.append(group);}}root.append(cardsPanel);
  const note=el('p','report-footnote','Cartas invocadas por habilidades não são contadas como novas jogadas da mão. O relatório não revela cartas que permaneceram ocultas.');root.append(note);
 }
 function local(duel){
  const stats=duel.matchStats||{},plays=stats.plays||[],online=Boolean(duel.online),own=duel.myTeam||'player_one',other=own==='player_one'?'player_two':'player_one',end=duel.finishedAt||Date.now();
  const participants=online?(duel.participants||[]).map(p=>({...p,team:p.team==='player'||p.team===1?'player_one':p.team==='enemy'||p.team===2?'player_two':p.team})):[];
  if(!participants.length)participants.push({id:'player',name:duel.playerTeamName||duel.playerName||window.MythicOnline?.playerName?.()||'Você',team:own,icon:duel.playerIcon||window.MythicOnline?.playerIcon?.()},{id:'enemy',name:duel.opponentName||'Guardião da Arena',team:other,icon:duel.opponentIcon||'guardian'});
  const counts=new Map();for(const p of plays){const key=p.actor_id+':'+p.card_id;const prior=counts.get(key);if(prior)prior.count++;else counts.set(key,{actor_id:p.actor_id,card_id:p.card_id,count:1});}
  const outcome=duel.practice?'practice':duel.serverOutcome||(duel.roundWins.player>duel.roundWins.enemy?'victory':duel.roundWins.player<duel.roundWins.enemy?'defeat':'draw');
  return{id:duel.onlineMatchId||duel.localMatchId,mode:duel.practice?'practice':duel.customRoomId?'custom':online?duel.onlineMode:duel.isTutorial?'tutorial':'guardian',team_size:duel.teamSize||1,my_team:own,participants,outcome,
   started_at:duel.startedAt?new Date(duel.startedAt).toISOString():null,finished_at:new Date(end).toISOString(),duration_seconds:duel.startedAt?(end-duel.startedAt)/1000:null,
   round_wins:{[own]:duel.roundWins.player,[other]:duel.roundWins.enemy},rounds:(duel.roundScores||[]).map(r=>({round:r.round,[own]:r.player??r[own]??0,[other]:r.enemy??r[other]??0,in_progress:r.in_progress})),
   cards:online?null:[...counts.values()],actions:online?null:[{actor_id:'player',actions:stats.actions||0,passes:stats.passes||0}],complete_tracking:!online&&Boolean(duel.startedAt),tiebreak:duel.matchTiebreak||null,room_id:duel.customRoomId||null};
 }
 window.MythicMatchReport={open:async(duel,back)=>{
  const token=++generation,uid=window.MythicOnline?.userId?.();report=local(duel);returnAction=back;leaving=false;loading=Boolean(duel.online);draw();
  if(!duel.online)return;
  let timer;
  try{const official=await Promise.race([window.MythicOnline.portalRequest('get_match_report',{p_match_id:duel.onlineMatchId}),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Tempo de espera excedido.')),10000);})]);if(token!==generation||uid!==window.MythicOnline?.userId?.())return;report=official;}
  catch{if(token!==generation)return;report.complete_tracking=false;}
  finally{clearTimeout(timer);if(token===generation){loading=false;draw();}}
 }};
 window.addEventListener('mythic-account-signed-out',()=>{generation++;report=null;root.replaceChildren();});
})();
