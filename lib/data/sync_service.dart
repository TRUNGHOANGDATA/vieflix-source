import 'dart:convert';
import 'package:http/http.dart' as http;

/// Đồng bộ danh sách "đang xem" / "yêu thích" giữa các máy bằng một MÃ ngắn.
///
/// Cơ chế: đẩy gói JSON lên dịch vụ lưu tạm dpaste.com (không cần tài khoản),
/// lấy về mã ngắn ở đuôi URL. Máy khác nhập mã đó để tải gói về.
class SyncService {
  static const _endpoint = 'https://dpaste.com/api/v2/';
  static const _ua = 'VieFlix-Sync';

  /// Đẩy [content] lên, trả về MÃ ngắn (vd "3ab9xk"). Mã sống ~1 năm.
  Future<String> upload(String content) async {
    final r = await http.post(
      Uri.parse(_endpoint),
      headers: {'User-Agent': _ua},
      body: {
        'content': content,
        'syntax': 'text',
        'title': 'vieflix-sync',
        'expiry_days': '365',
      },
    );
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception('Tạo mã thất bại (mã lỗi ${r.statusCode})');
    }
    // Thân phản hồi là URL, vd https://dpaste.com/3AB9XK -> lấy đoạn cuối.
    final url = utf8.decode(r.bodyBytes).trim();
    final code = url.split('/').where((s) => s.isNotEmpty).last;
    if (code.isEmpty) throw Exception('Không đọc được mã trả về');
    return code;
  }

  /// Tải gói JSON về theo [code].
  Future<String> download(String code) async {
    final c = code.trim().replaceAll(RegExp(r'\s'), '');
    if (c.isEmpty) throw Exception('Mã trống');
    final r = await http.get(
      Uri.parse('https://dpaste.com/$c.txt'),
      headers: {'User-Agent': _ua},
    );
    if (r.statusCode == 404) throw Exception('Không tìm thấy mã "$c"');
    if (r.statusCode != 200) throw Exception('Tải về thất bại (mã lỗi ${r.statusCode})');
    return utf8.decode(r.bodyBytes);
  }
}
