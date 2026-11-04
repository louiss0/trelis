import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
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
