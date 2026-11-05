import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Buddhist modern range and leap rules are strict at boundaries',
    () async {
      final input = DateInput(
        'Date',
        order: DateFieldOrder.dayMonthYear,
        calendar: DateCalendar.buddhist,
      );
      for (final bad in [
        '31/12/2483',
        '29/02/2643',
        '31/04/2567',
        '1/1/0000',
      ]) {
        expect(
          await input.prompt(source: SuppliedAnswer(bad)),
          isA<Unavailable>(),
          reason: bad,
        );
      }
      final first = (await input.prompt(
        source: SuppliedAnswer('1/1/2484'),
      ) as Accepted<CivilDate>).value;
      expect(
        (first.year, first.month, first.day, first.inputYear),
        (1941, 1, 1, 2484),
      );
      final upper = (await input.prompt(
        source: SuppliedAnswer('31/12/9999'),
      ) as Accepted<CivilDate>).value;
      expect((upper.year, upper.month, upper.day), (9456, 12, 31));
    },
  );
}
