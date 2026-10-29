import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Material 3 themes built only from the tokens in app_tokens.dart.
/// Pills for every control, flat cards, Caprasimo for display and headings,
/// Figtree for everything else (design.md §2, §7).
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppPalette.light);
  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);

  /// The type scale in design.md §2.2. One change from the table: list titles
  /// (Figtree 600 15) are [TextTheme.titleSmall], so [TextTheme.bodyLarge],
  /// which text fields use, stays regular weight.
  static TextTheme textTheme(Color text, Color muted) {
    TextStyle display(double size, double height) => TextStyle(
          fontFamily: AppFonts.display,
          fontSize: size,
          fontWeight: FontWeight.w400,
          height: height,
          letterSpacing: -0.015 * size,
          color: text,
        );
    TextStyle body(double size, FontWeight weight, double height, {Color? color}) => TextStyle(
          fontFamily: AppFonts.body,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color ?? text,
        );

    return TextTheme(
      displayLarge: display(40, 1.04),
      displayMedium: display(36, 1.05),
      displaySmall: display(30, 1.08),
      headlineLarge: display(32, 1.1),
      headlineMedium: display(24, 1.15),
      headlineSmall: display(22, 1.15),
      titleLarge: display(20, 1.2),
      titleMedium: display(17, 1.2),
      titleSmall: body(15, FontWeight.w600, 1.4),
      bodyLarge: body(15, FontWeight.w400, 1.4),
      bodyMedium: body(14, FontWeight.w400, 1.5),
      bodySmall: body(12.5, FontWeight.w400, 1.4, color: muted),
      labelLarge: body(15, FontWeight.w600, 1.2),
      labelMedium: body(13, FontWeight.w600, 1.2),
      labelSmall: body(11, FontWeight.w400, 1.2),
    );
  }

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final text = textTheme(p.text, p.muted);
    const stadium = StadiumBorder();
    const buttonSize = Size(AppSizes.minTouch, AppSizes.button);
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpace.xl);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.warning.fill,
      onPrimaryContainer: p.warning.on,
      secondary: p.sageStrong,
      onSecondary: p.onSageStrong,
      secondaryContainer: p.success.fill,
      onSecondaryContainer: p.success.on,
      tertiary: p.accent,
      onTertiary: p.onAccent,
      error: p.danger.on,
      onError: p.danger.fill,
      errorContainer: p.danger.fill,
      onErrorContainer: p.danger.on,
      surface: p.background,
      onSurface: p.text,
      onSurfaceVariant: p.muted,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surface,
      surfaceContainerHighest: p.surface,
      outline: p.divider,
      outlineVariant: p.divider,
      inverseSurface: p.text,
      onInverseSurface: p.background,
      shadow: Organic.n900,
      scrim: p.scrim,
      surfaceTint: Organic.transparent,
    );

    // Hover = one ramp step darker, pressed one more (for the filled
    // button, whose pressed step is in the palette).
    WidgetStateProperty<Color?> overlay(Color base) => WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.pressed)) return base.withValues(alpha: 0.14);
          if (s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)) return base.withValues(alpha: 0.07);
          return null;
        });

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: color, width: width),
        );

    final filledStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return p.primary.withValues(alpha: 0.45);
        if (s.contains(WidgetState.pressed)) return p.primaryPressed;
        return p.primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? p.onPrimary.withValues(alpha: 0.8) : p.onPrimary,
      ),
      overlayColor: overlay(p.onPrimary),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: const WidgetStatePropertyAll(buttonSize),
      padding: const WidgetStatePropertyAll(buttonPadding),
      shape: const WidgetStatePropertyAll(stadium),
      textStyle: WidgetStatePropertyAll(text.titleMedium),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      fontFamily: AppFonts.body,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.divider,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        surfaceTintColor: Organic.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpace.sm,
        titleTextStyle: text.headlineMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? p.text.withValues(alpha: 0.45) : p.text,
          ),
          overlayColor: overlay(p.text),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(color: s.contains(WidgetState.disabled) ? p.divider.withValues(alpha: 0.08) : p.divider),
          ),
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          padding: const WidgetStatePropertyAll(buttonPadding),
          shape: const WidgetStatePropertyAll(stadium),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? p.accentText.withValues(alpha: 0.45) : p.accentText,
          ),
          overlayColor: overlay(p.accent),
          minimumSize: const WidgetStatePropertyAll(Size(AppSizes.minTouch, AppSizes.minTouch)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpace.md)),
          shape: const WidgetStatePropertyAll(stadium),
          textStyle: WidgetStatePropertyAll(text.labelLarge?.copyWith(fontSize: 14)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(AppSizes.minTouch, AppSizes.minTouch),
          shape: const CircleBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        shape: stadium,
        extendedTextStyle: text.labelLarge,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Organic.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        // Labels sit above the field (AppField), never inside it.
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintStyle: text.bodyLarge?.copyWith(color: p.placeholder),
        helperStyle: text.bodySmall,
        helperMaxLines: 3,
        errorStyle: text.bodySmall?.copyWith(color: p.danger.on, fontWeight: FontWeight.w600),
        errorMaxLines: 3,
        prefixIconColor: p.muted,
        suffixIconColor: p.muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: inputBorder(p.divider),
        enabledBorder: inputBorder(p.divider),
        focusedBorder: inputBorder(p.accent, 2),
        errorBorder: inputBorder(p.danger.on),
        focusedErrorBorder: inputBorder(p.danger.on, 2),
        disabledBorder: inputBorder(p.divider.withValues(alpha: 0.08)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.3),
        selectionHandleColor: p.accent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Organic.transparent,
        modalBackgroundColor: p.background,
        modalBarrierColor: p.scrim,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: p.track,
        dragHandleSize: const Size(44, 5),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Organic.transparent,
        barrierColor: p.scrim,
        titleTextStyle: text.headlineMedium,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Organic.transparent,
        headerBackgroundColor: p.surface,
        headerForegroundColor: p.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        dayShape: const WidgetStatePropertyAll(CircleBorder()),
        todayBorder: BorderSide(color: p.accent),
        dayBackgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.text : null),
        dayForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return p.background;
          if (s.contains(WidgetState.disabled)) return p.placeholder;
          return p.text;
        }),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: p.accentText),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: p.accentText),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.background,
        surfaceTintColor: Organic.transparent,
        elevation: 6,
        shadowColor: Organic.n900.withValues(alpha: 0.3),
        textStyle: text.bodyLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.tile)),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.background),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.tile))),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyLarge,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.background),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.tile))),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Organic.transparent,
        selectedColor: p.text,
        disabledColor: Organic.transparent,
        side: BorderSide(color: p.divider),
        showCheckmark: false,
        labelStyle: text.labelMedium?.copyWith(fontSize: 12.5),
        secondaryLabelStyle: text.labelMedium?.copyWith(fontSize: 12.5, color: p.background),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        labelPadding: EdgeInsets.zero,
        shape: stadium,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.text : null),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.background : p.text,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.divider)),
          shape: const WidgetStatePropertyAll(stadium),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.accent,
        textColor: p.text,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        minVerticalPadding: AppSpace.sm,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.tile)),
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surface,
        circularTrackColor: Organic.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.sage : null),
        checkColor: WidgetStatePropertyAll(p.background),
        side: BorderSide(color: p.track, width: 1.5),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(p.accent)),
      // 46 × 28 pill: sage track when on, sand knob.
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Organic.n100),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Organic.sage600 : p.track,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Organic.transparent),
        thumbIcon: const WidgetStatePropertyAll(Icon(null)),
        padding: EdgeInsets.zero,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: p.text, borderRadius: BorderRadius.circular(AppRadius.pill)),
        textStyle: text.labelMedium?.copyWith(color: p.background),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
      ),
    );
  }
}
