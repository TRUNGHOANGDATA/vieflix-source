import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';
import 'movie_card.dart';
import 'tv_focusable.dart';

/// Nút mũi tên cuộn trái/phải cho hàng phim ngang (Netflix-style).
class ScrollArrow extends StatelessWidget {
  final bool left;
  final ScrollController controller;
  const ScrollArrow({super.key, required this.left, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              if (!controller.hasClients) return;
              final w = controller.position.viewportDimension * 0.8;
              final target = (controller.offset + (left ? -w : w))
                  .clamp(0.0, controller.position.maxScrollExtent);
              controller.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(left ? Icons.chevron_left : Icons.chevron_right, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút "Xem tất cả" ở đầu hàng. Dùng FocusHighlight để remote TV chọn tới được
/// (TextButton thường gần như không thấy viền chọn trên TV).
class SeeAllButton extends StatelessWidget {
  final VoidCallback onPressed;
  const SeeAllButton({super.key, required this.onPressed});
  @override
  Widget build(BuildContext context) => FocusHighlight(
        onPressed: onPressed,
        scale: 1.0,
        builder: (f) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: f ? kRed : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: f ? kRed : Colors.white24, width: 2),
          ),
          child: Text('Xem tất cả ›',
              style: TextStyle(
                  color: f ? Colors.white : kRed, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      );
}

class MovieRow extends StatefulWidget {
  final String title;
  final List<Movie> movies;
  final void Function(Movie) onTap;
  final VoidCallback? onSeeMore;
  const MovieRow({
    super.key,
    required this.title,
    required this.movies,
    required this.onTap,
    this.onSeeMore,
  });
  @override
  State<MovieRow> createState() => _MovieRowState();
}

class _MovieRowState extends State<MovieRow> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onSeeMore,
              child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          if (widget.onSeeMore != null) SeeAllButton(onPressed: widget.onSeeMore!),
        ]),
      ),
      SizedBox(
        height: 300,
        child: Stack(children: [
          ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: widget.movies.length + (widget.onSeeMore != null ? 1 : 0),
            itemBuilder: (c, i) {
              if (i >= widget.movies.length) {
                return _SeeMoreCard(onTap: widget.onSeeMore!);
              }
              return MovieCard(movie: widget.movies[i], onTap: () => widget.onTap(widget.movies[i]));
            },
          ),
          ScrollArrow(left: true, controller: _scroll),
          ScrollArrow(left: false, controller: _scroll),
        ]),
      ),
    ]);
  }
}

class _SeeMoreCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeMoreCard({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return FocusHighlight(
      onPressed: onTap,
      scale: 1.05,
      builder: (f) => Container(
        width: 180,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: f ? kRed : Colors.white24, width: f ? 3 : 1),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.arrow_forward, color: kRed, size: 36),
          SizedBox(height: 8),
          Text('Xem thêm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}
