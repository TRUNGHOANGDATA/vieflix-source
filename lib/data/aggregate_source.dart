import '../models/movie.dart';
import '../models/movie_detail.dart';
import '../models/paginated.dart';
import 'movie_source.dart';

/// Gộp nhiều nguồn thành MỘT danh mục.
///
/// Quy tắc: nguồn đứng trước được ưu tiên (nguonc), phim nào nguồn trước
/// **chưa có** thì nguồn sau bù vào — lọc trùng bằng [MergeDedup] (tên gốc đã
/// bỏ dấu + năm), vì slug hai bên không giống nhau.
///
/// Mỗi nguồn tự giữ số trang riêng: nguồn nào hết trang thì bỏ qua, các nguồn
/// còn lại vẫn chạy tiếp. `totalPage` trả về là số trang LỚN NHẤT trong các
/// nguồn, nên cuộn vô tận không dừng sớm vì một nguồn ít phim hơn.
class AggregateSource implements MovieSource {
  /// Các nguồn dùng để DỰNG DANH MỤC (chỉ nguồn đang bật trong Cài đặt).
  final List<MovieSource> sources;

  /// Các nguồn dùng để MỞ CHI TIẾT một phim. Luôn đủ mọi nguồn, kể cả nguồn
  /// đang tắt — để phim đã lưu trong Yêu thích / Đang xem vẫn mở được.
  final List<MovieSource> detailSources;

  AggregateSource(this.sources, {List<MovieSource>? detailSources})
      : detailSources = detailSources ?? sources,
        assert(sources.isNotEmpty, 'Phải có ít nhất một nguồn');

  @override
  String get id => sources.length == 1 ? sources.first.id : 'gop';

  /// Số trang đã biết của từng nguồn (biết được sau lần tải đầu).
  final Map<String, int> _totalPageOf = {};

  bool _exhausted(MovieSource s, int page) {
    final total = _totalPageOf[s.id];
    return total != null && page > total;
  }

  Future<Paginated<Movie>> _merge(
    int page,
    Future<Paginated<Movie>> Function(MovieSource s) fetch,
  ) async {
    final wanted = sources.where((s) => !_exhausted(s, page)).toList();
    if (wanted.isEmpty) {
      return Paginated(items: [], currentPage: page, totalPage: page);
    }

    // Một nguồn lỗi (hết trang, 404 thể loại không có bên đó, rớt mạng) thì
    // KHÔNG kéo cả danh mục xuống — chỉ bỏ qua nguồn đó.
    final results = await Future.wait(wanted.map((s) async {
      try {
        final r = await fetch(s);
        _totalPageOf[s.id] = r.totalPage;
        return r;
      } catch (_) {
        return null;
      }
    }));

    final dedup = MergeDedup();
    final items = <Movie>[];
    for (final r in results) {
      if (r == null) continue;
      for (final m in r.items) {
        if (dedup.add(m)) items.add(m);
      }
    }

    // Nếu MỌI nguồn đều lỗi thì báo lỗi thật, đừng giả vờ là hết phim.
    if (results.every((r) => r == null)) {
      throw ApiException('Không tải được dữ liệu từ nguồn nào');
    }

    var total = 1;
    for (final t in _totalPageOf.values) {
      if (t > total) total = t;
    }
    return Paginated(items: items, currentPage: page, totalPage: total);
  }

  @override
  Future<Paginated<Movie>> latest({int page = 1}) =>
      _merge(page, (s) => s.latest(page: page));

  @override
  Future<Paginated<Movie>> listByType(String type, {int page = 1}) =>
      _merge(page, (s) => s.listByType(type, page: page));

  @override
  Future<Paginated<Movie>> byGenre(String slug, {int page = 1}) =>
      _merge(page, (s) => s.byGenre(slug, page: page));

  @override
  Future<Paginated<Movie>> byCountry(String slug, {int page = 1}) =>
      _merge(page, (s) => s.byCountry(slug, page: page));

  @override
  Future<Paginated<Movie>> byYear(String year, {int page = 1}) =>
      _merge(page, (s) => s.byYear(year, page: page));

  @override
  Future<Paginated<Movie>> browse(BrowseFilter filter, {int page = 1}) =>
      _merge(page, (s) => s.browse(filter, page: page));

  @override
  Future<List<Movie>> search(String keyword) async {
    final results = await Future.wait(sources.map((s) async {
      try {
        return await s.search(keyword);
      } catch (_) {
        return <Movie>[];
      }
    }));
    final dedup = MergeDedup();
    final items = <Movie>[];
    for (final list in results) {
      for (final m in list) {
        if (dedup.add(m)) items.add(m);
      }
    }
    return items;
  }

  /// Chi tiết phim đi thẳng tới đúng nguồn giữ phim đó (đọc từ slug).
  @override
  Future<MovieDetail> detail(String slug) {
    final want = sourceOfSlug(slug);
    for (final s in detailSources) {
      if (s.id == want) return s.detail(slug);
    }
    throw ApiException('Không có nguồn "${sourceLabel(want)}"');
  }
}
