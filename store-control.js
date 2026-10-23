(() => {
 'use strict';
 const api=()=>window.MythicOnline,uid=()=>api()?.userId?.(),rpc=(n,p={})=>api().portalRequest(n,p);
 const el=(tag,cls='',text)=>{const n=document.createElement(tag);n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const button=(text,fn)=>{const n=el('button','button button-secondary',text);n.type='button';n.onclick=fn;return n;};
 const fmt=n=>Number(n||0).toLocaleString('pt-BR');
 let owner=null,testing=false,walletRequest=0,reportRequest=0,offset=0,reportCount=0;
 document.querySelector('.concept-account-coins')?.setAttribute('title','Mythic Coins');
 const premium=el('span','account-trixx'),icon=el('img'),balance=el('b','','—');icon.src='assets/currency/trixx-coins.webp';icon.alt='Trixx Coins';
 const recharge=button('+',()=>{const d=modal('Recarregar Trixx Coins');d.append(el('p','','As recargas com dinheiro real estarão disponíveis em breve.'));});recharge.classList.add('account-recharge');recharge.setAttribute('aria-label','Recarregar Trixx Coins');premium.append(icon,balance,recharge);
 const currencies=el('div','account-currencies'),earned=document.querySelector('.concept-account-coins');
 if(earned){earned.before(currencies);currencies.append(earned,premium);}else document.querySelector('.concept-account-bar')?.append(premium);
 const notice=el('p','store-test-notice','MODO TESTE · Compras simuladas: sem cobrança, entrega de itens ou registro contábil.');notice.hidden=true;notice.setAttribute('role','status');document.querySelector('#view-store')?.prepend(notice);
 function modal(title){const d=el('dialog','basic-pack-dialog store-control-dialog'),header=el('header');header.append(el('h2','',title),button('Fechar',()=>d.close()));d.append(header);document.body.append(d);d.addEventListener('close',()=>d.remove(),{once:true});d.showModal();return d;}
 function apply(data){testing=Boolean(data.test_mode);balance.textContent=fmt(data.balance);notice.hidden=!testing;toggle.checked=testing;api()?.repaintStore?.();window.MythicPacksStore?.refresh?.();}
 async function refresh(){const who=uid(),ticket=++walletRequest;if(!who){owner=null;testing=false;balance.textContent='—';notice.hidden=true;toggle.checked=false;return;}if(owner!==who){testing=false;balance.textContent='—';notice.hidden=true;toggle.checked=false;owner=who;}try{const data=await rpc('get_store_wallet');if(who!==uid()||ticket!==walletRequest)return;apply(data);}catch{if(who===uid()&&ticket===walletRequest){testing=false;notice.hidden=true;balance.textContent='—';toggle.checked=false;api()?.repaintStore?.();}}}
 function preview(item){const d=modal('Compra de teste'),art=el('img','store-test-art');art.src=window.MythicSecurity.assetUrl(item.art);art.alt=item.name;d.append(el('p','store-test-notice','Simulação concluída. Nenhum saldo, item ou registro contábil foi alterado.'),art,el('h3','',item.name));}
 const panel=el('article','panel admin-card store-accounting'),heading=el('header');heading.append(el('small','','LOJA'),el('h2','','Contabilidade e modo teste'));panel.append(heading);
 const mode=el('label','store-test-toggle'),toggle=el('input');toggle.type='checkbox';mode.append(toggle,el('span','','Ativar modo teste da loja nesta conta'));const state=el('p');state.setAttribute('role','status');panel.append(mode,el('p','','Com o modo teste ativo, você pode simular compras de qualquer produto, inclusive itens já adquiridos, sem gastar moedas ou receber itens.'),state);
 toggle.onchange=async()=>{const enabled=toggle.checked,who=uid();toggle.disabled=true;try{const data=await rpc('admin_set_store_test',{p_enabled:enabled});if(who!==uid())return;apply(data);state.textContent=data.test_mode?'Modo teste ativado para sua conta.':'Compras reais reativadas para sua conta.';}catch(e){if(who===uid()){toggle.checked=testing;state.textContent=e.message;}}finally{toggle.disabled=false;}};
 const filters=el('div','store-accounting-filters'),from=el('input'),to=el('input'),currency=el('select');from.type=to.type='date';
 for(const [value,text] of [['','As duas moedas'],['mythic','Mythic Coins'],['trixx','Trixx Coins']]){const option=el('option','',text);option.value=value;currency.append(option);}
 for(const [text,input] of [['De',from],['Até',to],['Moeda',currency]]){const label=el('label','',text);label.append(input);filters.append(label);}
 filters.append(button('Filtrar',()=>{offset=0;loadReport();}));panel.append(filters);
 const totals=el('div','store-accounting-totals'),tableWrap=el('div','admin-table-wrap'),table=el('table','admin-table'),thead=el('thead'),tr=el('tr'),body=el('tbody'),pager=el('div','store-accounting-pager'),position=el('span'),feedback=el('p');feedback.setAttribute('role','status');
 for(const h of ['Data','Jogador','Operação','Produto','Moeda','Valor'])tr.append(el('th','',h));thead.append(tr);table.append(thead,body);tableWrap.append(table);
 const previous=button('← Anterior',()=>{offset=Math.max(0,offset-50);loadReport();}),next=button('Próxima →',()=>{offset+=50;loadReport();});pager.append(previous,position,next);panel.append(totals,feedback,tableWrap,pager,el('small','','Compras em Mythic Coins são registradas a partir desta atualização. O histórico premium disponível é importado. Créditos e recompensas são separados de compras; estes valores não representam faturamento em reais.'));
 document.querySelector('#view-admin .admin-grid')?.append(panel);window.MythicAdminMenu?.register('Contabilidade',panel);
 const labels={purchase:'Compra',credit:'Crédito',reward:'Recompensa',adjustment:'Ajuste'};
 async function loadReport(){if(!api()?.isAdmin?.())return;const who=uid(),ticket=++reportRequest;previous.disabled=next.disabled=true;feedback.textContent='Carregando lançamentos…';try{
  const end=to.value?new Date(to.value+'T00:00:00'):null;if(end)end.setDate(end.getDate()+1);
  const data=await rpc('admin_store_accounting',{p_from:from.value?new Date(from.value+'T00:00:00').toISOString():null,p_to:end?.toISOString()||null,p_currency:currency.value||null,p_offset:offset});if(who!==uid()||ticket!==reportRequest)return;
  body.replaceChildren();totals.replaceChildren();reportCount=Number(data.count);
  for(const code of ['mythic','trixx']){if(currency.value&&currency.value!==code)continue;const card=el('section'),name=code==='trixx'?'Trixx Coins':'Mythic Coins';card.append(el('h3','',name));for(const kind of ['purchase','credit','reward','adjustment']){const t=data.totals.find(x=>x.currency===code&&x.kind===kind);card.append(el('p','',`${labels[kind]}: ${fmt(t?.amount)} · ${fmt(t?.operations)} operações`));}totals.append(card);}
  for(const row of data.rows){const line=el('tr');for(const v of [new Date(row.created_at).toLocaleString('pt-BR'),row.player_name,labels[row.kind],row.product,row.currency==='trixx'?'Trixx Coins':'Mythic Coins',fmt(row.amount)])line.append(el('td','',v));body.append(line);}
  feedback.textContent=reportCount?'':'Nenhum lançamento neste período.';position.textContent=`${reportCount?offset+1:0}–${Math.min(offset+50,reportCount)} de ${fmt(reportCount)}`;
 }catch(e){if(who===uid()&&ticket===reportRequest)feedback.textContent=e.message;}finally{if(who===uid()&&ticket===reportRequest){previous.disabled=offset===0;next.disabled=offset+50>=reportCount;}}}
 window.addEventListener('mythic-admin-tab-changed',e=>{if(e.detail?.tab==='Contabilidade')loadReport();});
 window.MythicStoreControl={isTesting:()=>owner===uid()&&testing,refresh,preview};
 window.addEventListener('mythic-profile-loaded',refresh);
 window.addEventListener('mythic-view-changed',e=>{if(['store','admin'].includes(e.detail?.view))refresh();if(e.detail?.view==='admin'){offset=0;loadReport();}});
 window.addEventListener('mythic-admin-catalog-loaded',()=>{refresh();loadReport();});
 window.addEventListener('mythic-account-signed-out',()=>{walletRequest++;reportRequest++;owner=null;testing=false;balance.textContent='—';notice.hidden=true;toggle.checked=false;state.textContent='';totals.replaceChildren();body.replaceChildren();document.querySelectorAll('.store-control-dialog').forEach(d=>d.close());});
 refresh();
})();
