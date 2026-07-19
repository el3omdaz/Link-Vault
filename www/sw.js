const CACHE_NAME = 'linkvault-v8-trailer-library-splash-fix';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './app-config.js',
  './icon-192.png',
  './icon-512.png',
  './apple-touch-icon.png',
  './assets/LinkVault_splash_FHD_ultra_clear_preview.png',
  './assets/LinkVault_splash_FHD_original_logo_ultra_clear.mp4',
  './assets/LinkVault_splash_white_glow_fixed.gif'
];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL)).catch(() => null));
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))))
  );
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;

  if (req.mode === 'navigate') {
    event.respondWith(fetch(req).catch(() => caches.match('./index.html')));
    return;
  }

  event.respondWith(
    caches.match(req).then(cached => cached || fetch(req).then(res => {
      const copy = res.clone();
      caches.open(CACHE_NAME).then(cache => cache.put(req, copy)).catch(() => null);
      return res;
    }).catch(() => cached))
  );
});
