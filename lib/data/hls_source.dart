import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'app_log.dart';
import 'hls_ad_filter.dart';

/// Chuẩn bị link HLS cho trình phát native: tải playlist về, bỏ quảng cáo chèn
/// trong luồng, rồi **phục vụ lại qua một máy chủ HTTP nội bộ** (127.0.0.1).
///
/// Vì sao phải qua HTTP chứ không ghi ra file: quảng cáo nằm ngay trong playlist
/// nên bắt buộc phải sửa playlist. Nhưng nếu đưa cho trình phát một FILE cục bộ
/// mà bên trong trỏ tới phân đoạn `https`, thì bộ đọc HLS của ffmpeg coi đó là
/// nhảy giao thức (file -> https) và tuỳ bản dựng từng nền tảng mà CHẶN. Phục vụ
/// qua `http://127.0.0.1` thì playlist và phân đoạn cùng nằm trong nhóm giao thức
/// mạng nên không bản nào chặn — và cũng khỏi đụng tới quyền ghi file trên Android.
///
/// Mọi lỗi đều trả về null để bên gọi dùng link gốc — thà xem kèm quảng cáo còn
/// hơn không xem được.
class HlsPreparer {
  final http.Client _client;
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  HlsPreparer({http.Client? client}) : _client = client ?? http.Client();

  static HttpServer? _server;
  static final Map<String, String> _served = {};
  static int _counter = 0;

  Future<String> _get(Uri u) async {
    final r = await _client.get(u, headers: {'User-Agent': _ua}).timeout(
          const Duration(seconds: 15),
        );
    if (r.statusCode != 200) {
      throw HttpException('HTTP ${r.statusCode}', uri: u);
    }
    return r.body;
  }

  /// Bật máy chủ nội bộ nếu chưa có. Chỉ nghe trên loopback nên không máy nào
  /// ngoài thiết bị này với tới được.
  static Future<int> _ensureServer() async {
    final s = _server;
    if (s != null) return s.port;
    final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = srv;
    srv.listen((req) async {
      final body = _served[req.uri.path];
      if (body == null) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      req.response.headers.contentType =
          ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');
      req.response.headers.set('Cache-Control', 'no-store');
      req.response.add(utf8.encode(body));
      await req.response.close();
    }, onError: (Object e) => vlog('ads', 'may chu noi bo loi: $e'));
    vlog('ads', 'may chu playlist noi bo chay o cong ${srv.port}');
    return srv.port;
  }

  /// Đóng máy chủ nội bộ (gọi khi thoát trình phát).
  static Future<void> shutdown() async {
    final s = _server;
    _server = null;
    _served.clear();
    if (s != null) await s.close(force: true);
  }

  /// Trả về link playlist đã bỏ quảng cáo (trỏ vào máy chủ nội bộ) kèm số liệu
  /// đã cắt. null nghĩa là không lọc được hoặc phim vốn không có quảng cáo —
  /// cứ dùng link gốc.
  Future<({String url, double removedSeconds, int removedSegments})?> prepare(
    String m3u8Url,
  ) async {
    try {
      var url = Uri.parse(m3u8Url);
      var body = await _get(url);

      // Playlist master -> chọn luồng có bitrate cao nhất rồi tải tiếp.
      if (body.contains('#EXT-X-STREAM-INF')) {
        final variant = _pickBestVariant(body);
        if (variant == null) return null;
        url = url.resolve(variant);
        body = await _get(url);
      }

      final res = filterHlsAds(body, url);
      if (res == null || !res.hasAds) return null; // không có quảng cáo thì thôi

      final port = await _ensureServer();
      // Giữ tối đa vài playlist gần nhất (đổi tập/đổi nguồn liên tục).
      if (_served.length > 4) _served.clear();
      final path = '/vf${_counter++}.m3u8';
      _served[path] = res.playlist;

      return (
        url: 'http://127.0.0.1:$port$path',
        removedSeconds: res.removedSeconds,
        removedSegments: res.removedSegments,
      );
    } catch (e) {
      vlog('ads', 'chuan bi playlist that bai: $e');
      return null;
    }
  }

  /// Dòng URI của luồng có BANDWIDTH lớn nhất trong playlist master.
  static String? _pickBestVariant(String master) {
    final lines = master.split('\n').map((l) => l.trim()).toList();
    String? best;
    var bestBw = -1;
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].startsWith('#EXT-X-STREAM-INF')) continue;
      final bw = int.tryParse(
              RegExp(r'BANDWIDTH=(\d+)').firstMatch(lines[i])?.group(1) ?? '') ??
          0;
      for (var j = i + 1; j < lines.length; j++) {
        if (lines[j].isEmpty || lines[j].startsWith('#')) continue;
        if (bw > bestBw) {
          bestBw = bw;
          best = lines[j];
        }
        break;
      }
    }
    return best;
  }
}
