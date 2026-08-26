import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'hls_ad_filter.dart';

/// Chuẩn bị link HLS cho trình phát native: tải playlist về, bỏ quảng cáo chèn
/// trong luồng, ghi ra file tạm rồi cho trình phát mở file đó.
///
/// Vì sao phải ghi ra file: quảng cáo nằm NGAY TRONG playlist nên chặn theo tên
/// miền không ăn thua — phải sửa chính playlist. Phân đoạn giữ lại được đổi sang
/// URL tuyệt đối nên trình phát vẫn tải thẳng từ host gốc như thường.
///
/// Mọi lỗi đều trả về null để bên gọi dùng link gốc — thà xem kèm quảng cáo còn
/// hơn không xem được.
class HlsPreparer {
  final http.Client _client;
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  HlsPreparer({http.Client? client}) : _client = client ?? http.Client();

  Future<String> _get(Uri u) async {
    final r = await _client.get(u, headers: {'User-Agent': _ua}).timeout(
          const Duration(seconds: 15),
        );
    if (r.statusCode != 200) {
      throw HttpException('HTTP ${r.statusCode}', uri: u);
    }
    return r.body;
  }

  /// Trả về (đường dẫn file playlist đã lọc, số giây quảng cáo đã bỏ).
  /// null nghĩa là không lọc được — cứ dùng link gốc.
  Future<({String path, double removedSeconds, int removedSegments})?> prepare(
    String m3u8Url, {
    Directory? tempDir,
  }) async {
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

      final dir = tempDir ?? await getTemporaryDirectory();
      final f = File(
          '${dir.path}${Platform.pathSeparator}vieflix_${url.pathSegments.join('_').hashCode}.m3u8');
      await f.writeAsString(res.playlist, flush: true);
      return (
        path: f.path,
        removedSeconds: res.removedSeconds,
        removedSegments: res.removedSegments,
      );
    } catch (_) {
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
