import 'dart:async';

import 'package:trelis/trelis.dart';

/// MultiSpinner — one component, one structural theme (LedgerTheme),

/// one colour theme (ColorThemes.lavender).

///

/// Run: dart run example/ledger/multi_spinner.dart

Future<void> main(List<String> arguments) async {
  final theme = LedgerTheme(
    interaction: const InteractionPreferences(mode: PromptMode.automatic),
  );

  final tasks = await theme
      .multiSpinner(
        const ['Download', 'Compile', 'Package'],

        interval: Duration.zero,

        colors: ComponentColors.palette(ColorThemes.lavender),
      )
      .start();

  tasks.update('Compile', TaskActivity.running, phase: 'linking');
  await Future<void>.delayed(const Duration(milliseconds: 400));

  tasks.finishTask('Download', FeedbackOutcome.completed);

  tasks.update('Package', TaskActivity.running, phase: 'archiving');
  await Future<void>.delayed(const Duration(milliseconds: 400));
  tasks.finishTask('Compile', FeedbackOutcome.completed);

  await Future<void>.delayed(const Duration(milliseconds: 400));
  tasks.finishTask('Package', FeedbackOutcome.completed);

  await tasks.stop();
}
