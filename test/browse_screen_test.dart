import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_xem_phim/data/local_store.dart';
import 'package:app_xem_phim/data/nguonc_api.dart';
import 'package:app_xem_phim/models/movie.dart';
import 'package:app_xem_phim/models/movie_detail.dart';
import 'package:app_xem_phim/models/paginated.dart';
import 'package:app_xem_phim/screens/browse_screen.dart';
import 'package:app_xem_phim/state/providers.dart';
import 'package:app_xem_phim/widgets/lang_filter_row.dart';
import 'package:app_xem_phim/widgets/multi_filter_bar.dart';

/// API giả: trả rỗng ngay, không chạm mạng.
class _FakeApi extends NguoncApi {
  Paginated<Movie> _empty() => Paginated(items: [], currentPage: 1, totalPage: 1);
  @override
  Future<Paginated<Movie>> latest({int page = 1}) async => _empty();
  @override
  Future<Paginated<Movie>> listByType(String type, {int page = 1}) async => _empty();
  @override
  Future<Paginated<Movie>> byGenre(String slug, {int page = 1}) async => _empty();
  @override
  Future<Paginated<Movie>> byCountry(String slug, {int page = 1}) async => _empty();
  @override
  Future<Paginated<Movie>> byYear(String year, {int page = 1}) async => _empty();
  @override
  Future<List<Movie>> search(String keyword) async => [];
  @override
  Future<MovieDetail> detail(String slug) async => throw UnimplementedError();
}

/// Kho lưu giả (SharedPreferences rỗng) — màn Thư viện đọc "Tìm kiếm gần đây".
Future<LocalStore> _store(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final s = LocalStore();
  await tester.runAsync(s.init);
  return s;
}

void main() {
  /// Dựng màn Thư viện trong khung đúng bằng vùng nội dung thật trên màn 1080p
  /// (1706x889 sau khi trừ thanh nav và thanh tiêu đề cửa sổ).
  Future<void> pumpBrowse(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1706, 889));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(_FakeApi()),
          storeProvider.overrideWithValue(await _store(tester)),
        ],
        child: const MaterialApp(home: Scaffold(body: BrowseScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mở từ ô tìm trên menu (cờ đang gõ bật sẵn) -> con trỏ vào thẳng ô gõ',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1706, 889));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(overrides: [
      apiProvider.overrideWithValue(_FakeApi()),
      storeProvider.overrideWithValue(await _store(tester)),
    ]);
    addTearDown(container.dispose);
    container.read(searchTypingProvider.notifier).state = true;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: BrowseScreen())),
    ));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets('bố cục mới: ô tìm to nằm TRÊN khung bộ lọc, có hàng "Tìm kiếm phổ biến"',
      (tester) async {
    await pumpBrowse(tester);
    final field = tester.getRect(find.byType(TextField));
    final filters = tester.getRect(find.byType(MultiFilterBar));
    expect(field.bottom, lessThan(filters.top));
    // Khung ô tìm (Container bọc ngay ngoài TextField) to theo mẫu, không còn bị nén.
    final box = tester.getRect(find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first);
    expect(box.height, greaterThan(50));
    expect(find.text('Tìm kiếm phổ biến'), findsOneWidget);
    expect(find.text('Phim Trung Quốc'), findsOneWidget);
  });

  testWidgets('cả trang cuộn liền một khối (phần đầu cuộn đi cùng kết quả)', (tester) async {
    await pumpBrowse(tester);
    // Ô tìm + khung lọc nằm TRONG CustomScrollView của trang -> cuộn đi được,
    // không còn chiếm cố định chiều cao màn hình như bản cũ.
    expect(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(TextField)), findsOneWidget);
    expect(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(LangFilterRow)), findsOneWidget);
  });

  testWidgets('chọn lọc tiếng -> chuyển sang lưới cuộn-tải-thêm, KHÔNG lọc trên '
      '20 phim gợi ý', (tester) async {
    await pumpBrowse(tester);
    // Ban đầu: hub gợi ý, chưa có lưới.
    expect(find.byType(SliverGrid), findsNothing);

    await tester.ensureVisible(find.text('Thuyết minh'));
    await tester.tap(find.text('Thuyết minh'));
    await tester.pumpAndSettle();

    // Sau khi chọn: phải là lưới (nguồn của lưới gom nhiều trang nên lọc ra đủ
    // phim, thay vì chỉ lọc trên 20 phim của hàng gợi ý). Nguồn giả rỗng nên
    // lưới chưa có thẻ nào — tiêu đề khối kết quả lọc là đủ chứng minh.
    expect(find.text('Kết quả lọc'), findsOneWidget);
  });

  testWidgets('bấm "Phim Trung Quốc" ở Tìm kiếm phổ biến -> sang chế độ lọc', (tester) async {
    await pumpBrowse(tester);
    await tester.tap(find.text('Phim Trung Quốc'));
    await tester.pumpAndSettle();
    expect(find.text('Kết quả lọc'), findsOneWidget);
  });

  testWidgets('có phim xu hướng + lịch sử tìm: trang vẽ được, KHÔNG trống trơn', (tester) async {
    // Lỗi 15/10/2026: ô Xu hướng (LayoutBuilder) bị bọc IntrinsicHeight -> lỗi vẽ,
    // cả trang Thư viện trống. Test cũ không bắt được vì nguồn giả trả rỗng.
    await tester.binding.setSurfaceSize(const Size(1706, 889));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final movies = [
      for (var i = 1; i <= 6; i++) Movie.fromJson({'name': 'Phim $i', 'slug': 'p$i', 'quality': 'FHD'}),
    ];
    SharedPreferences.setMockInitialValues({'recent_search_v1': ['running man', 'tru tien']});
    final store = LocalStore();
    await tester.runAsync(store.init);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(_FakeApi()),
        storeProvider.overrideWithValue(store),
        topSeriesProvider.overrideWith((ref) async => movies),
        latestListProvider.overrideWith((ref) async => movies),
      ],
      child: const MaterialApp(home: Scaffold(body: BrowseScreen())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('Xu hướng hôm nay'), findsOneWidget);
    expect(find.text('running man'), findsOneWidget);
    expect(find.text('Phim 1'), findsWidgets);
  });
}
