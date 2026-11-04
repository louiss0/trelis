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

  test('exact decimal bounds and precision reject without rounding', () async {
    final input = NumberInput(
      'Amount',
      convention: NumericConvention.ascii(),
      decimal: true,
      minimum: '9007199254740993.01',
      maximum: '9007199254740993.99',
      precision: 2,
    );
    expect(
      (await input.prompt(
        source: SuppliedAnswer('9007199254740993.02'),
      ) as Accepted<String?>).value,
      '9007199254740993.02',
    );
    for (final value in [
      '9007199254740993.009',
      '9007199254740993.00',
      '9007199254740994.00',
    ]) {
      expect(
        await input.prompt(source: SuppliedAnswer(value)),
        isA<Unavailable>(),
      );
    }
  });

  test(
    'localized grouping and native digits require consistent syntax',
    () async {
      final convention = NumericConvention(
        decimalSeparator: ',',
        groupingSeparator: '.',
        grouping: [3, 2],
        nativeDigits: '٠١٢٣٤٥٦٧٨٩',
      );
      final input = NumberInput(
        'Amount',
        convention: convention,
        decimal: true,
      );
      for (final value in ['12.34.567,89', '١٢.٣٤.٥٦٧,٨٩', '1234567,89']) {
        expect(
          await input.prompt(source: SuppliedAnswer(value)),
          isA<Accepted>(),
        );
      }
      for (final value in [
        '1.234.567,89',
        '12.٣٤.567,89',
        '12.34,5.67',
        '12,34,56',
      ]) {
        expect(
          await input.prompt(source: SuppliedAnswer(value)),
          isA<Unavailable>(),
        );
      }
    },
  );

  test('rich and linear sessions use the same numeric validation', () async {
    for (final mode in [PromptMode.rich, PromptMode.linear]) {
      final output = StringBuffer();
      final result = await NumberInput(
        'Count',
        convention: NumericConvention.ascii(),
      ).prompt(source: ScriptedInput(Stream.value('12\r'), output), mode: mode);
      expect((result as Accepted<String?>).value, '12');
    }
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
