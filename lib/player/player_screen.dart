import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform, File, FileMode;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../main.dart' show webViewEnvironment;
import '../models/episode.dart';
import '../theme/app_theme.dart';
import 'ad_blocker.dart';

// Tên tập hiển thị: tránh "Tập Tập 01" khi nguồn đã có sẵn chữ "Tập"
String _epDisplay(String name) {
  final n = name.trim();
  if (RegExp(r'^t[aậ]p\b', caseSensitive: false).hasMatch(n)) return n;
  return 'Tập $n';
}

class PlayerScreen extends StatefulWidget {
  final String movieName, posterUrl, embedUrl;
  final List<Episode> episodes;
  final int startIndex;
  final int totalEpisodes; // tổng số tập full của phim (kể cả chưa ra)
  final void Function(Episode) onEpisodeChange;
  const PlayerScreen({
    super.key,
    required this.movieName,
    required this.posterUrl,
    required this.embedUrl,
    required this.episodes,
    required this.startIndex,
    required this.totalEpisodes,
    required this.onEpisodeChange,
  });
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  InAppWebViewController? _c;
  late int _idx;
  late String _url;

  // Thanh điều khiển của APP (remote không bấm được nút bên trong trang web).
  bool _showBar = false;      // đang hiện thanh điều khiển
  bool _paused = false;       // trạng thái phát
  double _pos = 0, _dur = 0;  // vị trí / tổng thời lượng (giây)
  Timer? _hideT, _pollT;

  // Hết tập -> đếm ngược rồi tự chuyển sang tập kế tiếp.
  static const int _autoNextSeconds = 8;
  int? _nextIn;               // số giây còn lại (null = không đếm)
  Timer? _nextT;
  bool _nextBlocked = false;  // người dùng đã bấm huỷ ở tập này

  @override
  void initState() {
    super.initState();
    _idx = widget.startIndex < 0 ? 0 : widget.startIndex;
    _url = widget.embedUrl;
    // ESC (PC) / phím remote (TV)
    HardwareKeyboard.instance.addHandler(_onKey);
    // Cập nhật vị trí phát để vẽ thanh tiến trình.
    _pollT = Timer.periodic(const Duration(seconds: 1), (_) => _syncState());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _hideT?.cancel();
    _pollT?.cancel();
    _nextT?.cancel();
    super.dispose();
  }

  // ------- Điều khiển video bằng JS (dùng được cả video HTML5 lẫn JWPlayer) -------
  Future<void> _js(String code) async {
    try { await _c?.evaluateJavascript(source: code); } catch (_) {}
  }

  void _seek(double delta) {
    _js('''(function(){var v=document.querySelector('video');
      if(v&&isFinite(v.duration)){v.currentTime=Math.max(0,Math.min(v.duration,v.currentTime+($delta)));return;}
      try{var p=jwplayer();p.seek(Math.max(0,p.getPosition()+($delta)));}catch(e){}})();''');
    _bumpBar();
  }

  void _togglePlay() {
    _js('''(function(){var v=document.querySelector('video');
      if(v){if(v.paused){v.play();}else{v.pause();}return;}
      try{var p=jwplayer();if(p.getState()==='playing'){p.pause();}else{p.play(true);}}catch(e){}})();''');
    setState(() => _paused = !_paused);
    _bumpBar();
  }

  /// Đọc vị trí/thời lượng/trạng thái từ trang để vẽ thanh tiến trình.
  Future<void> _syncState() async {
    if (!mounted || _c == null) return;
    try {
      final r = await _c!.evaluateJavascript(source: '''(function(){
        var v=document.querySelector('video');
        if(v&&isFinite(v.duration))return v.currentTime+'|'+v.duration+'|'+(v.paused?1:0)+'|'+(v.ended?1:0);
        try{var p=jwplayer();var st=p.getState();
          return p.getPosition()+'|'+p.getDuration()+'|'+(st==='playing'?0:1)+'|'+(st==='complete'?1:0);}catch(e){}
        return '';
      })();''');
      final s = (r ?? '').toString();
      if (s.isEmpty || !s.contains('|')) return;
      final parts = s.split('|');
      final pos = double.tryParse(parts[0]) ?? 0;
      final dur = double.tryParse(parts[1]) ?? 0;
      final paused = parts.length > 2 && parts[2].trim() == '1';
      final ended = parts.length > 3 && parts[3].trim() == '1';
      if (mounted) setState(() { _pos = pos; _dur = dur; _paused = paused; });
      // Hết tập: cờ ended của trình phát, hoặc chạy tới sát cuối (một số nguồn
      // không bắn sự kiện ended).
      final nearEnd = dur > 60 && pos > 0 && pos >= dur - 1.5;
      if (ended || nearEnd) _armAutoNext();
    } catch (_) {}
  }

