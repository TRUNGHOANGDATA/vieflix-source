import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../screens/detail_screen.dart';
import '../screens/category_list_screen.dart';
import 'movie_card.dart';
import 'movie_row.dart' show ScrollArrow, RowHeader, SnapScrollPhysics, rowMetricsFor;
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
            // Chia vừa khít như hàng thường; số thứ tự nằm TRONG thẻ (cạnh tên).
            final m = rowMetricsFor(cons.maxWidth);
            return SizedBox(
              height: m.rowHeight,
              child: Stack(children: [
                Padding(
                  padding: EdgeInsets.only(left: m.padLeft, right: m.padRight),
                  child: ListView.builder(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    physics: SnapScrollPhysics(itemExtent: m.extent),
                    itemExtent: m.extent,
                    itemCount: list.length,
                    itemBuilder: (c, i) => MovieCard(
                      movie: list[i], width: m.cardWidth, rank: i + 1, onTap: () => _open(c, list[i]),
                    ),
                  ),
                ),
                ScrollArrow(left: true, controller: _scroll, step: m.step),
                ScrollArrow(left: false, controller: _scroll, step: m.step),
              ]),
            );
          }),
        ]);
      },
      orElse: () => const MovieRowSkeleton(),
    );
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
