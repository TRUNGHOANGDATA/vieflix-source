import 'package:app_xem_phim/data/aggregate_source.dart';
import 'package:app_xem_phim/data/nguonc_api.dart';
import 'package:app_xem_phim/data/phimapi_source.dart';
import 'package:app_xem_phim/data/movie_source.dart';

Future<void> main() async {
  final agg = AggregateSource([NguoncApi(), PhimApiSource()]);
  final cases = <(String, BrowseFilter)>[
    ('the loai + nam (ca 2 nguon)', BrowseFilter(genre: 'hanh-dong', year: '2024')),
    ('quoc gia + nam (ca 2 nguon)', BrowseFilter(country: 'han-quoc', year: '2024')),
    ('the loai + quoc gia (nguonc lui)', BrowseFilter(genre: 'hanh-dong', country: 'han-quoc')),
    ('3 chieu (chi phimapi)', BrowseFilter(type: 'phim-bo', genre: 'hanh-dong', country: 'han-quoc')),
  ];
  for (final c in cases) {
    try {
      final r = await agg.browse(c.$2, page: 1);
      final pa = r.items.where((m) => sourceOfSlug(m.slug) == kSrcPhimApi).length;
      print('${c.$1.padRight(38)} ${r.items.length} phim (nguonc ${r.items.length - pa} / phimapi $pa)');
    } catch (e) {
      print('${c.$1.padRight(38)} LOI: $e');
    }
  }
}
