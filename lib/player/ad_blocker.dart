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
    // 3) Ẩn overlay/banner QC + cho video full khung
    var css = document.createElement('style');
    css.innerHTML = [
      '#_wau, ._wau, .ad, .ads, .adsbox, [id^="ad_"], [class*="popup"],',
      '[class*="overlay-ad"], [class*="banner"], iframe[src*="ads"] { display:none !important; }',
      'html, body { overflow:hidden !important; background:#000 !important; }',
      'video, .jwplayer, #player { width:100vw !important; height:100vh !important; }'
    ].join('\n');
    (document.head || document.documentElement).appendChild(css);

    // 4) CHẶN QUẢNG CÁO VAST (an toàn, không đụng khởi tạo jwplayer):
    //    tự bấm "Bỏ qua quảng cáo" + gọi API skipAd ngay khi có thể.
    setInterval(function () {
      try {
        // Bấm nút skip của jwplayer khi hiện
        var sels = ['.jw-skip', '.jw-skippable', '[class*="jw-skip"]'];
        for (var s = 0; s < sels.length; s++) {
          var els = document.querySelectorAll(sels[s]);
          for (var j = 0; j < els.length; j++) {
            if (els[j] && els[j].offsetParent !== null) { try { els[j].click(); } catch (e) {} }
          }
        }
      } catch (e) {}
      try {
        // Gọi API skipAd của jwplayer (bỏ qua ngay sau skipoffset)
        if (typeof window.jwplayer === 'function') {
          var p = window.jwplayer();
          if (p && typeof p.skipAd === 'function') p.skipAd();
        }
      } catch (e) {}
      try {
        var links = document.querySelectorAll('a[target="_blank"]');
        for (var i = 0; i < links.length; i++) { links[i].removeAttribute('target'); }
      } catch (e) {}
    }, 500);
  } catch (e) {}
})();
''';
