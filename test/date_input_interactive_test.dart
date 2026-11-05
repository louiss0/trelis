import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('linear entry requires review and explicit submit', () async {
    final output = StringBuffer();
    final result = await DateInput('Date', order: DateFieldOrder.dayMonthYear)
        .prompt(
          source: ScriptedInput(Stream.value('29/02/2024\r/submit\r'), output),
          mode: PromptMode.linear,
        );
    expect(result, isA<Accepted<CivilDate>>());
    expect(output.toString(), contains('ISO date: 2024-02-29'));
  });
  test('end during review does not accept', () async {
    final result = await DateInput('Date', order: DateFieldOrder.dayMonthYear)
        .prompt(
          source: ScriptedInput(Stream.value('29/02/2024\r'), StringBuffer()),
          mode: PromptMode.linear,
        );
    expect(result, isA<InputEnded<CivilDate>>());
  });
}
