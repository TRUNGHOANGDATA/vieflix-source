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
}
