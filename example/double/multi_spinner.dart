import 'dart:async';

import 'package:trelis/trelis.dart';

/// MultiSpinner — one component, one structural theme (DoubleTheme),

/// one colour theme (ColorThemes.lavender).

///

/// Run: dart run example/double/multi_spinner.dart

Future<void> main(List<String> arguments) async {
  final theme = DoubleTheme(
    interaction: const InteractionPreferences(mode: PromptMode.automatic),
  );

  final tasks = await theme
      .multiSpinner(
        const ['Download', 'Compile', 'Package'],

        interval: Duration.zero,

        colors: ComponentColors.palette(ColorThemes.lavender),
      )
      .start();

  await tasks.runAll({
    'Download': () => Future<void>.delayed(const Duration(seconds: 2)),
    'Compile': () => Future<void>.delayed(const Duration(seconds: 4)),
    'Package': () => Future<void>.delayed(const Duration(seconds: 6)),
  });
  await tasks.stop();
}
