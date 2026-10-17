(() => {
 const make=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text)n.textContent=text;return n;};
 const grid=document.querySelector('#view-profile .legend-grid');if(!grid)return;
 let current=null,busy=false,kind='title';
 const hero=document.querySelector('#view-profile .profile-identity');
 const title=make('p','equipped-honor-title');title.id='equipped-honor-title';
 const featured=make('div','featured-medals');hero.append(title,featured);
 const sidebarTitle=make('small','sidebar-honor-title');document.querySelector('.profile-summary').append(sidebarTitle);
 const panel=make('section','panel honor-panel');panel.setAttribute('aria-label','Títulos e medalhas');
 const heading=make('header');heading.append(make('h3','','TÍTULOS E MEDALHAS'),make('small','','Conquistas permanentes da sua jornada'));panel.append(heading);
 const tabs=make('nav','honor-tabs');tabs.setAttribute('aria-label','Tipos de conquista');
 const titles=make('button','','Títulos'),medals=make('button','','Medalhas');titles.type=medals.type='button';tabs.append(titles,medals);panel.append(tabs);
 const status=make('p','honor-status','Carregando conquistas…');status.setAttribute('role','status');
 const items=make('div','honor-grid');panel.append(status,items);grid.append(panel);
 const friendArea=make('div','friend-honors');document.querySelector('.friend-profile-hero').after(friendArea);
 const signOut=()=>{const b=make('button','button button-secondary sign-out-account','Sair da conta');b.type='button';b.dataset.signOut='true';return b;};
 document.querySelector('.sidebar-bottom').append(signOut());document.querySelector('#view-profile .legend-actions').append(signOut());
 function medalChip(row){const chip=make('span','featured-medal',row.icon);chip.title=row.name;chip.setAttribute('aria-label',row.name);return chip;}
 function paintFeatured(data,targetTitle,targetMedals){
   const catalog=data?.catalog||[],equipped=catalog.find(c=>c.id===data.title_id&&c.unlocked);
   targetTitle.textContent=equipped?.name||'';targetMedals.replaceChildren();
   for(const id of data?.medals||[]){const row=catalog.find(c=>c.id===id&&c.unlocked);if(row)targetMedals.append(medalChip(row));}
 }
 async function equip(nextTitle,nextMedals){
   if(busy)return;busy=true;render();status.textContent='Salvando…';
   try{const result=await window.MythicOnline.equipHonors(nextTitle,nextMedals);if(result){current=result;status.textContent='Perfil atualizado.';}}
   catch(error){status.textContent=error.message||'Não foi possível salvar.';}
   finally{busy=false;render();}
 }
 function render(){
   titles.setAttribute('aria-pressed',String(kind==='title'));medals.setAttribute('aria-pressed',String(kind==='medal'));items.replaceChildren();
   if(!current)return;
   paintFeatured(current,title,featured);sidebarTitle.textContent=title.textContent;
   for(const row of current.catalog.filter(c=>c.kind===kind)){
     const active=kind==='title'?current.title_id===row.id:current.medals.includes(row.id);
     const card=make('article','honor-card'+(row.unlocked?' unlocked':' locked'));
     card.append(make('span','honor-emblem',row.icon),make('b','',row.name),make('small','',row.description));
     const progress=make('progress');progress.max=Math.max(1,row.target);progress.value=row.unlocked?progress.max:row.progress;progress.setAttribute('aria-label',row.name);card.append(progress);
     card.append(make('span','honor-progress',row.unlocked?'✓ Desbloqueado':`${row.progress} / ${row.target}`));
     const action=make('button','button '+(active?'button-primary':'button-secondary'),!row.unlocked?'Bloqueado':active?'Remover':kind==='title'?'Usar título':'Destacar medalha');action.type='button';action.disabled=!row.unlocked||busy;
     action.setAttribute('aria-pressed',String(active));
     action.addEventListener('click',()=>{
       if(kind==='title')return equip(active?null:row.id,current.medals);
       const selected=active?current.medals.filter(id=>id!==row.id):[...current.medals,row.id];
       if(selected.length>3){status.textContent='Você pode destacar até três medalhas. Remova uma antes de escolher outra.';return;}
       equip(current.title_id,selected);
     });card.append(action);items.append(card);
   }
 }
 titles.addEventListener('click',()=>{kind='title';render();});medals.addEventListener('click',()=>{kind='medal';render();});
 window.addEventListener('mythic-honors-loaded',event=>{
   const {playerId,data,error}=event.detail;
   if(playerId===window.MythicOnline?.userId()){
     current=data||null;status.textContent=error?'Títulos e medalhas aguardam a atualização do banco de dados.':'Escolha um título e até três medalhas para exibir no perfil.';render();
   }else if(document.getElementById('friend-profile-backdrop').dataset.playerId===playerId){
     friendArea.replaceChildren();if(!data)return;const friendTitle=make('b');const friendMedals=make('div','featured-medals');friendArea.append(friendTitle,friendMedals);paintFeatured(data,friendTitle,friendMedals);
   }
 });
 window.addEventListener('mythic-account-signed-out',()=>{current=null;items.replaceChildren();title.textContent=sidebarTitle.textContent='';featured.replaceChildren();friendArea.replaceChildren();status.textContent='Entre na conta para ver suas conquistas.';});
 render();window.MythicOnline?.loadHonors?.();
})();
