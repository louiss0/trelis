import 'dart:async';
import 'dart:io';

import 'package:prompty/prompty.dart';

Future<void> main(List<String> args) async {
  try {
    final scenario = args.isEmpty ? 'repeat' : args.first;
    final prompt = TextInput(
      'Name',
      initialValue: scenario == 'paste' || scenario == 'unicode' ? '' : 'alpha',
    );
    if (scenario == 'concurrent') {
      final pending = prompt.prompt(mode: PromptMode.linear);
      var outcome = 'overlap';
      try {
        await TextInput('Other')
            .prompt(mode: PromptMode.linear)
            .timeout(const Duration(seconds: 1));
      } on StateError {
        outcome = 'busy';
      } on TimeoutException {
        outcome = 'timeout';
      }
      final result = await pending;
      print('$outcome,${result is Accepted<String> ? result.value : 'failed'}');
      return;
    }
    final results = <String>[];
    for (var i = 0; i < (scenario == 'repeat' ? 2 : 1); i++) {
      final result = await prompt.prompt(
        mode: scenario == 'rich' ? PromptMode.rich : PromptMode.linear,
        output: scenario == 'stdout' ? stdout : null,
      );
      results.add(switch (result) {
        Accepted<String>(:final value) => value,
        Cancelled<String>() => 'cancel',
        Interrupted<String>() => 'interrupt',
        InputEnded<String>() => 'eof',
        Unavailable<String>(:final reason) => 'unavailable:$reason',
      });
    }
    print(
      scenario == 'unicode'
          ? results.single.runes.map((r) => r.toRadixString(16)).join(',')
          : results.join(','),
    );
  } catch (error) {
    print('ERROR:$error');
  }
}
