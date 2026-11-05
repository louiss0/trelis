import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('default remains editable after review', () async {
    final out = StringBuffer();
    final value =
        await DateInput(
          'Date',
          order: DateFieldOrder.dayMonthYear,
          initialValue: '28/02/2024',
        ).prompt(
          source: ScriptedInput(
            Stream.value('\r/edit\r\x7f\x7f\x7f\x7f2020\r/submit\r'),
            out,
          ),
          mode: PromptMode.linear,
        );
    expect((value as Accepted<CivilDate>).value.year, 2020);
    expect(out.toString(), contains('ISO date: 2024-02-28'));
  });
  test('invalid default is rejected at construction', () {
    expect(
      () => DateInput(
        'Date',
        order: DateFieldOrder.dayMonthYear,
        initialValue: '31/02/2024',
      ),
      throwsArgumentError,
    );
  });
}
