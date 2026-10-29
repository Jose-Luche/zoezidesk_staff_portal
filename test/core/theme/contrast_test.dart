import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoezidesk_staff/core/theme/app_tokens.dart';

/// WCAG 2.x relative luminance.
double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
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
    expect(contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)), closeTo(4.48, 0.01));
  });

  for (final (name, p) in [('light', AppPalette.light), ('dark', AppPalette.dark)]) {
    group('$name theme text pairs meet 4.5:1', () {
      final grounds = {'background': p.background, 'surface': p.surface};
      final texts = {'text': p.text, 'muted': p.muted, 'accentText': p.accentText};
      for (final bg in grounds.entries) {
        for (final fg in texts.entries) {
          test('${fg.key} on ${bg.key}', () => expect(contrast(fg.value, bg.value), greaterThanOrEqualTo(4.5)));
        }
      }

      final pairs = <String, (Color, Color)>{
        'filled button label': (p.onPrimary, p.primary),
        'filled button label, pressed': (p.onPrimary, p.primaryPressed),
        'selected nav label on accent': (p.onAccent, p.accent),
        'nav labels on the pill': (p.background, p.text),
        'toast text': (p.background, p.text),
        'toast action': (p.inverseAccent, p.text),
        'selected chip and segment': (p.background, p.text),
        'selected note type on sage': (p.onSageStrong, p.sageStrong),
        'success banner': (p.success.on, p.success.fill),
        'success tag': (p.successTag.on, p.successTag.fill),
        'warning card': (p.warning.on, p.warning.fill),
        'danger card': (p.danger.on, p.danger.fill),
        'neutral tag': (p.neutral.on, p.neutral.fill),
        'role switcher label': (p.neutral.on, p.neutral.fill),
        'avatar, sage': (p.avatarSage.on, p.avatarSage.fill),
        'avatar, terracotta': (p.avatarTerra.on, p.avatarTerra.fill),
        'avatar, sand': (p.avatarSand.on, p.avatarSand.fill),
        'follow-up status on the ground': (p.warning.on, p.background),
        'selected plan row': (p.text, p.warning.fill),
      };
      for (final MapEntry(:key, value: (fg, bg)) in pairs.entries) {
        test(key, () => expect(contrast(fg, bg), greaterThanOrEqualTo(4.5)));
      }
    });
  }

  group('large text and icons only (3:1)', () {
    test('cream Scan label on terracotta is 3:1, so it stays at headline size', () {
      final c = contrast(AppPalette.light.background, AppPalette.light.accent);
      expect(c, greaterThanOrEqualTo(3));
      expect(c, lessThan(4.5));
    });

    test('accent icons on the ground', () {
      for (final p in [AppPalette.light, AppPalette.dark]) {
        expect(contrast(p.accent, p.background), greaterThanOrEqualTo(3));
      }
    });
  });

  test('placeholder grey is never good enough for meaningful text', () {
    expect(contrast(AppPalette.light.placeholder, AppPalette.light.background), lessThan(4.5));
  });
}
