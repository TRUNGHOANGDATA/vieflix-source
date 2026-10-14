import 'package:flutter/material.dart';

// Bảng màu theo mẫu thiết kế 10/2026: nền xanh-tím rất tối cho hợp ảnh nền điện
// ảnh đỏ/tím (assets/images/app_bg.jpg), thay cho xám xanh kiểu RoPhim cũ.
const kBg = Color(0xFF0E0D16);
const kSurface = Color(0xFF1C1B27);
const kRed = Color(0xFFE50914);
const kRedHot = Color(0xFFFF2D55);  // đầu sáng của dải đỏ trên nút chính
const kAmber = Color(0xFFF5C518);   // vàng IMDb / số thứ tự Top

/// Dải đỏ cho nút "Xem ngay" / huy hiệu TOP.
const kRedGradient = LinearGradient(colors: [kRedHot, kRed]);

/// Font đóng gói trong app (assets/fonts), dùng cho TOÀN BỘ chữ trên mọi nền
/// tảng (trước 10/2026 Windows dùng Segoe UI hệ thống). Logo vẫn ghim thẳng tên
/// font này để không lệ thuộc theme.
const kBrandFont = 'Be Vietnam Pro';

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.dark(
    primary: kRed,
    surface: kSurface,
  ),
  // Mọi nền tảng cùng một font đóng gói -> PC, TV, iPad nhìn y hệt nhau.
  fontFamily: kBrandFont,
  useMaterial3: true,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kRed,
      foregroundColor: Colors.white,
      disabledBackgroundColor: kSurface,
      disabledForegroundColor: Colors.white38,
    ),
  ),
);
