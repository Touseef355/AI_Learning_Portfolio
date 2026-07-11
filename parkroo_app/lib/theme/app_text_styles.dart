import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Parkroo Typography System
/// Scale: display → headline → title → body → label → caption
///
/// NOTE: Color fields here are intentionally omitted (null) so that Flutter
/// inherits the correct color from DefaultTextStyle / theme. Callers that
/// need a specific color should use `.copyWith(color: colors.textPrimary)`.
/// The legacy static aliases below keep backward compatibility where the
/// old dark-only colors were previously baked in.
class AppTextStyles {
  AppTextStyles._();

  // ── Display (hero sections, splash) ───────────────────────────────────────
  static const TextStyle display1 = TextStyle(
    fontSize: 40, fontWeight: FontWeight.w800,
    letterSpacing: -1.0, height: 1.1,
  );
  static const TextStyle display2 = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w700,
    letterSpacing: -0.8, height: 1.15,
  );

  // ── Headline ──────────────────────────────────────────────────────────────
  static const TextStyle h1 = TextStyle(
    fontSize: 26, fontWeight: FontWeight.w700,
    letterSpacing: -0.5, height: 1.2,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700,
    letterSpacing: -0.3, height: 1.25,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600,
    letterSpacing: -0.2, height: 1.3,
  );

  // ── Title ─────────────────────────────────────────────────────────────────
  static const TextStyle titleLg = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    letterSpacing: -0.1, height: 1.4,
  );
  static const TextStyle titleMd = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle titleSm = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle bodyMd = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle bodySm = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ── Label ─────────────────────────────────────────────────────────────────
  static const TextStyle labelLg = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500,
    letterSpacing: 0.1, height: 1.4,
  );
  static const TextStyle labelMd = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w500,
    letterSpacing: 0.2, height: 1.4,
  );
  static const TextStyle labelSm = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    letterSpacing: 0.3, height: 1.3,
  );

  // ── Caption ───────────────────────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    height: 1.3,
  );

  // ── Special ───────────────────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white,
    letterSpacing: 0.1, height: 1.0,
  );
  static const TextStyle buttonSm = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white,
    letterSpacing: 0.1, height: 1.0,
  );
  static const TextStyle overline = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w600,
    letterSpacing: 1.2, height: 1.3,
  );
  static const TextStyle mono = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'monospace',
    letterSpacing: 0.5, height: 1.4,
  );
}