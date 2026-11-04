import 'package:prompty/prompty.dart';

Future<void> main() async {
  final result = await SearchSelect<String>('Pick', [
    Choice('a', 'A'),
    Choice('b', 'B'),
  ]).prompt(mode: PromptMode.rich);
  print(switch (result) {
    Accepted<String>(:final value) => value,
    Cancelled<String>() => 'cancel',
    Interrupted<String>() => 'interrupt',
    InputEnded<String>() => 'eof',
    Unavailable<String>(:final reason) => 'unavailable:$reason',
  });
}
