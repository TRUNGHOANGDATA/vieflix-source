import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../state/providers.dart';
import '../widgets/movie_row.dart';
import '../widgets/paginated_movie_row.dart';
import '../widgets/home_hero.dart';
import '../widgets/top_ranked_row.dart';
import '../widgets/tv_focusable.dart';
import '../theme/app_theme.dart';
import '../data/local_store.dart';
import 'detail_screen.dart';
import 'category_list_screen.dart';
import 'movie_grid_screen.dart';

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

  /// Bản TV: hỏi lại trước khi bỏ (remote dễ bấm nhầm).
  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Bỏ theo dõi?', style: TextStyle(color: Colors.white)),
        content: Text('Xoá "$name" khỏi hàng Xem tiếp.\nPhim vẫn còn trong danh mục, bạn xem lại lúc nào cũng được.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Giữ lại')),
          ElevatedButton(
            autofocus: true,
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Bỏ theo dõi'),
          ),
        ],
      ),
    );
    if (ok == true) await _remove(ref);
  }

  /// Nút "Bỏ theo dõi" nằm NGAY DƯỚI thẻ phim: trên TV chỉ cần bấm ▼ từ thẻ là
  /// tới nút này rồi bấm OK (remote không bấm được dấu ✕ nhỏ ở góc).
  Widget _removeButton(BuildContext context, WidgetRef ref, String name) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: FocusHighlight(
          scale: 1.0,
          onPressed: () => _confirmRemove(context, ref, name),
          builder: (f) => Container(
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: f ? kRed : Colors.white12,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: f ? kRed : Colors.white24, width: 2),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.close, size: 15, color: f ? Colors.white : Colors.white70),
              const SizedBox(width: 4),
              Text('Bỏ theo dõi',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: f ? Colors.white : Colors.white70)),
            ]),
          ),
        ),
      );

  Widget _card(BuildContext context, WidgetRef ref, String img, String name, String sub, String slug, String openName) {
    // Hàng "Xem tiếp": KHÔNG hiện ô preview lớn (bấm là xem luôn), chỉ sáng
    // viền khi được chọn để dùng được bằng remote.
    final card = FocusHighlight(
      onPressed: () => onOpen(slug, openName),
      scale: 1.04,
      builder: (f) => Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: f ? kRed : Colors.transparent, width: 3),
          boxShadow: f ? [BoxShadow(color: kRed.withValues(alpha: 0.6), blurRadius: 16)] : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(fit: StackFit.expand, children: [
            if (img.isNotEmpty)
              CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, memCacheWidth: 400, maxWidthDiskCache: 400, errorWidget: (c, _, __) => Container(color: kSurface))
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
            // Nút ✕ ở góc: chỉ dành cho chuột (bản PC). Trên TV dùng nút
            // "Bỏ theo dõi" ở dưới thẻ vì remote không trỏ được vào đây.
            if (!Platform.isAndroid)
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
              left: 8, right: 8, bottom: 10,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),
            // Thanh tiến độ đã xem trong tập (nếu có ghi vị trí)
            if (progress.durationSeconds > 0 && progress.positionSeconds > 0)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: LinearProgressIndicator(
                  value: (progress.positionSeconds / progress.durationSeconds).clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  color: kRed,
                ),
              ),
          ]),
        ),
      ),
    );
    if (!Platform.isAndroid) return card;
    // TV: thẻ phim + nút "Bỏ theo dõi" ngay dưới -> bấm ▼ là tới, OK là xoá.
    return Column(children: [
      Expanded(child: card),
      _removeButton(context, ref, name),
    ]);
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext c, String slug, String title) => Navigator.of(c).push(
      MaterialPageRoute(builder: (_) => DetailScreen(slug: slug, title: title)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeRefreshProvider); // vẽ lại khi xoá mục Xem tiếp
    return ListView(padding: EdgeInsets.zero, children: [
      const HomeHero(),
      const SizedBox(height: 8),
      const TopSeriesRow(),
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
      LayoutBuilder(builder: (ctx, cons) {
        // Chia vừa khít số thẻ nguyên -> thẻ cuối không chạm mép, không bị cắt.
        // TV cần cao thêm để chứa nút "Bỏ theo dõi" dưới mỗi thẻ.
        final m = rowMetricsFor(cons.maxWidth,
            target: 210, gap: 12, heightFactor: 1.5,
            extraHeight: Platform.isAndroid ? 44 : 10);
        return SizedBox(
          height: m.rowHeight,
          // Lề nằm NGOÀI vùng cuộn -> thẻ thừa bị cắt hẳn, không lòi nửa ảnh.
          child: Padding(
            padding: EdgeInsets.only(left: m.padLeft, right: m.padRight),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: SnapScrollPhysics(itemExtent: m.extent),
              itemExtent: m.extent,
              itemCount: cw.length,
              itemBuilder: (c, i) => ContinueCard(
                progress: cw[i],
                onOpen: (slug, name) => _open(context, slug, name),
              ),
            ),
          ),
        );
      }),
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
              movies: res.$3,
              onTap: (m) => _open(c, m.slug, m.name),
              // Xem tất cả -> mở đúng thể loại đang được gợi ý
              onSeeMore: () => _seeMore(c, 'Phim ${res.$1}', BrowseQuery('genre', res.$2)),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _recommendedRow(WidgetRef ref, BuildContext c) {
    final rec = ref.watch(recommendedProvider);
    return rec.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final all = list.map((e) => e.$1).toList();
        return MovieRow(
          title: '⭐ Phim đề cử (điểm cao)',
          movies: all.take(12).toList(),
          onTap: (m) => _open(c, m.slug, m.name),
          // Danh sách này do app tự chấm điểm -> mở trang lưới danh sách có sẵn
          onSeeMore: () => Navigator.of(c).push(MaterialPageRoute(
              builder: (_) => MovieGridScreen(title: 'Phim đề cử (điểm cao)', movies: all))),
        );
      },
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
