import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../widgets/movie_row.dart';
import '../widgets/movie_card.dart';
import '../widgets/paginated_movie_row.dart';
import '../theme/app_theme.dart';
import '../data/local_store.dart';
import 'detail_screen.dart';
import 'category_list_screen.dart';

// Tên tập hiển thị: tránh "Tập Tập 08" khi nguồn (KKPhim) đã có sẵn chữ "Tập"
String _epText(String name) {
  final n = name.trim();
  if (RegExp(r'^t[aậ]p\b', caseSensitive: false).hasMatch(n)) return n;
  return 'Tập $n';
}

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
        final sub = total > 1 ? '${_epText(progress.episodeName)} / $total' : 'Xem tiếp';
        return _card(context, ref, img, det.name, sub, det.slug, det.name);
      },
      orElse: () {
        final name = progress.name.isNotEmpty ? progress.name : progress.slug;
        return _card(context, ref, progress.poster, name, _epText(progress.episodeName), progress.slug, name);
      },
    );
  }

  Future<void> _remove(WidgetRef ref) async {
    await ref.read(storeProvider).removeProgress(progress.slug);
    ref.read(homeRefreshProvider.notifier).state++; // buộc trang chủ vẽ lại
  }

  Widget _card(BuildContext context, WidgetRef ref, String img, String name, String sub, String slug, String openName) {
    final preview = Movie(
      name: openName, slug: slug, originalName: '', thumbUrl: img, posterUrl: img,
      description: '', quality: '', language: '', currentEpisode: '', totalEpisodes: 0,
    );
    return HoverPreview(
      movie: preview,
      onOpen: () => onOpen(slug, openName),
      builder: (_) => Container(
        margin: const EdgeInsets.all(4),
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
    return ListView(children: [
      const SizedBox(height: 12),
      _continueRow(ref, context),
      _personalRow(ref, context),
      _recommendedRow(ref, context),
      PaginatedMovieRow(
        title: 'Mới cập nhật',
        query: const BrowseQuery('all', ''),
        onTap: (m) => _open(context, m.slug, m.name),
        onSeeMore: () => _seeMore(context, 'Phim mới cập nhật', const BrowseQuery('all', '')),
      ),
      // Ưu tiên theo quốc gia
      _countryRow(ref, context, 'Phim Trung Quốc', 'trung-quoc'),
      _countryRow(ref, context, 'Phim Hàn Quốc', 'han-quoc'),
      _countryRow(ref, context, 'Phim Việt Nam', 'viet-nam'),
      _countryRow(ref, context, 'Phim Nhật Bản', 'nhat-ban'),
      _countryRow(ref, context, 'Phim Thái Lan', 'thai-lan'),
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
          itemBuilder: (c, i) => SizedBox(
            width: 158,
            child: ContinueCard(
              progress: cw[i],
              onOpen: (slug, name) => _open(context, slug, name),
            ),
          ),
        ),
      ),
    ]);
  }

  void _seeMore(BuildContext c, String title, BrowseQuery q) => Navigator.of(c).push(
      MaterialPageRoute(builder: (_) => CategoryListScreen(title: title, query: q)));

  Widget _personalRow(WidgetRef ref, BuildContext c) {
    final v = ref.watch(personalRecProvider);
    return v.maybeWhen(
      data: (res) => res == null
          ? const SizedBox.shrink()
          : MovieRow(
              title: '🎯 Vì bạn hay xem ${res.$1}',
              movies: res.$2,
              onTap: (m) => _open(c, m.slug, m.name),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }

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

  Widget _typeRow(WidgetRef ref, BuildContext c, String title, String type) =>
      PaginatedMovieRow(
        title: title,
        query: BrowseQuery('type', type),
        onTap: (m) => _open(c, m.slug, m.name),
        onSeeMore: () => _seeMore(c, title, BrowseQuery('type', type)),
      );

  Widget _genreRow(WidgetRef ref, BuildContext c, String title, String slug) =>
      PaginatedMovieRow(
        title: title,
        query: BrowseQuery('genre', slug),
        onTap: (m) => _open(c, m.slug, m.name),
        onSeeMore: () => _seeMore(c, title, BrowseQuery('genre', slug)),
      );

  Widget _countryRow(WidgetRef ref, BuildContext c, String title, String slug) =>
      PaginatedMovieRow(
        title: title,
        query: BrowseQuery('country', slug),
        onTap: (m) => _open(c, m.slug, m.name),
        onSeeMore: () => _seeMore(c, title, BrowseQuery('country', slug)),
      );
}
