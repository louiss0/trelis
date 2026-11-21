import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/ledger_adaptive_theme.dart';
import 'package:trelis/src/state_help_presentation.dart';
import 'package:trelis/trelis.dart';

/// Authored normal-text pairs and their declared reference backgrounds.
///
/// These literals are the design source of truth for the Ledger sepia
/// direction. They are deliberately independent of the palette objects so a
/// contrast assertion cannot pass by construction.
const _lightReference = '#f7f0e2';
const _darkReference = '#211d19';

const Map<String, String> _lightPairs = {
  'foreground': '#42392f',
  'muted': '#6b5e4c',
  'accent': '#83562d',
  'success': '#416a44',
  'warning': '#8a5a10',
  'error': '#ad3b37',
};

const Map<String, String> _darkPairs = {
  'foreground': '#f3e9d8',
  'muted': '#c0b09a',
  'accent': '#d2a679',
  'success': '#9bc98f',
  'warning': '#e0b45f',
  'error': '#f0998c',
};

TerminalColor _rgb(String hex) {
  final value = hex.replaceFirst('#', '');
  return TerminalColor.rgb(
    int.parse(value.substring(0, 2), radix: 16),
    int.parse(value.substring(2, 4), radix: 16),
    int.parse(value.substring(4, 6), radix: 16),
  );
}

TerminalColor _role(ColorTheme palette, String role) => switch (role) {
  'foreground' => palette.foreground,
  'muted' => palette.muted,
  'accent' => palette.accent,
  'success' => palette.success,
  'warning' => palette.warning,
  'error' => palette.error,
  _ => throw ArgumentError(role),
};

