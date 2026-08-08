import 'dart:io';
import 'package:flutter/material.dart';

const kBg = Color(0xFF141414);
const kSurface = Color(0xFF1F1F1F);
const kRed = Color(0xFFE50914);

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
