import 'package:prompty/prompty.dart';

Future<void> main() async {
  final result = await Autocomplete(
    'Name',
    suggestions: (_) => ['Ada', 'Grace'],
  ).prompt(mode: PromptMode.rich);
  print(switch (result) {
    Accepted<String>(:final value) => value,
    Cancelled<String>() => 'cancel',
    Interrupted<String>() => 'interrupt',
    InputEnded<String>() => 'eof',
    Unavailable<String>(:final reason) => 'unavailable:$reason',
  });
}
