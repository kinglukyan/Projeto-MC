const CACHE = "mythic-clash-v116";
const FILES = ["./", "./index.html", "./mobile.html", "./styles.css", "./app.js", "./online.js", "./supabase-config.js", "./manifest.webmanifest", "./assets/app-icon.svg", "./assets/card-back.svg", "./assets/battlefield-mud.png", "./assets/battlefield-forest.png", "./assets/hand-heaven.png", "./assets/soldado-esparta-sem-pontas-azuis.png", "./assets/menu-theme.mp3", "./assets/battle-theme.mp3", "./assets/victory-emblem.png", "./assets/defeat-emblem.png"];
self.addEventListener("install", event => { event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(FILES))); self.skipWaiting(); });
self.addEventListener("activate", event => { event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key))))); self.clients.claim(); });
self.addEventListener("fetch", event => {
  if (event.request.method !== "GET" || new URL(event.request.url).origin !== self.location.origin) return;
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request).then(response => { const copy=response.clone(); caches.open(CACHE).then(cache=>cache.put(event.request,copy)); return response; }).catch(()=>caches.match("./index.html"))));
});

























