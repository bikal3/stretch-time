// Offline cache. Bump VERSION whenever you change any file below.
const VERSION = 'stretchtime-v1';
const FILES = ['./', 'index.html', 'app.js', 'plan.js', 'manifest.json', 'icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png'];

self.addEventListener('install', e => e.waitUntil(caches.open(VERSION).then(c => c.addAll(FILES)).then(() => self.skipWaiting())));
self.addEventListener('activate', e => e.waitUntil(
  caches.keys().then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k)))).then(() => self.clients.claim())
));
self.addEventListener('fetch', e => e.respondWith(
  caches.match(e.request, { ignoreSearch: true }).then(r => r || fetch(e.request))
));
