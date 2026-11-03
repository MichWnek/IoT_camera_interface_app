import 'package:camera_trap_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast ratio between two opaque colours (1.0 to 21.0).
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

const textMin = 4.5; // WCAG AA for normal text
const iconMin = 3.0; // WCAG AA for non-text elements (icons, borders)

void main() {
  for (final (themeName, theme) in [
    ('day', AppTheme.day),
    ('night', AppTheme.night),
  ]) {
    group('$themeName theme', () {
      final c = theme.colorScheme;

      // Each pair is (what the UI paints, foreground, background, minimum).
      // Backgrounds are the Material 3 defaults for those widgets.
      final pairs = [
        ('body text on scaffold', c.onSurface, c.surface, textMin),
        ('text on card', c.onSurface, c.surfaceContainerLow, textMin),
        ('low battery text on card', c.error, c.surfaceContainerLow, textMin),
        ('online icon on card', c.primary, c.surfaceContainerLow, iconMin),
        ('offline icon on card', c.outline, c.surfaceContainerLow, iconMin),
        ('content on primary button', c.onPrimary, c.primary, textMin),
        ('FAB icon', c.onPrimaryContainer, c.primaryContainer, iconMin),
      ];

      for (final (label, fg, bg, min) in pairs) {
        test('$label is readable', () {
          // Flatten any transparency the way the screen would draw it.
          final solidBg = Color.alphaBlend(bg, c.surface);
          final solidFg = Color.alphaBlend(fg, solidBg);
          final ratio = contrast(solidFg, solidBg);

          expect(
            ratio,
            greaterThanOrEqualTo(min),
            reason: 'ratio was ${ratio.toStringAsFixed(2)}, needs $min',
          );
        });
      }
    });
  }
}
