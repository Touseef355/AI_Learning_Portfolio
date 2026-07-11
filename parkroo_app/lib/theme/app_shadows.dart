import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Parkroo Shadow System — Phase 1 Premium Polish
/// Softer, more refined shadows for premium feel
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get none => [];

  static List<BoxShadow> get sm => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get md => [
    BoxShadow(
      color: Colors.black.withOpacity(0.18),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get lg => [
    BoxShadow(
      color: Colors.black.withOpacity(0.24),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get xl => [
    BoxShadow(
      color: Colors.black.withOpacity(0.32),
      blurRadius: 40,
      offset: const Offset(0, 14),
    ),
  ];

  // Softer, more premium glow — less "AI-generated cheap" feel
  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.22),
      blurRadius: 20,
      spreadRadius: -4,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: AppColors.primary.withOpacity(0.10),
      blurRadius: 40,
      spreadRadius: -8,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get successGlow => [
    BoxShadow(
      color: AppColors.success.withOpacity(0.20),
      blurRadius: 16,
      spreadRadius: -4,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get dangerGlow => [
    BoxShadow(
      color: AppColors.danger.withOpacity(0.20),
      blurRadius: 16,
      spreadRadius: -4,
      offset: const Offset(0, 4),
    ),
  ];

  // Card elevation shadow — for PkCard
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withOpacity(0.14),
      blurRadius: 18,
      spreadRadius: -2,
      offset: const Offset(0, 6),
    ),
  ];

  // Bottom nav shadow
  static List<BoxShadow> get bottomNav => [
    BoxShadow(
      color: Colors.black.withOpacity(0.28),
      blurRadius: 24,
      offset: const Offset(0, -4),
    ),
  ];
}
