// ignore_for_file: avoid_print

import 'dart:io';

import 'package:trelis/trelis.dart';

/// Demonstrates Plain's adaptive defaults and a whole-palette component
/// override through the public theme-instance API.
///
/// Run: dart run example/plain_adaptive_example.dart

Future<void> _show(
  String title, {
  required ColorPreferences colors,
  ComponentColors component = const ComponentColors(),
}) async {
  final output = StringBuffer();
  final theme = PlainTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value('Ada\r'),
      output: output,
      profile: const OutputProfile(colorDepth: ColorDepth.rgb),
    ),
    interaction: const InteractionPreferences(mode: PromptMode.linear),
    colors: colors,
  );

  final result = await theme
      .textInput('Project name', colors: component)
      .prompt();
  stderr.writeln('$title: ${result.runtimeType}');
  stderr.writeln('rendered: ${output.toString().split('\n').first}');
}

Future<void> main() async {
  await _show(
    'Light default',
    colors: const ColorPreferences(background: BackgroundPreference.light),
  );
  await _show(
    'Dark default',
    colors: const ColorPreferences(background: BackgroundPreference.dark),
  );
  await _show(
    'Explicit component palette',
    colors: const ColorPreferences(background: BackgroundPreference.dark),
    component: ComponentColors.palette(
      ColorThemes.terminalDefault.copyWith(
        foreground: TerminalColor.rgb(9, 8, 7),
      ),
    ),
  );
}
