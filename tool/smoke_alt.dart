import 'package:app_xem_phim/data/nguonc_api.dart';
import 'package:app_xem_phim/data/phimapi_source.dart';
import 'package:app_xem_phim/data/stream_sources.dart';

Future<void> main() async {
  final nguonc = NguoncApi();
  final phimapi = PhimApiSource();
  // vai phim nguonc chi co Vietsub nhung phimapi co TM
  for (final slug in ['lau-dai-tham-vong-ban-thai', 'sep-chinh-la-than-tuong']) {
    try {
      final d = await nguonc.detail(slug);
      final primary = streamSourcesOf(d);
      final alt = await alternateStreamSources(primary: d, others: [phimapi]);
      print('\n${d.name}  <${d.base.originalName}> nam=${d.year}');
      print('  primary (nguonc): ${primary.map((s) => s.label).toList()}');
      print('  alt (phimapi):    ${alt.map((s) => s.label).toList()}');
      final all = [...primary, ...alt];
      print('  => co TM khong: ${all.any((s) => s.lang == "Thuyết minh")}');
    } catch (e) {
      print('$slug LOI: $e');
    }
  }
}
