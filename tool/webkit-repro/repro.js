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
    W: window.__vfW, xhr: window.__vfXhr, MS: window.__vfMS, test: window.__vfTest, its: window.__vfITS, Hls: typeof window.Hls,
    SB: window.__vfSB, nat: window.__vfNat, who: window.__vfWho});
})()`;

setTimeout(() => { console.log('  == het gio cung, thoat =='); process.exit(0); }, 110000);
(async () => {
  const browser = await (engine === 'webkit' ? webkit : chromium).launch({ headless: true });
  const ctx = await browser.newContext({ userAgent: UA, viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  const log = (s) => { console.log(s); };
  // Giữ console GỐC trước khi script chống-devtool bịt nó, rồi mở lại đúng 5 hàm
  // log/debug/info/warn/error (table/clear/dir vẫn câm để lừa bộ dò Performance).
  // Nhờ đó đọc được logger của hls.js ở luồng chính.
  await page.addInitScript(() => { window.__vfNativeConsole = { log: console.log, debug: console.debug, info: console.info, warn: console.warn, error: console.error }; });
  await page.addInitScript(anti);              // y hệt app: tiêm ở document-start
  await page.addInitScript(() => { const n = window.__vfNativeConsole; if (n) { for (const k of ['log', 'debug', 'info', 'warn', 'error']) { try { console[k] = n[k]; } catch (e) {} } } });
  if (process.env.INJECT) { log('  [tiem them] ' + process.env.INJECT.slice(0, 120)); await page.addInitScript(process.env.INJECT); }
  await page.addInitScript(() => {
    // Soi MediaSource: loại nào được dùng (MMS hay MSE thường), sourceopen có nổ không.
    window.__vfMS = { mms: 0, mse: 0, open: 0, ended: 0, attach: 0, drp: null };
    for (const [k, nm] of [['ManagedMediaSource', 'mms'], ['MediaSource', 'mse']]) {
      const O = window[k]; if (!O) continue;
      const P = function () { const o = new O(); window.__vfMS[nm]++;
        o.addEventListener('sourceopen', () => window.__vfMS.open++);
        o.addEventListener('sourceended', () => window.__vfMS.ended++);
        return o; };
      P.prototype = O.prototype; P.isTypeSupported = O.isTypeSupported && O.isTypeSupported.bind(O);
      window[k] = P;
    }
    window.__vfITS = [];
    for (const k of ['MediaSource', 'ManagedMediaSource']) {
      const O = window[k]; if (!O || !O.isTypeSupported) continue;
      const of = O.isTypeSupported.bind(O);
      O.isTypeSupported = function (m) { const r = of(m); if (window.__vfITS.length < 16) window.__vfITS.push(k.replace('ManagedMediaSource', 'MMS').replace('MediaSource', 'MS') + ' ' + m + ' => ' + r); return r; };
    }
    // Soi SourceBuffer: nạp gì (tên box), rồi WebKit trả lời gì (updateend/error/buffered).
    window.__vfSB = [];
    const boxes = (u8) => { try { const names = []; let i = 0; const dv = new DataView(u8.buffer, u8.byteOffset, u8.byteLength);
      while (i + 8 <= u8.byteLength && names.length < 8) { let sz = dv.getUint32(i); const ty = String.fromCharCode(u8[i+4], u8[i+5], u8[i+6], u8[i+7]); if (sz === 1) { sz = Number(dv.getBigUint64(i + 8)); } if (sz < 8) { names.push(ty + '?'); break; } names.push(ty + ':' + sz); i += sz; }
      return names.join(' '); } catch (e) { return 'boxes? ' + e; } };
    const SBp = window.SourceBuffer && window.SourceBuffer.prototype;
    if (SBp) {
      const oAppend = SBp.appendBuffer;
      SBp.appendBuffer = function (b) {
        let rec = this.__vfRec; if (!rec) { rec = this.__vfRec = { n: window.__vfSB.length, appends: 0, updateend: 0, errors: [], boxes: [], buffered: '', tso: this.timestampOffset }; window.__vfSB.push(rec);
          this.addEventListener('updateend', () => { rec.updateend++; try { const r = []; for (let k = 0; k < this.buffered.length; k++) r.push(this.buffered.start(k).toFixed(2) + '-' + this.buffered.end(k).toFixed(2)); rec.buffered = r.join(',') || '(rong)'; } catch (e) { rec.buffered = 'err ' + e; } });
          this.addEventListener('error', (e) => { const v = document.querySelector('video'); rec.errors.push('SB error; video.error=' + (v && v.error ? v.error.code + ':' + v.error.message : 'null')); });
          this.addEventListener('abort', () => { rec.errors.push('SB abort'); }); }
        rec.appends++;
        try { const u8 = b instanceof ArrayBuffer ? new Uint8Array(b) : new Uint8Array(b.buffer, b.byteOffset, b.byteLength); if (rec.boxes.length < 6) rec.boxes.push(u8.byteLength + 'B[' + boxes(u8) + ']'); } catch (e) { rec.boxes.push('?' + e); }
        rec.tso = this.timestampOffset;
        return oAppend.apply(this, arguments);
      };
    }
    // AI gỡ SourceBuffer? Ghi stack của removeSourceBuffer/abort/endOfStream, và
    // đếm sự kiện 'emptied'/'loadstart' trên video kèm media.src lúc đó.
    window.__vfWho = [];
    const who = (tag) => { try { const st = (new Error().stack || '').split(String.fromCharCode(10)).slice(1, 7).map(l => l.trim().replace(/^at /, '').replace(new RegExp('https?://[^/]+/','g'), '').slice(0, 70)).join(' < '); const v = document.querySelector('video'); if (window.__vfWho.length < 12) window.__vfWho.push(tag + ' | src=' + (v ? String(v.src).slice(0, 25) : '-') + ' | ' + st); } catch (e) {} };
    const MSP = (window.ManagedMediaSource || window.MediaSource || {}).prototype;
    for (const P of [window.MediaSource && window.MediaSource.prototype, window.ManagedMediaSource && window.ManagedMediaSource.prototype]) {
      if (!P || P.__vfHooked) continue; P.__vfHooked = 1;
      for (const fn of ['removeSourceBuffer', 'endOfStream']) { const o = P[fn]; if (o) P[fn] = function () { who(fn); return o.apply(this, arguments); }; }
    }
    if (SBp && SBp.abort) { const oa = SBp.abort; SBp.abort = function () { who('SB.abort'); return oa.apply(this, arguments); }; }
    const oLoad = HTMLMediaElement.prototype.load;
    HTMLMediaElement.prototype.load = function () { who('media.load()'); return oLoad.apply(this, arguments); };
    document.addEventListener('emptied', (e) => { if (e.target && e.target.tagName === 'VIDEO') who('EVENT emptied'); }, true);
    document.addEventListener('loadstart', (e) => { if (e.target && e.target.tagName === 'VIDEO') who('EVENT loadstart'); }, true);
    // Giữ lại Blob playlist đã giải mã để thử phát native.
    const oc = URL.createObjectURL;
    window.__vfMsObjs = [];
    URL.createObjectURL = function (o) {
      if (o && o.type && /mpegurl/i.test(o.type)) { window.__vfM3u8BlobObj = o; }
      if (o && (o instanceof MediaSource || (window.ManagedMediaSource && o instanceof window.ManagedMediaSource))) window.__vfMsObjs.push(o);
      if (o && (o instanceof MediaSource || (window.ManagedMediaSource && o instanceof window.ManagedMediaSource))) {
        window.__vfMS.attach++;
        setTimeout(() => { const v = document.querySelector('video'); window.__vfMS.drp = v ? { disableRemotePlayback: v.disableRemotePlayback, inDom: v.isConnected, muted: v.muted, autoplay: v.autoplay, playsinline: v.hasAttribute('playsinline') } : null; }, 1500);
      }
      return oc.apply(this, arguments);
    };
    // Soi Worker: đếm, bắt lỗi, đếm tin nhắn vào/ra.
    window.__vfW = { tao: 0, loi: [], in: 0, out: 0 };
    const OW = window.Worker;
    window.Worker = function (u, o) {
      window.__vfW.tao++;
      const w = new OW(u, o);
      window.__vfW.msgIn = []; window.__vfW.msgOut = [];
      const tag = (d) => { try { if (!d || typeof d !== 'object') return String(d).slice(0, 30);
        const k = d.cmd || d.event || d.type || Object.keys(d).slice(0, 3).join('|');
        if (k === 'workerLog' && d.data) return ('log:' + String(d.data.message || d.data.msg || JSON.stringify(d.data))).slice(0, 110);
        let extra = '';
        if (d.data && d.data.details) extra = ':' + d.data.details; else if (d.data && d.data.type) extra = ':' + d.data.type;
        if (d.data && d.data.reason) extra += ':' + String(d.data.reason).slice(0, 60);
        if (d.data && d.data.error) extra += ':' + String(d.data.error.message || d.data.error).slice(0, 60);
        if (d.data && d.data.byteLength != null) extra += ':' + d.data.byteLength + 'B';
        if (d.data && d.data.data1 && d.data.data1.byteLength != null) extra += ':d1=' + d.data.data1.byteLength + 'B';
        if (d.data && d.data.tracks) extra += ':tracks=' + Object.keys(d.data.tracks).join('+');
        return (k + extra).slice(0, 90); } catch (e) { return '?'; } };
      w.addEventListener('error', e => { window.__vfW.loi.push(('' + (e.message || e)).slice(0, 200) + ' @' + (e.filename || '').slice(-30) + ':' + e.lineno); });
      w.addEventListener('messageerror', e => { window.__vfW.loi.push('messageerror'); });
      w.addEventListener('message', (e) => { window.__vfW.out++; if (window.__vfW.msgOut.length < 14) window.__vfW.msgOut.push(tag(e.data)); });
      const pm = w.postMessage.bind(w);
      w.postMessage = function (d) { window.__vfW.in++; if (window.__vfW.msgIn.length < 10) window.__vfW.msgIn.push(tag(d)); return pm.apply(w, arguments); };
      return w;
    };
    window.Worker.prototype = OW.prototype;
    // XHR: ghi lại số byte thật sự nhận được cho segment.
    window.__vfXhr = [];
    const oo = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function (m, u) {
      this.__vfUrl = u;
      // Đăng ký NGAY trong open() -> nổ TRƯỚC onreadystatechange của hls.js,
      // tức đọc được số byte trước khi nó transfer buffer sang Worker.
      this.addEventListener('readystatechange', () => {
        if (this.readyState !== 4) return;
        try { const uu = String(this.responseURL || u); if (/amass|\.png/.test(uu)) {
          const n = this.response && this.response.byteLength != null ? this.response.byteLength : -1;
          if (window.__vfXhr.length < 8) window.__vfXhr.push(`SOM ${this.status} bytes=${n} ${uu.slice(-30)}`); } } catch (e) {}
      });
      return oo.apply(this, arguments);
    };
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
  page.on('console', m => { const t = m.text(); if (!/Array\(|console\.clear|^div$|^function|preconnected|^\[object|^Sun |^Mon |^Tue |^Wed |^Thu |^Fri |^Sat /.test(t)) log(`  [console.${m.type()}] ${t.slice(0, 300)}`); });
  page.on('pageerror', e => log(`  [pageerror] ${String(e).slice(0, 200)}`));
  page.on('requestfailed', r => log(`  [REQ FAIL] ${r.failure() && r.failure().errorText} ${r.url().slice(0, 110)}`));
  page.on('response', async r => {
    const u = r.url(); const s = r.status();
    const ct = (r.headers()['content-type'] || '').slice(0, 30);
    if (s >= 400 || /\.m3u8|\.ts\b|\.m4s|segment|chunk|\.mp4|embed15|embed18|streamc/.test(u))
      log(`  [${s}] ${ct.padEnd(30)} ${u.slice(0, 120)}`);
  });
  log(`=== ${engine.toUpperCase()} -> ${URL}` + (process.env.NOAUTO ? '  [KHONG tiem script tu-phat]' : ''));
  await page.goto(URL, { referer: 'http://127.0.0.1:5555/', waitUntil: 'domcontentloaded' });
  // Tiêm autoplay như app (onLoadStop + nhịp tự lành)
  for (let i = 0; i < 12; i++) {
    await page.waitForTimeout(2500);
    if (!process.env.NOAUTO) { try { await page.evaluate(auto); } catch (e) {} }
    try { log(`  t=${(i + 1) * 2.5}s ${await page.evaluate(PROBE)}`); } catch (e) { log('  probe loi ' + e); }
  }
  browser.close().catch(() => {}); setTimeout(() => process.exit(0), 1500);
})().catch(e => { console.error('LOI:', e); process.exit(1); });
