/// Lọc quảng cáo được chèn THẲNG vào luồng HLS.
///
/// Host của phimapi nhồi quảng cáo bằng cách chèn phân đoạn lạ vào giữa playlist,
/// bọc bằng `#EXT-X-DISCONTINUITY`. Vì quảng cáo nằm ngay trong luồng video nên
/// không có nút bỏ qua nào cả — trình phát coi nó là một phần của phim.
///
/// Cách nhận ra: phân đoạn của phim nằm CÙNG một thư mục, còn quảng cáo trỏ đi
/// chỗ khác (`convertv8/...` hoặc `/v8/<mã>/segment_0001.ts`). Nên lấy thư mục
/// có NHIỀU phân đoạn nhất làm thư mục phim, cái nào khác thư mục đó là quảng cáo.
/// Không đoán theo tên miền hay tên file, để host đổi cách đặt tên vẫn lọc được.
library;

class HlsFilterResult {
  /// Playlist đã bỏ quảng cáo, mọi phân đoạn đổi sang URL tuyệt đối.
  final String playlist;

  /// Số phân đoạn quảng cáo đã bỏ.
  final int removedSegments;

  /// Tổng thời lượng quảng cáo đã bỏ (giây).
  final double removedSeconds;

  const HlsFilterResult({
    required this.playlist,
    required this.removedSegments,
    required this.removedSeconds,
  });

  bool get hasAds => removedSegments > 0;
}

/// Thư mục chứa một URL (bỏ phần tên file).
String _dirOf(Uri u) {
  final segs = [...u.pathSegments];
  if (segs.isNotEmpty) segs.removeLast();
  return '${u.scheme}://${u.authority}/${segs.join('/')}';
}

/// Trả về null nếu đây không phải playlist phân đoạn (vd playlist master).
HlsFilterResult? filterHlsAds(String playlist, Uri base) {
  final lines = playlist.split('\n').map((l) => l.trimRight()).toList();
  if (!lines.any((l) => l.startsWith('#EXTINF'))) return null;

  // Đếm số phân đoạn theo từng thư mục.
  final count = <String, int>{};
  for (final l in lines) {
    if (l.isEmpty || l.startsWith('#')) continue;
    final dir = _dirOf(base.resolve(l));
    count[dir] = (count[dir] ?? 0) + 1;
  }
  if (count.isEmpty) return null;

  var movieDir = count.keys.first;
  for (final e in count.entries) {
    if (e.value > (count[movieDir] ?? 0)) movieDir = e.key;
  }

  final out = <String>[];
  var removed = 0;
  var removedSecs = 0.0;
  double? pendingDur; // #EXTINF đang chờ phân đoạn của nó
  var pendingTags = <String>[]; // các thẻ đi kèm chưa xuất ra
  var justCutAd = false; // vừa cắt quảng cáo -> bỏ luôn thẻ nối quay lại phim

  for (final line in lines) {
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTINF')) {
      pendingDur = double.tryParse(
              RegExp(r'#EXTINF:\s*([\d.]+)').firstMatch(line)?.group(1) ?? '') ??
          0;
      pendingTags.add(line);
      continue;
    }
    if (line.startsWith('#EXT-X-DISCONTINUITY')) {
      // Chỉ giữ nếu phân đoạn ngay sau nó được giữ lại.
      pendingTags.add(line);
      continue;
    }
    if (line.startsWith('#')) {
      // Thẻ khác (KEY, VERSION, ENDLIST...) giữ nguyên.
      out.addAll(pendingTags);
      pendingTags = [];
      out.add(line);
      continue;
    }

    // Tới đây là một phân đoạn.
    final abs = base.resolve(line);
    if (_dirOf(abs) != movieDir) {
      removed++;
      removedSecs += pendingDur ?? 0;
      pendingTags = []; // bỏ luôn #EXTINF và #EXT-X-DISCONTINUITY của nó
      pendingDur = null;
      justCutAd = true;
      continue;
    }
    // Cắt quảng cáo xong thì hai phân đoạn phim hai bên lại liền mạch (cùng một
    // bản mã hoá), nên thẻ DISCONTINUITY "quay lại phim" thành thừa. Để lại là
    // bảo trình phát dựng lại mốc thời gian vô cớ, dễ giật và sai thời lượng.
    if (justCutAd) {
      pendingTags.removeWhere((t) => t.startsWith('#EXT-X-DISCONTINUITY'));
      justCutAd = false;
    }
    out.addAll(pendingTags);
    pendingTags = [];
    pendingDur = null;
    out.add(abs.toString()); // URL tuyệt đối vì playlist sẽ nằm ở máy
  }
  out.addAll(pendingTags);

  // Bỏ DISCONTINUITY thừa: dính nhau, hoặc nằm ngay đầu/cuối.
  final cleaned = <String>[];
  for (final l in out) {
    final isDisc = l.startsWith('#EXT-X-DISCONTINUITY');
    if (isDisc) {
      final prevIsHeaderOnly = cleaned.every((x) => x.startsWith('#'));
      if (prevIsHeaderOnly) continue; // chưa có phân đoạn nào -> thừa
      if (cleaned.isNotEmpty &&
          cleaned.last.startsWith('#EXT-X-DISCONTINUITY')) {
        continue; // dính nhau
      }
    }
    cleaned.add(l);
  }
  while (cleaned.isNotEmpty &&
      cleaned.last.startsWith('#EXT-X-DISCONTINUITY')) {
    cleaned.removeLast();
  }

  return HlsFilterResult(
    playlist: '${cleaned.join('\n')}\n',
    removedSegments: removed,
    removedSeconds: removedSecs,
  );
}
