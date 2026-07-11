import 'package:flutter/material.dart';

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF5B8CFF),
      Color(0xFF7B61FF),
    ],
  );

  static const LinearGradient darkSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1F2B),
      Color(0xFF12161F),
    ],
  );

  static const LinearGradient premiumGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x335B8CFF),
      Color(0x117B61FF),
    ],
  );

  static const LinearGradient headerOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x66000000),
      Color(0xDD000000),
    ],
  );
}