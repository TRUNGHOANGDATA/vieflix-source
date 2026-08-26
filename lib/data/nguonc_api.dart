import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import '../models/movie_detail.dart';
import '../models/paginated.dart';
import 'movie_source.dart';

export 'movie_source.dart' show ApiException;

class NguoncApi implements MovieSource {
  final http.Client _client;
  static const _base = 'https://phim.nguonc.com/api';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  NguoncApi({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get id => kSrcNguonc;

  /// Vài thể loại nguonc đặt slug KHÁC với tên thường gọi (và khác phimapi).
  /// Không map thì các hàng này rỗng bên nguonc — trước giờ "Hài" và
  /// "Viễn Tưởng" đúng là không ra phim nào.
  static const _genreAlias = {
    'hai': 'phim-hai',
    'hai-huoc': 'phim-hai',
    'vien-tuong': 'khoa-hoc-vien-tuong',
  };

  Future<Map<String, dynamic>> _getJson(String path) async {
    Object? lastErr;
    // Thử tối đa 3 lần: nguonc thỉnh thoảng lỗi tạm thời (5xx / rớt mạng).
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
      try {
        final r = await _client.get(
          Uri.parse('$_base$path'),
          headers: {'User-Agent': _ua, 'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 12));
        if (r.statusCode != 200) {
          lastErr = ApiException('Máy chủ trả về ${r.statusCode}');
          continue; // thử lại
        }
        return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      } catch (e) {
        lastErr = e; // lỗi mạng / timeout / JSON hỏng -> thử lại
      }
    }
    throw ApiException('Không tải được dữ liệu (thử lại vẫn lỗi): $lastErr');
  }

  Paginated<Movie> _parseList(Map<String, dynamic> j) {
    final p = (j['paginate'] as Map?)?.cast<String, dynamic>() ?? {};
    final items = ((j['items'] as List?) ?? [])
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
    return Paginated(
      items: items,
      currentPage: (p['current_page'] is int) ? p['current_page'] : 1,
      totalPage: (p['total_page'] is int) ? p['total_page'] : 1,
    );
  }

  @override
  Future<Paginated<Movie>> latest({int page = 1}) async =>
      _parseList(await _getJson('/films/phim-moi-cap-nhat?page=$page'));

  @override
  Future<Paginated<Movie>> listByType(String type, {int page = 1}) async =>
      _parseList(await _getJson('/films/danh-sach/$type?page=$page'));

  @override
  Future<Paginated<Movie>> byGenre(String slug, {int page = 1}) async =>
      _parseList(await _getJson(
          '/films/the-loai/${_genreAlias[slug] ?? slug}?page=$page'));

  @override
  Future<Paginated<Movie>> byCountry(String slug, {int page = 1}) async =>
      _parseList(await _getJson('/films/quoc-gia/$slug?page=$page'));

  @override
  Future<Paginated<Movie>> byYear(String year, {int page = 1}) async =>
      _parseList(await _getJson('/films/nam-phat-hanh/$year?page=$page'));

  @override
  Future<List<Movie>> search(String keyword) async {
    final j = await _getJson('/films/search?keyword=${Uri.encodeQueryComponent(keyword)}');
    return _parseList(j).items;
  }

  @override
  Future<MovieDetail> detail(String slug) async {
    final j = await _getJson('/film/$slug');
    final movie = (j['movie'] as Map?)?.cast<String, dynamic>();
    if (movie == null) throw ApiException('Không tìm thấy phim');
    return MovieDetail.fromJson(movie);
  }
}
