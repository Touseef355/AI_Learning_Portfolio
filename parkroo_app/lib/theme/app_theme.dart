import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_constants.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  // ════════════════════════════════════════════════════════════
  //  DARK THEME
  // ════════════════════════════════════════════════════════════
  static ThemeData get darkTheme => _build(Brightness.dark);

  // ════════════════════════════════════════════════════════════
  //  LIGHT THEME
  // ════════════════════════════════════════════════════════════
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Resolved tokens
    final bg0   = isDark ? AppColors.bg0   : const Color(0xFFF0F4FF);
    final bg1   = isDark ? AppColors.bg1   : const Color(0xFFF7F8FC);
    final bg2   = isDark ? AppColors.bg2   : const Color(0xFFFFFFFF);
    final bg3   = isDark ? AppColors.bg3   : const Color(0xFFFFFFFF);
    final bg4   = isDark ? AppColors.bg4   : const Color(0xFFEEF1FA);

    final textPrimary   = isDark ? AppColors.textPrimary   : const Color(0xFF0D1121);
    final textSecondary = isDark ? AppColors.textSecondary : const Color(0xFF4A5070);
    final textHint      = isDark ? AppColors.textHint      : const Color(0xFF9AA0BC);

    final border      = isDark ? AppColors.border      : const Color(0x18000000);
    final borderFocus = isDark ? AppColors.borderFocus : const Color(0x4D4F6EF7);

    final statusIconBrightness =
        isDark ? Brightness.light : Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness:   brightness,
      fontFamily:   'SF Pro Display',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary:    AppColors.primary,
        secondary:  AppColors.primaryLight,
        surface:    bg2,
        error:      AppColors.danger,
        onPrimary:  AppColors.white,
        onSecondary: AppColors.white,
        onSurface:  textPrimary,
        onError:    AppColors.white,
        outline:    border,
      ),
      scaffoldBackgroundColor: bg1,

      // ── AppBar ──────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: bg1,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusIconBrightness,
        ),
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.1,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),

      // ── Inputs ──────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg4,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide(color: borderFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle:    AppTextStyles.labelLg,
        hintStyle:     AppTextStyles.bodyMd.copyWith(color: textHint),
        errorStyle:    AppTextStyles.labelMd.copyWith(color: AppColors.danger),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),

      // ── Elevated Button ─────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:         AppColors.primary,
          foregroundColor:         AppColors.white,
          disabledBackgroundColor: bg4,
          disabledForegroundColor: textHint,
          minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
          elevation:    0,
          shadowColor:  Colors.transparent,
          textStyle:    AppTextStyles.button,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),

      // ── Outlined Button ─────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:         AppColors.primary,
          disabledForegroundColor: textHint,
          minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
          side:      BorderSide(color: border, width: 1),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
          padding:   const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),

      // ── Text Button ─────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.buttonSm.copyWith(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),

      // ── Card ────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation:        0,
        color:            bg2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          side:         BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Bottom Nav ──────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:       bg2,
        selectedItemColor:     AppColors.primary,
        unselectedItemColor:   textHint,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:   const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),

      // ── Divider ─────────────────────────────────────────────
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      // ── Checkbox ────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.white),
        side: BorderSide(color: border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Switch ──────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.white;
          return textHint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return bg4;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ── Chip ────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: bg4,
        selectedColor:   AppColors.primaryGlow,
        labelStyle:      AppTextStyles.labelMd,
        side:            BorderSide(color: border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusFull)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── SnackBar ────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor:  bg3,
        contentTextStyle: AppTextStyles.bodyMd.copyWith(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side:         BorderSide(color: border),
        ),
        behavior:  SnackBarBehavior.floating,
        elevation: 0,
      ),

      // ── Dialog ──────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor:  bg2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusXl)),
        elevation:        0,
        titleTextStyle:   AppTextStyles.h3,
        contentTextStyle: AppTextStyles.bodyMd,
      ),

      // ── Bottom Sheet ─────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:  bg2,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation:      0,
        showDragHandle: false,
      ),

      // ── Tab Bar ─────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor:            AppColors.primary,
        unselectedLabelColor:  textHint,
        indicatorColor:        AppColors.primary,
        indicatorSize:         TabBarIndicatorSize.label,
        labelStyle:   const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        dividerColor:  border,
      ),
    );
  }
}
