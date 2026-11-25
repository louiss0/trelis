import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/state_help_presentation.dart';
import 'package:trelis/src/themes/minimal_presentation.dart';
import 'package:trelis/src/testing/compat_api.dart';

/// Independent authored values for the Minimal adaptive defaults.
///
/// These literals are the review fixture: the implementation must match them,
/// and the contrast maths below uses these numbers rather than asking the
/// palette to describe its own suitability.
const Map<String, List<int>> _light = {
  'foreground': [54, 43, 34],
  'muted': [96, 80, 68],
  'accent': [126, 72, 20],
  'selectionForeground': [255, 251, 244],
  'selectionBackground': [126, 72, 20],
  'success': [26, 92, 57],
  'warning': [128, 74, 8],
  'error': [150, 36, 40],
  'border': [112, 92, 74],
};

const Map<String, List<int>> _dark = {
  'foreground': [244, 236, 224],
  'muted': [190, 174, 156],
  'accent': [214, 158, 97],
  'selectionForeground': [30, 26, 22],
  'selectionBackground': [214, 158, 97],
  'success': [146, 210, 164],
  'warning': [238, 188, 112],
  'error': [250, 146, 138],
  'border': [158, 138, 118],
};

const Map<BackgroundVariant, List<int>> _referenceBackground = {
  BackgroundVariant.light: [245, 238, 225],
  BackgroundVariant.dark: [30, 26, 22],
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
  group('Minimal adaptive defaults', () {
    test('light and dark defaults are distinct warm-ink sepia palettes', () {
      expect(
        MinimalPresentation.lightDefault,
        isNot(MinimalPresentation.darkDefault),
      );
      expect(
        MinimalPresentation.referenceBackground(BackgroundVariant.light),
        TerminalColor.rgb(245, 238, 225),
      );
      expect(
        MinimalPresentation.referenceBackground(BackgroundVariant.dark),
        TerminalColor.rgb(30, 26, 22),
      );
      for (final entry in _light.entries) {
        expect(
          _actual(entry.key, MinimalPresentation.lightDefault),
          _expected(entry.key, BackgroundVariant.light),
          reason: 'light ${entry.key}',
        );
      }
      for (final entry in _dark.entries) {
        expect(
          _actual(entry.key, MinimalPresentation.darkDefault),
          _expected(entry.key, BackgroundVariant.dark),
          reason: 'dark ${entry.key}',
        );
      }
      expect(
        MinimalPresentation.lightDefault.background,
        TerminalColor.terminalDefault(),
      );
      expect(
        MinimalPresentation.darkDefault.background,
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
        lightDefault: MinimalPresentation.lightDefault,
        darkDefault: MinimalPresentation.darkDefault,
      );
      final explicit = resolveColors(
        facts: const ColorDetectionFacts(
          passiveBackground: BackgroundObservation.dark,
        ),
        lightDefault: MinimalPresentation.lightDefault,
        darkDefault: MinimalPresentation.darkDefault,
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
        ),
      );

      expect(unknown.background, BackgroundVariant.dark);
      expect(unknown.palette, MinimalPresentation.darkDefault);
      expect(explicit.background, BackgroundVariant.light);
      expect(explicit.palette, MinimalPresentation.lightDefault);
    });
  });

  group('Minimal text input through the internal seam', () {
    for (final variant in BackgroundVariant.values) {
      final isLight = variant == BackgroundVariant.light;
      final foreground = isLight ? '54;43;34' : '244;236;224';
      final muted = isLight ? '96;80;68' : '190;174;156';

      test(
        '$variant palette styles a real conversational text input',
        () async {
          final output = StringBuffer();
          final tracer = MinimalPresentationTracer(
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
          expect(text, contains('\x1b[38;2;$muted;49mLeft/Right move;'));
          expect(text, contains('Enter submits. F1 opens help.'));
          expect(text, contains('› '));
          expect(
            text.indexOf('Project name'),
            lessThan(text.indexOf('F1 opens help.')),
          );
          for (final enclosure in ['┌', '┐', '└', '┘', '╭', '╮', '╰', '╯']) {
            expect(text, isNot(contains(enclosure)));
          }
          expect(text, isNot(contains('──')));
          expect(text, isNot(contains('\x1b[48;2;')));
          expect(text, isNot(contains('\x1b[?1049h')));
          expect(text, isNot(contains('\x1b[2J')));
        },
      );
    }
  });

  group('Minimal choices through the internal seam', () {
    test(
      'a real light choice keeps the conversational rows and markers',
      () async {
        final text = await _renderChoice(
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
        );

        expect(text, contains('\x1b[38;2;54;43;34;49mPick tools'));
        expect(text, contains('\x1b[38;2;126;72;20;49m1. Starter'));
        expect(text, contains('[checked] [default]'));
        expect(text, contains('Unavailable: needs owner role.'));
        final plain = _renderedPromptText(text);
        expect(plain.indexOf('Pick tools'), lessThan(plain.indexOf('Starter')));
        expect(plain.indexOf('Starter'), lessThan(plain.indexOf('F1 help')));
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

        expect(text, contains('\x1b[38;2;244;236;224;49mPick tools'));
        expect(text, contains('\x1b[38;2;214;158;97;49m1. Starter'));
        expect(text, contains('[checked] [default]'));
        expect(text, contains('[unavailable: needs owner role]'));
        expect(
          text,
          contains('\x1b[38;2;238;188;112;49mUnavailable: needs owner role.'),
        );
        expect(_renderedPromptText(text), contains('F1 help'));
        expect(text, isNot(contains('\x1b[48;2;')));
        expect(text, isNot(contains('\x1b[?1049h')));
      },
    );
  });

  group('Minimal palette precedence through the internal seam', () {
    for (final variant in BackgroundVariant.values) {
      final isLight = variant == BackgroundVariant.light;
      final preference = isLight
          ? BackgroundPreference.light
          : BackgroundPreference.dark;
      final defaultAccent = isLight ? '126;72;20' : '214;158;97';
      final defaultForeground = isLight ? '54;43;34' : '244;236;224';

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
          expect(text, contains('\x1b[38;2;44;55;66;49m1. Starter'));
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
        expect(text, contains('\x1b[38;2;$expected;49m1. Starter'));
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
        expect(text, contains('\x1b[38;2;66;55;44;49m1. Starter'));
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
        expect(text, contains('\x1b[38;2;$expected;49m1. Starter'));
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
          expect(text, contains('Pick tools'));
          expect(text, contains('1. Starter'));
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

      expect(text, contains('\x1b[38;2;54;43;34;49mPick tools'));
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

        expect(text, contains('1. Starter'));
        expect(text, contains('38;5;'));
        expect(text, isNot(contains('38;2;')));
        expect(text, isNot(contains('\x1b[48;5;')));
        expect(text, isNot(contains('\x1b[48;2;')));
      },
    );
  });

  group('Minimal ASCII and no-colour rendering', () {
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
            glyphs: GlyphSet.ascii,
            geometry: OutputGeometry.fixed(columns: 30, rows: 12),
          ),
        );

        final plain = _renderedPromptText(text);
        expect(plain, contains('Pick tools'));
        expect(plain, contains('1. Starter [unchecked]'));
        expect(plain, contains('[focused]'));
        expect(plain, contains('[checked]'));
        expect(plain, contains('[default]'));
        expect(plain, contains('[unavailable: needs owner role]'));
        expect(plain, contains('Unavailable: needs owner role.'));
        expect(plain, contains('Enter submits'));
        expect(plain, contains('F1 help'));
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
      'a narrow ASCII text input keeps the live marker and help route',
      () async {
        final output = StringBuffer();
        final tracer = MinimalPresentationTracer(
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
        expect((result as Accepted<String>).value, 'Ada');
        expect(text, contains('> '));
        expect(_renderedPromptText(text), contains('Project name'));
        expect(_renderedPromptText(text), contains('Enter submits'));
        expect(_renderedPromptText(text), contains('F1 opens help'));
        expect(text, isNot(contains('\x1b[38;2;')));
        expect(text, isNot(contains('\x1b[48;2;')));
      },
    );
  });

  group('Minimal compact help placement', () {
    final glyphs = headingGlyphsFor(PromptStructure.minimal, ascii: false)!;
    final hint = compactHint(
      mode: PresentationMode.rich,
      component: ComponentRoute.standard,
      primaryAction: 'Enter submits',
      shortPrimaryAction: 'Enter',
    );

    test('the grammar keeps the question, body and hint unframed', () {
      expect(glyphs.headingPrefix, isEmpty);
      expect(glyphs.headingSuffix, isEmpty);
      expect(glyphs.bodyIndent, isEmpty);
      expect(glyphs.hintPrefix, isEmpty);
      expect(glyphs.bodyMarker, '› ');
      expect(
        headingGlyphsFor(PromptStructure.minimal, ascii: true)!.bodyMarker,
        '> ',
      );
      expect(glyphs.drawsRule, isFalse);
      expect(glyphs.drawsBand, isFalse);
    });

    test(
      'the hint closes rich and linear presentations without decoration',
      () {
        final rich = composePromptPresentation(
          mode: PresentationMode.rich,
          prompt: 'Pick tools',
          essential: 'Pick tools entry.',
          hint: hint,
        );
        final linear = composePromptPresentation(
          mode: PresentationMode.linear,
          prompt: 'Pick tools',
          essential: 'Pick tools entry.',
          hint: hint,
        );

        expect(rich.placement, HintPlacement.richBottom);
        expect(linear.placement, HintPlacement.linearAfter);
        for (final presentation in [rich, linear]) {
          expect(presentation.lines, ['Pick tools', hint.text]);
          expect(presentation.lines.last, hint.text);
          expect(presentation.lines.first, 'Pick tools');
        }
      },
    );

    test('screen-reader essentials precede the prompt with a help route', () {
      final presentation = composePromptPresentation(
        mode: PresentationMode.screenReader,
        prompt: 'Pick tools',
        essential: 'Pick tools entry.',
        hint: hint,
      );

      expect(presentation.placement, HintPlacement.screenReaderBefore);
      expect(presentation.essentialBefore, 'Pick tools entry. ${hint.text}');
      expect(presentation.essentialBefore, contains('F1 opens help'));
      expect(presentation.lines, [presentation.essentialBefore!, 'Pick tools']);
      expect(sequentialTranscript(presentation, response: 'b'), [
        presentation.essentialBefore!,
        'Pick tools',
        'b',
      ]);
    });

    test('short screens keep the compact route without inventing chrome', () {
      final presentation = composePromptPresentation(
        mode: PresentationMode.rich,
        prompt: 'Pick tools',
        essential: 'Pick tools entry.',
        hint: hint,
        decoration: const ['!'],
        availableRows: 2,
      );

      expect(presentation.lines, ['Pick tools', hint.shortText]);
      expect(presentation.lines.join(), contains('Enter'));
      expect(presentation.lines.join(), contains('F1 help'));
      expect(presentation.lines, isNot(contains('!')));
    });
  });
}

List<String> _visibleLines(String text) => [
  for (final line in text.replaceAll('\r', '').split('\n'))
    if (line.isNotEmpty) line.replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), ''),
];

/// Strips style and repaint control so wrapped output can be inspected as
/// the sequential text a reader would receive, without adding line breaks
/// inside a wrapped word.
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
  final tracer = MinimalPresentationTracer(
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
