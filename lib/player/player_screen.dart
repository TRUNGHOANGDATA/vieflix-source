import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform, File, FileMode;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../main.dart' show webViewEnvironment;
import '../models/episode.dart';
import '../theme/app_theme.dart';
import 'ad_blocker.dart';
import 'channel_bug.dart';

// Tên tập hiển thị: tránh "Tập Tập 01" khi nguồn đã có sẵn chữ "Tập"
String _epDisplay(String name) {
  final n = name.trim();
  if (RegExp(r'^t[aậ]p\b', caseSensitive: false).hasMatch(n)) return n;
  return 'Tập $n';
}

/// Cầu nối điều khiển video, TIÊM VÀO MỌI KHUNG (kể cả iframe khác miền — nơi
/// trình phát thật sự nằm). Vì `evaluateJavascript` chỉ chạy ở khung ngoài cùng
/// nên nút tạm dừng/tua trước đây "không ăn" khi player nằm trong iframe.
///
/// Cơ chế:
/// - Nhận lệnh (toggle/play/pause/seek/seekto) qua postMessage rồi thao tác lên
///   `<video>` hoặc JWPlayer NGAY TRONG khung đó; đồng thời chuyển lệnh xuống các
///   iframe con -> lệnh lan tới đúng khung có video dù lồng nhiều lớp.
/// - Mỗi khung có video sẽ gửi trạng thái (vị trí/thời lượng/đang phát/đã hết)
///   NGƯỢC lên tới khung ngoài cùng, lưu ở `window.__vfState` để app đọc.
const String kPlayerBridgeScript = r'''
(function(){
  if (window.__vfBridge) return; window.__vfBridge = 1;
  function vid(){ return document.querySelector('video'); }
  function jw(){ try { return (typeof jwplayer==='function') ? jwplayer() : null; } catch(e){ return null; } }
  function act(cmd, delta){
    try {
      var v = vid();
      if (cmd==='toggle'){
        if (v){ if(v.paused) v.play(); else v.pause(); return; }
        var p=jw(); if(p&&p.getState){ if(p.getState()==='playing') p.pause(); else p.play(true); }
      } else if (cmd==='play'){
        if (v){ v.play(); return; } var p2=jw(); if(p2&&p2.play) p2.play(true);
      } else if (cmd==='pause'){
        if (v){ v.pause(); return; } var p3=jw(); if(p3&&p3.pause) p3.pause();
      } else if (cmd==='seek'){
        if (v && isFinite(v.duration)){ v.currentTime=Math.max(0,Math.min(v.duration, v.currentTime+delta)); return; }
        var p4=jw(); if(p4&&p4.getPosition){ p4.seek(Math.max(0, p4.getPosition()+delta)); }
      } else if (cmd==='seekto'){
        if (v && isFinite(v.duration)){ v.currentTime=Math.max(0,Math.min(v.duration, delta)); return; }
        var p5=jw(); if(p5&&p5.seek){ p5.seek(delta); }
      }
    } catch(e){}
  }
  window.addEventListener('message', function(e){
    var d=e.data; if(!d || typeof d!=='object') return;
    if (d.__vf===1){
      act(d.cmd, d.delta||0);
      for (var i=0;i<window.frames.length;i++){ try{ window.frames[i].postMessage(d,'*'); }catch(err){} }
    } else if (d.__vfState===1){
      if (window.top===window){ window.__vfState=d.s; }
      else { try{ window.parent.postMessage(d,'*'); }catch(err){} }
    }
  });
  setInterval(function(){
    var v=vid(); var s=null;
    try {
      if (v && isFinite(v.duration) && v.duration>0){
        s={p:v.currentTime, d:v.duration, paused:v.paused?1:0, ended:v.ended?1:0};
      } else {
        var p=jw();
        if (p&&p.getDuration){ var st=p.getState(); s={p:p.getPosition(), d:p.getDuration(), paused:(st==='playing')?0:1, ended:(st==='complete')?1:0}; }
      }
    } catch(e){}
    if (s && s.d>0){
      if (window.top===window){ window.__vfState=s; }
      else { try{ window.parent.postMessage({__vfState:1, s:s}, '*'); }catch(err){} }
    }
  }, 1000);
})();
''';

