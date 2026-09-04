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
    net:(window.__vfNet||[]).slice(0,6), errs:(window.__vfErrors||[]).slice(0,6)});
})()`;

(async () => {
  const browser = await (engine === 'webkit' ? webkit : chromium).launch({ headless: true });
  const ctx = await browser.newContext({ userAgent: UA, viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  const log = (s) => { console.log(s); };
  await page.addInitScript(anti);              // y hệt app: tiêm ở document-start
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
