import 'dart:async';

import 'package:trelis/trelis.dart';

// In stale mode, type a then b: the a response is released after ab.
Future<List<Choice<String>>> Function(String) controlledSearch(
  String scenario,
) {
  final old = Completer<List<Choice<String>>>();
  return (query) async {
    if (scenario == 'failure' && query == 'fail') {
      throw StateError('controlled search failure');
    }
    if (scenario == 'stale' && query == 'a') return old.future;
    if (scenario == 'stale' && query == 'ab') {
      Timer.run(() {
        if (!old.isCompleted) old.complete([Choice('a', 'Obsolete')]);
      });
      return [Choice('b', 'Current')];
    }
    return query == 'ok' ? [Choice('b', 'Recovered')] : <Choice<String>>[];
  };
}

Future<void> main(List<String> args) async {
  final scenario = args.firstOrNull;
  final result = await SearchSelect<String>(
    'Pick',
    [Choice('a', 'A'), Choice('b', 'B')],
    search: scenario == 'stale' || scenario == 'failure'
        ? controlledSearch(scenario!)
        : null,
  ).prompt(mode: scenario == 'linear' ? PromptMode.linear : PromptMode.rich);
  print(switch (result) {
    Accepted<String>(:final value) => value,
    Cancelled<String>() => 'cancel',
    Interrupted<String>() => 'interrupt',
    InputEnded<String>() => 'eof',
    Unavailable<String>(:final reason) => 'unavailable:$reason',
  });
}
