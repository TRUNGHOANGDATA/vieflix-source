import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';

/// Logo góc kiểu kênh truyền hình ("logo bug" của VTV/HTV): nằm im một góc suốt
/// cả phim, để mờ cho khỏi tranh với hình. Khi người dùng bấm remote thì sáng rõ
/// lên cùng thanh điều khiển rồi mờ lại.
///
/// Là widget RỜI chứ không viết thẳng trong PlayerScreen để TEST được:
/// PlayerScreen dựng InAppWebView nên không pump được trong môi trường test.
class ChannelBug extends StatelessWidget {
  /// Độ mờ lúc nằm im (0.4 = 40%).
  static const double dimOpacity = 0.4;

  /// Tên phim, vd "Người Nhện".
  final String movieName;

  /// Nhãn tập, vd "Tập 5". Để RỖNG với phim lẻ -> chỉ hiện tên phim.
  /// Số tập tổng ("/ 16") KHÔNG hiện ở đây cho gọn — thanh điều khiển đã có.
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
    final line = episodeLabel.isEmpty ? movieName : '$movieName · $episodeLabel';
    // IgnorePointer nằm NGAY TRONG widget: logo chỉ để nhìn, không bao giờ được
    // "ăn" chuột — nếu không, cái góc này thành vùng chết đè lên phim trên PC.
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: bright ? 1.0 : dimOpacity,
        duration: const Duration(milliseconds: 250),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const BrandLogo(height: 20),
            const SizedBox(height: 3),
            // Tên phim dài phải cắt bớt, không thì tràn ngang che hết cảnh.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                // Bóng đen: cảnh phim sáng thì chữ trắng vẫn đọc được.
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
