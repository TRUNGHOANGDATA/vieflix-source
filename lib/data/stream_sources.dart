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
  // Hai tầng ưu tiên:
  //   1) LOẠI TIẾNG (quan trọng nhất): Thuyết minh > Lồng tiếng > còn lại.
  //   2) Trong CÙNG loại tiếng: bản phát thẳng (hls, vd phimapi) trước bản nhúng
  //      (embed, vd nguonc) vì mở nhanh hơn nhiều và không dính quảng cáo.
  // Nhờ vậy Thuyết minh LUÔN thắng; chỉ khi đồng hạng tiếng mới xét tốc độ.
  int langRank(String lang) {
    if (lang == 'Thuyết minh') return 0;
    if (lang == 'Lồng tiếng') return 1;
    return 2;
  }
  int best = 0, bestLang = 99, bestKind = 99;
  for (int i = 0; i < servers.length; i++) {
    final lr = langRank(servers[i].lang);
    final kr = servers[i].kind == StreamKind.hls ? 0 : 1;
    if (lr < bestLang || (lr == bestLang && kr < bestKind)) {
      best = i;
      bestLang = lr;
      bestKind = kr;
    }
  }
  return best;
}

/// Vị trí cần tua tới khi bấm "Xem tiếp", tính bằng giây (0 = phát từ đầu).
///
/// nguonc TỰ NHỚ vị trí trong trang embed của nó: mở lại là hiện hộp "Bạn đã
/// dừng lại ở ..." và app bấm hộ. Tua đè lên sẽ đá nhau với cơ chế đó, nên
/// nguồn này trả về 0. Mọi nguồn khác — và cả đường phát thẳng m3u8, vốn không
/// có trang web nào để mà nhớ — thì app phải tự tua.
///
/// Gần hết tập thì coi như xem xong, phát lại từ đầu thay vì nhảy vào đoạn
/// giới thiệu cuối phim.
double resumePosition({
  required String provider,
  required double positionSeconds,
  required double durationSeconds,
  double endGuardSeconds = 45,
  double minSeconds = 5,
}) {
  if (provider == kSrcNguonc) return 0;
  if (positionSeconds < minSeconds) return 0;
  if (durationSeconds > 0 && positionSeconds > durationSeconds - endGuardSeconds) {
    return 0;
  }
  return positionSeconds;
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
  final want = nameCandidates(primary.base);
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

Movie? _bestMatch(List<Movie> found, Set<String> want, String year) {
  Movie? nameOnly;
  for (final m in found) {
    // Khớp khi TẬP tên giao nhau ở ít nhất một tên (so ĐÚNG cả tên, không phải
    // chứa chuỗi, để "Conan" không dính "Conan 21: ...").
    if (nameCandidates(m).intersection(want).isEmpty) continue;
    final y = m.year.trim();
    if (year.isNotEmpty && y.isNotEmpty && y == year) return m; // khớp cả năm -> chắc
    if (year.isNotEmpty && y.isNotEmpty && y != year) continue; // năm lệch -> bỏ
    nameOnly ??= m;
  }
  return nameOnly;
}
