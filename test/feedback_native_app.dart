import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';

Future<void> main(List<String> args) async {
  Text('literal\x1b[31m', kind: TextKind.warning).present();
  final progress = Progress(
    'A long operation with a task name that wraps at a narrow console width',
    total: 100,
  );
  final mode = args.contains('linear')
      ? PromptMode.linear
      : PromptMode.automatic;
  progress.start(mode: mode);
  progress.update(20);
  progress.finish(FeedbackOutcome.failed, detail: 'network unavailable');
  final spinner = Spinner('Connection');
  spinner.start(mode: mode);
  spinner.update('waiting for server');
  spinner.finish(FeedbackOutcome.skipped);
  final group = MultiSpinner(['build', 'test']);
  group.start(mode: mode);
  group.update('build', TaskActivity.running, phase: 'compiling');
  group.finishTask('test', FeedbackOutcome.failed, detail: 'test failure');
  group.finishTask('build', FeedbackOutcome.completed);
  stdout.writeln('application result');
  await stdout.flush();
  await stderr.flush();
  if (args.contains('wait')) {
    await Future<void>.delayed(const Duration(seconds: 8));
  }
}
