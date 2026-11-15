'use strict';

// Isolated recipe-tech preview.
// No Firebase, no push notifications, no production URLs.
// Network-only worker; offline caching is intentionally disabled.
self.addEventListener('install', (event) => {
  self.skipWaiting();
});
self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});
