import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_xem_phim/data/local_store.dart';
import 'package:app_xem_phim/models/movie.dart';

Movie _mv(String slug) => Movie.fromJson({'name': slug, 'slug': slug, 'total_episodes': 1});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toggleFavorite thêm rồi xóa', () async {
    final s = LocalStore();
    await s.init();
    expect(s.isFavorite('a'), false);
    await s.toggleFavorite(_mv('a'));
    expect(s.isFavorite('a'), true);
    expect(s.favorites.length, 1);
    await s.toggleFavorite(_mv('a'));
    expect(s.isFavorite('a'), false);
  });

  test('favorites bền qua lần init mới', () async {
    final s1 = LocalStore();
    await s1.init();
    await s1.toggleFavorite(_mv('b'));
    final s2 = LocalStore();
    await s2.init();
    expect(s2.isFavorite('b'), true);
  });

  test('saveProgress lưu và đọc lại, continueWatching mới nhất trước', () async {
    final s = LocalStore();
    await s.init();
    await s.saveProgress(slug: 'x', server: 'Vietsub #1', episodeSlug: 'tap-3', episodeName: '3');
    await Future.delayed(const Duration(milliseconds: 5));
    await s.saveProgress(slug: 'y', server: 'Vietsub #1', episodeSlug: 'tap-1', episodeName: '1');
    expect(s.progressFor('x')!.episodeName, '3');
    expect(s.continueWatching.first.slug, 'y'); // lưu sau -> đứng trước
  });

  test('saveProgress giữ vị trí cũ khi vẫn ở đúng tập đó', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    await store.init();

    await store.saveProgress(
        slug: 'pa:phim', server: 'Vietsub', episodeSlug: 'tap-05',
        episodeName: 'Tập 05', name: 'Phim');
    await store.savePosition('pa:phim', 600, 2400);
    expect(store.progressFor('pa:phim')!.positionSeconds, 600);

    // Bấm phát lại ĐÚNG tập đó -> không được xoá chỗ đang xem dở.
    await store.saveProgress(
        slug: 'pa:phim', server: 'Vietsub', episodeSlug: 'tap-05',
        episodeName: 'Tập 05', name: 'Phim');
    expect(store.progressFor('pa:phim')!.positionSeconds, 600);
    expect(store.progressFor('pa:phim')!.durationSeconds, 2400);

    // Sang tập KHÁC thì phải về 0.
    await store.saveProgress(
        slug: 'pa:phim', server: 'Vietsub', episodeSlug: 'tap-06',
        episodeName: 'Tập 06', name: 'Phim');
    expect(store.progressFor('pa:phim')!.positionSeconds, 0);
  });

  test('tìm kiếm gần đây: mới nhất lên đầu, gộp trùng, tối đa 8, xoá được', () async {
    final s = LocalStore();
    await s.init();
    for (final k in ['a1', 'b2', 'c3']) {
      await s.addRecentSearch(k);
    }
    await s.addRecentSearch('A1'); // trùng (khác hoa thường) -> lên đầu, không nhân đôi
    expect(s.recentSearches, ['A1', 'c3', 'b2']);
    await s.addRecentSearch('x'); // quá ngắn -> bỏ qua
    for (var i = 0; i < 10; i++) {
      await s.addRecentSearch('k$i');
    }
    expect(s.recentSearches.length, 8);
    await s.removeRecentSearch('k9');
    expect(s.recentSearches.first, 'k8');
    await s.clearRecentSearches();
    expect(s.recentSearches, isEmpty);
  });
}
