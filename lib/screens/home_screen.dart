import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../state/providers.dart';
import '../widgets/movie_row.dart';
import '../widgets/hero_banner.dart';
import '../widgets/async_view.dart';
import '../theme/app_theme.dart';
import '../data/local_store.dart';
import 'detail_screen.dart';
import 'category_list_screen.dart';

/// Thẻ "Xem tiếp" (ảnh dọc): tự lấy poster + tên + tổng số tập từ API theo slug.
class ContinueCard extends ConsumerWidget {
  final WatchProgress progress;
  final void Function(String slug, String name) onOpen;
  const ContinueCard({super.key, required this.progress, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(detailProvider(progress.slug));
    return d.maybeWhen(
      data: (det) {
        final img = det.posterUrl.isNotEmpty ? det.posterUrl : det.thumbUrl;
        final avail = det.servers.isNotEmpty ? det.servers.first.items.length : 0;
        final total = det.base.totalEpisodes > avail ? det.base.totalEpisodes : (avail > 0 ? avail : det.base.totalEpisodes);
        final sub = total > 1 ? 'Tập ${progress.episodeName} / $total' : 'Xem tiếp';
        return _card(context, ref, img, det.name, sub, det.slug, det.name);
      },
      orElse: () {
        final name = progress.name.isNotEmpty ? progress.name : progress.slug;
        return _card(context, ref, progress.poster, name, 'Tập ${progress.episodeName}', progress.slug, name);
      },
    );
  }

  Future<void> _remove(WidgetRef ref) async {
    await ref.read(storeProvider).removeProgress(progress.slug);
    ref.read(homeRefreshProvider.notifier).state++; // buộc trang chủ vẽ lại
  }

  Widget _card(BuildContext context, WidgetRef ref, String img, String name, String sub, String slug, String openName) {
    return GestureDetector(
      onTap: () => onOpen(slug, openName),
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(fit: StackFit.expand, children: [
            if (img.isNotEmpty)
              CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (c, _, __) => Container(color: kSurface))
            else
              Container(color: kSurface, child: const Icon(Icons.movie, color: Colors.white24, size: 40)),
            // Lớp tối dưới đáy để chữ trắng luôn đọc rõ
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center,
                    colors: [Colors.black, Colors.transparent]),
              ),
            ),
            const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 42)),
            // Nút xóa khỏi Xem tiếp
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () => _remove(ref),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
            // Tên + tập (chữ trắng hết)
            Positioned(
              left: 8, right: 8, bottom: 8,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext c, String slug, String title) => Navigator.of(c).push(
      MaterialPageRoute(builder: (_) => DetailScreen(slug: slug, title: title)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeRefreshProvider); // vẽ lại khi xoá mục Xem tiếp
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
          _recommendedRow(ref, context),
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
        height: 250,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: cw.length,
          itemBuilder: (c, i) => ContinueCard(
            progress: cw[i],
            onOpen: (slug, name) => _open(context, slug, name),
          ),
        ),
      ),
    ]);
  }

  void _seeMore(BuildContext c, String title, BrowseQuery q) => Navigator.of(c).push(
      MaterialPageRoute(builder: (_) => CategoryListScreen(title: title, query: q)));

  Widget _recommendedRow(WidgetRef ref, BuildContext c) {
    final rec = ref.watch(recommendedProvider);
    return rec.maybeWhen(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : MovieRow(
              title: '⭐ Phim đề cử (điểm cao)',
              movies: list.map((e) => e.$1).toList(),
              onTap: (m) => _open(c, m.slug, m.name),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }

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
