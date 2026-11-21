import 'dart:async';
import 'dart:io';

import 'package:trelis/src/rail_ink_blue_theme.dart';
import 'package:trelis/trelis.dart';

/// Demonstrates Rail's internal adaptive defaults and an explicit override.
///
/// This imports an internal, unstable seam on purpose: the public component
/// cutover is a later ticket. `RailTheme` static factories remain the public
/// API here. The example uses scripted I/O so it runs without a terminal.
///
/// Run: dart run example/rail_adaptive_theme_example.dart
Future<void> main() async {
  final profile = OutputProfile(
    colorDepth: ColorDepth.rgb,
    glyphs: GlyphSet.ascii,
    geometry: OutputGeometry.fixed(columns: 60, rows: 20),
  );
  final interaction = const InteractionPreferences(mode: PromptMode.linear);
  const lightColors = ColorPreferences(background: BackgroundPreference.light);

  final adaptiveOutput = StringBuffer();
  final adaptive = RailInkBlueTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value('Ada\r'),
      output: adaptiveOutput,
      profile: profile,
    ),
    interaction: interaction,
    colors: lightColors,
  );
  final adaptiveResult = await adaptive.textInput('Project name');
  final adaptiveText = adaptiveOutput.toString();

  final overrideOutput = StringBuffer();
  final explicit = RailInkBlueTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value('Ada\r'),
      output: overrideOutput,
      profile: profile,
    ),
    interaction: interaction,
    colors: const ColorPreferences(background: BackgroundPreference.dark),
  );
  final overrideResult = await explicit.textInput(
    'Project name',
    colors: ComponentColors.palette(ColorThemes.terminalDefault),
  );
  final overrideText = overrideOutput.toString();

  stderr.writeln('Adaptive light answer: ${adaptiveResult.runtimeType}');
  stderr.writeln(
    'Reference background: ${RailAdaptivePalettes.lightReferenceHex} '
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
