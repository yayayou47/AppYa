/* AppYa — service hors ligne (téléphone).
   La page et ses fichiers sont gardés en cache : AppYa s'ouvre sans réseau. Stratégie « réseau d'abord » :
   connecté, on prend toujours la dernière version (et on met le cache à jour) ; hors ligne, on sert le cache.
   Les appels /api/ ne passent jamais par le cache : les données sont gérées par la page (stockage local + synchronisation).

   v3 (2026-11-14) : chemins relatifs (servi aussi sous /AppYa/ sur GitHub Pages) ; mode.js et moteur.js en cache.
   v2 (2026-11-14) : la page est rangée sous une seule clé, '/index.html', à l'écriture comme à la lecture.
   En v1, l'installation rangeait aussi '/', et la lecture hors ligne de '/' retombait sur cette copie
   figée au jour de l'installation : hors ligne, le téléphone montrait une vieille version (sans les icônes).
   Si l'ordinateur ne répond pas (éteint, Tailscale coupé), on n'attend pas plus de DELAI ms avant de
   servir le cache (la page) ; les icônes et le tableur sont servis du cache sans attendre. La réponse du réseau, si elle arrive plus tard, met quand même le cache à jour. */
const CACHE = 'appya-v5';
const DELAI = 3000;
// chemins relatifs au dossier du service : '/' sur l'ordinateur, '/AppYa/' sur GitHub Pages
const BASE = new URL('./', self.location).pathname;
const FICHIERS = ['index.html', 'mode.js', 'moteur.js', 'releve.js', 'demo.js', 'pdf.min.js', 'pdf.worker.min.js', 'xlsx.full.min.js', 'icone.svg', 'manifest.webmanifest', 'icone-192.png', 'icone-512.png', 'icone-512-masque.png'].map(f => BASE + f);

function cle(req) {
  const url = new URL(req.url);
  if (req.mode === 'navigate' || url.pathname === BASE || url.pathname === BASE + 'index.html') return BASE + 'index.html';
  return url.pathname;
}

self.addEventListener('install', ev => {
  ev.waitUntil(caches.open(CACHE)
    .then(c => c.addAll(FICHIERS.map(f => new Request(f, {cache: 'reload'}))))
    .then(() => self.skipWaiting()));
});
self.addEventListener('activate', ev => {
  ev.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', ev => {
  const req = ev.request, url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== location.origin || url.pathname.startsWith('/api/')) return;
  const k = cle(req);
  // Le service reste éveillé jusqu'à la fin de la mise à jour du cache, même si la page a déjà été servie.
  let finMaj; ev.waitUntil(new Promise(r => { finMaj = r; }));
  const reseau = fetch(req, {cache: 'no-store'}).then(rep => {
    if (rep.ok && rep.type === 'basic') { const copie = rep.clone(); caches.open(CACHE).then(c => c.put(k, copie)).catch(() => {}).then(finMaj); }
    else finMaj();
    return rep;
  }, err => { finMaj(); throw err; });
  if (k !== BASE + 'index.html') {
    // Fichiers d'accompagnement (icônes, tableur) : le cache tout de suite s'il les a, mis à jour en arrière-plan.
    ev.respondWith(caches.open(CACHE).then(c => c.match(k)).then(r => {
      if (r) { reseau.catch(() => {}); return r; }
      return reseau;
    }));
    return;
  }
  ev.respondWith(new Promise(resoudre => {
    let fini = false;
    const servirCache = () => caches.open(CACHE).then(c => c.match(k)).then(r => { if (r && !fini) { fini = true; resoudre(r); } return r; });
    const minuterie = setTimeout(servirCache, DELAI);
    reseau.then(rep => { clearTimeout(minuterie); if (!fini) { fini = true; resoudre(rep); } })
      .catch(() => { clearTimeout(minuterie); servirCache().then(r => { if (!r && !fini) { fini = true; resoudre(Response.error()); } }); });
  }));
});
