import 'dart:async';
import 'dart:io';

import 'package:trelis/trelis.dart';

/// Demonstrates Ascii's adaptive theme-instance defaults and an explicit
/// component override through the public API. Scripted I/O keeps the example
/// runnable without a terminal.
///
/// Run: dart run example/ascii_adaptive_theme_example.dart
Future<void> main() async {
  final profile = OutputProfile(
    colorDepth: ColorDepth.rgb,
    glyphs: GlyphSet.ascii,
    geometry: OutputGeometry.fixed(columns: 60, rows: 20),
  );
  final interaction = const InteractionPreferences(mode: PromptMode.linear);
  const lightColors = ColorPreferences(background: BackgroundPreference.light);

  final adaptiveOutput = StringBuffer();
  final adaptive = AsciiTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value('Ada\r'),
      output: adaptiveOutput,
      profile: profile,
    ),
    interaction: interaction,
    colors: lightColors,
  );
  final adaptiveResult = await adaptive.textInput('Project name').prompt();
  final adaptiveText = adaptiveOutput.toString();

  final overrideOutput = StringBuffer();
  final explicit = AsciiTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value('Ada\r'),
      output: overrideOutput,
      profile: profile,
    ),
    interaction: interaction,
    colors: const ColorPreferences(background: BackgroundPreference.dark),
  );
  final overrideResult = await explicit
      .textInput(
        'Project name',
        colors: ComponentColors.palette(ColorThemes.terminalDefault),
      )
      .prompt();
  final overrideText = overrideOutput.toString();

  stderr.writeln('Adaptive light answer: ${adaptiveResult.runtimeType}');
  stderr.writeln(
    'Reference background: #FAF8F3 '
    '(documentation only, never painted)',
  );
  stderr.writeln(
    'Light default palette applied: '
    '${adaptiveText.contains('\x1b[38;2;47;53;66;49m')}',
  );
  stderr.writeln(
    'Explicit terminalDefault answer: ${overrideResult.runtimeType}',
  );
  stderr.writeln(
    'Explicit palette suppressed colour: '
    '${!overrideText.contains('\x1b[38;')}',
  );
}
