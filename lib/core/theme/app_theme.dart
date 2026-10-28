import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Material 3 themes built only from [AppColors], [AppSpace], [AppRadius]
/// and [AppFonts].
abstract final class AppTheme {
  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);
  static ThemeData get light => _build(Brightness.light, AppPalette.light);

  /// Full type scale. Headings use Barlow Condensed, everything else Barlow.
  /// Body styles never go below 16sp.
  static TextTheme textTheme(Color text, Color muted) {
    TextStyle heading(double size, FontWeight weight) => TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: size,
          fontWeight: weight,
          height: 1.15,
          color: text,
        );
    TextStyle body(double size, FontWeight weight, {Color? color}) =>
        TextStyle(
          fontFamily: AppFonts.body,
          fontSize: size,
          fontWeight: weight,
          height: 1.4,
          color: color ?? text,
        );

    return TextTheme(
      displayLarge: heading(48, FontWeight.w700),
      displayMedium: heading(40, FontWeight.w700),
      displaySmall: heading(32, FontWeight.w700),
      headlineLarge: heading(28, FontWeight.w700),
      headlineMedium: heading(24, FontWeight.w700),
      headlineSmall: heading(22, FontWeight.w600),
      titleLarge: heading(20, FontWeight.w600),
      titleMedium: body(18, FontWeight.w600),
      titleSmall: body(16, FontWeight.w600),
      bodyLarge: body(18, FontWeight.w400),
      bodyMedium: body(16, FontWeight.w400),
      bodySmall: body(16, FontWeight.w400, color: muted),
      labelLarge: body(16, FontWeight.w600),
      labelMedium: body(14, FontWeight.w600),
      labelSmall: body(12, FontWeight.w600),
    );
  }

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final isDark = brightness == Brightness.dark;
    final text = textTheme(p.text, p.textMuted);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.orange,
      onPrimary: AppColors.onOrange,
      primaryContainer: p.accentTint,
      onPrimaryContainer: p.text,
      secondary: AppColors.orangeLight,
      onSecondary: AppColors.onOrange,
      tertiary: p.success,
      onTertiary: isDark ? AppColors.onOrange : AppColors.white,
      error: p.danger,
      onError: isDark ? AppColors.onOrange : AppColors.white,
      surface: p.background,
      onSurface: p.text,
      onSurfaceVariant: p.textMuted,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceHigh,
      surfaceContainerHighest: p.surfaceHigh,
      outline: p.border,
      outlineVariant: p.border,
      shadow: AppColors.shadow,
      scrim: AppColors.scrim,
      surfaceTint: AppColors.transparent,
    );

    const controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
    );
    const minButton = Size(AppSizes.minTouch, AppSizes.minTouch);
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpace.lg);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      fontFamily: AppFonts.body,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.border,
      splashFactory: InkRipple.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.onOrange,
          disabledBackgroundColor: p.surfaceHigh,
          disabledForegroundColor: p.textMuted,
          minimumSize: minButton,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.onOrange,
          disabledBackgroundColor: p.surfaceHigh,
          disabledForegroundColor: p.textMuted,
          elevation: 0,
          minimumSize: minButton,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.border),
          minimumSize: minButton,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentText,
          minimumSize: minButton,
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: minButton,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: AppColors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: isDark ? 0 : 1,
        shadowColor: p.cardShadow ?? AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: isDark ? BorderSide(color: p.border) : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceHigh,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: text.bodyMedium?.copyWith(color: p.textMuted),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: p.text),
        hintStyle: text.bodyMedium?.copyWith(color: p.textMuted),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: p.danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.md,
        ),
        border: inputBorder(p.border),
        enabledBorder: inputBorder(p.border),
        focusedBorder: inputBorder(AppColors.orange, 2),
        errorBorder: inputBorder(p.danger),
        focusedErrorBorder: inputBorder(p.danger, 2),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: AppColors.transparent,
        modalBackgroundColor: p.surface,
        modalBarrierColor: AppColors.scrim,
        showDragHandle: true,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: AppColors.transparent,
        barrierColor: AppColors.scrim,
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: AppColors.transparent,
        indicatorColor: p.accentTint,
        elevation: 0,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? p.accentText : p.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected) ? p.text : p.textMuted,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceHigh,
        selectedColor: p.accentTint,
        checkmarkColor: p.accentText,
        side: BorderSide(color: p.border),
        labelStyle: text.labelLarge?.copyWith(color: p.text),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surfaceHigh,
        contentTextStyle: text.bodyMedium,
        actionTextColor: p.accentText,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textMuted,
        textColor: p.text,
        minVerticalPadding: AppSpace.sm,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.orange,
        linearTrackColor: p.surfaceHigh,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.onOrange : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.orange : p.surfaceHigh,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
