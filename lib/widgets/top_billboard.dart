import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../screens/detail_screen.dart';
import '../screens/category_list_screen.dart';
import 'movie_row.dart' show ScrollArrow, RowHeader;
import 'shimmer.dart';
import 'tv_focusable.dart';

/// ĐIỂM NHẤN đầu trang chủ (thay cho hero cũ hay nhảy dọc/ngang):
/// bảng xếp hạng "Top 10 Hôm Nay" kiểu Netflix — số VÀNG khổng lồ nằm sau
/// mỗi poster dọc. Chỉ dùng ảnh dọc (nguồn phim luôn có) nên MỌI thẻ đồng nhất,
/// tải nhanh, không phụ thuộc TMDB.
class TopBillboard extends ConsumerStatefulWidget {
  const TopBillboard({super.key});
  @override
  ConsumerState<TopBillboard> createState() => _TopBillboardState();
}

class _TopBillboardState extends ConsumerState<TopBillboard> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _open(BuildContext c, Movie m) => Navigator.of(c).push(
      MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name)));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(topSeriesProvider);
    return async.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final top = list.take(10).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RowHeader(
            title: '🔥 Top 10 Hôm Nay',
            edgeRight: 50,
            onSeeMore: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CategoryListScreen(
                    title: 'Phim Bộ', query: BrowseQuery('type', 'phim-bo')))),
          ),
          LayoutBuilder(builder: (ctx, cons) {
            // Kích thước co theo màn: poster to hơn thẻ thường -> ra dáng "điểm nhấn".
            final posterH = (cons.maxWidth * 0.24).clamp(180.0, 300.0);
            final posterW = posterH * 2 / 3;
            final numLead = posterH * 0.52; // phần chữ số ló ra bên trái poster
            final slotW = numLead + posterW;
            const gap = 20.0;
            final extent = slotW + gap;
            const padLeft = 16.0, padRight = 50.0;
            final rowH = posterH + 30; // chừa 1 dòng tên dưới poster

            return SizedBox(
              height: rowH,
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.only(left: padLeft, right: padRight),
                  child: ListView.builder(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    itemExtent: extent,
                    itemCount: top.length,
                    itemBuilder: (c, i) => _BillboardItem(
                      movie: top[i],
                      rank: i + 1,
                      posterW: posterW,
                      posterH: posterH,
                      numLead: numLead,
                      slotW: slotW,
                      onTap: () => _open(c, top[i]),
                    ),
                  ),
                ),
                ScrollArrow(left: true, controller: _scroll, step: extent * 3),
                ScrollArrow(left: false, controller: _scroll, step: extent * 3),
              ]),
            );
          }),
        ]);
      },
      orElse: () => const MovieRowSkeleton(),
    );
  }
}

class _BillboardItem extends StatelessWidget {
  final Movie movie;
  final int rank;
  final double posterW, posterH, numLead, slotW;
  final VoidCallback onTap;
  const _BillboardItem({
    required this.movie,
    required this.rank,
    required this.posterW,
    required this.posterH,
    required this.numLead,
    required this.slotW,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final img = movie.thumbUrl.isNotEmpty ? movie.thumbUrl : movie.posterUrl;
    return FocusHighlight(
      onPressed: onTap,
      scale: 1.0,
      builder: (f) => SizedBox(
        width: slotW,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: posterH,
            child: Stack(clipBehavior: Clip.none, children: [
              // Số hạng khổng lồ, canh đáy-trái, để poster đè lên phần phải.
              Positioned(
                left: 0, bottom: -posterH * 0.04,
                child: _rankNumber(rank, posterH),
              ),
              // Poster dọc canh phải + viền vàng khi được chọn/di chuột.
              Positioned(
                right: 0, top: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: posterW,
                  height: posterH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: f ? kAmber : Colors.white12, width: f ? 3 : 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 14, offset: const Offset(0, 6)),
                      if (f) BoxShadow(color: kAmber.withValues(alpha: 0.55), blurRadius: 22, spreadRadius: 1),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(fit: StackFit.expand, children: [
                      CachedNetworkImage(
                        imageUrl: img, fit: BoxFit.cover,
                        memCacheWidth: 400, maxWidthDiskCache: 400,
                        placeholder: (c, _) => Container(color: kSurface),
                        errorWidget: (c, _, _) => Container(
                            color: kSurface, child: const Icon(Icons.movie, color: Colors.white24)),
                      ),
                      // Chọn/di chuột: phủ tối nhẹ + nút play tròn.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: f ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Container(
                              color: Colors.black26,
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kRed,
                                  boxShadow: [BoxShadow(color: kRed.withValues(alpha: 0.6), blurRadius: 16)],
                                ),
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 26),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          // Tên phim 1 dòng, canh dưới poster.
          Padding(
            padding: EdgeInsets.only(left: numLead),
            child: Text(movie.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: f ? kAmber : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  // Số hạng: gradient VÀNG (kiểu bảng xếp hạng), viền tối dày cho nổi khối.
  Widget _rankNumber(int n, double h) {
    final s = '$n';
    final fs = h * 0.92;
    final base = TextStyle(
      fontSize: fs, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.0,
    );
    return Stack(children: [
      // Viền tối phía sau.
      Text(s,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = h * 0.028
              ..color = Colors.black.withValues(alpha: 0.85),
          )),
      // Ruột vàng gradient.
      ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFFDE68A), Color(0xFFF5C518), Color(0xFFB8860B)],
        ).createShader(r),
        child: Text(s, style: base.copyWith(color: Colors.white)),
      ),
    ]);
  }
}
