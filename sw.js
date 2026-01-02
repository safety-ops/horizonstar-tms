// Horizon Star TMS Service Worker
const CACHE_NAME = 'horizonstar-tms-v1';

// Install event - skip waiting to activate immediately
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

// Activate event - claim clients immediately
self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});

// Fetch event - pass through (no caching for real-time TMS data)
self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
});
