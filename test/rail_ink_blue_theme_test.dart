import 'dart:async';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/rail_ink_blue_theme.dart';
import 'package:trelis/src/text_measurement.dart';
import 'package:trelis/trelis.dart';

/// Behavioral coverage for the internal Rail presentation seam.
///
/// Reference backgrounds are documented in the generated palette source:
/// light #FAF8F3 (Atelier Sepia direction), dark #191C26 (warm ink).
void main() {
  group('adaptive defaults', () {
    test(
      'a light rail text input renders the authored ink-blue palette',
      () async {
        final text = await renderText(
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
        );

        expect(text, contains('| Project name'));
        expect(text, contains('${fg([47, 53, 66])}| Project name'));
        expect(text, contains('${fg([90, 96, 112])}| Left/Right move'));
        expect(text, contains('/help opens help.'));
        expect(text, contains(r'\ '));
        expect(text, isNot(contains('\x1b[48;2')));
      },
    );

    test(
      'dark and unknown backgrounds render the dark ink-blue default',
      () async {
        for (final colors in const [
          ColorPreferences(background: BackgroundPreference.dark),
          ColorPreferences(),
        ]) {
          final text = await renderText(colors: colors);
          expect(
            text,
            contains('${fg([236, 232, 222])}| Project name'),
            reason: '$colors selects the dark default',
          );
          expect(text, contains('${fg([180, 184, 197])}| Left/Right move'));
          expect(text, isNot(contains('\x1b[48;2')));
        }
      },
    );

    test('explicit choice wins and injected background facts are carried into '
        'a real rendering', () async {
      final profile = _profile();
      final explicit = await renderText(
        colors: const ColorPreferences(background: BackgroundPreference.light),
        colorFacts: ColorDetectionFacts(
          outputProfile: profile,
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.dark,
        ),
      );
      final queried = await renderText(
        colors: const ColorPreferences(),
        colorFacts: ColorDetectionFacts(
          outputProfile: profile,
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.light,
        ),
      );
      final passive = await renderText(
        colors: const ColorPreferences(),
        colorFacts: ColorDetectionFacts(
          outputProfile: profile,
          passiveBackground: BackgroundObservation.light,
        ),
      );

      expect(explicit, contains('${fg([47, 53, 66])}| Project name'));
      expect(queried, contains('${fg([47, 53, 66])}| Project name'));
      expect(passive, contains('${fg([47, 53, 66])}| Project name'));
    });

    test('authored normal-text roles meet the 4.5:1 reference target in both '
        'variants', () {
      final variants = [
        (
          name: 'light',
          palette: RailAdaptivePalettes.light,
          reference: RailAdaptivePalettes.lightReference,
          hex: RailAdaptivePalettes.lightReferenceHex,
        ),
        (
          name: 'dark',
          palette: RailAdaptivePalettes.dark,
          reference: RailAdaptivePalettes.darkReference,
          hex: RailAdaptivePalettes.darkReferenceHex,
        ),
      ];
      for (final variant in variants) {
        final roles = <String, TerminalColor>{
          'foreground': variant.palette.foreground,
          'muted': variant.palette.muted,
          'accent': variant.palette.accent,
          'success': variant.palette.success,
          'warning': variant.palette.warning,
          'error': variant.palette.error,
          'border': variant.palette.border,
        };
        for (final entry in roles.entries) {
          final ratio = contrast(rgb(entry.value), [
            variant.reference.red,
            variant.reference.green,
            variant.reference.blue,
          ]);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${variant.name} ${entry.key} on ${variant.hex} is $ratio:1',
          );
        }
        final selection = contrast(
          rgb(variant.palette.selectionForeground),
          rgb(variant.palette.selectionBackground),
        );
        expect(
          selection,
          greaterThanOrEqualTo(4.5),
          reason: '${variant.name} selection foreground/background',
        );
      }
    });
  });

  group('real choice component', () {
    test('a rail selection keeps focus, default and restriction markers '
        'independent', () async {
      final output = StringBuffer();
      final theme = railTheme(
        output,
        '1\r',
        colors: const ColorPreferences(background: BackgroundPreference.light),
      );
      final result = await theme.select<String>('Deploy target', [
        Choice('staging', 'Staging here'),
        Choice('production', 'Production', disabledReason: 'locked for demo'),
      ], defaultValue: 'staging');

      expect((result as Accepted<String>).value, 'staging');
      final text = output.toString();
      expect(text, contains('${fg([47, 53, 66])}| Deploy target Select:'));
      expect(
        text,
        contains('${fg([30, 78, 140])}| 1. Staging here [focused] [default]'),
      );
      expect(text, contains('| 2. Production [unavailable: locked for demo]'));
      expect(text, contains('/help'));
      expect(text, contains('${fg([35, 107, 74])}| Accepted: Staging here.'));
      expect(text, isNot(contains('\x1b[48;2')));
    });

    test('unicode glyphs keep one continuous spine through title, choices '
        'and compact help', () async {
      final output = StringBuffer();
      final theme = railTheme(
        output,
        '1\r',
        profile: _profile(glyphs: GlyphSet.unicode),
        colors: const ColorPreferences(background: BackgroundPreference.dark),
      );
      await theme.select<String>('Deploy target', [
        Choice('staging', 'Staging here'),
        Choice('production', 'Production'),
      ], defaultValue: 'staging');

      final lines = stripAnsi(output.toString()).split('\n');
      final framed = lines.where((line) => line.startsWith('│ ')).toList();
      expect(framed, isNotEmpty);
      expect(
        framed.any((line) => line.contains('Deploy target Select:')),
        isTrue,
        reason: 'the title is on the spine',
      );
      expect(
        framed.any((line) => line.contains('1. Staging here [focused]')),
        isTrue,
        reason: 'the choices are on the spine',
      );
      expect(
        framed.any((line) => line.contains('/help')),
        isTrue,
        reason: 'compact help is on the spine',
      );
      expect(lines.any((line) => line.startsWith('└ ')), isTrue);
    });

    test(
      'a narrow choice keeps readable markers and help inside its width',
      () async {
        final output = StringBuffer();
        final theme = railTheme(
          output,
          '1\r',
          profile: _profile(columns: 26, glyphs: GlyphSet.unicode),
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
        );
        await theme.select<String>('Deploy target', [
          Choice('staging', 'Staging with a deliberately long label'),
          Choice('production', 'Production', disabledReason: 'locked'),
        ], defaultValue: 'staging');

        final text = stripAnsi(output.toString());
        expect(text, contains('[focused] [default]'));
        expect(text, contains('[unavailable: locked]'));
        expect(text, contains('/help'));
        expect(text, contains('Accepted:'));
        for (final line in text.split('\n')) {
          if (line.trim().isEmpty) continue;
          expect(
            TextDisplayMap(line).cellWidth,
            lessThanOrEqualTo(26),
            reason: 'narrow line "$line" must not clip',
          );
        }
        expect(text, isNot(contains('\x1b[48;2')));
      },
    );
  });

  group('palette precedence and restrictions', () {
    for (final background in BackgroundPreference.values) {
      if (background == BackgroundPreference.automatic) continue;
      test('app and component palette layers for ${background.name}', () async {
        final colors = ColorPreferences(background: background);
        final themeFg = background == BackgroundPreference.light
            ? [47, 53, 66]
            : [236, 232, 222];
        final appFg = background == BackgroundPreference.light
            ? [11, 22, 33]
            : [33, 22, 11];
        const appMuted = [120, 121, 122];
        final componentFg = background == BackgroundPreference.light
            ? [77, 88, 99]
            : [99, 88, 77];
        final variantFg = background == BackgroundPreference.light
            ? [44, 55, 66]
            : [66, 55, 44];

        final themeDefault = await renderText(colors: colors);
        expect(themeDefault, contains('${fg(themeFg)}| Project name'));

        final appPalette = await renderText(
          colors: colors,
          appColors: ComponentColors.palette(_palette(appFg, appMuted)),
        );
        expect(appPalette, contains('${fg(appFg)}| Project name'));
        expect(appPalette, contains('${fg(appMuted)}| Left/Right move'));
        expect(appPalette, isNot(contains(fg(themeFg))));

        final appRole = await renderText(
          colors: colors,
          appColors: ComponentColors(
            roles: ColorRoleOverrides(
              foreground: TerminalColor.rgb(appFg[0], appFg[1], appFg[2]),
            ),
          ),
        );
        expect(appRole, contains('${fg(appFg)}| Project name'));
        if (background == BackgroundPreference.light) {
          expect(appRole, contains('${fg([90, 96, 112])}| Left/Right move'));
        } else {
          expect(appRole, contains('${fg([180, 184, 197])}| Left/Right move'));
        }

        final appVariantRole = await renderText(
          colors: colors,
          appColors: ComponentColors(
            lightRoles: ColorRoleOverrides(
              foreground: TerminalColor.rgb(44, 55, 66),
            ),
            darkRoles: ColorRoleOverrides(
              foreground: TerminalColor.rgb(66, 55, 44),
            ),
          ),
        );
        expect(appVariantRole, contains('${fg(variantFg)}| Project name'));

        final componentPalette = await renderText(
          colors: colors,
          appColors: ComponentColors(
            roles: ColorRoleOverrides(
              foreground: TerminalColor.rgb(appFg[0], appFg[1], appFg[2]),
            ),
          ),
          component: ComponentColors.palette(_palette(componentFg)),
        );
        expect(componentPalette, contains('${fg(componentFg)}| Project name'));
        expect(componentPalette, isNot(contains(fg(appFg))));
        expect(componentPalette, isNot(contains(fg(appMuted))));

        final componentRole = await renderText(
          colors: colors,
          appColors: ComponentColors.palette(_palette(appFg, appMuted)),
          component: ComponentColors(
            roles: ColorRoleOverrides(
              foreground: TerminalColor.rgb(
                componentFg[0],
                componentFg[1],
                componentFg[2],
              ),
            ),
          ),
        );
        expect(componentRole, contains('${fg(componentFg)}| Project name'));
        expect(componentRole, contains('${fg(appMuted)}| Left/Right move'));
      });
    }

    test(
      'component colours cannot change background or output capability',
      () async {
        final darkWithLightOverride = await renderText(
          colors: const ColorPreferences(background: BackgroundPreference.dark),
          component: ComponentColors(
            lightPalette: _palette([11, 22, 33]),
            darkPalette: _palette([44, 55, 66]),
          ),
        );
        expect(
          darkWithLightOverride,
          contains('${fg([44, 55, 66])}| Project name'),
        );
        expect(darkWithLightOverride, isNot(contains(fg([11, 22, 33]))));

        final noDepth = await renderText(
          profile: _profile(depth: ColorDepth.none),
          component: ComponentColors.palette(_palette([11, 22, 33])),
        );
        expect(noDepth, contains('| Project name'));
        expect(noDepth, isNot(contains('\x1b[38;')));
      },
    );

    test(
      'terminalDefault at app and component scope suppresses colour',
      () async {
        final appDefault = await renderText(
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
          appColors: ComponentColors.palette(ColorThemes.terminalDefault),
        );
        final componentDefault = await renderText(
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
          appColors: ComponentColors.palette(_palette([11, 22, 33])),
          component: ComponentColors.palette(ColorThemes.terminalDefault),
        );
        final explicitColourWithNoColor = await renderText(
          environment: const {'NO_COLOR': '1'},
          component: ComponentColors.palette(_palette([200, 10, 20])),
        );

        for (final text in [
          appDefault,
          componentDefault,
          explicitColourWithNoColor,
        ]) {
          expect(text, contains('| Project name'));
          expect(text, isNot(contains('\x1b[38;')));
          expect(text, isNot(contains('\x1b[48;')));
        }
      },
    );

    test('monochrome and reduced depth degrade authored colours', () async {
      final monochrome = await renderText(
        profile: _profile(depth: ColorDepth.none),
      );
      expect(monochrome, contains('| Project name'));
      expect(monochrome, isNot(contains('\x1b[38;')));

      final indexed = await renderText(
        profile: _profile(depth: ColorDepth.indexed256),
      );
      expect(indexed, contains(RegExp(r'\x1b\[38;5;')));
      expect(indexed, isNot(contains('\x1b[38;2;')));

      final basic = await renderText(
        profile: _profile(depth: ColorDepth.ansi16),
      );
      expect(basic, contains(RegExp(r'\x1b\[3[0-7];49m')));
      expect(basic, isNot(contains('\x1b[38;2;')));
    });

    test('non-empty NO_COLOR wins over every explicit colour', () async {
      final output = StringBuffer();
      final theme = railTheme(
        output,
        'Ada\r',
        environment: const {'NO_COLOR': '1'},
        colors: const ColorPreferences(
          background: BackgroundPreference.light,
          colors: ComponentColors.palette(ColorThemes.terminalDefault),
        ),
      );
      final result = await theme.textInput(
        'Project name',
        colors: ComponentColors.palette(_palette([250, 10, 20])),
      );

      expect((result as Accepted<String>).value, 'Ada');
      expect(output.toString(), contains('| Project name'));
      expect(output.toString(), isNot(contains('\x1b[38;')));
      expect(output.toString(), isNot(contains('\x1b[48;')));
    });
  });
}

