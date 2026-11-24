import 'dart:async';

import 'package:trelis/trelis.dart';

/// Progress — one component, one structural theme (AsciiTheme),
/// one colour theme (ColorThemes.slate).
///
/// Run: dart run example/ascii/progress.dart
Future<void> main(List<String> arguments) async {
  final theme = AsciiTheme(
    interaction: const InteractionPreferences(mode: PromptMode.automatic),
  );
  final progress = await theme
      .progress(
        'Download',
        total: 3,
        interval: Duration.zero,
        colors: ComponentColors.palette(ColorThemes.slate),
      )
      .start();
  await progress.run((report) async {
    for (var i = 1; i <= 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      report(i);
    }
  }, detail: '3 items');
}
