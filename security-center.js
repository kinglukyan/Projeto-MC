(() => {
 'use strict';
 const $=s=>document.querySelector(s),el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const labels={invalid_payload:'Formato de ação inesperado',foreign_match:'Acesso a partida indisponível',request_reused:'Identificador reutilizado com outra ação',repeated_rejection:'Reenvio de ação rejeitada',action_rate:'Limite de ações excedido',action_rejected:'Jogada rejeitada pelo motor',economy_change:'Alteração de progresso ou moedas',admin_operation:'Operação administrativa',admin_code_failures:'Tentativas de código administrativo'};
 let panel=null,tab=null,request=0,cursor=null,history=[],rows=[],busy=false;
 const api=()=>window.MythicOnline,allowed=()=>Boolean(api()?.isAdmin?.());
 const rpc=(name,args={})=>api().portalRequest(name,args);
 const btn=(text,fn)=>{const n=el('button','button button-secondary',text);n.type='button';n.addEventListener('click',fn);return n;};
 function clear(){request++;cursor=null;history=[];rows=[];if(panel){panel.querySelector('.security-events').replaceChildren();panel.querySelector('.security-summary').replaceChildren();panel.querySelector('.security-health').replaceChildren();panel.querySelector('.security-status').textContent='';panel.querySelector('.security-pager').replaceChildren();panel.querySelector('.security-filters').reset();panel.hidden=true;}if(tab){tab.hidden=true;tab.setAttribute('aria-pressed','false');}}
 function status(text){panel.querySelector('.security-status').textContent=text;}
 async function load(){
  if(!allowed()||busy)return;const own=api().userId(),run=++request,actor=panel.querySelector('[name=actor]').value.trim(),category=panel.querySelector('[name=category]').value;
  if(actor&&!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(actor)){status('Informe o ID completo do jogador ou deixe em branco.');return;}
  busy=true;status('Carregando auditoria…');
  try{const result=await rpc('admin_security_events',{p_before:cursor,p_category:category,p_actor:actor||null});if(run!==request||own!==api().userId()||!allowed())return;rows=result.events||[];draw(rows,result.summary||{});status('Atualizado. Os registros são sinais para revisão, não prova automática de trapaça.');}
  catch(e){if(run===request)status(/admin_security/.test(e.message)?'A auditoria precisa da atualização 037 no servidor.':e.message);}
  finally{busy=false;}
 }
 function draw(events,summary){
  const stats=panel.querySelector('.security-summary');stats.replaceChildren();for(const [key,title]of [['events_24h','Registros · 24h'],['high_24h','Prioridade alta · 24h'],['pending_24h','Revisão pendente · 24h']]){const box=el('article');box.append(el('b','',String(summary[key]||0)),el('span','',title));stats.append(box);}
  const list=panel.querySelector('.security-events');list.replaceChildren();
  for(const entry of events){const row=el('article','security-event');row.dataset.severity=entry.severity;const head=el('header'),identity=el('div');identity.append(el('h3','',labels[entry.category]||entry.category),el('p','',entry.nickname||'Conta removida ou rotina de serviço'));
   head.append(identity,el('small','',new Date(entry.created_at).toLocaleString('pt-BR')));row.append(head);
   if(entry.actor_id)row.append(el('p','security-player-id','Jogador: '+entry.actor_id));if(entry.match_id)row.append(el('p','security-player-id','Partida: '+entry.match_id));
   const metadata=el('dl','security-metadata');const keys={type:'Tipo de jogada',sqlstate:'Código do motor',player_id:'Conta afetada',coins_delta:'Variação de moedas',xp_delta:'Variação de XP',rank_delta:'Variação de rank',wins_delta:'Vitórias',losses_delta:'Derrotas',operation:'Operação',target_id:'Destino',attempts:'Tentativas'};
   for(const [key,value]of Object.entries(entry.metadata||{})){if(!keys[key])continue;metadata.append(el('dt','',keys[key]),el('dd','',String(value)));}row.append(metadata);
   if(entry.reviewed_at){row.append(el('p','security-reviewed','Revisado em '+new Date(entry.reviewed_at).toLocaleString('pt-BR')));if(entry.review_note)row.append(el('p','',entry.review_note));}
   else{const review=el('div','security-review-form');review.hidden=true;const note=el('textarea');note.maxLength=500;note.placeholder='Observação da revisão (opcional)';note.setAttribute('aria-label','Observação da revisão');const save=btn('Marcar como revisado',async()=>{save.disabled=true;try{await rpc('admin_review_security_event',{p_event_id:entry.id,p_note:note.value});await load();}catch(e){status(e.message);save.disabled=false;}});review.append(note,save);row.append(btn('Revisar registro',()=>{review.hidden=!review.hidden;if(!review.hidden)note.focus();}),review);}
   list.append(row);
  }
  if(!events.length)list.append(el('p','','Nenhum registro para esses filtros.'));
  const pager=panel.querySelector('.security-pager');pager.replaceChildren();const prev=btn('← Mais recentes',()=>{cursor=history.pop()??null;load();}),next=btn('Mais antigos →',()=>{history.push(cursor);cursor=events[events.length-1]?.id||null;load();});prev.disabled=!history.length;next.disabled=events.length<50;pager.append(prev,next);
 }
 async function health(){if(!allowed())return;const own=api().userId();const target=panel.querySelector('.security-health');target.replaceChildren(el('p','','Consultando permissões do servidor…'));
  try{const result=await rpc('admin_security_health');if(own!==api().userId()||!allowed())return;target.replaceChildren();for(const [key,name]of [['tables_without_rls','Tabelas sem proteção por usuário'],['exposed_internal_helpers','Rotinas internas acessíveis'],['sensitive_write_grants','Permissões de escrita sensíveis']]){const section=el('article');section.append(el('h3','',name));const items=result[key]||[];if(!items.length)section.append(el('p','','Nenhum item encontrado nesta verificação.'));else{const list=el('ul');for(const item of items)list.append(el('li','',typeof item==='string'?item:JSON.stringify(item)));section.append(list);}target.append(section);}target.append(el('small','','Verificação de configuração. Não substitui uma auditoria completa nem valida o firewall ou o login.'));}
  catch(e){target.replaceChildren(el('p','',e.message));}
 }
 function ensure(){if(panel)return;const admin=$('.admin-operations'),tabs=admin?.querySelector('.admin-operation-tabs');if(!tabs)return;
  tab=btn('Segurança',()=>{for(const b of tabs.querySelectorAll('[data-admin-tab]'))b.setAttribute('aria-pressed',String(b===tab));for(const s of admin.querySelectorAll('[data-admin-section]'))s.hidden=s!==panel;load();});tab.dataset.adminTab='security';tab.setAttribute('aria-pressed','false');tab.hidden=!allowed();tabs.append(tab);
  panel=el('section','security-center');panel.dataset.adminSection='security';panel.hidden=true;
  panel.innerHTML='<header><h2>Segurança e jogo justo</h2><p>Revise ações rejeitadas e mudanças registradas pelo servidor. Erros de rede, versões antigas e escolhas fora de hora também podem gerar sinais. Nenhuma suspensão é aplicada automaticamente por esta tela.</p></header><form class="security-filters"><label>Ocorrência<select name="category"><option value="">Todas</option></select></label><label>ID do jogador<input name="actor" maxlength="36" placeholder="Opcional"></label><button class="button button-secondary" type="submit">Atualizar auditoria</button></form><p class="security-status" role="status"></p><div class="security-summary"></div><div class="security-events" data-admin-private></div><div class="security-pager"></div><section class="security-health-section"><h3>Configuração de permissões</h3><p>Consulte pontos que exigem revisão na configuração atual do banco.</p><div class="security-health-actions"></div><div class="security-health" data-admin-private></div></section>';
  for(const [key,name]of Object.entries(labels)){const option=el('option','',name);option.value=key;panel.querySelector('select').append(option);}panel.querySelector('form').addEventListener('submit',e=>{e.preventDefault();cursor=null;history=[];load();});panel.querySelector('.security-health-actions').append(btn('Verificar permissões',health));admin.append(panel);
 }
 document.addEventListener('DOMContentLoaded',ensure);window.addEventListener('mythic-admin-access',()=>{ensure();if(tab)tab.hidden=!allowed();if(!allowed())clear();});
 // O painel de administração também muda conforme o perfil/sessão.
 window.addEventListener('mythic-profile-loaded',()=>{ensure();if(tab)tab.hidden=!allowed();});window.addEventListener('mythic-account-signed-out',clear);window.addEventListener('mythic-session-changed',()=>{clear();queueMicrotask(()=>{if(tab)tab.hidden=!allowed();});});
})();
