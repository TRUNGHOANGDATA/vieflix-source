import 'dart:async';
import 'dart:ui' as ui;
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

  // Chuyển phim bằng mũi tên (đặt lại đồng hồ tự đổi để không giật).
  void _go(int delta) {
    if (!_pc.hasClients || _count == 0) return;
    final next = (_page + delta + _count) % _count;
    _pc.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    _armAuto();
  }

  Widget _arrow(bool right) => Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _go(right ? 1 : -1),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(right ? Icons.chevron_right : Icons.chevron_left, color: Colors.white, size: 32),
          ),
        ),
      );

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
            // Mũi tên qua lại (bấm chuột được; trên TV vẫn tự đổi phim)
            if (movies.length > 1) ...[
              Positioned(left: 10, top: 0, bottom: 0, child: Center(child: _arrow(false))),
              Positioned(right: 10, top: 0, bottom: 0, child: Center(child: _arrow(true))),
              // Chấm chỉ vị trí (đặt giữa dưới)
              Positioned(
                bottom: 14, left: 0, right: 0,
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
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
              ),
            ],
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
    // Ảnh nền ngang chất lượng cao (TMDB). Ảnh nguonc chỉ có poster DỌC -> ép
    // ngang sẽ xấu, nên khi không có ảnh ngang thì dùng poster dọc LÀM NỀN MỜ.
    final backdrop = ref.watch(backdropProvider(q)).maybeWhen(data: (u) => u, orElse: () => null);
    final hasWide = backdrop != null && backdrop.isNotEmpty;
    final poster = movie.posterUrl.isNotEmpty ? movie.posterUrl : movie.thumbUrl;
    final rating = ref.watch(tmdbRatingProvider(q)).maybeWhen(data: (r) => r, orElse: () => null);
    final store = ref.watch(storeProvider);
    final fav = store.isFavorite(movie.slug);

    return Stack(fit: StackFit.expand, children: [
      if (hasWide)
        CachedNetworkImage(
          imageUrl: backdrop,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          memCacheWidth: 1280,
          placeholder: (c, _) => Container(color: kSurface),
          errorWidget: (c, _, __) => Container(color: kSurface),
        )
      else ...[
        // Nền: poster dọc phủ kín + làm mờ mạnh -> đẹp, không bị cắt kỳ cục.
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: CachedNetworkImage(
            imageUrl: poster, fit: BoxFit.cover, memCacheWidth: 640,
            placeholder: (c, _) => Container(color: kSurface),
            errorWidget: (c, _, __) => Container(color: kSurface),
          ),
        ),
        // Poster dọc SẮC NÉT đặt bên phải (kiểu tấm áp phích)
        Positioned(
          right: 60, top: 20, bottom: 20,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: poster, fit: BoxFit.cover, memCacheWidth: 400,
                errorWidget: (c, _, __) => Container(color: kSurface),
              ),
            ),
          ),
        ),
      ],
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
          if (movie.originalName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(movie.originalName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 15, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 12),
          // Hàng thông tin: IMDb + chất lượng + tập
          Row(children: [
            if (rating != null) ...[
              _imdb(rating.rating),
              const SizedBox(width: 10),
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

  Widget _imdb(double r) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: kAmber, borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('IMDb', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          Text(r.toStringAsFixed(1), style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );
}
