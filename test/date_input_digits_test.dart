import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'native digits and ASCII can differ by field but not inside one field',
    () async {
      final input = DateInput(
        'Date',
        order: DateFieldOrder.dayMonthYear,
        calendar: DateCalendar.buddhist,
        digits: DateDigits.thai,
      );
      final result = await input.prompt(
        source: SuppliedAnswer('\u0e52\u0e59/02/\u0e52\u0e55\u0e56\u0e57'),
      );
      expect((result as Accepted<CivilDate>).value.year, 2024);
      expect(
        await input.prompt(
          source: SuppliedAnswer('\u0e529/02/\u0e52\u0e55\u0e56\u0e57'),
        ),
        isA<Unavailable>(),
      );
    },
  );
}
