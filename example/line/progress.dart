import 'dart:async';

import 'package:trelis/trelis.dart';

/// Progress — one component, one structural theme (LineTheme),
/// one colour theme (ColorThemes.slate).
///
/// Run: dart run example/line/progress.dart
Future<void> main(List<String> arguments) async {
  final theme = LineTheme(
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
