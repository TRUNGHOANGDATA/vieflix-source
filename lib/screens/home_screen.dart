import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../state/providers.dart';
import '../widgets/movie_row.dart';
import '../widgets/hero_banner.dart';
import '../widgets/async_view.dart';
import '../theme/app_theme.dart';
import 'detail_screen.dart';
import 'category_list_screen.dart';

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
          // Ưu tiên theo quốc gia
          _countryRow(ref, context, 'Phim Trung Quốc', 'trung-quoc'),
          _countryRow(ref, context, 'Phim Hàn Quốc', 'han-quoc'),
          _countryRow(ref, context, 'Phim Việt Nam', 'viet-nam'),
          _countryRow(ref, context, 'Phim Nhật Bản', 'nhat-ban'),
          _countryRow(ref, context, 'Phim Âu Mỹ', 'au-my'),
          // Rồi tới thể loại
          _genreRow(ref, context, 'Hành Động', 'hanh-dong'),
          _genreRow(ref, context, 'Tình Cảm', 'tinh-cam'),
          _genreRow(ref, context, 'Kinh Dị', 'kinh-di'),
          _genreRow(ref, context, 'Hài', 'hai'),
          _genreRow(ref, context, 'Cổ Trang', 'co-trang'),
          // Rồi tới loại phim
          _typeRow(ref, context, 'Hoạt Hình', 'hoat-hinh'),
          _typeRow(ref, context, 'TV Shows', 'tv-shows'),
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
        height: 104,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: cw.length,
          itemBuilder: (c, i) {
            final p = cw[i];
            return GestureDetector(
              onTap: () => _open(context, p.slug, p.name),
              child: Container(
                width: 300,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    child: SizedBox(
                      width: 130, height: 104,
                      child: p.poster.isNotEmpty
                          ? CachedNetworkImage(imageUrl: p.poster, fit: BoxFit.cover,
                              errorWidget: (c, _, __) => Container(color: Colors.black26, child: const Icon(Icons.movie, color: Colors.white24)))
                          : Container(color: Colors.black26, child: const Icon(Icons.movie, color: Colors.white24)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.play_circle_fill, color: kRed, size: 18),
                          const SizedBox(width: 4),
                          Text('Xem tiếp Tập ${p.episodeName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                      ]),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  void _seeMore(BuildContext c, String title, BrowseQuery q) => Navigator.of(c).push(
      MaterialPageRoute(builder: (_) => CategoryListScreen(title: title, query: q)));

  Widget _typeRow(WidgetRef ref, BuildContext c, String title, String type) {
    final v = ref.watch(typeRowProvider(type));
    return v.maybeWhen(
      data: (list) => MovieRow(
        title: title, movies: list, onTap: (m) => _open(c, m.slug, m.name),
        onSeeMore: () => _seeMore(c, title, BrowseQuery('type', type)),
      ),
      orElse: () => const SizedBox(height: 8),
    );
  }

  Widget _genreRow(WidgetRef ref, BuildContext c, String title, String slug) {
    final v = ref.watch(genreRowProvider(slug));
    return v.maybeWhen(
      data: (list) => MovieRow(
        title: title, movies: list, onTap: (m) => _open(c, m.slug, m.name),
        onSeeMore: () => _seeMore(c, title, BrowseQuery('genre', slug)),
      ),
      orElse: () => const SizedBox(height: 8),
    );
  }

  Widget _countryRow(WidgetRef ref, BuildContext c, String title, String slug) {
    final v = ref.watch(countryRowProvider(slug));
    return v.maybeWhen(
      data: (list) => MovieRow(
        title: title, movies: list, onTap: (m) => _open(c, m.slug, m.name),
        onSeeMore: () => _seeMore(c, title, BrowseQuery('country', slug)),
      ),
      orElse: () => const SizedBox(height: 8),
    );
  }
}
