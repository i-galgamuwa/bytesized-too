import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dark brown gradient behind every screen.
class AppBackground extends StatelessWidget {
  AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: context.colors.gradient),
      child: child,
    );
  }
}
