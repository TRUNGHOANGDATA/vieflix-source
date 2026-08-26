import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/aggregate_source.dart';
import '../data/movie_source.dart';
import '../data/nguonc_api.dart';
import '../data/phimapi_source.dart';
import '../data/stream_sources.dart';
import '../data/local_store.dart';
import '../data/tmdb_api.dart';
import '../data/update_checker.dart';
import '../models/movie.dart';
import '../models/movie_detail.dart';
import '../models/paginated.dart';
import '../models/stream_source.dart';

/// Các nguồn ĐANG BẬT (override ở main từ store; đổi khi bật/tắt ở Cài đặt).
final enabledSourcesProvider =
    StateProvider<Set<String>>((ref) => {kSrcNguonc, kSrcPhimApi});

/// Toàn bộ nguồn app biết, theo thứ tự ưu tiên khi gộp danh mục.
final allSourcesProvider = Provider<List<MovieSource>>(
    (ref) => [NguoncApi(), PhimApiSource()]);

/// Nguồn phim app dùng: gộp các nguồn đang bật thành một danh mục.
/// Chi tiết phim vẫn mở được từ MỌI nguồn (phim đã lưu không bị kẹt khi tắt nguồn).
final apiProvider = Provider<MovieSource>((ref) {
  final on = ref.watch(enabledSourcesProvider);
  final all = ref.watch(allSourcesProvider);
  final picked = all.where((s) => on.contains(s.id)).toList();
  return AggregateSource(
    picked.isEmpty ? [all.first] : picked,
    detailSources: all,
  );
});

/// Tăng giá trị này để buộc Trang chủ vẽ lại (sau khi xoá mục Xem tiếp...).
final homeRefreshProvider = StateProvider<int>((ref) => 0);

/// TV: người dùng ĐANG gõ trong ô tìm ở màn Thư viện hay không.
/// Shell đọc cờ này để: bấm Back khi đang gõ thì chỉ THOÁT ô gõ (bỏ focus bàn
/// phím), KHÔNG nhảy về Trang chủ.
final searchTypingProvider = StateProvider<bool>((ref) => false);

// Kiểm tra bản cập nhật (GitHub Releases). Null nếu chưa cấu hình / không có bản mới.
final updateProvider = FutureProvider<UpdateInfo?>((ref) => UpdateChecker().check());

/// storeProvider được override ở main sau khi init().
final storeProvider = Provider<LocalStore>((ref) => throw UnimplementedError());

/// Khóa TMDB mặc định (khóa cá nhân người dùng cung cấp; có thể đổi ở Cài đặt).
const kDefaultTmdbKey = '8ef7373103c6691be809f158bee8b65e';

/// Khóa TMDB (override ở main từ store; cập nhật khi lưu ở Cài đặt).
final tmdbKeyProvider = StateProvider<String>((ref) => kDefaultTmdbKey);

/// Điểm rating TMDB theo tên (ưu tiên tên gốc). Null nếu chưa có khóa/không khớp.
final tmdbRatingProvider = FutureProvider.family<TmdbResult?, String>((ref, query) async {
  final key = ref.watch(tmdbKeyProvider);
  if (key.isEmpty || query.trim().isEmpty) return null;
  return TmdbApi(key).rating(query);
});

/// Phim đề cử: lấy phim mới, chấm điểm TMDB rồi xếp theo điểm cao. Rỗng nếu chưa có khóa.
final recommendedProvider = FutureProvider<List<(Movie, double)>>((ref) async {
  final key = ref.watch(tmdbKeyProvider);
  if (key.isEmpty) return [];
  final api = ref.read(apiProvider);
  final p1 = await api.latest(page: 1);
  final p2 = await api.latest(page: 2);
  final items = [...p1.items, ...p2.items];
  final tmdb = TmdbApi(key);
  final rated = <(Movie, double)>[];
  await Future.wait(items.map((m) async {
    final q = m.originalName.isNotEmpty ? m.originalName : m.name;
    final r = await tmdb.rating(q);
    if (r != null) rated.add((m, r.rating));
  }));
  rated.sort((a, b) => b.$2.compareTo(a.$2));
  // Trả về nhiều hơn số hiện ở trang chủ để trang "Xem tất cả" có đủ phim.
  return rated.take(60).toList();
});

