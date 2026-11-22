import 'package:trelis/trelis.dart';

/// Spinner — one component, one structural theme (BranchTheme),
/// one colour theme (ColorThemes.neonGrid).
///
/// Run: dart run example/branch/spinner.dart
Future<void> main(List<String> arguments) async {
  final theme = BranchTheme(
    interaction: const InteractionPreferences(mode: PromptMode.linear),
  );
  final spinner = await theme
      .spinner(
        'Connecting',
        colors: ComponentColors.palette(ColorThemes.neonGrid),
      )
      .start();
  spinner.update('authenticating');
  await spinner.finish(FeedbackOutcome.completed);
}
