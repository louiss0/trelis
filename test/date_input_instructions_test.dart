import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'instructions identify bounded calendar and example before entry',
    () async {
      final out = StringBuffer();
      final result =
          await DateInput(
            'Date',
            order: DateFieldOrder.dayMonthYear,
            calendar: DateCalendar.buddhist,
          ).prompt(
            source: ScriptedInput(const Stream.empty(), out),
            mode: PromptMode.linear,
          );
      expect(result, isA<InputEnded>());
      expect(out.toString(), contains('2484-9999'));
      expect(out.toString(), contains('29/2/2567'));
    },
  );
}