// --- Gợi ý cá nhân: dựa vào thể loại hay xem (Xem tiếp) + Yêu thích ---
// Trả về (tên thể loại, slug thể loại, danh sách phim) — slug để mở "Xem tất cả".
final personalRecProvider = FutureProvider<(String, String, List<Movie>)?>((ref) async {
  ref.watch(homeRefreshProvider); // tính lại khi xem/thích phim mới
  final store = ref.read(storeProvider);
  final api = ref.read(apiProvider);

  final freq = <String, int>{};        // slug thể loại -> điểm
  final nameOf = <String, String>{};   // slug -> tên hiển thị
  final seen = <String>{};             // slug phim đã xem/đã thích -> loại khỏi gợi ý

  // Yêu thích đã lưu sẵn tên thể loại
  for (final f in store.favorites) {
    seen.add(f.slug);
    for (final g in f.genres) {
      final s = _genreSlug(g);
      if (s.isEmpty) continue;
      freq[s] = (freq[s] ?? 0) + 1;
      nameOf[s] = g;
    }
  }
  // Phim đang xem dở: lấy thể loại từ chi tiết (ưu tiên cao hơn), giới hạn 8 phim gần nhất
  for (final w in store.continueWatching.take(8)) {
    seen.add(w.slug);
    try {
      final d = await api.detail(w.slug);
      for (final g in d.genres) {
        if (g.slug.isEmpty) continue;
        freq[g.slug] = (freq[g.slug] ?? 0) + 2;
        nameOf[g.slug] = g.name;
      }
    } catch (_) {}
  }
  if (freq.isEmpty) return null;

  // Thể loại điểm cao nhất
  final top = freq.entries.reduce((a, b) => a.value >= b.value ? a : b);
  final list = (await api.byGenre(top.key)).items
      .where((m) => !seen.contains(m.slug))
      .toList();
  if (list.isEmpty) return null;
  return (nameOf[top.key] ?? top.key, top.key, list);
});

// Phim nổi bật cho hero banner trang chủ. CHỈ giữ phim CÓ ảnh ngang (TMDB) để
// mọi slide đồng nhất kiểu ảnh ngang (không lẫn poster dọc gây chỏi khi đổi).
final featuredMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final key = ref.watch(tmdbKeyProvider);
  // Gom ứng viên: ưu tiên phim đề cử (đã khớp TMDB), không có thì phim mới.
  List<Movie> pool = [];
  try {
    final rec = await ref.watch(recommendedProvider.future);
    pool = rec.map((e) => e.$1).toList();
  } catch (_) {}
  if (pool.isEmpty) {
    final latest = await ref.read(apiProvider).latest(page: 1);
    pool = latest.items;
  }
  if (key.isEmpty || pool.isEmpty) return pool.take(6).toList();

  // Kiểm tra ảnh ngang song song, chỉ giữ phim có ảnh ngang.
  final tmdb = TmdbApi(key);
  final checks = await Future.wait(pool.take(14).map((m) async {
    final q = m.originalName.isNotEmpty ? m.originalName : m.name;
    try {
      final b = await tmdb.backdrop(q);
      return (m, b != null && b.isNotEmpty);
    } catch (_) {
      return (m, false);
    }
  }));
  final withWide = checks.where((e) => e.$2).map((e) => e.$1).take(6).toList();
  return withWide.isNotEmpty ? withWide : pool.take(6).toList();
});

// Top phim bộ "hôm nay" cho hàng xếp hạng ở đầu trang chủ.
final topSeriesProvider = FutureProvider<List<Movie>>((ref) async {
  try {
    final r = await ref.read(apiProvider).listByType('phim-bo', page: 1);
    if (r.items.isNotEmpty) return r.items.take(30).toList();
  } catch (_) {}
  // Dự phòng: nếu nguồn không có 'phim-bo' thì dùng phim mới cập nhật.
  final l = await ref.read(apiProvider).latest(page: 1);
  return l.items.take(30).toList();
});

// --- Home rows ---
final latestProvider =
    FutureProvider<Paginated<Movie>>((ref) => ref.read(apiProvider).latest());

// Danh sách phim mới cập nhật (dạng List) — dùng cho gợi ý ở trang Tìm kiếm.
final latestListProvider = FutureProvider<List<Movie>>(
    (ref) async => (await ref.read(apiProvider).latest(page: 1)).items.take(20).toList());

final typeRowProvider = FutureProvider.family<List<Movie>, String>(
    (ref, type) async => (await ref.read(apiProvider).listByType(type)).items);

final genreRowProvider = FutureProvider.family<List<Movie>, String>(
    (ref, slug) async => (await ref.read(apiProvider).byGenre(slug)).items);

final countryRowProvider = FutureProvider.family<List<Movie>, String>(
    (ref, slug) async => (await ref.read(apiProvider).byCountry(slug)).items);

// --- Detail ---
final detailProvider = FutureProvider.family<MovieDetail, String>(
    (ref, slug) => ref.read(apiProvider).detail(slug));

/// Lựa chọn phát LẤY THÊM từ các nguồn KHÁC (cùng bộ phim, tìm theo tên).
///
/// Tách riêng khỏi [detailProvider] để trang chi tiết hiện ngay bằng nguồn
/// chính, nguồn phụ tìm được lúc nào thì thêm chip lúc đó.
final alternateSourcesProvider =
    FutureProvider.family<List<StreamSource>, String>((ref, slug) async {
  final d = await ref.watch(detailProvider(slug).future);
  final own = sourceOfSlug(slug);
  final others = ref
      .watch(allSourcesProvider)
      .where((s) => s.id != own && ref.watch(enabledSourcesProvider).contains(s.id))
      .toList();
  if (others.isEmpty) return [];
  return alternateStreamSources(primary: d, others: others);
});

