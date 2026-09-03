import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import '../data/hls_source.dart';
import '../data/referer_gate.dart';
import '../data/app_log.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../main.dart' show webViewEnvironment;
import '../models/episode.dart';
import '../models/stream_source.dart';
import '../theme/app_theme.dart';
import 'ad_blocker.dart';
import 'channel_bug.dart';
import '../widgets/tv_focusable.dart';

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
  // GIẤU thanh điều khiển của trang nguồn (JWPlayer): app đã có thanh riêng
  // (pause/tua/chuyển tập), để cả hai là hai thanh chồng nhau rất rối.
  // Dùng CSS thay vì xoá phần tử: JWPlayer vẽ lại thanh thì CSS vẫn áp.
  // Giữ .jw-display (nút play giữa màn + bấm vào hình để tạm dừng vẫn chạy).
  try {
    if (!document.getElementById('__vfHideCtl')) {
      var st = document.createElement('style');
      st.id = '__vfHideCtl';
      st.textContent = '.jw-controlbar,.jw-nextup-container,.jw-rightclick,' +
        '.jw-settings-menu{display:none !important;}' +
        'video::-webkit-media-controls-enclosure{display:none !important;}';
      (document.head || document.documentElement).appendChild(st);
    }
  } catch (e) {}
  // BẮN PHÍM VỀ APP. Trên Windows, WebView2 chiếm tiêu điểm bàn phím (nhất là
  // sau khi bấm chuột vào hình) nên Flutter KHÔNG nhận được phím nào -> ESC,
  // mũi tên, Space đều chết. Trang bắt keydown rồi đẩy ra console; app đọc lại
  // trong onConsoleMessage (đường này nối thẳng vào WebView2, không cần tiêm
  // script nên chắc chắn chạy — khác với callHandler vốn cần plugin script mà
  // plugin Windows 0.6.0 không bao giờ tiêm).
  // Chỉ NGHE ở pha capture, KHÔNG preventDefault -> không phá phím của trang.
  try {
    window.addEventListener('keydown', function(e){
      try { console.log('VFKEY:' + e.key); } catch(err){}
    }, true);
  } catch (e) {}
  function vid(){ return document.querySelector('video'); }
  function jw(){ try { return (typeof jwplayer==='function') ? jwplayer() : null; } catch(e){ return null; } }
  function act(cmd, delta){
    try {
      var v = vid();
      // __vfUserPaused: ghi lại việc người dùng CHỦ ĐỘNG tạm dừng, để script ép
      // tự phát biết mà thôi, không bật lại phim sau lưng người dùng.
      if (cmd==='toggle'){
        if (v){ if(v.paused){ window.__vfUserPaused=0; v.play(); } else { window.__vfUserPaused=1; v.pause(); } return; }
        var p=jw();
        if(p&&p.getState){
          if(p.getState()==='playing'){ window.__vfUserPaused=1; p.pause(); }
          else { window.__vfUserPaused=0; p.play(true); }
        }
      } else if (cmd==='play'){
        window.__vfUserPaused=0;
        if (v){ v.play(); return; } var p2=jw(); if(p2&&p2.play) p2.play(true);
      } else if (cmd==='pause'){
        window.__vfUserPaused=1;
        if (v){ v.pause(); return; } var p3=jw(); if(p3&&p3.pause) p3.pause();
      } else if (cmd==='seek'){
        if (v && isFinite(v.duration)){ v.currentTime=Math.max(0,Math.min(v.duration, v.currentTime+delta)); return; }
        var p4=jw(); if(p4&&p4.getPosition){ p4.seek(Math.max(0, p4.getPosition()+delta)); }
      } else if (cmd==='seekto'){
        if (v && isFinite(v.duration)){ v.currentTime=Math.max(0,Math.min(v.duration, delta)); return; }
        var p5=jw(); if(p5&&p5.seek){ p5.seek(delta); }
      } else if (cmd==='volume'){
        // delta = 0..1 (tuyệt đối). 0 thì tắt tiếng luôn cho khỏi còn tiếng rít.
        var vv = Math.max(0, Math.min(1, delta));
        if (v){ v.muted = (vv<=0); v.volume = vv; return; }
        var p6=jw();
        if (p6&&p6.setVolume){ try{ p6.setMute(vv<=0); }catch(e2){} p6.setVolume(Math.round(vv*100)); }
      } else if (cmd==='mute'){
        if (v){ v.muted = !v.muted; return; }
        var p7=jw(); if(p7&&p7.setMute){ p7.setMute(!p7.getMute()); }
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
    // Nguồn dùng <video controls> thuần (không qua JWPlayer): tắt bộ nút gốc
    // của trình duyệt. Đặt trong nhịp lặp vì video có thể xuất hiện muộn.
    try { if (v && v.controls) v.controls = false; } catch(e){}
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

  /// Mọi lựa chọn phát của phim này (nguồn + loại tiếng). Rỗng = chỉ có một
  /// nguồn, nút "Nguồn" không hiện.
  final List<StreamSource> sources;
  final int sourceIndex;

  /// Báo về khi người xem đổi sang nguồn khác (để lưu đúng nguồn đang xem).
  final void Function(StreamSource src, Episode ep)? onSourceChange;

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
    this.sources = const [],
    this.sourceIndex = 0,
    this.onSourceChange,
  });
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  InAppWebViewController? _c;
  late int _idx;
  /// Trang embed đang xem. Khởi tạo rỗng chứ KHÔNG `late`: [_setEmbedUrl] đọc
  /// giá trị cũ để biết có phải đổi trang hay không, kể cả ở lần gọi đầu tiên.
  String _url = '';

  /// Link mà WebView bắt đầu nạp gần nhất — dùng để biết cổng Referer có dẫn
  /// được sang trang phim hay không.
  String _lastNavStart = '';
  Timer? _gateT;

  /// Link THẬT đưa cho WebView. Thường bằng [_url], nhưng với nguồn chặn
  /// hotlink thì là trang cổng nội bộ tự nhảy sang [_url] để trình duyệt sinh
  /// Referer (xem [RefererGate]). null = đang dựng cổng, chưa nạp được.
  String? _navUrl;
  late int _srcIdx;          // nguồn đang phát (chỉ số trong widget.sources)
  bool _srcPanel = false;    // đang mở bảng chọn nguồn

  /// Trang nguồn đã tải xong ít nhất một lần. Trước mốc này thì chuyển hướng
  /// khung chính là chuyện bình thường của trang; sau mốc này là quảng cáo cướp.
  bool _pageLoadedOnce = false;

  /// Trang của nguồn tải hỏng (chỉ tính khung chính). Có giá trị thì hiện bảng
  /// báo lỗi thay vì để người xem ngồi nhìn màn hình đen không biết chuyện gì.
  String? _webError;

  // ---- Trình phát native (chỉ dùng khi có link m3u8) ----
  // Có link video trực tiếp thì phát thẳng, khỏi qua trang embed: không quảng
  // cáo, không cần cầu nối JS, vị trí xem đọc chính xác từng giây.
  Player? _np;
  VideoController? _nvc;
  final List<StreamSubscription> _nsubs = [];
  bool _native = false;      // đang phát bằng player native hay WebView
  bool _hlsFailed = false;   // hls lỗi -> đã rơi về embed, đừng thử lại vòng vo
  double _pendingSeek = 0;   // giây cần tua tới NGAY KHI player sẵn sàng
  int _seekTries = 0;
  double _adsSkipped = 0;    // số giây quảng cáo đã cắt khỏi luồng

  /// Bật trên Windows và Android/TV. Có link m3u8 là phát thẳng bằng trình phát
  /// của app: bỏ được trang embed, và quan trọng hơn là CẮT ĐƯỢC quảng cáo chèn
  /// trong luồng — thứ mà trang embed của nguồn không cho bỏ qua.
  bool _canNative(Episode ep) =>
      (Platform.isWindows || Platform.isAndroid || Platform.isIOS) &&
      ep.m3u8.isNotEmpty &&
      !_hlsFailed;

  Episode? get _curEp =>
      (_idx >= 0 && _idx < _eps.length) ? _eps[_idx] : null;

  /// Danh sách tập của NGUỒN ĐANG PHÁT. Không truyền sources thì dùng danh sách
  /// truyền thẳng vào như trước.
  List<Episode> get _eps => widget.sources.isEmpty
      ? widget.episodes
      : widget.sources[_srcIdx].episodes;

  // Thanh điều khiển của APP (remote không bấm được nút bên trong trang web).
  bool _showBar = false;      // đang hiện thanh điều khiển
  bool _paused = false;       // trạng thái phát
  double _pos = 0, _dur = 0;  // vị trí / tổng thời lượng (giây)

  // Âm lượng (0..1). Thanh của trang nguồn đã bị giấu nên đây là chỗ chỉnh tiếng
  // duy nhất trong app.
  double _vol = 1.0;
  /// Lúc người dùng vừa tự chỉnh tiếng — trong ~1 giây sau đó KHÔNG lấy mức từ
  /// trang về nữa, kẻo nhịp đọc mỗi giây kéo con trượt giật về chỗ cũ khi đang kéo.
  DateTime _lastVolChange = DateTime.fromMillisecondsSinceEpoch(0);
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
    _srcIdx = (widget.sources.isEmpty ||
            widget.sourceIndex < 0 ||
            widget.sourceIndex >= widget.sources.length)
        ? 0
        : widget.sourceIndex;
    _setEmbedUrl(widget.embedUrl);
    // Giữ màn hình sáng suốt lúc ở trong trình phát. media_kit chỉ giữ cho
    // trình phát native CỦA NÓ, nên đường WebView (nguồn nguonc) bị máy tự tắt
    // màn hình giữa chừng khi lâu không chạm. Buộc theo MÀN HÌNH TRÌNH PHÁT
    // thay vì theo trạng thái đang phát: đơn giản, và trả lại ở dispose.
    WakelockPlus.enable().catchError((_) {});
    _resumeTo = widget.startPosition;
    _resumeApplied = widget.startPosition <= 2;
    // ESC (PC) / phím remote (TV)
    HardwareKeyboard.instance.addHandler(_onKey);
    // Theo dõi vòng đời app: khi bị đưa xuống nền / đóng đột ngột thì lưu ngay
    // vị trí đang xem (dispose có thể không kịp chạy khi hệ thống kill app).
    WidgetsBinding.instance.addObserver(this);
    // Cập nhật vị trí phát để vẽ thanh tiến trình (đường WebView).
    _pollT = Timer.periodic(const Duration(seconds: 1), (_) => _syncState());
    // Có link m3u8 -> phát thẳng bằng player native.
    final ep0 = _curEp;
    vlog('player', 'mo trinh phat: platform=${Platform.operatingSystem} '
        'co_m3u8=${ep0?.m3u8.isNotEmpty ?? false} '
        'co_embed=${ep0?.embed.isNotEmpty ?? false} '
        'chon_native=${ep0 != null && _canNative(ep0)}');
    if (ep0 != null && _canNative(ep0)) {
      _native = true;
      _openNative(ep0.m3u8, widget.startPosition);
    } else {
      vlog('player', 'dung WebView voi url=$_url');
    }
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
    _closeNative();
    HlsPreparer.shutdown(); // tắt máy chủ playlist nội bộ khi rời trình phát
    _gateT?.cancel();
    RefererGate.shutdown(); // và cả cổng Referer
    WakelockPlus.disable().catchError((_) {}); // cho màn hình được tắt lại
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

  // ================= Trình phát native (m3u8) =================

  /// Mở link m3u8 bằng player native và bám vào các luồng trạng thái của nó.
  /// Khác hẳn đường WebView: không phải dò bằng JS mỗi giây, player bắn thẳng
  /// vị trí / thời lượng / trạng thái phát ra.
  Future<void> _openNative(String url, double startAt) async {
    _closeNative();
    // Box Android yếu (vd KICKPI) phát HLS 1080p hay GIẬT vì mạng tải không kịp
    // libmpv. Tăng bộ đệm đọc trước để chịu được mạng phập phù. Windows mặc định
    // 32MB đã đủ nên không đụng (khỏi tốn RAM vô ích).
    final mobile = Platform.isAndroid || Platform.isIOS;
    final p = mobile
        ? Player(configuration: const PlayerConfiguration(bufferSize: 96 * 1024 * 1024))
        : Player();
    final c = VideoController(p);
    _np = p;
    _nvc = c;

    _nsubs.add(p.stream.position.listen((d) {
      if (!mounted || !_native) return;
      final pos = d.inMilliseconds / 1000.0;
      setState(() => _pos = pos);
      // Lưu vị trí xuống đĩa mỗi ~3 giây, giống đường WebView.
      if (_dur > 0 && pos > 0) {
        _saveTick++;
        if (_saveTick >= 3) {
          _saveTick = 0;
          widget.onPosition?.call(pos, _dur);
        }
      }
    }));
    _nsubs.add(p.stream.duration.listen((d) {
      if (!mounted || !_native) return;
      final dur = d.inMilliseconds / 1000.0;
      setState(() => _dur = dur);
      // Tua ĐÚNG LÚC NÀY chứ không phải ngay sau open(): với HLS, mpv nuốt lệnh
      // tua phát ra trước khi nó đọc xong playlist — đo thật thì phim vẫn nằm ở
      // giây thứ 4 thay vì nhảy tới phút 10.
      _applyPendingSeek();
    }));
    _nsubs.add(p.stream.playing.listen((v) {
      if (!mounted || !_native) return;
      setState(() => _paused = !v);
    }));
    _nsubs.add(p.stream.completed.listen((v) {
      if (!mounted || !_native || !v) return;
      _armAutoNext();
    }));
    // Host m3u8 hay đổi/hết hạn -> rơi về link embed thay vì đứng hình.
    _nsubs.add(p.stream.error.listen((e) {
      vlog('player', 'mpv bao loi: $e');
      if (!mounted || !_native) return;
      _fallbackToEmbed(e);
    }));

    _pendingSeek = startAt;
    _seekTries = 0;
    // Bỏ quảng cáo chèn trong luồng trước khi phát. Quảng cáo nằm ngay trong
    // playlist nên không có nút bỏ qua; lọc hỏng thì dùng link gốc như cũ.
    String toPlay = url;
    try {
      final cleaned = await HlsPreparer().prepare(url);
      vlog('ads', cleaned == null
          ? 'KHONG loc duoc quang cao -> phat link goc'
          : 'da cat ${cleaned.removedSegments} phan doan '
              '= ${cleaned.removedSeconds.toStringAsFixed(1)}s');
      if (cleaned != null && mounted && _native) {
        toPlay = cleaned.url;
        _adsSkipped = cleaned.removedSeconds;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kRed,
          duration: const Duration(seconds: 3),
          content: Text('Đã cắt ${_adsSkipped.round()} giây quảng cáo '
              'chèn trong phim'),
        ));
      }
    } catch (e) {
      vlog('ads', 'loi khi loc quang cao: $e');
    }
    if (!mounted || !_native || _np != p) return; // đã đổi tập/nguồn lúc đang lọc

    try {
      await p.open(Media(toPlay), play: true);
      await p.setVolume(_vol * 100);
      // Đọc trước theo THỜI GIAN: giữ sẵn ~30s phim để một nhịp mạng chậm không
      // làm khựng hình. Chỉ box Android yếu mới cần; lỗi thì bỏ qua (không sống
      // chết vì tinh chỉnh này).
      if (mobile) {
        try {
          final plat = p.platform;
          if (plat is NativePlayer) {
            await plat.setProperty('cache', 'yes');
            await plat.setProperty('cache-secs', '30');
            await plat.setProperty('demuxer-readahead-secs', '30');
          }
        } catch (e) {
          vlog('player', 'khong dat duoc cache mpv: $e');
        }
      }
      _resumeApplied = true; // đường native tự lo bằng _applyPendingSeek
      vlog('player', 'da mo native OK: ${toPlay == url ? "link goc" : "playlist da loc"}');
    } catch (e) {
      vlog('player', 'MO NATIVE LOI: $e');
      if (mounted) _fallbackToEmbed('$e');
    }
  }

  /// Tua tới chỗ đang xem dở, và KIỂM LẠI xem có tới nơi thật không.
  /// mpv thỉnh thoảng vẫn nuốt lệnh tua đầu tiên trên luồng mạng, nên thử tối đa
  /// 3 lần rồi thôi — thà phát từ đầu còn hơn tua loạn cả buổi.
  void _applyPendingSeek() {
    final p = _np;
    if (p == null || !_native) return;
    final target = _pendingSeek;
    if (target <= 2 || _dur <= 0) return;
    if (target >= _dur - 5) {
      _pendingSeek = 0; // chỗ lưu đã quá cuối phim -> bỏ, xem từ đầu
      return;
    }
    _seekTries++;
    p.seek(Duration(milliseconds: (target * 1000).round()));
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || !_native || _pendingSeek <= 2) return;
      // Tính là TỚI NƠI khi đã ở target trở đi: HLS nhảy theo khung hình khoá
      // nên hay quá đà chục giây, đo thật thấy tua 600 vào 626. Thứ cần bắt là
      // lệnh tua bị NUỐT (vẫn nằm ở đầu phim), chứ không phải quá đà.
      if (_pos >= target - 10) {
        _pendingSeek = 0;
        return;
      }
      if (_seekTries >= 3) {
        _pendingSeek = 0;
        return;
      }
      _applyPendingSeek();
    });
  }

  void _closeNative() {
    _pendingSeek = 0;
    _seekTries = 0;
    _adsSkipped = 0;
    for (final s in _nsubs) {
      s.cancel();
    }
    _nsubs.clear();
    _np?.dispose();
    _np = null;
    _nvc = null;
  }

  /// hls hỏng -> quay về trang embed của chính nguồn đó, giữ nguyên chỗ đang xem.
  void _fallbackToEmbed(String why) {
    vlog('player', 'roi ve embed vi: $why');
    if (_hlsFailed) return;
    final ep = _curEp;
    if (ep == null || ep.embed.isEmpty) return;
    final keep = _pos;
    _hlsFailed = true;
    _closeNative();
    setState(() => _native = false);
    _setEmbedUrl(ep.embed);
    _resumeTo = keep;
    _resumeApplied = keep <= 2;
    _resumeTries = 0;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      backgroundColor: kRed,
      content: Text('Link phát trực tiếp lỗi — chuyển sang trang nguồn'),
    ));
  }

  /// Khung hình của player native. Dùng lại đúng thanh điều khiển của app nên
  /// tắt hết điều khiển sẵn có của media_kit.
  Widget _nativeVideo() {
    final c = _nvc;
    if (c == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: kRed)),
      );
    }
    return Video(
      controller: c,
      controls: NoVideoControls,
      fit: BoxFit.contain,
      fill: Colors.black,
    );
  }

  // ------- Điều khiển video qua cầu nối (chạy được cả khi player nằm trong iframe) -------
  Future<void> _js(String code) async {
    try { await _c?.evaluateJavascript(source: code); } catch (_) {}
  }

  /// Gửi lệnh xuống mọi khung (khung chính + iframe con) qua postMessage.
  /// Đang phát native thì đi thẳng vào player, khỏi qua cầu nối JS.
  void _cmd(String cmd, [double delta = 0]) {
    final np = _np;
    if (_native && np != null) {
      switch (cmd) {
        case 'toggle':
          np.playOrPause();
        case 'seek':
          np.seek(Duration(milliseconds: ((_pos + delta) * 1000).round().clamp(0, 1 << 31)));
        case 'seekto':
          np.seek(Duration(milliseconds: (delta * 1000).round().clamp(0, 1 << 31)));
        case 'volume':
          np.setVolume(delta * 100);
      }
      return;
    }
    _js('''(function(){var m={__vf:1,cmd:'$cmd',delta:$delta};
      try{window.postMessage(m,'*');}catch(e){}
      for(var i=0;i<window.frames.length;i++){try{window.frames[i].postMessage(m,'*');}catch(e){}}})();''');
  }

  void _seek(double delta) { _cmd('seek', delta); _bumpBar(); }

  /// Đặt mức tiếng (0..1). Cập nhật UI ngay rồi mới gửi lệnh xuống trang, để con
  /// trượt không bị trễ theo độ chậm của WebView.
  void _setVolume(double v) {
    final nv = v.clamp(0.0, 1.0);
    _lastVolChange = DateTime.now();
    if (mounted) setState(() => _vol = nv);
    _cmd('volume', nv);
    _bumpBar();
  }

  /// Bấm nút loa: đang có tiếng thì tắt, đang tắt thì mở lại mức vừa phải.
  void _toggleMute() => _setVolume(_vol > 0 ? 0 : 0.7);

  void _togglePlay() {
    _cmd('toggle');
    setState(() => _paused = !_paused);
    _bumpBar();
  }

  /// JS đọc trạng thái video: ưu tiên đọc THẲNG thẻ <video>/jwplayer ở khung
  /// chính (nguồn đang dùng đặt video ở đó), chỉ rơi về `window.__vfState`
  /// (do cầu nối gom từ iframe về) khi khung chính không có video.
  static const String _kReadStateJs = r'''JSON.stringify((function(){
    try {
      var v = document.querySelector('video');
      if (v && isFinite(v.duration) && v.duration > 0)
        return {p:v.currentTime, d:v.duration, paused:v.paused?1:0, ended:v.ended?1:0,
                vol: v.muted ? 0 : v.volume};
      if (typeof jwplayer === 'function') {
        var p = jwplayer();
        if (p && p.getDuration && p.getDuration() > 0) {
          var st = p.getState();
          return {p:p.getPosition(), d:p.getDuration(), paused:(st==='playing')?0:1, ended:(st==='complete')?1:0,
                  vol: (p.getMute && p.getMute()) ? 0 : ((p.getVolume ? p.getVolume() : 100) / 100)};
        }
      }
    } catch (e) {}
    return window.__vfState || null;
  })())''';

  /// Đọc vị trí/thời lượng/trạng thái video, mỗi giây một lần.
  Future<void> _syncState() async {
    // Native tự bắn trạng thái qua stream, không phải dò bằng JS.
    if (_native) return;
    if (!mounted || _c == null) return;
    try {
      // TỰ LÀNH: cầu nối có thể chưa được tiêm — onLoadStop và initialUserScripts
      // đều đã tỏ ra không đáng tin trên Windows (initialUserScripts thì plugin
      // 0.6.0 nhận rồi bỏ quên, không bao giờ tiêm). Nên mỗi nhịp kiểm cờ
      // __vfBridge, thiếu thì tiêm lại ngay tại đây. Tiêm lại nhiều lần vô hại
      // (cầu nối có guard); kAutoPlayScript chỉ tiêm kèm lần đầu vì nó không có
      // guard, tiêm lặp sẽ chồng setInterval.
      // Dùng JSON.stringify chứ không trả số/boolean trần: evaluateJavascript mỗi
      // nền tảng trả một kiểu (số, chuỗi, chuỗi có kèm dấu nháy), so sánh '1' hụt
      // là tưởng cầu nối chưa có -> TIÊM LẠI MỖI GIÂY, mà mỗi lần tiêm lại là một
      // interval ép-tự-phát mới đè lên lệnh tạm dừng của người dùng.
      final probe = (await _c!.evaluateJavascript(source: 'JSON.stringify(window.__vfBridge===1)'))
          .toString();
      if (!probe.contains('true')) {
        // kAntiAdUserScript PHẢI tiêm ở đây nữa: trên Windows plugin nhận
        // initialUserScripts rồi bỏ quên, nên trước bản này nó CHƯA BAO GIỜ chạy
        // -> window.open không bị chặn, trang phim bị quảng cáo đá đi mất.
        await _c!.evaluateJavascript(source: kAntiAdUserScript);
        await _c!.evaluateJavascript(source: kPlayerBridgeScript);
        await _c!.evaluateJavascript(source: kAutoPlayScript);
        return; // nhịp sau đọc được ngay
      }
      final r = await _c!.evaluateJavascript(source: _kReadStateJs);
      // Nới cách giải mã: tuỳ nền tảng, evaluateJavascript trả Map sẵn, chuỗi
      // JSON, hoặc chuỗi JSON bị bọc thêm một lớp nữa.
      dynamic decoded = r;
      for (var i = 0; i < 2 && decoded is String; i++) {
        final s = decoded.trim();
        if (s.isEmpty || s == 'null') return;
        decoded = jsonDecode(s);
      }
      if (decoded is! Map) return;
      final m = decoded.cast<String, dynamic>();
      final pos = (m['p'] is num) ? (m['p'] as num).toDouble() : 0.0;
      final dur = (m['d'] is num) ? (m['d'] as num).toDouble() : 0.0;
      final paused = m['paused'] == 1;
      final ended = m['ended'] == 1;
      // Mức tiếng: bỏ qua nếu người dùng vừa chỉnh (xem _lastVolChange).
      final vol = (m['vol'] is num) ? (m['vol'] as num).toDouble().clamp(0.0, 1.0) : null;
      final takeVol = vol != null &&
          DateTime.now().difference(_lastVolChange).inMilliseconds > 1000;
      if (mounted) {
        setState(() {
          _pos = pos;
          _dur = dur;
          _paused = paused;
          if (takeVol) _vol = vol;
        });
      }

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
    if (_idx + 1 >= _eps.length) return; // đang ở tập cuối
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

  /// Chuột động là hiện thanh điều khiển (giống mọi trình phát video). Cần thiết
  /// vì từ khi phim tràn kín màn, không còn thanh cố định nào: người dùng chuột
  /// mà không bấm phím thì sẽ không có cách nào gọi nút Thoát / chuyển tập ra.
  /// Có chặn nhịp: chuột động cả chục lần mỗi giây, không thể setState từng lần.
  DateTime _lastHover = DateTime.fromMillisecondsSinceEpoch(0);
  void _onHover() {
    final now = DateTime.now();
    if (now.difference(_lastHover).inMilliseconds < 400) return;
    _lastHover = now;
    _bumpBar();
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

  /// Lúc Flutter xử lý phím gần nhất — để phím do trang bắn về không bị xử lý
  /// lần hai (tua 10 giây thành 20 giây) khi cả hai đường cùng nhận được.
  DateTime _lastFlutterKey = DateTime.fromMillisecondsSinceEpoch(0);

  /// Đã bắt đầu thoát trình phát. ESC tới được app bằng HAI đường (Flutter và
  /// trang web bắn qua console), đường console tới chậm hơn nên lọt qua cửa chặn
  /// theo thời gian -> pop hai lần -> thoát luôn cả trang chi tiết, rơi về trang
  /// chủ. Cờ này chốt lại: đã pop một lần thì không nhận phím nào nữa.
  bool _exiting = false;

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    _lastFlutterKey = DateTime.now();
    return _handleKey(e.logicalKey);
  }

  /// Phím do TRANG WEB bắt được rồi bắn về qua console (xem kPlayerBridgeScript).
  /// Ánh xạ `KeyboardEvent.key` sang phím của Flutter rồi dùng CHUNG một hàm xử
  /// lý, để hai đường không bao giờ lệch hành vi nhau.
  static const Map<String, LogicalKeyboardKey> _kPageKeyMap = {
    'Escape': LogicalKeyboardKey.escape,
    'ArrowLeft': LogicalKeyboardKey.arrowLeft,
    'ArrowRight': LogicalKeyboardKey.arrowRight,
    'ArrowUp': LogicalKeyboardKey.arrowUp,
    'ArrowDown': LogicalKeyboardKey.arrowDown,
    ' ': LogicalKeyboardKey.space,
    'Enter': LogicalKeyboardKey.enter,
    'MediaPlayPause': LogicalKeyboardKey.mediaPlayPause,
    'MediaTrackNext': LogicalKeyboardKey.mediaTrackNext,
    'MediaTrackPrevious': LogicalKeyboardKey.mediaTrackPrevious,
  };

  void _handlePageKey(String key) {
    if (DateTime.now().difference(_lastFlutterKey).inMilliseconds < 300) return;
    final k = _kPageKeyMap[key];
    if (k != null) {
      _handleKey(k);
    } else {
      _bumpBar(); // phím lạ -> ít nhất cũng gọi thanh điều khiển ra
    }
  }

  /// Thoát trình phát. Mọi đường thoát (ESC, nút Thoát) phải đi qua đây để chốt
  /// cờ TRƯỚC khi pop — ESC còn tới bằng đường console chậm hơn, không chốt là
  /// nó pop tiếp trang chi tiết và rơi thẳng về trang chủ.
  void _exit() {
    if (_exiting || !mounted || !Navigator.canPop(context)) return;
    // Cũng phải kiểm isCurrent như các màn khác: nếu có màn khác đang phủ lên
    // trình phát thì phím ESC là của màn đó, không phải để thoát phim.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _exiting = true;
    Navigator.pop(context);
  }

  bool _handleKey(LogicalKeyboardKey k) {
    if (_exiting) return true; // đang thoát -> nuốt hết phím, không pop lần hai
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
        _exit();
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
    // Phím KHÔNG dùng tới (Menu, Info, phím màu... trên remote) vẫn cho hiện
    // thanh điều khiển: trên TV đó là cách gọi thanh ra mà không làm gì khác.
    _bumpBar();
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
    if (i < 0 || i >= _eps.length) return;
    final ep = _eps[i];
    // Sang tập mới -> xoá mọi trạng thái "hết tập" của tập cũ.
    _nextT?.cancel();
    _nextT = null;
    _nextBlocked = false;
    _hlsFailed = false; // tập trước hỏng link thẳng không có nghĩa tập này hỏng
    // Sang tập mới -> xem từ đầu, không seek theo vị trí cũ nữa.
    _resumeTo = 0;
    _resumeApplied = true;
    _saveTick = 0;
    setState(() {
      _idx = i;
      _nextIn = null;
      _pos = 0;
      _dur = 0;
      _showBar = true; // đổi tập -> hiện thanh cho thấy đang ở tập nào
    });
    _armHideBar(_introBarSeconds);
    widget.onEpisodeChange(ep);
    _loadEpisode(ep, 0);
  }

  /// Đặt trang embed cần xem, rồi tính link thật để nạp.
  ///
  /// Nguồn chặn hotlink (streamc.xyz) đòi có Referer, mà header Referer tự đặt
  /// thì WebView2 trên Windows vứt bỏ — nên phải đi vòng qua [RefererGate] để
  /// chính trình duyệt sinh Referer. Chi tiết nằm trong tài liệu của lớp đó.
  ///
  /// [viaController] = true khi WebView đã có sẵn (đổi tập): nạp đè bằng
  /// controller cho nhanh, khỏi dựng lại cả WebView.
  Future<void> _setEmbedUrl(String url, {bool viaController = false}) async {
    if (_url != url) {
      _url = url;
      if (!viaController) {
        _navUrl = null; // đừng để WebView kịp nạp lại link của tập cũ
        if (mounted) setState(() {});
      }
    }
    final nav = await RefererGate.urlFor(url);
    if (!mounted || _url != url) return; // đã đổi tập/nguồn trong lúc chờ
    vlog('embed', 'mo trang embed: $url' + (nav == url ? '' : ' (qua cong $nav)'));
    if (viaController && _c != null) {
      _navUrl = nav;
      await _c!.loadUrl(urlRequest: URLRequest(url: WebUri(nav)));
    } else {
      setState(() => _navUrl = nav);
    }
    _armGateWatchdog(url, nav);
  }

  /// Lưới an toàn cho cổng Referer: nếu sau vài giây WebView vẫn còn nằm ở
  /// trang cổng (chưa nhảy được sang trang phim) thì nạp thẳng link gốc như
  /// cách cũ. Thà dính lại lỗi chặn hotlink còn hơn treo ở trang trắng — và
  /// dòng nhật ký ở đây cho biết nền tảng nào đi được đường nào.
  void _armGateWatchdog(String target, String nav) {
    _gateT?.cancel();
    if (nav == target) return; // không qua cổng thì không phải canh
    _gateT = Timer(const Duration(seconds: 8), () {
      if (!mounted || _url != target) return;
      if (!RefererGate.isGateUrl(_lastNavStart)) return; // đã sang trang phim
      vlog('embed', 'cong khong dan sang trang phim sau 8s -> nap thang $target');
      _navUrl = target;
      _c?.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
    });
  }

  /// Nạp một tập: ưu tiên link m3u8 (player native), không có thì trang embed.
  void _loadEpisode(Episode ep, double startAt) {
    _pageLoadedOnce = false; // trang mới, cho phép nó tự chuyển hướng lúc đầu
    if (_canNative(ep)) {
      if (!_native) setState(() => _native = true);
      _openNative(ep.m3u8, startAt);
      return;
    }
    if (_native) {
      _closeNative();
      setState(() => _native = false);
    }
    _setEmbedUrl(ep.embed, viaController: true);
  }

  /// Đổi sang nguồn khác, GIỮ NGUYÊN tập và vị trí đang xem.
  ///
  /// Hai nguồn đánh số tập khác nhau nên tập tương ứng tìm theo SỐ tập. Không
  /// có tập đó bên kia thì báo và ở lại nguồn cũ — thà báo còn hơn phát nhầm.
  void _switchSource(int i) {
    if (i < 0 || i >= widget.sources.length) return;
    setState(() => _srcPanel = false);
    if (i == _srcIdx) return;

    final from = widget.sources[_srcIdx];
    final to = widget.sources[i];
    final j = matchEpisodeIndex(from.episodes, _idx, to.episodes);
    if (j == null) {
      final epName = (_idx < from.episodes.length) ? from.episodes[_idx].name : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kRed,
        content: Text('Nguồn "${to.label}" chưa có $epName — vẫn giữ nguồn cũ'),
      ));
      return;
    }

    final ep = to.episodes[j];
    // Xem tiếp đúng chỗ đang dở ở nguồn mới.
    final keep = _pos;
    _nextT?.cancel();
    _nextT = null;
    _nextBlocked = false;
    _resumeTo = keep;
    _resumeApplied = keep <= 2;
    _resumeTries = 0;
    _saveTick = 0;
    setState(() {
      _srcIdx = i;
      _idx = j;
      _nextIn = null;
      _pos = keep;
      _dur = 0;
      _showBar = true;
    });
    _armHideBar(_introBarSeconds);
    widget.onSourceChange?.call(to, ep);
    // Đổi nguồn có thể đổi luôn cả kiểu phát (hls <-> embed).
    _hlsFailed = false; // nguồn mới -> cho phép thử lại đường hls
    _loadEpisode(ep, keep);
  }

  /// Bảng chọn nguồn: kiểu bảng của TvFilterBar, D-pad bấm được.
  /// Bảng báo khi trang phát của nguồn không mở được.
  ///
  /// Trước đây gặp cảnh này là màn hình đen câm, không biết hỏng gì cũng chẳng
  /// làm gì được. Nguồn khác thường vẫn phát bình thường nên lối thoát tốt nhất
  /// là mời đổi nguồn ngay tại đây.
  /// Sau khi trang embed của nguonc tải xong, đợi nó chạy hết rồi ghi lại
  /// trạng thái. Không có bước này thì lỗi trên iPad chỉ còn nước đoán, vì màn
  /// hình chỉ hiện một câu chung chung của trang.
  void _probeNguoncPage(InAppWebViewController c) {
    if (!RefererGate.needsGate(_url)) return;
    Future.delayed(const Duration(seconds: 7), () async {
      if (!mounted) return;
      try {
        final r = await c.evaluateJavascript(source: _kNguoncProbeJs);
        vlog('embed', 'trang thai trang nguonc: $r');
      } catch (e) {
        vlog('embed', 'khong doc duoc trang thai trang nguonc: $e');
      }
    });
  }

  Widget _webErrorPanel() {
    final coNguonKhac = widget.sources.length > 1;
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: kAmber, size: 48),
          const SizedBox(height: 12),
          const Text('Không mở được trang phát của nguồn này',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(_webError ?? '',
                textAlign: TextAlign.center,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 12, children: [
            FocusHighlight(
              scale: 1.0,
              onPressed: () {
                setState(() => _webError = null);
                _setEmbedUrl(_url, viaController: true);
              },
              builder: (f) => _errBtn('Thử lại', f, dam: false),
            ),
            if (coNguonKhac)
              FocusHighlight(
                scale: 1.0,
                autofocus: true,
                onPressed: () => setState(() { _webError = null; _srcPanel = true; }),
                builder: (f) => _errBtn('Đổi nguồn khác', f, dam: true),
              ),
            FocusHighlight(
              scale: 1.0,
              onPressed: _exit,
              builder: (f) => _errBtn('Thoát', f, dam: false),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _errBtn(String label, bool focused, {required bool dam}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: dam ? kRed : kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: focused ? kAmber : Colors.transparent, width: 2),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );

  Widget _sourcePanel() => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _srcPanel = false),
          child: Container(
            color: const Color(0xCC000000),
            alignment: Alignment.center,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Chọn nguồn / loại tiếng',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Đổi nguồn vẫn giữ đúng tập và chỗ đang xem',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 14),
                for (int i = 0; i < widget.sources.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SourceRow(
                      src: widget.sources[i],
                      selected: i == _srcIdx,
                      autofocus: i == _srcIdx,
                      onPressed: () => _switchSource(i),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final total = widget.totalEpisodes > _eps.length ? widget.totalEpisodes : _eps.length;
    final epName = (_eps.isNotEmpty && _idx < _eps.length) ? _eps[_idx].name : '';
    // Nhãn tập cho logo góc. Phim lẻ -> để rỗng, logo chỉ hiện tên phim.
    final epLabel = total > 1 ? _epDisplay(epName) : '';
    return Scaffold(
      backgroundColor: Colors.black,
      // KHÔNG bọc SafeArea ở ngoài: phim phải tràn kín màn, không chừa dải đen.
      // MouseRegion opaque:false -> chỉ NGHE chuột đi qua, không chặn cú bấm
      // xuống WebView (trang nguồn vẫn bấm được như cũ trên PC).
      body: MouseRegion(
        opaque: false,
        onHover: (_) => _onHover(),
        child: Stack(children: [
        Positioned.fill(child: _native ? _nativeVideo() : _webView()),
        // BẤM VÀO PHIM để tạm dừng/phát như trình phát thường. Lớp này nằm DƯỚI
        // thanh điều khiển, bảng chọn nguồn và hộp báo lỗi (chúng ở SAU trong
        // Stack nên được bấm trước — nút vẫn ăn), chỉ bắt cú bấm vào vùng phim.
        //
        // ⚠️ KHÔNG phủ suốt trên máy CẢM ỨNG khi đang xem qua TRANG NHÚNG: trang
        // có nút bấm của riêng nó, mà iOS thì CHẶN tự phát (`play()` do script
        // gọi bị từ chối, log ghi "AbortError: The operation was aborted") nên
        // người xem BUỘC phải chạm tay vào nút Phát của trang. Lớp phủ nuốt mất
        // cú chạm đó -> thấy nút Phát mà bấm không được, phim quay mãi.
        if (_native ? !Platform.isAndroid : _dungChuot)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
            ),
          )
        // Máy cảm ứng + trang nhúng: chỉ chắn khi thanh điều khiển ĐANG ẨN, và
        // chỉ để GỌI THANH RA — vì không có chuột để rê, không có bàn phím, nên
        // đây là đường duy nhất lấy lại nút thoát/đổi tập. Thanh đang hiện thì
        // thả cú chạm xuống cho trang, để bấm được nút Phát của nó.
        else if (!_showBar)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _bumpBar,
            ),
          ),
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
          Positioned(right: 28, bottom: _showBar ? 150 : 28, child: _nextEpisodeBox()),
        // Bảng chọn nguồn nằm TRÊN CÙNG để nhận được phím/chuột.
        if (_webError != null && !_native) _webErrorPanel(),
        if (_srcPanel) _sourcePanel(),
        ]),
      ),
    );
  }

  /// Hộp "Tập tiếp theo" khi phim/tập vừa hết: đếm ngược rồi tự chuyển.
  /// Bấm chuột được (PC) và bấm OK trên remote được (TV).
  Widget _nextEpisodeBox() {
    final next = _idx + 1 < _eps.length ? _eps[_idx + 1] : null;
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
    final multi = _eps.length > 1;
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
              onPressed: _exit,
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
                onPressed: _idx < _eps.length - 1 ? () => _goto(_idx + 1) : null,
              ),
            ],
            const Spacer(),
            // Đổi nguồn / đổi tiếng. Chỉ hiện khi phim có nhiều hơn một lựa chọn.
            if (widget.sources.length > 1) ...[
              TextButton.icon(
                onPressed: () {
                  setState(() => _srcPanel = true);
                  _hideT?.cancel(); // đang chọn nguồn thì đừng giấu thanh
                },
                icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                label: Text(widget.sources[_srcIdx].label,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const SizedBox(width: 4),
            ],
            // NÚT tạm dừng/phát chứ không phải icon trang trí: thanh của nguồn
            // đã bị giấu nên đây là nút pause duy nhất cho người dùng chuột.
            // Icon theo HÀNH ĐỘNG sắp làm (đang dừng -> hiện ▶ để phát).
            IconButton(
              tooltip: _paused ? 'Phát (OK)' : 'Tạm dừng (OK)',
              icon: Icon(_paused ? Icons.play_circle_fill : Icons.pause_circle_filled,
                  color: kRed, size: 26),
              onPressed: _togglePlay,
            ),
            // Âm lượng: thanh của trang nguồn bị giấu nên đây là chỗ chỉnh tiếng
            // duy nhất trong app (trước bản này người dùng phải ra mixer Windows).
            IconButton(
              tooltip: _vol > 0 ? 'Tắt tiếng' : 'Mở tiếng',
              icon: Icon(
                _vol <= 0
                    ? Icons.volume_off
                    : (_vol < 0.5 ? Icons.volume_down : Icons.volume_up),
                color: Colors.white,
                size: 22,
              ),
              onPressed: _toggleMute,
            ),
            SizedBox(
              width: 110,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(value: _vol, onChanged: _setVolume),
              ),
            ),
            const SizedBox(width: 10),
            Text('${_fmt(_pos)} / ${_fmt(_dur)}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
          // Bấm/kéo để tua. BẮT BUỘC phải tua được: thanh này che thanh tua của
          // trang nguồn khi hiện, nếu chỉ để hiển thị thì người dùng chuột mất
          // luôn khả năng tua.
          LayoutBuilder(builder: (ctx, c) {
            void seekTo(double dx) {
              if (_dur <= 0) return;
              _cmd('seekto', (dx / c.maxWidth).clamp(0.0, 1.0) * _dur);
              _bumpBar();
            }
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => seekTo(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
              // Vùng bấm dày hơn vạch (vạch chỉ 5px) cho dễ trúng bằng chuột.
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: p, minHeight: 5,
                    backgroundColor: Colors.white24, color: kRed,
                  ),
                ),
              ),
            );
          }),
          const Text('◀ ▶ tua 10 giây   •   ▲ ▼ tua 1 phút   •   OK: tạm dừng   •   Back: thoát   •   bấm vào vạch để tua',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
        ]),
      ),
    );
  }

  /// UA giả kiểu máy tính cho Windows/Android. Xem chú thích chỗ dùng.
  static const _kDesktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Đọc các cờ mà CHÍNH trang embed của nguonc đặt ra, để biết nó tắc ở khâu
  /// nào: chưa qua ải quảng cáo (popup), chọn sai luồng, hay phát lỗi.
  static const _kNguoncProbeJs = r'''
JSON.stringify({
  ua: (navigator.userAgent||'').slice(0, 70),
  plat: navigator.platform,
  popupReady: window.popupReady, popupFailed: window.popupFailed,
  started: window.playerStarted, blocked: window.playerBlocked,
  stream: (window.streamURL||'').slice(0, 60),
  video: !!document.querySelector('video'),
  // Năng lực của WebView — trang phát HLS mã hoá cần một trong số này.
  mse: typeof MediaSource !== 'undefined',
  mms: typeof ManagedMediaSource !== 'undefined',
  sw: !!navigator.serviceWorker,
  wasm: typeof WebAssembly !== 'undefined',
  subtle: !!(window.crypto && window.crypto.subtle),
  hlsNative: !!document.createElement('video')
        .canPlayType('application/vnd.apple.mpegurl'),
  errs: (window.__vfErrors||[]).slice(0, 3),
  txt: ((document.getElementById('player')||{}).innerText||'')
        .replace(/\s+/g,' ').slice(0, 140)
})
''';

  /// Máy dùng CHUỘT. Chỉ những máy này mới bấm-vào-phim-để-tạm-dừng được trên
  /// trang nhúng; máy cảm ứng cần chạm thẳng vào nút của trang.
  static final bool _dungChuot =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Widget _webView() {
    final nav = _navUrl;
    if (nav == null) {
      // Đang dựng cổng Referer (vài mili giây). Nền đen cho liền mạch.
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: kRed)),
      );
    }
    final w = InAppWebView(
              // Windows: môi trường WebView2 đã mở khóa autoplay (main.dart).
              webViewEnvironment: webViewEnvironment,
              initialUrlRequest: URLRequest(url: WebUri(nav)),
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
                // KHÔNG khai man trên iOS. Trang embed của nguonc TỰ CHIA NHÁNH
                // theo máy Apple:
                //   const isIOS = /iphone|ipod|ipad/i.test(navigator.userAgent) || ...
                //   window.streamURL = '/' + sUb + (isApple ? '' : '?d=1');
                // Đưa UA Windows vào iPad là ép nó đi nhánh sai -> trang tự báo
                // "Đã xảy ra lỗi khi phát video". Trên Windows/Android thì UA giả
                // vẫn cần, để trang trả giao diện máy tính thay vì bản rút gọn.
                userAgent: Platform.isIOS ? null : _kDesktopUa,
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
              onWebViewCreated: (c) {
                _c = c;
                vlog('webview', 'da tao WebView');
              },
              onLoadStart: (c, url) {
                _lastNavStart = url?.toString() ?? '';
                vlog('webview', 'bat dau tai $_lastNavStart');
              },
              onReceivedError: (c, req, err) {
                vlog('webview', 'LOI TAI TRANG ${req.url}: ${err.type} ${err.description}');
                // Chỉ báo khi hỏng CHÍNH trang phim; ảnh/quảng cáo lỗi lặt vặt
                // thì kệ, phim vẫn chạy được.
                if (req.isForMainFrame == true && mounted) {
                  setState(() => _webError = err.description);
                }
              },
              onReceivedHttpError: (c, req, resp) =>
                  vlog('webview', 'HTTP ${resp.statusCode} khi tai ${req.url}'),
              shouldOverrideUrlLoading: (c, action) async {
                final u = action.request.url?.toString() ?? '';
                if (isAdUrl(u)) return NavigationActionPolicy.CANCEL;
                // Quảng cáo cướp cả khung chính để đá sang trang khác (hay gặp
                // nhất là trang cờ bạc, rồi nhà mạng chặn và trả về trang cảnh
                // báo đè kín màn hình, mất luôn phim đang xem).
                if (isHijackNavigation(
                  currentUrl: _url,
                  targetUrl: u,
                  isMainFrame: action.isForMainFrame,
                  pageLoadedOnce: _pageLoadedOnce,
                )) {
                  vlog('webview', 'CHAN quang cao cuop trang -> $u');
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (c, req) async => false,
              // Ghi dòng chẩn đoán VIEFLIX_DBG ra file để soi khi phim không tự chạy.
              onConsoleMessage: (c, msg) async {
                final m = msg.message;
                // Phím do trang bắn về (Windows: WebView2 giữ tiêu điểm bàn phím).
                if (m.startsWith('VFKEY:')) {
                  _handlePageKey(m.substring(6));
                  return;
                }
                // Ghi MỌI thông báo console ra nhật ký để soi khi phim lỗi
                // (player.js của nguồn in "Lỗi khởi tạo player" ra đây).
                final lvl = msg.messageLevel.toString().split('.').last;
                vlog('web-console',
                    '[$lvl] ${m.length > 500 ? m.substring(0, 500) : m}');
              },
              // Sau khi trang tải xong thì TỰ TIÊM LẠI script bằng evaluateJavascript.
              //
              // ⚠️ BẮT BUỘC, đừng tưởng `initialUserScripts` ở trên là đủ: plugin
              // flutter_inappwebview_windows 0.6.0 nhận initialUserScripts rồi cất
              // vào `userOnlyScripts_` nhưng KHÔNG BAO GIỜ tiêm — hàm đọc ra
              // (`getUserOnlyScriptsAt`) không được gọi ở đâu trong plugin. Nên trên
              // Windows, cầu nối không tồn tại -> `window.__vfState` luôn rỗng ->
              // app hiện 00:00/00:00 và pause/tua đều không ăn.
              //
              // Cầu nối có cờ `window.__vfBridge` nên tiêm lại nhiều lần vô hại;
              // Android vẫn chạy bằng userScript như cũ.
              onLoadStop: (c, url) async {
                // Trang cổng chỉ là bàn đạp, chưa phải trang phim: đừng tính là
                // "đã tải xong" — nếu tính, cú nhảy sang streamc.xyz ngay sau đó
                // sẽ bị luật chặn quảng cáo cướp trang bắt nhầm. Cũng chẳng có
                // gì để tiêm vào đó.
                if (RefererGate.isGateUrl(url?.toString() ?? '')) return;
                _pageLoadedOnce = true;
                _probeNguoncPage(c);
                if (_webError != null && mounted) {
                  setState(() => _webError = null); // tải lại được rồi
                }
                try { await c.evaluateJavascript(source: kPlayerBridgeScript); } catch (_) {}
                try { await c.evaluateJavascript(source: kAutoPlayScript); } catch (_) {}
                _syncState();
              },
            );
    // TV: chặn WebView "ăn" phím của remote — mọi phím do app xử lý, còn video
    // được điều khiển bằng JS. Trên PC vẫn cho bấm chuột vào trang như cũ.
    return Platform.isAndroid ? ExcludeFocus(child: IgnorePointer(child: w)) : w;
  }
}

/// Một dòng trong bảng chọn nguồn. Tách riêng để có Focus rõ ràng cho remote TV.
class _SourceRow extends StatelessWidget {
  final StreamSource src;
  final bool selected, autofocus;
  final VoidCallback onPressed;
  const _SourceRow({
    required this.src,
    required this.selected,
    required this.autofocus,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FocusHighlight(
      scale: 1.0,
      autofocus: autofocus,
      onPressed: onPressed,
      builder: (f) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kRed : kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: f ? kAmber : Colors.white12, width: 2),
        ),
        child: Row(children: [
          Icon(selected ? Icons.play_circle_fill : Icons.circle_outlined,
              color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(src.label,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
              Text('${src.serverName} · ${src.episodes.length} tập',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}
