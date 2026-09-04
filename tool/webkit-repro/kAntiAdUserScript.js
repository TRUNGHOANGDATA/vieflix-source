
(function () {
  try {
    // -2) KHAI MÁY TÍNH CHO TRỌN VẸN. Đặt userAgent kiểu Windows là CHƯA ĐỦ trên
    //     iPad: trang embed của nguonc còn dò thêm
    //         navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1
    //     mà iPadOS khai đúng như vậy (platform 'MacIntel', 5 điểm chạm), nên nó
    //     vẫn xếp iPad vào máy Apple rồi đưa luồng của nhánh Apple — nhánh cần
    //     ServiceWorker, thứ WebView nhúng vĩnh viễn không có, dẫn tới đứng ở
    //     "0 seconds of 0 seconds" quay mãi. Nhánh còn lại chỉ cần MediaSource,
    //     iPad có sẵn. Đây là DÒ THIẾT BỊ cho hợp máy, không phải lớp bảo vệ nào.
    try {
      var fake = function (k, v) {
        try { Object.defineProperty(navigator, k, {
          configurable: true, get: function () { return v; }
        }); } catch (e) {}
      };
      if (navigator.platform !== 'Win32') fake('platform', 'Win32');
      if (navigator.maxTouchPoints > 0) fake('maxTouchPoints', 0);
    } catch (e) {}

    // -1b) GHI LẠI MỌI REQUEST HỎNG. Không có máy Mac để cắm Safari Web Inspector
    //      vào iPad, nên tự dựng "tab Network" tí hon: vá fetch và XHR, hỏng cái
    //      nào ghi cái đó. Đây là thứ duy nhất trả lời được câu "dữ liệu không về
    //      thì tắc ở request nào".
    try {
      if (!window.__vfNet) {
        window.__vfNet = [];
        var note = function (how, url, what) {
          try {
            if (window.__vfNet.length < 10) {
              window.__vfNet.push(how + ' ' + what + ' ' + String(url).slice(-80));
            }
          } catch (e) {}
        };
        var of = window.fetch;
        if (of) {
          window.fetch = function (input, init) {
            var u = (input && input.url) ? input.url : input;
            try { window.__vfReq.n++; window.__vfReq.cuoi = String(u).slice(-60); } catch (e2) {}
            var pr;
            try { pr = of.apply(this, arguments); } catch (e) { note('fetch', u, 'nem:' + e); throw e; }
            return pr.then(function (r) {
              if (!r.ok) note('fetch', u, 'HTTP' + r.status);
              return r;
            }, function (e) { note('fetch', u, 'hong:' + e); throw e; });
          };
        }
        var OX = window.XMLHttpRequest;
        if (OX) {
          var op = OX.prototype.open, sd = OX.prototype.send;
          OX.prototype.open = function (m, u) { this.__vfUrl = u; return op.apply(this, arguments); };
          OX.prototype.send = function () {
            var self = this;
            try { window.__vfReq.n++; window.__vfReq.cuoi = String(self.__vfUrl).slice(-60); } catch (e2) {}
            self.addEventListener('error', function () { note('xhr', self.__vfUrl, 'hong'); });
            self.addEventListener('abort', function () { note('xhr', self.__vfUrl, 'bi huy'); });
            self.addEventListener('load', function () {
              if (self.status >= 400) note('xhr', self.__vfUrl, 'HTTP' + self.status);
            });
            return sd.apply(this, arguments);
          };
        }
      }
    } catch (e) {}

    // -1c) THEO DÕI CHỖ NẠP DỮ LIỆU VÀO TRÌNH PHÁT. Đo trên iPad cho thấy
    //      MediaSource đã gắn (currentSrc là blob:) nhưng buffered.length = 0 và
    //      KHÔNG request nào hỏng — tức là hoặc player chưa từng gọi nạp, hoặc
    //      gọi rồi bị ném lỗi. Đây là chỗ duy nhất phân định được hai khả năng.
    try {
      window.__vfMse = { addSB: 0, mime: '', append: 0, loi: '' };
      var MSp = window.MediaSource && window.MediaSource.prototype;
      if (MSp && MSp.addSourceBuffer) {
        var oAdd = MSp.addSourceBuffer;
        MSp.addSourceBuffer = function (mime) {
          window.__vfMse.addSB++;
          window.__vfMse.mime = String(mime).slice(0, 60);
          try { return oAdd.apply(this, arguments); }
          catch (e) { window.__vfMse.loi = 'addSourceBuffer: ' + e; throw e; }
        };
      }
      var SBp = window.SourceBuffer && window.SourceBuffer.prototype;
      if (SBp && SBp.appendBuffer) {
        var oApp = SBp.appendBuffer;
        SBp.appendBuffer = function (b) {
          window.__vfMse.append++;
          try { return oApp.apply(this, arguments); }
          catch (e) { window.__vfMse.loi = 'appendBuffer: ' + e; throw e; }
        };
      }
      // Đếm TỔNG số request (không chỉ request hỏng) để biết player có đi lấy
      // dữ liệu hay không.
      window.__vfReq = { n: 0, cuoi: '' };
    } catch (e) {}

    // -1) GOM LỖI JS của trang. Console của trang bị bịt ở phần dưới (để qua
    //     mặt bộ dò devtool), nên khi trang phát hỏng thì không còn đường nào
    //     biết vì sao. Gom vào đây rồi app đọc ra bằng evaluateJavascript.
    try {
      if (!window.__vfErrors) {
        window.__vfErrors = [];
        var push = function (s) {
          try {
            if (window.__vfErrors.length < 8) window.__vfErrors.push(String(s).slice(0, 160));
          } catch (e) {}
        };
        window.addEventListener('error', function (e) {
          // Lỗi TẢI TÀI NGUYÊN (script/ảnh/video hỏng) không có message — nó nằm
          // ở e.target. Trước đây chỉ ghi được "error @:undefined", vô dụng.
          try {
            var t = e && e.target;
            if (t && t !== window && t.tagName) {
              push('tai hong <' + t.tagName.toLowerCase() + '> ' +
                   String(t.currentSrc || t.src || t.href || '').slice(-70));
              return;
            }
          } catch (e2) {}
          push((e && e.message ? e.message : 'error') + ' @' +
               ((e && e.filename ? e.filename : '').split('/').pop()) + ':' + (e && e.lineno));
        }, true);

        // Lỗi do CHÍNH jwplayer báo — nó có mã lỗi rất cụ thể (vd 232011 =
        // không tải được playlist, 224003 = định dạng không phát được). Player
        // xuất hiện muộn nên phải chờ; thôi chờ sau ~24 giây.
        var tries = 0;
        var jwT = setInterval(function () {
          if (++tries > 80) { clearInterval(jwT); return; }
          try {
            if (typeof window.jwplayer !== 'function') return;
            var jp = window.jwplayer();
            if (!jp || !jp.on) return;
            clearInterval(jwT);
            var note = function (kind) {
              return function (ev) {
                try {
                  window.__vfJwErr = kind + ' ' + (ev && ev.code ? ev.code : '') +
                    ' ' + String((ev && (ev.message || ev.type)) || '').slice(0, 90);
                } catch (e) {}
              };
            };
            jp.on('error', note('error'));
            jp.on('setupError', note('setupError'));
            if (jp.on) { try { jp.on('warning', note('warning')); } catch (e) {} }
          } catch (e) {}
        }, 300);
        window.addEventListener('unhandledrejection', function (e) {
          push('reject: ' + (e && e.reason ? e.reason : ''));
        });
        var ce = console.error;
        console.error = function () { push(Array.prototype.join.call(arguments, ' ')); };
        void ce;
      }
    } catch (e) {}
    // 0) VÔ HIỆU "disable-devtool" (devtool-guard.bundle.js của streamc.xyz).
    //    Log thật cho thấy nó bắn 'You don't have permission to use DEVTOOL type=6'
    //    rồi HUỶ/TẢI LẠI trang liên tục -> player không bao giờ dựng được.
    //    WebView nhúng hay bị DƯƠNG TÍNH GIẢ vì outerWidth/Height khác innerWidth
    //    (nó dùng chênh lệch đó để đoán devtools đang mở). Ép outer = inner, đặt
    //    vị trí cửa sổ về 0, và CẤM luôn hành động phá của nó (reload/điều hướng/
    //    đóng) để dù có "phát hiện" cũng không đá được trang đi.
    try {
      var mirror = function (k, innerKey) {
        try { Object.defineProperty(window, k, {
          configurable: true, get: function () { return window[innerKey]; }
        }); } catch (e) {}
      };
      mirror('outerWidth', 'innerWidth');
      mirror('outerHeight', 'innerHeight');
      try { Object.defineProperty(window, 'screenX', { configurable: true, get: function () { return 0; } }); } catch (e) {}
      try { Object.defineProperty(window, 'screenY', { configurable: true, get: function () { return 0; } }); } catch (e) {}
      try { Object.defineProperty(window, 'screenLeft', { configurable: true, get: function () { return 0; } }); } catch (e) {}
      try { Object.defineProperty(window, 'screenTop', { configurable: true, get: function () { return 0; } }); } catch (e) {}
    } catch (e) {}
    // Bộ phát hiện type=6 là "Performance": nó gọi console.table(mảng 50x500)
    // rồi ĐO THỜI GIAN. App đẩy MỌI console qua cầu nối native nên console.table
    // rất chậm -> bị tưởng là DevTools mở -> reload vô tận (đã xác minh trong
    // devtool-guard.bundle.js). Cho console.table/clear/dir... thành no-op NHANH;
    // console.log chỉ còn chuyển tiếp tin nhắn CỦA APP (VFKEY / VIEFLIX_DBG).
    // Giữ nguyên console.error/warn để vẫn đọc được lỗi thật khi chẩn đoán.
    try {
      var _c = window.console;
      if (_c) {
        var _log = _c.log ? _c.log.bind(_c) : function () {};
        var noop = function () {};
        ['table','clear','dir','dirxml','profile','profileEnd','group',
         'groupCollapsed','groupEnd','count','countReset','trace','time',
         'timeEnd','timeLog'].forEach(function (k) { try { _c[k] = noop; } catch (e) {} });
        _c.log = function () {
          try {
            var a0 = arguments[0];
            if (typeof a0 === 'string' &&
                (a0.lastIndexOf('VFKEY:', 0) === 0 ||
                 a0.lastIndexOf('VIEFLIX_DBG', 0) === 0)) {
              return _log.apply(null, arguments);
            }
          } catch (e) {}
          // mọi log khác: bỏ nhanh, KHÔNG qua cầu nối -> detector đo thấy nhanh.
        };
      }
    } catch (e) {}

    // Chặn hành động "trừng phạt" của guard: nó hay reload/điều hướng cả trang.
    try { window.stop = function () {}; } catch (e) {}
    try { Object.defineProperty(location, 'reload', { configurable: true, value: function () {} }); } catch (e) {}
    // Một số bản disable-devtool để lại API toàn cục -> tắt luôn nếu có.
    try { window.DisableDevtool = function () {}; } catch (e) {}
    try { Object.defineProperty(window, 'disableDevtool', { configurable: true, value: function () {} }); } catch (e) {}

    // 1) Popup quảng cáo: KHÔNG mở thật, nhưng phải trả về một CỬA SỔ GIẢ.
    //
    // Trang embed của nguồn (streamc.xyz) chỉ chạy player khi mở được popup:
    //   window.addEventListener('popup-failed', () => blockPlayer());
    // và blockPlayer() xoá luôn link phim, hiện "PHÁT HIỆN CHẶN QUẢNG CÁO".
    // Trả null là chúng nó biết ngay -> mất phim. Trả cửa sổ giả thì chúng tưởng
    // popup đã mở, player chạy bình thường, mà thực tế không có tab nào bật lên.
    window.open = function () {
      var noop = function () {};
      var fake = {
        closed: false, opener: null, name: '', focus: noop, blur: noop,
        close: function () { this.closed = true; }, print: noop,
        moveTo: noop, resizeTo: noop, postMessage: noop,
        addEventListener: noop, removeEventListener: noop,
        location: { href: 'about:blank', replace: noop, assign: noop, reload: noop },
        document: { write: noop, writeln: noop, close: noop, open: noop, body: null }
      };
      fake.self = fake; fake.window = fake; fake.top = fake; fake.parent = fake;
      return fake;
    };
    // 2) Vô hiệu anti-devtools reload của trang embed
    try { Object.defineProperty(window, 'devtoolsDetector', {
      value: { launch: function(){}, addListener: function(){} },
      configurable: true
    }); } catch (e) {}

    // 2b) [ĐÃ TẮT] Trước đây bọc jwplayer bằng Proxy để xoá quảng cáo + ép tự
    //     phát. Nhưng nguồn streamc.xyz nay phát bằng player.js 2.1 (mã hoá) tự
    //     dựng player, và việc mình sửa config setup của nó làm nó init hỏng
    //     ("Lỗi khởi tạo player"). Đường tự-phát đã có kAutoPlayScript lo, nên
    //     bỏ hẳn lớp can thiệp này để không phá player của nguồn.

    // 3) Ẩn overlay/banner QC + cho video full khung
    var css = document.createElement('style');
    css.innerHTML = [
      '#_wau, ._wau, .ad, .ads, .adsbox, [id^="ad_"], [class*="popup"],',
      '[class*="overlay-ad"], [class*="banner"], iframe[src*="ads"] { display:none !important; }',
      'html, body { overflow:hidden !important; background:#000 !important; }',
      'video, .jwplayer, #player { width:100vw !important; height:100vh !important; }'
    ].join('\n');
    (document.head || document.documentElement).appendChild(css);

    // 4) CHẶN QUẢNG CÁO (video pre-roll tự chèn của nguồn):
    //    a) tự bấm nút "Bỏ qua" tìm theo CHỮ (không phụ thuộc class), bắn đủ sự kiện chuột.
    //    b) khi đang có quảng cáo, TUA NHANH video quảng cáo (ngắn) tới cuối để vào phim.
    function fireClick(el) {
      try {
        var r = el.getBoundingClientRect();
        var x = r.left + r.width / 2, y = r.top + r.height / 2;
        ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(function (t) {
          var ev;
          try { ev = new MouseEvent(t, { bubbles: true, cancelable: true, view: window, clientX: x, clientY: y }); }
          catch (e) { ev = document.createEvent('MouseEvents'); ev.initEvent(t, true, true); }
          el.dispatchEvent(ev);
        });
      } catch (e) {}
    }

    function norm(s) { return (s || '').toString().toLowerCase(); }

    setInterval(function () {
      // Phát hiện đang có quảng cáo (chữ "quảng cáo"/"bỏ qua" xuất hiện)
      var pageText = '';
      try { pageText = norm(document.body ? document.body.innerText : ''); } catch (e) {}
      var adOn = /quảng cáo|bỏ qua/.test(pageText);

      // a) Bấm mọi phần tử skip: theo chữ "bỏ qua" hoặc class/id chứa "skip"
      try {
        var cands = document.querySelectorAll('button, a, div, span, [class*="skip"], [id*="skip"]');
        for (var i = 0; i < cands.length; i++) {
          var el = cands[i];
          if (!el || el.offsetParent === null) continue;
          var t = norm(el.textContent).trim();
          var cls = norm(el.className) + ' ' + norm(el.id);
          var byText = t.length > 0 && t.length < 40 && t.indexOf('bỏ qua') >= 0 && el.children.length <= 3;
          var byCls = cls.indexOf('skip') >= 0;
          if (byText || byCls) fireClick(el);
        }
      } catch (e) {}

      // b) Tua nhanh video quảng cáo (ngắn) tới cuối khi đang có quảng cáo
      if (adOn) {
        try {
          var vids = document.querySelectorAll('video');
          for (var k = 0; k < vids.length; k++) {
            var v = vids[k];
            var d = v.duration;
            // Quảng cáo thường ngắn (<6 phút); phim/tập dài hơn nhiều -> chỉ tua clip ngắn
            if (isFinite(d) && d > 0 && d < 360) {
              try { v.muted = true; if (v.currentTime < d - 0.3) v.currentTime = d; } catch (e) {}
            }
          }
        } catch (e) {}
      }

      // c) Gọi API skipAd của jwplayer nếu có (trường hợp là VAST chuẩn)
      try {
        if (typeof window.jwplayer === 'function') {
          var p = window.jwplayer();
          if (p && typeof p.skipAd === 'function') p.skipAd();
        }
      } catch (e) {}

      // d) Bỏ target=_blank tránh mở tab QC
      try {
        var links = document.querySelectorAll('a[target="_blank"]');
        for (var m = 0; m < links.length; m++) { links[m].removeAttribute('target'); }
      } catch (e) {}
    }, 350);
  } catch (e) {}
})();
