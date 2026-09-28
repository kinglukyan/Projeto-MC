const CACHE = "mythic-clash-v142";
const FILES = ["./", "./index.html", "./mobile.html", "./styles.css", "./app.js", "./online.js", "./supabase-config.js", "./manifest.webmanifest", "./assets/app-icon.svg", "./assets/card-back.svg", "./assets/battlefield-mud.png", "./assets/battlefield-forest.png", "./assets/hand-heaven.png", "./assets/soldado-esparta-sem-pontas-azuis.png", "./assets/spartan-chibi.svg", "./assets/card-badges/greece.svg", "./assets/card-badges/norse.svg", "./assets/card-badges/norse-viking.png", "./assets/medusa-full.png", "./assets/medusa-illustration.png", "./assets/ranks/aprendiz-de-heroi.svg", "./assets/ranks/escudeiro.svg", "./assets/ranks/heroi.svg", "./assets/ranks/lenda.svg", "./assets/ranks/semideus.svg", "./assets/ranks/deus.svg", "./assets/ranks/convergente.svg", "./assets/card-badges/egypt.svg", "./assets/card-badges/celtic.svg", "./assets/card-badges/monster.png", "./assets/card-badges/alyans.png", "./assets/menu-theme.mp3", "./assets/battle-theme.mp3", "./assets/victory-emblem.png", "./assets/defeat-emblem.png", "./assets/ares-helm.svg", "./assets/mode-ranked.png", "./assets/mode-normal.png", "./assets/mode-guardian.png", "./assets/mode-x1.png"];
self.addEventListener("install", event => { event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(FILES))); self.skipWaiting(); });
self.addEventListener("activate", event => { event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key))))); self.clients.claim(); });
self.addEventListener("fetch", event => {
  if (event.request.method !== "GET" || new URL(event.request.url).origin !== self.location.origin) return;
  if (new URL(event.request.url).pathname.endsWith("/supabase-config.js")) {
    event.respondWith(fetch(event.request).then(response => {
      const copy=response.clone();
      caches.open(CACHE).then(cache=>cache.put(event.request,copy));
      return response;
    }).catch(()=>caches.match(event.request)));
    return;
  }
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request).then(response => { const copy=response.clone(); caches.open(CACHE).then(cache=>cache.put(event.request,copy)); return response; }).catch(()=>caches.match("./index.html"))));
});

























