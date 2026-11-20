import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/themes/chevron_theme_internal.dart';

double _relativeLuminance(ChevronRgb rgb) {
  double channel(int value) {
    final scaled = value / 255;
    return scaled <= 0.04045
        ? scaled / 12.92
        : math.pow((scaled + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(rgb.red) +
      0.7152 * channel(rgb.green) +
      0.0722 * channel(rgb.blue);
}

double _contrast(ChevronRgb first, ChevronRgb second) {
  final a = _relativeLuminance(first);
  final b = _relativeLuminance(second);
  final high = a > b ? a : b;
  final low = a < b ? a : b;
  return (high + 0.05) / (low + 0.05);
}

void main() {
  test('authored normal-text pairs meet the reference contrast target', () {
    for (final reference in [
      (
        name: 'Atelier Sepia light',
        background: ChevronPaletteDefaults.lightReferenceBackground,
        roles: ChevronPaletteDefaults.lightRgb,
      ),
      (
        name: 'warm ink dark',
        background: ChevronPaletteDefaults.darkReferenceBackground,
        roles: ChevronPaletteDefaults.darkRgb,
      ),
    ]) {
      for (final role in [
        ChevronPaletteRole.foreground,
        ChevronPaletteRole.muted,
        ChevronPaletteRole.accent,
        ChevronPaletteRole.success,
        ChevronPaletteRole.warning,
        ChevronPaletteRole.error,
        ChevronPaletteRole.border,
      ]) {
        final ratio = _contrast(reference.roles[role]!, reference.background);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$role against ${reference.name}: $ratio',
        );
      }
      final selectionRatio = _contrast(
        reference.roles[ChevronPaletteRole.selectionForeground]!,
        reference.roles[ChevronPaletteRole.selectionBackground]!,
      );
      expect(
        selectionRatio,
        greaterThanOrEqualTo(4.5),
        reason: 'selection pair against ${reference.name}',
      );
    }
  });
}
