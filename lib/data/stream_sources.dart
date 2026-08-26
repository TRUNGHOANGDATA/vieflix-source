import '../models/movie.dart';
import '../models/movie_detail.dart';
import '../models/stream_source.dart';
import 'movie_source.dart';

/// Các lựa chọn phát lấy từ CHI TIẾT một phim (một nguồn -> N server).
List<StreamSource> streamSourcesOf(MovieDetail d) {
  final provider = sourceLabel(sourceOfSlug(d.slug));
  return [
    for (final s in d.servers)
      if (s.items.isNotEmpty)
        StreamSource(
          provider: provider,
          movieSlug: d.slug,
          serverName: s.serverName,
          lang: langOfServer(s.serverName),
          kind: s.items.any((e) => e.m3u8.isNotEmpty)
              ? StreamKind.hls
              : StreamKind.embed,
          episodes: s.items,
        ),
  ];
}

/// Nguồn phát mặc định khi mở một phim.
///
/// Giữ thói quen cũ là ưu tiên tiếng Việt (Thuyết minh / Lồng tiếng); trong
/// cùng loại tiếng thì ưu tiên bản có link phát thẳng (m3u8) vì phát bằng trình
/// phát của app, không phải trang embed.
int defaultSourceIndex(List<StreamSource> servers) {
  int? viet, vietHls, hls;
  for (int i = 0; i < servers.length; i++) {
    final s = servers[i];
    final isViet = s.lang == 'Thuyết minh' || s.lang == 'Lồng tiếng';
    final isHls = s.kind == StreamKind.hls;
    if (isViet && isHls) vietHls ??= i;
    if (isViet) viet ??= i;
    if (isHls) hls ??= i;
  }
  return vietHls ?? viet ?? hls ?? 0;
}

/// Tìm CÙNG bộ phim đó ở một nguồn khác rồi lấy thêm lựa chọn phát.
///
/// Nguồn kia đặt slug khác nên phải tìm theo tên: tìm kiếm bằng tên gốc (không
/// có thì tên tiếng Việt), rồi chỉ nhận kết quả khớp [mergeName]. Năm chỉ dùng
/// để loại bớt khi CẢ HAI bên đều có năm — vài endpoint không trả năm.
Future<List<StreamSource>> alternateStreamSources({
  required MovieDetail primary,
  required List<MovieSource> others,
}) async {
  final want = mergeName(primary.base);
  if (want.isEmpty) return [];
  final keyword =
      primary.base.originalName.trim().isNotEmpty ? primary.base.originalName : primary.name;
  final year = (primary.year ?? primary.base.year).trim();

  final lists = await Future.wait(others.map((s) async {
    try {
      final found = await s.search(keyword);
      final hit = _bestMatch(found, want, year);
      if (hit == null) return <StreamSource>[];
      return streamSourcesOf(await s.detail(hit.slug));
    } catch (_) {
      // Nguồn kia không có phim này / lỗi mạng: bỏ qua, đừng làm hỏng trang.
      return <StreamSource>[];
    }
  }));
  return lists.expand((e) => e).toList();
}

Movie? _bestMatch(List<Movie> found, String want, String year) {
  Movie? sameName;
  for (final m in found) {
    if (mergeName(m) != want) continue;
    final y = m.year.trim();
    // Khớp cả năm là chắc nhất -> nhận ngay.
    if (year.isNotEmpty && y.isNotEmpty && y == year) return m;
    sameName ??= m;
  }
  // Chỉ khớp tên: nhận, trừ khi năm hai bên đều có và lệch nhau.
  if (sameName != null) {
    final y = sameName.year.trim();
    if (year.isNotEmpty && y.isNotEmpty && y != year) return null;
  }
  return sameName;
}
