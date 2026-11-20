import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/ascii_ink_blue_theme.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
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

String fg(List<int> rgb) => '\x1b[38;2;${rgb.join(';')};49m';
