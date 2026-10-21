/* LUMEN service worker: versioned precache, network-first page (updates on reload), runtime cache for the PeerJS CDN. */
const VERSION = 'lumen-v8';
const CORE = ['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png', './icon-maskable-512.png', './apple-touch-icon.png'];
const CDN = ['https://cdn.jsdelivr.net/npm/peerjs@', 'https://unpkg.com/peerjs@'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('lumen-') && k !== VERSION).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = req.url;
  // never cache Firebase SDK / Google sign-in / Firestore traffic: let it go straight to the network
  if (/^https:\/\/([a-z0-9-]+\.)*(gstatic\.com|googleapis\.com|firebaseapp\.com|firebaseio\.com|google\.com|googleusercontent\.com)\//.test(url) || url.includes('/__/auth/')) return;
  // PeerJS library from a CDN: cache-first, stored the first time it is fetched (multiplayer itself still needs the network)
  if (CDN.some(p => url.startsWith(p))) {
    e.respondWith(caches.open(VERSION).then(c => c.match(req).then(hit => hit || fetch(req).then(r => { if (r.ok) c.put(req, r.clone()); return r; }))));
    return;
  }
  if (new URL(url).origin !== self.location.origin) return;
  // the game page: network first, so a reload picks up a new version; fall back to the cache offline
  if (req.mode === 'navigate' || url.endsWith('/index.html')) {
    e.respondWith(fetch(req).then(r => { if (r.ok) { const cp = r.clone(); caches.open(VERSION).then(c => c.put('./index.html', cp)); } return r; })
      .catch(() => caches.match('./index.html').then(r => r || caches.match('./'))));
    return;
  }
  // other same-origin files: cache first, refresh in the background
  e.respondWith(caches.match(req, {ignoreSearch: true}).then(hit => {
    const net = fetch(req).then(r => { if (r.ok) { const cp = r.clone(); caches.open(VERSION).then(c => c.put(req, cp)); } return r; }).catch(() => hit);
    return hit || net;
  }));
});
