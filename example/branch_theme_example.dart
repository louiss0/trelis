// ignore_for_file: avoid_print

import 'package:trelis/trelis.dart';

Future<void> main() async {
  await _show(
    'Branch light default',
    colors: const ColorPreferences(background: BackgroundPreference.light),
  );
  await _show(
    'Branch dark default',
    colors: const ColorPreferences(background: BackgroundPreference.dark),
  );

  final explicit = ColorThemes.terminalDefault.copyWith(
    foreground: TerminalColor.rgb(40, 35, 30),
    accent: TerminalColor.rgb(120, 40, 80),
  );
  await _show(
    'Branch with an explicit application palette',
    colors: ColorPreferences(
      background: BackgroundPreference.dark,
      colors: ComponentColors.palette(explicit),
    ),
  );
}

Future<void> _show(
  String title, {
  required ColorPreferences colors,
  ComponentColors component = const ComponentColors(),
}) async {
  final output = StringBuffer();
  final theme = BranchTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value('\r'),
      output: output,
      profile: OutputProfile(
        cursor: CapabilitySupport.supported,
        colorDepth: ColorDepth.rgb,
        geometry: OutputGeometry.fixed(columns: 60, rows: 12),
        glyphs: GlyphSet.unicode,
      ),
    ),
    colors: colors,

    interaction: const InteractionPreferences(mode: PromptMode.rich),
  );

  final result = await theme
      .select<String>(
        'Choose a feature',
        [Choice('starter', 'Starter'), Choice('library', 'Library')],
        defaultValue: 'starter',
        colors: component,
      )
      .prompt();
  final answer = result is Accepted<String> ? result.value : result.runtimeType;

  print(title);
  print('  answer: $answer');
  print(output.toString().replaceAll('\x1b', '<ESC>').trimRight());
}
