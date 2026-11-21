import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';

// In stale mode, type a then b: the a response is released after ab.
Future<List<String>> Function(String) controlledSuggestions(String scenario) {
  final old = Completer<List<String>>();
  return (query) async {
    if (scenario == 'failure' && query == 'fail') {
      throw StateError('controlled search failure');
    }
    if (scenario == 'stale' && query == 'a') return old.future;
    if (scenario == 'stale' && query == 'ab') {
      Timer.run(() {
        if (!old.isCompleted) old.complete(['Obsolete']);
      });
      return ['Current'];
    }
    return query == 'ok' ? ['Recovered'] : <String>[];
  };
}

Future<void> main(List<String> args) async {
  final scenario = args.firstOrNull;
  final result = await Autocomplete(
    'Name',
    suggestions: scenario == 'stale' || scenario == 'failure'
        ? controlledSuggestions(scenario!)
        : (_) => ['Ada', 'Grace'],
  ).prompt(mode: PromptMode.rich);
  print(switch (result) {
    Accepted<String>(:final value) => value,
    Cancelled<String>() => 'cancel',
    Interrupted<String>() => 'interrupt',
    InputEnded<String>() => 'eof',
    Unavailable<String>(:final reason) => 'unavailable:$reason',
  });
}
