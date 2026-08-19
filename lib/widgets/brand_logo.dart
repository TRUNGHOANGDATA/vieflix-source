import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Logo thương hiệu VieFlix: khối "play" bo góc đỏ PHẲNG, tam giác play KHOÉT
/// RỖNG (màu nền xuyên qua) đứng cạnh wordmark "Vie" trắng + "Flix" đỏ.
///
/// Cố tình KHÔNG dùng gradient / vệt gloss / quầng sáng / viền trong. Bản cũ xếp
/// cả 4 hiệu ứng đó lên nhau, ở cỡ dùng thật (20–28px) chúng nhoè thành một khối
/// đỏ mờ. Phẳng + khoét rỗng thì nét ở mọi cỡ.
///
/// Lưu ý về độ đậm: app chỉ nhúng 4 file Be Vietnam Pro (400/500/600/700), nên
/// khai w800/w900 cũng chỉ ra đúng file Bold. Ghi thẳng w700 cho khớp thực tế.
class BrandLogo extends StatelessWidget {
  final double height;
  const BrandLogo({super.key, this.height = 34});

  @override
  Widget build(BuildContext context) {
    final mark = height;
    final word = TextStyle(
      fontFamily: kBrandFont, // ghim: theme dùng Segoe UI trên Windows
      fontSize: height * 0.72,
      fontWeight: FontWeight.w700,
      // Bản cũ dùng -0.5px cố định làm các chữ dính vào nhau ở cỡ nhỏ.
      letterSpacing: height * 0.008,
      height: 1.0,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1))],
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: mark,
        height: mark,
        child: CustomPaint(painter: _PlayMark()),
      ),
      SizedBox(width: mark * 0.32),
      Text('Vie', style: word.copyWith(color: Colors.white)),
      Text('Flix', style: word.copyWith(color: kRed)),
    ]);
  }
}

class _PlayMark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final squircle = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.28)));

    // Tam giác play, lệch trái nhẹ cho cân mắt.
    final s = w * 0.23;
    final cx = w * 0.42, cy = h * 0.5;
    final tri = Path()
      ..moveTo(cx - s * 0.72, cy - s)
      ..lineTo(cx - s * 0.72, cy + s)
      ..lineTo(cx + s * 0.95, cy)
      ..close();

    // KHOÉT RỖNG: lấy hiệu hai hình rồi tô một lần -> chỗ tam giác không được tô,
    // màu nền phía sau xuyên qua. Nét hơn hẳn việc vẽ tam giác trắng đè lên.
    canvas.drawPath(
      Path.combine(PathOperation.difference, squircle, tri),
      Paint()..color = kRed,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
