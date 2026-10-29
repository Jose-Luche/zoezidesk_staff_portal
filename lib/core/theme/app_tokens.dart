import 'package:flutter/material.dart';

/// Single source for every design literal: colors, spacing, radius, shadows,
/// motion and font names (design.md §2, the Organic "Shift home" system).
/// Widgets read colors through `context.palette`, never as hex values.
///
/// Every text/background pair the app uses is checked for 4.5:1 contrast
/// in test/core/theme/contrast_test.dart.
abstract final class Organic {
  static const bg = Color(0xFFF5EAD8);
  static const surface = Color(0xFFEBDDC5);
  static const text = Color(0xFF201E1D);
  static const accent = Color(0xFFC67139);

  // Neutral ramp
  static const n100 = Color(0xFFF9F4ED);
  static const n200 = Color(0xFFEEE7DB);
  static const n300 = Color(0xFFDCD3C4);
  static const n400 = Color(0xFFC0B6A5);
  static const n500 = Color(0xFFA19786);
  static const n600 = Color(0xFF82796A);
  static const n700 = Color(0xFF645C50);
  static const n800 = Color(0xFF474238);
  static const n900 = Color(0xFF2E2B25);

  // Accent (terracotta) ramp
  static const accent100 = Color(0xFFFFF2EB);
  static const accent200 = Color(0xFFFFE1D0);
  static const accent300 = Color(0xFFFFC6A5);
  static const accent400 = Color(0xFFF6A06B);
  static const accent500 = Color(0xFFD67F48);
  static const accent600 = Color(0xFFB2622D);
  static const accent700 = Color(0xFF8C491A);
  static const accent800 = Color(0xFF643312);
  static const accent900 = Color(0xFF402310);

  // Accent 2 (sage) ramp
  static const sage100 = Color(0xFFF0FAE1);
  static const sage200 = Color(0xFFE1EECC);
  static const sage300 = Color(0xFFCCDBB2);
  static const sage400 = Color(0xFFAEBF92);
  static const sage500 = Color(0xFF8FA073);
  static const sage600 = Color(0xFF728157);
  static const sage700 = Color(0xFF56633F);
  static const sage800 = Color(0xFF3D472B);
  static const sage900 = Color(0xFF272E1B);

  static const transparent = Color(0x00000000);
}

/// 1.1× density scale: 4.4, 8.8, 13.2, 17.6, 26.4, 35.2, used rounded.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double xxl = 26;
  static const double xxxl = 36;
}

/// Screen gutters: headings sit further in than card stacks, and list rows
/// (which pad themselves by 10) sit closest to the edge.
abstract final class AppGutter {
  static const double heading = 22;
  static const double cards = 16;
  static const double rows = 12;

  /// Room under the content for the floating nav pill.
  static const double belowNav = 120;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 16;
  static const double tile = 22;
  static const double card = 26;
  static const double lg = 28;
  static const double sheet = 34;
  static const double pill = 999;
}

abstract final class AppSizes {
  static const double minTouch = 44;
  static const double button = 54;
  static const double input = 50;
  static const double quickAction = 46;
  static const double navItem = 46;
  static const double scanButton = 138;
  static const double checkToggle = 44;
  static const double smallButton = 36;
}

/// Shadows tinted with neutral 900 (design.md §2.3). Cards stay flat.
abstract final class AppShadows {
  static const _tint = Organic.n900;

  static final sm = [BoxShadow(color: _tint.withValues(alpha: 0.14), offset: const Offset(0, 1), blurRadius: 2)];
  static final md = [BoxShadow(color: _tint.withValues(alpha: 0.16), offset: const Offset(0, 3), blurRadius: 10)];
  static final lg = [BoxShadow(color: _tint.withValues(alpha: 0.22), offset: const Offset(0, 12), blurRadius: 32)];
}

abstract final class AppMotion {
  static const sheet = Duration(milliseconds: 340);
  static const backdrop = Duration(milliseconds: 300);
  static const fast = Duration(milliseconds: 200);
  static const toast = Duration(milliseconds: 250);
  static const toastHold = Duration(milliseconds: 2400);
  static const pulse = Duration(milliseconds: 1400);
  static const curve = Cubic(0.2, 0.8, 0.2, 1);

  /// Zero when the phone asks for reduced motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

abstract final class AppFonts {
  static const display = 'Caprasimo';
  static const body = 'Figtree';
}

/// A semantic fill and the text that goes on it.
@immutable
class Tint {
  const Tint(this.fill, this.on);

  final Color fill;
  final Color on;

