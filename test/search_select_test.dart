import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
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

