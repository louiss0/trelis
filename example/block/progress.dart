import 'package:trelis/trelis.dart';

/// Progress — one component, one structural theme (BlockTheme),
/// one colour theme (ColorThemes.slate).
///
/// Run: dart run example/block/progress.dart
Future<void> main(List<String> arguments) async {
  final theme = BlockTheme(
    interaction: const InteractionPreferences(mode: PromptMode.linear),
  );
  final progress = await theme
      .progress(
        'Download',
        total: 3,
        interval: Duration.zero,
        colors: ComponentColors.palette(ColorThemes.slate),
      )
      .start();
  progress.update(2);
  await progress.finish(FeedbackOutcome.completed, detail: '3 items');
}
