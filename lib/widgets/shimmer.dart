import 'package:flutter/material.dart';

/// Hiệu ứng "shimmer": vệt sáng quét qua khối xám -> cảm giác đang tải mượt mà,
/// sang hơn hẳn vòng xoay. Bọc quanh các khối SkeletonBox.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = bounds.width * (_c.value * 2 - 1); // -w .. +w
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [Color(0xFF2A2A2A), Color(0xFF3D3D3D), Color(0xFF2A2A2A)],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(dx),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double dx;
  const _SlideGradient(this.dx);
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(dx, 0, 0);
}

/// Khối chữ nhật bo góc dùng làm "xương" (placeholder) khi tải.
class SkeletonBox extends StatelessWidget {
  final double? width, height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height, this.radius = 8});
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Xương của một HÀNG phim ngang (tiêu đề + vài thẻ dọc) — dùng khi đang tải.
class MovieRowSkeleton extends StatelessWidget {
  final double cardWidth, rowHeight;
  final int count;
  const MovieRowSkeleton({super.key, this.cardWidth = 170, this.rowHeight = 300, this.count = 7});
  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: SkeletonBox(width: 180, height: 22),
        ),
        SizedBox(
          height: rowHeight - 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: count,
            itemBuilder: (c, i) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SkeletonBox(width: cardWidth, radius: 10),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Xương của một LƯỚI phim (trang danh mục / xem tất cả).
class MovieGridSkeleton extends StatelessWidget {
  const MovieGridSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200, childAspectRatio: 0.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: 12,
        itemBuilder: (c, i) => const SkeletonBox(radius: 10),
      ),
    );
  }
}

/// Xương cho khối lớn (vd hero banner) — dùng màu nền tối nhẹ.
class HeroSkeleton extends StatelessWidget {
  final double height;
  const HeroSkeleton({super.key, required this.height});
  @override
  Widget build(BuildContext context) => Shimmer(
        child: SkeletonBox(height: height, radius: 0),
      );
}
