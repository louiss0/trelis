import 'dart:async';
import 'dart:math' as math;

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/branch_presentation.dart';
import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

/// Independent authored values for the Branch adaptive defaults.
///
/// These literals are the review fixture: the implementation must match them,
/// and the contrast maths below uses these numbers rather than asking the
/// palette to describe its own suitability.
const Map<String, List<int>> _light = {
  'foreground': [55, 45, 40],
  'muted': [98, 83, 77],
  'accent': [125, 43, 96],
  'selectionForeground': [255, 251, 246],
  'success': [34, 103, 65],
  'warning': [126, 74, 14],
  'error': [157, 39, 50],
  'border': [112, 92, 84],
};

const Map<String, List<int>> _dark = {
  'foreground': [238, 232, 235],
  'muted': [177, 165, 173],
  'accent': [216, 150, 205],
  'selectionForeground': [27, 24, 29],
  'success': [150, 214, 172],
  'warning': [240, 190, 120],
  'error': [255, 145, 155],
  'border': [145, 126, 140],
};

const Map<BackgroundVariant, List<int>> _referenceBackground = {
  BackgroundVariant.light: [246, 241, 232],
  BackgroundVariant.dark: [27, 24, 29],
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
  group('Branch adaptive defaults', () {
    test('light and dark defaults are distinct warm-ink plum palettes', () {
      expect(BranchPresentation.lightDefault,
          isNot(BranchPresentation.darkDefault));
      expect(
        BranchPresentation.referenceBackground(BackgroundVariant.light),
        TerminalColor.rgb(246, 241, 232),
      );
      expect(
        BranchPresentation.referenceBackground(BackgroundVariant.dark),
        TerminalColor.rgb(27, 24, 29),
      );
      for (final entry in _light.entries) {
        expect(
          _actual(entry.key, BranchPresentation.lightDefault),
          _expected(entry.key, BackgroundVariant.light),
          reason: 'light ${entry.key}',
        );
      }
      for (final entry in _dark.entries) {
        expect(
          _actual(entry.key, BranchPresentation.darkDefault),
          _expected(entry.key, BackgroundVariant.dark),
          reason: 'dark ${entry.key}',
        );
      }
    });

    for (final variant in BackgroundVariant.values) {
      final reference = _referenceBackground[variant]!;
      final authored = variant == BackgroundVariant.light ? _light : _dark;
      final palette = variant == BackgroundVariant.light
          ? BranchPresentation.lightDefault
          : BranchPresentation.darkDefault;

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
          _contrast(_light['selectionForeground']!, _light['accent']!),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(_dark['selectionForeground']!, _dark['accent']!),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    test('unknown background falls back to dark; explicit light wins', () {
      final unknown = resolveColors(
        facts: const ColorDetectionFacts(),
        lightDefault: BranchPresentation.lightDefault,
        darkDefault: BranchPresentation.darkDefault,
      );
      final explicit = resolveColors(
        facts: const ColorDetectionFacts(
          passiveBackground: BackgroundObservation.dark,
        ),
        lightDefault: BranchPresentation.lightDefault,
        darkDefault: BranchPresentation.darkDefault,
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
        ),
      );

      expect(unknown.background, BackgroundVariant.dark);
      expect(unknown.palette, BranchPresentation.darkDefault);
      expect(explicit.background, BackgroundVariant.light);
      expect(explicit.palette, BranchPresentation.lightDefault);
    });
  });

  group('Branch text input through the internal seam', () {
    for (final variant in BackgroundVariant.values) {
      final isLight = variant == BackgroundVariant.light;
      final foreground = isLight ? '55;45;40' : '238;232;235';
      final muted = isLight ? '98;83;77' : '177;165;173';

      test('$variant palette styles a real branching text input', () async {
        final output = StringBuffer();
        final tracer = BranchPresentationTracer(
          io: TerminalEnvironment.scripted(
            input: Stream.value('Ada\r'),
            output: output,
            profile: _richProfile,
          ),
          colors: ColorPreferences(
            background: isLight
                ? BackgroundPreference.light
                : BackgroundPreference.dark,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
        );

        final result = await tracer.textInput('Choose features');
        final text = output.toString();

        expect((result as Accepted<String>).value, 'Ada');
        expect(text, contains('\x1b[38;2;$foreground;49m├ Choose features'));
        expect(text, contains('\x1b[38;2;$muted;49m│ '));
        expect(text, contains('\x1b[38;2;$muted;49m└ '));
        expect(text, contains('Ctrl+T opens help.'));
        expect(text, contains('│ '));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
        expect(text, isNot(contains('\x1b[2J')));
      });
    }
  });
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 70, rows: 20),
  glyphs: GlyphSet.unicode,
);
