import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/themes/bracket_theme_internal.dart';
import 'package:trelis/trelis.dart';

double _relativeLuminance(BracketRgb rgb) {
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

double _contrast(BracketRgb first, BracketRgb second) {
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
        background: BracketPaletteDefaults.lightReferenceBackground,
        roles: BracketPaletteDefaults.lightRgb,
      ),
      (
        name: 'warm ink dark',
        background: BracketPaletteDefaults.darkReferenceBackground,
        roles: BracketPaletteDefaults.darkRgb,
      ),
    ]) {
      for (final role in [
        BracketPaletteRole.foreground,
        BracketPaletteRole.muted,
        BracketPaletteRole.accent,
        BracketPaletteRole.success,
        BracketPaletteRole.warning,
        BracketPaletteRole.error,
        BracketPaletteRole.border,
      ]) {
        final ratio = _contrast(reference.roles[role]!, reference.background);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$role against ${reference.name}: $ratio',
        );
      }
      final selectionRatio = _contrast(
        reference.roles[BracketPaletteRole.selectionForeground]!,
        reference.roles[BracketPaletteRole.selectionBackground]!,
      );
      expect(
        selectionRatio,
        greaterThanOrEqualTo(4.5),
        reason: 'selection pair against ${reference.name}',
      );
    }
  });

  test('authored defaults keep the terminal surface and a rust accent', () {
    for (final palette in [
      BracketPaletteDefaults.light,
      BracketPaletteDefaults.dark,
    ]) {
      expect(palette.background, const TerminalColor.terminalDefault());
      expect(isTerminalDefault(palette.background), isTrue);
    }
    expect(BracketPaletteDefaults.light.accent, TerminalColor.rgb(166, 69, 38));
    expect(BracketPaletteDefaults.dark.accent, TerminalColor.rgb(232, 135, 90));
    expect(ColorThemes.terminalDefault.foreground, isA<TerminalColor>());
  });
}
