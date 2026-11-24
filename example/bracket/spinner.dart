import 'dart:async';

import 'package:trelis/trelis.dart';

/// Spinner — one component, one structural theme (BracketTheme),
/// one colour theme (ColorThemes.neonGrid).
///
/// Run: dart run example/bracket/spinner.dart
Future<void> main(List<String> arguments) async {
  final theme = BracketTheme(
    interaction: const InteractionPreferences(mode: PromptMode.automatic),
  );
  final spinner = await theme
      .spinner(
        'Connecting',
        colors: ComponentColors.palette(ColorThemes.neonGrid),
      )
      .start();
  await spinner.run(
    () => Future<void>.delayed(const Duration(seconds: 8)),
    active: 'authenticating',
    detail: 'ready',
  );
}
