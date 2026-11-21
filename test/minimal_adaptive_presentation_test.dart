import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/themes/minimal_presentation.dart';
import 'package:trelis/trelis.dart';

/// Independent authored values for the Minimal adaptive defaults.
///
/// These literals are the review fixture: the implementation must match them,
/// and the contrast maths below uses these numbers rather than asking the
/// palette to describe its own suitability.
const Map<String, List<int>> _light = {
  'foreground': [54, 43, 34],
  'muted': [96, 80, 68],
  'accent': [126, 72, 20],
  'selectionForeground': [255, 251, 244],
  'selectionBackground': [126, 72, 20],
  'success': [26, 92, 57],
  'warning': [128, 74, 8],
  'error': [150, 36, 40],
  'border': [112, 92, 74],
};

const Map<String, List<int>> _dark = {
  'foreground': [244, 236, 224],
  'muted': [190, 174, 156],
  'accent': [214, 158, 97],
  'selectionForeground': [30, 26, 22],
  'selectionBackground': [214, 158, 97],
  'success': [146, 210, 164],
  'warning': [238, 188, 112],
  'error': [250, 146, 138],
  'border': [158, 138, 118],
};

const Map<BackgroundVariant, List<int>> _referenceBackground = {
  BackgroundVariant.light: [245, 238, 225],
  BackgroundVariant.dark: [30, 26, 22],
};

TerminalColor _expected(String role, BackgroundVariant variant) {
  final rgb = variant == BackgroundVariant.light ? _light[role]! : _dark[role]!;
  return TerminalColor.rgb(rgb[0], rgb[1], rgb[2]);
}

TerminalColor _actual(String role, ColorTheme palette) => switch (role) {
  'foreground' => palette.foreground,
  'muted' => palette.muted,
  'accent' => palette.accent,
  'selectionForeground' => palette.selectionForeground,
  'selectionBackground' => palette.selectionBackground,
  'success' => palette.success,
  'warning' => palette.warning,
  'error' => palette.error,
  'border' => palette.border,
  _ => throw ArgumentError(role),
};

double _luminance(List<int> rgb) {
  double channel(int value) {
    final scaled = value / 255;
    return scaled <= 0.03928
        ? scaled / 12.92
        : math.pow((scaled + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(rgb[0]) +
      0.7152 * channel(rgb[1]) +
      0.0722 * channel(rgb[2]);
}

double _contrast(List<int> foreground, List<int> background) {
  final first = _luminance(foreground);
  final second = _luminance(background);
  final high = first > second ? first : second;
  final low = first < second ? first : second;
  return (high + 0.05) / (low + 0.05);
}

void main() {
  group('Minimal adaptive defaults', () {
    test('light and dark defaults are distinct warm-ink sepia palettes', () {
      expect(
        MinimalPresentation.lightDefault,
        isNot(MinimalPresentation.darkDefault),
      );
      expect(
        MinimalPresentation.referenceBackground(BackgroundVariant.light),
        TerminalColor.rgb(245, 238, 225),
      );
      expect(
        MinimalPresentation.referenceBackground(BackgroundVariant.dark),
        TerminalColor.rgb(30, 26, 22),
      );
      for (final entry in _light.entries) {
        expect(
          _actual(entry.key, MinimalPresentation.lightDefault),
          _expected(entry.key, BackgroundVariant.light),
          reason: 'light ${entry.key}',
        );
      }
      for (final entry in _dark.entries) {
        expect(
          _actual(entry.key, MinimalPresentation.darkDefault),
          _expected(entry.key, BackgroundVariant.dark),
          reason: 'dark ${entry.key}',
        );
      }
      expect(
        MinimalPresentation.lightDefault.background,
        TerminalColor.terminalDefault(),
      );
      expect(
        MinimalPresentation.darkDefault.background,
        TerminalColor.terminalDefault(),
      );
    });

    for (final variant in BackgroundVariant.values) {
      final reference = _referenceBackground[variant]!;
      final authored = variant == BackgroundVariant.light ? _light : _dark;

      test('$variant normal-text roles meet the 4.5:1 reference target', () {
        for (final role in [
          'foreground',
          'muted',
          'accent',
          'success',
          'warning',
          'error',
          'border',
        ]) {
          expect(
            _contrast(authored[role]!, reference),
            greaterThanOrEqualTo(4.5),
            reason: '$variant $role against the documented reference surface',
          );
        }
      });

      test('$variant selection foreground stays readable on its highlight', () {
        expect(
          _contrast(
            authored['selectionForeground']!,
            authored['selectionBackground']!,
          ),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    test('unknown background falls back to dark; explicit light wins', () {
      final unknown = resolveColors(
        facts: const ColorDetectionFacts(),
        lightDefault: MinimalPresentation.lightDefault,
        darkDefault: MinimalPresentation.darkDefault,
      );
      final explicit = resolveColors(
        facts: const ColorDetectionFacts(
          passiveBackground: BackgroundObservation.dark,
        ),
        lightDefault: MinimalPresentation.lightDefault,
        darkDefault: MinimalPresentation.darkDefault,
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
        ),
      );

      expect(unknown.background, BackgroundVariant.dark);
      expect(unknown.palette, MinimalPresentation.darkDefault);
      expect(explicit.background, BackgroundVariant.light);
      expect(explicit.palette, MinimalPresentation.lightDefault);
    });
  });
}
