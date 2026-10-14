import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_xem_phim/data/local_store.dart';
import 'package:app_xem_phim/models/movie_detail.dart';
import 'package:app_xem_phim/models/stream_source.dart';
import 'package:app_xem_phim/screens/detail_screen.dart';
import 'package:app_xem_phim/state/providers.dart';

/// Phim kiểu Running Man: 1700 tập -> trang chi tiết phải chia khoảng 100 tập,
/// chỉ dựng nút cho khoảng đang chọn.
void main() {
  testWidgets('phim 1700 tập: có hàng chọn khoảng, bấm khoảng nào hiện tập khoảng đó',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    await tester.runAsync(store.init);

    final detail = MovieDetail.fromJson({
      'name': 'Running Man', 'slug': 'running-man', 'original_name': '',
      'thumb_url': '', 'poster_url': '', 'description': '',
      'total_episodes': 1700, 'current_episode': 'Tập 1700',
      'episodes': [
        {
          'server_name': 'Vietsub #1',
          'items': [for (var i = 1; i <= 1700; i++) {'name': 'Tập $i', 'slug': 'tap-$i', 'm3u8': 'http://x/$i.m3u8'}],
        },
      ],
    });

    await tester.binding.setSurfaceSize(const Size(1706, 889));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        detailProvider.overrideWith((ref, slug) async => detail),
        alternateSourcesProvider.overrideWith((ref, slug) async => <StreamSource>[]),
      ],
      child: const MaterialApp(home: DetailScreen(slug: 'running-man', title: 'Running Man')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1–100'), findsOneWidget);
    expect(find.text('1601–1700'), findsOneWidget);
    // Mặc định khoảng đầu: có Tập 1, KHÔNG dựng Tập 101 (đỡ 1600 nút).
    expect(find.text('Tập 1'), findsOneWidget);
    expect(find.text('Tập 101'), findsNothing);

    await tester.ensureVisible(find.text('1601–1700'));
    await tester.tap(find.text('1601–1700'));
    await tester.pump();
    expect(find.text('Tập 1700'), findsOneWidget);
    expect(find.text('Tập 1'), findsNothing);
  });
}
