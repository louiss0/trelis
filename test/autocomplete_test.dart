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
  test(
    'linear default is editable and invalid submission retains draft',
    () async {
      final output = StringBuffer();
      final result =
          await Autocomplete(
            'Name',
            initialValue: 'Ada',
            required: true,
            suggestions: (_) => <String>[],
            validate: (value) => value == 'Ada!' ? null : 'Add an exclamation',
          ).prompt(
            source: ScriptedInput(
              Stream.value('\r/submit\r/edit\r!\r/submit\r'),
              output,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'Ada!');
      expect(output.toString(), contains('Add an exclamation'));
    },
  );
  test('Escape dismisses help before the active suggestion layer', () async {
    final input = StreamController<String>();
    final result = Autocomplete('Name', suggestions: (_) => ['Ada']).prompt(
      source: ScriptedInput(input.stream, StringBuffer()),
      mode: PromptMode.rich,
    );
    input.add('A\x1b[B\x14\x1b');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    input.add('\r\r');
    expect((await result as Accepted<String>).value, 'Ada');
    await input.close();
  });
  test('late rich results cannot replace newer suggestions', () async {
    final requests = <String, Completer<List<String>>>{};
    final input = StreamController<String>();
    final result =
        Autocomplete(
          'Name',
          suggestions: (query) =>
              requests.putIfAbsent(query, Completer<List<String>>.new).future,
        ).prompt(
          source: ScriptedInput(input.stream, StringBuffer()),
          mode: PromptMode.rich,
        );
    input.add('a');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    input.add('b');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    requests['ab']!.complete(['Newest']);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    requests['a']!.complete(['Stale']);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    input.add('\t\r');
    expect((await result as Accepted<String>).value, 'Newest');
    await input.close();
  });
  test(
    'navigating and dismissing suggestions retains the editing cursor',
    () async {
      final input = StreamController<String>();
      final result = Autocomplete('Name', suggestions: (_) => ['candidate'])
          .prompt(
            source: ScriptedInput(input.stream, StringBuffer()),
            mode: PromptMode.rich,
          );
      input.add('ab\x1b[D\x1b[B\x1b');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      input.add('X\r');
      expect((await result as Accepted<String>).value, 'aXb');
      await input.close();
    },
  );
  test('linear quoted command remains free-text data', () async {
    final result = await Autocomplete('Name', suggestions: (_) => <String>[])
        .prompt(
          source: ScriptedInput(
            Stream.value('\\/cancel\r/submit\r'),
            StringBuffer(),
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, '/cancel');
  });
  test('pasted action-stage submit is literal, not a command', () async {
    final result = await Autocomplete('Name', suggestions: (_) => <String>[])
        .prompt(
          source: ScriptedInput(
            Stream.value('Ada\r\x1b[200~/submit\x1b[201~\r/cancel\r'),
            StringBuffer(),
          ),
          mode: PromptMode.linear,
        );
    expect(result, isA<Cancelled<String>>());
  });
  test('quoted action-stage submit is not executed', () async {
    final result = await Autocomplete('Name', suggestions: (_) => <String>[])
        .prompt(
          source: ScriptedInput(
            Stream.value('Ada\r\\/submit\r/cancel\r'),
            StringBuffer(),
          ),
          mode: PromptMode.linear,
        );
    expect(result, isA<Cancelled<String>>());
  });
  test('pasted candidate number does not accept a candidate', () async {
    final result = await Autocomplete('Name', suggestions: (_) => ['Grace'])
        .prompt(
          source: ScriptedInput(
            Stream.value('Ada\r\x1b[200~1\x1b[201~\r/submit\r'),
            StringBuffer(),
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'Ada');
  });
  test(
    'late linear results cannot replace results for the edited query',
    () async {
      final requests = <String, Completer<List<String>>>{};
      final input = StreamController<String>();
      final result =
          Autocomplete(
            'Name',
            suggestions: (query) =>
                requests.putIfAbsent(query, Completer<List<String>>.new).future,
          ).prompt(
            source: ScriptedInput(input.stream, StringBuffer()),
            mode: PromptMode.linear,
          );
      input.add('a\r/edit\rb\r');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      requests['ab']!.complete(['Newest']);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      requests['a']!.complete(['Stale']);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      input.add('1\r/submit\r');
      expect((await result as Accepted<String>).value, 'Newest');
      await input.close();
    },
  );
  test('offered candidates do not intercept free-text Enter', () async {
    final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
        .prompt(
          source: ScriptedInput(Stream.value('Grace\r'), StringBuffer()),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'Grace');
  });
  test('Tab accepts the first suggestion without submitting it', () async {
    final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
        .prompt(
          source: ScriptedInput(Stream.value('x\t!\r'), StringBuffer()),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'Ada!');
  });
  test('rich Escape dismisses suggestions then cancels', () async {
    final input = StreamController<String>();
    final result = Autocomplete('Name', suggestions: (_) => ['Ada']).prompt(
      source: ScriptedInput(input.stream, StringBuffer()),
      mode: PromptMode.rich,
    );
    input.add('x\x1b');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    input.add('\x1b');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await result, isA<Cancelled<String>>());
    await input.close();
  });
  test(
    'linear cancel remains available with a short character limit',
    () async {
      final result =
          await Autocomplete(
            'Name',
            maxLength: 2,
            suggestions: (_) => <String>[],
          ).prompt(
            source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer()),
            mode: PromptMode.linear,
          );
      expect(result, isA<Cancelled<String>>());
    },
  );
}
