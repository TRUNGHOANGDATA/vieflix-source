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
    try { location.reload = function () {}; } catch (e) {}

    // 3) CHẶN QUẢNG CÁO VAST: bọc window.jwplayer để xoá 'advertising' khi setup
    var _jw;
    function wrapFactory(orig) {
      if (!orig || orig.__adWrapped) return orig;
      var wrapped = function () {
        var inst = orig.apply(this, arguments);
        try {
          if (inst && typeof inst.setup === 'function' && !inst.__adSetup) {
            inst.__adSetup = 1;
            var origSetup = inst.setup.bind(inst);
            inst.setup = function (cfg) {
              try {
                if (cfg && typeof cfg === 'object') {
                  delete cfg.advertising;
                  delete cfg.ads;
                }
              } catch (e) {}
              return origSetup(cfg);
            };
          }
        } catch (e) {}
        return inst;
      };
      try {
        Object.getOwnPropertyNames(orig).forEach(function (k) {
          try { wrapped[k] = orig[k]; } catch (e) {}
        });
      } catch (e) {}
      wrapped.__adWrapped = 1;
      return wrapped;
    }
    try {
      Object.defineProperty(window, 'jwplayer', {
        configurable: true,
        get: function () { return _jw; },
        set: function (v) { _jw = wrapFactory(v); }
      });
    } catch (e) {}

    // 4) Ẩn overlay/banner QC + cho video full khung
    var css = document.createElement('style');
    css.innerHTML = [
      '#_wau, ._wau, .ad, .ads, .adsbox, [id^="ad_"], [class*="popup"],',
      '[class*="overlay-ad"], [class*="banner"], iframe[src*="ads"] { display:none !important; }',
      'html, body { overflow:hidden !important; background:#000 !important; }',
      'video, .jwplayer, #player { width:100vw !important; height:100vh !important; }'
    ].join('\n');
    (document.head || document.documentElement).appendChild(css);

    // 5) Dự phòng: tự bấm "Bỏ qua quảng cáo" + gọi API skipAd + xoá target=_blank
    setInterval(function () {
      try {
        var sk = document.querySelector('.jw-skip:not(.jw-hidden)');
        if (sk && sk.offsetParent !== null) sk.click();
      } catch (e) {}
      try {
        if (typeof _jw === 'function') { var p = _jw(); if (p && p.skipAd) p.skipAd(); }
      } catch (e) {}
      try {
        var links = document.querySelectorAll('a[target="_blank"]');
        for (var i = 0; i < links.length; i++) { links[i].removeAttribute('target'); }
      } catch (e) {}
    }, 600);
  } catch (e) {}
})();
''';
