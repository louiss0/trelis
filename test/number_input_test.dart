import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'integer input accepts a supplied answer under an explicit convention',
    () async {
      final result = await NumberInput(
        'Count',
        convention: NumericConvention.ascii(),
      ).prompt(source: SuppliedAnswer('123'));
      expect((result as Accepted<String?>).value, '123');
    },
  );

  test('decimal input preserves exact decimal spelling', () async {
    final input = NumberInput(
      'Amount',
      convention: NumericConvention.ascii(),
      decimal: true,
    );
    final result = await input.prompt(
      source: SuppliedAnswer('9007199254740993.0123456789'),
    );
    expect((result as Accepted<String?>).value, '9007199254740993.0123456789');
    expect(
      await input.prompt(source: SuppliedAnswer('1e3')),
      isA<Unavailable>(),
    );
  });

  test('integer input rejects decimal and non-base-ten forms', () async {
    final input = NumberInput('Count', convention: NumericConvention.ascii());
    for (final value in ['1.0', '1e3', '0xff', 'NaN', 'Infinity', '2%', '']) {
      expect(
        await input.prompt(source: SuppliedAnswer(value)),
        isA<Unavailable>(),
      );
    }
  });
}
