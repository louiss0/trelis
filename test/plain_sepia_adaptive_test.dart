import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/background_query.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/plain_adaptive_presentation.dart';
import 'package:trelis/src/themes/plain_sepia_palettes.dart';
import 'package:trelis/trelis.dart';

/// Reads a request back through the public SGR rendering, so the test does not
/// depend on the private colour subclasses.
List<int> _rgb(TerminalColor color) => terminalSgr(
  color,
  background: false,
  depth: ColorDepth.rgb,
).split(';').skip(2).map(int.parse).toList();

/// True when a rendering requests an explicit background colour.
///
/// Foreground RGB requests can contain the digits `48` as a channel, so a
/// plain substring check would confuse `38;2;48;...` with a surface paint.
bool _paintsSurface(String text) =>
    text.contains('48;2;') ||
    text.contains('48;5;') ||
    text.contains('\x1b[48m');

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

  group('Plain adaptive colour resolution', () {
    test('explicit choice wins and unknown background falls back to dark', () {
      final explicit = resolvePlainColors(
        facts: const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.dark,
        ),
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
        ),
      );
      final queried = resolvePlainColors(
        facts: const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.light,
        ),
      );
      final passive = resolvePlainColors(
        facts: const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
          passiveBackground: BackgroundObservation.light,
        ),
      );
      final unknown = resolvePlainColors(
        facts: const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
          queriedBackground: BackgroundObservation.malformed,
        ),
      );

      expect(explicit.background, BackgroundVariant.light);
      expect(queried.background, BackgroundVariant.light);
      expect(passive.background, BackgroundVariant.light);
      expect(unknown.background, BackgroundVariant.dark);
      expect(explicit.palette.foreground, PlainSepiaPalettes.light.foreground);
      expect(queried.palette.foreground, PlainSepiaPalettes.light.foreground);
      expect(unknown.palette.foreground, PlainSepiaPalettes.dark.foreground);
      expect(explicit.shouldQueryBackground, isFalse);
      expect(queried.shouldQueryBackground, isFalse);
      expect(passive.shouldQueryBackground, isTrue);
    });

    test(
      'app roles layer over defaults and component replacement discards them',
      () {
        final appPalette = ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(1, 2, 3),
        );
        final appAccent = TerminalColor.rgb(4, 5, 6);
        final appDarkAccent = TerminalColor.rgb(7, 8, 9);
        final componentPalette = ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(10, 11, 12),
        );
        final componentAccent = TerminalColor.rgb(13, 14, 15);
        final preferences = ColorPreferences(
          colors: ComponentColors(
            palette: appPalette,
            roles: ColorRoleOverrides(accent: appAccent),
            darkRoles: ColorRoleOverrides(accent: appDarkAccent),
          ),
        );
        final facts = const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
        );

        final appOnly = resolvePlainColors(
          facts: facts,
          preferences: preferences,
        );
        final withComponent = resolvePlainColors(
          facts: facts,
          preferences: preferences,
          component: ComponentColors(
            palette: componentPalette,
            roles: ColorRoleOverrides(accent: componentAccent),
          ),
        );

        expect(appOnly.palette.foreground, appPalette.foreground);
        expect(appOnly.palette.accent, appDarkAccent);
        expect(withComponent.palette.foreground, componentPalette.foreground);
        expect(withComponent.palette.accent, componentAccent);
        expect(
          withComponent.palette.accent,
          isNot(anyOf(appAccent, appDarkAccent)),
        );
      },
    );

    test('variant roles win over shared roles in both scopes', () {
      final shared = TerminalColor.rgb(20, 21, 22);
      final lightAccent = TerminalColor.rgb(23, 24, 25);
      final darkAccent = TerminalColor.rgb(26, 27, 28);
      final resolved = resolvePlainColors(
        facts: const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
        ),
        preferences: ColorPreferences(
          colors: ComponentColors(
            roles: ColorRoleOverrides(accent: shared),
            lightRoles: ColorRoleOverrides(accent: lightAccent),
            darkRoles: ColorRoleOverrides(accent: darkAccent),
          ),
        ),
        component: ComponentColors(
          roles: ColorRoleOverrides(border: shared),
          lightRoles: ColorRoleOverrides(border: lightAccent),
          darkRoles: ColorRoleOverrides(border: darkAccent),
        ),
      );

      expect(resolved.palette.accent, darkAccent);
      expect(resolved.palette.border, darkAccent);
    });

    test('terminalDefault is an explicit palette at either scope', () {
      final facts = const ColorDetectionFacts(
        outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
      );
      final atApp = resolvePlainColors(
        facts: facts,
        preferences: const ColorPreferences(
          colors: ComponentColors.palette(ColorThemes.terminalDefault),
        ),
      );
      final atComponent = resolvePlainColors(
        facts: facts,
        component: const ComponentColors.palette(ColorThemes.terminalDefault),
      );

      expect(isTerminalDefault(atApp.palette.foreground), isTrue);
      expect(isTerminalDefault(atComponent.palette.foreground), isTrue);
    });

    test(
      'NO_COLOR and output depth restrict colour requests at the boundary',
      () {
        final explicit = ComponentColors.palette(
          ColorThemes.terminalDefault.copyWith(
            foreground: TerminalColor.rgb(31, 32, 33),
          ),
        );
        final restricted = resolvePlainColors(
          facts: const ColorDetectionFacts(
            noColor: '1',
            outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
          ),
          component: explicit,
        );
        final degraded = resolvePlainColors(
          facts: const ColorDetectionFacts(
            outputProfile: OutputProfile(colorDepth: ColorDepth.indexed256),
          ),
        );
        final unknownDepth = resolvePlainColors();

        expect(restricted.outputProfile.colorDepth, ColorDepth.none);
        expect(restricted.shouldQueryBackground, isFalse);
        expect(degraded.outputProfile.colorDepth, ColorDepth.indexed256);
        expect(unknownDepth.outputProfile.colorDepth, ColorDepth.none);
        expect(unknownDepth.shouldQueryBackground, isFalse);
      },
    );
  });

  group('Plain adaptive component output', () {
    test(
      'real text input uses the light default and bare Plain placement',
      () async {
        final output = StringBuffer();
        final presentation = PlainAdaptivePresentation(
          io: TerminalEnvironment.scripted(
            input: Stream.value('Ada\r'),
            output: output,
            profile: const OutputProfile(colorDepth: ColorDepth.rgb),
          ),
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );

        final result = await presentation.textInput(
          'Project name',
          instructions: InstructionDisplay.hidden,
        );

        expect((result as Accepted<String>).value, 'Ada');
        final text = output.toString();
        expect(
          text,
          contains('\x1b[38;2;55;45;35;49mProject name (Optional).'),
        );
        expect(
          text.indexOf('Project name'),
          lessThan(text.indexOf('Enter submits')),
        );
        expect(text, contains('Enter submits; /help opens help.'));
        expect(text, isNot(contains('┌')));
        expect(text, isNot(contains('│')));
        expect(text, isNot(contains('? PROJECT NAME')));
        expect(_paintsSurface(text), isFalse, reason: 'no whole-surface paint');
      },
    );

    test(
      'real text input uses the dark default when background is unknown',
      () async {
        final output = StringBuffer();
        final presentation = PlainAdaptivePresentation(
          io: TerminalEnvironment.scripted(
            input: Stream.value('Ada\r'),
            output: output,
            profile: const OutputProfile(colorDepth: ColorDepth.rgb),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );

        expect(
          (await presentation.textInput(
            'Project name',
          ) as Accepted<String>).value,
          'Ada',
        );
        expect(
          output.toString(),
          contains('\x1b[38;2;236;225;207;49mProject name (Optional).'),
        );
        expect(_paintsSurface(output.toString()), isFalse);
      },
    );

    test(
      'real choice component keeps independent markers in both variants',
      () async {
        for (final (background, foreground) in [
          (BackgroundPreference.light, '55;45;35'),
          (BackgroundPreference.dark, '236;225;207'),
        ]) {
          final output = StringBuffer();
          final presentation = PlainAdaptivePresentation(
            io: TerminalEnvironment.scripted(
              input: Stream.value('2\r'),
              output: output,
              profile: const OutputProfile(colorDepth: ColorDepth.rgb),
            ),
            colors: ColorPreferences(background: background),
            interaction: const InteractionPreferences(mode: PromptMode.linear),
          );

          final result = await presentation.select<String>('Choose features', [
            Choice('starter', 'Starter'),
            Choice('library', 'Library'),
          ], defaultValue: 'starter');

          expect((result as Accepted<String>).value, 'library');
          final text = output.toString();
          expect(text, contains('\x1b[38;2;$foreground;49mChoose features'));
          expect(text, contains('[focused]'));
          expect(text, contains('[default]'));
          expect(text, contains('Starter'));
          expect(text, contains('Library'));
          expect(
            text.indexOf('Choose features'),
            lessThan(text.indexOf('Starter')),
          );
          expect(text.indexOf('Library'), lessThan(text.indexOf('/help')));
          expect(
            _paintsSurface(text),
            isFalse,
            reason: 'no whole-surface paint',
          );
        }
      },
    );

    test('component palette replaces app palette in rendered output', () async {
      final output = StringBuffer();
      final presentation = PlainAdaptivePresentation(
        io: TerminalEnvironment.scripted(
          input: Stream.value('Ada\r'),
          output: output,
          profile: const OutputProfile(colorDepth: ColorDepth.rgb),
        ),
        colors: ColorPreferences(
          colors: ComponentColors(
            palette: ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(1, 2, 3),
            ),
          ),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      await presentation.textInput(
        'Project name',
        colors: ComponentColors.palette(
          ColorThemes.terminalDefault.copyWith(
            foreground: TerminalColor.rgb(9, 8, 7),
          ),
        ),
      );

      expect(output.toString(), contains('\x1b[38;2;9;8;7;49mProject name'));
      expect(output.toString(), isNot(contains('38;2;1;2;3')));
    });

    test(
      'explicit terminalDefault at app and component scope emits no colour',
      () async {
        for (final scope in ['app', 'component']) {
          final output = StringBuffer();
          final presentation = PlainAdaptivePresentation(
            io: TerminalEnvironment.scripted(
              input: Stream.value('Ada\r'),
              output: output,
              profile: const OutputProfile(colorDepth: ColorDepth.rgb),
            ),
            colors: scope == 'app'
                ? const ColorPreferences(
                    colors: ComponentColors.palette(
                      ColorThemes.terminalDefault,
                    ),
                  )
                : const ColorPreferences(),
            interaction: const InteractionPreferences(mode: PromptMode.linear),
          );

          await presentation.textInput(
            'Project name',
            colors: scope == 'component'
                ? const ComponentColors.palette(ColorThemes.terminalDefault)
                : const ComponentColors(),
          );

          expect(output.toString(), contains('Project name'));
          expect(output.toString(), isNot(contains('38;2;')), reason: scope);
          expect(_paintsSurface(output.toString()), isFalse, reason: scope);
        }
      },
    );

    test(
      'non-empty NO_COLOR wins over an explicit component palette',
      () async {
        final output = StringBuffer();
        final presentation = PlainAdaptivePresentation(
          io: TerminalEnvironment.scripted(
            input: Stream.value('Ada\r'),
            output: output,
            profile: const OutputProfile(colorDepth: ColorDepth.rgb),
            environment: const {'NO_COLOR': '1'},
          ),
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );

        await presentation.textInput(
          'Project name',
          colors: ComponentColors.palette(
            ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(9, 8, 7),
            ),
          ),
        );

        expect(output.toString(), contains('Project name'));
        expect(output.toString(), isNot(contains('38;2;')));
        expect(output.toString(), isNot(contains(osc11BackgroundRequest)));
      },
    );

    test(
      'narrow ASCII no-colour choice keeps markers and readable reasons',
      () async {
        final output = StringBuffer();
        final presentation = PlainAdaptivePresentation(
          io: TerminalEnvironment.scripted(
            input: Stream.value('1\r'),
            output: output,
            profile: OutputProfile(
              glyphs: GlyphSet.ascii,
              colorDepth: ColorDepth.none,
              geometry: OutputGeometry.fixed(columns: 20, rows: 6),
            ),
          ),
          colors: const ColorPreferences(background: BackgroundPreference.dark),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );

        final result = await presentation.select<String>('Choose features', [
          Choice('starter', 'Starter'),
          Choice('library', 'Library', disabledReason: 'needs owner role'),
        ], defaultValue: 'starter');

        expect((result as Accepted<String>).value, 'starter');
        final text = output.toString().replaceAll('\n', ' ');
        expect(text, contains('Choose features'));
        expect(text, contains('Starter'));
        expect(text, contains('[focused]'));
        expect(text, contains('[default]'));
        expect(text, contains('unavailable: needs owner role'));
        expect(text, contains('/help'));
        expect(text, isNot(contains('38;')));
        expect(_paintsSurface(text), isFalse);
        expect(text, isNot(contains('┌')));
      },
    );

    test('both variants layer app and component declarations in order', () {
      for (final (background, defaultPalette) in [
        (BackgroundPreference.light, PlainSepiaPalettes.light),
        (BackgroundPreference.dark, PlainSepiaPalettes.dark),
      ]) {
        final facts = ColorDetectionFacts(
          outputProfile: const OutputProfile(colorDepth: ColorDepth.rgb),
          passiveBackground: background == BackgroundPreference.light
              ? BackgroundObservation.dark
              : BackgroundObservation.light,
        );
        final preferences = ColorPreferences(
          background: background,
          colors: ComponentColors(
            lightPalette: ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(41, 42, 43),
            ),
            darkPalette: ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(44, 45, 46),
            ),
            roles: ColorRoleOverrides(accent: TerminalColor.rgb(51, 52, 53)),
            lightRoles: ColorRoleOverrides(
              accent: TerminalColor.rgb(54, 55, 56),
            ),
            darkRoles: ColorRoleOverrides(
              accent: TerminalColor.rgb(57, 58, 59),
            ),
          ),
        );
        final presentation = PlainAdaptivePresentation(
          io: TerminalEnvironment.scripted(
            input: const Stream<String>.empty(),
            output: StringBuffer(),
          ),
          colors: preferences,
        );
        final componentAccent = TerminalColor.rgb(61, 62, 63);
        final appOnly = presentation.resolve(facts: facts);
        final withComponent = presentation.resolve(
          facts: facts,
          component: ComponentColors(
            palette: ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(64, 65, 66),
            ),
            roles: ColorRoleOverrides(accent: componentAccent),
          ),
        );

        expect(
          appOnly.background,
          background == BackgroundPreference.light
              ? BackgroundVariant.light
              : BackgroundVariant.dark,
        );
        expect(
          appOnly.palette.accent,
          background == BackgroundPreference.light
              ? TerminalColor.rgb(54, 55, 56)
              : TerminalColor.rgb(57, 58, 59),
        );
        expect(
          appOnly.palette.foreground,
          background == BackgroundPreference.light
              ? TerminalColor.rgb(41, 42, 43)
              : TerminalColor.rgb(44, 45, 46),
        );
        expect(withComponent.palette.foreground, TerminalColor.rgb(64, 65, 66));
        expect(withComponent.palette.accent, componentAccent);
        expect(
          withComponent.palette.foreground,
          isNot(defaultPalette.foreground),
        );
      }
    });

    test(
      'component colours cannot choose a background or suppress detection',
      () {
        final presentation = PlainAdaptivePresentation(
          io: TerminalEnvironment.scripted(
            input: const Stream<String>.empty(),
            output: StringBuffer(),
          ),
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
        );
        final facts = const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
        );
        final plain = presentation.resolve(facts: facts);
        final withComponent = presentation.resolve(
          facts: facts,
          component: ComponentColors(
            lightPalette: ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(71, 72, 73),
            ),
            darkPalette: ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(74, 75, 76),
            ),
          ),
        );

        expect(plain.background, BackgroundVariant.light);
        expect(withComponent.background, BackgroundVariant.light);
        expect(
          plain.shouldQueryBackground,
          withComponent.shouldQueryBackground,
        );
        expect(withComponent.palette.foreground, TerminalColor.rgb(71, 72, 73));
      },
    );

    test(
      'real output degrades colour depth without changing structure',
      () async {
        for (final (depth, marker) in [
          (ColorDepth.indexed256, '38;5;'),
          (ColorDepth.none, null),
        ]) {
          final output = StringBuffer();
          final presentation = PlainAdaptivePresentation(
            io: TerminalEnvironment.scripted(
              input: Stream.value('Ada\r'),
              output: output,
              profile: OutputProfile(colorDepth: depth),
            ),
            interaction: const InteractionPreferences(mode: PromptMode.linear),
          );

          await presentation.textInput(
            'Project name',
            instructions: InstructionDisplay.hidden,
          );

          expect(output.toString(), contains('Project name'));
          expect(
            output.toString(),
            contains('Enter submits; /help opens help.'),
          );
          if (marker == null) {
            expect(output.toString(), isNot(contains('38;')));
          } else {
            expect(output.toString(), contains(marker));
            expect(output.toString(), isNot(contains('38;2;')));
          }
          expect(_paintsSurface(output.toString()), isFalse);
        }
      },
    );

    test(
      'narrow ASCII text input keeps the bare question and compact hint',
      () async {
        final output = StringBuffer();
        final presentation = PlainAdaptivePresentation(
          io: TerminalEnvironment.scripted(
            input: Stream.value('Ada\r'),
            output: output,
            profile: OutputProfile(
              glyphs: GlyphSet.ascii,
              colorDepth: ColorDepth.none,
              geometry: OutputGeometry.fixed(columns: 24, rows: 6),
            ),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );

        await presentation.textInput(
          'Project name',
          instructions: InstructionDisplay.hidden,
        );

        final text = output.toString();
        final joined = text.replaceAll('\n', ' ');
        expect(text, contains('Project name (Optional).'));
        expect(joined, contains('Enter submits'));
        expect(joined, contains('/help'));
        expect(joined, contains('help.'));
        expect(text, isNot(contains('38;')));
        expect(_paintsSurface(text), isFalse);
        expect(text, isNot(contains('┌')));
        expect(text, isNot(contains('? PROJECT NAME')));
      },
    );
  });
}
