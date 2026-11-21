import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/themes/plain_sepia_palettes.dart';
import 'package:trelis/trelis.dart';

/// Reads a request back through the public SGR rendering, so the test does not
/// depend on the private colour subclasses.
List<int> _rgb(TerminalColor color) => terminalSgr(
  color,
  background: false,
  depth: ColorDepth.rgb,
).split(';').skip(2).map(int.parse).toList();

double _contrast(List<int> foreground, List<int> background) {
  double luminance(List<int> rgb) {
    final channels = rgb.map((value) {
      final channel = value / 255;
      return channel <= 0.03928
          ? channel / 12.92
          : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
    });
    return 0.2126 * channels.elementAt(0) +
        0.7152 * channels.elementAt(1) +
        0.0722 * channels.elementAt(2);
  }

  final lighter = luminance(foreground);
  final darker = luminance(background);
  return lighter > darker
      ? (lighter + 0.05) / (darker + 0.05)
      : (darker + 0.05) / (lighter + 0.05);
}

void main() {
  group('Plain adaptive sepia defaults', () {
    test('light and dark defaults are distinct warm-ink palettes', () {
      final light = PlainSepiaPalettes.light;
      final dark = PlainSepiaPalettes.dark;

      expect(light.foreground, isNot(dark.foreground));
      expect(light.accent, isNot(dark.accent));
      expect(isTerminalDefault(light.background), isTrue);
      expect(isTerminalDefault(dark.background), isTrue);

      final lightAccent = _rgb(light.accent);
      final darkAccent = _rgb(dark.accent);
      expect(lightAccent[0], greaterThan(lightAccent[1]));
      expect(lightAccent[1], greaterThan(lightAccent[2]));
      expect(darkAccent[0], greaterThan(darkAccent[1]));
      expect(darkAccent[1], greaterThan(darkAccent[2]));
    });

    test(
      'each authored normal-text pair meets the reference contrast target',
      () {
        final variants = [
          (PlainSepiaPalettes.light, plainLightReferenceRgb),
          (PlainSepiaPalettes.dark, plainDarkReferenceRgb),
        ];
        for (final (palette, reference) in variants) {
          final roles = <String, TerminalColor>{
            'foreground': palette.foreground,
            'muted': palette.muted,
            'accent': palette.accent,
            'success': palette.success,
            'warning': palette.warning,
            'error': palette.error,
            'border': palette.border,
          };
          for (final MapEntry(:key, :value) in roles.entries) {
            expect(
              _contrast(_rgb(value), [
                reference.$1,
                reference.$2,
                reference.$3,
              ]),
              greaterThanOrEqualTo(4.5),
              reason: '$key against documented reference $reference',
            );
          }
          expect(
            _contrast(
              _rgb(palette.selectionForeground),
              _rgb(palette.selectionBackground),
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'localized selection highlight $reference',
          );
        }
      },
    );
  });
}
