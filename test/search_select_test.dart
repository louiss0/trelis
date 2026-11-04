import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('linear user can explicitly choose after an async focused choice disappears', () async {
    final out = StringBuffer();
    final result =
        await SearchSelect(
          'Fruit',
          [Choice('a', 'Apple'), Choice('b', 'Banana')],
          defaultValue: 'a',
          search: (q) => q.isEmpty
              ? [Choice('a', 'Apple'), Choice('b', 'Banana')]
              : [Choice('b', 'Banana')],
        ).prompt(
          source: ScriptedInput(Stream.value('\r/search\rb\r2\r'), out),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'b');
    expect(out.toString(), contains('Previously focused choice'));
  });
  test('obsolete async search cannot replace current results', () async {
    final requests = <String, Completer<List<Choice<String>>>>{};
    final input = StreamController<String>();
    final out = StringBuffer();
    final prompt = SearchSelect(
      'Fruit',
      [Choice('a', 'Apple'), Choice('b', 'Banana')],
      search: (query) =>
          (requests[query] = Completer<List<Choice<String>>>()).future,
    ).prompt(source: ScriptedInput(input.stream, out), mode: PromptMode.linear);
    input.add('a');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    input.add('\x7fb\r');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    requests['b']!.complete([Choice('b', 'Banana')]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    requests['a']!.complete([Choice('a', 'Apple')]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    input.add('1\r2\r');
    expect((await prompt as Accepted<String>).value, 'b');
    await input.close();
  });
  test(
    'Tab traverses results and cancel action before returning to query',
    () async {
      final out = StringBuffer();
      final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
        source: ScriptedInput(Stream.value('\t\t\t\r\r'), out),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<String>).value, 'a');
      expect(out.toString(), contains('Cancel action focused'));
    },
  );
  test('returning from no matches restores prior focused choice', () async {
    final result =
        await SearchSelect('Fruit', [
          Choice('apple', 'Apple'),
          Choice('pear', 'Pear'),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('\r\x1b[B\t\tzzz\r\t\t\x7f\x7f\x7f\r\r'),
            StringBuffer(),
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'pear');
  });
  test('pasting in results returns to query without accepting', () async {
    final result =
        await SearchSelect('Fruit', [
          Choice('apple', 'Apple'),
          Choice('pear', 'Pear'),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('\r\x1b[200~pear\x1b[201~\r\r'),
            StringBuffer(),
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'pear');
  });
  test('query Enter cannot accept a choice', () async {
    final result = await SearchSelect('Fruit', [Choice('apple', 'Apple')])
        .prompt(
          source: ScriptedInput(Stream.value('app\r'), StringBuffer()),
          mode: PromptMode.rich,
        );
    expect(result, isA<InputEnded<String>>());
  });

  test(
    'linear search rejects a stale reference before accepting a current one',
    () async {
      final output = StringBuffer();
      final result =
          await SearchSelect('Fruit', [
            Choice('apple', 'Apple'),
            Choice('pear', 'Pear'),
          ]).prompt(
            source: ScriptedInput(Stream.value('pear\r1\r2\r'), output),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'pear');
      expect(output.toString(), contains('Choose a current result reference.'));
    },
  );
  test('Enter in query only enters results; Enter there chooses', () async {
    final output = StringBuffer();
    final result =
        await SearchSelect('Fruit', [
          Choice('apple', 'Apple'),
          Choice('pear', 'Pear'),
        ]).prompt(
          source: ScriptedInput(Stream.value('PL\r\r'), output),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'apple');
    expect(output.toString(), contains('1. Apple'));
  });
}
