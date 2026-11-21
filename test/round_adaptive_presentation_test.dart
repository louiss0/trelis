import 'dart:async';
import 'dart:math' as math;

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/round_presentation.dart';
import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 70, rows: 20),
  glyphs: GlyphSet.unicode,
);

/// Independent authored values for the Round adaptive defaults.
///
/// These literals are the review fixture: the implementation must match them,
/// and the contrast maths below uses these numbers rather than asking the
/// palette to describe its own suitability.
const Map<String, List<int>> _light = {
  'foreground': [58, 46, 42],
  'muted': [100, 84, 78],
  'accent': [119, 39, 94],
  'selectionForeground': [255, 250, 246],
  'success': [30, 100, 62],
  'warning': [124, 72, 12],
  'error': [150, 35, 48],
  'border': [107, 88, 82],
};

const Map<String, List<int>> _dark = {
  'foreground': [240, 232, 236],
  'muted': [180, 166, 175],
  'accent': [222, 146, 202],
  'selectionForeground': [27, 24, 29],
  'success': [150, 214, 172],
  'warning': [240, 190, 120],
  'error': [255, 145, 155],
  'border': [147, 128, 142],
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
  group('Round adaptive defaults', () {
    test('light and dark defaults are distinct warm-ink plum palettes', () {
      expect(
        RoundPresentation.lightDefault,
        isNot(RoundPresentation.darkDefault),
      );
      expect(
        RoundPresentation.referenceBackground(BackgroundVariant.light),
        TerminalColor.rgb(246, 241, 232),
      );
      expect(
        RoundPresentation.referenceBackground(BackgroundVariant.dark),
        TerminalColor.rgb(27, 24, 29),
      );
      for (final entry in _light.entries) {
        expect(
          _actual(entry.key, RoundPresentation.lightDefault),
          _expected(entry.key, BackgroundVariant.light),
          reason: 'light ${entry.key}',
        );
      }
      for (final entry in _dark.entries) {
        expect(
          _actual(entry.key, RoundPresentation.darkDefault),
          _expected(entry.key, BackgroundVariant.dark),
          reason: 'dark ${entry.key}',
        );
      }
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
        lightDefault: RoundPresentation.lightDefault,
        darkDefault: RoundPresentation.darkDefault,
      );
      final explicit = resolveColors(
        facts: const ColorDetectionFacts(
          passiveBackground: BackgroundObservation.dark,
        ),
        lightDefault: RoundPresentation.lightDefault,
        darkDefault: RoundPresentation.darkDefault,
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
        ),
      );

      expect(unknown.background, BackgroundVariant.dark);
      expect(unknown.palette, RoundPresentation.darkDefault);
      expect(explicit.background, BackgroundVariant.light);
      expect(explicit.palette, RoundPresentation.lightDefault);
    });
  });

  group('Round text input through the internal seam', () {
    for (final variant in BackgroundVariant.values) {
      final isLight = variant == BackgroundVariant.light;
      final foreground = isLight ? '58;46;42' : '240;232;236';
      final muted = isLight ? '100;84;78' : '180;166;175';
      final border = isLight ? '107;88;82' : '147;128;142';

      test('$variant palette styles a real rounded text input', () async {
        final output = StringBuffer();
        final tracer = RoundPresentationTracer(
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
        expect(text, contains('\x1b[38;2;$border;49m╭─'));
        expect(text, contains('─╮\x1b[0m'));
        expect(text, contains('\x1b[38;2;$foreground;49m│ Project name'));
        expect(text, contains('\x1b[38;2;$border;49m╰─'));
        expect(text, contains('─╯\x1b[0m'));
        expect(
          text,
          contains('\x1b[38;2;$muted;49m  Enter submits. Ctrl+T opens help.'),
        );
        expect(text.indexOf('╮'), lessThan(text.indexOf('Project name')));
        expect(text.indexOf('╯'), lessThan(text.indexOf('Ctrl+T opens help.')));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
        expect(text, isNot(contains('\x1b[2J')));
      });
    }
  });

  group('Round choices through the internal seam', () {
    test(
      'a real light choice uses the authored sepia and plum roles',
      () async {
        final text = await _renderChoice(
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
        );

        expect(text, contains('\x1b[38;2;107;88;82;49m╭─'));
        expect(text, contains('\x1b[38;2;58;46;42;49m│ Pick tools'));
        expect(text, contains('\x1b[38;2;119;39;94;49m│ 1. Starter'));
        expect(text, contains('╰─'));
        expect(text, contains('[checked] [default]'));
        expect(text.indexOf('╯'), greaterThan(text.indexOf('Starter')));
        expect(text, isNot(contains('\x1b[48;2;')));
      },
    );

    test(
      'a real dark choice renders plum focus, checked, default and reasons',
      () async {
        final text = await _renderChoice(
          colors: const ColorPreferences(background: BackgroundPreference.dark),
        );

        expect(text, contains('\x1b[38;2;147;128;142;49m╭─'));
        expect(text, contains('\x1b[38;2;240;232;236;49m│ Pick tools'));
        expect(
          text,
          contains(
            '\x1b[38;2;222;146;202;49m│ 1. Starter [unchecked] [focused] '
            '[unavailable: needs owner role]',
          ),
        );
        expect(text, contains('[checked] [default]'));
        expect(
          text,
          contains('\x1b[38;2;240;190;120;49m  Unavailable: needs owner role.'),
        );
        expect(text.indexOf('╯'), greaterThan(text.indexOf('Starter')));
        expect(text, contains('Ctrl+T help'));
        expect(text.indexOf('Ctrl+T help'), greaterThan(text.indexOf('╯')));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
      },
    );

    for (final variant in BackgroundVariant.values) {
      final isLight = variant == BackgroundVariant.light;
      final preference = isLight
          ? BackgroundPreference.light
          : BackgroundPreference.dark;
      final defaultAccent = isLight ? '119;39;94' : '222;146;202';
      final defaultForeground = isLight ? '58;46;42' : '240;232;236';

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

          expect(text, contains('\x1b[38;2;11;22;33;49m│ Pick tools'));
          expect(text, contains('\x1b[38;2;44;55;66;49m│ 1. Starter'));
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
        expect(text, contains('\x1b[38;2;$expected;49m│ 1. Starter'));
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

        expect(text, contains('\x1b[38;2;99;88;77;49m│ Pick tools'));
        expect(text, contains('\x1b[38;2;66;55;44;49m│ 1. Starter'));
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
        expect(text, contains('\x1b[38;2;$expected;49m│ 1. Starter'));
        expect(text, isNot(contains('38;2;3;3;3;')));
        expect(text, isNot(contains('38;2;$defaultAccent;')));
      });
    }
  });
}

Future<String> _renderChoice({
  ColorPreferences colors = const ColorPreferences(),
  ComponentColors component = const ComponentColors(),
  Map<String, String?> environment = const <String, String?>{},
  OutputProfile? profile,
}) async {
  final output = StringBuffer();
  final tracer = RoundPresentationTracer(
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
