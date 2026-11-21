import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';

Future<void> main(List<String> args) async {
  final scenario = args.single;
  final prompt = Multiline('Notes');
  final result = await prompt.prompt(
    mode: scenario == 'linear' ? PromptMode.linear : PromptMode.rich,
    output: stderr,
  );
  print(switch (result) {
    Accepted<String>(:final value) =>
      value.runes.map((r) => r.toRadixString(16)).join(','),
    Cancelled<String>() => 'cancel',
    Interrupted<String>() => 'interrupt',
    InputEnded<String>() => 'eof',
    Unavailable<String>(:final reason) => 'unavailable:$reason',
  });
}
