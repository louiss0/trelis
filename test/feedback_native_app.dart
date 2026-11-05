import 'dart:io';

import 'package:prompty/prompty.dart';

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
  stdout.writeln('application result');
  await stdout.flush();
  await stderr.flush();
  if (args.contains('wait')) {
    await Future<void>.delayed(const Duration(seconds: 8));
  }
}
