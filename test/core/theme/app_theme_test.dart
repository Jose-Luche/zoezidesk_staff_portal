import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoezidesk_staff/core/theme/app_theme.dart';
import 'package:zoezidesk_staff/core/theme/app_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (name, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
    group('$name theme', () {
      test('primary is orange with dark text', () {
        expect(theme.colorScheme.primary, AppColors.orange);
        expect(theme.colorScheme.onPrimary, AppColors.onOrange);
      });

      test('carries the semantic palette', () {
        expect(theme.extension<AppPalette>(), isNotNull);
      });

      test('body text is at least 16sp', () {
        final t = theme.textTheme;
        for (final style in [t.bodyLarge, t.bodyMedium, t.bodySmall]) {
          expect(style!.fontSize, greaterThanOrEqualTo(16));
        }
      });

      test('headings use Barlow Condensed and body uses Barlow', () {
        expect(theme.textTheme.headlineMedium!.fontFamily,
            equals(AppFonts.heading));
        expect(theme.textTheme.bodyMedium!.fontFamily, AppFonts.body);
      });

      test('filled buttons are at least 48dp with 8dp radius', () {
        final style = theme.filledButtonTheme.style!;
        expect(style.minimumSize!.resolve({})!.height,
            greaterThanOrEqualTo(AppSizes.minTouch));
        final shape = style.shape!.resolve({})! as RoundedRectangleBorder;
        expect(shape.borderRadius,
            BorderRadius.circular(AppRadius.control));
      });

      test('cards use 12dp radius', () {
        final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(AppRadius.card));
      });

      test('inputs keep labels visible and focus in primary', () {
        final input = theme.inputDecorationTheme;
        expect(input.floatingLabelBehavior, FloatingLabelBehavior.always);
        final focused = input.focusedBorder! as OutlineInputBorder;
        expect(focused.borderSide.color, AppColors.orange);
        expect(focused.borderRadius, BorderRadius.circular(AppRadius.control));
      });

      test('bottom sheets use 16dp radius and a plain scrim', () {
        final sheet = theme.bottomSheetTheme;
        expect(sheet.modalBarrierColor, AppColors.scrim);
        expect((sheet.shape! as RoundedRectangleBorder).borderRadius,
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)));
      });
    });
  }

  test('dark cards use a border instead of a shadow', () {
    final shape = AppTheme.dark.cardTheme.shape! as RoundedRectangleBorder;
    expect(AppTheme.dark.cardTheme.elevation, 0);
    expect(shape.side.color, AppColors.darkBorder);
  });

  test('light cards use a light shadow and no border', () {
    final shape = AppTheme.light.cardTheme.shape! as RoundedRectangleBorder;
    expect(AppTheme.light.cardTheme.elevation, greaterThan(0));
    expect(shape.side, BorderSide.none);
  });
}
