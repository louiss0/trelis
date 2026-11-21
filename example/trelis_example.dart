import 'dart:io';

import 'package:trelis/trelis.dart';

/// A short end-to-end flow over the unstable theme-instance public API.
///
/// `RailTheme` owns its I/O and active period; swap it for any of the other
/// fourteen structural themes to change the visual grammar without changing
/// the prompt calls. This demo uses a fixed script so it runs without a
/// terminal and demonstrates automatic cleanup: there is no theme close.
///
/// Run `dart run example/trelis_example.dart`.
Future<void> main() async {
  const scriptedChunks = [
    'demo\r',
    '1\r',
    'new-tag\r/done\r',
    'y\r',
  ];
  var chunk = 0;

  ThemePrompt<String> promptFor(String label) => RailTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value(scriptedChunks[chunk++]),
      output: stderr,
    ),
  ).textInput(label, required: true);

  final name = await promptFor('Project name').prompt();
  if (name is! Accepted<String>) return _stopped('Project name', name);

  final targetTheme = RailTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value(scriptedChunks[chunk++]),
      output: stderr,
    ),
  );
  final target = await targetTheme.select<String>('Deploy target', [
    Choice('staging', 'Staging'),
    Choice('production', 'Production', disabledReason: 'locked for demo'),
  ]).prompt();
  if (target is! Accepted<String>) return _stopped('Deploy target', target);

  final tagsTheme = RailTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value(scriptedChunks[chunk++]),
      output: stderr,
    ),
  );
  final tags = await tagsTheme.tagInput('Tags').prompt();
  if (tags is! Accepted<List<String>>) return _stopped('Tags', tags);

  final confirmTheme = RailTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.value(scriptedChunks[chunk++]),
      output: stderr,
    ),
  );
  final confirm = await confirmTheme
      .confirm('Deploy ${name.value} to ${target.value}?')
      .prompt();
  if (confirm is! Accepted<bool>) return _stopped('Confirmation', confirm);
  if (!confirm.value) {
    stderr.writeln('Declined; nothing was deployed.');
    return;
  }

  final feedbackTheme = RailTheme(
    io: TerminalEnvironment.scripted(
      input: const Stream<String>.empty(),
      output: stderr,
    ),
  );
  final progress = await feedbackTheme
      .progress('Preparing ${name.value}', total: 3)
      .start();
  await progress.finish(FeedbackOutcome.completed, detail: target.value);

  stderr.writeln(
    'Ready: project ${name.value}, target ${target.value}, '
    'tags ${tags.value.join(', ')}, no work was performed.',
  );
}

void _stopped(String step, PromptResult<Object?> result) {
  stderr.writeln('$step did not accept a value: ${result.runtimeType}.');
  if (result is Unavailable<Object?>) {
    stderr.writeln('Reason: ${result.reason}');
  }
}
