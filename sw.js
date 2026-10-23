// Content revisions preserve warm image caches across releases.
const BUILD_ID='f45ac4042e76e0b89ab2';
const CACHE='mythic-clash-fast-shell-v1',MEDIA='mythic-clash-fast-media-v1';
const MANIFEST=new URL('asset-manifest.json',self.registration.scope).href;
let revisions={},optimized={},localManifest=null,manifestUpdate=null;
function valid(map){return map&&typeof map==='object'&&!Array.isArray(map)?Object.fromEntries(Object.entries(map).filter(([p,v])=>p.startsWith('assets/')&&!p.split('/').includes('..')&&typeof v==='string').slice(0,10000)):{};}
function readManifest(){if(!localManifest)localManifest=(async()=>{try{const response=await(await caches.open(CACHE)).match(MANIFEST);if(response){const data=await response.json();revisions=valid(data.assets);optimized=valid(data.optimized);}}catch{}})();return localManifest;}
function updateManifest(){if(!manifestUpdate)manifestUpdate=(async()=>{await readManifest();const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),6000);try{const response=await fetch(MANIFEST,{cache:'no-store',signal:controller.signal});if(!response.ok)return;const data=await response.clone().json();if(!data.assets)return;revisions=valid(data.assets);optimized=valid(data.optimized);await(await caches.open(CACHE)).put(MANIFEST,response);}catch{}finally{clearTimeout(timer);}})().finally(()=>{manifestUpdate=null;});return manifestUpdate;}
async function save(cache,key,response){try{await cache.put(key,response);}catch{}}
async function networkFirst(request,event){const cache=await caches.open(CACHE);try{const response=await fetch(request,{cache:'no-store'});if(response.status>=500)throw Error('server');if(response.ok)event.waitUntil(save(cache,request,response.clone()));return response;}catch{const saved=await cache.match(request);if(saved)return saved;if(request.mode==='navigate')return(await cache.match(new URL('index.html',self.registration.scope).href))||new Response('Sem conexão. Tente novamente.',{status:503,headers:{'Content-Type':'text/plain; charset=utf-8'}});return Response.error();}}
self.addEventListener('install',event=>event.waitUntil(self.skipWaiting()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{await self.clients.claim();await readManifest();const clients=await self.clients.matchAll({type:'window'});for(const client of clients)client.postMessage({type:'MYTHIC_RELEASE',id:BUILD_ID});})()));
self.addEventListener('message',event=>{if(event.data?.type==='MYTHIC_SKIP_WAITING')self.skipWaiting();});
self.addEventListener('fetch',event=>{const request=event.request,url=new URL(request.url);if(request.method!=='GET'||url.origin!==self.location.origin||request.headers.has('range'))return;
 if(/\/(?:rest|auth|api)\//.test(url.pathname))return;
 if(url.pathname.endsWith('/release.json')){event.respondWith(fetch(request,{cache:'no-store'}));return;}
 if(request.mode==='navigate'){event.waitUntil(updateManifest());event.respondWith(networkFirst(request,event));return;}
 if(/\.(js|css)$/i.test(url.pathname)&&url.searchParams.has('v')){event.respondWith((async()=>{const cache=await caches.open(CACHE);return(await cache.match(request))||networkFirst(request,event);})());return;}
 const media=url.pathname.includes('/assets/')||['image','font','audio','video'].includes(request.destination)||/\.(png|jpe?g|webp|avif|gif|svg|woff2?|ttf|otf|mp3|ogg|wav|mp4|webm)$/i.test(url.pathname);
 if(!media){event.respondWith(networkFirst(request,event));return;}
 event.respondWith((async()=>{await readManifest();let relative=url.pathname.slice(new URL(self.registration.scope).pathname.length);try{relative=decodeURIComponent(relative);}catch{}const mapped=optimized[relative];const target=mapped&&/^assets\/[a-z0-9_./-]+$/i.test(mapped)?new URL(mapped,self.registration.scope):new URL(request.url),revision=revisions[mapped||relative];if(revision){target.search='';target.searchParams.set('__mythic_rev',revision);}const cache=await caches.open(MEDIA),saved=await cache.match(target.href);if(saved)return saved;try{const response=await fetch(target.href,{cache:'default'});if(response.ok)event.waitUntil(save(cache,target.href,response.clone()));return response;}catch{return Response.error();}})());
});
