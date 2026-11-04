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
}
