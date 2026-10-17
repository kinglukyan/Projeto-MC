const CACHE = "mythic-clash-network-first-v1";
const CORE = ["./", "./index.html", "./mobile.html", "./styles.css?v=151", "./rework.css?v=citadela-6", "./missions-menu.css?v=1", "./profile-redesign.css?v=1", "./honors.css?v=1", "./concept-theme.css?v=2", "./sidebar-arcane.css?v=1", "./eclipse.css?v=1", "./abilities.css?v=1", "./arcane-palette.css?v=1", "./arcane-upgrade.css?v=9", "./supabase-config.js?v=2", "./card-expansion.js?v=5", "./terrain-cards.js?v=1", "./location-cards.js?v=1", "./equipment-cards.js?v=2", "./eclipse.js?v=1", "./loki-card.js?v=2", "./abilities-data.js?v=4", "./abilities-engine.js?v=3", "./abilities-ui.js?v=1", "./avatars-chibi.js?v=1", "./combat-fx.js?v=1", "./arcane-upgrade.js?v=1", "./app.js?v=145", "./online.js?v=52", "./missions-menu.js?v=1", "./profile-redesign.js?v=1", "./honors.js?v=1", "./concept-theme.js?v=7", "./sidebar-arcane.js?v=1"];
self.addEventListener("install",event=>{
  event.waitUntil((async()=>{
    const cache=await caches.open(CACHE);
    await Promise.all(CORE.map(async url=>{try{const response=await fetch(new Request(url,{cache:"reload"}));if(response.ok)await cache.put(url,response);}catch{}}));
    await self.skipWaiting();
  })());
});
self.addEventListener("message",event=>{if(event.data?.type==="MYTHIC_SKIP_WAITING")self.skipWaiting();});
self.addEventListener("activate",event=>{
  event.waitUntil((async()=>{
    const names=await caches.keys();
    const legacy=names.some(name=>name.startsWith("mythic-clash-")&&!name.startsWith("mythic-clash-network-first-"));
    await Promise.all(names.filter(name=>name.startsWith("mythic-clash-")&&name!==CACHE).map(name=>caches.delete(name)));
    await self.clients.claim();
    // One-time migration: old pages have no controllerchange update handler.
    if(legacy){const clients=await self.clients.matchAll({type:"window"});await Promise.allSettled(clients.filter(client=>client.url.startsWith(self.registration.scope)).map(client=>client.navigate(client.url)));}
  })());
});
self.addEventListener("fetch",event=>{
  const request=event.request,url=new URL(request.url);
  if(request.method!=="GET"||url.origin!==self.location.origin||request.headers.has("range"))return;
  // Account and server requests must always retain their own authentication/cache rules.
  if(url.pathname.includes("/rest/")||url.pathname.includes("/auth/")||url.pathname.includes("/api/"))return;
  event.respondWith((async()=>{
    const cache=await caches.open(CACHE);
    try{
      const response=await fetch(request,{cache:"no-cache"});
      if(response.ok&&response.type!=="opaque")event.waitUntil(cache.put(request,response.clone()).catch(()=>{}));
      return response;
    }catch{
      const saved=await cache.match(request);if(saved)return saved;
      if(request.mode==="navigate")return (await cache.match("./index.html"))||new Response("Você está sem conexão. Tente novamente.",{status:503,headers:{"Content-Type":"text/plain; charset=utf-8"}});
      return Response.error();
    }
  })());
});
