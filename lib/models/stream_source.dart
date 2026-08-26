import 'episode.dart';

/// Cách phát của một nguồn.
enum StreamKind {
  /// Nhúng trang web của nguồn (WebView).
  embed,

  /// Có link video trực tiếp (HLS m3u8) — dành cho trình phát native.
  hls,
}

/// MỘT lựa chọn phát của một bộ phim.
///
/// Với các site này, "Thuyết minh" và "Vietsub" là HAI BẢN UPLOAD KHÁC NHAU
/// chứ không phải hai đường tiếng trong cùng một file. Nên đổi nguồn và đổi
/// tiếng thật ra là cùng một thao tác: chọn một [StreamSource] khác.
class StreamSource {
  /// Nguồn giữ bản này: `nguonc` | `phimapi`.
  final String provider;

  /// Slug của phim Ở NGUỒN ĐÓ (khác nhau giữa hai nguồn).
  final String movieSlug;

  /// Tên server do nguồn đặt, vd `Vietsub #1`, `Thuyết Minh`.
  final String serverName;

  /// Loại tiếng rút gọn để hiện lên chip.
  final String lang;

  final StreamKind kind;
  final List<Episode> episodes;

  StreamSource({
    required this.provider,
    required this.movieSlug,
    required this.serverName,
    required this.lang,
    required this.kind,
    required this.episodes,
  });

  /// Nhãn hiện trên chip chọn nguồn, vd `phimapi · Thuyết minh`.
  String get label => '$provider · $lang';
}

/// Rút loại tiếng từ tên server. Không nhận ra thì trả lại chính tên server.
String langOfServer(String serverName) {
  final n = serverName.toLowerCase();
  if (n.contains('thuyết minh') || n.contains('thuyet minh') || n.contains('t.minh')) {
    return 'Thuyết minh';
  }
  if (n.contains('lồng tiếng') || n.contains('long tieng')) return 'Lồng tiếng';
  if (n.contains('vietsub') || n.contains('phụ đề') || n.contains('phu de')) {
    return 'Vietsub';
  }
  return serverName.trim().isEmpty ? 'Mặc định' : serverName.trim();
}

/// Số tập rút từ tên tập (`Tập 01` -> 1, `3` -> 3, `Full` -> null).
int? episodeNumber(String name) {
  final m = RegExp(r'\d+').firstMatch(name);
  return m == null ? null : int.tryParse(m.group(0)!);
}

/// Tìm tập TƯƠNG ỨNG khi đổi nguồn giữa chừng.
///
/// Hai nguồn đặt tên tập khác nhau (`Tập 01` vs `1`) và có thể lệch số tập, nên
/// map theo SỐ tập chứ không theo vị trí. Không tìm được thì trả null để màn
/// hình báo rõ — thà báo còn hơn phát nhầm sang tập khác.
int? matchEpisodeIndex(List<Episode> from, int index, List<Episode> to) {
  if (to.isEmpty) return null;
  if (index < 0 || index >= from.length) return null;
  // Phim lẻ hai bên đều một tập -> khỏi so số.
  if (from.length == 1 && to.length == 1) return 0;

  final want = episodeNumber(from[index].name);
  if (want != null) {
    for (int i = 0; i < to.length; i++) {
      if (episodeNumber(to[i].name) == want) return i;
    }
    return null;
  }
  // Không bên nào đánh số (tên kiểu "Full", "Phần 1"...) -> đành theo vị trí.
  final noNumbers = to.every((e) => episodeNumber(e.name) == null);
  if (noNumbers && index < to.length) return index;
  return null;
}
