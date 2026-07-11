import 'package:flutter/material.dart';

/// Parkroo Design System — Dual-Mode Color Palette
///
/// Usage:
///   AppColors.of(context).background   ← always correct for current theme
///   AppColors.primary                   ← brand colors (same in both modes)
///
class AppColors {
  AppColors._();

  // ════════════════════════════════════════════════════════════
  //  BRAND — identical in light & dark
  // ════════════════════════════════════════════════════════════
  static const Color primary      = Color(0xFF4F6EF7);
  static const Color primaryLight = Color(0xFF7B93F9);
  static const Color primaryDark  = Color(0xFF3350D4);
  static const Color primaryGlow  = Color(0x264F6EF7);

  static const Color success      = Color(0xFF22C55E);
  static const Color successLight = Color(0xFF4ADE80);
  static const Color successGlow  = Color(0x1A22C55E);

  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningGlow  = Color(0x1AF59E0B);

  static const Color danger       = Color(0xFFEF4444);
  static const Color dangerLight  = Color(0xFFF87171);
  static const Color dangerGlow   = Color(0x1AEF4444);

  static const Color white        = Color(0xFFFFFFFF);
  static const Color black        = Color(0xFF000000);
  static const Color transparent  = Color(0x00000000);

  // Gradient stops
  static const Color gradientStart = Color(0xFF4F6EF7);
  static const Color gradientEnd   = Color(0xFF7B5CF9);

  // Gradient lists
  static const List<Color> primaryGradient = [Color(0xFF4F6EF7), Color(0xFF7B5CF9)];
  static const List<Color> successGradient = [Color(0xFF22C55E), Color(0xFF16A34A)];
  static const List<Color> cardGradient    = [Color(0xFF1A2035), Color(0xFF131829)];

  // Backward compat alias
  static const Color accent = success;

  // ════════════════════════════════════════════════════════════
  //  DARK MODE palette (static — backward compat)
  // ════════════════════════════════════════════════════════════
  static const Color bg0 = Color(0xFF060A12);
  static const Color bg1 = Color(0xFF0D1121);
  static const Color bg2 = Color(0xFF131829);
  static const Color bg3 = Color(0xFF1A2035);
  static const Color bg4 = Color(0xFF212840);

  static const Color background = bg1;
  static const Color surface    = bg2;
  static const Color surface2   = bg3;
  static const Color surface3   = bg4;

  static const Color border      = Color(0x1AFFFFFF);
  static const Color borderLight = Color(0x0DFFFFFF);
  static const Color borderFocus = Color(0x4D4F6EF7);

  static const Color textPrimary   = Color(0xFFF1F3FC);
  static const Color textSecondary = Color(0xFF8B93B8);
  static const Color textHint      = Color(0xFF4E566D);
  static const Color textDisabled  = Color(0xFF363D57);

  // ════════════════════════════════════════════════════════════
  //  THEME-AWARE — use AppColors.of(context).xxx
  // ════════════════════════════════════════════════════════════
  static AppColorScheme of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _dark : _light;
  }

  static const AppColorScheme _dark = AppColorScheme(
    // Backgrounds
    bgDeep:          Color(0xFF060A12),
    bgBase:          Color(0xFF0D1121),
    bgCard:          Color(0xFF131829),
    bgElevated:      Color(0xFF1A2035),
    bgInput:         Color(0xFF212840),

    // Text
    textPrimary:     Color(0xFFF1F3FC),
    textSecondary:   Color(0xFF8B93B8),
    textHint:        Color(0xFF4E566D),
    textDisabled:    Color(0xFF363D57),
    textOnAccent:    Color(0xFFFFFFFF),

    // Borders
    border:          Color(0x1AFFFFFF),
    borderFocus:     Color(0x4D4F6EF7),

    // Auth screen specifics
    authScaffold:     Color(0xFF060A12),
    authFormBg:       Color(0xD0060A12),      // glassmorphic overlay
    authFormBorder:   Color(0x12FFFFFF),
    authHandle:       Color(0x20FFFFFF),
    authSubtitle:     Color(0x72FFFFFF),
    authDividerText:  Color(0x4DFFFFFF),
    authSocialBg:     Color(0x0DFFFFFF),
    authSocialBorder: Color(0x1AFFFFFF),
    authSocialText:   Color(0x8CFFFFFF),
    authGlowColor:    Color(0xFF4F6EF7),      // primary glow
    statusBarLight:   false,                  // dark = white icons
  );

  static const AppColorScheme _light = AppColorScheme(
    // Backgrounds
    bgDeep:          Color(0xFFF0F2FA),
    bgBase:          Color(0xFFF7F8FC),
    bgCard:          Color(0xFFFFFFFF),
    bgElevated:      Color(0xFFFFFFFF),
    bgInput:         Color(0xFFF0F2FA),

    // Text
    textPrimary:     Color(0xFF0D1121),
    textSecondary:   Color(0xFF4A5070),
    textHint:        Color(0xFF9AA0BC),
    textDisabled:    Color(0xFFC4CAE0),
    textOnAccent:    Color(0xFFFFFFFF),

    // Borders
    border:          Color(0x18000000),
    borderFocus:     Color(0x4D4F6EF7),

    // Auth screen specifics
    authScaffold:     Color(0xFFF0F4FF),
    authFormBg:       Color(0xF5FFFFFF),      // near-white glass
    authFormBorder:   Color(0x18000000),
    authHandle:       Color(0x20000000),
    authSubtitle:     Color(0x80000000),
    authDividerText:  Color(0x55000000),
    authSocialBg:     Color(0x08000000),
    authSocialBorder: Color(0x14000000),
    authSocialText:   Color(0x80000000),
    authGlowColor:    Color(0xFF4F6EF7),
    statusBarLight:   true,                   // light = dark icons
  );
}

/// Resolved color set for the current theme mode.
class AppColorScheme {
  final Color bgDeep, bgBase, bgCard, bgElevated, bgInput;
  final Color textPrimary, textSecondary, textHint, textDisabled, textOnAccent;
  final Color border, borderFocus;

  // Auth-specific
  final Color authScaffold, authFormBg, authFormBorder;
  final Color authHandle, authSubtitle, authDividerText;
  final Color authSocialBg, authSocialBorder, authSocialText;
  final Color authGlowColor;
  final bool  statusBarLight;

  const AppColorScheme({
    required this.bgDeep,
    required this.bgBase,
    required this.bgCard,
    required this.bgElevated,
    required this.bgInput,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.textDisabled,
    required this.textOnAccent,
    required this.border,
    required this.borderFocus,
    required this.authScaffold,
    required this.authFormBg,
    required this.authFormBorder,
    required this.authHandle,
    required this.authSubtitle,
    required this.authDividerText,
    required this.authSocialBg,
    required this.authSocialBorder,
    required this.authSocialText,
    required this.authGlowColor,
    required this.statusBarLight,
  });
}
