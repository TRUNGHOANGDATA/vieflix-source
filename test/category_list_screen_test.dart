import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_xem_phim/data/nguonc_api.dart';
import 'package:app_xem_phim/models/movie.dart';
import 'package:app_xem_phim/models/movie_detail.dart';
import 'package:app_xem_phim/models/paginated.dart';
import 'package:app_xem_phim/state/providers.dart';
import 'package:app_xem_phim/screens/category_list_screen.dart';
import 'package:app_xem_phim/widgets/tv_filter_bar.dart';
import 'package:app_xem_phim/widgets/lang_filter_row.dart';

/// API giả: trả về rỗng ngay, không chạm mạng.
class _FakeApi extends NguoncApi {
  _FakeApi() : super();
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
  testWidgets('Trang "Xem tất cả" dùng bộ lọc TV mới (TvFilterBar) + LangFilterRow, '
      'không còn dropdown FilterBar cũ', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(_FakeApi())],
        child: const MaterialApp(
          home: CategoryListScreen(
            title: 'Phim Cổ Trang',
            query: BrowseQuery('genre', 'co-trang'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Bộ lọc TV mới hiện diện...
    expect(find.byType(TvFilterBar), findsOneWidget);
    // ...và hàng lọc loại tiếng dùng widget chung.
    expect(find.byType(LangFilterRow), findsOneWidget);

    // Các nút lọc kiểu TV hiển thị đúng nhãn (nhóm chưa chọn -> "Tất cả ...").
    expect(find.text('Tất cả Loại'), findsOneWidget);
    expect(find.text('Tất cả Quốc gia'), findsOneWidget);
    // Nhóm đang lọc (Thể loại = Cổ Trang) hiển thị giá trị đã chọn.
    expect(find.text('Cổ Trang'), findsOneWidget);

    // Các chip loại tiếng vẫn đầy đủ.
    expect(find.text('Mọi loại tiếng'), findsOneWidget);
    expect(find.text('Phụ đề'), findsOneWidget);
    expect(find.text('Thuyết minh'), findsOneWidget);
    expect(find.text('Lồng tiếng'), findsOneWidget);
  });
}
