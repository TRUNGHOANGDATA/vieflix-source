import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../screens/detail_screen.dart';
import '../screens/category_list_screen.dart';
import 'movie_card.dart';
import 'movie_row.dart' show ScrollArrow, RowHeader, SnapScrollPhysics;
import 'shimmer.dart';

/// Hàng "Top ... hôm nay": số thứ tự VÀNG cỡ lớn nằm bên trái mỗi poster
/// (kiểu bảng xếp hạng của RoPhim). Bấm số/poster để mở chi tiết.
class TopRankedRow extends ConsumerStatefulWidget {
  final String title;
  final FutureProvider<List<Movie>> provider;
  final VoidCallback? onSeeMore;
  const TopRankedRow({super.key, required this.title, required this.provider, this.onSeeMore});
  @override
  ConsumerState<TopRankedRow> createState() => _TopRankedRowState();
}

class _TopRankedRowState extends ConsumerState<TopRankedRow> {
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
    final async = ref.watch(widget.provider);
    return async.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RowHeader(title: widget.title, onSeeMore: widget.onSeeMore, edgeRight: 50),
          LayoutBuilder(builder: (ctx, cons) {
            // Chia vừa khít MỘT SỐ NGUYÊN ô (số thứ tự + thẻ). Lề ngoài vùng cuộn
            // -> thẻ cuối không bị cắt (không còn cảnh chỉ hiện mỗi số như "8").
            const numW = 50.0, gap = 12.0, padLeft = 12.0, padRight = 40.0;
            final avail = (cons.maxWidth - padLeft - padRight).clamp(200.0, double.infinity);
            var n = (avail / (185 + numW)).round();
            if (n < 2) n = 2;
            final extent = avail / n;
            final cardW = (extent - numW - gap).clamp(80.0, double.infinity);
            final rowHeight = cardW * 1.5 + 64;
            return SizedBox(
              height: rowHeight,
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.only(left: padLeft, right: padRight),
                  child: ListView.builder(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    physics: SnapScrollPhysics(itemExtent: extent),
                    itemExtent: extent,
                    itemCount: list.length,
                    itemBuilder: (c, i) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      SizedBox(
                        width: numW,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: rowHeight * 0.30),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _rankNumber(i + 1),
                          ),
                        ),
                      ),
                      Expanded(child: MovieCard(movie: list[i], width: cardW, onTap: () => _open(c, list[i]))),
                    ]),
                  ),
                ),
                ScrollArrow(left: true, controller: _scroll, step: extent * n),
                ScrollArrow(left: false, controller: _scroll, step: extent * n),
              ]),
            );
          }),
        ]);
      },
      orElse: () => const MovieRowSkeleton(),
    );
  }

  // Số vàng cỡ lớn, có viền tối để nổi trên mọi nền.
  Widget _rankNumber(int n) {
    final s = '$n';
    const size = 56.0;
    return Stack(children: [
      Text(s,
          style: TextStyle(
            fontSize: size, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.0,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = Colors.black,
          )),
      Text(s,
          style: const TextStyle(
            fontSize: size, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.0,
            color: kAmber,
          )),
    ]);
  }
}

/// Hàng Top phim bộ dùng sẵn cho trang chủ.
class TopSeriesRow extends StatelessWidget {
  const TopSeriesRow({super.key});
  @override
  Widget build(BuildContext context) => TopRankedRow(
        title: '🔥 Top 30 Phim Bộ hôm nay',
        provider: topSeriesProvider,
        onSeeMore: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const CategoryListScreen(title: 'Phim Bộ', query: BrowseQuery('type', 'phim-bo')))),
      );
}
