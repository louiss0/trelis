import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  for (final entry in [
    (DateFieldOrder.dayMonthYear, '29/2/2567'),
    (DateFieldOrder.monthDayYear, '2/29/2567'),
    (DateFieldOrder.yearMonthDay, '2567/2/29'),
  ]) {
    test(
      'Buddhist explicit profile preserves ${entry.$1.name} interpretation',
      () async {
        final input = DateInput(
          'Date',
          order: entry.$1,
          calendar: DateCalendar.buddhist,
        );
        final result = await input.prompt(source: SuppliedAnswer(entry.$2));
        final date = (result as Accepted<CivilDate>).value;
        expect(
          (date.year, date.month, date.day, date.inputYear, date.era),
          (2024, 2, 29, 2567, 'BE'),
        );
      },
    );
  }
  test(
    'native repertoire is applied per field without reinterpreting calendar',
    () async {
      final input = DateInput(
        'Date',
        order: DateFieldOrder.yearMonthDay,
        calendar: DateCalendar.buddhist,
        digits: DateDigits.arabicIndic,
      );
      final result = await input.prompt(
        source: SuppliedAnswer('\u0662\u0665\u0666\u0667/2/\u0662\u0669'),
      );
      expect((result as Accepted<CivilDate>).value.year, 2024);
      expect(
        await input.prompt(source: SuppliedAnswer('\u0662567/2/29')),
        isA<Unavailable>(),
      );
    },
  );
}
