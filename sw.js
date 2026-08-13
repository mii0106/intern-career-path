/* ============================================================
   STEP — オフライン用のキャッシュ
   ------------------------------------------------------------
   画面のファイル（HTML・JS・アイコン）だけを手元に置いておき、
   電波が無いところでもアプリが開くようにする。

   データ（Supabaseへの通信）はキャッシュしない。
   古い進捗が本当のデータのように見えてしまうため。
   オフライン中に押したチェックは shared/store.js が端末に積み、
   電波が戻ったときに送る。
   ============================================================ */
const CACHE = 'step-v1';
const SHELL = [
  './',
  './index.html',
  './admin.html',
  './shared/config.js',
  './shared/steps.js',
  './shared/ui.js',
  './shared/store.js',
  './manifest.webmanifest',
  './favicon-32.png',
  './icon-192.png',
  './icon-512.png',
  './apple-touch-icon.png'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      /* 1つでも取れないと全部失敗するので、個別に入れる */
      .then(c => Promise.all(SHELL.map(u => c.add(u).catch(() => null))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  /* 自分のドメインのファイルだけ扱う。Supabase や CDN は素通し */
  if (url.origin !== self.location.origin) return;

  /* 画面のファイルは、まずネットワーク。取れたら次回用に控える。
     取れなければキャッシュを出す（＝オフラインでも開ける）。 */
  e.respondWith(
    fetch(req)
      .then(res => {
        if (res && res.status === 200) {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {});
        }
        return res;
      })
      .catch(() => caches.match(req).then(hit => hit || caches.match('./index.html')))
  );
});
