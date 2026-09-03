import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'app_log.dart';

/// Cổng sinh Referer cho các trang embed đòi hotlink hợp lệ.
///
/// **Vì sao cần:** streamc.xyz (nguồn nguonc) bật luật Cloudflare chặn hotlink —
/// yêu cầu nạp `embedNN.streamc.xyz/embed.php` mà THIẾU `Referer` thì trả về
/// HTTP 403 "Sorry, you have been blocked". Đo thực tế cho thấy luật chỉ đòi
/// Referer **khác rỗng** (trỏ đâu cũng được, kể cả `http://127.0.0.1`) cộng với
/// User-Agent kiểu trình duyệt; không soi tên miền.
///
/// **Vì sao không tự đặt header:** app từng truyền `URLRequest(headers:
/// {'Referer': ...})`, nhưng WebView2 trên Windows **vứt bỏ** header đó trong
/// `NavigateWithWebResourceRequest` — đo bằng máy chủ dội header thì điều hướng
/// không hề có `referer`, trong khi ảnh do chính trang tải lại có. Nên header
/// tự đặt chưa bao giờ tới được máy chủ.
///
/// **Cách làm:** để CHÍNH trình duyệt sinh Referer. Máy chủ nội bộ này trả một
/// trang HTML tí hon rồi trang đó tự `location.replace` sang link embed. Vì đây
/// là điều hướng do tài liệu khởi xướng, trình duyệt tự gắn `Referer` = gốc của
/// trang cổng. Dùng `replace` nên trang cổng không nằm lại trong lịch sử.
///
/// Trang embed vẫn là **khung chính** sau khi chuyển, nên cầu nối điều khiển
/// (tiêm bằng `evaluateJavascript`, chỉ với tới được khung chính trên Windows)
/// hoạt động y như cũ — khác hẳn cách bọc trong iframe.
class RefererGate {
  static HttpServer? _server;
  static final Map<String, String> _targets = {};
  static int _counter = 0;

  /// Những trang embed cần đi vòng qua cổng. Chỉ gắn cho host đã biết là chặn
  /// hotlink, tránh làm chậm/sai các nguồn embed khác.
  static bool needsGate(String url) =>
      (Uri.tryParse(url)?.host ?? '').toLowerCase().endsWith('streamc.xyz');

  /// Link này có phải trang cổng của chính app không (để bỏ qua trong các bước
  /// xử lý dành cho trang phim thật).
  static bool isGateUrl(String url) {
    final port = _server?.port;
    if (port == null) return false;
    final u = Uri.tryParse(url);
    return u != null && u.host == '127.0.0.1' && u.port == port;
  }

  static Future<int> _ensureServer() async {
    final s = _server;
    if (s != null) return s.port;
    final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = srv;
    srv.listen((req) async {
      final target = _targets[req.uri.path];
      if (target == null) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      req.response.headers.contentType =
          ContentType('text', 'html', charset: 'utf-8');
      req.response.headers.set('Cache-Control', 'no-store');
      req.response.add(utf8.encode(_page(target)));
      await req.response.close();
    }, onError: (Object e) => vlog('embed', 'cong referer loi: $e'));
    vlog('embed', 'cong referer chay o cong ${srv.port}');
    return srv.port;
  }

  /// `content="origin"` để Referer luôn là gốc trang cổng, không kèm đường dẫn —
  /// đủ cho luật của Cloudflare và không lộ gì thêm.
  static String _page(String target) => '<!doctype html>\n'
      '<html><head><meta charset="utf-8">\n'
      '<meta name="referrer" content="origin">\n'
      '<style>html,body{margin:0;height:100%;background:#000}</style>\n'
      '</head><body><script>location.replace(${jsonEncode(target)});</script>'
      '</body></html>';

  /// Link cần đưa cho WebView để mở [target] kèm Referer hợp lệ.
  ///
  /// Trục trặc gì (không mở được cổng) thì trả lại chính [target] — thà thử nạp
  /// thẳng rồi báo lỗi còn hơn không mở gì cả.
  static Future<String> urlFor(String target) async {
    if (!needsGate(target)) return target;
    try {
      final port = await _ensureServer();
      if (_targets.length > 4) _targets.clear(); // đổi tập/nguồn liên tục
      final path = '/g${_counter++}';
      _targets[path] = target;
      return 'http://127.0.0.1:$port$path';
    } catch (e) {
      vlog('embed', 'khong mo duoc cong referer: $e');
      return target;
    }
  }

  static Future<void> shutdown() async {
    final s = _server;
    _server = null;
    _targets.clear();
    if (s != null) await s.close(force: true);
  }
}
