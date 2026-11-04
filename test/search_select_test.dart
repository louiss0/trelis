import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('query help explains Enter only opens results', () async {
    final out = StringBuffer();
    final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
      source: ScriptedInput(Stream.value('\x14\x1b\r\r'), out),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'a');
    expect(out.toString(), contains('Enter opens results without accepting'));
  });
  test(
    'removed focused result requires navigation before rich acceptance',
    () async {
      final out = StringBuffer();
      final result =
          await SearchSelect(
            'Fruit',
            [Choice('a', 'Apple'), Choice('b', 'Banana')],
            search: (q) => q.isEmpty
                ? [Choice('a', 'Apple'), Choice('b', 'Banana')]
                : [Choice('b', 'Banana')],
          ).prompt(
            source: ScriptedInput(Stream.value('\r\t\tb\r\r\x1b[B\r'), out),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'b');
      expect(
        out.toString(),
        contains('Previously focused choice is removed or unavailable'),
      );
    },
  );
  test('rich results help is dismissed before root cancellation', () async {
    final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
      source: ScriptedInput(Stream.value('\r\x14\x1b\r'), StringBuffer()),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'a');
  });
  test('supplied reference cannot bypass dynamic availability', () async {
    final result = await SearchSelect('Fruit', [
      Choice('a', 'Apple'),
    ], search: (_) => <Choice<String>>[]).prompt(source: SuppliedAnswer('1'));
    expect(result, isA<Unavailable<String>>());
  });
  test('pending async search cannot accept a reference', () async {
    final pending = Completer<List<Choice<String>>>();
    final input = StreamController<String>();
    final out = StringBuffer();
    final result = SearchSelect(
      'Fruit',
      [Choice('a', 'Apple')],
      search: (_) => pending.future,
    ).prompt(source: ScriptedInput(input.stream, out), mode: PromptMode.linear);
    input.add('\r1\r');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(out.toString(), contains('Choose a current result reference.'));
    pending.complete([Choice('a', 'Apple')]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    input.add('1\r');
    expect((await result as Accepted<String>).value, 'a');
    await input.close();
  });

  test('late asynchronous result does not write after cancellation', () async {
    final pending = Completer<List<Choice<String>>>();
    final out = StringBuffer();
    final result =
        await SearchSelect('Fruit', [
          Choice('a', 'Apple'),
        ], search: (_) => pending.future).prompt(
          source: ScriptedInput(Stream.value('/cancel\r'), out),
          mode: PromptMode.linear,
        );
    expect(result, isA<Cancelled<String>>());
    final snapshot = out.toString();
    pending.complete([Choice('a', 'Apple')]);
    await Future<void>.delayed(Duration.zero);
    expect(out.toString(), snapshot);
  });
  test('default focus resumes when it matches again after filtering', () async {
    final result =
        await SearchSelect('Fruit', [
          Choice('a', 'Apple'),
          Choice('b', 'Banana'),
        ], defaultValue: 'b').prompt(
          source: ScriptedInput(
            Stream.value('app\r\t\t\x7f\x7f\x7f\r\r'),
            StringBuffer(),
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'b');
  });
  test('disabled default is explained and cannot be accepted', () async {
    final out = StringBuffer();
    final result =
        await SearchSelect('Fruit', [
          Choice('a', 'Apple', disabledReason: 'seasonal'),
          Choice('b', 'Banana'),
        ], defaultValue: 'a').prompt(
          source: ScriptedInput(Stream.value('\r\r\x1b[B\r'), out),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'b');
    expect(out.toString(), contains('Unavailable: seasonal'));
  });

  test(
    'linear paging retains original references and permits review',
    () async {
      final out = StringBuffer();
      final result =
          await SearchSelect('Items', [
            for (var i = 1; i <= 12; i++) Choice(i, 'Item $i'),
          ]).prompt(
            source: ScriptedInput(
              Stream.value('item\r/next\r/list\r12\r'),
              out,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<int>).value, 12);
      expect(out.toString(), contains('Page 2 of 2'));
      expect(out.toString(), contains('12. Item 12'));
    },
  );

  test('no matches cannot submit and query can be replaced', () async {
    final out = StringBuffer();
    final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
      source: ScriptedInput(
        Stream.value('zzz\r1\r/search\r\x7f\x7f\x7fapple\r1\r'),
        out,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'a');
    expect(out.toString(), contains('No matching choices'));
  });
  test(
    'rich results entered while loading can be accepted after loading',
    () async {
      final pending = Completer<List<Choice<String>>>();
      final input = StreamController<String>();
      final result =
          SearchSelect('Fruit', [
            Choice('a', 'Apple'),
          ], search: (_) => pending.future).prompt(
            source: ScriptedInput(input.stream, StringBuffer()),
            mode: PromptMode.rich,
          );
      input.add('\r');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      pending.complete([Choice('a', 'Apple')]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      input.add('\r');
      await input.close();
      expect((await result as Accepted<String>).value, 'a');
    },
  );
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
