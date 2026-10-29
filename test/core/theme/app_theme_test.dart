import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoezidesk_staff/core/theme/app_theme.dart';
import 'package:zoezidesk_staff/core/theme/app_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('light theme sits on the cream ground with terracotta buttons', () {
    final t = AppTheme.light;
    expect(t.scaffoldBackgroundColor, Organic.bg);
    expect(t.colorScheme.primary, Organic.accent700);
    expect(t.colorScheme.onPrimary, Organic.bg);
    expect(t.cardTheme.color, Organic.surface);
  });

  test('dark theme uses the neutral ramp and the lighter accent', () {
    final t = AppTheme.dark;
    expect(t.scaffoldBackgroundColor, Organic.n900);
    expect(t.colorScheme.primary, Organic.accent400);
    expect(t.extension<AppPalette>()!.surface, Organic.n800);
  });

  for (final (name, theme) in [('light', AppTheme.light), ('dark', AppTheme.dark)]) {
    group('$name theme', () {
      test('carries the semantic palette', () {
        expect(theme.extension<AppPalette>(), isNotNull);
      });

      test('display and headings use Caprasimo, body uses Figtree', () {
        final t = theme.textTheme;
        for (final style in [t.displayLarge, t.headlineLarge, t.headlineMedium, t.titleLarge, t.titleMedium]) {
          expect(style!.fontFamily, AppFonts.display);
        }
        for (final style in [t.titleSmall, t.bodyLarge, t.bodyMedium, t.bodySmall, t.labelMedium]) {
          expect(style!.fontFamily, AppFonts.body);
        }
        expect(t.displayLarge!.fontSize, 40);
        expect(t.headlineLarge!.fontSize, 32);
      });

      test('buttons are pills, at least 44dp tall', () {
        for (final style in [theme.filledButtonTheme.style!, theme.outlinedButtonTheme.style!]) {
          expect(style.shape!.resolve({}), isA<StadiumBorder>());
          expect(style.minimumSize!.resolve({})!.height, greaterThanOrEqualTo(AppSizes.minTouch));
        }
      });

      test('filled buttons fade to 45% when disabled', () {
        final fill = theme.filledButtonTheme.style!.backgroundColor!;
        final p = theme.extension<AppPalette>()!;
        expect(fill.resolve({WidgetState.disabled})!.a, closeTo(p.primary.a * 0.45, 0.01));
      });

      test('cards are flat with radius 26', () {
        expect(theme.cardTheme.elevation, 0);
        final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(AppRadius.card));
      });

      test('inputs are filled pills that focus in accent', () {
        final input = theme.inputDecorationTheme;
        final p = theme.extension<AppPalette>()!;
        expect(input.filled, isTrue);
        expect(input.fillColor, p.surface);
        final focused = input.focusedBorder! as OutlineInputBorder;
        expect(focused.borderSide.color, p.accent);
        expect(focused.borderSide.width, 2);
        expect(focused.borderRadius, BorderRadius.circular(AppRadius.pill));
      });

      test('sheets are cream with a 34 top radius and a half-dark backdrop', () {
        final sheet = theme.bottomSheetTheme;
        final p = theme.extension<AppPalette>()!;
        expect(sheet.backgroundColor, p.background);
        expect(sheet.modalBarrierColor, p.scrim);
        expect((sheet.shape! as RoundedRectangleBorder).borderRadius,
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)));
      });
    });
  }
}
