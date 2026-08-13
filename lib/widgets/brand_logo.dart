import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Logo thương hiệu VieFlix: khối "play" squircle gradient (có gloss + quầng
/// sáng) đứng cạnh wordmark "Vie" trắng + "Flix" gradient đỏ. Tách riêng để
/// dùng lại ở thanh nav, splash, v.v.
class BrandLogo extends StatelessWidget {
  final double height;
  const BrandLogo({super.key, this.height = 34});

  @override
  Widget build(BuildContext context) {
    final mark = height;
    final fs = height * 0.74;
    final word = TextStyle(
      fontSize: fs,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
      height: 1.0,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: mark,
        height: mark,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(mark * 0.3),
          boxShadow: [
            BoxShadow(color: kRed.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 5)),
          ],
        ),
        child: CustomPaint(painter: _PlayMark()),
      ),
      SizedBox(width: mark * 0.34),
      Text('Vie', style: word.copyWith(color: Colors.white)),
      // "Flix" tô gradient đỏ (srcIn phủ chữ trắng bên dưới).
      ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF4E5E), kRed, Color(0xFFB00610)],
        ).createShader(r),
        child: Text('Flix', style: word.copyWith(color: Colors.white)),
      ),
    ]);
  }
}

class _PlayMark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.3));

    canvas.save();
    canvas.clipRRect(rr);
    // Nền gradient chéo (đỏ tươi -> đỏ VieFlix -> đỏ thẫm) cho khối có chiều sâu.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF4E5E), Color(0xFFE50914), Color(0xFF8E0510)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    // Vệt sáng gloss ở nửa trên.
    final glossRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.5);
    canvas.drawRect(
      glossRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.30), Colors.white.withValues(alpha: 0.0)],
        ).createShader(glossRect),
    );
    canvas.restore();

    // Viền trong mảnh -> khối trông "chắc" và tách nền.
    canvas.drawRRect(
      rr.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    // Tam giác play trắng, bo góc mềm (fill + stroke round join).
    final w = size.width, h = size.height;
    final s = w * 0.22;
    final cx = w * 0.40, cy = h * 0.5; // lệch trái nhẹ cho cân mắt
    final tri = Path()
      ..moveTo(cx - s * 0.75, cy - s)
      ..lineTo(cx - s * 0.75, cy + s)
      ..lineTo(cx + s, cy)
      ..close();
    canvas.drawPath(tri, Paint()..color = Colors.white);
    canvas.drawPath(
      tri,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.11
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
