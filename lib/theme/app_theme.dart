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
  fontFamily: 'Segoe UI',
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
