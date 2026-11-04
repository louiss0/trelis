import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('rich opening a branch does not choose it or its descendants', () async {
    final out = StringBuffer();
    final result =
        await TreeSelect<String>('Pick', [
          TreeNode('a', 'A', children: [TreeNode('b', 'B')]),
        ]).prompt(
          source: ScriptedInput(Stream.value('\r\x1b[C\x1b[C\r'), out),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'b');
    expect(out.toString(), contains('not selectable'));
    expect(out.toString(), contains('A / B'));
  });
}
