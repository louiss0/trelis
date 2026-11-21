import 'package:trelis/trelis.dart';

/// Demonstrates Plain theme instances and component-scoped colour overrides.
///
/// Run: dart example/plain_theme_example.dart
///
/// The palette passed to `textInput` is an explicit component override; the
/// theme's authored adaptive light/dark defaults apply when no override is
/// supplied. Themes release terminal resources after their last component.
Future<void> main() async {
  const script = ['trelis\r', 'starter\r', '3\r'];
  var chunk = 0;

  PlainTheme nextTheme() => PlainTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value(script[chunk++]),
      output: StringBuffer(),
    ),
  );

  final name = await nextTheme()
      .textInput(
        'Project name',
        required: true,
        initialValue: 'app',
        colors: ComponentColors.palette(ColorThemes.signal),
        instructions: InstructionDisplay.compact,
        supplementaryHelp: const ['Use the name of your package.'],
      )
      .prompt();
  final template = await nextTheme()
      .select<String>(
        'Choose a template',
        [Choice('starter', 'Starter'), Choice('library', 'Library')],
        defaultValue: 'starter',
        instructions: InstructionDisplay.expanded,
      )
      .prompt();
  final count = await nextTheme()
      .numberInput('Package count', minimum: '0', maximum: '10')
      .prompt();

  print('Project name: $name');
  print('Template: $template');
  print('Count: $count');
}