  static Tint lerp(Tint a, Tint b, double t) => Tint(Color.lerp(a.fill, b.fill, t)!, Color.lerp(a.on, b.on, t)!);
}

/// Semantic colors, light and dark. Read with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.placeholder,
    required this.divider,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.inverseAccent,
    required this.primary,
    required this.onPrimary,
    required this.primaryPressed,
    required this.sage,
    required this.sageStrong,
    required this.onSageStrong,
    required this.success,
    required this.successTag,
    required this.warning,
    required this.danger,
    required this.neutral,
    required this.track,
    required this.hover,
    required this.skeleton,
    required this.halo,
    required this.decoration,
    required this.chartBar,
    required this.avatarSage,
    required this.avatarTerra,
    required this.avatarSand,
    required this.methodBank,
    required this.scrim,
  });

  /// Scaffold and sheets.
  final Color background;

  /// Cards, inputs, stat tiles.
  final Color surface;
  final Color text;

  /// Secondary text; passes 4.5:1 on [background] and [surface].
  final Color muted;

  /// Placeholders and decoration only, never meaningful text.
  final Color placeholder;

  /// Input and outline borders.
  final Color divider;

  /// Scan button, selection, icons, headline-sized text.
  final Color accent;

  /// Text on [accent] (labels on a selected nav item).
  final Color onAccent;

  /// Accent as body-sized text: ghost buttons, links.
  final Color accentText;

  /// Accent on a [text] fill (the toast's action, the nav pill).
  final Color inverseAccent;

  /// Filled-button fill, and the text on it.
  final Color primary;
  final Color onPrimary;
  final Color primaryPressed;

  /// Success and "yours" accents: switch tracks, check toggles, dots.
  final Color sage;

  /// Sage fills under text (selected note-type chips).
  final Color sageStrong;
  final Color onSageStrong;

  /// Banners and cards by meaning.
  final Tint success;

  /// Lighter success, for tags.
  final Tint successTag;
  final Tint warning;
  final Tint danger;
  final Tint neutral;

  /// Switch off, check-toggle ring, drag handle.
  final Color track;

  /// Row hover and pressed fill.
  final Color hover;
  final Color skeleton;

  /// The ring around the Scan button and success circles.
  final Color halo;

  /// The one soft circle bleeding off Home.
  final Color decoration;
  final Color chartBar;
  final Tint avatarSage;
  final Tint avatarTerra;
  final Tint avatarSand;

  /// The bank dot in revenue breakdowns (M-Pesa is [sage], cash [accent]).
  final Color methodBank;
  final Color scrim;

  static final light = AppPalette(
    background: Organic.bg,
    surface: Organic.surface,
    text: Organic.text,
    muted: Organic.n700,
    placeholder: Organic.n600,
    divider: Organic.text.withValues(alpha: 0.16),
    accent: Organic.accent,
    onAccent: Organic.text,
    accentText: Organic.accent700,
    inverseAccent: Organic.accent,
    primary: Organic.accent700,
    onPrimary: Organic.bg,
    primaryPressed: Organic.accent800,
    sage: Organic.sage600,
    sageStrong: Organic.sage700,
    onSageStrong: Organic.bg,
    success: const Tint(Organic.sage200, Organic.sage800),
    successTag: const Tint(Organic.sage100, Organic.sage800),
    warning: const Tint(Organic.accent100, Organic.accent800),
    danger: const Tint(Organic.accent200, Organic.accent900),
    neutral: const Tint(Organic.n100, Organic.n800),
    track: Organic.n400,
    hover: Organic.n100,
    skeleton: Organic.n300,
    halo: Organic.accent200,
    decoration: Organic.sage200,
    chartBar: Organic.sage300,
    avatarSage: const Tint(Organic.sage200, Organic.sage800),
    avatarTerra: const Tint(Organic.accent200, Organic.accent800),
    avatarSand: const Tint(Organic.n300, Organic.n800),
    methodBank: Organic.n500,
    scrim: Organic.n900.withValues(alpha: 0.5),
  );

  /// Ground neutral 900, surface 800, tints as 800 fills with 200 text.
  static final dark = AppPalette(
    background: Organic.n900,
    surface: Organic.n800,
    text: Organic.n100,
    muted: Organic.n300,
    placeholder: Organic.n500,
    divider: Organic.n100.withValues(alpha: 0.16),
    accent: Organic.accent400,
    onAccent: Organic.n900,
    accentText: Organic.accent300,
    inverseAccent: Organic.accent700,
    primary: Organic.accent400,
    onPrimary: Organic.n900,
    primaryPressed: Organic.accent300,
    sage: Organic.sage400,
    sageStrong: Organic.sage400,
    onSageStrong: Organic.n900,
    success: const Tint(Organic.sage800, Organic.sage200),
    successTag: const Tint(Organic.sage800, Organic.sage200),
    warning: const Tint(Organic.accent800, Organic.accent200),
    danger: const Tint(Organic.accent900, Organic.accent200),
    neutral: const Tint(Organic.n700, Organic.n100),
    track: Organic.n600,
    hover: Organic.n800,
    skeleton: Organic.n700,
    halo: Organic.accent800,
    decoration: Organic.sage800,
    chartBar: Organic.sage700,
    avatarSage: const Tint(Organic.sage800, Organic.sage200),
    avatarTerra: const Tint(Organic.accent800, Organic.accent200),
    avatarSand: const Tint(Organic.n700, Organic.n100),
    methodBank: Organic.n400,
    scrim: Organic.n900.withValues(alpha: 0.6),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    Tint n(Tint a, Tint b) => Tint.lerp(a, b, t);
    return AppPalette(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      text: c(text, other.text),
      muted: c(muted, other.muted),
      placeholder: c(placeholder, other.placeholder),
      divider: c(divider, other.divider),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentText: c(accentText, other.accentText),
      inverseAccent: c(inverseAccent, other.inverseAccent),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryPressed: c(primaryPressed, other.primaryPressed),
      sage: c(sage, other.sage),
      sageStrong: c(sageStrong, other.sageStrong),
      onSageStrong: c(onSageStrong, other.onSageStrong),
      success: n(success, other.success),
      successTag: n(successTag, other.successTag),
      warning: n(warning, other.warning),
      danger: n(danger, other.danger),
      neutral: n(neutral, other.neutral),
      track: c(track, other.track),
      hover: c(hover, other.hover),
      skeleton: c(skeleton, other.skeleton),
      halo: c(halo, other.halo),
      decoration: c(decoration, other.decoration),
      chartBar: c(chartBar, other.chartBar),
      avatarSage: n(avatarSage, other.avatarSage),
      avatarTerra: n(avatarTerra, other.avatarTerra),
      avatarSand: n(avatarSand, other.avatarSand),
      methodBank: c(methodBank, other.methodBank),
      scrim: c(scrim, other.scrim),
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
