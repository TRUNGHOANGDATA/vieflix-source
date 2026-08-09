import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../screens/detail_screen.dart';
import 'shimmer.dart';
import 'tv_focusable.dart';

/// Hero banner điện ảnh ở đầu trang chủ: 1 phim nổi bật chiếm khoảng nửa màn
/// hình, ảnh nền ngang chất lượng cao, chữ + nút nổi trên lớp mờ, và tự đổi phim.
class HomeHero extends ConsumerStatefulWidget {
  const HomeHero({super.key});
  @override
  ConsumerState<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends ConsumerState<HomeHero> {
  final _pc = PageController();
  Timer? _auto;
  int _page = 0;
  int _count = 0;

  @override
  void dispose() {
    _auto?.cancel();
    _pc.dispose();
    super.dispose();
  }

  void _armAuto() {
    _auto?.cancel();
    if (_count <= 1) return;
    _auto = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !_pc.hasClients) return;
      final next = (_page + 1) % _count;
      _pc.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }

  double _heroHeight(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return (w * 0.42).clamp(320.0, 460.0);
  }

  @override
  Widget build(BuildContext context) {
    final h = _heroHeight(context);
    final async = ref.watch(featuredMoviesProvider);
    return async.maybeWhen(
      data: (movies) {
        if (movies.isEmpty) return const SizedBox.shrink();
        if (_count != movies.length) {
          _count = movies.length;
          WidgetsBinding.instance.addPostFrameCallback((_) => _armAuto());
        }
        return SizedBox(
          height: h,
          child: Stack(children: [
            PageView.builder(
              controller: _pc,
              itemCount: movies.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (c, i) => _HeroSlide(movie: movies[i], height: h),
            ),
            // Chấm chỉ vị trí (trang nào đang hiện)
            if (movies.length > 1)
              Positioned(
                bottom: 18, right: 40,
                child: Row(children: [
                  for (int i = 0; i < movies.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 22 : 8, height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? kRed : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ]),
              ),
          ]),
        );
      },
      orElse: () => HeroSkeleton(height: h),
    );
  }
}

class _HeroSlide extends ConsumerWidget {
  final Movie movie;
  final double height;
  const _HeroSlide({required this.movie, required this.height});

  void _openDetail(BuildContext c) => Navigator.of(c).push(
      MaterialPageRoute(builder: (_) => DetailScreen(slug: movie.slug, title: movie.name)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = movie.originalName.isNotEmpty ? movie.originalName : movie.name;
    // Ảnh nền ngang chất lượng cao (TMDB). Không có -> dùng poster/thumb.
    final backdrop = ref.watch(backdropProvider(q)).maybeWhen(data: (u) => u, orElse: () => null);
    final img = (backdrop != null && backdrop.isNotEmpty)
        ? backdrop
        : (movie.posterUrl.isNotEmpty ? movie.posterUrl : movie.thumbUrl);
    final rating = ref.watch(tmdbRatingProvider(q)).maybeWhen(data: (r) => r, orElse: () => null);
    final store = ref.watch(storeProvider);
    final fav = store.isFavorite(movie.slug);

    return Stack(fit: StackFit.expand, children: [
      CachedNetworkImage(
        imageUrl: img,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        memCacheWidth: 1280,
        placeholder: (c, _) => Container(color: kSurface),
        errorWidget: (c, _, __) => Container(color: kSurface),
      ),
      // Mờ trái->phải để chữ dễ đọc
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [Colors.black, Colors.black54, Colors.transparent],
            stops: [0.0, 0.4, 0.85],
          ),
        ),
      ),
      // Mờ đáy -> hoà vào nền trang
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.center,
            colors: [kBg, Colors.transparent],
          ),
        ),
      ),
      Positioned(
        left: 40, right: 200, bottom: 40,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(movie.name,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, height: 1.1,
                  shadows: [Shadow(color: Colors.black, blurRadius: 12)])),
          const SizedBox(height: 10),
          // Hàng thông tin: điểm + chất lượng + tập
          Row(children: [
            if (rating != null) ...[
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(rating.rating.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 14),
            ],
            if (movie.quality.isNotEmpty) _tag(movie.quality),
            if (movie.currentEpisode.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(movie.currentEpisode, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ]),
          if (movie.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(movie.description,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
          ],
          const SizedBox(height: 18),
          Row(children: [
            FocusHighlight(
              scale: 1.05,
              onPressed: () => _openDetail(context),
              builder: (f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                decoration: BoxDecoration(
                  color: f ? Colors.white : kRed,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: kRed.withValues(alpha: f ? 0.0 : 0.5), blurRadius: 14)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.play_arrow, color: f ? kRed : Colors.white, size: 24),
                  const SizedBox(width: 6),
                  Text('Xem ngay',
                      style: TextStyle(color: f ? kRed : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            FocusHighlight(
              scale: 1.05,
              onPressed: () async {
                await store.toggleFavorite(Movie.fromJson({
                  'name': movie.name, 'slug': movie.slug,
                  'poster_url': movie.posterUrl, 'thumb_url': movie.thumbUrl,
                  'quality': movie.quality, 'current_episode': movie.currentEpisode,
                  'total_episodes': movie.totalEpisodes, 'genres': movie.genres,
                }));
                ref.read(homeRefreshProvider.notifier).state++;
              },
              builder: (f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: f ? 0.28 : 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: f ? Colors.white : Colors.white38, width: 2),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(fav ? Icons.check : Icons.add, color: Colors.white, size: 22),
                  const SizedBox(width: 6),
                  Text(fav ? 'Đã lưu' : 'Danh sách',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ]),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  Widget _tag(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(4)),
        child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
}
