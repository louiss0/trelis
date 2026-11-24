import 'dart:async';

import 'package:trelis/trelis.dart';

/// MultiSpinner — one component, one structural theme (BoxTheme),

/// one colour theme (ColorThemes.lavender).

///

/// Run: dart run example/box/multi_spinner.dart

Future<void> main(List<String> arguments) async {
  final theme = BoxTheme(
    interaction: const InteractionPreferences(mode: PromptMode.automatic),
  );

  final tasks = await theme
      .multiSpinner(
        const ['Download', 'Compile', 'Package'],

        interval: Duration.zero,

        colors: ComponentColors.palette(ColorThemes.lavender),
      )
      .start();

  await tasks.followAll({
    'Download': Stream.periodic(
      const Duration(milliseconds: 400),
      (count) => 'chunk ${count + 1}',
    ).take(5),
    'Compile': Stream.periodic(
      const Duration(milliseconds: 500),
      (count) => 'unit ${count + 1}',
    ).take(8),
    'Package': Stream.periodic(
      const Duration(milliseconds: 600),
      (count) => 'file ${count + 1}',
    ).take(10),
  });
}