// Ảnh nền độ phân giải cao (TMDB) cho banner trang chi tiết
final backdropProvider = FutureProvider.family<String?, String>((ref, query) async {
  final key = ref.watch(tmdbKeyProvider);
  if (key.isEmpty) return null;
  return TmdbApi(key).backdrop(query);
});

// Mã trailer YouTube (TMDB) theo tên phim — dùng cho hover tự chạy trailer
final trailerProvider = FutureProvider.family<String?, String>((ref, query) async {
  final key = ref.watch(tmdbKeyProvider);
  if (key.isEmpty) return null;
  return TmdbApi(key).trailerKey(query);
});

// Bỏ dấu tiếng Việt để so sánh (dùng chung với lớp nguồn phim).
String _stripDiacritics(String s) => stripDiacritics(s);

// Tên thể loại -> slug (vd "Cổ Trang" -> "co-trang")
String _genreSlug(String s) => _stripDiacritics(s)
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

// --- Search ---
final searchProvider = FutureProvider.family<List<Movie>, String>((ref, q) async {
  final query = q.trim();
  if (query.length < 2) return [];
  final res = await ref.read(apiProvider).search(query);
  final ql = query.toLowerCase();
  // Nguồn tìm KHÔNG phân biệt dấu (gõ "phàm nhân" vẫn ra "phạm nhân").
  // Nếu người dùng CÓ gõ dấu -> chỉ giữ phim khớp ĐÚNG dấu, loại phần sai dấu.
  final typedWithDiacritics = _stripDiacritics(query) != ql;
  var list = res;
  if (typedWithDiacritics) {
    final exact = res
        .where((m) => m.name.toLowerCase().contains(ql) || m.originalName.toLowerCase().contains(ql))
        .toList();
    if (exact.isNotEmpty) list = exact; // nếu lọc ra rỗng thì giữ nguyên để còn kết quả
  }
  // Xếp phim khớp sát tên lên đầu. So sánh theo bản ĐÃ BỎ DẤU để gõ không dấu
  // (vd "nguoi nhen") vẫn đưa đúng "Người Nhện" lên trước.
  final qs = _stripDiacritics(ql);
  int rank(Movie m) {
    final n = _stripDiacritics(m.name.toLowerCase());
    final o = _stripDiacritics(m.originalName.toLowerCase());
    if (n == qs) return 0;
    if (n.startsWith(qs)) return 1;
    if (n.contains(qs) || o.contains(qs)) return 2;
    return 3;
  }
  list.sort((a, b) => rank(a).compareTo(rank(b)));
  return list;
});

// --- Browse (phân trang, cuộn vô tận) ---
class BrowseQuery {
  final String kind; // 'type' | 'genre' | 'country' | 'year'
  final String value;
  const BrowseQuery(this.kind, this.value);
  @override
  bool operator ==(Object o) => o is BrowseQuery && o.kind == kind && o.value == value;
  @override
  int get hashCode => Object.hash(kind, value);
}

class BrowseState {
  final List<Movie> items;
  final int page, totalPage;
  final bool loading;
  BrowseState({required this.items, required this.page, required this.totalPage, required this.loading});
}

class BrowseNotifier extends StateNotifier<BrowseState> {
  final MovieSource api;
  final BrowseQuery q;
  BrowseNotifier(this.api, this.q)
      : super(BrowseState(items: [], page: 0, totalPage: 1, loading: false)) {
    loadMore();
  }

  Future<Paginated<Movie>> _fetchPage(int p) {
    switch (q.kind) {
      case 'all': return api.latest(page: p);
      case 'type': return api.listByType(q.value, page: p);
      case 'genre': return api.byGenre(q.value, page: p);
      case 'country': return api.byCountry(q.value, page: p);
      default: return api.byYear(q.value, page: p);
    }
  }

  // Tải NHIỀU trang song song (mặc định 3) cho nhanh — nhất là khi lọc tiếng
  // phải gom nhiều trang. Trang đầu tải 1 (chưa biết tổng số trang).
  Future<void> loadMore({int batch = 3}) async {
    if (state.loading || state.page >= state.totalPage) return;
    state = BrowseState(items: state.items, page: state.page, totalPage: state.totalPage, loading: true);
    final start = state.page + 1;
    final end = (start + batch - 1) <= state.totalPage ? (start + batch - 1) : state.totalPage;
    try {
      final results = await Future.wait([for (var p = start; p <= end; p++) _fetchPage(p)]);
      final newItems = results.expand((r) => r.items).toList();
      final total = results.isNotEmpty ? results.last.totalPage : state.totalPage;
      final newPage = end > total ? total : end;
      state = BrowseState(items: [...state.items, ...newItems], page: newPage, totalPage: total, loading: false);
    } catch (_) {
      state = BrowseState(items: state.items, page: state.page, totalPage: state.totalPage, loading: false);
    }
  }
}

final browseProvider = StateNotifierProvider.family<BrowseNotifier, BrowseState, BrowseQuery>(
    (ref, q) => BrowseNotifier(ref.read(apiProvider), q));
