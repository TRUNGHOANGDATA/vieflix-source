import '../models/movie.dart';
import '../models/movie_detail.dart';
import '../models/paginated.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}

/// Mã nhà cung cấp phim.
const kSrcNguonc = 'nguonc';
const kSrcPhimApi = 'phimapi';

/// Slug của phimapi được gắn tiền tố để phân biệt với slug của nguonc.
/// Nhờ vậy mọi chỗ trong app (yêu thích, đang xem, mở chi tiết) vẫn chỉ cần
/// MỘT chuỗi slug như cũ mà không lẫn phim của hai nguồn.
const kPhimApiPrefix = 'pa:';

/// Nguồn nào giữ phim này, đọc từ slug.
String sourceOfSlug(String slug) =>
    slug.startsWith(kPhimApiPrefix) ? kSrcPhimApi : kSrcNguonc;

/// Tên hiển thị của nguồn.
String sourceLabel(String id) => id == kSrcPhimApi ? 'phimapi' : 'nguonc';

/// Các phép lấy dữ liệu mà app đang dùng. Mỗi nhà cung cấp là một hiện thực.
abstract class MovieSource {
  String get id;

  Future<Paginated<Movie>> latest({int page = 1});
  Future<Paginated<Movie>> listByType(String type, {int page = 1});
  Future<Paginated<Movie>> byGenre(String slug, {int page = 1});
  Future<Paginated<Movie>> byCountry(String slug, {int page = 1});
  Future<Paginated<Movie>> byYear(String year, {int page = 1});
  Future<List<Movie>> search(String keyword);
  Future<MovieDetail> detail(String slug);

  /// Lọc GHÉP nhiều chiều (màn Thư viện). Nguồn không kham được combo này thì
  /// NÉM lỗi để [AggregateSource] bỏ qua nó (không kéo cả danh mục xuống).
  Future<Paginated<Movie>> browse(BrowseFilter filter, {int page = 1});
}

/// Bỏ dấu tiếng Việt (dùng để so tên phim giữa hai nguồn).
String stripDiacritics(String s) {
  const from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    final i = from.indexOf(c);
    buf.write(i >= 0 ? to[i] : c);
  }
  return buf.toString();
}

/// Tên dùng để nhận ra MỘT bộ phim giữa hai nguồn.
///
/// Slug hai bên KHÔNG giống nhau (vd cùng phim: nguonc `sep-chinh-la-than-tuong`
/// vs phimapi `sep-chinh-la-than-tuong-bias-toi-sep-cua-toi`), nên so theo
/// **tên gốc (không có thì tên tiếng Việt) đã bỏ dấu**.
String mergeName(Movie m) {
  final raw = m.originalName.trim().isNotEmpty ? m.originalName : m.name;
  return stripDiacritics(raw).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Lọc trùng khi gộp danh sách của nhiều nguồn.
///
/// Cùng tên + cùng năm là cùng phim. Năm dùng để tách các mùa/bản làm lại trùng
/// tên. Nhưng có endpoint KHÔNG trả năm (vd tìm kiếm của nguonc) — lúc đó thà
/// coi cùng tên là cùng phim còn hơn để lọt một dòng trùng hiện ra trước mắt.
class MergeDedup {
  final _slugs = <String>{};
  final _yearsOf = <String, Set<String>>{};

  /// Trả về true nếu phim này CHƯA có (và ghi nhận lại).
  bool add(Movie m) {
    if (!_slugs.add(m.slug)) return false;
    final name = mergeName(m);
    if (name.isEmpty) return true;
    final year = m.year.trim();
    final seen = _yearsOf[name];
    if (seen != null &&
        (year.isEmpty || seen.contains('') || seen.contains(year))) {
      return false;
    }
    (_yearsOf[name] ??= <String>{}).add(year);
    return true;
  }
}

/// Bộ lọc GHÉP nhiều chiều cho màn Thư viện. Mỗi chiều có thể null (= không lọc).
///
/// phimapi lọc ghép được cả 4 chiều. nguonc chỉ lọc được MỘT chiều cấu trúc
/// (type/genre/country) phía máy chủ + lọc `year` phía app; ghép 2 chiều cấu
/// trúc trở lên thì nguonc không làm được (danh sách của nó không kèm thể loại/
/// quốc gia) — lúc đó [AggregateSource] để nguonc tự lui, phimapi gánh.
class BrowseFilter {
  final String? type;    // phim-bo / phim-le / hoat-hinh / tv-shows
  final String? genre;   // slug thể loại
  final String? country; // slug quốc gia
  final String? year;    // '2024'
  const BrowseFilter({this.type, this.genre, this.country, this.year});

  bool get isEmpty => type == null && genre == null && country == null && year == null;

  /// Số chiều CẤU TRÚC (không tính năm) — nguonc lọc server được tối đa 1.
  int get structuralCount =>
      (type != null ? 1 : 0) + (genre != null ? 1 : 0) + (country != null ? 1 : 0);

  BrowseFilter copyWith({
    String? type, String? genre, String? country, String? year,
    bool clearType = false, bool clearGenre = false,
    bool clearCountry = false, bool clearYear = false,
  }) =>
      BrowseFilter(
        type: clearType ? null : (type ?? this.type),
        genre: clearGenre ? null : (genre ?? this.genre),
        country: clearCountry ? null : (country ?? this.country),
        year: clearYear ? null : (year ?? this.year),
      );

  @override
  bool operator ==(Object o) =>
      o is BrowseFilter &&
      o.type == type && o.genre == genre && o.country == country && o.year == year;
  @override
  int get hashCode => Object.hash(type, genre, country, year);
}
