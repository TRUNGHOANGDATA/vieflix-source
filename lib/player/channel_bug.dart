import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Logo góc kiểu kênh truyền hình ("logo bug" của VTV/HTV): nằm im góc trên-phải
/// suốt cả phim, để mờ cho khỏi tranh với hình. Khi người dùng bấm remote thì
/// sáng rõ lên cùng thanh điều khiển rồi mờ lại.
///
/// Cách xếp chữ bám đúng bug của kênh TV — tương phản ĐẬM/NHẠT là thứ tạo ra cảm
/// giác "đài truyền hình":
///   ▶ VIEFLIX              <- w700, IN HOA, letter-spacing rộng
///   ────────────           <- hairline 1px
///   Người Nhện · TẬP 5     <- w500 nhỏ hơn, riêng số tập quay lại w700
///
/// Chỉ dùng 4 độ đậm mà app có nhúng (400/500/600/700): khai w800/w900 cũng chỉ
/// ra đúng file Bold nên không tạo thêm tương phản.
///
/// Là widget RỜI chứ không viết thẳng trong PlayerScreen để TEST được:
/// PlayerScreen dựng InAppWebView nên không pump được trong môi trường test.
class ChannelBug extends StatelessWidget {
  /// Độ mờ lúc nằm im. 0.6 là mức của bản mockup đã chốt — đủ rõ để đọc từ xa
  /// trên TV mà vẫn không tranh với hình.
  static const double dimOpacity = 0.6;

  /// Tên phim, vd "Người Nhện".
  final String movieName;

  /// Nhãn tập, vd "Tập 5" (sẽ tự IN HOA). Để RỖNG với phim lẻ -> chỉ hiện tên.
  final String episodeLabel;

  /// true khi thanh điều khiển đang hiện -> logo sáng rõ 100%.
  final bool bright;

  const ChannelBug({
    super.key,
    required this.movieName,
    this.episodeLabel = '',
    this.bright = false,
  });

  @override
  Widget build(BuildContext context) {
    const prog = TextStyle(
      fontFamily: kBrandFont, // ghim để logo góc giống nhau trên PC và TV
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.15,
      // Bóng đen: cảnh phim sáng thì chữ trắng vẫn đọc được.
      shadows: [Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1))],
    );

    // IgnorePointer nằm NGAY TRONG widget để không ai gọi mà quên: logo chỉ để
    // nhìn, góc đó không được "ăn" chuột đè lên phim.
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: bright ? 1.0 : dimOpacity,
        duration: const Duration(milliseconds: 250),
        child: ConstrainedBox(
          // Tên phim dài phải cắt bớt, không thì tràn ngang che hết cảnh.
          constraints: const BoxConstraints(maxWidth: 340),
          // IntrinsicWidth để hairline rộng đúng bằng dòng chữ dài nhất.
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  // Tam giác vẽ bằng CustomPaint, KHÔNG dùng ký tự "▶": glyph phụ
                  // thuộc font, máy thiếu font là ra ô vuông.
                  const SizedBox(width: 9, height: 11, child: CustomPaint(painter: _PlayTri())),
                  const SizedBox(width: 7),
                  const Text(
                    'VIEFLIX',
                    style: TextStyle(
                      fontFamily: kBrandFont,
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                      height: 1.0,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1))],
                    ),
                  ),
                ]),
                const SizedBox(height: 5),
                // 0.5 chứ không phải 0.28: cả khối còn bị nhân với opacity 0.6 nữa
                // nên 0.28 ra ~17% trắng, gần như tàng hình trên cảnh tối.
                Container(height: 1, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: movieName, style: prog),
                    if (episodeLabel.isNotEmpty) ...[
                      TextSpan(text: ' · ', style: prog.copyWith(color: Colors.white54)),
                      TextSpan(
                        text: episodeLabel.toUpperCase(),
                        style: prog.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
                      ),
                    ],
                  ]),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tam giác play đỏ, cùng hình khối với tam giác khoét rỗng trong BrandLogo.
class _PlayTri extends CustomPainter {
  const _PlayTri();

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(0, s.height)
      ..lineTo(s.width, s.height / 2)
      ..close();
    canvas.drawPath(p, Paint()..color = kRed);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
