// ignore_for_file: avoid_print

import 'package:trelis/trelis.dart';

/// Demonstrates Ledger's adaptive theme-instance defaults and a separate
/// whole-palette component override through the public API.
///
/// Run: dart run example/ledger_theme_example.dart

Future<void> _show(
  String title, {
  required ColorPreferences colors,
  ComponentColors component = const ComponentColors(),
}) async {
  final output = StringBuffer();
  final theme = LedgerTheme(
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
  print('$title: ${result.runtimeType}');
  print('rendered: ${output.toString().split('\n').first}');
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

  final explicit = ColorThemes.terminalDefault.copyWith(
    foreground: TerminalColor.rgb(40, 45, 50),
    accent: TerminalColor.rgb(32, 92, 197),
  );
  await _show(
    'Explicit component palette',
    colors: const ColorPreferences(background: BackgroundPreference.dark),
    component: ComponentColors.palette(explicit),
  );
}
