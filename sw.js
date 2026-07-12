/* Service worker för Assistenten — gör appen installerbar och offline-bar. */
'use strict';

const CACHE_VERSION = 'assistenten-v1';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-512.png',
  './apple-touch-icon.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then(cache => cache.addAll(APP_SHELL))
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
  /* API-anrop och andra domäner går alltid direkt mot nätet */
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