  /// Bắt đầu đếm ngược chuyển tập (chỉ khi còn tập sau và chưa bị huỷ).
  void _armAutoNext() {
    if (_nextT != null || _nextBlocked) return;
    if (_idx + 1 >= widget.episodes.length) return; // đang ở tập cuối
    setState(() => _nextIn = _autoNextSeconds);
    _nextT = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final left = (_nextIn ?? 1) - 1;
      if (left <= 0) {
        _stopAutoNext();
        _goto(_idx + 1);
      } else {
        setState(() => _nextIn = left);
      }
    });
  }

  /// Dừng đếm ngược. [block] = người dùng huỷ -> không đếm lại ở tập này nữa.
  void _stopAutoNext({bool block = false}) {
    _nextT?.cancel();
    _nextT = null;
    if (block) _nextBlocked = true;
    if (mounted) setState(() => _nextIn = null);
  }

  /// Hiện thanh điều khiển rồi tự ẩn sau 3 giây.
  void _bumpBar() {
    _syncState();
    if (!_showBar && mounted) setState(() => _showBar = true);
    _hideT?.cancel();
    _hideT = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showBar = false);
    });
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    final k = e.logicalKey;
    // Đang đếm ngược chuyển tập: OK = xem ngay, ▼ = huỷ (ở lại tập này).
    if (_nextIn != null) {
      if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space ||
          k == LogicalKeyboardKey.gameButtonA) {
        _stopAutoNext();
        _goto(_idx + 1);
        return true;
      }
      if (k == LogicalKeyboardKey.arrowDown) { _stopAutoNext(block: true); return true; }
    }
    if (k == LogicalKeyboardKey.escape) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        return true;
      }
      return false;
    }
    // Điều khiển bằng remote / bàn phím
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.mediaFastForward) {
      _seek(10); return true;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.mediaRewind) {
      _seek(-10); return true;
    }
    if (k == LogicalKeyboardKey.arrowUp) { _seek(60); return true; }
    if (k == LogicalKeyboardKey.arrowDown) { _seek(-60); return true; }
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.mediaPlayPause || k == LogicalKeyboardKey.mediaPlay ||
        k == LogicalKeyboardKey.mediaPause || k == LogicalKeyboardKey.gameButtonA) {
      _togglePlay(); return true;
    }
    if (k == LogicalKeyboardKey.mediaTrackNext) { _goto(_idx + 1); return true; }
    if (k == LogicalKeyboardKey.mediaTrackPrevious) { _goto(_idx - 1); return true; }
    return false;
  }

  static String _fmt(double s) {
    if (!s.isFinite || s < 0) s = 0;
    final t = s.round();
    final h = t ~/ 3600, m = (t % 3600) ~/ 60, ss = t % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(ss)}' : '${two(m)}:${two(ss)}';
  }

  void _goto(int i) {
    if (i < 0 || i >= widget.episodes.length) return;
    final ep = widget.episodes[i];
    // Sang tập mới -> xoá mọi trạng thái "hết tập" của tập cũ.
    _nextT?.cancel();
    _nextT = null;
    _nextBlocked = false;
    setState(() {
      _idx = i;
      _url = ep.embed;
      _nextIn = null;
      _pos = 0;
      _dur = 0;
    });
    widget.onEpisodeChange(ep);
    _c?.loadUrl(urlRequest: URLRequest(url: WebUri(ep.embed)));
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalEpisodes > widget.episodes.length ? widget.totalEpisodes : widget.episodes.length;
    final epName = widget.episodes.isNotEmpty ? widget.episodes[_idx].name : '';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          // Thanh trên: back + poster + tên đầy đủ + Tập X/Y
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Thoát (ESC)',
                onPressed: () => Navigator.pop(context),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: widget.posterUrl,
                  width: 40, height: 56, fit: BoxFit.cover,
                  memCacheWidth: 120,
                  placeholder: (c, _) => Container(width: 40, height: 56, color: kSurface),
                  errorWidget: (c, _, __) => Container(width: 40, height: 56, color: kSurface, child: const Icon(Icons.movie, color: Colors.white24, size: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.movieName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(total > 1 ? '${_epDisplay(epName)} / $total' : 'Phim lẻ',
                        style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(Platform.isAndroid ? 'Nhấn Back để thoát' : 'Nhấn ESC để thoát',
                    style: const TextStyle(color: Colors.white24, fontSize: 12)),
              ),
            ]),
          ),
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: _webView()),
              // Thanh điều khiển của app (dành cho remote trên TV)
              if (_showBar)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: _controlBar(),
                ),
              // Hết tập -> hộp đếm ngược sang tập kế tiếp
              if (_nextIn != null)
                Positioned(right: 24, bottom: 24, child: _nextEpisodeBox()),
            ]),
          ),
          // Thanh dưới: chuyển tập
          if (widget.episodes.length > 1)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: _idx > 0 ? () => _goto(_idx - 1) : null),
                Text('${_epDisplay(epName)} / $total', style: const TextStyle(color: Colors.white)),
                IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: _idx < widget.episodes.length - 1 ? () => _goto(_idx + 1) : null),
              ]),
            ),
        ]),
      ),
    );
  }

  /// Hộp "Tập tiếp theo" khi phim/tập vừa hết: đếm ngược rồi tự chuyển.
  /// Bấm chuột được (PC) và bấm OK trên remote được (TV).
  Widget _nextEpisodeBox() {
    final next = _idx + 1 < widget.episodes.length ? widget.episodes[_idx + 1] : null;
    if (next == null) return const SizedBox.shrink();
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRed, width: 2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tập tiếp theo', style: TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 4),
        Text(_epDisplay(next.name),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
              onPressed: () { _stopAutoNext(); _goto(_idx + 1); },
              icon: const Icon(Icons.play_arrow, size: 20),
              label: Text('Xem ngay (${_nextIn}s)'),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _stopAutoNext(block: true),
            child: const Text('Huỷ', style: TextStyle(color: Colors.white70)),
          ),
        ]),
        const SizedBox(height: 4),
        const Text('OK: xem ngay   •   ▼: huỷ',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    );
  }

  /// Thanh điều khiển do APP vẽ: hiện khi bấm phím trên remote.
  Widget _controlBar() {
    final p = (_dur > 0) ? (_pos / _dur).clamp(0.0, 1.0) : 0.0;
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(_paused ? Icons.pause_circle_filled : Icons.play_circle_fill, color: kRed, size: 26),
          const SizedBox(width: 10),
          Text('${_fmt(_pos)} / ${_fmt(_dur)}',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          const Text('◀ ▶ tua 10 giây   •   ▲ ▼ tua 1 phút   •   OK: tạm dừng   •   Back: thoát',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: p, minHeight: 5,
            backgroundColor: Colors.white24, color: kRed,
          ),
        ),
      ]),
    );
  }

  Widget _webView() {
    final w = InAppWebView(
              // Windows: môi trường WebView2 đã mở khóa autoplay (main.dart).
              webViewEnvironment: webViewEnvironment,
              initialUrlRequest: URLRequest(url: WebUri(_url)),
              initialSettings: InAppWebViewSettings(
                contentBlockers: adContentBlockers(),
                javaScriptCanOpenWindowsAutomatically: false,
                supportMultipleWindows: false,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllowFullscreen: true,
                // Android: KHÔNG để nền trong suốt (làm video đen), và bật các cấu hình cần cho video.
                transparentBackground: !Platform.isAndroid,
                useHybridComposition: true,
                // Cho phép stream http nằm trong trang https (nhiều nguồn phim vậy).
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                domStorageEnabled: true,
                databaseEnabled: true,
                userAgent:
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              ),
              initialUserScripts: UnmodifiableListView([
                UserScript(
                  source: kAntiAdUserScript,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  forMainFrameOnly: false,
                ),
                // Tự phát: tiêm vào CẢ các iframe (player thường nằm trong iframe
                // khác miền -> JS ở trang ngoài không với tới được).
                UserScript(
                  source: kAutoPlayScript,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                  forMainFrameOnly: false,
                ),
              ]),
              onWebViewCreated: (c) => _c = c,
              shouldOverrideUrlLoading: (c, action) async {
                final u = action.request.url?.toString() ?? '';
                if (isAdUrl(u)) return NavigationActionPolicy.CANCEL;
                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (c, req) async => false,
              // Ghi dòng chẩn đoán VIEFLIX_DBG ra file để soi khi phim không tự chạy.
              onConsoleMessage: (c, msg) async {
                final m = msg.message;
                if (!m.startsWith('VIEFLIX_DBG')) return;
                try {
                  final dir = await getApplicationSupportDirectory();
                  final f = File('${dir.path}${Platform.pathSeparator}player-debug.log');
                  await f.writeAsString('$m\n', mode: FileMode.append);
                } catch (_) {}
              },
              // Sau khi trang tải xong: tự động phát (remote khó "bấm" nút play trong web).
              onLoadStop: (c, url) async {
                try { await c.evaluateJavascript(source: kAutoPlayScript); } catch (_) {}
                _syncState();
              },
            );
    // TV: chặn WebView "ăn" phím của remote — mọi phím do app xử lý, còn video
    // được điều khiển bằng JS. Trên PC vẫn cho bấm chuột vào trang như cũ.
    return Platform.isAndroid ? ExcludeFocus(child: IgnorePointer(child: w)) : w;
  }
}
