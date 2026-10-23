/* Downloads are verified against the exact media revisions consumed by the worker. */
(() => {
 'use strict';
 let job=null,controller=null,completed=false,owner=null,epoch=0;
 const CACHE='mythic-clash-fast-media-v1',base=new URL('./',location.href);
 const mb=n=>(n/1048576).toFixed(1)+' MB';
 function ui(){const root=document.getElementById('loading-screen');if(!root)return null;let box=root.querySelector('.resource-download');if(!box){box=document.createElement('div');box.className='resource-download';const progress=document.createElement('progress');progress.max=100;progress.value=0;progress.setAttribute('aria-label','Recursos salvos no navegador');const number=document.createElement('strong');number.textContent='0%';const info=document.createElement('small');info.setAttribute('role','status');const retry=document.createElement('button');retry.type='button';retry.className='button button-secondary';retry.textContent='Tentar baixar novamente';retry.hidden=true;box.append(progress,number,info,retry);root.append(box);}return box;}
 async function ensure(){
  if(completed)return true;if(job)return job;owner=window.MythicOnline?.userId?.();if(!owner)return false;
  controller=new AbortController();const signal=controller.signal,token=++epoch;window.MythicLoading?.begin('resources','BAIXANDO RECURSOS NO NAVEGADOR');
  job=(async()=>{
   if(!window.caches)throw Error('Este navegador não liberou o armazenamento de recursos. Abra o jogo no Safari, Chrome ou Edge fora do modo privado.');
   try{await navigator.storage?.persist?.();}catch{}
   const response=await fetch(new URL('asset-manifest.json',base),{cache:'no-store',signal});if(!response.ok)throw Error('Não foi possível consultar os recursos desta versão.');const manifest=await response.json();
   const paths=[...new Set(Object.keys(manifest.assets).map(p=>manifest.optimized?.[p]||p))].filter(p=>p.startsWith('assets/')&&!p.startsWith('assets/basic-packs/')&&!p.split('/').includes('..'));
   const cache=await caches.open(CACHE),total=paths.reduce((s,p)=>s+(manifest.sizes?.[p]||0),0);let bytes=0,done=0,index=0,failed=false;
   const wanted=new Set(paths.map(p=>{const u=new URL(p,base);u.searchParams.set('__mythic_rev',manifest.assets[p]);return u.href;}));for(const request of await cache.keys()){if(signal.aborted)return false;const u=new URL(request.url);if(u.origin===base.origin&&u.pathname.startsWith(new URL('assets/',base).pathname)&&!wanted.has(u.href))await cache.delete(request);}
   let painting=false;function paint(){if(painting)return;painting=true;requestAnimationFrame(()=>{painting=false;if(completed||failed||signal.aborted||token!==epoch)return;const box=ui();if(!box)return;const percentage=Math.min(99,Math.floor(total?bytes/total*100:done/paths.length*100));box.querySelector('progress').value=percentage;box.querySelector('strong').textContent=percentage+'%';box.querySelector('small').textContent=`${done} / ${paths.length} recursos${total?' · '+mb(bytes)+' / '+mb(total):''}`;});}
   paint();
   async function worker(){while(index<paths.length&&!failed){const path=paths[index++],url=new URL(path,base);url.searchParams.set('__mythic_rev',manifest.assets[path]);const expected=manifest.sizes?.[path]||0;
    try{if(signal.aborted)throw new DOMException('Cancelado','AbortError');if(await cache.match(url.href)){bytes+=expected;done++;paint();continue;}
     let received=0;const abort=new AbortController(),relay=()=>abort.abort();signal.addEventListener('abort',relay,{once:true});const timeout=setTimeout(()=>abort.abort(),120000);
     try{const result=await fetch(url.href,{signal:abort.signal,cache:'no-store'});if(!result.ok)throw Error('Não foi possível baixar '+path.split('/').at(-1)+'.');
      const saved=cache.put(url.href,result.clone());saved.catch(()=>{});if(result.body){const reader=result.body.getReader();try{for(;;){const part=await reader.read();if(part.done)break;received+=part.value.byteLength;bytes+=part.value.byteLength;paint();}}finally{reader.releaseLock();}}await saved;bytes+=Math.max(0,expected-received);done++;paint();
     }finally{clearTimeout(timeout);signal.removeEventListener('abort',relay);}
    }catch(error){failed=true;throw error;}
   }}
   const results=await Promise.allSettled(Array.from({length:3},worker));const error=results.find(r=>r.status==='rejected');if(error)throw error.reason;if(signal.aborted)return false;
   const box=ui();if(box){box.querySelector('progress').value=100;box.querySelector('strong').textContent='100%';box.querySelector('small').textContent='Recursos desta versão disponíveis no navegador.';}completed=true;window.dispatchEvent(new Event('mythic-resources-ready'));return true;
  })().catch(error=>{
   if(signal.aborted||token!==epoch)return false;const box=ui();if(box){box.querySelector('small').textContent=error.name==='QuotaExceededError'?'Sem espaço para todos os recursos. Libere armazenamento e tente novamente.':error.message||'O download foi interrompido. Confira a conexão.';const retry=box.querySelector('button');retry.hidden=false;retry.onclick=()=>{retry.hidden=true;job=null;ensure();};}return false;
  }).finally(()=>{if(token!==epoch)return;if(completed||signal.aborted){window.MythicLoading?.end('resources');ui()?.remove();}if(completed)job=null;});return job;
 }
 window.MythicResources={ensure,get ready(){return completed;}};
 window.addEventListener('mythic-profile-loaded',()=>{if(!completed&&!job)ensure();});
 window.addEventListener('mythic-account-signed-out',()=>{epoch++;controller?.abort();job=null;completed=false;owner=null;window.MythicLoading?.end('resources');ui()?.remove();});
})();
