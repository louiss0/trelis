import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/state_help_presentation.dart';
import 'package:trelis/src/themes/form_presentation.dart';
import 'package:trelis/trelis.dart';

/// Independent authored values for the Form adaptive defaults.
///
/// These literals are the review fixture: the implementation must match them,
/// and the contrast maths below uses these numbers rather than asking the
/// palette to describe its own suitability.
const Map<String, List<int>> _light = {
  'foreground': [49, 39, 31],
  'muted': [92, 76, 62],
  'accent': [133, 76, 24],
  'selectionForeground': [255, 252, 246],
  'selectionBackground': [115, 66, 20],
  'success': [24, 88, 56],
  'warning': [124, 72, 10],
  'error': [145, 38, 38],
  'border': [101, 84, 68],
};

const Map<String, List<int>> _dark = {
  'foreground': [242, 233, 218],
  'muted': [185, 169, 150],
  'accent': [218, 163, 101],
  'selectionForeground': [32, 27, 22],
  'selectionBackground': [218, 163, 101],
  'success': [140, 205, 158],
  'warning': [232, 181, 105],
  'error': [246, 141, 132],
  'border': [158, 139, 119],
};

const Map<BackgroundVariant, List<int>> _referenceBackground = {
  BackgroundVariant.light: [243, 236, 221],
  BackgroundVariant.dark: [34, 29, 25],
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
  group('Form adaptive defaults', () {
    test('light and dark defaults are distinct warm-ink sepia palettes', () {
      expect(
        FormPresentation.lightDefault,
        isNot(FormPresentation.darkDefault),
      );
      expect(
        FormPresentation.referenceBackground(BackgroundVariant.light),
        TerminalColor.rgb(243, 236, 221),
      );
      expect(
        FormPresentation.referenceBackground(BackgroundVariant.dark),
        TerminalColor.rgb(34, 29, 25),
      );
      for (final entry in _light.entries) {
        expect(
          _actual(entry.key, FormPresentation.lightDefault),
          _expected(entry.key, BackgroundVariant.light),
          reason: 'light ${entry.key}',
        );
      }
      for (final entry in _dark.entries) {
        expect(
          _actual(entry.key, FormPresentation.darkDefault),
          _expected(entry.key, BackgroundVariant.dark),
          reason: 'dark ${entry.key}',
        );
      }
      expect(
        FormPresentation.lightDefault.background,
        TerminalColor.terminalDefault(),
      );
      expect(
        FormPresentation.darkDefault.background,
        TerminalColor.terminalDefault(),
      );
      expect(FormPresentation.structure, PromptStructure.form);
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
        lightDefault: FormPresentation.lightDefault,
        darkDefault: FormPresentation.darkDefault,
      );
      final explicit = resolveColors(
        facts: const ColorDetectionFacts(
          passiveBackground: BackgroundObservation.dark,
        ),
        lightDefault: FormPresentation.lightDefault,
        darkDefault: FormPresentation.darkDefault,
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
        ),
      );

      expect(unknown.background, BackgroundVariant.dark);
      expect(unknown.palette, FormPresentation.darkDefault);
      expect(explicit.background, BackgroundVariant.light);
      expect(explicit.palette, FormPresentation.lightDefault);
    });
  });

  group('Form text input through the internal seam', () {
    for (final variant in BackgroundVariant.values) {
      final isLight = variant == BackgroundVariant.light;
      final foreground = isLight ? '49;39;31' : '242;233;218';

      test('$variant palette styles a real Form text input', () async {
        final output = StringBuffer();
        final tracer = FormPresentationTracer(
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
        expect(text, contains('PROJECT NAME'));
        expect(text, contains('\x1b[38;2;$foreground;49m'));
        expect(text, contains('\x1b[38;2;'));
        // A Form field keeps an uppercase label, a rule and a left edge.
        final lines = _visibleLines(text);
        expect(lines.first, startsWith('PROJECT NAME'));
        expect(lines.first, lines.first.toUpperCase());
        expect(lines[1].split('').every((char) => char == '─'), isTrue);
        expect(lines.skip(2).any((line) => line.startsWith('│ ')), isTrue);
        expect(text, contains('Enter submits'));
        expect(text, contains('Ctrl+T opens help.'));
        expect(
          lines.indexWhere((line) => line.startsWith('  Left/Right move')),
          greaterThan(1),
          reason: 'the hint follows the uppercase heading and rule',
        );
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
        expect(text, isNot(contains('\x1b[2J')));
      });
    }
  });

  group('Form choices through the internal seam', () {
    test(
      'a real light choice keeps the ruled field and independent markers',
      () async {
        final text = await _renderChoice(
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
        );

        expect(text, contains('\x1b[38;2;49;39;31;49mPICK TOOLS'));
        expect(text, contains('\x1b[38;2;101;84;68;49m────'));
        expect(text, contains('\x1b[38;2;133;76;24;49m│ 1. Starter'));
        expect(text, contains('[unchecked] [focused]'));
        expect(text, contains('[checked] [default]'));
        expect(text, contains('Unavailable: needs owner role.'));

        final plain = _renderedPromptText(text);
        expect(plain.indexOf('PICK TOOLS'), lessThan(plain.indexOf('──')));
        expect(plain.indexOf('──'), lessThan(plain.indexOf('Starter')));
        expect(
          plain.indexOf('Starter'),
          lessThan(plain.indexOf('Enter submits')),
        );
        expect(
          plain.indexOf('Enter submits'),
          lessThan(plain.indexOf('Ctrl+T help')),
        );
        for (final enclosure in ['┌', '┐', '└', '┘', '╭', '╮', '╰', '╯']) {
          expect(text, isNot(contains(enclosure)));
        }
        expect(text, isNot(contains('\x1b[48;2;')));
      },
    );

    test(
      'a real dark choice renders sepia focus, checked, default and reasons',
      () async {
        final text = await _renderChoice(
          colors: const ColorPreferences(background: BackgroundPreference.dark),
        );

        expect(text, contains('\x1b[38;2;242;233;218;49mPICK TOOLS'));
        expect(text, contains('\x1b[38;2;158;139;119;49m────'));
        expect(text, contains('\x1b[38;2;218;163;101;49m│ 1. Starter'));
        expect(text, contains('[unchecked] [focused]'));
        expect(text, contains('[checked] [default]'));
        expect(text, contains('[unavailable: needs owner role]'));
        expect(
          text,
          contains('\x1b[38;2;232;181;105;49m│ Unavailable: needs owner role.'),
        );
        expect(_renderedPromptText(text), contains('Ctrl+T help'));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
      },
    );
  });

  group('Form palette precedence through the internal seam', () {
    for (final variant in BackgroundVariant.values) {
      final isLight = variant == BackgroundVariant.light;
      final preference = isLight
          ? BackgroundPreference.light
          : BackgroundPreference.dark;
      final defaultAccent = isLight ? '133;76;24' : '218;163;101';
      final defaultForeground = isLight ? '49;39;31' : '242;233;218';

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

          expect(text, contains('\x1b[38;2;11;22;33;49mPICK TOOLS'));
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

        expect(text, contains('\x1b[38;2;99;88;77;49mPICK TOOLS'));
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
          expect(text, contains('PICK TOOLS'));
          expect(text, contains('Starter'));
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

      expect(text, contains('\x1b[38;2;49;39;31;49mPICK TOOLS'));
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

        expect(text, contains('Starter'));
        expect(text, contains('38;5;'));
        expect(text, isNot(contains('38;2;')));
        expect(text, isNot(contains('\x1b[48;5;')));
        expect(text, isNot(contains('\x1b[48;2;')));
      },
    );
  });

  group('Form ASCII, no-colour and narrow rendering', () {
    test(
      'ASCII no-colour narrow output keeps markers, rules and compact help',
      () async {
        final text = await _renderChoice(
          colors: ColorPreferences(
            background: BackgroundPreference.light,
            colors: ComponentColors.palette(ColorThemes.signal),
          ),
          profile: OutputProfile(
            cursor: CapabilitySupport.supported,
            colorDepth: ColorDepth.none,
            glyphs: GlyphSet.ascii,
            geometry: OutputGeometry.fixed(columns: 30, rows: 12),
          ),
        );

        final plain = _renderedPromptText(text);
        expect(plain, contains('PICK TOOLS'));
        final rule = _visibleLines(text).firstWhere(
          (line) => line.split('').every((c) => c == '-'),
          orElse: () => fail('the narrow field keeps its rule'),
        );
        expect(rule.length, lessThanOrEqualTo(30));
        expect(plain, contains('| 1. Starter [unchecked]'));
        expect(plain, contains('[focused]'));
        expect(plain, contains('[checked]'));
        expect(plain, contains('[default]'));
        expect(plain, contains('[unavailable: needs owner role]'));
        expect(
          plain,
          contains('| Unavailable:'),
          reason: 'the status keeps its text label even when it wraps',
        );
        expect(plain, contains('Enter submits'));
        expect(plain, contains('Ctrl+T help'));
        expect(text, isNot(contains('\x1b[38;2;')));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
        expect(text, isNot(contains('\x1b[2J')));
        for (final line in _visibleLines(text)) {
          expect(line, isNot(contains('…')));
          expect(line, isNot(contains('...')));
        }
      },
    );

    test(
      'a narrow ASCII text input keeps its uppercase field and help route',
      () async {
        final output = StringBuffer();
        final tracer = FormPresentationTracer(
          io: TerminalEnvironment.scripted(
            input: Stream.value('Ada\r'),
            output: output,
            profile: OutputProfile(
              cursor: CapabilitySupport.supported,
              colorDepth: ColorDepth.none,
              glyphs: GlyphSet.ascii,
              geometry: OutputGeometry.fixed(columns: 24, rows: 8),
            ),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
        );

        final result = await tracer.textInput('Project name');
        final text = output.toString();
        final plain = _renderedPromptText(text);

        expect((result as Accepted<String>).value, 'Ada');
        expect(plain, contains('PROJECT NAME'));
        final rule = _visibleLines(text).firstWhere(
          (line) => line.split('').every((c) => c == '-'),
          orElse: () => fail('the narrow field keeps its rule'),
        );
        expect(rule.length, lessThanOrEqualTo(24));
        expect(plain, contains('| Ada'));
        expect(plain, contains('Enter submits'));
        expect(plain, contains(RegExp(r'Ctrl\+\s*T')));
        expect(plain, contains('help'));
        expect(text, isNot(contains('\x1b[38;2;')));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
        expect(text, isNot(contains('\x1b[2J')));
      },
    );

    test('a screen-reader essential line precedes the Form prompt', () async {
      final output = StringBuffer();
      final tracer = FormPresentationTracer(
        io: TerminalEnvironment.scripted(
          input: Stream.value('Ada\r'),
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(
          mode: PromptMode.linear,
          screenReader: ScreenReaderPreference.on,
        ),
      );

      expect(
        (await tracer.textInput('Project name') as Accepted<String>).value,
        'Ada',
      );
      final text = output.toString();
      expect(
        text.indexOf('Project name entry.'),
        lessThan(text.indexOf('PROJECT NAME')),
      );
      expect(text, contains('Enter submits; /help opens help.'));
      expect(text, isNot(contains('\x1b[48;2;')));
    });
  });

  group('Form compact help placement', () {
    final glyphs = headingGlyphsFor(PromptStructure.form, ascii: false)!;
    final hint = compactHint(
      mode: PresentationMode.rich,
      component: ComponentRoute.standard,
      primaryAction: 'Enter submits',
      shortPrimaryAction: 'Enter',
    );

    test('the Form grammar keeps its uppercase label, rule and left edge', () {
      expect(glyphs.headingPrefix, isEmpty);
      expect(glyphs.uppercaseHeading, isTrue);
      expect(glyphs.ruleGlyph, '─');
      expect(glyphs.bodyIndent, '│ ');
      expect(glyphs.bodyMarker, '│ ');
      expect(glyphs.hintIndent, '  ');
      expect(
        headingGlyphsFor(PromptStructure.form, ascii: true)!.ruleGlyph,
        '-',
      );
      expect(
        headingGlyphsFor(PromptStructure.form, ascii: true)!.bodyIndent,
        '| ',
      );
      expect(glyphs.drawsRule, isTrue);
    });

    test('the hint closes the field in rich and linear presentations', () {
      final decoration = [glyphs.rule(12), '${glyphs.bodyMarker}Ada'];
      final rich = composePromptPresentation(
        mode: PresentationMode.rich,
        prompt: 'PROJECT NAME',
        essential: 'Project name entry.',
        hint: hint,
        decoration: decoration,
      );
      final linear = composePromptPresentation(
        mode: PresentationMode.linear,
        prompt: 'PROJECT NAME',
        essential: 'Project name entry.',
        hint: hint,
        decoration: decoration,
      );

      expect(rich.placement, HintPlacement.richBottom);
      expect(linear.placement, HintPlacement.linearAfter);
      for (final presentation in [rich, linear]) {
        expect(presentation.lines.first, 'PROJECT NAME');
        expect(presentation.lines.last, hint.text);
        expect(
          presentation.lines.indexOf(hint.text),
          greaterThan(presentation.lines.indexOf(decoration.last)),
        );
        expect(presentation.lines, contains(decoration.first));
        expect(presentation.lines, contains(decoration.last));
      }
    });

    test(
      'screen-reader essentials precede the Form field with a help route',
      () {
        final presentation = composePromptPresentation(
          mode: PresentationMode.screenReader,
          prompt: 'PROJECT NAME',
          essential: 'Project name entry.',
          hint: hint,
        );

        expect(presentation.placement, HintPlacement.screenReaderBefore);
        expect(
          presentation.essentialBefore,
          'Project name entry. ${hint.text}',
        );
        expect(presentation.essentialBefore, contains('Ctrl+T opens help'));
        expect(presentation.lines, [
          presentation.essentialBefore!,
          'PROJECT NAME',
        ]);
        expect(sequentialTranscript(presentation, response: 'Ada'), [
          presentation.essentialBefore!,
          'PROJECT NAME',
          'Ada',
        ]);
      },
    );

    test('short screens keep the compact route and drop only decoration', () {
      final presentation = composePromptPresentation(
        mode: PresentationMode.rich,
        prompt: 'PROJECT NAME',
        essential: 'Project name entry.',
        hint: hint,
        decoration: const ['────', '│ Ada', '!'],
        availableRows: 2,
      );

      expect(presentation.lines.last, hint.shortText);
      expect(presentation.lines.first, 'PROJECT NAME');
      expect(presentation.lines.join(), contains('Enter'));
      expect(presentation.lines.join(), contains('Ctrl+T help'));
      expect(presentation.lines, isNot(contains('!')));
    });
  });
}

List<String> _visibleLines(String text) => [
  for (final line in text.replaceAll('\r', '').split('\n'))
    if (line.isNotEmpty) line.replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), ''),
];

/// Strips style and repaint control so wrapped output can be inspected as the
/// sequential text a reader would receive, without adding line breaks inside a
/// wrapped word.
String _renderedPromptText(String text) => text
    .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '')
    .replaceAll('\r', '')
    .replaceAll('\n', '');

Future<String> _renderChoice({
  ColorPreferences colors = const ColorPreferences(),
  ComponentColors component = const ComponentColors(),
  Map<String, String?> environment = const <String, String>{},
  OutputProfile? profile,
}) async {
  final output = StringBuffer();
  final tracer = FormPresentationTracer(
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
