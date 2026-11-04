import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('elapsed weeks and fractions have exact microsecond meaning', () async {
    final result = await DurationInput(
      'Duration',
      durationMode: DurationInputMode.elapsed,
    ).prompt(source: SuppliedAnswer('1w 0.5s'));
    expect(
      (result as Accepted<DurationValue>).value.microseconds,
      BigInt.from(604800500000),
    );
  });
}
