import 'dart:async';
import 'dart:io';

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
      expect((result as Accepted<NumericAnswer?>).value?.spelling, '123');
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
    expect(
      (result as Accepted<NumericAnswer?>).value?.spelling,
      '9007199254740993.0123456789',
    );
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
      ) as Accepted<NumericAnswer?>).value?.spelling,
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
      expect((result as Accepted<NumericAnswer?>).value?.spelling, '12');
    }
  });

  test('optional empty input returns absence rather than zero', () async {
    final input = NumberInput(
      'Amount',
      convention: NumericConvention.ascii(),
      required: false,
    );
    final result = await input.prompt(source: SuppliedAnswer(''));
    expect((result as Accepted<NumericAnswer?>).value?.spelling, isNull);
  });

  test('overlapping sessions on one input are rejected', () async {
    final input = NumberInput('Count', convention: NumericConvention.ascii());
    final stream = StreamController<String>();
    final pending = input.prompt(
      source: ScriptedInput(stream.stream, StringBuffer()),
    );
    await expectLater(
      input.prompt(source: SuppliedAnswer('2')),
      throwsStateError,
    );
    stream.add('1\r');
    expect((await pending as Accepted<NumericAnswer?>).value?.spelling, '1');
    await stream.close();
    expect(await input.prompt(source: SuppliedAnswer('2')), isA<Accepted>());
  });

  test('convention provider resolves once per prompt and override takes precedence', () async {
    var resolutions = 0;
    NumericConvention? provider() {
      resolutions++;
      return NumericConvention.ascii();
    }

    final input = NumberInput('Count', conventionProvider: provider);
    expect(await input.prompt(source: SuppliedAnswer('123')), isA<Accepted>());
    expect(resolutions, 1);
    final override = NumberInput(
      'Count',
      convention: NumericConvention.ascii(),
      conventionProvider: provider,
    );
    expect(
      await override.prompt(source: SuppliedAnswer('123')),
      isA<Accepted>(),
    );
    expect(resolutions, 1);
    expect(
      await NumberInput(
        'Count',
        conventionProvider: () => null,
      ).prompt(source: SuppliedAnswer('123')),
      isA<Unavailable>(),
    );
  });

  test('ambiguous or nonnumeric conventions are rejected at construction', () {
    for (final digits in ['abcdefghij', '012345678a']) {
      expect(
        () => NumericConvention(
          decimalSeparator: '.',
          groupingSeparator: ',',
          grouping: [3],
          nativeDigits: digits,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => NumericConvention(
        decimalSeparator: '-',
        groupingSeparator: ',',
        grouping: [3],
        nativeDigits: '0123456789',
      ),
      throwsArgumentError,
    );
    expect(
      () => NumericConvention(
        decimalSeparator: '.',
        groupingSeparator: '1',
        grouping: [3],
        nativeDigits: '٠١٢٣٤٥٦٧٨٩',
      ),
      throwsArgumentError,
    );
  });

  test(
    'accepted answer exposes spelling separately from exact decimal meaning',
    () async {
      final result = await NumberInput(
        'Amount',
        convention: NumericConvention(
          decimalSeparator: ',',
          groupingSeparator: '.',
          grouping: [3],
          nativeDigits: '٠١٢٣٤٥٦٧٨٩',
        ),
        decimal: true,
      ).prompt(source: SuppliedAnswer('١.٢٣٤,٥٠'));
      final answer = (result as Accepted<NumericAnswer?>).value!;
      expect(answer.spelling, '١.٢٣٤,٥٠');
      expect(answer.coefficient, BigInt.from(123450));
      expect(answer.scale, 2);
    },
  );

  test(
    'configured trailing negative sign is required for negative numbers',
    () async {
      final convention = NumericConvention(
        decimalSeparator: '.',
        groupingSeparator: ',',
        grouping: [3],
        nativeDigits: '0123456789',
        negativeSign: '~',
        negativePattern: NumericNegativePattern.trailing,
      );
      final input = NumberInput('Count', convention: convention);
      final answer = (await input.prompt(
        source: SuppliedAnswer('123~'),
      ) as Accepted<NumericAnswer?>).value!;
      expect(answer.coefficient, BigInt.from(-123));
      for (final text in ['-123', '~123', '123-', '123~~']) {
        expect(
          await input.prompt(source: SuppliedAnswer(text)),
          isA<Unavailable>(),
        );
      }
    },
  );

  test('Windows default resolves effective system numeric settings', () async {
    if (!Platform.isWindows) return;
    final result = await NumberInput('Count')
        .prompt(source: SuppliedAnswer('123'));
    expect(
      (result as Accepted<NumericAnswer?>).value!.coefficient,
      BigInt.from(123),
    );
  });

  test('editing discloses the active convention and an example', () async {
    final output = StringBuffer();
    await NumberInput('Count', convention: NumericConvention.ascii()).prompt(
      source: ScriptedInput(Stream.value('12\r'), output),
      mode: PromptMode.linear,
    );
    expect(output.toString(), contains('decimal separator .'));
    expect(output.toString(), contains('grouping separator ,'));
    expect(output.toString(), contains('negative example -123'));
  });

  test('format and exact constraints are stated before editing', () async {
    final output = StringBuffer();
    await NumberInput(
      'Amount',
      convention: NumericConvention.ascii(),
      decimal: true,
      minimum: '0.01',
      maximum: '10.00',
      precision: 2,
    ).prompt(
      source: ScriptedInput(Stream.value('1\r'), output),
      mode: PromptMode.linear,
    );
    expect(output.toString(), contains('decimal mode'));
    expect(output.toString(), contains('minimum 0.01'));
    expect(output.toString(), contains('maximum 10.00'));
    expect(output.toString(), contains('maximum 2 decimal places'));
  });

  test('preference changes do not reinterpret an active draft', () async {
    var current = NumericConvention.ascii();
    final input = NumberInput(
      'Amount',
      decimal: true,
      conventionProvider: () => current,
    );
    final stream = StreamController<String>();
    final pending = input.prompt(
      source: ScriptedInput(stream.stream, StringBuffer()),
      mode: PromptMode.linear,
    );
    stream.add('1,234');
    await Future<void>.delayed(Duration.zero);
    current = NumericConvention(
      decimalSeparator: ',',
      groupingSeparator: '.',
      grouping: [3],
      nativeDigits: '0123456789',
    );
    stream.add('\r');
    final answer = (await pending as Accepted<NumericAnswer?>).value!;
    expect(answer.coefficient, BigInt.from(1234));
    expect(answer.scale, 0);
    await stream.close();
    final next = (await input.prompt(
      source: SuppliedAnswer('1,234'),
    ) as Accepted<NumericAnswer?>).value!;
    expect(next.coefficient, BigInt.from(1234));
    expect(next.scale, 3);
  });

  test(
    'an ungrouped-only convention rejects all grouping separators',
    () async {
      final convention = NumericConvention(
        decimalSeparator: '.',
        groupingSeparator: '',
        grouping: [],
        nativeDigits: '0123456789',
      );
      final input = NumberInput(
        'Amount',
        convention: convention,
        decimal: true,
      );
      expect(
        await input.prompt(source: SuppliedAnswer('1234.5')),
        isA<Accepted>(),
      );
      expect(
        await input.prompt(source: SuppliedAnswer('1,234.5')),
        isA<Unavailable>(),
      );
      final output = StringBuffer();
      await input.prompt(
        source: ScriptedInput(Stream.value('1\r'), output),
        mode: PromptMode.linear,
      );
      expect(output.toString(), contains('grouping not supported'));
    },
  );

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
