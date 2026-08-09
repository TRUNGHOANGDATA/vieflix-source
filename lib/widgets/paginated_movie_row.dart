import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'movie_card.dart';
import 'movie_row.dart' show ScrollArrow, RowHeader, SnapScrollPhysics, rowMetricsFor;
import 'tv_focusable.dart';

/// Hàng phim ngang TỰ TẢI THÊM khi cuộn sang phải (dùng lại browseProvider).
class PaginatedMovieRow extends ConsumerStatefulWidget {
  final String title;
  final BrowseQuery query;
  final void Function(Movie) onTap;
  final VoidCallback? onSeeMore;
  const PaginatedMovieRow({
    super.key,
    required this.title,
    required this.query,
    required this.onTap,
    this.onSeeMore,
  });
  @override
  ConsumerState<PaginatedMovieRow> createState() => _PaginatedMovieRowState();
}

class _PaginatedMovieRowState extends ConsumerState<PaginatedMovieRow> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Gần chạm mép phải -> tải thêm trang
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        ref.read(browseProvider(widget.query).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(browseProvider(widget.query));
    if (st.items.isEmpty) return const SizedBox(height: 8); // đang tải trang đầu / rỗng
    final hasMore = st.page < st.totalPage;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RowHeader(title: widget.title, onSeeMore: widget.onSeeMore, edgeRight: 50),
      LayoutBuilder(builder: (ctx, cons) {
        final m = rowMetricsFor(cons.maxWidth);
        return SizedBox(
          height: m.rowHeight,
          child: Stack(children: [
            // Lề đặt NGOÀI vùng cuộn -> thẻ thừa bị cắt khỏi khung nhìn.
            Padding(
              padding: EdgeInsets.only(left: m.padLeft, right: m.padRight),
              child: ListView.builder(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: SnapScrollPhysics(itemExtent: m.extent),
              itemExtent: m.extent,
              itemCount: st.items.length + 1,
              itemBuilder: (c, i) {
                if (i >= st.items.length) {
                  // Ô cuối hàng: đang tải thêm -> spinner; hết phim -> nút "Xem tất cả"
                  if (hasMore) {
                    return const Center(child: CircularProgressIndicator(color: kRed));
                  }
                  if (widget.onSeeMore != null) return _seeMoreCard(m.cardWidth);
                  return const SizedBox.shrink();
                }
                return MovieCard(
                  movie: st.items[i],
                  width: m.cardWidth,
                  onTap: () => widget.onTap(st.items[i]),
                );
              },
            ),
            ),
            ScrollArrow(left: true, controller: _scroll, step: m.step),
            ScrollArrow(left: false, controller: _scroll, step: m.step),
          ]),
        );
      }),
    ]);
  }

  Widget _seeMoreCard(double width) => FocusHighlight(
        onPressed: widget.onSeeMore ?? () {},
        scale: 1.05,
        builder: (f) => Container(
          width: width,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: f ? kRed : Colors.white24, width: f ? 3 : 1),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.arrow_forward, color: kRed, size: 36),
            SizedBox(height: 8),
            Text('Xem tất cả', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}
