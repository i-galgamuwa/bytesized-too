import 'package:flutter/material.dart';

/// Styling shared by the live route and the read-only shift map.
class LiveMapConfig {
  const LiveMapConfig._();

  static const tileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const tileSubdomains = ['a', 'b', 'c', 'd'];
  static const userAgentPackageName = 'com.example.gps_sales_tracker';
  static const routeColor = Colors.white;
  static const routeWidth = 4.5;
  static const routeGlowColor = Color(0x99FFFFFF);
  static const routeGlowWidth = 10;
  static const mapTint = Color(0x401A0F0A);
}
