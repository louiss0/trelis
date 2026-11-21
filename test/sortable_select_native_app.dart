import 'package:trelis/src/testing/compat_api.dart';

Future<void> main() async {
  final result = await SortableSelect<String>('Pick', [
    Choice('a', 'A'),
    Choice('b', 'B'),
  ]).prompt(mode: PromptMode.rich);
  print(switch (result) {
    Accepted<List<String>>(:final value) => value.join(','),
    Cancelled<List<String>>() => 'cancel',
    Interrupted<List<String>>() => 'interrupt',
    InputEnded<List<String>>() => 'eof',
    Unavailable<List<String>>(:final reason) => 'unavailable:$reason',
  });
}
