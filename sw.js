/* Service worker för Assistenten — gör appen installerbar och offline-bar. */
'use strict';

const CACHE_VERSION = 'assistenten-v3';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-512.png',
  './apple-touch-icon.png'
];
/* inloggningsbiblioteket, bästa-möjliga-försök (får inte stoppa installationen
   om CDN:et krånglar just då) */
const EXTRA_SHELL = [
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then(cache => cache.addAll(APP_SHELL)
        .then(() => Promise.all(EXTRA_SHELL.map(u => cache.add(u).catch(() => {})))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE_VERSION).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  /* inloggningsbiblioteket: cache först, så det funkar offline med en
     redan aktiv session — nätet uppdaterar cachen i bakgrunden */
  if (EXTRA_SHELL.includes(event.request.url)) {
    event.respondWith(
      caches.match(event.request).then(cached => {
        const fetchPromise = fetch(event.request)
          .then(res => {
            if (res && res.ok) caches.open(CACHE_VERSION).then(c => c.put(event.request, res.clone()));
            return res;
          })
          .catch(() => cached);
        return cached || fetchPromise;
      })
    );
    return;
  }

  /* övriga API-anrop och andra domäner går alltid direkt mot nätet */
  if (url.origin !== self.location.origin) return;
  if (event.request.method !== 'GET') return;

  /* nätet först, cachen som reserv — så uppdateringar syns direkt */
  event.respondWith(
    fetch(event.request)
      .then(res => {
        if (res && res.ok) {
          const clone = res.clone();
          caches.open(CACHE_VERSION).then(c => c.put(event.request, clone));
        }
        return res;
      })
      .catch(() => caches.match(event.request, { ignoreSearch: true }))
  );
});
