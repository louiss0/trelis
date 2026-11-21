import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/line_presentation.dart';
import 'package:trelis/trelis.dart';

/// Independent authored values for the Line adaptive defaults.
///
/// These literals are the review fixture: the implementation must match them,
/// and the contrast maths below uses these numbers rather than asking the
/// palette to describe its own suitability.
const Map<String, List<int>> _light = {
  'foreground': [52, 40, 36],
  'muted': [92, 78, 72],
  'accent': [112, 34, 88],
  'selectionForeground': [255, 250, 246],
  'success': [28, 96, 60],
  'warning': [120, 68, 10],
  'error': [146, 32, 44],
  'border': [101, 82, 76],
};

const Map<String, List<int>> _dark = {
  'foreground': [242, 234, 238],
  'muted': [182, 168, 177],
  'accent': [214, 139, 196],
  'selectionForeground': [29, 25, 31],
  'success': [148, 212, 168],
  'warning': [238, 186, 116],
  'error': [252, 142, 152],
  'border': [151, 132, 146],
};

const Map<BackgroundVariant, List<int>> _referenceBackground = {
  BackgroundVariant.light: [246, 241, 232],
  BackgroundVariant.dark: [29, 25, 31],
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
  group('Line adaptive defaults', () {
    test('light and dark defaults are distinct warm-ink plum palettes', () {
      expect(
        LinePresentation.lightDefault,
        isNot(LinePresentation.darkDefault),
      );
      expect(
        LinePresentation.referenceBackground(BackgroundVariant.light),
        TerminalColor.rgb(246, 241, 232),
      );
      expect(
        LinePresentation.referenceBackground(BackgroundVariant.dark),
        TerminalColor.rgb(29, 25, 31),
      );
      for (final entry in _light.entries) {
        expect(
          _actual(entry.key, LinePresentation.lightDefault),
          _expected(entry.key, BackgroundVariant.light),
          reason: 'light ${entry.key}',
        );
      }
      for (final entry in _dark.entries) {
        expect(
          _actual(entry.key, LinePresentation.darkDefault),
          _expected(entry.key, BackgroundVariant.dark),
          reason: 'dark ${entry.key}',
        );
      }
      expect(
        LinePresentation.lightDefault.background,
        TerminalColor.terminalDefault(),
      );
      expect(
        LinePresentation.darkDefault.background,
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
          _contrast(authored['selectionForeground']!, authored['accent']!),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    test('unknown background falls back to dark; explicit light wins', () {
      final unknown = resolveColors(
        facts: const ColorDetectionFacts(),
        lightDefault: LinePresentation.lightDefault,
        darkDefault: LinePresentation.darkDefault,
      );
      final explicit = resolveColors(
        facts: const ColorDetectionFacts(
          passiveBackground: BackgroundObservation.dark,
        ),
        lightDefault: LinePresentation.lightDefault,
        darkDefault: LinePresentation.darkDefault,
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
        ),
      );

      expect(unknown.background, BackgroundVariant.dark);
      expect(unknown.palette, LinePresentation.darkDefault);
      expect(explicit.background, BackgroundVariant.light);
      expect(explicit.palette, LinePresentation.lightDefault);
    });
  });

  group('Line text input through the internal seam', () {
    for (final variant in BackgroundVariant.values) {
      final isLight = variant == BackgroundVariant.light;
      final foreground = isLight ? '52;40;36' : '242;234;238';
      final muted = isLight ? '92;78;72' : '182;168;177';
      final border = isLight ? '101;82;76' : '151;132;146';

      test('$variant palette styles a real ruled text input', () async {
        final output = StringBuffer();
        final tracer = LinePresentationTracer(
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

        final result = await tracer.textInput('Project name');
        final text = output.toString();

        expect((result as Accepted<String>).value, 'Ada');
        expect(
          text,
          contains('\x1b[38;2;$foreground;49mProject name (Optional).'),
        );
        expect(text, contains('\x1b[38;2;$border;49m────'));
        expect(text, contains('\x1b[38;2;$muted;49m  '));
        expect(text, contains('Enter submits. Ctrl+T opens help.'));
        expect(text.indexOf('Project name'), lessThan(text.indexOf('──')));
        expect(
          text.indexOf('──'),
          lessThan(text.indexOf('Ctrl+T opens help.')),
        );
        for (final enclosure in ['╭', '╮', '╰', '╯']) {
          expect(text, isNot(contains(enclosure)));
        }
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
        expect(text, isNot(contains('\x1b[2J')));
      });
    }
  });
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  glyphs: GlyphSet.unicode,
  geometry: OutputGeometry.fixed(columns: 60, rows: 12),
);
