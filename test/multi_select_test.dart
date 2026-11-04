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
}
