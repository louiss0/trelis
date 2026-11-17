import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

void main() {
  test('date input rejects an empty prompt label', () {
    expect(() => DateInput(''), throwsArgumentError);
  });

  test('malformed supplied date is never accepted', () async {
    final result = await DateInput('Date')
        .prompt(source: SuppliedAnswer('not a date'));
    expect(result, isA<Unavailable>());
  });
}
