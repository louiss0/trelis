import 'dart:io';

import 'package:trelis/trelis.dart';

/// A short end-to-end flow over the public component seam.
///
/// Run `dart run example/trelis_example.dart` in a terminal. The mode is
/// selected automatically, or forced with `--rich` or `--linear`. Add
/// `--scripted` to replay the same flow from a fixed scripted stream, which
/// also works without a terminal. Nothing here needs a secret, a network or a
/// writable directory.
Future<void> main(List<String> arguments) async {
  final forced = arguments.contains('--linear')
      ? PromptMode.linear
      : arguments.contains('--rich')
      ? PromptMode.rich
      : null;
  final mode = forced ?? PromptMode.automatic;
  // One chunk per prompt: `demo`, accept the first target, add `new-tag`, then
  // confirm yes. Each prompt needs its own single-subscription source.
  const scriptedChunks = ['demo\r', '\r', 'new-tag\r\t\r', 'y\r'];
  var chunk = 0;
  PromptSource? nextSource() => arguments.contains('--scripted')
      ? ScriptedInput(Stream.value(scriptedChunks[chunk++]), stderr)
      : null;

  final name = await TextInput(
    'Project name',
    required: true,
  ).prompt(source: nextSource(), mode: mode);
  if (name is! Accepted<String>) return _stopped('Project name', name);

  final target = await Select<String>('Deploy target', [
    Choice('staging', 'Staging'),
    Choice('production', 'Production', disabledReason: 'locked for this demo'),
  ]).prompt(source: nextSource(), mode: mode);
  if (target is! Accepted<String>) return _stopped('Deploy target', target);

  final tags = await TagInput('Tags').prompt(source: nextSource(), mode: mode);
  if (tags is! Accepted<List<String>>) return _stopped('Tags', tags);

  final confirm = await Confirm('Deploy ${name.value} to ${target.value}?')
      .prompt(source: nextSource(), mode: mode);
  if (confirm is! Accepted<bool>) return _stopped('Confirmation', confirm);
  if (!confirm.value) {
    stderr.writeln('Declined; nothing was deployed.');
    return;
  }

  final progress = Progress('Preparing ${name.value}', total: 3);
  progress.start(output: stderr, mode: mode, supportsRich: true);
  for (var step = 1; step <= 3; step++) {
    progress.update(step);
  }
  progress.finish(FeedbackOutcome.completed, detail: target.value);

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
