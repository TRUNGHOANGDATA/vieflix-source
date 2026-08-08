import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../widgets/movie_row.dart';
import '../widgets/hero_banner.dart';
import '../widgets/async_view.dart';
import '../theme/app_theme.dart';
import 'detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext c, String slug, String title) => Navigator.of(c).push(
      MaterialPageRoute(builder: (_) => DetailScreen(slug: slug, title: title)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestProvider);
    return AsyncView(
      value: latest,
      onRetry: () => ref.invalidate(latestProvider),
      builder: (page) {
        final movies = page.items;
        final hero = movies.isNotEmpty ? movies.first : null;
        return ListView(children: [
          if (hero != null)
            HeroBanner(
              movie: hero,
              onPlay: () => _open(context, hero.slug, hero.name),
              onInfo: () => _open(context, hero.slug, hero.name),
            ),
          _continueRow(ref, context),
          MovieRow(title: 'Mới cập nhật', movies: movies, onTap: (m) => _open(context, m.slug, m.name)),
          _typeRow(ref, context, 'Phim Bộ', 'phim-bo'),
          _typeRow(ref, context, 'Phim Lẻ', 'phim-le'),
          _typeRow(ref, context, 'Hoạt Hình', 'hoat-hinh'),
          _typeRow(ref, context, 'TV Shows', 'tv-shows'),
          _genreRow(ref, context, 'Hành Động', 'hanh-dong'),
          _genreRow(ref, context, 'Tình Cảm', 'tinh-cam'),
          const SizedBox(height: 40),
        ]);
      },
    );
  }

  Widget _continueRow(WidgetRef ref, BuildContext context) {
    final cw = ref.watch(storeProvider).continueWatching;
    if (cw.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text('Xem tiếp', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      SizedBox(
        height: 54,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final p in cw)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                backgroundColor: kSurface,
                avatar: const Icon(Icons.play_circle_fill, color: kRed),
                label: Text('${p.slug}  ·  Tập ${p.episodeName}', style: const TextStyle(color: Colors.white)),
                onPressed: () => _open(context, p.slug, p.slug),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _typeRow(WidgetRef ref, BuildContext c, String title, String type) {
    final v = ref.watch(typeRowProvider(type));
    return v.maybeWhen(
      data: (list) => MovieRow(title: title, movies: list, onTap: (m) => _open(c, m.slug, m.name)),
      orElse: () => const SizedBox(height: 8),
    );
  }

  Widget _genreRow(WidgetRef ref, BuildContext c, String title, String slug) {
    final v = ref.watch(genreRowProvider(slug));
    return v.maybeWhen(
      data: (list) => MovieRow(title: title, movies: list, onTap: (m) => _open(c, m.slug, m.name)),
      orElse: () => const SizedBox(height: 8),
    );
  }
}
