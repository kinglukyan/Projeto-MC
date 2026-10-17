const CACHE = "mythic-clash-cards-20261017-2";
const FILES = ["./assets/cards-20261017/afrodite.png","./assets/cards-20261017/anubis.png","./assets/cards-20261017/apolo.png","./assets/cards-20261017/aquiles.png","./assets/cards-20261017/ares.png","./assets/cards-20261017/artemis.png","./assets/cards-20261017/athena.png","./assets/cards-20261017/beowulf.png","./assets/cards-20261017/butter.png","./assets/cards-20261017/dionisio.png","./assets/cards-20261017/hefesto.png","./assets/cards-20261017/heimdall.png","./assets/cards-20261017/hercules.png","./assets/cards-20261017/hermes.png","./assets/cards-20261017/horus.png","./assets/cards-20261017/isis.png","./assets/cards-20261017/lobo-alfa.png","./assets/cards-20261017/lobo-beta.png","./assets/cards-20261017/lobo-omega.png","./assets/cards-20261017/lukyan-rei-de-todos.png","./assets/cards-20261017/lukyan.png","./assets/cards-20261017/minotauro.png","./assets/cards-20261017/odin.png","./assets/cards-20261017/osiris.png","./assets/cards-20261017/ra.png","./assets/cards-20261017/ragnar.png","./assets/cards-20261017/seth.png","./assets/cards-20261017/sobek.png","./assets/cards-20261017/thor.png","./assets/holograms/afrodite-hologram.png","./assets/holograms/anubis-hologram.png","./assets/holograms/apolo-hologram.png","./assets/holograms/aquiles-hologram.png","./assets/holograms/ares-hologram.png","./assets/holograms/artemis-hologram.png","./assets/holograms/athena-hologram.png","./assets/holograms/beowulf-hologram.png","./assets/holograms/butter-hologram.png","./assets/holograms/dionisio-hologram.png","./assets/holograms/feiticeira-serpentes-hologram.png","./assets/holograms/hefesto-hologram.png","./assets/holograms/heimdall-hologram.png","./assets/holograms/hercules-hologram.png","./assets/holograms/hermes-hologram.png","./assets/holograms/horus-hologram.png","./assets/holograms/isis-hologram.png","./assets/holograms/lobo-alfa-hologram.png","./assets/holograms/lobo-beta-hologram.png","./assets/holograms/lobo-omega-hologram.png","./assets/holograms/lukyan-hologram.png","./assets/holograms/lukyan-rei-de-todos-hologram.png","./assets/holograms/minotauro-hologram.png","./assets/holograms/odin-hologram.png","./assets/holograms/osiris-hologram.png","./assets/holograms/ra-hologram.png","./assets/holograms/ragnar-hologram.png","./assets/holograms/seth-hologram.png","./assets/holograms/sobek-hologram.png","./assets/holograms/thor-hologram.png","./card-expansion.js","./card-expansion.js?v=2","./card-hologram-map.json","./cartas-hologramas.html","./assets/concept-ui/convergence-star.svg","./concept-theme.css","./concept-theme.css?v=2","./concept-theme.js","./concept-theme.js?v=3","./assets/concept-ui/citadela-luminosa.png","./assets/concept-ui/mode-custom.png","./assets/concept-ui/mode-guardian.png","./assets/concept-ui/mode-normal.png","./assets/concept-ui/mode-ranked.png","./assets/concept-ui/mode-x1.png","./assets/concept-ui/panel-frame.svg","./honors.css", "./honors.css?v=1", "./honors.js", "./honors.js?v=1", "./profile-redesign.css", "./profile-redesign.css?v=1", "./profile-redesign.js", "./profile-redesign.js?v=1", "./missions-menu.css", "./missions-menu.css?v=1", "./missions-menu.js", "./missions-menu.js?v=1", "./online.js?v=47", "./app.js?v=131", "./rework.css", "./rework.css?v=citadela-6", "./assets/rework/citadela.webp", "./assets/rework/NotoSans-Bold.ttf", "./assets/rework/NotoSans-Regular.ttf", "./assets/rework/NotoSerif-Bold.ttf", "./assets/rework/OFL.txt", "./", "./index.html", "./mobile.html", "./styles.css", "./app.js", "./online.js", "./supabase-config.js", "./manifest.webmanifest", "./assets/app-icon.svg", "./assets/card-back.svg", "./assets/poseidon-full.png", "./assets/zeus-full.png", "./assets/hades-full.png", "./assets/friends-icon.svg", "./assets/battlefield-mud.png", "./assets/battlefield-forest.png", "./assets/hand-heaven.png", "./assets/soldado-esparta-sem-pontas-azuis.png", "./assets/spartan-chibi.svg", "./assets/card-badges/greece.svg", "./assets/card-badges/norse.svg", "./assets/card-badges/norse-viking.png", "./assets/medusa-full.png", "./assets/medusa-illustration.png", "./assets/holograms/spartan-hologram.png", "./assets/holograms/medusa-hologram.png", "./assets/holograms/poseidon-hologram.png", "./assets/holograms/zeus-hologram.png", "./assets/holograms/hades-hologram.png", "./assets/ranks/aprendiz-de-heroi.svg", "./assets/ranks/escudeiro.svg", "./assets/ranks/heroi.svg", "./assets/ranks/lenda.svg", "./assets/ranks/semideus.svg", "./assets/ranks/deus.svg", "./assets/ranks/convergente.svg", "./assets/card-badges/egypt.svg", "./assets/card-badges/celtic.svg", "./assets/card-badges/monster.png", "./assets/card-badges/alyans.png", "./assets/menu-theme.mp3", "./assets/battle-theme.mp3", "./assets/victory-emblem.png", "./assets/defeat-emblem.png", "./assets/ares-helm.svg", "./assets/mode-ranked.png", "./assets/mode-normal.png", "./assets/mode-guardian.png", "./assets/mode-x1.png", "./assets/mode-custom.png", "./assets/vs-emblem.png"];
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
































