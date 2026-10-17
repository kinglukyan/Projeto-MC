const CACHE="mythic-clash-fast-shell-v1";
const MEDIA="mythic-clash-fast-media-v1";
const MANIFEST=new URL("asset-manifest.json",self.registration.scope).href;
let revisions={},manifestLoaded=false,manifestPending=null;
async function fetchFresh(request,timeout=4000){
 const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),timeout);
 try{return await fetch(request,{cache:"no-cache",signal:controller.signal});}finally{clearTimeout(timer);}
}
async function refreshManifest(force=false){
 if(manifestPending)return manifestPending;
 if(manifestLoaded&&!force)return revisions;
 manifestPending=(async()=>{
  const cache=await caches.open(CACHE);let response;
  try{response=await fetchFresh(MANIFEST,1800);if(!response.ok)throw new Error("manifest");await cache.put(MANIFEST,response.clone());}
  catch{response=await cache.match(MANIFEST);}
  if(response){try{const data=await response.json();if(data.assets&&typeof data.assets==="object")revisions=data.assets;}catch{}}
  manifestLoaded=true;return revisions;
 })();
 try{return await manifestPending;}finally{manifestPending=null;}
}
async function networkFirst(request,event){
 const cache=await caches.open(CACHE);
 try{const response=await fetchFresh(request);if(response.status>=500)throw new Error("server");if(response.ok)event.waitUntil(cache.put(request,response.clone()).catch(()=>{}));return response;}
 catch{const saved=await cache.match(request);if(saved)return saved;
  if(request.mode==="navigate")return (await cache.match(new URL("index.html",self.registration.scope).href))||new Response("Você está sem conexão. Tente novamente.",{status:503,headers:{"Content-Type":"text/plain; charset=utf-8"}});
  return Response.error();}
}
self.addEventListener("install",event=>event.waitUntil(self.skipWaiting()));
self.addEventListener("message",event=>{if(event.data?.type==="MYTHIC_SKIP_WAITING")self.skipWaiting();});
self.addEventListener("activate",event=>event.waitUntil((async()=>{
 const names=await caches.keys();
 const legacy=names.some(name=>name.startsWith("mythic-clash-")&&!name.startsWith("mythic-clash-network-first-")&&!name.startsWith("mythic-clash-fast-"));
 await Promise.all(names.filter(name=>name.startsWith("mythic-clash-")&&name!==CACHE&&name!==MEDIA).map(name=>caches.delete(name)));
 await self.clients.claim();
 if(legacy){const clients=await self.clients.matchAll({type:"window"});await Promise.allSettled(clients.filter(c=>c.url.startsWith(self.registration.scope)).map(c=>c.navigate(c.url)));}
})()));
self.addEventListener("fetch",event=>{
 const request=event.request,url=new URL(request.url);
 if(request.method!=="GET"||url.origin!==self.location.origin||request.headers.has("range"))return;
 if(url.pathname.includes("/rest/")||url.pathname.includes("/auth/")||url.pathname.includes("/api/"))return;
 if(request.mode==="navigate"){
  event.respondWith((async()=>{const [response]=await Promise.all([networkFirst(request,event),refreshManifest(true)]);return response;})());return;
 }
 const media=["image","font","audio","video"].includes(request.destination)||/\.(?:png|jpe?g|webp|avif|gif|svg|woff2?|ttf|otf|mp3|ogg|wav|mp4|webm)$/i.test(url.pathname);
 if(!media){event.respondWith(networkFirst(request,event));return;}
 event.respondWith((async()=>{
  await refreshManifest();const relative=decodeURIComponent(url.pathname.slice(new URL(self.registration.scope).pathname.length)),revision=revisions[relative];
  // Unknown assets still revalidate. Known unchanged files return immediately.
  if(!revision)return networkFirst(request,event);
  const key=new URL(request.url);key.searchParams.set("__mythic_rev",revision);
  const cache=await caches.open(MEDIA),saved=await cache.match(key.href);if(saved)return saved;
  try{const response=await fetchFresh(request,15000);if(response.ok)event.waitUntil(cache.put(key.href,response.clone()).catch(()=>{}));return response;}catch{return Response.error();}
 })());
});
