import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'supplied unmatched text is accepted without querying suggestions',
    () async {
      var calls = 0;
      final prompt = Autocomplete(
        'Name',
        suggestions: (query) async {
          calls++;
          return ['Ada'];
        },
      );
      final result = await prompt.prompt(source: SuppliedAnswer('Grace'));
      expect((result as Accepted<String>).value, 'Grace');
      expect(calls, 0);
    },
  );
  test(
    'linear candidate acceptance requires explicit final submission',
    () async {
      final output = StringBuffer();
      final result =
          await Autocomplete(
            'Name',
            suggestions: (_) async => ['Ada', 'Grace'],
          ).prompt(
            source: ScriptedInput(Stream.value('A\r2\r/submit\r'), output),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'Grace');
      expect(output.toString(), contains('1. Ada'));
      expect(output.toString(), contains('2. Grace'));
    },
  );
  test(
    'rich navigation accepts a candidate before a separate submission',
    () async {
      final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
          .prompt(
            source: ScriptedInput(Stream.value('A\x1b[B\r\r'), StringBuffer()),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'Ada');
    },
  );
  test('linear free text can submit while suggestions are pending', () async {
    final pending = Completer<List<String>>();
    final result =
        await Autocomplete('Name', suggestions: (_) => pending.future)
            .prompt(
              source: ScriptedInput(
                Stream.value('Grace\r/submit\r'),
                StringBuffer(),
              ),
              mode: PromptMode.linear,
            )
            .timeout(const Duration(seconds: 1));
    expect((result as Accepted<String>).value, 'Grace');
  });
  test(
    'rich Escape dismisses pending suggestions before cancellation',
    () async {
      final pending = Completer<List<String>>();
      final input = StreamController<String>();
      final result = Autocomplete('Name', suggestions: (_) => pending.future)
          .prompt(
            source: ScriptedInput(input.stream, StringBuffer()),
            mode: PromptMode.rich,
          );
      input.add('A\x1b');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      input.add('\r');
      expect((await result as Accepted<String>).value, 'A');
      await input.close();
    },
  );
}
