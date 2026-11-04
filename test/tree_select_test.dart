import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('initial focus prefers an enabled root', () async {
    final result =
        await TreeSelect<String>('Pick', [
          TreeNode('a', 'A', disabledReason: 'offline'),
          TreeNode('b', 'B'),
        ]).prompt(
          source: ScriptedInput(Stream.value('\r'), StringBuffer()),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'b');
  });
  test(
    'unresolved branches do not become selectable leaves or invent children',
    () async {
      final out = StringBuffer();
      final result =
          await TreeSelect<String>('Pick', [
            TreeNode('a', 'A', childrenUnavailableReason: 'not loaded'),
          ]).prompt(
            source: ScriptedInput(Stream.value('\r\x1b[C\x03'), out),
            mode: PromptMode.rich,
          );
      expect(result, isA<Interrupted<String>>());
      expect(out.toString(), contains('not loaded'));
      expect(out.toString(), contains('not selectable'));
    },
  );
  test(
    'linear open and up navigate separately from choosing stable references',
    () async {
      final out = StringBuffer();
      final result =
          await TreeSelect<String>('Pick', [
            TreeNode('a', 'A', children: [TreeNode('b', 'B')]),
            TreeNode('c', 'C'),
          ]).prompt(
            source: ScriptedInput(
              Stream.value('/open\r1\r/up\r/choose\r3\r'),
              out,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'c');
      expect(out.toString(), contains('A / B'));
      expect(out.toString(), contains('Path: root'));
    },
  );
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
