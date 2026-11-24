import 'dart:async';

import 'package:trelis/trelis.dart';

/// Spinner — one component, one structural theme (MinimalTheme),
/// one colour theme (ColorThemes.neonGrid).
///
/// Run: dart run example/minimal/spinner.dart
Future<void> main(List<String> arguments) async {
  final theme = MinimalTheme(
    interaction: const InteractionPreferences(mode: PromptMode.automatic),
  );
  final spinner = await theme
      .spinner(
        'Connecting',
        colors: ComponentColors.palette(ColorThemes.neonGrid),
      )
      .start();
  const phases = [
    'authenticating',
    'resolving routes',
    'loading data',
  ];
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  var step = 0;
  while (DateTime.now().isBefore(deadline)) {
    spinner.update(phases[step++ % phases.length]);
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }
  await spinner.finish(FeedbackOutcome.completed);
}
