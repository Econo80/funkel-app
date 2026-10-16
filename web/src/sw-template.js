// Funkel offline service worker (generated into dist/sw.js at build time).
// Cache-first for the app's own files; nothing else is ever fetched.
const CACHE = "__CACHE_NAME__";
const PRECACHE = __PRECACHE__;

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key.startsWith("funkel-") && key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET" || new URL(request.url).origin !== self.location.origin) return;
  // ignoreVary: servers often send "Vary: Origin/Accept-Encoding", and module
  // scripts are requested with an Origin header the pre-cache request lacked.
  const lookup = { ignoreSearch: true, ignoreVary: true };
  event.respondWith(
    caches.match(request, lookup).then(
      (cached) =>
        cached ??
        fetch(request).then((response) => {
          if (response.ok) {
            const copy = response.clone();
            caches.open(CACHE).then((cache) => cache.put(request, copy));
          }
          return response;
        }).catch(() =>
          // Offline and not cached: only page loads fall back to the app shell.
          request.mode === "navigate" ? caches.match("./", lookup) : Response.error(),
        ),
    ),
  );
});
