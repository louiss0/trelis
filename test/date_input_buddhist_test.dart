import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Buddhist override converts a known leap date without a timestamp',
    () async {
      final result = await DateInput(
        'Date',
        order: DateFieldOrder.dayMonthYear,
        calendar: DateCalendar.buddhist,
      ).prompt(source: SuppliedAnswer('29/02/2567'));
      expect(result, isA<Accepted<CivilDate>>());
      final value = (result as Accepted<CivilDate>).value;
      expect((value.year, value.month, value.day), (2024, 2, 29));
      expect((value.inputYear, value.calendar), (2567, DateCalendar.buddhist));
    },
  );
}
