import 'dart:async';
import 'dart:io';

import 'package:prompty/prompty.dart';

Future<void> main(List<String> args) async {
  try {
    final scenario = args.isEmpty ? 'repeat' : args.first;
    final prompt = TextInput(
      'Name',
      initialValue: switch (scenario) {
        'paste' || 'unicode' => '',
        'linear-long' => '0123456789' * 30,
        _ => 'alpha',
      },
    );
    if (scenario.startsWith('help-')) {
      final mode = scenario.endsWith('rich')
          ? PromptMode.rich
          : PromptMode.linear;
      final result = scenario.contains('password')
          ? await Password('Synthetic password').prompt(mode: mode)
          : await prompt.prompt(mode: mode);
      // Never print the hidden answer, even for a synthetic native test.
      print(switch (result) {
        Accepted<String>(:final value) =>
          scenario.contains('password')
              ? (value == 'secret' ? 'accepted' : 'wrong')
              : value,
        Interrupted<String>() => 'interrupt',
        Cancelled<String>() => 'cancel',
        InputEnded<String>() => 'eof',
        _ => 'failed',
      });
      return;
    }
    if (scenario == 'error') {
      final failing = TextInput(
        'Failure',
        validate: (_) => throw StateError('validation'),
      );
      try {
        await failing.prompt(mode: PromptMode.linear);
      } on StateError {
        // A subsequent session must still be usable after validation throws.
      }
      final result = await prompt.prompt(mode: PromptMode.linear);
      print(result is Accepted<String> ? result.value : 'failed');
      return;
    }
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
        mode: switch (scenario) {
          'rich' || 'dumb-rich' => PromptMode.rich,
          'dumb-auto' => PromptMode.automatic,
          _ => PromptMode.linear,
        },
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
