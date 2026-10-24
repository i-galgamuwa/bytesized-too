import 'package:flutter/material.dart';

class AppColors {
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color background;
  final Color card;
  final Color cardHighlight;
  final Color cream;
  final Color gold;
  final Color muted;
  final Color error;
  final Color buttonText;

  const AppColors({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.background,
    required this.card,
    required this.cardHighlight,
    required this.cream,
    required this.gold,
    required this.muted,
    required this.error,
    required this.buttonText,
  });

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );

  static const AppColors dark = AppColors(
    backgroundTop: Color(0xFF0F172A), // Slate 900
    backgroundBottom: Color(0xFF020617), // Slate 950
    background: Color(0xFF0F172A), // Slate 900
    card: Color(0xFF1E293B), // Slate 800
    cardHighlight: Color(0xFF334155), // Slate 700
    cream: Color(0xFFF8FAFC), // Slate 50 (Text)
    gold: Color(0xFF3B82F6), // Blue 500 (Accent)
    muted: Color(0xFF94A3B8), // Slate 400 (Muted text)
    error: Color(0xFFF87171), // Red 400
    buttonText: Color(0xFFFFFFFF),
  );

  static const AppColors light = AppColors(
    backgroundTop: Color(0xFFF8FAFC), // Slate 50
    backgroundBottom: Color(0xFFE2E8F0), // Slate 200
    background: Color(0xFFF8FAFC), // Slate 50
    card: Color(0xFFFFFFFF), // White
    cardHighlight: Color(0xFFF1F5F9), // Slate 100
    cream: Color(0xFF0F172A), // Slate 900 (Text)
    gold: Color(0xFF2563EB), // Blue 600 (Accent)
    muted: Color(0xFF64748B), // Slate 500 (Muted text)
    error: Color(0xFFEF4444), // Red 500
    buttonText: Color(0xFFFFFFFF),
  );
}

extension ThemeColorsExt on BuildContext {
  AppColors get colors => Theme.of(this).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
}
