import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_xem_phim/data/nguonc_api.dart';
import 'package:app_xem_phim/models/movie.dart';
import 'package:app_xem_phim/models/movie_detail.dart';
import 'package:app_xem_phim/models/paginated.dart';
import 'package:app_xem_phim/screens/browse_screen.dart';
import 'package:app_xem_phim/state/providers.dart';
import 'package:app_xem_phim/widgets/lang_filter_row.dart';
import 'package:app_xem_phim/widgets/tv_filter_bar.dart';

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

void main() {
  /// Dựng màn Thư viện trong khung đúng bằng vùng nội dung thật trên màn 1080p
  /// (1706x889 sau khi trừ thanh nav và thanh tiêu đề cửa sổ).
  Future<void> pumpBrowse(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1706, 889));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(_FakeApi())],
        child: const MaterialApp(home: Scaffold(body: BrowseScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ô tìm và 4 ô lọc nằm CHUNG MỘT HÀNG (không phải hai hàng)',
      (tester) async {
    await pumpBrowse(tester);
    final field = tester.getRect(find.byType(TextField));
    final filters = tester.getRect(find.byType(TvFilterBar));
    // Cùng hàng: hai khối phải trùng nhau theo chiều dọc.
    expect(filters.top, lessThan(field.bottom));
    expect(filters.bottom, greaterThan(field.top));
    // Và ô lọc phải nằm BÊN PHẢI ô tìm.
    expect(filters.left, greaterThan(field.right - 1));
  });

  testWidgets('cả khối lọc không được ăn quá 110px chiều cao — còn chỗ cho '
      'một hàng phim đầy đủ', (tester) async {
    await pumpBrowse(tester);
    // Đáy của hàng loại tiếng = đáy của toàn bộ khối lọc.
    final headerBottom = tester.getRect(find.byType(LangFilterRow)).bottom;
    expect(headerBottom, lessThan(110),
        reason: 'Khối lọc phình ra $headerBottom px. Thẻ phim cao ~350px nên '
            'khối lọc quá 110px là hàng phim bị cắt mất nửa dưới, nhất là trên TV.');
  });
}
