import 'package:flutter_test/flutter_test.dart';
import 'package:app_xem_phim/data/movie_source.dart';

void main() {
  group('BrowseFilter', () {
    test('đếm chiều cấu trúc (không tính năm)', () {
      expect(const BrowseFilter().structuralCount, 0);
      expect(const BrowseFilter(year: '2024').structuralCount, 0);
      expect(const BrowseFilter(genre: 'hanh-dong', year: '2024').structuralCount, 1);
      expect(const BrowseFilter(genre: 'hanh-dong', country: 'han-quoc').structuralCount, 2);
      expect(const BrowseFilter(type: 'phim-bo', genre: 'a', country: 'b').structuralCount, 3);
    });

    test('copyWith đặt và xoá từng chiều độc lập', () {
      const f = BrowseFilter(genre: 'hanh-dong', country: 'han-quoc', year: '2024');
      expect(f.copyWith(genre: 'tinh-cam').genre, 'tinh-cam');
      expect(f.copyWith(clearCountry: true).country, isNull);
      // xoá country KHÔNG đụng các chiều khác
      final g = f.copyWith(clearCountry: true);
      expect(g.genre, 'hanh-dong');
      expect(g.year, '2024');
    });

    test('isEmpty', () {
      expect(const BrowseFilter().isEmpty, isTrue);
      expect(const BrowseFilter(year: '2024').isEmpty, isFalse);
    });

    test('== và hashCode để dùng làm khoá provider.family', () {
      expect(const BrowseFilter(genre: 'a', year: '2024'),
          const BrowseFilter(genre: 'a', year: '2024'));
      expect(const BrowseFilter(genre: 'a').hashCode,
          const BrowseFilter(genre: 'a').hashCode);
      expect(const BrowseFilter(genre: 'a') == const BrowseFilter(genre: 'b'), isFalse);
    });
  });
}
