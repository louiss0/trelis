import 'dart:async';

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/plain_adaptive_presentation.dart';
import 'package:trelis/trelis.dart';

/// Internal pre-cutover example for Plain's adaptive presentation.
///
/// This deliberately imports the internal seam: the static [PlainTheme]
/// factories keep their terminal-default behaviour until the coordinated public
/// cutover. Ticket 32 moves these calls onto theme instances; neither this
/// example nor the internal seam is a stable public API.
///
/// Run: dart example/plain_adaptive_example.dart
Future<void> main() async {
  const facts = ColorDetectionFacts(
    outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
  );

  for (final background in [
    BackgroundPreference.light,
    BackgroundPreference.dark,
  ]) {
    final presentation = PlainAdaptivePresentation(
      io: TerminalEnvironment.scripted(
        input: const Stream<String>.empty(),
        output: StringBuffer(),
      ),
      colors: ColorPreferences(background: background),
    );
    final resolved = presentation.resolve(facts: facts);
    print(
      '$background default foreground: '
      '${terminalSgr(resolved.palette.foreground, background: false, depth: ColorDepth.rgb)}',
    );
  }

  final output = StringBuffer();
  final presentation = PlainAdaptivePresentation(
    io: TerminalEnvironment.scripted(
      input: Stream.value('Ada\r'),
      output: output,
      profile: const OutputProfile(colorDepth: ColorDepth.rgb),
    ),
    colors: const ColorPreferences(background: BackgroundPreference.light),
    interaction: const InteractionPreferences(mode: PromptMode.linear),
  );

  // A whole component palette replaces the adaptive default for this call.
  final explicit = ComponentColors.palette(
    ColorThemes.terminalDefault.copyWith(
      foreground: TerminalColor.rgb(9, 8, 7),
    ),
  );
  final result = await presentation.textInput(
    'Project name',
    instructions: InstructionDisplay.hidden,
    colors: explicit,
  );

  print(
    'explicit override foreground: '
    '${terminalSgr(explicit.palette!.foreground, background: false, depth: ColorDepth.rgb)}',
  );
  print('answer: ${(result as Accepted<String>).value}');
  print('rendered: ${output.toString().split('\n').first}');
}
