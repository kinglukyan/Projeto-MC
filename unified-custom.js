(() => {
 'use strict';document.body.classList.add('unified-custom');const root=document.querySelector('#view-custom');if(!root)return;
 const heading=root.querySelector('.page-heading h1'),copy=root.querySelector('.page-heading>div>p:last-child');heading.textContent='Partida personalizada';if(copy)copy.textContent='Seu X1 está aqui. Jogue 1 × 1 ou forme equipes para um 2 × 2, com regras e convites na mesma sala.';
 const legacy=document.querySelector('#join-invite-form');if(legacy){const details=document.createElement('details');details.className='custom-legacy-code';const title=document.createElement('summary');title.textContent='Recebi um código X1 da versão anterior';details.append(title,legacy);root.append(details);}
 const action=document.querySelector('[data-invite-action="x1"]');if(action)action.textContent='Personalizada · X1';
 const oldMode=document.querySelector('.arena-mode-card[data-mode=friend]');if(oldMode)oldMode.hidden=true;
})();
