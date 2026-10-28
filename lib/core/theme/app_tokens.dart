import 'package:flutter/material.dart';

/// Single source for every design literal: colors, spacing, radius, motion
/// and font names. Widgets read these through the theme, never directly
/// as hex values.
///
/// Every text/background pair used by the app is checked for 4.5:1 contrast
/// in test/core/theme/contrast_test.dart.
abstract final class AppColors {
  // Brand
  static const orange = Color(0xFFF97316);
  static const orangeLight = Color(0xFFFB923C);
  static const orangeDark = Color(0xFFC2410C); // orange text on light surfaces
  static const onOrange = Color(0xFF1F2937); // never white on orange

  // Dark theme (default)
  static const darkBackground = Color(0xFF1F2937);
  static const darkSurface = Color(0xFF2D3748); // cards, one step lighter
  static const darkSurfaceHigh = Color(0xFF374151); // inputs, sheets, insets
  static const darkText = Color(0xFFF8FAFC);
  static const darkTextMuted = Color(0xFFCBD5E1);
  static const darkBorder = Color(0xFF4B5563);
  static const darkSuccess = Color(0xFF22C55E);
  static const darkWarning = Color(0xFFF59E0B);
  static const darkDanger = Color(0xFFFCA5A5);

  // Light theme
  static const lightBackground = Color(0xFFF8FAFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFF1F5F9);
  static const lightText = Color(0xFF0F172A);
  static const lightTextMuted = Color(0xFF475569);
  static const lightBorder = Color(0xFFE5E7EB);
  static const lightSuccess = Color(0xFF15803D);
  static const lightWarning = Color(0xFFB45309);
  static const lightDanger = Color(0xFFB91C1C);

  // Shared
  static const white = Color(0xFFFFFFFF);
  static const scrim = Color(0x8A000000); // plain semi-transparent, no blur
  static const shadow = Color(0x1A0F172A);
  static const transparent = Color(0x00000000);

  // Tints (0xAARRGGBB): 15% orange for badge and nav-indicator fills
  static const orangeTint = Color(0x26F97316);
}

abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

abstract final class AppRadius {
  static const double control = 8;
  static const double card = 12;
  static const double sheet = 16;
}

abstract final class AppSizes {
  static const double minTouch = 48;
  static const double icon = 24;
  static const double qrOnCard = 112;
  static const double qrFullScreen = 264;
  static const double avatar = 72;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
  static const curve = Curves.easeOutCubic;
}

abstract final class AppFonts {
  static const heading = 'Barlow Condensed';
  static const body = 'Barlow';
}

/// Semantic colors that ColorScheme has no slot for. Read with
/// `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.accentText,
    required this.accentTint,
    required this.success,
    required this.warning,
    required this.danger,
    required this.skeleton,
    required this.cardGradient,
    required this.onCardGradient,
    required this.qrBackground,
    required this.cardShadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color text;
  final Color textMuted;
  final Color border;

  /// Orange used as text, icons and badges (highlight color).
  final Color accentText;

  /// Translucent orange fill behind [accentText] badges.
  final Color accentTint;
  final Color success;
  final Color warning;
  final Color danger;
  final Color skeleton;

  /// Membership card hero. Both stops pass 4.5:1 with [onCardGradient].
  final List<Color> cardGradient;
  final Color onCardGradient;
  final Color qrBackground;

  /// Null in dark mode: cards use a border instead.
  final Color? cardShadow;

  static const dark = AppPalette(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceHigh: AppColors.darkSurfaceHigh,
    text: AppColors.darkText,
    textMuted: AppColors.darkTextMuted,
    border: AppColors.darkBorder,
    accentText: AppColors.orangeLight,
    accentTint: AppColors.orangeTint,
    success: AppColors.darkSuccess,
    warning: AppColors.darkWarning,
    danger: AppColors.darkDanger,
    skeleton: AppColors.darkSurfaceHigh,
    cardGradient: [AppColors.orangeLight, AppColors.orange],
    onCardGradient: AppColors.onOrange,
    qrBackground: AppColors.white,
    cardShadow: null,
  );

  static const light = AppPalette(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceHigh: AppColors.lightSurfaceHigh,
    text: AppColors.lightText,
    textMuted: AppColors.lightTextMuted,
    border: AppColors.lightBorder,
    accentText: AppColors.orangeDark,
    accentTint: AppColors.orangeTint,
    success: AppColors.lightSuccess,
    warning: AppColors.lightWarning,
    danger: AppColors.lightDanger,
    skeleton: AppColors.lightBorder,
    cardGradient: [AppColors.orangeLight, AppColors.orange],
    onCardGradient: AppColors.onOrange,
    qrBackground: AppColors.white,
    cardShadow: AppColors.shadow,
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceHigh: c(surfaceHigh, other.surfaceHigh),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      border: c(border, other.border),
      accentText: c(accentText, other.accentText),
      accentTint: c(accentTint, other.accentTint),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      skeleton: c(skeleton, other.skeleton),
      cardGradient: [
        for (var i = 0; i < cardGradient.length; i++)
          c(cardGradient[i], other.cardGradient[i]),
      ],
      onCardGradient: c(onCardGradient, other.onCardGradient),
      qrBackground: c(qrBackground, other.qrBackground),
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
