import 'dart:async';

import 'package:trelis/trelis.dart';

/// Spinner — one component, one structural theme (DoubleTheme),
/// one colour theme (ColorThemes.neonGrid).
///
/// Run: dart run example/double/spinner.dart
Future<void> main(List<String> arguments) async {
  final theme = DoubleTheme(
    interaction: const InteractionPreferences(mode: PromptMode.automatic),
  );
  final spinner = await theme
      .spinner(
        'Connecting',
        colors: ComponentColors.palette(ColorThemes.neonGrid),
      )
      .start();
  await spinner.follow(
    Stream.periodic(
      const Duration(milliseconds: 800),
      (count) =>
          const ['authenticating', 'resolving routes', 'loading data'][count % 3],
    ).take(10),
    detail: 'ready',
  );
}
