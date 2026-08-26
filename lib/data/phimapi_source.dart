import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/episode.dart';
import '../models/movie.dart';
import '../models/movie_detail.dart';
import '../models/paginated.dart';
import 'movie_source.dart';

/// Nguồn phim thứ hai: phimapi.com (~30k phim, có sẵn link m3u8 lẫn link embed).
class PhimApiSource implements MovieSource {
  final http.Client _client;
  static const _base = 'https://phimapi.com';
  static const _cdn = 'https://phimimg.com';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  /// Số phim mỗi trang — để bằng nguonc cho hai nguồn gộp lại cân nhau.
  static const _limit = 10;

  PhimApiSource({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get id => kSrcPhimApi;

  /// Slug thể loại của nguonc -> slug của phimapi (chỗ hai bên đặt khác tên).
  /// Nhận cả hai cách gọi vì slug có thể đến từ chi tiết phim của nguồn kia.
  static const _genreAlias = {
    'hai': 'hai-huoc',
    'phim-hai': 'hai-huoc',
    'khoa-hoc-vien-tuong': 'vien-tuong',
  };

  /// nguonc coi "hoạt hình" là THỂ LOẠI, phimapi coi là DANH SÁCH (type).
  static const _genreAsType = {'hoat-hinh'};

  Future<Map<String, dynamic>> _getJson(String path) async {
    Object? lastErr;
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
          continue;
        }
        return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      } catch (e) {
        lastErr = e;
      }
    }
    throw ApiException('Không tải được dữ liệu (thử lại vẫn lỗi): $lastErr');
  }

  static String _abs(String url, String cdn) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final host = cdn.isNotEmpty ? cdn : _cdn;
    return '$host/${url.replaceAll(RegExp('^/+'), '')}';
  }

  /// Bỏ thẻ HTML trong nội dung (nguonc trả văn bản thuần, phimapi trả HTML).
  static String stripHtml(String s) => s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  static Movie _movie(Map<String, dynamic> j, String cdn) {
    final cats = (j['category'] as List?) ?? const [];
    return Movie(
      name: (j['name'] ?? '').toString(),
      slug: '$kPhimApiPrefix${j['slug'] ?? ''}',
      originalName: (j['origin_name'] ?? '').toString(),
      thumbUrl: _abs((j['thumb_url'] ?? '').toString(), cdn),
      posterUrl: _abs((j['poster_url'] ?? '').toString(), cdn),
      description: stripHtml((j['content'] ?? '').toString()),
      quality: (j['quality'] ?? '').toString(),
      language: (j['lang'] ?? '').toString(),
      currentEpisode: (j['episode_current'] ?? '').toString(),
      totalEpisodes: int.tryParse('${j['episode_total'] ?? ''}') ?? 0,
      year: (j['year'] ?? '').toString(),
      genres: cats.map((e) => ((e as Map)['name'] ?? '').toString()).toList(),
    );
  }

  /// Dạng trả về của các endpoint `/v1/api/...` (items nằm trong `data`).
  static Paginated<Movie> _parseV1(Map<String, dynamic> j) {
    final data = (j['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final cdn = (data['APP_DOMAIN_CDN_IMAGE'] ?? _cdn).toString();
    final pg = ((data['params'] as Map?)?['pagination'] as Map?)
            ?.cast<String, dynamic>() ??
        {};
    return Paginated(
      items: ((data['items'] as List?) ?? [])
          .map((e) => _movie((e as Map).cast<String, dynamic>(), cdn))
          .toList(),
      currentPage: int.tryParse('${pg['currentPage']}') ?? 1,
      totalPage: int.tryParse('${pg['totalPages']}') ?? 1,
    );
  }

  /// Dạng trả về của `/danh-sach/phim-moi-cap-nhat-v3` (items ở ngoài cùng).
  static Paginated<Movie> _parseV3(Map<String, dynamic> j) {
    final pg = (j['pagination'] as Map?)?.cast<String, dynamic>() ?? {};
    return Paginated(
      items: ((j['items'] as List?) ?? [])
          .map((e) => _movie((e as Map).cast<String, dynamic>(), _cdn))
          .toList(),
      currentPage: int.tryParse('${pg['currentPage']}') ?? 1,
      totalPage: int.tryParse('${pg['totalPages']}') ?? 1,
    );
  }

  @override
  Future<Paginated<Movie>> latest({int page = 1}) async => _parseV3(await _getJson(
      '/danh-sach/phim-moi-cap-nhat-v3?page=$page&limit=$_limit'));

  @override
  Future<Paginated<Movie>> listByType(String type, {int page = 1}) async =>
      _parseV1(await _getJson('/v1/api/danh-sach/$type?page=$page&limit=$_limit'));

  @override
  Future<Paginated<Movie>> byGenre(String slug, {int page = 1}) async {
    if (_genreAsType.contains(slug)) return listByType(slug, page: page);
    final s = _genreAlias[slug] ?? slug;
    return _parseV1(
        await _getJson('/v1/api/the-loai/$s?page=$page&limit=$_limit'));
  }

  @override
  Future<Paginated<Movie>> byCountry(String slug, {int page = 1}) async =>
      _parseV1(await _getJson('/v1/api/quoc-gia/$slug?page=$page&limit=$_limit'));

  @override
  Future<Paginated<Movie>> byYear(String year, {int page = 1}) async =>
      _parseV1(await _getJson('/v1/api/nam/$year?page=$page&limit=$_limit'));

  @override
  Future<List<Movie>> search(String keyword) async => _parseV1(await _getJson(
          '/v1/api/tim-kiem?keyword=${Uri.encodeQueryComponent(keyword)}&limit=24'))
      .items;

  @override
  Future<MovieDetail> detail(String slug) async {
    final bare = slug.startsWith(kPhimApiPrefix)
        ? slug.substring(kPhimApiPrefix.length)
        : slug;
    final j = await _getJson('/phim/$bare');
    final m = (j['movie'] as Map?)?.cast<String, dynamic>();
    if (m == null) throw ApiException('Không tìm thấy phim');

    List<CategoryItem> items(String key) => ((m[key] as List?) ?? [])
        .map((e) => CategoryItem(
              name: ((e as Map)['name'] ?? '').toString(),
              slug: (e['slug'] ?? '').toString(),
            ))
        .toList();

    String joinList(String key) {
      final v = m[key];
      if (v is List) {
        return v
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .join(', ');
      }
      return (v ?? '').toString();
    }

    final director = joinList('director');
    final casts = joinList('actor');
    final year = (m['year'] ?? '').toString();

    return MovieDetail(
      base: _movie(m, _cdn),
      director: director.isEmpty ? null : director,
      casts: casts.isEmpty ? null : casts,
      year: year.isEmpty ? null : year,
      genres: items('category'),
      countries: items('country'),
      servers: ((j['episodes'] as List?) ?? []).map((e) {
        final g = (e as Map).cast<String, dynamic>();
        return ServerGroup(
          serverName: (g['server_name'] ?? '').toString(),
          items: ((g['server_data'] as List?) ?? []).map((x) {
            final ep = (x as Map).cast<String, dynamic>();
            return Episode(
              name: (ep['name'] ?? '').toString(),
              slug: (ep['slug'] ?? '').toString(),
              embed: (ep['link_embed'] ?? '').toString(),
              m3u8: (ep['link_m3u8'] ?? '').toString(),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
