import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('a removed node is not silently replaced on submission', () async {
    final out = StringBuffer();
    final tree = TreeSelect<String>('Pick', [
      TreeNode('a', 'A'),
      TreeNode('b', 'B'),
    ], isCurrent: (id) => id != 'a');
    final result = await tree.prompt(
      source: ScriptedInput(Stream.value('/choose\r1\r/choose\r2\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'b');
    expect(out.toString(), contains('no longer available'));
    expect(
      await tree.prompt(source: SuppliedAnswer('1')),
      isA<Unavailable<String>>(),
    );
  });
  test('linear cancel and incomplete reference do not accept a node', () async {
    final tree = TreeSelect<String>('Pick', [TreeNode('a', 'A')]);
    expect(
      await tree.prompt(
        source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<Cancelled<String>>(),
    );
    expect(
      await tree.prompt(
        source: ScriptedInput(Stream.value('/choose\r1'), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<InputEnded<String>>(),
    );
  });
  test('rich left moves to parent then collapses without selecting', () async {
    final out = StringBuffer();
    final result =
        await TreeSelect<String>('Pick', [
          TreeNode('a', 'A', selectable: true, children: [TreeNode('b', 'B')]),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[C\x1b[C\x1b[D\x1b[D\r'),
            out,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'a');
    expect(out.toString(), contains('A [focused] [collapsed] [selectable]'));
  });

  test('disabled nodes remain visible but cannot be chosen', () async {
    final out = StringBuffer();
    final result =
        await TreeSelect<String>('Pick', [
          TreeNode('a', 'A', disabledReason: 'offline'),
          TreeNode('b', 'B'),
        ]).prompt(
          source: ScriptedInput(Stream.value('/choose\r1\r/choose\r2\r'), out),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'b');
    expect(out.toString(), contains('unavailable: offline'));
  });

  test(
    'supplied references are stable and reject branches and disabled nodes',
    () async {
      final tree = TreeSelect<String>('Pick', [
        TreeNode('a', 'A', children: [TreeNode('b', 'B')]),
        TreeNode('c', 'C', disabledReason: 'offline'),
      ]);
      expect(
        (await tree.prompt(
          source: SuppliedAnswer('2'),
        ) as Accepted<String>).value,
        'b',
      );
      for (final value in ['1', '3', '4', '/cancel']) {
        expect(
          await tree.prompt(source: SuppliedAnswer(value)),
          isA<Unavailable<String>>(),
        );
      }
    },
  );

  test('empty tree and unsupported rich mode never select a node', () async {
    final tree = TreeSelect<String>('Pick', []);
    expect(
      await tree.prompt(
        source: ScriptedInput(Stream.value('\r'), StringBuffer()),
        mode: PromptMode.rich,
      ),
      isA<InputEnded<String>>(),
    );
    expect(
      await tree.prompt(
        source: ScriptedInput(
          Stream.value(''),
          StringBuffer(),
          supportsRich: false,
        ),
        mode: PromptMode.rich,
      ),
      isA<Unavailable<String>>(),
    );
  });

  test('duplicate identities are rejected even across branches', () {
    expect(
      () => TreeSelect<String>('Pick', [
        TreeNode('x', 'X', children: [TreeNode('x', 'Other')]),
      ]),
      throwsArgumentError,
    );
  });
  test('linear shows current selectable branch after opening it', () async {
    final out = StringBuffer();
    final result =
        await TreeSelect<String>('Pick', [
          TreeNode('a', 'A', selectable: true, children: [TreeNode('b', 'B')]),
        ]).prompt(
          source: ScriptedInput(Stream.value('/open\r1\r/choose\r1\r'), out),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'a');
    expect(out.toString(), contains('A [expanded] [selectable]'));
  });
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
