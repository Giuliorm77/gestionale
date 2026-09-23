/* Service worker minimale del Gestionale Creatio.
   Serve SOLO a rendere l'app installabile (PWA) su Android/Chrome.
   NON fa cache: ogni richiesta va sempre in rete, così non vengono
   mai servite versioni vecchie del gestionale. */
self.addEventListener("install", (e) => { self.skipWaiting(); });
self.addEventListener("activate", (e) => { e.waitUntil(self.clients.claim()); });
self.addEventListener("fetch", (e) => { /* passthrough: rete, niente cache */ });
