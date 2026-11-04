import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('rich Space changes draft and Enter submits in source order', () async {
    final result =
        await MultiSelect<String>('Pick', [
          Choice('a', 'A'),
          Choice('b', 'B'),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B \x1b[A \r'),
            StringBuffer(),
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['a', 'b']);
  });
  test('linear references toggle and done submits', () async {
    final result =
        await MultiSelect<String>('Pick', [
          Choice('a', 'A'),
          Choice('b', 'B'),
        ]).prompt(
          source: ScriptedInput(Stream.value('2\r1\r/done\r'), StringBuffer()),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<List<String>>).value, ['a', 'b']);
  });
  test(
    'filter retains hidden choices and bulk covers all filtered pages',
    () async {
      final out = StringBuffer();
      final choices = [
        Choice('hidden', 'Other'),
        ...List.generate(12, (i) => Choice('v$i', 'Visible $i')),
        Choice('disabled', 'Visible disabled', disabledReason: 'offline'),
      ];
      final result = await MultiSelect<String>('Pick', choices).prompt(
        source: ScriptedInput(
          Stream.value(
            '1\r/filter\rVisible\r/select-visible\r/selected\r/done\r',
          ),
          out,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<List<String>>).value, [
        'hidden',
        ...List.generate(12, (i) => 'v$i'),
      ]);
      expect(out.toString(), contains('1 hidden selected'));
      expect(out.toString(), contains('1. Other [hidden]'));
    },
  );
  test('maximum rejects bulk atomically and minimum preserves draft', () async {
    final out = StringBuffer();
    final result =
        await MultiSelect<String>(
          'Pick',
          [Choice('a', 'A'), Choice('b', 'B'), Choice('c', 'C')],
          min: 2,
          max: 2,
        ).prompt(
          source: ScriptedInput(
            Stream.value('1\r/done\r/select-visible\r2\r/done\r'),
            out,
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<List<String>>).value, ['a', 'b']);
    expect(out.toString(), contains('Minimum 2'));
    expect(out.toString(), contains('no changes made'));
  });
  test('empty is an accepted result', () async {
    final result = await MultiSelect<String>('Pick', []).prompt(
      source: ScriptedInput(Stream.value('/done\r'), StringBuffer()),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, isEmpty);
  });
  test('supplied references are literal, validated and ordered', () async {
    final prompt = MultiSelect<String>(
      'Pick',
      [
        Choice('a', 'Same'),
        Choice('b', 'Same'),
        Choice('c', 'C', disabledReason: 'offline'),
      ],
      min: 1,
      max: 2,
    );
    expect(
      (await prompt.prompt(
        source: SuppliedAnswer('2,1'),
      ) as Accepted<List<String>>).value,
      ['a', 'b'],
    );
    for (final input in ['', '1,1', '3', '4', '/cancel', '1,2,3']) {
      expect(
        await prompt.prompt(source: SuppliedAnswer(input)),
        isA<Unavailable<List<String>>>(),
      );
    }
    final empty = await MultiSelect<String>(
      'Pick',
      [],
    ).prompt(source: SuppliedAnswer(''));
    expect((empty as Accepted<List<String>>).value, isEmpty);
  });
}
