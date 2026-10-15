import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_xem_phim/data/local_store.dart';
import 'package:app_xem_phim/models/movie.dart';
import 'package:app_xem_phim/models/movie_detail.dart';
import 'package:app_xem_phim/screens/my_list_screen.dart';
import 'package:app_xem_phim/state/providers.dart';

void main() {
  testWidgets('bấm ✕ trên thẻ -> phim biến khỏi Yêu thích NGAY (không còn nằm lì)', (tester) async {
    // Thư viện đệm ảnh của thẻ phim đòi thư mục tạm (path_provider) — trả thư
    // mục tạm của máy chạy test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (call) async => Directory.systemTemp.path);
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    await tester.runAsync(store.init);
    await tester.runAsync(() => store.toggleFavorite(Movie.fromJson({
          'name': 'Thiên Thịnh Trường Ca', 'slug': 'thien-thinh-truong-ca',
          // Không link ảnh: test không có kho đệm ảnh (path_provider) để tải ảnh mạng.
        })));

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        // Thẻ thiếu ảnh sẽ hỏi thông tin phim -> cho treo ở "đang tải", không chạm mạng.
        detailProvider.overrideWith((ref, slug) => Completer<MovieDetail>().future),
      ],
      child: const MaterialApp(home: Scaffold(body: MyListScreen())),
    ));
    await tester.pump();
    expect(find.text('Thiên Thịnh Trường Ca'), findsOneWidget);

    await tester.tap(find.byTooltip('Bỏ khỏi yêu thích'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(store.isFavorite('thien-thinh-truong-ca'), isFalse);
    expect(find.text('Thiên Thịnh Trường Ca'), findsNothing);
    expect(find.textContaining('Chưa có phim yêu thích'), findsOneWidget);
  });
}
