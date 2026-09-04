import 'package:flutter_test/flutter_test.dart';
import 'package:app_xem_phim/data/movie_source.dart';
import 'package:app_xem_phim/state/providers.dart';

void main() {
  List<String> loc(List<String> slugs, Set<String> bat) =>
      onlyEnabledSources(slugs, bat, (s) => s).toList();

  test('tắt nguonc thì phim nguonc biến mất, phimapi ở lại', () {
    final ds = ['man-giang-hong', '${kPhimApiPrefix}sep-chinh-la-than-tuong'];
    expect(loc(ds, {kSrcPhimApi}), ['${kPhimApiPrefix}sep-chinh-la-than-tuong']);
  });

  test('bật cả hai thì giữ nguyên thứ tự, không mất gì', () {
    final ds = ['a', '${kPhimApiPrefix}b', 'c'];
    expect(loc(ds, {kSrcNguonc, kSrcPhimApi}), ds);
  });

  test('tắt hết thì rỗng — và KHÔNG xoá gì, chỉ là danh sách hiện ra rỗng', () {
    expect(loc(['a', '${kPhimApiPrefix}b'], {}), isEmpty);
  });

  test('tắt phimapi thì chỉ còn nguonc', () {
    expect(loc(['a', '${kPhimApiPrefix}b'], {kSrcNguonc}), ['a']);
  });
}