class PlayerScreen extends StatefulWidget {
  final String movieName, embedUrl;
  final List<Episode> episodes;
  final int startIndex;
  final int totalEpisodes; // tổng số tập full của phim (kể cả chưa ra)
  final double startPosition; // giây: xem tiếp từ đâu (0 = từ đầu)
  final void Function(Episode) onEpisodeChange;
  final void Function(double pos, double dur)? onPosition; // lưu vị trí đang xem
  const PlayerScreen({
    super.key,
    required this.movieName,
    required this.embedUrl,
    required this.episodes,
    required this.startIndex,
    required this.totalEpisodes,
    required this.onEpisodeChange,
    this.startPosition = 0,
    this.onPosition,
  });
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  InAppWebViewController? _c;
  late int _idx;
  late String _url;

  // Thanh điều khiển của APP (remote không bấm được nút bên trong trang web).
  bool _showBar = false;      // đang hiện thanh điều khiển
  bool _paused = false;       // trạng thái phát
  double _pos = 0, _dur = 0;  // vị trí / tổng thời lượng (giây)
  Timer? _hideT, _pollT;

  /// Số giây hiện thanh điều khiển khi MỚI mở phim / vừa đổi tập.
  /// Phim tràn kín màn nên không còn thanh đen cố định: nếu không tự hiện lúc
  /// đầu thì người dùng chuột (PC) không biết nút Thoát / chuyển tập ở đâu.
  static const int _introBarSeconds = 5;

  // Hết tập -> đếm ngược rồi tự chuyển sang tập kế tiếp.
  static const int _autoNextSeconds = 8;
  int? _nextIn;               // số giây còn lại (null = không đếm)
  Timer? _nextT;
  bool _nextBlocked = false;  // người dùng đã bấm huỷ ở tập này

  // Xem tiếp từ vị trí cũ + lưu vị trí đang xem.
  double _resumeTo = 0;       // giây cần seek tới sau khi tải xong (0 = không)
  bool _resumeApplied = false;
  int _resumeTries = 0;       // số lần đã ép seek (nguồn hay reset về 0)
  int _saveTick = 0;          // đếm nhịp để ~3s mới ghi vị trí xuống đĩa 1 lần

