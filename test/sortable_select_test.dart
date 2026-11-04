import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('rich pick up move and drop produces a permutation', () async {
    final result =
        await SortableSelect<String>('Order', [
          Choice('a', 'A'),
          Choice('b', 'B'),
        ]).prompt(
          source: ScriptedInput(Stream.value(' \x1b[B\r\r'), StringBuffer()),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['b', 'a']);
  });
}
