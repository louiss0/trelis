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

  group('Line choices through the internal seam', () {
    test(
      'a real light choice keeps the rule beneath the title and markers',
      () async {
        final text = await _renderChoice(
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
        );

        expect(text, contains('\x1b[38;2;101;82;76;49m────'));
        expect(text, contains('\x1b[38;2;52;40;36;49mPick tools'));
        expect(text, contains('\x1b[38;2;112;34;88;49m  1. Starter'));
        expect(text, contains('[checked] [default]'));
        expect(text, contains('Unavailable: needs owner role.'));
        expect(text.indexOf('Pick tools'), lessThan(text.indexOf('──')));
        expect(text.indexOf('──'), lessThan(text.indexOf('Starter')));
        expect(text.indexOf('──'), lessThan(text.indexOf('Ctrl+T help')));
        for (final enclosure in ['╭', '╮', '╰', '╯']) {
          expect(text, isNot(contains(enclosure)));
        }
        expect(text, isNot(contains('\x1b[48;2;')));
      },
    );

    test(
      'a real dark choice renders plum focus, checked, default and reasons',
      () async {
        final text = await _renderChoice(
          colors: const ColorPreferences(background: BackgroundPreference.dark),
        );

        expect(text, contains('\x1b[38;2;151;132;146;49m────'));
        expect(text, contains('\x1b[38;2;242;234;238;49mPick tools'));
        expect(text, contains('\x1b[38;2;214;139;196;49m  1. Starter'));
        expect(text, contains('[checked] [default]'));
        expect(text, contains('[unavailable: needs owner role]'));
        expect(
          text,
          contains('\x1b[38;2;238;186;116;49m  Unavailable: needs owner role.'),
        );
        expect(text, contains('Ctrl+T help'));
        expect(text.indexOf('Ctrl+T help'), greaterThan(text.indexOf('──')));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
      },
    );

    for (final variant in BackgroundVariant.values) {
      final isLight = variant == BackgroundVariant.light;
      final preference = isLight
          ? BackgroundPreference.light
          : BackgroundPreference.dark;
      final defaultAccent = isLight ? '112;34;88' : '214;139;196';
      final defaultForeground = isLight ? '52;40;36' : '242;234;238';

      test(
        '$variant app whole-palette replacement reaches the output',
        () async {
          final replacement = ColorThemes.terminalDefault.copyWith(
            foreground: TerminalColor.rgb(11, 22, 33),
            accent: TerminalColor.rgb(44, 55, 66),
          );
          final text = await _renderChoice(
            colors: ColorPreferences(
              background: preference,
              colors: ComponentColors.palette(replacement),
            ),
          );

          expect(text, contains('\x1b[38;2;11;22;33;49mPick tools'));
          expect(text, contains('\x1b[38;2;44;55;66;49m  1. Starter'));
          expect(text, isNot(contains('38;2;$defaultForeground;')));
          expect(text, isNot(contains('38;2;$defaultAccent;')));
        },
      );

      test('$variant app variant roles win over shared app roles', () async {
        final text = await _renderChoice(
          colors: ColorPreferences(
            background: preference,
            colors: ComponentColors(
              roles: ColorRoleOverrides(accent: TerminalColor.rgb(70, 71, 72)),
              lightRoles: ColorRoleOverrides(
                accent: TerminalColor.rgb(80, 81, 82),
              ),
              darkRoles: ColorRoleOverrides(
                accent: TerminalColor.rgb(90, 91, 92),
              ),
            ),
          ),
        );

        final expected = isLight ? '80;81;82' : '90;91;92';
        expect(text, contains('\x1b[38;2;$expected;49m  1. Starter'));
        expect(text, isNot(contains('38;2;70;71;72;')));
        expect(text, isNot(contains('38;2;$defaultAccent;')));
      });

      test('$variant component palette discards the app layers', () async {
        final app = ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(11, 22, 33),
          accent: TerminalColor.rgb(44, 55, 66),
        );
        final component = ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(99, 88, 77),
          accent: TerminalColor.rgb(66, 55, 44),
        );
        final text = await _renderChoice(
          colors: ColorPreferences(
            background: preference,
            colors: ComponentColors(
              palette: app,
              roles: ColorRoleOverrides(accent: TerminalColor.rgb(12, 13, 14)),
            ),
          ),
          component: ComponentColors.palette(component),
        );

        expect(text, contains('\x1b[38;2;99;88;77;49mPick tools'));
        expect(text, contains('\x1b[38;2;66;55;44;49m  1. Starter'));
        for (final obsolete in ['11;22;33', '44;55;66', '12;13;14']) {
          expect(text, isNot(contains('38;2;$obsolete;')));
        }
      });

      test('$variant component variant roles override shared roles', () async {
        final text = await _renderChoice(
          colors: ColorPreferences(background: preference),
          component: ComponentColors(
            roles: ColorRoleOverrides(accent: TerminalColor.rgb(3, 3, 3)),
            lightRoles: ColorRoleOverrides(accent: TerminalColor.rgb(4, 4, 4)),
            darkRoles: ColorRoleOverrides(accent: TerminalColor.rgb(5, 5, 5)),
          ),
        );

        final expected = isLight ? '4;4;4' : '5;5;5';
        expect(text, contains('\x1b[38;2;$expected;49m  1. Starter'));
        expect(text, isNot(contains('38;2;3;3;3;')));
        expect(text, isNot(contains('38;2;$defaultAccent;')));
      });
    }

    test(
      'explicit terminalDefault at app and component scope emits no colour',
      () async {
        final appPlain = await _renderChoice(
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
            colors: ComponentColors.palette(ColorThemes.terminalDefault),
          ),
        );
        final componentPlain = await _renderChoice(
          colors: ColorPreferences(
            background: BackgroundPreference.light,
            colors: ComponentColors.palette(ColorThemes.signal),
          ),
          component: const ComponentColors.palette(ColorThemes.terminalDefault),
        );

        for (final text in [appPlain, componentPlain]) {
          expect(text, contains('──'));
          expect(text, contains('Pick tools'));
          expect(text, isNot(contains('\x1b[38;2;')));
          expect(text, isNot(contains('\x1b[48;2;')));
        }
      },
    );

    test(
      'non-empty NO_COLOR is the final restriction against explicit colours',
      () async {
        final text = await _renderChoice(
          colors: ColorPreferences(
            background: BackgroundPreference.light,
            colors: ComponentColors.palette(ColorThemes.signal),
          ),
          component: ComponentColors.palette(ColorThemes.signal),
          environment: const {'NO_COLOR': '1'},
        );

        expect(text, contains('──'));
        expect(text, contains('[checked] [default]'));
        expect(text, isNot(contains('\x1b[38;2;')));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b]11')));
      },
    );

    test('a component override cannot redirect background detection', () async {
      final text = await _renderChoice(
        colors: const ColorPreferences(background: BackgroundPreference.light),
        component: ComponentColors(
          darkPalette: ColorThemes.terminalDefault.copyWith(
            foreground: TerminalColor.rgb(201, 202, 203),
          ),
        ),
      );

      expect(text, contains('\x1b[38;2;52;40;36;49mPick tools'));
      expect(text, isNot(contains('38;2;201;202;203;')));
    });

    test(
      'output depth degrades rgb requests without painting a surface',
      () async {
        final text = await _renderChoice(
          profile: OutputProfile(
            cursor: CapabilitySupport.supported,
            colorDepth: ColorDepth.indexed256,
            glyphs: GlyphSet.unicode,
            geometry: OutputGeometry.fixed(columns: 70, rows: 20),
          ),
        );

        expect(text, contains('──'));
        expect(text, contains('38;5;'));
        expect(text, isNot(contains('38;2;')));
        expect(text, isNot(contains('\x1b[48;5;')));
        expect(text, isNot(contains('\x1b[48;2;')));
      },
    );
  });
}

Future<String> _renderChoice({
  ColorPreferences colors = const ColorPreferences(),
  ComponentColors component = const ComponentColors(),
  Map<String, String?> environment = const <String, String>{},
  OutputProfile? profile,
}) async {
  final output = StringBuffer();
  final tracer = LinePresentationTracer(
    io: TerminalEnvironment.scripted(
      input: Stream.value(' \r'),
      output: output,
      profile: profile ?? _richProfile,
      environment: environment,
    ),
    colors: colors,
    componentColors: component,
    interaction: const InteractionPreferences(mode: PromptMode.rich),
  );
  final result = await tracer.multiSelect<String>(
    'Pick tools',
    [
      Choice('a', 'Starter', disabledReason: 'needs owner role'),
      Choice('b', 'Library'),
    ],
    defaultValues: const ['b'],
  );
  expect(result, isA<Accepted<List<String>>>());
  return output.toString();
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  glyphs: GlyphSet.unicode,
  geometry: OutputGeometry.fixed(columns: 60, rows: 12),
);
