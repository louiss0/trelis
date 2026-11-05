import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('rich entry reviews a Buddhist date before submission', () async {
    final output = StringBuffer();
    final result =
        await DateInput(
          'Date',
          order: DateFieldOrder.dayMonthYear,
          calendar: DateCalendar.buddhist,
        ).prompt(
          source: ScriptedInput(Stream.value('29/02/2567\r/submit\r'), output),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<CivilDate>).value.year, 2024);
    expect(output.toString(), contains('ISO date: 2024-02-29'));
  });
}
