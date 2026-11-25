import 'dart:async';
import 'dart:math' as math;

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/branch_presentation.dart';
import 'package:trelis/src/testing/compat_api.dart';
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
      expect(
        BranchPresentation.lightDefault,
        isNot(BranchPresentation.darkDefault),
      );
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
        expect(text, contains('F1 opens help.'));
        expect(text, contains('│ '));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
        expect(text, isNot(contains('\x1b[2J')));
      });
    }
  });

  group('Branch choices through the internal seam', () {
    test(
      'a real light choice uses the authored sepia and plum roles',
      () async {
        final text = await _renderChoice(
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
        );

        expect(text, contains('\x1b[38;2;55;45;40;49m├ Pick tools'));
        expect(text, contains('\x1b[38;2;125;43;96;49m│ 1. Starter'));
        expect(text, contains('\x1b[38;2;98;83;77;49m└ '));
        expect(text, contains('[checked] [default]'));
        expect(text, isNot(contains('\x1b[48;2;')));
      },
    );

    test(
      'a real choice renders plum focus, checked, default and reasons',
      () async {
        final text = await _renderChoice(
          colors: const ColorPreferences(background: BackgroundPreference.dark),
        );

        expect(text, contains('\x1b[38;2;238;232;235;49m├ Pick tools'));
        expect(
          text,
          contains(
            '\x1b[38;2;216;150;205;49m│ 1. Starter [unchecked] [focused] '
            '[unavailable: needs owner role]',
          ),
        );
        expect(text, contains('[checked] [default]'));
        expect(text, contains('Unavailable: needs owner role.'));
        expect(text.indexOf('└ '), greaterThan(text.indexOf('Starter')));
        expect(text, contains('F1 help'));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
      },
    );

    for (final variant in BackgroundVariant.values) {
      final isLight = variant == BackgroundVariant.light;
      final preference = isLight
          ? BackgroundPreference.light
          : BackgroundPreference.dark;
      final defaultAccent = isLight ? '125;43;96' : '216;150;205';
      final defaultForeground = isLight ? '55;45;40' : '238;232;235';

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

          expect(text, contains('\x1b[38;2;11;22;33;49m├ Pick tools'));
          expect(text, contains('\x1b[38;2;44;55;66;49m│ 1. Starter'));
          expect(text, isNot(contains('38;2;$defaultForeground;')));
          expect(text, isNot(contains('38;2;$defaultAccent;')));
        },
      );

      test('$variant variant roles win over shared app roles', () async {
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

        expect(text, contains('\x1b[38;2;99;88;77;49m├ Pick tools'));
        expect(text, contains('\x1b[38;2;66;55;44;49m│ 1. Starter'));
        for (final obsolete in ['11;22;33', '44;55;66', '12;13;14']) {
          expect(text, isNot(contains('38;2;$obsolete;')));
        }
      });

      test(
        '$variant component variant roles override its shared roles',
        () async {
          final text = await _renderChoice(
            colors: ColorPreferences(background: preference),
            component: ComponentColors(
              roles: ColorRoleOverrides(accent: TerminalColor.rgb(3, 3, 3)),
              lightRoles: ColorRoleOverrides(
                accent: TerminalColor.rgb(4, 4, 4),
              ),
              darkRoles: ColorRoleOverrides(accent: TerminalColor.rgb(5, 5, 5)),
            ),
          );

          final expected = isLight ? '4;4;4' : '5;5;5';
          expect(text, contains('\x1b[38;2;$expected;49m│ 1. Starter'));
          expect(text, isNot(contains('38;2;3;3;3;')));
          expect(text, isNot(contains('38;2;$defaultAccent;')));
        },
      );
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
          expect(text, contains('├ Pick tools'));
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

        expect(text, contains('├ Pick tools'));
        expect(text, contains('[checked] [default]'));
        expect(text, isNot(contains('\x1b[38;2;')));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b]11')));
      },
    );

    test(
      'ASCII no-colour narrow output keeps markers and compact help',
      () async {
        final text = await _renderChoice(
          colors: ColorPreferences(
            background: BackgroundPreference.light,
            colors: ComponentColors.palette(ColorThemes.signal),
          ),
          profile: OutputProfile(
            cursor: CapabilitySupport.supported,
            colorDepth: ColorDepth.none,
            geometry: OutputGeometry.fixed(columns: 30, rows: 12),
            glyphs: GlyphSet.ascii,
          ),
        );

        expect(text, contains('+-Pick tools'));
        expect(text, contains('| 1. Starter [unchecked]'));
        expect(text, contains('[focused]'));
        expect(text, contains('needs owner role'));
        expect(text, contains('[checked]'));
        expect(text, contains('[default]'));
        expect(text, contains('Unavailable: needs owner rol'));
        expect(text, contains('F1 help'));
        expect(text.indexOf(r'\-'), greaterThan(text.indexOf('Starter')));
        expect(text, isNot(contains('\x1b[38;2;')));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
        expect(text, isNot(contains('\x1b[2J')));

        // Narrow output wraps the stage and keeps the atomic restriction marker
        // whole; essential text is never truncated to make it fit.
        expect(text, contains('[unavailable: needs owner role]'));
        expect(_visibleLines(text), isNotEmpty);
        for (final line in _visibleLines(text)) {
          expect(line, isNot(contains('…')));
          expect(line, isNot(contains('...')));
        }
      },
    );
  });
}

Future<String> _renderChoice({
  ColorPreferences colors = const ColorPreferences(),
  ComponentColors component = const ComponentColors(),
  Map<String, String?> environment = const <String, String?>{},
  OutputProfile? profile,
}) async {
  final output = StringBuffer();
  final tracer = BranchPresentationTracer(
    io: TerminalEnvironment.scripted(
      input: Stream.value(' \r'),
      output: output,
      profile: profile ?? _choiceProfile,
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

List<String> _visibleLines(String text) => [
  for (final line in text.replaceAll(RegExp(r'\r'), '').split('\n'))
    if (line.isNotEmpty) line.replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), ''),
];

final _choiceProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 70, rows: 20),
  glyphs: GlyphSet.unicode,
);

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 70, rows: 20),
  glyphs: GlyphSet.unicode,
);
