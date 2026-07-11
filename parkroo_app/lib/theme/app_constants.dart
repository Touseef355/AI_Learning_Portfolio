/// Parkroo Premium Design System — Spacing & Constants
class AppConstants {
  AppConstants._();

  // ── Spacing Scale (4pt grid) ───────────────────────────────────────────────
  static const double sp2  = 2.0;
  static const double sp4  = 4.0;
  static const double sp6  = 6.0;
  static const double sp8  = 8.0;
  static const double sp10 = 10.0;
  static const double sp12 = 12.0;
  static const double sp16 = 16.0;
  static const double sp20 = 20.0;
  static const double sp24 = 24.0;
  static const double sp28 = 28.0;
  static const double sp32 = 32.0;
  static const double sp40 = 40.0;
  static const double sp48 = 48.0;
  static const double sp56 = 56.0;
  static const double sp64 = 64.0;

  // ── Legacy aliases (preserve backward compat) ─────────────────────────────
  static const double defaultPadding          = sp16;
  static const double defaultPaddingSmall     = sp8;
  static const double defaultPaddingLarge     = sp24;
  static const double defaultPaddingExtraLarge = sp32;

  // ── Border Radius System ──────────────────────────────────────────────────
  static const double radiusXs  = 6.0;
  static const double radiusSm  = 10.0;
  static const double radiusMd  = 14.0;
  static const double radiusLg  = 18.0;
  static const double radiusXl  = 24.0;
  static const double radius2xl = 32.0;
  static const double radiusFull = 999.0;

  // ── Legacy aliases ─────────────────────────────────────────────────────────
  static const double borderRadiusSmall      = radiusSm;
  static const double borderRadiusMedium     = radiusMd;
  static const double borderRadiusLarge      = radiusLg;
  static const double borderRadiusExtraLarge = radiusXl;
  static const double borderRadiusCircular   = radiusFull;

  // ── Button Heights ────────────────────────────────────────────────────────
  static const double buttonHeight      = 56.0;
  static const double buttonHeightSmall = 44.0;
  static const double buttonHeightXs    = 36.0;
  static const double buttonHeightLarge = 56;
  static const double buttonHeightMedium = 48;
  static const double buttonHeightXSmall = 32;
  
  static const double inputHeightLarge = 56;
  static const double inputHeightMedium = 48;
  
  static const double cardPaddingLarge = 20;
  static const double cardPaddingMedium = 16;
  static const double cardPaddingSmall = 12;
  // ── Icon Sizes ────────────────────────────────────────────────────────────
  static const double iconSizeSmall      = 16.0;
  static const double iconSizeMedium     = 20.0;
  static const double iconSizeLarge      = 24.0;
  static const double iconSizeExtraLarge = 28.0;

  // ── Avatar Sizes ──────────────────────────────────────────────────────────
  static const double avatarSizeSmall  = 36.0;
  static const double avatarSizeMedium = 48.0;
  static const double avatarSizeLarge  = 72.0;
  static const double avatarSizeXl     = 88.0;

  // ── Animation Durations ───────────────────────────────────────────────────
  static const Duration durationFast   = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow   = Duration(milliseconds: 400);
  static const Duration animationDuration = durationNormal;
  static const Duration splashDuration    = Duration(seconds: 2);
  static const Duration otpTimeout        = Duration(minutes: 5);
  static const Duration durationMicro = Duration(milliseconds: 80);
  static const Duration durationExtraSlow = Duration(milliseconds: 600);

  // ── App-specific constants ────────────────────────────────────────────────
  static const List<int> presetAmounts = [500, 1000, 2000, 5000];
  static const List<String> vehicleTypes = ['Sedan', 'SUV', 'Hatchback', 'Pickup', 'Van'];

  // ── Page Padding ──────────────────────────────────────────────────────────
  static const double pagePaddingH = 20.0;  // horizontal page padding
  static const double pagePaddingV = 16.0;  // vertical section gap
  // ── Elevation System ──────────────────────────────────────────
  static const double elevation0 = 0;
  static const double elevation1 = 2;
  static const double elevation2 = 4;
  static const double elevation3 = 8;
  static const double elevation4 = 12;
  static const double elevation5 = 16;


}
