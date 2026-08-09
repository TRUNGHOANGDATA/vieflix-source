import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';
import 'movie_card.dart';
import 'tv_focusable.dart';

/// Kích thước tính sẵn cho một hàng phim ngang.
///
/// Ý tưởng: vùng CUỘN rộng đúng bằng một số nguyên thẻ, còn lề trái/phải nằm
/// NGOÀI vùng cuộn. Nhờ vậy thẻ thứ n+1 bị cắt hẳn khỏi khung nhìn: thẻ cuối
/// không bao giờ chạm mép và không bao giờ lòi ra nửa tấm ảnh.
/// (Nếu để lề bằng `padding` của ListView thì thẻ kế tiếp vẫn tràn vào lề.)
class RowMetrics {
  final double cardWidth;  // bề rộng phần nhìn thấy của thẻ
  final double extent;     // bước của 1 thẻ = cardWidth + khoảng cách
  final double padLeft, padRight;
  final double step;       // cuộn 1 lần bằng mũi tên = trọn 1 trang
  final double rowHeight;
  final int perPage;
  const RowMetrics({
    required this.cardWidth, required this.extent,
    required this.padLeft, required this.padRight,
    required this.step, required this.rowHeight, required this.perPage,
  });
}

/// [viewport] bề rộng khả dụng; [target] bề rộng thẻ mong muốn; [gap] khoảng
/// hở giữa 2 thẻ; [edgeLeft]/[edgeRight] lề tính từ mép màn hình (lề phải rộng
/// hơn để chừa chỗ cho nút mũi tên).
RowMetrics rowMetricsFor(
  double viewport, {
  double target = 250, // card TO như RoPhim: màn rộng ~7 card/dòng, màn hẹp ~5
  double gap = 14,
  double edgeLeft = 16,
  double edgeRight = 50,
  double heightFactor = 1.44,
  double extraHeight = 66, // chừa chỗ cho tên Việt + tên gốc + số tập dưới card
}) {
  final padLeft = (edgeLeft - gap / 2).clamp(0.0, double.infinity);
  final padRight = (edgeRight - gap / 2).clamp(0.0, double.infinity);
  final avail = (viewport - padLeft - padRight).clamp(120.0, double.infinity);
  var n = (avail / target).round();
  if (n < 2) n = 2;
  final extent = avail / n;
  final cardW = (extent - gap).clamp(60.0, double.infinity);
  return RowMetrics(
    cardWidth: cardW,
    extent: extent,
    padLeft: padLeft,
    padRight: padRight,
    step: extent * n,
    rowHeight: cardW * heightFactor + extraHeight,
    perPage: n,
  );
}

/// Cuộn xong luôn dừng đúng mép một thẻ (không để lộ nửa thẻ).
class SnapScrollPhysics extends ScrollPhysics {
  final double itemExtent;
  const SnapScrollPhysics({required this.itemExtent, super.parent});

  @override
  SnapScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      SnapScrollPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (itemExtent <= 0) return super.createBallisticSimulation(position, velocity);
    // Đang ở mép -> để hiệu ứng nảy mặc định lo.
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    // Tính cả đà lướt tay rồi làm tròn về thẻ gần nhất.
    final proposed = position.pixels + velocity * 0.15;
    final target = ((proposed / itemExtent).roundToDouble() * itemExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    final tol = toleranceFor(position);
    if ((target - position.pixels).abs() < tol.distance) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tol);
  }
}

/// Nút mũi tên cuộn trái/phải: cuộn trọn 1 trang và TỰ ẨN khi đã hết đường.
class ScrollArrow extends StatefulWidget {
  final bool left;
  final ScrollController controller;
  final double step;
  const ScrollArrow({super.key, required this.left, required this.controller, required this.step});
  @override
  State<ScrollArrow> createState() => _ScrollArrowState();
}

class _ScrollArrowState extends State<ScrollArrow> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (!mounted || !widget.controller.hasClients) return;
    final p = widget.controller.position;
    final can = widget.left ? p.pixels > 1 : p.pixels < p.maxScrollExtent - 1;
    if (can != _show) setState(() => _show = can);
  }

  void _go() {
    if (!widget.controller.hasClients) return;
    final p = widget.controller.position;
    final target = (widget.controller.offset + (widget.left ? -widget.step : widget.step))
        .clamp(0.0, p.maxScrollExtent);
    widget.controller.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return Align(
      alignment: widget.left ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _go,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(widget.left ? Icons.chevron_left : Icons.chevron_right, color: Colors.white, size: 30),
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

/// Tiêu đề hàng phim (bấm vào tên cũng mở "Xem tất cả").
class RowHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeMore;
  final double edgeLeft, edgeRight;
  const RowHeader({super.key, required this.title, this.onSeeMore, this.edgeLeft = 16, this.edgeRight = 16});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(edgeLeft, 16, edgeRight, 8),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: onSeeMore,
              child: Text(title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          if (onSeeMore != null) SeeAllButton(onPressed: onSeeMore!),
        ]),
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
    final extra = widget.onSeeMore != null ? 1 : 0;
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
              itemCount: widget.movies.length + extra,
              itemBuilder: (c, i) {
                if (i >= widget.movies.length) {
                  return _SeeMoreCard(onTap: widget.onSeeMore!, width: m.cardWidth);
                }
                return MovieCard(
                  movie: widget.movies[i],
                  width: m.cardWidth,
                  onTap: () => widget.onTap(widget.movies[i]),
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
}

class _SeeMoreCard extends StatelessWidget {
  final VoidCallback onTap;
  final double width;
  const _SeeMoreCard({required this.onTap, required this.width});
  @override
  Widget build(BuildContext context) {
    return FocusHighlight(
      onPressed: onTap,
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
}
