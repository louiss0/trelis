import 'package:trelis/trelis.dart';

/// Demonstrates the pre-cutover PlainTheme factories and named palettes.
///
/// Run: dart example/plain_theme_example.dart
///
/// The named palettes below are example choices, not Plain's defaults. Plain's
/// adaptive light/dark defaults and a separate explicit override are shown in
/// the internal pre-cutover example `plain_adaptive_example.dart`; the public
/// theme-instance cutover belongs to ticket 32.
///
/// The factories only configure components; [prompt], [present] or [start] are
/// called separately with the desired session/output configuration.
void main() async {
  // A named palette from the 45 existing theme directions.
  final signal = ColorThemes.signal;

  // Override one role while keeping every other role from the named palette.
  final patched = signal.copyWith(warning: TerminalColor.rgb(255, 190, 80));

  // Configure a TextInput through PlainTheme with a non-default palette,
  // compact instructions and application-specific help.
  final project = PlainTheme.textInput(
    'Project name',
    initialValue: 'trelis',
    required: true,
    colors: patched,
    instructions: InstructionDisplay.compact,
    supplementaryHelp: ['Use the name of your package.'],
  );

  // Configure a single-choice prompt.
  final template = PlainTheme.select<String>(
    'Choose a template',
    [
      Choice('starter', 'Starter'),
      Choice('library', 'Library'),
      Choice('workspace', 'Workspace'),
    ],
    defaultValue: 'starter',
    colors: ColorThemes.terminalDefault,
    instructions: InstructionDisplay.expanded,
  );

  // A feedback component with its own palette.
  final progress = PlainTheme.progress(
    'Installing dependencies',
    total: 10,
    colors: ColorThemes.workbench,
  );

  // In a real program, call await project.prompt() with a TerminalIo or
  // ScriptedInput. Here we only demonstrate that construction is output-free
  // and that every factory returns the correct concrete type.
  print('Configured:');
  print(
    '  project: ${project.label} (${project.colors.foreground == signal.foreground ? 'signal foreground' : 'other'})',
  );
  print(
    '  template: ${template.label} with ${template.choices.length} choices',
  );
  print('  progress: ${progress.label} (${progress.total} items)');
}
