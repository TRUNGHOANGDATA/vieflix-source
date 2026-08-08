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
}
