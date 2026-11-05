import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('partial calendar override cannot be silently ignored', () {
    expect(
      () => DateInput('Date', calendar: DateCalendar.buddhist),
      throwsArgumentError,
    );
    expect(
      () => DateInput('Date', digits: DateDigits.thai),
      throwsArgumentError,
    );
  });
}
