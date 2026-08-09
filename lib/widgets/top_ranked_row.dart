import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../screens/detail_screen.dart';
import '../screens/category_list_screen.dart';
import 'movie_card.dart';
import 'movie_row.dart' show ScrollArrow, RowHeader, rowMetricsFor;
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
            final m = rowMetricsFor(cons.maxWidth);
            // Số thứ tự chiếm thêm chỗ bên trái mỗi thẻ.
            const numW = 52.0;
            final itemW = m.cardWidth + numW + 12;
            return SizedBox(
              height: m.rowHeight,
              child: Stack(children: [
                ListView.builder(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 12, right: 40),
                  itemCount: list.length,
                  itemBuilder: (c, i) => SizedBox(
                    width: itemW,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      SizedBox(
                        width: numW,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: m.rowHeight * 0.30),
                          child: _rankNumber(i + 1),
                        ),
                      ),
                      Expanded(child: MovieCard(movie: list[i], width: m.cardWidth, onTap: () => _open(c, list[i]))),
                    ]),
                  ),
                ),
                ScrollArrow(left: true, controller: _scroll, step: itemW * 3),
                ScrollArrow(left: false, controller: _scroll, step: itemW * 3),
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
