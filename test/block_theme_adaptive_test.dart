import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/background_query.dart';
import 'package:trelis/src/block_theme_presentation.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/testing/compat_api.dart';

final _rgbRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 72, rows: 20),
  glyphs: GlyphSet.unicode,
);

void main() {
  test('dark default renders a real Block text input with warm ink', () async {
    final out = StringBuffer();
    final theme = BlockThemePresentation(
      io: TerminalEnvironment.scripted(
        input: Stream.value('Ada\r'),
        output: out,
        profile: _rgbRichProfile,
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      colors: const ColorPreferences(background: BackgroundPreference.dark),
    );

    final result = await theme.textInput('Project name');

    expect((result as Accepted<String>).value, 'Ada');
    expect(out.toString(), contains('PROJECT NAME'));
    expect(out.toString(), contains('█'));
    expect(out.toString(), contains('\x1b[38;2;232;224;209;49m'));
    expect(out.toString(), isNot(contains('\x1b[48;2;')));
    expect(out.toString(), isNot(contains('\x1b[2J')));
  });

  test('light default renders a real Block text input with warm ink', () async {
    final out = StringBuffer();
    final theme = BlockThemePresentation(
      io: TerminalEnvironment.scripted(
        input: Stream.value('Ada\r'),
        output: out,
        profile: _rgbRichProfile,
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      colors: const ColorPreferences(background: BackgroundPreference.light),
    );

    final result = await theme.textInput('Project name');

    expect((result as Accepted<String>).value, 'Ada');
    expect(out.toString(), contains('PROJECT NAME'));
    expect(out.toString(), contains('█'));
    expect(out.toString(), contains('\x1b[38;2;64;56;46;49m'));
    expect(out.toString(), isNot(contains('\x1b[48;2;')));
  });

  test('authored normal-text roles meet 4.5:1 on their reference surfaces', () {
    for (final swatch in [
      ...BlockAdaptivePalettes.lightTextRoles,
      ...BlockAdaptivePalettes.darkTextRoles,
    ]) {
      expect(
        swatch.color,
        TerminalColor.rgb(swatch.rgb.$1, swatch.rgb.$2, swatch.rgb.$3),
        reason: '${swatch.role} swatch must match the authored palette',
      );
      expect(
        _contrastRatio(swatch.rgb, swatch.reference),
        greaterThanOrEqualTo(4.5),
        reason: '${swatch.role} contrast is documented, not guaranteed live',
      );
    }
  });

  test(
    'unknown background falls back to dark and explicit choice wins',
    () async {
      Future<String> render(
        ColorPreferences preferences,
        BackgroundObservation passive,
      ) async {
        final out = StringBuffer();
        final theme = BlockThemePresentation(
          io: TerminalEnvironment.scripted(
            input: Stream.value('Ada\r'),
            output: out,
            profile: _rgbRichProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          colors: preferences,
          colorFacts: ColorDetectionFacts(
            outputProfile: _rgbRichProfile,
            passiveBackground: passive,
          ),
        );
        expect(await theme.textInput('Name'), isA<Accepted<String>>());
        return out.toString();
      }

      final unknown = await render(
        const ColorPreferences(),
        BackgroundObservation.unavailable,
      );
      final malformed = await render(
        const ColorPreferences(),
        BackgroundObservation.malformed,
      );
      final hinted = await render(
        const ColorPreferences(),
        BackgroundObservation.light,
      );
      final explicit = await render(
        const ColorPreferences(background: BackgroundPreference.dark),
        BackgroundObservation.light,
      );

      expect(unknown, contains('\x1b[38;2;232;224;209;49m'));
      expect(malformed, contains('\x1b[38;2;232;224;209;49m'));
      expect(hinted, contains('\x1b[38;2;64;56;46;49m'));
      expect(explicit, contains('\x1b[38;2;232;224;209;49m'));
      expect(explicit, isNot(contains('\x1b[38;2;64;56;46;49m')));
    },
  );

  test(
    'a real choice keeps focus, selection and default markers distinct',
    () async {
      for (final entry in [
        (BackgroundPreference.dark, '\x1b[38;2;224;139;95;49m'),
        (BackgroundPreference.light, '\x1b[38;2;154;67;37;49m'),
      ]) {
        final out = StringBuffer();
        final theme = BlockThemePresentation(
          io: TerminalEnvironment.scripted(
            input: Stream.value(' \r'),
            output: out,
            profile: _rgbRichProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          colors: ColorPreferences(background: entry.$1),
        );

        final result = await theme.multiSelect<String>(
          'Features',
          [Choice('a', 'Starter'), Choice('b', 'Library')],
          defaultValues: const ['b'],
        );

        expect((result as Accepted<List<String>>).value, ['a', 'b']);
        final text = out.toString();
        expect(text, contains('FEATURES'));
        expect(text, contains('█'));
        expect(text, contains('[checked]'));
        expect(text, contains('[unchecked]'));
        expect(text, contains('[focused]'));
        expect(text, contains('[default]'));
        expect(text, contains('Starter: checked.'));
        expect(text, contains('Space toggles'));
        expect(text, contains('Ctrl+T help'));
        expect(
          text,
          contains(entry.$2),
          reason: 'rust accent on the focused row',
        );
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[2J')));
      }
    },
  );

  test(
    'narrow ASCII no-colour choice keeps structure, markers and help',
    () async {
      final out = StringBuffer();
      final profile = OutputProfile(
        cursor: CapabilitySupport.supported,
        colorDepth: ColorDepth.none,
        geometry: OutputGeometry.fixed(columns: 24, rows: 12),
        glyphs: GlyphSet.ascii,
      );
      final theme = BlockThemePresentation(
        io: TerminalEnvironment.scripted(
          input: Stream.value(' \r'),
          output: out,
          profile: profile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        colors: const ColorPreferences(background: BackgroundPreference.dark),
      );

      final result = await theme.multiSelect<String>(
        'Features',
        [Choice('a', 'Starter with a long label'), Choice('b', 'Library')],
        defaultValues: const ['b'],
      );

      expect((result as Accepted<List<String>>).value, ['a', 'b']);
      final text = out.toString();
      expect(text, contains('FEATURES'));
      expect(text, contains('#'));
      expect(text, contains('[checked]'));
      expect(text, contains('[unchecked]'));
      expect(text, contains('[focused]'));
      expect(text, contains('[default]'));
      // A 24-column band wraps words and moves markers to hanging-indent rows;
      // nothing essential is truncated, so compare without wrap whitespace.
      final compact = text.replaceAll(RegExp(r'\s+'), '');
      expect(compact, contains('Spacetoggles'));
      expect(compact, contains('Ctrl+Thelp'));
      expect(text, isNot(contains('\x1b[38;')));
      expect(text, isNot(contains('\x1b[48;')));
      expect(text, isNot(contains('\x1b[2J')));
      expect(text, isNot(contains('\x1b[?1049h')));
    },
  );

  test(
    'palette precedence is visible in rendered output for both variants',
    () async {
      for (final variant in [
        (
          BackgroundPreference.dark,
          _sgr(232, 224, 209),
          _sgr(179, 168, 148),
          _sgr(88, 99, 111),
          _sgr(188, 199, 210),
        ),
        (
          BackgroundPreference.light,
          _sgr(64, 56, 46),
          _sgr(109, 98, 84),
          _sgr(77, 88, 99),
          _sgr(177, 188, 199),
        ),
      ]) {
        final background = variant.$1;
        final app = _palette(11, 22, 33);
        final componentPalette = _palette(111, 122, 133);

        Future<String> render({
          ColorPreferences? preferences,
          ComponentColors component = const ComponentColors(),
          Map<String, String?> environment = const {},
        }) async {
          final out = StringBuffer();
          final theme = BlockThemePresentation(
            io: TerminalEnvironment.scripted(
              input: Stream.value('Ada\r'),
              output: out,
              profile: _rgbRichProfile,
              supportsRich: true,
              environment: environment,
            ),
            interaction: const InteractionPreferences(mode: PromptMode.rich),
            colors: preferences ?? ColorPreferences(background: background),
            colorFacts: ColorDetectionFacts(outputProfile: _rgbRichProfile),
          );
          expect(
            await theme.textInput('Name', colors: component),
            isA<Accepted<String>>(),
          );
          return out.toString();
        }

        final themeDefault = await render();
        expect(themeDefault, contains(variant.$2));
        expect(themeDefault, contains(variant.$3));

        final appWhole = await render(
          preferences: ColorPreferences(
            background: background,
            colors: ComponentColors(
              palette: app,
              roles: ColorRoleOverrides(foreground: _fg(1, 2, 3)),
            ),
          ),
        );
        expect(appWhole, contains(_sgr(1, 2, 3)));
        expect(appWhole, contains(_sgr(22, 33, 11)));
        expect(appWhole, isNot(contains(variant.$2)));

        final appRoles = await render(
          preferences: ColorPreferences(
            background: background,
            colors: ComponentColors(
              roles: ColorRoleOverrides(foreground: _fg(44, 55, 66)),
              lightRoles: ColorRoleOverrides(foreground: _fg(77, 88, 99)),
              darkRoles: ColorRoleOverrides(foreground: _fg(88, 99, 111)),
            ),
          ),
        );
        expect(appRoles, contains(variant.$4));
        expect(appRoles, isNot(contains(_sgr(44, 55, 66))));
        expect(
          appRoles,
          contains(variant.$3),
          reason: 'other roles still come from the theme',
        );

        final componentWhole = await render(
          preferences: ColorPreferences(
            background: background,
            colors: ComponentColors(
              palette: app,
              roles: ColorRoleOverrides(foreground: _fg(1, 2, 3)),
            ),
          ),
          component: ComponentColors.palette(componentPalette),
        );
        expect(componentWhole, contains(_sgr(111, 122, 133)));
        expect(componentWhole, contains(_sgr(122, 133, 111)));
        expect(componentWhole, isNot(contains(_sgr(1, 2, 3))));
        expect(componentWhole, isNot(contains(_sgr(11, 22, 33))));

        final componentRoles = await render(
          component: ComponentColors(
            roles: ColorRoleOverrides(foreground: _fg(144, 155, 166)),
            lightRoles: ColorRoleOverrides(foreground: _fg(177, 188, 199)),
            darkRoles: ColorRoleOverrides(foreground: _fg(188, 199, 210)),
          ),
        );
        expect(componentRoles, contains(variant.$5));
        expect(componentRoles, isNot(contains(_sgr(144, 155, 166))));
      }
    },
  );

  test(
    'explicit terminalDefault at app and component scope emits no colour',
    () async {
      for (final background in [
        BackgroundPreference.light,
        BackgroundPreference.dark,
      ]) {
        final appScope = await _renderText(
          preferences: ColorPreferences(
            background: background,
            colors: ComponentColors.palette(ColorThemes.terminalDefault),
          ),
        );
        final componentScope = await _renderText(
          preferences: ColorPreferences(
            background: background,
            colors: ComponentColors(
              palette: _palette(11, 22, 33),
              roles: ColorRoleOverrides(foreground: _fg(1, 2, 3)),
            ),
          ),
          component: ComponentColors.palette(ColorThemes.terminalDefault),
        );

        for (final text in [appScope, componentScope]) {
          expect(text, contains('NAME'));
          expect(text, isNot(contains('\x1b[38;2;')));
          expect(text, isNot(contains('\x1b[48;2;')));
          expect(text, isNot(contains(_sgr(1, 2, 3))));
          expect(text, isNot(contains(_sgr(11, 22, 33))));
        }
      }
    },
  );

  test(
    'non-empty NO_COLOR defeats explicit colours and background queries',
    () async {
      final text = await _renderText(
        preferences: ColorPreferences(
          background: BackgroundPreference.dark,
          colors: ComponentColors.palette(_palette(11, 22, 33)),
        ),
        component: ComponentColors.palette(_palette(44, 55, 66)),
        environment: const {'NO_COLOR': '1'},
      );

      expect(text, contains('NAME'));
      expect(text, isNot(contains('\x1b[38;2;')));
      expect(text, isNot(contains('\x1b[48;2;')));
      expect(text, isNot(contains(osc11BackgroundRequest)));
    },
  );

  test(
    'output colour depth degrades authored RGB without losing content',
    () async {
      final out = StringBuffer();
      final profile = OutputProfile(
        cursor: CapabilitySupport.supported,
        styles: CapabilitySupport.supported,
        colorDepth: ColorDepth.indexed256,
        geometry: OutputGeometry.fixed(columns: 72, rows: 20),
        glyphs: GlyphSet.unicode,
      );
      final theme = BlockThemePresentation(
        io: TerminalEnvironment.scripted(
          input: Stream.value('Ada\r'),
          output: out,
          profile: profile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        colors: const ColorPreferences(background: BackgroundPreference.dark),
      );

      expect(await theme.textInput('Name'), isA<Accepted<String>>());
      final text = out.toString();
      expect(text, contains('NAME'));
      expect(text, contains('█'));
      expect(text, isNot(contains('38;2;')));
      expect(text, matches(RegExp(r'\x1b\[38;5;')));
      expect(text, isNot(contains('\x1b[48;2;')));
    },
  );

  test(
    'a component override cannot choose the background or the I/O',
    () async {
      final out = StringBuffer();
      final theme = BlockThemePresentation(
        io: TerminalEnvironment.scripted(
          input: Stream.value('Ada\r'),
          output: out,
          profile: _rgbRichProfile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        colorFacts: ColorDetectionFacts(
          outputProfile: _rgbRichProfile,
          passiveBackground: BackgroundObservation.light,
        ),
      );

      final result = await theme.textInput(
        'Name',
        colors: ComponentColors(
          lightPalette: _palette(1, 2, 3),
          darkPalette: _palette(4, 5, 6),
        ),
      );

      expect(result, isA<Accepted<String>>());
      expect(out.toString(), contains(_sgr(1, 2, 3)));
      expect(out.toString(), isNot(contains(_sgr(4, 5, 6))));
      expect(out.toString(), contains('NAME'));
    },
  );

  test(
    'Block heading, indented rows and compact help keep their order',
    () async {
      final out = StringBuffer();
      final theme = BlockThemePresentation(
        io: TerminalEnvironment.scripted(
          input: Stream.value(' \r'),
          output: out,
          profile: _rgbRichProfile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        colors: const ColorPreferences(background: BackgroundPreference.dark),
      );
      await theme.multiSelect<String>('Features', [
        Choice('a', 'Starter'),
        Choice('b', 'Library'),
      ]);

      final text = out.toString();
      final heading = text.indexOf('FEATURES');
      final row = text.indexOf('1. Starter');
      final hint = text.indexOf('Space toggles');
      expect(heading, greaterThanOrEqualTo(0));
      expect(row, greaterThan(heading));
      expect(hint, greaterThan(row));
      expect(text, contains('  1. Starter'));
    },
  );

  test('screen-reader essential guidance precedes the Block prompt', () async {
    final out = StringBuffer();
    final theme = BlockThemePresentation(
      io: TerminalEnvironment.scripted(
        input: Stream.value('Ada\r'),
        output: out,
        profile: _rgbRichProfile,
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(
        mode: PromptMode.linear,
        screenReader: ScreenReaderPreference.on,
      ),
      colors: const ColorPreferences(background: BackgroundPreference.dark),
    );

    expect(await theme.textInput('Name'), isA<Accepted<String>>());
    final text = out.toString();
    expect(text, contains('Name entry.'));
    expect(text.indexOf('Name entry.'), lessThan(text.indexOf('NAME')));
    expect(text.indexOf('/help opens help.'), lessThan(text.indexOf('NAME')));
  });
}

Future<String> _renderText({
  required ColorPreferences preferences,
  ComponentColors component = const ComponentColors(),
  Map<String, String?> environment = const {},
}) async {
  final out = StringBuffer();
  final theme = BlockThemePresentation(
    io: TerminalEnvironment.scripted(
      input: Stream.value('Ada\r'),
      output: out,
      profile: _rgbRichProfile,
      supportsRich: true,
      environment: environment,
    ),
    interaction: const InteractionPreferences(mode: PromptMode.rich),
    colors: preferences,
  );
  expect(
    await theme.textInput('Name', colors: component),
    isA<Accepted<String>>(),
  );
  return out.toString();
}

TerminalColor _fg(int red, int green, int blue) =>
    TerminalColor.rgb(red, green, blue);

ColorTheme _palette(int red, int green, int blue) =>
    ColorThemes.terminalDefault.copyWith(
      foreground: _fg(red, green, blue),
      muted: _fg(green, blue, red),
      accent: _fg(blue, red, green),
    );

String _sgr(int red, int green, int blue) => '\x1b[38;2;$red;$green;$blue;49m';

double _contrastRatio((int, int, int) a, (int, int, int) b) {
  final first = _relativeLuminance(a);
  final second = _relativeLuminance(b);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance((int, int, int) rgb) {
  double channel(int value) {
    final scaled = value / 255;
    if (scaled <= 0.03928) return scaled / 12.92;
    final adjusted = (scaled + 0.055) / 1.055;
    return adjusted * adjusted * adjusted * adjusted;
  }

  return 0.2126 * channel(rgb.$1) +
      0.7152 * channel(rgb.$2) +
      0.0722 * channel(rgb.$3);
}
