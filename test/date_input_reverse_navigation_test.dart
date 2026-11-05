import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('rich reverse navigation works with delivered Ctrl+B', () async {
    final out = StringBuffer();
    final result =
        await DateInput(
          'Date',
          order: DateFieldOrder.dayMonthYear,
          initialValue: '29/02/2024',
        ).prompt(
          mode: PromptMode.rich,
          source: ScriptedInput(Stream.value('\t\x02\x03'), out),
        );
    expect(result, isA<Interrupted>());
    expect('Focus: day'.allMatches(out.toString()).length, 2);
    expect(out.toString(), contains('Ctrl+B'));
  });
}
