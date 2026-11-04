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
  test(
    'escape restores current move and focus while retaining earlier drops',
    () async {
      final result =
          await SortableSelect<String>('Order', [
            Choice('a', 'A'),
            Choice('b', 'B'),
            Choice('c', 'C'),
          ]).prompt(
            source: ScriptedInput(
              Stream.value(' \x1b[B  \x1b[B\x1b \x1b[A\r\r'),
              StringBuffer(),
            ),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<List<String>>).value, ['a', 'b', 'c']);
    },
  );
  test('linear moves use stable references and cannot cross anchors', () async {
    final out = StringBuffer();
    final result =
        await SortableSelect<String>('Order', [
          Choice('a', 'Same'),
          Choice('b', 'Same'),
          Choice('x', 'Anchor', disabledReason: 'fixed'),
          Choice('c', 'C'),
          Choice('d', 'D'),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('/move\r2\r1\r/move\r1\r5\r/move\r5\r4\r/done\r'),
            out,
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<List<String>>).value, ['b', 'a', 'x', 'd', 'c']);
    expect(out.toString(), contains('Cannot cross a locked anchor'));
    expect(out.toString(), contains('locked: fixed'));
  });
  test(
    'supplied order must be a complete anchor-respecting permutation',
    () async {
      final prompt = SortableSelect<String>('Order', [
        Choice('a', 'A'),
        Choice('x', 'X', disabledReason: 'fixed'),
        Choice('b', 'B'),
      ]);
      expect(
        await prompt.prompt(source: SuppliedAnswer('3,2,1')),
        isA<Unavailable<List<String>>>(),
      );
      expect(
        (await prompt.prompt(
          source: SuppliedAnswer('1,2,3'),
        ) as Accepted<List<String>>).value,
        ['a', 'x', 'b'],
      );
    },
  );
}
