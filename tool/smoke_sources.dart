// Kiểm tra nhanh lớp nguồn với API THẬT. Không phải test tự động.
// Chạy: dart run tool/smoke_sources.dart
import 'package:app_xem_phim/data/aggregate_source.dart';
import 'package:app_xem_phim/data/nguonc_api.dart';
import 'package:app_xem_phim/data/phimapi_source.dart';
import 'package:app_xem_phim/data/movie_source.dart';
import 'package:app_xem_phim/data/stream_sources.dart';
import 'package:app_xem_phim/models/stream_source.dart';

Future<void> main() async {
  final nguonc = NguoncApi();
  final phimapi = PhimApiSource();
  final agg = AggregateSource([nguonc, phimapi]);

  print('===== P1: gộp danh mục =====');
  for (final probe in <(String, Future<dynamic> Function())>[
    ('latest p1', () => agg.latest(page: 1)),
    ('type phim-bo', () => agg.listByType('phim-bo')),
    ('genre hai', () => agg.byGenre('hai')),
    ('genre vien-tuong', () => agg.byGenre('vien-tuong')),
    ('country han-quoc', () => agg.byCountry('han-quoc')),
  ]) {
    try {
      final r = await probe.$2();
      final items = r.items as List;
      final pa = items.where((m) => sourceOfSlug(m.slug) == kSrcPhimApi).length;
      print('${probe.$1.padRight(18)} ${items.length} phim '
          '(nguonc ${items.length - pa} / phimapi $pa), tổng trang ${r.totalPage}');
    } catch (e) {
      print('${probe.$1.padRight(18)} LỖI: $e');
    }
  }

  print('\n===== P2: gộp nguồn phát trong một phim =====');
  for (final slug in ['sep-chinh-la-than-tuong', 'pa:nguoi-nhen-hang-xom-than-thien']) {
    final own = sourceOfSlug(slug);
    final d = await agg.detail(slug);
    final primary = streamSourcesOf(d);
    final alt = await alternateStreamSources(
      primary: d,
      others: [nguonc, phimapi].where((s) => s.id != own).toList(),
    );
    final all = [...primary, ...alt];
    print('\n${d.name} (${d.year}) <${d.base.originalName}>');
    for (final s in all) {
      print('   ${s.label.padRight(24)} ${s.episodes.length} tập  '
          '${s.kind == StreamKind.hls ? 'hls+embed' : 'embed'}   vd tập: '
          '${s.episodes.isEmpty ? '-' : s.episodes.first.name}');
    }
    // Đổi nguồn giữa chừng: đang xem tập thứ 2 của nguồn đầu thì sang nguồn cuối là tập nào?
    if (all.length > 1 && all.first.episodes.length > 1) {
      final from = all.first, to = all.last;
      const idx = 1;
      final j = matchEpisodeIndex(from.episodes, idx, to.episodes);
      print('   đổi nguồn: "${from.label}" tập "${from.episodes[idx].name}" '
          '-> "${to.label}" ${j == null ? 'KHÔNG CÓ tập tương ứng' : 'tập "${to.episodes[j].name}"'}');
    }
  }
}
