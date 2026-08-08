import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// CHẨN ĐOÁN v3: báo cáo qua cầu nối Dart (page không chặn được),
// hook media/fetch/XHR để lộ link quảng cáo. Chạy:
//   flutter run -t lib/diag_main.dart -d windows
const kEmbed = 'https://embed14.streamc.xyz/embed.php?hash=ca054de7441d042efeb36dcff321591d';

const kInitScript = r'''
(function(){
  // Lưu tham chiếu gốc TRƯỚC khi trang kịp thay thế
  var _setInterval = window.setInterval.bind(window);
  var _setTimeout = window.setTimeout.bind(window);
  var _fetch = window.fetch ? window.fetch.bind(window) : null;
  var _xopen = XMLHttpRequest.prototype.open;

  var queue = [];
  function report(tag, msg){
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        while (queue.length) { var q = queue.shift(); window.flutter_inappwebview.callHandler('diag', q.tag, q.msg); }
        window.flutter_inappwebview.callHandler('diag', tag, msg);
      } else { queue.push({tag:tag, msg:msg}); }
    } catch(e){}
  }

  report('INIT', 'ok');

  // Chống soi + chống reload (nhiều đường)
  try { window.open = function(){ return null; }; } catch(e){}
  try { console.clear = function(){}; } catch(e){}
  try { location.reload = function(){}; } catch(e){}
  try { Object.defineProperty(window,'devtoolsDetector',{value:{launch:function(){},addListener:function(){}},configurable:true}); } catch(e){}

  // Hook fetch / XHR
  try { if (_fetch) window.fetch = function(u){ try{ report('NET','fetch '+(typeof u==='string'?u:(u&&u.url)).toString().slice(0,180)); }catch(e){} return _fetch.apply(this, arguments); }; } catch(e){}
  try { XMLHttpRequest.prototype.open = function(m,u){ try{ report('NET','xhr '+(''+u).slice(0,180)); }catch(e){} return _xopen.apply(this, arguments); }; } catch(e){}

  // Hook nguồn media (src của <video>/<source>)
  try {
    var proto = HTMLMediaElement.prototype;
    var d = Object.getOwnPropertyDescriptor(proto, 'src');
    if (d && d.set) {
      Object.defineProperty(proto, 'src', {
        configurable:true,
        get: d.get,
        set: function(v){ try{ report('MEDIA','video.src='+(''+v).slice(0,180)); }catch(e){} return d.set.call(this, v); }
      });
    }
    var setAttr = Element.prototype.setAttribute;
    Element.prototype.setAttribute = function(n, val){
      try { if ((n==='src') && (this.tagName==='VIDEO'||this.tagName==='SOURCE')) report('MEDIA','setAttr '+(''+val).slice(0,180)); } catch(e){}
      return setAttr.apply(this, arguments);
    };
  } catch(e){}

  // Dump định kỳ video + nút skip
  function norm(s){ return (s||'').toString(); }
  function tryPlay(){
    try {
      if (typeof window.jwplayer === 'function') {
        var p = window.jwplayer();
        if (p) {
          if (p.getState) report('STATE', 'jw state=' + p.getState());
          if (p.play) p.play(true);
        }
      }
    } catch(e){ report('STATE','playErr '+e); }
    // Bấm nút play lớn nếu có
    try {
      var pb = document.querySelector('.jw-display-icon-display, .jw-icon-playback, [aria-label*="Play"], [class*="play"]');
      if (pb) pb.click();
    } catch(e){}
  }
  function dump(){
    try {
      tryPlay();
      var vids = document.querySelectorAll('video');
      var parts = ['jw='+(typeof window.jwplayer)+' videos='+vids.length];
      for (var i=0;i<vids.length;i++){ var v=vids[i];
        parts.push('VID['+i+'] dur='+Math.round(v.duration||-1)+' cur='+Math.round(v.currentTime||0)+' paused='+v.paused+' src='+norm(v.currentSrc||v.src).slice(0,120)); }
      var all = document.querySelectorAll('button,a,div,span'); var found=0;
      for (var k=0;k<all.length && found<12;k++){ var el=all[k]; var t=(el.textContent||'').trim();
        if (t && t.length<50 && /b[oỏ] qua|qu[aả]ng c[aá]o|skip/i.test(t)){
          parts.push('SKIP<'+el.tagName+' cls="'+norm(el.className).slice(0,50)+'" id="'+el.id+'" vis='+(el.offsetParent!==null)+'>"'+t.slice(0,36)+'"'); found++; }
      }
      report('DUMP', parts.join(' || '));
    } catch(e){ report('DUMP','err '+e); }
  }
  _setTimeout(dump, 2000);
  var n=0; _setInterval(function(){ dump(); if(++n>25){} }, 3000);
})();
''';

void main() => runApp(const MaterialApp(home: DiagPage(), debugShowCheckedModeBanner: false));

class DiagPage extends StatelessWidget {
  const DiagPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(kEmbed)),
        initialSettings: InAppWebViewSettings(
          javaScriptCanOpenWindowsAutomatically: false,
          supportMultipleWindows: false,
          mediaPlaybackRequiresUserGesture: false,
          userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        ),
        initialUserScripts: UnmodifiableListView([
          UserScript(source: kInitScript, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
        ]),
        onWebViewCreated: (controller) {
          controller.addJavaScriptHandler(handlerName: 'diag', callback: (args) {
            final tag = args.isNotEmpty ? args[0] : '?';
            final msg = args.length > 1 ? args[1] : '';
            // ignore: avoid_print
            print('DIAG[$tag] $msg');
            return null;
          });
        },
        onCreateWindow: (c, r) async => false,
      ),
    );
  }
}
