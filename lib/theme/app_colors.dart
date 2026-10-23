import 'package:flutter/material.dart';

/// All app colors live here so you can change the look in one place.
class AppColors {
  static const backgroundTop = Color(0xFF2B1A12);
  static const backgroundBottom = Color(0xFF1A0F0A);
  static const background = Color(0xFF1A0F0A);
  static const card = Color(0xFF3B2519);
  static const cardHighlight = Color(0xFF4E3224);
  static const cream = Color(0xFFF5E9DD);
  static const gold = Color(0xFFE8C9A0);
  static const muted = Color(0xFFC9B8A8);
  static const error = Color(0xFFFFB4AB);
  static const buttonText = Color(0xFF1A0F0A);

  static const gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );
}
