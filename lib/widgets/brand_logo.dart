import 'package:flutter/material.dart';

/// Logo thương hiệu VieFlix: khối play đỏ uốn dải + chữ "Vie" trắng "Flix" đỏ.
///
/// Từ 10/2026 dùng ẢNH do chủ dự án thiết kế (assets/images/logo.png, nền trong
/// suốt, đã cắt sát mép, cao 180px để nét ở mọi cỡ hiển thị) thay cho bản vẽ
/// bằng code trước đây. [height] là chiều cao của cả logo; bề ngang tự theo tỉ lệ
/// ảnh (~3.4 : 1).
class BrandLogo extends StatelessWidget {
  final double height;
  const BrandLogo({super.key, this.height = 34});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/logo.png',
        height: height,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'VieFlix',
      );
}
