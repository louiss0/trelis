import 'package:trelis/trelis.dart';

/// MultiSpinner — one component, one structural theme (DoubleTheme),

/// one colour theme (ColorThemes.lavender).

///

/// Run: dart run example/double/multi_spinner.dart

Future<void> main(List<String> arguments) async {
  final theme = DoubleTheme(
    interaction: const InteractionPreferences(mode: PromptMode.linear),
  );

  final tasks = await theme
      .multiSpinner(
        const ['Download', 'Compile', 'Package'],

        interval: Duration.zero,

        colors: ComponentColors.palette(ColorThemes.lavender),
      )
      .start();

  tasks.update('Compile', TaskActivity.running, phase: 'linking');

  tasks.finishTask('Download', FeedbackOutcome.completed);

  tasks.finishTask('Compile', FeedbackOutcome.completed);

  tasks.finishTask('Package', FeedbackOutcome.completed);

  await tasks.stop();
}
