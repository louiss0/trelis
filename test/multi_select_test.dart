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
  test(
    'clear visible removes only enabled filtered selections across pages',
    () async {
      final out = StringBuffer();
      final choices = [
        Choice('hidden', 'Other'),
        ...List.generate(12, (i) => Choice('v$i', 'Visible $i')),
        Choice('disabled', 'Visible disabled', disabledReason: 'offline'),
      ];
      final result =
          await MultiSelect<String>(
            'Pick',
            choices,
            defaultValues: ['hidden', ...List.generate(12, (i) => 'v$i')],
          ).prompt(
            source: ScriptedInput(
              Stream.value(
                '/filter\rVisible\r/clear-visible\r/selected\r/done\r',
              ),
              out,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<List<String>>).value, ['hidden']);
      expect(out.toString(), contains('1. Other [hidden]'));
    },
  );
  test(
    'stable references identify duplicate labels through paging and filters',
    () async {
      final out = StringBuffer();
      final choices = [
        Choice('a', 'Same'),
        ...List.generate(10, (i) => Choice('x$i', 'Other $i')),
        Choice('b', 'Same'),
      ];
      final result = await MultiSelect<String>('Pick', choices).prompt(
        source: ScriptedInput(
          Stream.value('/next\r12\r/filter\rSame\r1\r/selected\r/done\r'),
          out,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<List<String>>).value, ['a', 'b']);
      expect(out.toString(), contains('12. Same'));
      expect(out.toString(), contains('Page 2 of 2'));
    },
  );
  test('disabled focus is inspectable but cannot toggle', () async {
    final out = StringBuffer();
    final result =
        await MultiSelect<String>('Pick', [
          Choice('a', 'A'),
          Choice('b', 'B', disabledReason: 'offline'),
        ]).prompt(
          source: ScriptedInput(Stream.value('\x1b[B \r'), out),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, isEmpty);
    expect(out.toString(), contains('[focused] [unavailable: offline]'));
    expect(out.toString(), contains('Unavailable: offline'));
  });
  test('cancellation interruption and EOF never accept a draft', () async {
    final prompt = MultiSelect<String>('Pick', [Choice('a', 'A')]);
    for (final scenario in [
      (PromptMode.rich, ' \x1bx', 0),
      (PromptMode.rich, ' \x03', 1),
      (PromptMode.rich, ' ', 2),
      (PromptMode.linear, '1\r/cancel\r', 0),
      (PromptMode.linear, '1\r', 2),
    ]) {
      final result = await prompt.prompt(
        source: ScriptedInput(Stream.value(scenario.$2), StringBuffer()),
        mode: scenario.$1,
      );
      if (scenario.$3 == 0) expect(result, isA<Cancelled<List<String>>>());
      if (scenario.$3 == 1) expect(result, isA<Interrupted<List<String>>>());
      if (scenario.$3 == 2) expect(result, isA<InputEnded<List<String>>>());
    }
  });
  test('invalid defaults and count constraints are rejected', () {
    final choices = [
      Choice('a', 'A'),
      Choice('b', 'B', disabledReason: 'offline'),
    ];
    expect(
      () => MultiSelect('Pick', choices, defaultValues: ['b']),
      throwsArgumentError,
    );
    expect(
      () => MultiSelect('Pick', choices, defaultValues: ['a', 'a']),
      throwsArgumentError,
    );
    expect(
      () => MultiSelect('Pick', choices, defaultValues: ['missing']),
      throwsArgumentError,
    );
    expect(
      () => MultiSelect('Pick', choices, min: 2, max: 1),
      throwsArgumentError,
    );
    expect(
      () => MultiSelect('Pick', [Choice('a', 'A'), Choice('a', 'B')]),
      throwsArgumentError,
    );
  });
  test('linear instructions explain literal command quoting', () async {
    final out = StringBuffer();
    await MultiSelect<String>('Pick', []).prompt(
      source: ScriptedInput(Stream.value('/done\r'), out),
      mode: PromptMode.linear,
    );
    expect(out.toString(), contains('Quote commands with a backslash'));
    expect(out.toString(), contains('Identified paste is literal'));
  });
  test(
    'rich filtering retains hidden draft and bulk enforces maximum atomically',
    () async {
      final out = StringBuffer();
      final result =
          await MultiSelect<String>('Pick', [
            Choice('a', 'Other'),
            Choice('b', 'Visible B'),
            Choice('c', 'Visible C'),
          ], max: 2).prompt(
            source: ScriptedInput(Stream.value(' /Visible\r\x01\x12 \r'), out),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<List<String>>).value, ['a', 'b']);
      expect(out.toString(), contains('1 hidden selected'));
      expect(out.toString(), contains('no changes made'));
      expect(out.toString(), contains('1. Other [hidden]'));
    },
  );
}
