// Demonstrates Block's adaptive light and dark defaults and a separate explicit
// colour override through the internal pre-cutover seam. The public
// BlockTheme factories stay unchanged until the coordinated API cutover; their
// current example palettes are not the adaptive defaults shown here.
//
// Run: dart run example/block_theme_example.dart

import 'dart:async';

import 'package:trelis/src/block_theme_presentation.dart';
import 'package:trelis/trelis.dart';

final _profile = OutputProfile(
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 72, rows: 20),
);

Future<void> _show(
  String title,
  BackgroundPreference background, {
  ComponentColors component = const ComponentColors(),
}) async {
  final output = StringBuffer();
  final theme = BlockThemePresentation(
    io: TerminalEnvironment.scripted(
      input: Stream.value('Ada\r'),
      output: output,
      profile: _profile,
    ),
    interaction: const InteractionPreferences(mode: PromptMode.linear),
    colors: ColorPreferences(background: background),
  );

  final result = await theme.textInput('Project name', colors: component);
  print('$title: $result');
  print(output.toString().replaceAll('\x1b', r'\e'));
}

Future<void> main() async {
  await _show('Adaptive light default', BackgroundPreference.light);
  await _show('Adaptive dark default', BackgroundPreference.dark);

  final custom = ColorThemes.terminalDefault.copyWith(
    foreground: TerminalColor.rgb(255, 190, 80),
    accent: TerminalColor.rgb(255, 120, 60),
  );
  await _show(
    'Explicit component override',
    BackgroundPreference.dark,
    component: ComponentColors.palette(custom),
  );
}