  @override
  void initState() {
    super.initState();
    _idx = widget.startIndex < 0 ? 0 : widget.startIndex;
    _url = widget.embedUrl;
    _resumeTo = widget.startPosition;
    _resumeApplied = widget.startPosition <= 2;
    // ESC (PC) / phím remote (TV)
    HardwareKeyboard.instance.addHandler(_onKey);
    // Theo dõi vòng đời app: khi bị đưa xuống nền / đóng đột ngột thì lưu ngay
    // vị trí đang xem (dispose có thể không kịp chạy khi hệ thống kill app).
    WidgetsBinding.instance.addObserver(this);
    // Cập nhật vị trí phát để vẽ thanh tiến trình.
    _pollT = Timer.periodic(const Duration(seconds: 1), (_) => _syncState());
    // Android: ẩn thanh trạng thái / thanh điều hướng cho phim thật sự kín màn.
    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    // Hiện thanh điều khiển mấy giây đầu (gán trực tiếp: đang trong initState nên
    // KHÔNG được gọi setState).
    _showBar = true;
    _armHideBar(_introBarSeconds);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    // Trả lại thanh trạng thái / điều hướng cho các màn còn lại.
    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    }
    // Lưu nốt vị trí cuối cùng khi thoát trình phát.
    _flushPosition();
    _hideT?.cancel();
    _pollT?.cancel();
    _nextT?.cancel();
    super.dispose();
  }

  /// Ghi ngay vị trí đang xem xuống đĩa (dùng khi thoát / app xuống nền).
  void _flushPosition() {
    if (_dur > 0 && _pos > 0) widget.onPosition?.call(_pos, _dur);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TV/điện thoại: bấm Home hoặc hệ thống thu hồi app -> lưu ngay kẻo mất chỗ.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _flushPosition();
    }
  }

  // ------- Điều khiển video qua cầu nối (chạy được cả khi player nằm trong iframe) -------
  Future<void> _js(String code) async {
    try { await _c?.evaluateJavascript(source: code); } catch (_) {}
  }

  /// Gửi lệnh xuống mọi khung (khung chính + iframe con) qua postMessage.
  void _cmd(String cmd, [double delta = 0]) {
    _js('''(function(){var m={__vf:1,cmd:'$cmd',delta:$delta};
      try{window.postMessage(m,'*');}catch(e){}
      for(var i=0;i<window.frames.length;i++){try{window.frames[i].postMessage(m,'*');}catch(e){}}})();''');
  }

  void _seek(double delta) { _cmd('seek', delta); _bumpBar(); }

  void _togglePlay() {
    _cmd('toggle');
    setState(() => _paused = !_paused);
    _bumpBar();
  }

  /// Đọc vị trí/thời lượng/trạng thái từ `window.__vfState` (do cầu nối gom về).
  Future<void> _syncState() async {
    if (!mounted || _c == null) return;
    try {
      final r = await _c!.evaluateJavascript(source: 'JSON.stringify(window.__vfState||null)');
      final raw = (r ?? '').toString();
      if (raw.isEmpty || raw == 'null') return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final pos = (m['p'] is num) ? (m['p'] as num).toDouble() : 0.0;
      final dur = (m['d'] is num) ? (m['d'] as num).toDouble() : 0.0;
      final paused = m['paused'] == 1;
      final ended = m['ended'] == 1;
      if (mounted) setState(() { _pos = pos; _dur = dur; _paused = paused; });

      // Xem tiếp: seek tới vị trí cũ. Nguồn phim hay reset về 0 sau khi tải, nên
      // ÉP seek NHIỀU LẦN cho tới khi vị trí "ăn" (hoặc thử đủ số lần thì thôi).
      if (!_resumeApplied && dur > 0) {
        if (_resumeTo <= 2 || _resumeTo >= dur - 8) {
          _resumeApplied = true;              // không cần seek
        } else if (pos >= _resumeTo - 4) {
          _resumeApplied = true;              // đã tới đúng chỗ
        } else if (_resumeTries < 8) {
          _resumeTries++;
          _cmd('seekto', _resumeTo);          // seek lại (đè việc nguồn nhảy về 0)
        } else {
          _resumeApplied = true;              // thử đủ rồi, thôi để khỏi kẹt
        }
      }

      // Lưu vị trí đang xem xuống đĩa mỗi ~3 giây (để "Xem tiếp" nhớ chỗ dừng,
      // ít mất khi app bị đóng đột ngột).
      if (dur > 0 && pos > 0) {
        _saveTick++;
        if (_saveTick >= 3) { _saveTick = 0; widget.onPosition?.call(pos, dur); }
      }

      // Hết tập: cờ ended, hoặc chạy tới sát cuối (một số nguồn không bắn ended).
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

  /// Hẹn giờ tự ẩn thanh điều khiển sau [seconds] giây (đặt lại nếu đang hẹn).
  void _armHideBar([int seconds = 3]) {
    _hideT?.cancel();
    _hideT = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => _showBar = false);
    });
  }

  /// Hiện thanh điều khiển rồi tự ẩn sau 3 giây.
  void _bumpBar() {
    _syncState();
    if (!_showBar && mounted) setState(() => _showBar = true);
    _armHideBar();
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
    // Sang tập mới -> xem từ đầu, không seek theo vị trí cũ nữa.
    _resumeTo = 0;
    _resumeApplied = true;
    _saveTick = 0;
    setState(() {
      _idx = i;
      _url = ep.embed;
      _nextIn = null;
      _pos = 0;
      _dur = 0;
      _showBar = true; // đổi tập -> hiện thanh cho thấy đang ở tập nào
    });
    _armHideBar(_introBarSeconds);
    widget.onEpisodeChange(ep);
    _c?.loadUrl(urlRequest: URLRequest(url: WebUri(ep.embed)));
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalEpisodes > widget.episodes.length ? widget.totalEpisodes : widget.episodes.length;
    final epName = widget.episodes.isNotEmpty ? widget.episodes[_idx].name : '';
    // Nhãn tập cho logo góc. Phim lẻ -> để rỗng, logo chỉ hiện tên phim.
    final epLabel = total > 1 ? _epDisplay(epName) : '';
    return Scaffold(
      backgroundColor: Colors.black,
      // KHÔNG bọc SafeArea ở ngoài: phim phải tràn kín màn, không chừa dải đen.
      body: Stack(children: [
        Positioned.fill(child: _webView()),
        // Logo góc kiểu kênh truyền hình: nằm im góc trên-phải suốt cả phim, mờ
        // 40%, sáng rõ khi thanh điều khiển hiện. Các lớp bọc (SafeArea/Align/
        // Padding) không "ăn" chuột, còn ChannelBug tự bọc IgnorePointer, nên bấm
        // vào phim ở vùng góc vẫn ăn bình thường trên PC.
        Positioned.fill(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                // Lề rộng để TV không cắt mất mép (overscan).
                padding: const EdgeInsets.only(top: 16, right: 28),
                child: ChannelBug(
                  movieName: widget.movieName,
                  episodeLabel: epLabel,
                  bright: _showBar,
                ),
              ),
            ),
          ),
        ),
        // Thanh điều khiển của app (remote trên TV + chuột trên PC)
        if (_showBar)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _controlBar(epLabel, total),
          ),
        // Hết tập -> hộp đếm ngược sang tập kế tiếp (nhường chỗ cho thanh điều khiển)
        if (_nextIn != null)
          Positioned(right: 28, bottom: _showBar ? 132 : 28, child: _nextEpisodeBox()),
      ]),
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

  /// Thanh điều khiển do APP vẽ: hiện khi bấm phím trên remote, khi mới mở phim
  /// và khi vừa đổi tập.
  ///
  /// Từ khi phim tràn kín màn (bỏ 2 thanh đen cố định), thanh này gánh luôn nút
  /// Thoát và nút chuyển tập — trước đây chúng nằm trên 2 thanh đó.
  Widget _controlBar(String epLabel, int total) {
    final p = (_dur > 0) ? (_pos / _dur).clamp(0.0, 1.0) : 0.0;
    final multi = widget.episodes.length > 1;
    return Container(
      // Gradient thay khối đen đặc: không cắt ngang hình bằng một đường thẳng.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xF2000000), Color(0x00000000)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 10),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            // Thoát: chuột bấm được trên PC; TV vẫn dùng Back/ESC là chính.
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              label: Text(Platform.isAndroid ? 'Thoát (Back)' : 'Thoát (ESC)',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            if (multi) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Tập trước',
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: _idx > 0 ? () => _goto(_idx - 1) : null,
              ),
              Text('$epLabel / $total',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              IconButton(
                tooltip: 'Tập sau',
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: _idx < widget.episodes.length - 1 ? () => _goto(_idx + 1) : null,
              ),
            ],
            const Spacer(),
            Icon(_paused ? Icons.pause_circle_filled : Icons.play_circle_fill, color: kRed, size: 24),
            const SizedBox(width: 8),
            Text('${_fmt(_pos)} / ${_fmt(_dur)}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: p, minHeight: 5,
              backgroundColor: Colors.white24, color: kRed,
            ),
          ),
          const SizedBox(height: 6),
          const Text('◀ ▶ tua 10 giây   •   ▲ ▼ tua 1 phút   •   OK: tạm dừng   •   Back: thoát',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
        ]),
      ),
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
                // Cầu nối điều khiển: tiêm vào MỌI khung để nút tạm dừng/tua
                // "với" được tới player nằm trong iframe.
                UserScript(
                  source: kPlayerBridgeScript,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
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
