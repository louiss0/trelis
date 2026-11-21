import 'dart:io';

import 'package:trelis/trelis.dart';

/// Demonstrates Bracket theme instances with pinned and explicit palettes.
///
/// Run: dart example/bracket_theme_example.dart
///
/// A scripted environment makes the example runnable without a terminal. A
/// real application omits the background preference so the theme owner selects
/// the authored light or dark default. Feedback is explicitly finished; the
/// theme restores the terminal when its final participant ends.
Future<void> _show({
  required String title,
  required BackgroundPreference background,
  ComponentColors component = const ComponentColors(),
}) async {
  stdout.writeln('\n$title');
  final theme = BracketTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value('Ada\r'),
      output: stdout,
    ),
    colors: ColorPreferences(background: background),
    interaction: const InteractionPreferences(mode: PromptMode.linear),
  );
  final result = await theme
      .textInput('Project name', colors: component)
      .prompt();
  stdout.writeln(
    result is Accepted<String>
        ? 'Accepted: ${result.value}'
        : 'Stopped: ${result.runtimeType}',
  );
}

Future<void> main() async {
  await _show(
    title: 'Authored light default (Atelier Sepia direction, rust accent)',
    background: BackgroundPreference.light,
  );
  await _show(
    title: 'Authored dark default (warm ink, rust accent)',
    background: BackgroundPreference.dark,
  );
  await _show(
    title: 'Explicit component palette replacement',
    background: BackgroundPreference.light,
    component: ComponentColors.palette(ColorThemes.paper),
  );

  final theme = BracketTheme(
    io: TerminalEnvironment.scripted(
      input: const Stream<String>.empty(),
      output: stdout,
    ),
  );
  await theme.text('Work complete', kind: TextKind.success).present();
  stdout.writeln('Feedback presented.');
}
