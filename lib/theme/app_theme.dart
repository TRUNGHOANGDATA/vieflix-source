import 'dart:io';
import 'package:flutter/material.dart';

const kBg = Color(0xFF0B0B10);      // nền tối sâu (giống các trang phim hiện đại)
const kSurface = Color(0xFF17171E);
const kRed = Color(0xFFE50914);
const kAmber = Color(0xFFF5C518);   // vàng IMDb

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
