import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'explicit Gregorian override accepts a leap day as a civil date',
    () async {
      final result = await DateInput(
        'Date',
        order: DateFieldOrder.dayMonthYear,
      ).prompt(source: SuppliedAnswer('29/02/2024'));
      expect(result, isA<Accepted<CivilDate>>());
      final date = (result as Accepted<CivilDate>).value;
      expect((date.year, date.month, date.day), (2024, 2, 29));
    },
  );
}