double _luminance(String hex) {
  final value = hex.replaceFirst('#', '');
  final channels =
      [
            for (final start in [0, 2, 4])
              int.parse(value.substring(start, start + 2), radix: 16) / 255,
          ]
          .map(
            (channel) => channel <= 0.03928
                ? channel / 12.92
                : ((channel + 0.055) / 1.055) *
                      ((channel + 0.055) / 1.055) *
                      ((channel + 0.055) / 1.055),
          )
          .toList();
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

double _contrast(String foreground, String reference) {
  final a = _luminance(foreground);
  final b = _luminance(reference);
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Ledger adaptive sepia defaults', () {
    test('light and dark defaults are distinct warm-ink palettes', () {
      final light = LedgerAdaptivePalettes.light;
      final dark = LedgerAdaptivePalettes.dark;

      expect(light.accent, isNot(dark.accent));
      expect(light.foreground, isNot(dark.foreground));
      expect(light.background, isTerminalDefault);
      expect(dark.background, isTerminalDefault);
      expect(
        ledgerPaletteFor(BackgroundVariant.light),
        same(LedgerAdaptivePalettes.light),
      );
      expect(
        ledgerPaletteFor(BackgroundVariant.dark),
        same(LedgerAdaptivePalettes.dark),
      );
    });

    for (final entry in {
      BackgroundVariant.light: (_lightReference, _lightPairs),
      BackgroundVariant.dark: (_darkReference, _darkPairs),
    }.entries) {
      test('${entry.key.name} authored normal-text pairs reach 4.5:1', () {
        final (reference, pairs) = entry.value;
        final palette = ledgerPaletteFor(entry.key);
        for (final role in pairs.keys) {
          expect(_role(palette, role), _rgb(pairs[role]!), reason: role);
          expect(
            _contrast(pairs[role]!, reference),
            greaterThanOrEqualTo(4.5),
            reason: '$role on reference $reference',
          );
        }
      });
    }

    ResolvedColors resolveLedger({
      ColorPreferences preferences = const ColorPreferences(),
      ComponentColors? component,
      ColorDetectionFacts facts = const ColorDetectionFacts(),
    }) => resolveLedgerColors(
      facts: facts,
      preferences: preferences,
      component: component,
    );

    test('unknown background falls back to dark; explicit choice wins', () {
      final unknown = resolveLedger();
      final light = resolveLedger(
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
        ),
        facts: const ColorDetectionFacts(
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.dark,
        ),
      );

      expect(unknown.background, BackgroundVariant.dark);
      expect(unknown.palette.accent, LedgerAdaptivePalettes.dark.accent);
      expect(light.background, BackgroundVariant.light);
      expect(light.palette.accent, LedgerAdaptivePalettes.light.accent);
    });

    for (final variant in BackgroundVariant.values) {
      final preference = variant == BackgroundVariant.light
          ? BackgroundPreference.light
          : BackgroundPreference.dark;
      final expectedRole = variant == BackgroundVariant.light ? 13 : 15;

      test('$variant palette precedence follows the reviewed order', () {
        final base = resolveLedger(
          preferences: ColorPreferences(background: preference),
        ).palette;
        expect(base.accent, ledgerPaletteFor(variant).accent);

        final app = resolveLedger(
          preferences: ColorPreferences(
            background: preference,
            colors: ComponentColors(
              palette: ColorThemes.terminalDefault.copyWith(
                foreground: TerminalColor.indexed(100),
              ),
              roles: ColorRoleOverrides(
                accent: TerminalColor.indexed(11),
                warning: TerminalColor.indexed(12),
              ),
              lightRoles: ColorRoleOverrides(accent: TerminalColor.indexed(13)),
              darkRoles: ColorRoleOverrides(accent: TerminalColor.indexed(15)),
            ),
          ),
        ).palette;
        expect(app.foreground, TerminalColor.indexed(100));
        expect(app.accent, TerminalColor.indexed(expectedRole));
        expect(app.warning, TerminalColor.indexed(12));

        final componentRoles = resolveLedger(
          preferences: ColorPreferences(
            background: preference,
            colors: ComponentColors(
              roles: ColorRoleOverrides(warning: TerminalColor.indexed(12)),
            ),
          ),
          component: ComponentColors(
            roles: ColorRoleOverrides(accent: TerminalColor.indexed(21)),
          ),
        ).palette;
        expect(componentRoles.accent, TerminalColor.indexed(21));
        expect(componentRoles.warning, TerminalColor.indexed(12));
        expect(componentRoles.foreground, ledgerPaletteFor(variant).foreground);

        final replacement = resolveLedger(
          preferences: ColorPreferences(
            background: preference,
            colors: ComponentColors(
              palette: ColorThemes.terminalDefault.copyWith(
                foreground: TerminalColor.indexed(100),
              ),
              roles: ColorRoleOverrides(warning: TerminalColor.indexed(12)),
            ),
          ),
          component: ComponentColors.palette(
            ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.indexed(200),
              muted: TerminalColor.indexed(201),
            ),
          ),
        ).palette;
        expect(replacement.foreground, TerminalColor.indexed(200));
        expect(replacement.muted, TerminalColor.indexed(201));
        expect(replacement.warning, ColorThemes.terminalDefault.warning);
      });
    }

    test(
      'explicit terminalDefault, NO_COLOR and depth degrade at the boundary',
      () {
        final facts = ColorDetectionFacts(
          outputProfile: const OutputProfile(colorDepth: ColorDepth.rgb),
          noColor: '1',
        );
        final native = resolveLedger(
          preferences: const ColorPreferences(
            colors: ComponentColors.palette(ColorThemes.terminalDefault),
          ),
          component: ComponentColors.palette(ColorThemes.terminalDefault),
          facts: facts,
        );
        expect(native.background, BackgroundVariant.dark);
        expect(isTerminalDefault(native.palette.accent), isTrue);
        expect(native.outputProfile.colorDepth, ColorDepth.none);
        expect(
          terminalStyledText(
            'ready',
            foreground: native.palette.foreground,
            background: native.palette.background,
            depth: native.outputProfile.colorDepth,
          ),
          'ready',
        );

        final plain = resolveLedger(
          component: ComponentColors.palette(
            ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(200, 10, 20),
            ),
          ),
          facts: const ColorDetectionFacts(
            outputProfile: OutputProfile(colorDepth: ColorDepth.none),
          ),
        );
        expect(
          terminalStyledText(
            'ready',
            foreground: plain.palette.foreground,
            background: plain.palette.background,
            depth: plain.outputProfile.colorDepth,
          ),
          'ready',
        );
      },
    );
  });

  group('Ledger components rendered through the internal seam', () {
    OutputProfile profile({
      bool ascii = false,
      ColorDepth depth = ColorDepth.rgb,
      int columns = 80,
    }) => OutputProfile(
      cursor: CapabilitySupport.supported,
      styles: CapabilitySupport.supported,
      colorDepth: depth,
      glyphs: ascii ? GlyphSet.ascii : GlyphSet.unicode,
      geometry: OutputGeometry.fixed(columns: columns, rows: 24),
    );

    LedgerAdaptiveTheme theme(
      StringSink out, {
      required String input,
      required BackgroundPreference background,
      bool ascii = false,
      ColorDepth depth = ColorDepth.rgb,
      int columns = 80,
      Map<String, String?> environment = const <String, String?>{},
      ComponentColors component = const ComponentColors(),
    }) => LedgerAdaptiveTheme(
      io: TerminalEnvironment.scripted(
        input: Stream.value(input),
        output: out,
        profile: profile(ascii: ascii, depth: depth, columns: columns),
        environment: environment,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      colors: ColorPreferences(background: background),
      component: component,
    );

    List<String> visible(String text) => [
      for (final line
          in text
              .replaceAll(RegExp(r'\x1b\[[0-9;?]*[ -/]*[@-~]'), '')
              .split(RegExp(r'[\r\n]')))
        if (line.isNotEmpty) line,
    ];

    test(
      'a real text input keeps the numbered ledger grammar in light sepia',
      () async {
        final out = StringBuffer();
        final result = await theme(
          out,
          input: 'Ada\r',
          background: BackgroundPreference.light,
        ).promptTextInput('Project name');

        expect((result as Accepted<String>).value, 'Ada');
        final lines = visible(out.toString());
        expect(lines.first, startsWith('01 / Project name'));
        expect(
          lines.where((line) => RegExp(r'^[·]+$').hasMatch(line)),
          isNotEmpty,
          reason: 'the dotted rule is drawn',
        );
        expect(
          lines.where((line) => line.startsWith('   ') && line.isNotEmpty),
          isNotEmpty,
          reason: 'answers are indented',
        );
        expect(
          lines.where((line) => line.contains('note:')),
          isNotEmpty,
          reason: 'the compact hint is a note',
        );
        expect(out.toString(), contains('\x1b[38;2;66;57;47;49m'));
        expect(
          out.toString(),
          isNot(contains('48;2')),
          reason: 'the terminal surface is never painted',
        );
      },
    );

    test(
      'a real choice renders the dark sepia palette and its default marker',
      () async {
        final out = StringBuffer();
        final result =
            await theme(
              out,
              input: '1\r',
              background: BackgroundPreference.dark,
            ).promptSelect<String>('Choose feature', [
              Choice('a', 'Starter'),
              Choice('b', 'Library'),
            ], defaultValue: 'a');

        expect((result as Accepted<String>).value, 'a');
        final lines = visible(out.toString());
        expect(lines.first, startsWith('01 / Choose feature'));
        expect(lines.join(' '), contains('Starter'));
        expect(lines.join(' '), contains('[default]'));
        expect(lines.join(' '), contains('[focused]'));
        expect(lines.join(' '), contains('note:'));
        expect(lines.join(' '), contains('Accepted: Starter.'));
        expect(out.toString(), contains('\x1b[38;2;243;233;216;49m'));
        expect(out.toString(), isNot(contains('48;2')));
      },
    );

    test(
      'both real components use their variant palette and Ledger grammar',
      () async {
        for (final variant in BackgroundVariant.values) {
          final background = variant == BackgroundVariant.light
              ? BackgroundPreference.light
              : BackgroundPreference.dark;
          final expectedForeground = variant == BackgroundVariant.light
              ? '\x1b[38;2;66;57;47;49m'
              : '\x1b[38;2;243;233;216;49m';

          final textOut = StringBuffer();
          final text = await theme(
            textOut,
            input: 'Ada\r',
            background: background,
          ).promptTextInput('Project name');
          expect(text, isA<Accepted<String>>(), reason: 'text/$variant');
          expect(textOut.toString(), contains(expectedForeground));

          final choiceOut = StringBuffer();
          final choice = await theme(
            choiceOut,
            input: '1\r',
            background: background,
          ).promptSelect<String>('Feature', [Choice('a', 'Starter')]);
          expect(choice, isA<Accepted<String>>(), reason: 'choice/$variant');
          expect(choiceOut.toString(), contains(expectedForeground));
          for (final output in [textOut.toString(), choiceOut.toString()]) {
            final lines = visible(output);
            expect(lines.first, startsWith('01 / '), reason: '$variant');
            expect(
              lines.where((line) => RegExp(r'^[·]+$').hasMatch(line)),
              isNotEmpty,
              reason: 'dotted rule for $variant',
            );
            expect(output, contains('note:'), reason: 'hint for $variant');
            expect(
              output,
              isNot(contains('48;2')),
              reason: 'surface for $variant',
            );
          }
        }
      },
    );

    test(
      'ASCII and narrow geometry keep the ledger grammar without clipping',
      () async {
        final out = StringBuffer();
        final result = await theme(
          out,
          input: 'Ada\r',
          background: BackgroundPreference.dark,
          ascii: true,
          columns: 24,
        ).promptTextInput('Deploy target');

        expect((result as Accepted<String>).value, 'Ada');
        final lines = visible(out.toString());
        expect(lines.first, startsWith('01 / '));
        expect(
          lines.where((line) => RegExp(r'^[.]+$').hasMatch(line)),
          isNotEmpty,
          reason: 'the ASCII dotted rule is drawn',
        );
        expect(
          lines.join(' '),
          contains('note:'),
          reason: 'the compact help route stays visible',
        );
        for (final line in lines) {
          expect(line.length, lessThanOrEqualTo(24), reason: '"$line"');
        }
      },
    );

    test(
      'NO_COLOR and a component palette still render an unstyled ledger',
      () async {
        final out = StringBuffer();
        final result = await theme(
          out,
          input: 'Ada\r',
          background: BackgroundPreference.light,
          environment: const {'NO_COLOR': '1'},
          component: ComponentColors.palette(
            ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(200, 10, 20),
            ),
          ),
        ).promptTextInput('Project name');

        expect((result as Accepted<String>).value, 'Ada');
        final text = out.toString();
        expect(text, isNot(contains('\x1b[38;2')));
        expect(text, isNot(contains('48;2')));
        expect(visible(text).first, startsWith('01 / Project name'));
      },
    );

    test(
      'an explicit component palette overrides the Ledger default',
      () async {
        final out = StringBuffer();
        await theme(
          out,
          input: 'Ada\r',
          background: BackgroundPreference.dark,
          component: ComponentColors.palette(
            ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(9, 8, 7),
            ),
          ),
        ).promptTextInput('Project name');

        expect(out.toString(), contains('\x1b[38;2;9;8;7;49m'));
        expect(out.toString(), isNot(contains('\x1b[38;2;243;233;216;49m')));
      },
    );

    test(
      'explicit terminalDefault at component scope emits no colour request',
      () async {
        final out = StringBuffer();
        await theme(
          out,
          input: 'Ada\r',
          background: BackgroundPreference.light,
          component: ComponentColors.palette(ColorThemes.terminalDefault),
        ).promptTextInput('Project name');

        expect(out.toString(), isNot(contains('\x1b[38;2')));
        expect(out.toString(), isNot(contains('48;2')));
        expect(visible(out.toString()).first, startsWith('01 / Project name'));
      },
    );

    test(
      'a component palette cannot change the theme-owned background',
      () async {
        final out = StringBuffer();
        await theme(
          out,
          input: 'Ada\r',
          background: BackgroundPreference.dark,
          component: ComponentColors(
            lightPalette: ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(1, 2, 3),
            ),
          ),
        ).promptTextInput('Project name');

        expect(out.toString(), contains('\x1b[38;2;243;233;216;49m'));
        expect(out.toString(), isNot(contains('\x1b[38;2;1;2;3;49m')));
      },
    );
  });

  group('Ledger state vocabulary and compact help', () {
    test(
      'focus, selection and default stay independent in both glyph sets',
      () {
        final focusedSelected = ChoicePresentation(
          label: 'Starter',
          focused: true,
          selected: true,
        );
        final defaultUnselected = ChoicePresentation(
          label: 'Library',
          isDefault: true,
          selected: false,
        );

        final unicodeFocus = renderChoiceRow(focusedSelected);
        final unicodeDefault = renderChoiceRow(defaultUnselected);
        expect(unicodeFocus, contains('●'));
        expect(unicodeFocus, contains('→'));
        expect(unicodeFocus, isNot(contains('★')));
        expect(unicodeDefault, contains('○'));
        expect(unicodeDefault, contains('★'));
        expect(unicodeDefault, isNot(contains('→')));

        final asciiFocus = renderChoiceRow(
          focusedSelected,
          glyphs: StateGlyphs.ascii,
        );
        final asciiDefault = renderChoiceRow(
          defaultUnselected,
          glyphs: StateGlyphs.ascii,
        );
        expect(asciiFocus, contains('(*)'));
        expect(asciiFocus, contains(r'> '));
        expect(asciiDefault, contains('( )'));
        expect(asciiDefault, contains('D'));
        expect(asciiFocus, isNot(contains('D ')));
      },
    );

    test('narrow Ledger rows keep markers atomic and wrap the label', () {
      final row = ChoicePresentation(
        label: 'A deliberately long choice label',
        focused: true,
        checked: false,
        isDefault: true,
      );
      final rendered = renderChoiceRow(
        row,
        glyphs: StateGlyphs.ascii,
        width: 16,
      );
      expect(rendered.split('\n').length, greaterThan(1));
      expect(rendered, contains('>'));
      expect(rendered, contains('-'));
      expect(rendered, contains('D'));
      for (final line in rendered.split('\n')) {
        expect(line, isNot(matches(RegExp(r'[>\-D]\S'))));
      }

      final heading = structureStageHeading(
        PromptStructure.ledger,
        1,
        'Choose feature',
        ascii: true,
      );
      final framed = [
        ...frameHeadingLines(
          PromptStructure.ledger,
          ascii: true,
          lines: [heading],
        ),
        for (final line in rendered.split('\n')) '   $line',
      ];
      expect(framed.first, startsWith('01 / '));
      expect(framed.skip(1).every((line) => line.startsWith('   ')), isTrue);
    });

    test(
      'status labels carry a symbol and readable text in both glyph sets',
      () {
        for (final glyphs in StateGlyphs.values) {
          final success = renderStatus(Status.success, 'Saved', glyphs: glyphs);
          final warning = renderStatus(Status.warning, 'Slow', glyphs: glyphs);
          final error = renderStatus(Status.error, 'Failed', glyphs: glyphs);
          for (final status in [success, warning, error]) {
            expect(status, contains(':'));
          }
          expect(success, contains('Success'));
          expect(warning, contains('Warning'));
          expect(error, contains('Error'));
          expect(
            success.startsWith(glyphs == StateGlyphs.unicode ? '✓' : '+'),
            isTrue,
          );
          expect(
            error.startsWith(glyphs == StateGlyphs.unicode ? '×' : 'x'),
            isTrue,
          );
        }
      },
    );

    test('the mandatory hint changes placement with the presentation mode', () {
      PromptPresentation presentation(PresentationMode mode) =>
          composePromptPresentation(
            mode: mode,
            prompt: '01 / Project name',
            essential: 'Project name entry.',
            hint: compactHint(
              mode: mode,
              component: ComponentRoute.standard,
              primaryAction: 'Enter submits',
              shortPrimaryAction: 'Enter',
            ),
          );

      final rich = presentation(PresentationMode.rich);
      final linear = presentation(PresentationMode.linear);
      final reader = presentation(PresentationMode.screenReader);
      expect(rich.placement, HintPlacement.richBottom);
      expect(rich.footer, contains('Ctrl+T opens help.'));
      final short = composePromptPresentation(
        mode: PresentationMode.rich,
        prompt: '01 / Project name',
        essential: 'Project name entry.',
        hint: compactHint(
          mode: PresentationMode.rich,
          component: ComponentRoute.standard,
          primaryAction: 'Enter submits',
          shortPrimaryAction: 'Enter',
        ),
        availableRows: 2,
      );
      expect(short.footer, contains('Ctrl+T help'));
      expect(linear.placement, HintPlacement.linearAfter);
      expect(linear.lines.last, contains('/help'));
      expect(reader.placement, HintPlacement.screenReaderBefore);
      expect(reader.essentialBefore, contains('Project name entry.'));
      expect(reader.essentialBefore, contains('/help'));
      expect(reader.lines.first, reader.essentialBefore);
    });
  });
}
