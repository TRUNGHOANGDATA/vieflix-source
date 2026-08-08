import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lấy điểm đánh giá (rating) từ TMDB theo tên phim gốc.
/// Cần khóa API v3 (miễn phí) do người dùng nhập ở phần Cài đặt.
class TmdbResult {
  final double rating; // vote_average (0..10)
  final int votes;
  TmdbResult(this.rating, this.votes);
}

class TmdbApi {
  final String apiKey;
  final http.Client _client;
  TmdbApi(this.apiKey, {http.Client? client}) : _client = client ?? http.Client();

  static const _base = 'https://api.themoviedb.org/3';

  /// Tìm theo tên (ưu tiên tên gốc tiếng Anh). Trả điểm của kết quả đầu có điểm > 0.
  Future<TmdbResult?> rating(String query) async {
    if (apiKey.isEmpty || query.trim().isEmpty) return null;
    final url = '$_base/search/multi?api_key=$apiKey'
        '&query=${Uri.encodeQueryComponent(query.trim())}&language=en-US&page=1';
    try {
      final r = await _client.get(Uri.parse(url));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final results = (j['results'] as List?) ?? [];
      for (final it in results) {
        final m = it as Map<String, dynamic>;
        final va = (m['vote_average'] is num) ? (m['vote_average'] as num).toDouble() : 0.0;
        final vc = (m['vote_count'] is num) ? (m['vote_count'] as num).toInt() : 0;
        if (va > 0 && vc > 0) return TmdbResult(va, vc);
      }
    } catch (_) {}
    return null;
  }

  /// Ảnh nền (backdrop) độ phân giải cao theo tên phim, cho banner trang chi tiết.
  /// Trả URL w1280 hoặc null nếu không có.
  Future<String?> backdrop(String query) async {
    if (apiKey.isEmpty || query.trim().isEmpty) return null;
    try {
      final r = await _client.get(Uri.parse(
          '$_base/search/multi?api_key=$apiKey&query=${Uri.encodeQueryComponent(query.trim())}&language=en-US&page=1'));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      for (final it in ((j['results'] as List?) ?? [])) {
        final m = it as Map<String, dynamic>;
        final bp = (m['backdrop_path'] ?? '').toString();
        if (bp.isNotEmpty) return 'https://image.tmdb.org/t/p/original$bp';
      }
    } catch (_) {}
    return null;
  }

  /// Lấy mã video YouTube của trailer theo tên phim (ưu tiên loại "Trailer").
  /// Trả null nếu không tìm được. Chỉ tra kết quả khớp đầu tiên cho nhanh.
  Future<String?> trailerKey(String query) async {
    if (apiKey.isEmpty || query.trim().isEmpty) return null;
    try {
      final s = await _client.get(Uri.parse(
          '$_base/search/multi?api_key=$apiKey&query=${Uri.encodeQueryComponent(query.trim())}&language=en-US&page=1'));
      if (s.statusCode != 200) return null;
      final sj = jsonDecode(utf8.decode(s.bodyBytes)) as Map<String, dynamic>;
      final results = (sj['results'] as List?) ?? [];
      for (final it in results) {
        final m = it as Map<String, dynamic>;
        final type = (m['media_type'] ?? '').toString();
        final id = m['id'];
        if ((type != 'movie' && type != 'tv') || id == null) continue;
        final v = await _client.get(Uri.parse('$_base/$type/$id/videos?api_key=$apiKey'));
        if (v.statusCode != 200) return null;
        final vj = jsonDecode(utf8.decode(v.bodyBytes)) as Map<String, dynamic>;
        final vids = (vj['results'] as List?) ?? [];
        Map<String, dynamic>? pick;
        for (final x in vids) {
          final vv = x as Map<String, dynamic>;
          if ((vv['site'] ?? '').toString().toLowerCase() != 'youtube') continue;
          if ((vv['type'] ?? '').toString().toLowerCase() == 'trailer') {
            pick = vv;
            break;
          }
          pick ??= vv; // tạm giữ video YouTube đầu tiên nếu chưa thấy Trailer
        }
        return pick == null ? null : (pick['key'] ?? '').toString();
      }
    } catch (_) {}
    return null;
  }
}
