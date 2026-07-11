import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_surfaces.dart';

class AppGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const AppGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 16,
          sigmaY: 16,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppSurfaces.glass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: AppSurfaces.border,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}