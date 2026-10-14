import 'package:flutter_test/flutter_test.dart';
import 'package:app_xem_phim/models/episode.dart';
import 'package:app_xem_phim/screens/detail_screen.dart';

void main() {
  List<Episode> eps(Iterable<String> names) =>
      [for (final n in names) Episode.fromJson({'name': n, 'slug': n, 'link_embed': '', 'link_m3u8': ''})];

  test('phim 1700 tập chia thành 17 khoảng 100 tập, nhãn theo số tập', () {
    final p = episodePages(eps([for (var i = 1; i <= 1700; i++) 'Tập $i']));
    expect(p.length, 17);
    expect(p.first.label, '1–100');
    expect(p.last.label, '1601–1700');
    expect((p.last.start, p.last.end), (1600, 1700));
  });

  test('khoảng cuối lẻ + phim ít tập chỉ có một khoảng', () {
    final p = episodePages(eps([for (var i = 1; i <= 205; i++) '$i']));
    expect(p.map((e) => e.label), ['1–100', '101–200', '201–205']);
    expect(episodePages(eps(['Full'])).single.label, '1');
  });
}
