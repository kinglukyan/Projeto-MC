// Boas-vindas com escolha de mitologia e pacote inicial.
// Regras aprovadas 025: scripts atualizados sem invalidar o cache de imagens.
// Keep existing caches: this repair must not download everyone's images again.
const CACHE="mythic-clash-fast-shell-v1";
const MEDIA="mythic-clash-fast-media-v1";
const MANIFEST=new URL("asset-manifest.json",self.registration.scope).href;
function validRevisions(value){if(!value||typeof value!=="object"||Array.isArray(value))return {};return Object.fromEntries(Object.entries(value).filter(([path,hash])=>path.startsWith("assets/")&&!path.split("/").includes("..")&&typeof hash==="string"&&/^[a-f0-9]{20,64}$/.test(hash)).slice(0,10000));}
let revisions={},localManifest=null,manifestUpdate=null;
function readManifest(){
 if(localManifest)return localManifest;
 localManifest=(async()=>{try{const response=await (await caches.open(CACHE)).match(MANIFEST);if(response){const data=await response.json();revisions=validRevisions(data.assets);}}catch{}return revisions;})();
 return localManifest;
}
function updateManifest(){
 if(manifestUpdate)return manifestUpdate;
 manifestUpdate=(async()=>{
  await readManifest();const previous=revisions;
  try{
   const response=await fetch(MANIFEST,{cache:"no-cache"});if(!response.ok)return;
   const data=await response.clone().json();if(!data.assets||typeof data.assets!=="object")return;
   const next=validRevisions(data.assets);if(!Object.keys(next).length)return;
   await (await caches.open(CACHE)).put(MANIFEST,response);revisions=next;
   const changed=Object.keys(previous).length>0&&Object.keys(next).some(path=>previous[path]&&previous[path]!==next[path]);
   if(changed){const clients=await self.clients.matchAll({type:"window"});for(const client of clients)client.postMessage({type:"MYTHIC_MEDIA_UPDATED"});}
  }catch{}
 })().finally(()=>{manifestUpdate=null;});return manifestUpdate;
}
async function save(cache,key,response){try{await cache.put(key,response);}catch{}}
async function saveMedia(cache,key,response){
 try{await cache.put(key,response);const current=new URL(key);if(!current.searchParams.has("__mythic_rev"))return;for(const old of await cache.keys(key,{ignoreSearch:true})){const u=new URL(old.url);if(u.searchParams.has("__mythic_rev")&&u.href!==current.href)await cache.delete(old);}}catch{}
}
async function networkFirst(request,event){
 const cache=await caches.open(CACHE);
 try{
  // No short abort deadline: slow connections must not lose their scripts.
  const preload=request.mode==="navigate"?await event.preloadResponse:null;
  const response=preload||await fetch(request,{cache:"no-cache"});
  if(response.status>=500)throw new Error("server");
  if(response.ok)event.waitUntil(save(cache,request,response.clone()));return response;
 }catch{
  const saved=await cache.match(request);if(saved)return saved;
  if(request.mode==="navigate")return (await cache.match(new URL("index.html",self.registration.scope).href))||new Response("Você está sem conexão. Tente novamente.",{status:503,headers:{"Content-Type":"text/plain; charset=utf-8"}});
  return Response.error();
 }
}
self.addEventListener("install",event=>event.waitUntil(self.skipWaiting()));
self.addEventListener("message",event=>{if(event.data?.type==="MYTHIC_SKIP_WAITING")self.skipWaiting();});
self.addEventListener("activate",event=>event.waitUntil((async()=>{
 if(self.registration.navigationPreload){try{await self.registration.navigationPreload.enable();}catch{}}
 // Preserve warmed caches and authentication. Do not navigate all open tabs.
 await self.clients.claim();
})()));
self.addEventListener("fetch",event=>{
 const request=event.request,url=new URL(request.url);
 if(request.method!=="GET"||url.origin!==self.location.origin||request.headers.has("range"))return;
 if(url.pathname.includes("/rest/")||url.pathname.includes("/auth/")||url.pathname.includes("/api/"))return;
 if(request.mode==="navigate"){
  event.waitUntil(updateManifest());event.respondWith(networkFirst(request,event));return;
 }
 const versionedCode=/\.(?:js|css)$/i.test(url.pathname)&&url.searchParams.has("v");
 if(versionedCode){
  event.respondWith((async()=>{const cache=await caches.open(CACHE);return (await cache.match(request))||networkFirst(request,event);})());return;
 }
 const media=["image","font","audio","video"].includes(request.destination)||/\.(?:png|jpe?g|webp|avif|gif|svg|woff2?|ttf|otf|mp3|ogg|wav|mp4|webm)$/i.test(url.pathname);
 if(!media){event.respondWith(networkFirst(request,event));return;}
 event.respondWith((async()=>{
  // Read local metadata only. No image waits for a manifest network request.
  await readManifest();let relative=url.pathname.slice(new URL(self.registration.scope).pathname.length);try{relative=decodeURIComponent(relative);}catch{}const revision=revisions[relative];
  const key=new URL(request.url);if(revision)key.searchParams.set("__mythic_rev",revision);
  const cache=await caches.open(MEDIA),saved=await cache.match(key.href);
  if(saved)return saved;
  // Reuse original URL entries from the earlier cache as a quick migration.
  const old=revision?null:await (await caches.open(CACHE)).match(request);
  if(old){event.waitUntil(save(cache,key.href,old.clone()));return old;}
  try{const response=await fetch(request,{cache:revision?"no-cache":"default"});if(response.ok)event.waitUntil(saveMedia(cache,key.href,response.clone()));return response;}catch{return Response.error();}
 })());
});
