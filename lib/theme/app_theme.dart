import 'dart:io';
import 'package:flutter/material.dart';

const kBg = Color(0xFF191B24);      // nền xám xanh — ĐÚNG màu RoPhim
const kSurface = Color(0xFF23252F);
const kRed = Color(0xFFE50914);
const kAmber = Color(0xFFF5C518);   // vàng IMDb / số thứ tự Top

/// Font đóng gói trong app (assets/fonts). Chữ THƯƠNG HIỆU (logo, logo góc khi
/// xem phim) phải ghim vào font này thay vì để theo theme: theme dùng Segoe UI
/// trên Windows nên nếu không ghim, logo sẽ ra hai kiểu chữ khác nhau giữa PC và
/// TV. Chữ giao diện thường thì vẫn để theo theme như cũ.
const kBrandFont = 'Be Vietnam Pro';

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.dark(
    primary: kRed,
    surface: kSurface,
  ),
  // Windows: dùng Segoe UI hệ thống. Android (TV): dùng Be Vietnam Pro đóng gói sẵn.
  fontFamily: Platform.isWindows ? 'Segoe UI' : 'Be Vietnam Pro',
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
