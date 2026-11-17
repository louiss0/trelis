import 'package:trelis/trelis.dart';

Future<void> main(List<String> args) async {
  final result = await TreeSelect<String>(
    'Pick',
    [
      TreeNode('a', 'A', children: [TreeNode('b', 'B')]),
    ],
  ).prompt(mode: args.contains('linear') ? PromptMode.linear : PromptMode.rich);
  print(switch (result) {
    Accepted<String>(:final value) => value,
    Cancelled<String>() => 'cancel',
    Interrupted<String>() => 'interrupt',
    InputEnded<String>() => 'eof',
    Unavailable<String>(:final reason) => 'unavailable:$reason',
  });
}
