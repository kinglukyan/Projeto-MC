(() => {
  const view=document.getElementById('view-profile');
  if(!view)return;
  const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text)n.textContent=text;return n;};
  const hero=view.querySelector('.player-profile-card'),progress=view.querySelector('.profile-progress'),analytics=view.querySelector('.profile-analytics'),summary=document.getElementById('profile-analytics-summary'),history=view.querySelector('.history-panel'),filters=history.querySelector('.history-filters'),replays=view.querySelector('.profile-replays'),form=document.getElementById('profile-edit-form');
  view.querySelector(':scope>.page-heading').hidden=true;
  const tabs=el('nav','legend-tabs');tabs.setAttribute('aria-label','Seções do perfil');
  const homeTab=el('button','selected','Perfil'),replayTab=el('button','','Replays');
  homeTab.type=replayTab.type='button';homeTab.setAttribute('aria-pressed','true');replayTab.setAttribute('aria-pressed','false');tabs.append(homeTab,replayTab);view.prepend(tabs);
  hero.classList.add('legend-hero');
  const identity=hero.querySelector('.profile-identity');
  identity.querySelector(':scope>small').textContent='SUA LENDA';
  const tagline=el('p','legend-tagline','Sua jornada entre deuses, heróis e lendas.');identity.insertBefore(tagline,identity.querySelector('.profile-email-label'));
  const privateInfo=el('div','legend-private-info');privateInfo.append(identity.querySelector('.profile-email-label'),document.getElementById('profile-email'));form.prepend(privateInfo);
  const stats=hero.querySelector('.profile-stats'),rank=stats.querySelector('.profile-rank-stat'),level=document.getElementById('profile-level').parentElement,coins=document.getElementById('profile-coins').parentElement;
  const rankWrap=el('div','legend-rank');rankWrap.append(rank);
  const progression=el('div','legend-progression'),levelLine=el('div','legend-level-line');levelLine.append(level,coins);progression.append(levelLine,progress);
  const actions=el('div','legend-actions'),edit=el('button','button button-secondary','Editar perfil'),share=el('button','button button-primary','Copiar código de amigo');edit.type=share.type='button';actions.append(edit,share);progression.append(actions);hero.append(rankWrap,progression);stats.remove();
  share.addEventListener('click',()=>document.getElementById('copy-profile-friend-code').click());
  const editDialog=el('dialog','legend-edit-dialog');editDialog.setAttribute('aria-label','Editar informações do perfil');const close=el('button','legend-dialog-close','×');close.type='button';close.setAttribute('aria-label','Fechar edição');editDialog.append(close,form);document.body.append(editDialog);edit.addEventListener('click',()=>editDialog.showModal());close.addEventListener('click',()=>editDialog.close());
  const dashboard=el('div','legend-dashboard');view.insertBefore(dashboard,analytics);
  const overview=el('section','legend-overview');overview.setAttribute('aria-label','Estatísticas gerais');overview.append(summary);
  const filterBar=el('div','legend-filterbar');filterBar.append(el('span','','Histórico e desempenho'),filters);overview.append(filterBar);dashboard.append(overview);
  const grid=el('div','legend-grid');dashboard.append(grid);
  const chart=el('section','panel legend-chart');const chartHeader=el('header');chartHeader.append(el('h3','','DESEMPENHO'),el('span','','Taxa de vitórias acumulada no período'));chart.append(chartHeader);const plot=el('div','legend-chart-plot');plot.id='legend-chart-plot';chart.append(plot);grid.append(chart);
  const cardPanel=document.getElementById('profile-top-cards').closest('section');cardPanel.classList.add('legend-card-panel');cardPanel.querySelector('header').replaceChildren(el('h3','','CARTAS MAIS USADAS'));grid.append(cardPanel);
  const deckPanel=document.getElementById('profile-top-decks').closest('section');deckPanel.classList.add('legend-deck-panel');deckPanel.querySelector('header').replaceChildren(el('h3','','DECKS MAIS USADOS'));grid.append(deckPanel);
  history.classList.add('legend-history');history.querySelector('h2').textContent='Últimas partidas';grid.append(history);
  const milestones=el('section','panel legend-milestones');milestones.append(el('h3','','CONQUISTAS NO PERÍODO'),el('p','legend-milestone-description','Seu progresso nas partidas do período selecionado.'));const milestoneList=el('div','legend-milestone-list');milestones.append(milestoneList);grid.append(milestones);
  const modes=document.getElementById('profile-mode-stats').closest('section');modes.classList.add('legend-modes');grid.append(modes);
  analytics.remove();
  const replayPage=el('div','legend-replay-page');replayPage.hidden=true;replayPage.append(replays);view.append(replayPage);
  function tab(replay){dashboard.hidden=replay;hero.hidden=replay;replayPage.hidden=!replay;homeTab.classList.toggle('selected',!replay);replayTab.classList.toggle('selected',replay);homeTab.setAttribute('aria-pressed',String(!replay));replayTab.setAttribute('aria-pressed',String(replay));}
  homeTab.addEventListener('click',()=>tab(false));replayTab.addEventListener('click',()=>tab(true));
  function renderHistory(rows=[]){
    const ordered=[...rows].sort((a,b)=>new Date(a.completed_at)-new Date(b.completed_at));
    plot.replaceChildren();
    if(!ordered.length){plot.append(el('p','legend-empty','Jogue partidas para acompanhar sua evolução.'));renderMilestones(0,0,0);return;}
    const ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg');svg.setAttribute('viewBox','0 0 620 220');svg.setAttribute('role','img');svg.setAttribute('aria-label','Taxa de vitórias acumulada nas partidas do período selecionado');
    function node(tag,attrs,text){const n=document.createElementNS(ns,tag);for(const [k,v]of Object.entries(attrs))n.setAttribute(k,String(v));if(text!==undefined)n.textContent=text;svg.append(n);return n;}
    for(let i=0;i<=4;i++){const y=20+i*40;node('line',{x1:48,x2:602,y1:y,y2:y,stroke:'#a7cce222','stroke-width':1});node('text',{x:38,y:y+4,fill:'#9fb4c4','font-size':11,'text-anchor':'end'},`${100-i*25}%`);}
    let victories=0,streak=0,best=0;const points=ordered.map((r,i)=>{if(r.outcome==='victory'){victories++;streak++;best=Math.max(best,streak);}else streak=0;return [ordered.length===1?325:48+i/(ordered.length-1)*554,180-(victories/(i+1))*160];});
    node('polygon',{points:`48,180 ${points.map(p=>p.join(',')).join(' ')} ${points.at(-1)[0]},180`,fill:'#49bfff13'});
    node('polyline',{points:points.map(p=>p.join(',')).join(' '),fill:'none',stroke:'#68ceff','stroke-width':2.5,'stroke-linejoin':'round'});
    for(const[x,y]of points)node('circle',{cx:x,cy:y,r:2.5,fill:'#c3efff'});
    const date=r=>new Date(r.completed_at).toLocaleDateString('pt-BR',{day:'2-digit',month:'short'});node('text',{x:48,y:209,fill:'#9fb4c4','font-size':11},date(ordered[0]));node('text',{x:602,y:209,fill:'#9fb4c4','font-size':11,'text-anchor':'end'},date(ordered.at(-1)));plot.append(svg);
    renderMilestones(victories,ordered.length,best);
  }
  function renderMilestones(victories,duels,best){
    milestoneList.replaceChildren();
    const definitions=[['first-victory','Primeira vitória',victories,1],['ten-victories','Dez vitórias',victories,10],['twenty-five-duels','Vinte e cinco duelos',duels,25],['five-streak','Cinco vitórias seguidas',best,5]];
    let earned=0;
    for(const [icon,title,value,target]of definitions){
      const complete=value>=target;if(complete)earned++;
      const item=el('article',complete?'earned':'');
      const medal=el('span','legend-medal'),art=el('img');
      art.src=window.MythicSecurity.assetUrl(`assets/profile-achievements/epic/${icon}.webp`);art.alt='';art.width=80;art.height=80;art.loading='lazy';medal.append(art);
      item.append(medal,el('b','',title));
      const bar=el('progress');bar.max=target;bar.value=Math.min(value,target);bar.setAttribute('aria-label',title);
      item.append(bar,el('small','',`${Math.min(value,target)} / ${target}`),el('span','legend-achievement-state',complete?'Concluída':'Em progresso'));
      milestoneList.append(item);
    }
    milestones.querySelector('h3').textContent=`CONQUISTAS NO PERÍODO · ${earned} / ${definitions.length}`;
  }
  window.addEventListener('mythic-profile-history',event=>renderHistory(event.detail?.rows||[]));renderHistory();
})();
