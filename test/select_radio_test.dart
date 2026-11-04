import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Select navigation is provisional and Enter accepts focused identity',
    () async {
      final output = StringBuffer();
      final result =
          await Select<String>('Pick', [
            Choice('a', 'Same'),
            Choice('b', 'Same'),
          ]).prompt(
            source: ScriptedInput(Stream.value('\x1b[B\r'), output),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'b');
      expect(output.toString(), contains('focused'));
    },
  );
  test(
    'linear help advertises paging rather than unrelated commands',
    () async {
      final output = StringBuffer();
      await Radio<String>('Pick', [Choice('a', 'A')]).prompt(
        source: ScriptedInput(Stream.value('/help\r/cancel\r'), output),
        mode: PromptMode.linear,
      );
      expect(output.toString(), isNot(contains('/list')));
      expect(output.toString(), contains('/next'));
    },
  );
  test('disabled default stays focused and cannot be accepted', () async {
    final out = StringBuffer();
    final result =
        await Radio<String>('Pick', [
          Choice('a', 'A', disabledReason: 'offline'),
          Choice('b', 'B'),
        ], defaultValue: 'a').prompt(
          source: ScriptedInput(Stream.value('\r\x1b[B\r'), out),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'b');
    expect(
      out.toString(),
      contains('[focused] [default] [unavailable: offline]'),
    );
    expect(out.toString(), contains('Unavailable: offline'));
  });
  test(
    'first enabled focus, boundaries and provisional cancellation',
    () async {
      final choices = [
        Choice('a', 'A', disabledReason: 'offline'),
        Choice('b', 'B'),
      ];
      final out = StringBuffer();
      final prompt = Select<String>('Pick', choices);
      expect(
        (await prompt.prompt(
          source: ScriptedInput(Stream.value('\x1b[B\r'), out),
          mode: PromptMode.rich,
        ) as Accepted<String>).value,
        'b',
      );
      expect(
        await prompt.prompt(
          source: ScriptedInput(Stream.value('\x1b[A'), StringBuffer()),
          mode: PromptMode.rich,
        ),
        isA<InputEnded<String>>(),
      );
      expect(
        await prompt.prompt(
          source: ScriptedInput(Stream.value('\x03'), StringBuffer()),
          mode: PromptMode.rich,
        ),
        isA<Interrupted<String>>(),
      );
      expect(
        await prompt.prompt(
          source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer()),
          mode: PromptMode.linear,
        ),
        isA<Cancelled<String>>(),
      );
    },
  );
  test('linear paging retains references despite duplicate labels', () async {
    final out = StringBuffer();
    final choices = List.generate(12, (i) => Choice('id$i', 'Same'));
    final result = await Select<String>('Pick', choices).prompt(
      source: ScriptedInput(Stream.value('/next\r12\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'id11');
    expect(out.toString(), contains('Page 2 of 2'));
    expect(out.toString(), contains('12. Same'));
  });
  test('missing defaults and duplicate identities are rejected', () {
    expect(
      () => Select<String>('Pick', [Choice('a', 'A')], defaultValue: 'missing'),
      throwsArgumentError,
    );
    expect(
      () => Radio<String>('Pick', [Choice('a', 'A'), Choice('a', 'B')]),
      throwsArgumentError,
    );
  });
  test('empty and all unavailable lists cannot submit', () async {
    for (final choices in <List<Choice<String>>>[
      [],
      [Choice('a', 'A', disabledReason: 'offline')],
    ]) {
      final out = StringBuffer();
      expect(
        await Select<String>('Pick', choices).prompt(
          source: ScriptedInput(Stream.value('\r'), out),
          mode: PromptMode.rich,
        ),
        isA<InputEnded<String>>(),
      );
      expect(
        out.toString(),
        anyOf(
          contains('No choice available'),
          contains('Unavailable: offline'),
        ),
      );
    }
  });
}
