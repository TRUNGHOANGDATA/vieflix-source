import 'dart:io' show Platform;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Danh sách mảnh chuỗi domain quảng cáo/tracker cần chặn.
/// Mở rộng khi phát hiện QC mới (chỉ sửa data, không sửa logic).
const List<String> kAdHosts = [
  'whos.amung.us', 'waust.at',            // widget đếm (kèm QC)
  'propellerads', 'popads', 'popcash', 'poptm', 'popunder',
  'adsterra', 'hilltopads', 'onclicka', 'clickadu', 'adnxs',
  'exoclick', 'juicyads', 'trafficjunky', 'mgid',
  'doubleclick.net', 'googlesyndication', 'google-analytics',
  'googletagmanager', 'g.doubleclick', 'histats', 'statcounter',
  'yandex.ru/metrika', 'facebook.net', 'connect.facebook',
];

bool isAdUrl(String url) {
  final u = url.toLowerCase();
  for (final h in kAdHosts) {
    if (u.contains(h)) return true;
  }
  return false;
}

/// Regex url-filter cho ContentBlocker (thuần, dễ test).
List<String> adUrlFilters() =>
    kAdHosts.map((h) => '.*${RegExp.escape(h)}.*').toList();

/// ContentBlocker rules: chặn tải mọi resource khớp host QC.
/// LƯU Ý: ContentBlocker chỉ hỗ trợ trên Android/iOS/macOS. Trên Windows/Linux
/// việc tạo `ContentBlockerActionType.BLOCK` sẽ ném lỗi (Null → String), nên
/// trả về [] ở các nền tảng đó và dựa vào user script + chặn điều hướng.
List<ContentBlocker> adContentBlockers() {
  if (Platform.isWindows || Platform.isLinux) return [];
  return adUrlFilters()
      .map((f) => ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: f),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ))
      .toList();
}

/// JS tiêm sớm (document start): chặn popup, ẩn overlay, VÀ chặn quảng cáo
/// VAST pre-roll bằng cách xoá cấu hình `advertising` khỏi jwplayer.setup(),
/// kèm tự bấm "Bỏ qua quảng cáo" làm phương án dự phòng.
const String kAntiAdUserScript = r'''
(function () {
  try {
    // 1) Chặn mở tab/popup quảng cáo
    window.open = function () { return null; };
    // 2) Vô hiệu anti-devtools reload của trang embed
    try { Object.defineProperty(window, 'devtoolsDetector', {
      value: { launch: function(){}, addListener: function(){} },
      configurable: true
    }); } catch (e) {}

    // 2b) CHẶN TẬN GỐC: bọc jwplayer bằng Proxy (giữ nguyên mọi thuộc tính),
    //     chỉ xoá 'advertising'/'ads' khỏi config khi setup -> ad không được nạp.
    try {
      var _jwReal;
      function makeProxy(orig) {
        if (!orig || orig.__adProxied) return orig;
        var pr = new Proxy(orig, {
          apply: function (target, thisArg, args) {
            var inst = Reflect.apply(target, thisArg, args);
            try {
              if (inst && typeof inst.setup === 'function' && !inst.__adStrip) {
                inst.__adStrip = 1;
                var origSetup = inst.setup.bind(inst);
                inst.setup = function (cfg) {
                  try {
                    if (cfg && typeof cfg === 'object') {
                      delete cfg.advertising;
                      delete cfg.ads;
                      if (cfg.plugins) { try { delete cfg.plugins.vast; delete cfg.plugins.googima; } catch (e) {} }
                    }
                  } catch (e) {}
                  return origSetup(cfg);
                };
              }
            } catch (e) {}
            return inst;
          }
        });
        try { orig.__adProxied = 1; } catch (e) {}
        return pr;
      }
      Object.defineProperty(window, 'jwplayer', {
        configurable: true,
        get: function () { return _jwReal; },
        set: function (v) { _jwReal = makeProxy(v); }
      });
    } catch (e) {}

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
''';
