const CACHE_PREFIX = 'amr-pro-';
const CACHE_NAME = `${CACHE_PREFIX}v5`;
const ASSETS = [
  './',
  './index.html',
  './styles.css',
  './app.js',
  './manifest.json'
];
const ASSET_URLS = new Set(
  ASSETS.map(path => new URL(path, self.registration.scope).href)
);

self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(ASSETS))
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys =>
        Promise.all(
          keys
            .filter(key => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME)
            .map(key => caches.delete(key))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  // Only application assets belong in this cache; API traffic goes directly to the network.
  if(event.request.method !== 'GET' || !ASSET_URLS.has(event.request.url)) return;

  const responsePromise = fetch(event.request);
  event.waitUntil(
    responsePromise.then(async response => {
      if(!response.ok) return;
      const copy = response.clone();
      const cache = await caches.open(CACHE_NAME);
      await cache.put(event.request, copy);
    }).catch(() => {})
  );
  event.respondWith(
    responsePromise.catch(async error => {
      const cache = await caches.open(CACHE_NAME);
      const cached = await cache.match(event.request);
      if(cached) return cached;
      throw error;
    })
  );
});
