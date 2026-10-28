import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoezidesk_staff/core/theme/app_tokens.dart';

/// WCAG 2.x relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color fg, Color bg) {
  final opaqueFg = Color.alphaBlend(fg, bg);
  final a = _luminance(opaqueFg);
  final b = _luminance(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  test('contrast helper matches known WCAG values', () {
    expect(contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01));
    expect(contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)),
        closeTo(4.48, 0.01));
  });

  for (final (name, p) in [('dark', AppPalette.dark), ('light', AppPalette.light)]) {
    group('$name theme text pairs meet 4.5:1', () {
      final backgrounds = {
        'background': p.background,
        'surface': p.surface,
        'surfaceHigh': p.surfaceHigh,
      };
      final foregrounds = {
        'text': p.text,
        'textMuted': p.textMuted,
        'accentText': p.accentText,
        'success': p.success,
        'warning': p.warning,
        'danger': p.danger,
      };
      for (final bg in backgrounds.entries) {
        for (final fg in foregrounds.entries) {
          test('${fg.key} on ${bg.key}', () {
            expect(contrast(fg.value, bg.value), greaterThanOrEqualTo(4.5));
          });
        }
      }

      test('accent tint (nav indicator, selected chip)', () {
        final tint = Color.alphaBlend(p.accentTint, p.surface);
        // Text placed on the tint must pass 4.5:1.
        expect(contrast(p.text, tint), greaterThanOrEqualTo(4.5));
        // Only the selected nav icon uses accentText on the tint. Icons are
        // non-text content, so WCAG 1.4.11 requires 3:1. Never put
        // accentText *text* on the tint.
        expect(contrast(p.accentText, tint), greaterThanOrEqualTo(3));
      });

      for (final stop in p.cardGradient) {
        test('membership card text on gradient stop $stop', () {
          expect(contrast(p.onCardGradient, stop), greaterThanOrEqualTo(4.5));
        });
      }
    });
  }

  test('primary button: dark text on orange', () {
    expect(contrast(AppColors.onOrange, AppColors.orange),
        greaterThanOrEqualTo(4.5));
  });

  test('white on orange or green fails, which is why it is never used', () {
    expect(contrast(AppColors.white, AppColors.orange), lessThan(4.5));
    expect(contrast(AppColors.white, AppColors.darkSuccess), lessThan(4.5));
  });
}
