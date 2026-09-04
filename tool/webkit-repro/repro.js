// Tái hiện trang embed nguonc trên WebKit (nhân Safari/WKWebView) và Chromium,
// cùng cấu hình như app VieFlix, rồi so hai bên.
const { webkit, chromium } = require('playwright');
const fs = require('fs');
const engine = process.argv[2] || 'webkit';
const URL = process.argv[3] || 'https://embed18.streamc.xyz/embed.php?hash=448155e801ad6d279c5ec02dff435d5a';
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const anti = fs.readFileSync(__dirname + '/kAntiAdUserScript.js', 'utf8');
const auto = fs.readFileSync(__dirname + '/kAutoPlayScript.js', 'utf8');

const PROBE = `(function(){
  var v=document.querySelector('video'); var st='nojw';
  try{ if(typeof jwplayer==='function') st=jwplayer().getState(); }catch(e){st='jwerr';}
  return JSON.stringify({plat:navigator.platform, touch:navigator.maxTouchPoints,
    stream:String(window.streamURL||'').slice(-8), started:window.playerStarted, blocked:window.playerBlocked,
    video:!!v, vErr:v&&v.error?v.error.code+':'+v.error.message:null, vNet:v?v.networkState:null,
    vReady:v?v.readyState:null, vDur:v?v.duration:null, vBuf:v&&v.buffered?v.buffered.length:null,
    vTime:v?v.currentTime:null, vSrc:v?String(v.currentSrc).slice(0,30):null, jw:st,
    jwErr:window.__vfJwErr||'', mse:window.__vfMse||null, req:window.__vfReq||null,
    net:(window.__vfNet||[]).slice(0,6), errs:(window.__vfErrors||[]).slice(0,6),
    W: window.__vfW, xhr: window.__vfXhr});
})()`;

(async () => {
  const browser = await (engine === 'webkit' ? webkit : chromium).launch({ headless: true });
  const ctx = await browser.newContext({ userAgent: UA, viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  const log = (s) => { console.log(s); };
  await page.addInitScript(anti);              // y hệt app: tiêm ở document-start
  await page.addInitScript(() => {
    // Soi Worker: đếm, bắt lỗi, đếm tin nhắn vào/ra, và giữ lại mã nguồn blob.
    window.__vfW = { tao: 0, loi: [], in: 0, out: 0, src: '', apis: {} };
    const OW = window.Worker;
    window.Worker = function (u, o) {
      window.__vfW.tao++;
      try {
        fetch(String(u)).then(r => r.text()).then(t => {
          window.__vfW.src = t.slice(0, 400);
          const apis = {};
          ['createImageBitmap', 'OffscreenCanvas', 'getImageData', 'WebAssembly', 'importScripts',
           'SharedArrayBuffer', 'Atomics', 'TextDecoder', 'DOMParser', 'crypto.subtle', 'decrypt',
           'AES-GCM', 'AES-CBC', 'appendBuffer', 'MediaSource', 'transmux', 'mp4', 'moof', 'PNG', 'IDAT',
           'inflate', 'pako', 'fflate', 'ReadableStream', 'FileReaderSync', 'setTimeout', 'postMessage'].forEach(k => {
            const n = t.split(k).length - 1; if (n) apis[k] = n;
          });
          window.__vfW.apis = apis; window.__vfW.len = t.length;
        }).catch(e => { window.__vfW.src = 'khong doc duoc blob: ' + e; });
      } catch (e) {}
      const w = new OW(u, o);
      w.addEventListener('error', e => { window.__vfW.loi.push(('' + (e.message || e)).slice(0, 200) + ' @' + (e.filename || '').slice(-30) + ':' + e.lineno); });
      w.addEventListener('messageerror', e => { window.__vfW.loi.push('messageerror'); });
      w.addEventListener('message', () => { window.__vfW.out++; });
      const pm = w.postMessage.bind(w);
      w.postMessage = function () { window.__vfW.in++; return pm.apply(w, arguments); };
      return w;
    };
    window.Worker.prototype = OW.prototype;
    // XHR: ghi lại số byte thật sự nhận được cho segment.
    window.__vfXhr = [];
    const os = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function () {
      const x = this;
      x.addEventListener('loadend', () => {
        try {
          const u = String(x.responseURL || x.__vfUrl || '');
          if (/amass|\.png|mpegurl|streamc\.xyz\/ey/.test(u)) {
            let n = -1; try { n = x.response && x.response.byteLength != null ? x.response.byteLength : (x.responseText || '').length; } catch (e) { n = 'khong doc duoc: ' + e; }
            if (window.__vfXhr.length < 8) window.__vfXhr.push(`${x.status} rt=${x.responseType} bytes=${n} ${u.slice(-45)}`);
          }
        } catch (e) {}
      });
      return os.apply(this, arguments);
    };
  });
  page.on('console', m => { const t = m.text(); if (!/Array\(|console\.clear|^div$|^function/.test(t)) log(`  [console.${m.type()}] ${t.slice(0, 160)}`); });
  page.on('pageerror', e => log(`  [pageerror] ${String(e).slice(0, 200)}`));
  page.on('requestfailed', r => log(`  [REQ FAIL] ${r.failure() && r.failure().errorText} ${r.url().slice(0, 110)}`));
  page.on('response', async r => {
    const u = r.url(); const s = r.status();
    const ct = (r.headers()['content-type'] || '').slice(0, 30);
    if (s >= 400 || /\.m3u8|\.ts\b|\.m4s|segment|chunk|\.mp4|embed15|embed18|streamc/.test(u))
      log(`  [${s}] ${ct.padEnd(30)} ${u.slice(0, 120)}`);
  });
  log(`=== ${engine.toUpperCase()} -> ${URL}`);
  await page.goto(URL, { referer: 'http://127.0.0.1:5555/', waitUntil: 'domcontentloaded' });
  // Tiêm autoplay như app (onLoadStop + nhịp tự lành)
  for (let i = 0; i < 12; i++) {
    await page.waitForTimeout(2500);
    try { await page.evaluate(auto); } catch (e) {}
    try { log(`  t=${(i + 1) * 2.5}s ${await page.evaluate(PROBE)}`); } catch (e) { log('  probe loi ' + e); }
  }
  await browser.close();
})().catch(e => { console.error('LOI:', e); process.exit(1); });
