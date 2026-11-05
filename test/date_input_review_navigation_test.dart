import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('rich review Tab focuses Submit and Enter explicitly accepts', () async {
    final output = StringBuffer();
    final result = await DateInput('Date', order: DateFieldOrder.dayMonthYear)
        .prompt(
          mode: PromptMode.rich,
          source: ScriptedInput(Stream.value('29/2/2024\r\t\r'), output),
        );
    expect(result, isA<Accepted<CivilDate>>());
    expect(output.toString(), contains('Review action: Submit'));
  });
  test('rich review Edit returns to retained fields', () async {
    final output = StringBuffer();
    final result = await DateInput('Date', order: DateFieldOrder.dayMonthYear)
        .prompt(
          mode: PromptMode.rich,
          source: ScriptedInput(
            Stream.value('29/2/2024\r\r\t\t\r\t\r'),
            output,
          ),
        );
    expect(result, isA<Accepted<CivilDate>>());
    expect(output.toString().split('Focus: day').length, greaterThan(2));
  });
}