OutputProfile _profile({
  GlyphSet glyphs = GlyphSet.ascii,
  ColorDepth depth = ColorDepth.rgb,
  int columns = 60,
}) => OutputProfile(
  colorDepth: depth,
  glyphs: glyphs,
  geometry: OutputGeometry.fixed(columns: columns, rows: 20),
);

RailInkBlueTheme railTheme(
  StringSink output,
  String input, {
  OutputProfile? profile,
  Map<String, String?> environment = const {},
  ColorPreferences colors = const ColorPreferences(),
  ColorDetectionFacts? colorFacts,
}) {
  final selected = profile ?? _profile();
  return RailInkBlueTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value(input),
      output: output,
      profile: selected,
      environment: environment,
    ),
    interaction: const InteractionPreferences(mode: PromptMode.linear),
    colors: colors,
    colorFacts:
        colorFacts ??
        ColorDetectionFacts(
          outputProfile: selected,
          noColor: environment['NO_COLOR'],
        ),
  );
}

Future<String> renderText({
  ColorPreferences colors = const ColorPreferences(),
  ComponentColors appColors = const ComponentColors(),
  ComponentColors component = const ComponentColors(),
  ColorDetectionFacts? colorFacts,
  OutputProfile? profile,
  Map<String, String?> environment = const {},
  String input = 'Ada\r',
}) async {
  final output = StringBuffer();
  final withApp = ColorPreferences(
    background: colors.background,
    allowBackgroundQuery: colors.allowBackgroundQuery,
    colors: appColors,
  );
  final theme = railTheme(
    output,
    input,
    profile: profile,
    environment: environment,
    colors: withApp,
    colorFacts: colorFacts,
  );
  final result = await theme.textInput('Project name', colors: component);
  expect(result, isA<Accepted<String>>());
  return output.toString();
}

ColorTheme _palette(
  List<int> foreground, [
  List<int>? muted,
]) => ColorThemes.terminalDefault.copyWith(
  foreground: TerminalColor.rgb(foreground[0], foreground[1], foreground[2]),
  muted: muted == null ? null : TerminalColor.rgb(muted[0], muted[1], muted[2]),
);

String fg(List<int> rgb) => '\x1b[38;2;${rgb.join(';')};49m';

String stripAnsi(String text) =>
    text.replaceAll(RegExp('\x1b\\[[0-9;?]*[A-Za-z]'), '');

List<int> rgb(TerminalColor color) => terminalSgr(
  color,
  background: false,
  depth: ColorDepth.rgb,
).split(';').skip(2).map(int.parse).toList();

double contrast(List<int> foreground, List<int> background) {
  final first = _luminance(foreground);
  final second = _luminance(background);
  final lighter = first > second ? first : second;
  final darker = first < second ? first : second;
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(List<int> rgb) {
  double channel(int value) {
    final scaled = value / 255;
    return scaled <= 0.04045
        ? scaled / 12.92
        : math.pow((scaled + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(rgb[0]) +
      0.7152 * channel(rgb[1]) +
      0.0722 * channel(rgb[2]);
}
