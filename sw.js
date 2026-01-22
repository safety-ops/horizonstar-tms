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
  // Only handle same-origin requests to avoid CORS issues
  if (event.request.url.startsWith(self.location.origin)) {
    event.respondWith(
      fetch(event.request).catch(() => {
        // Return empty response on failure
        return new Response('', { status: 503, statusText: 'Service Unavailable' });
      })
    );
  }
});
