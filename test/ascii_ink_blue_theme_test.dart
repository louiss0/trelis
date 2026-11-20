import 'dart:async';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/ascii_ink_blue_theme.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/text_measurement.dart';
import 'package:trelis/trelis.dart';

/// Behavioral coverage for the internal Ascii presentation seam.
///
/// Reference backgrounds are documented in the generated palette source:
/// light #FAF8F3 (Atelier Sepia direction), dark #191C26 (warm ink).
void main() {
  group('adaptive defaults', () {
    test(
      'a light ascii text input renders the authored ink-blue palette',
      () async {
        final text = await renderText(
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
        );

        expect(text, contains('${fg([47, 53, 66])}? PROJECT NAME'));
        expect(text, contains('${fg([90, 96, 112])}  -- Left/Right move'));
        expect(text, contains('/help opens help.'));
        expect(text, contains('backslash'));
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
            contains('${fg([236, 232, 222])}? PROJECT NAME'),
            reason: '$colors selects the dark default',
          );
          expect(text, contains('${fg([180, 184, 197])}  -- Left/Right move'));
          expect(text, isNot(contains('\x1b[48;2')));
        }
      },
    );

    test(
      'explicit choice wins and injected facts reach a real rendering',
      () async {
        final profile = _profile();
        final explicit = await renderText(
          colors: const ColorPreferences(
            background: BackgroundPreference.light,
          ),
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

        expect(explicit, contains('${fg([47, 53, 66])}? PROJECT NAME'));
        expect(queried, contains('${fg([47, 53, 66])}? PROJECT NAME'));
        expect(passive, contains('${fg([47, 53, 66])}? PROJECT NAME'));
      },
    );

    test('authored normal-text roles meet the 4.5:1 reference target in both '
        'variants', () {
      final variants = [
        (
          name: 'light',
          palette: AsciiAdaptivePalettes.light,
          reference: AsciiAdaptivePalettes.lightReference,
          hex: AsciiAdaptivePalettes.lightReferenceHex,
        ),
        (
          name: 'dark',
          palette: AsciiAdaptivePalettes.dark,
          reference: AsciiAdaptivePalettes.darkReference,
          hex: AsciiAdaptivePalettes.darkReferenceHex,
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

AsciiInkBlueTheme asciiTheme(
  StringSink output,
  String input, {
  OutputProfile? profile,
  Map<String, String?> environment = const {},
  ColorPreferences colors = const ColorPreferences(),
  ColorDetectionFacts? colorFacts,
}) {
  final selected = profile ?? _profile();
  return AsciiInkBlueTheme(
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
  final theme = asciiTheme(
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
