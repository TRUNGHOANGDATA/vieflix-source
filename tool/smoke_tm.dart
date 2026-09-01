import 'package:app_xem_phim/data/nguonc_api.dart';
import 'package:app_xem_phim/data/phimapi_source.dart';
import 'package:app_xem_phim/data/stream_sources.dart';
import 'package:app_xem_phim/models/stream_source.dart';

Future<void> main() async {
  final nguonc = NguoncApi();
  final phimapi = PhimApiSource();
  final list = await nguonc.latest(page: 1);
  int miss = 0, total = 0;
  for (final m in list.items) {
    try {
      final d = await nguonc.detail(m.slug);
      final primary = streamSourcesOf(d);
      final hasTMprimary = primary.any((s) => s.lang == 'Thuyết minh');
      final alt = await alternateStreamSources(primary: d, others: [phimapi]);
      final hasTMalt = alt.any((s) => s.lang == 'Thuyết minh');
      final altFound = alt.isNotEmpty;
      total++;
      // "sot TM" = primary khong co TM, va (khong tim thay nguon khac HOAC nguon khac co TM nhung...)
      final combined = [...primary, ...alt].any((s) => s.lang == 'Thuyết minh');
      final flag = (!hasTMprimary && !combined) ? '' : (!hasTMprimary && combined ? '  [TM chi co o phimapi]' : '');
      if (!altFound && !hasTMprimary) { miss++; }
      print('${m.name.substring(0,m.name.length>30?30:m.name.length).padRight(30)} '
          'primaryTM=$hasTMprimary altFound=$altFound altTM=$hasTMalt$flag');
    } catch (_) {}
  }
  print('\nTong $total phim | so phim KHONG tim thay nguon khac (co the sot TM): $miss');
}
