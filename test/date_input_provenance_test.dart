import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'accepted Buddhist date records calendar identity and provider provenance',
    () async {
      final value =
          (await DateInput(
                    'Date',
                    calendar: DateCalendar.buddhist,
                    order: DateFieldOrder.dayMonthYear,
                  ).prompt(source: SuppliedAnswer('29/2/2567'))
                  as Accepted<CivilDate>)
              .value;
      expect(value.provider, 'prompty-civil-arithmetic-v1');
      expect(value.era, 'BE');
      expect(value.monthIdentity, 'M02');
      expect(value.isLeapMonth, false);
    },
  );
}
