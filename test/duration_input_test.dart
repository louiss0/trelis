import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

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
  test('signed elapsed accepts a global negative sign', () async {
    final result = await DurationInput(
      'Duration',
      durationMode: DurationInputMode.elapsed,
      signed: true,
    ).prompt(source: SuppliedAnswer('-1h 30m'));
    expect(
      (result as Accepted<DurationValue>).value.microseconds,
      BigInt.from(-5400000000),
    );
  });
  test(
    'calendar zero can be explicitly forbidden without ordering periods',
    () async {
      final input = DurationInput(
        'Period',
        durationMode: DurationInputMode.calendarRelative,
        allowZero: false,
      );
      expect(
        await input.prompt(source: SuppliedAnswer('0y 0s')),
        isA<Unavailable>(),
      );
      final result = await input.prompt(
        source: SuppliedAnswer('1mo 2d 0.5s'),
      ) as Accepted<DurationValue>;
      expect(result.value.components, {'mo': BigInt.one, 'd': BigInt.from(2)});
      expect(result.value.microseconds, BigInt.from(500000));
    },
  );
  test('rich and linear review valid interpretation while editing and withdraw stale preview', () async {
    for (final mode in [PromptMode.rich, PromptMode.linear]) {
      final output = StringBuffer();
      final result =
          await DurationInput(
            'Span',
            durationMode: DurationInputMode.elapsed,
          ).prompt(
            source: ScriptedInput(
              Stream.value('1sX\x7f\r'),
              output,
              outputProfile: mode == PromptMode.rich
                  ? _richProfile
                  : const OutputProfile(),
            ),
            mode: mode,
          );
      expect(result, isA<Accepted<DurationValue>>());
      expect(
        output.toString(),
        contains('Elapsed interpretation: 1000000 microseconds'),
      );
      expect(output.toString(), contains('Interpretation unavailable'));
    }
  });
  test('token grammar rejects ambiguous invalid or inexact values', () async {
    final elapsed = DurationInput(
      'Span',
      durationMode: DurationInputMode.elapsed,
      signed: true,
    );
    for (final value in [
      '1mo',
      '1y',
      '1M',
      '1s 2s',
      '1h -2m',
      '--1s',
      '1,5s',
      '.5s',
      'Ã™Â¡s',
      '1e3s',
      '1h30m',
      '1 s',
      ' 1s',
      '1s ',
      '0.1us',
      '9223372036854775808us',
    ]) {
      expect(
        await elapsed.prompt(source: SuppliedAnswer(value)),
        isA<Unavailable>(),
        reason: value,
      );
    }
    for (final value in ['1.5d', '1.0mo', '0.1us', '1d 1d']) {
      expect(
        await DurationInput(
          'Period',
          durationMode: DurationInputMode.calendarRelative,
        ).prompt(source: SuppliedAnswer(value)),
        isA<Unavailable>(),
        reason: value,
      );
    }
  });
  test(
    'exact fractions and limits retain spelling and distinction of modes',
    () async {
      final elapsed = DurationInput(
        'Span',
        durationMode: DurationInputMode.elapsed,
      );
      for (final pair in [
        ('0.001ms', 1),
        ('0.000001s', 1),
        ('1d', 86400000000),
        ('60m', 3600000000),
      ]) {
        final v = (await elapsed.prompt(
          source: SuppliedAnswer(pair.$1),
        ) as Accepted<DurationValue>).value;
        expect(v.draft, pair.$1);
        expect(v.microseconds, BigInt.from(pair.$2));
      }
      final period =
          (await DurationInput(
                    'Period',
                    durationMode: DurationInputMode.calendarRelative,
                    signed: true,
                  ).prompt(source: SuppliedAnswer('-1y 2mo 3w 4d 1.5h'))
                  as Accepted<DurationValue>)
              .value;
      expect(period.draft, '-1y 2mo 3w 4d 1.5h');
      expect(period.components, {
        'y': BigInt.from(-1),
        'mo': BigInt.from(-2),
        'w': BigInt.from(-3),
        'd': BigInt.from(-4),
      });
      expect(period.microseconds, BigInt.from(-5400000000));
      expect(
        (await elapsed.prompt(
          source: SuppliedAnswer('9223372036854775807us'),
        ) as Accepted<DurationValue>).value.microseconds,
        BigInt.parse('9223372036854775807'),
      );
    },
  );
  test(
    'minimum and nonnegative rules apply without treating zero as cancellation',
    () async {
      final input = DurationInput(
        'Span',
        durationMode: DurationInputMode.elapsed,
        minimumMicroseconds: 1,
      );
      expect(
        await input.prompt(source: SuppliedAnswer('0s')),
        isA<Unavailable>(),
      );
      expect(
        await input.prompt(source: SuppliedAnswer('1us')),
        isA<Accepted<DurationValue>>(),
      );
      expect(
        await DurationInput(
          'Span',
          durationMode: DurationInputMode.elapsed,
        ).prompt(source: SuppliedAnswer('-1s')),
        isA<Unavailable>(),
      );
      expect(
        await DurationInput(
          'Period',
          durationMode: DurationInputMode.calendarRelative,
        ).prompt(source: SuppliedAnswer('0d')),
        isA<Accepted<DurationValue>>(),
      );
    },
  );
  test('invalid drafts remain editable in both interaction modes', () async {
    for (final mode in [PromptMode.rich, PromptMode.linear]) {
      final output = StringBuffer();
      final result =
          await DurationInput(
            'Span',
            durationMode: DurationInputMode.elapsed,
          ).prompt(
            source: ScriptedInput(
              Stream.value('1s 1s\r\x7f\x7f\x7f\r'),
              output,
              outputProfile: mode == PromptMode.rich
                  ? _richProfile
                  : const OutputProfile(),
            ),
            mode: mode,
          );
      expect((result as Accepted<DurationValue>).value.draft, '1s');
      expect(output.toString(), contains('Invalid duration'));
    }
  });
  test('outcomes and initial values use shared prompt semantics', () async {
    final input = DurationInput(
      'Span',
      durationMode: DurationInputMode.elapsed,
      initialValue: '1s',
    );
    expect(
      await input.prompt(
        source: ScriptedInput(
          (() async* {
            yield '\x1b';
            await Future<void>.delayed(const Duration(milliseconds: 200));
          })(),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<Cancelled>(),
    );
    expect(
      await input.prompt(
        source: ScriptedInput(
          Stream.value('\x03'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<Interrupted>(),
    );
    expect(
      await input.prompt(
        source: ScriptedInput(const Stream.empty(), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<InputEnded>(),
    );
    expect(
      () => DurationInput(
        'Span',
        durationMode: DurationInputMode.elapsed,
        initialValue: '1mo',
      ),
      throwsArgumentError,
    );
    expect(
      () => DurationInput(
        'Span',
        durationMode: DurationInputMode.calendarRelative,
        minimumMicroseconds: 0,
      ),
      throwsArgumentError,
    );
  });
  test(
    'unit prefixes distinguish minutes milliseconds microseconds and months',
    () async {
      final elapsed =
          (await DurationInput(
                    'Duration',
                    durationMode: DurationInputMode.elapsed,
                  ).prompt(source: SuppliedAnswer('1m 1ms 1us'))
                  as Accepted<DurationValue>)
              .value;
      expect(elapsed.microseconds, BigInt.from(60001001));
      final calendar =
          (await DurationInput(
                    'Period',
                    durationMode: DurationInputMode.calendarRelative,
                  ).prompt(source: SuppliedAnswer('1mo 1m'))
                  as Accepted<DurationValue>)
              .value;
      expect(calendar.components['mo'], BigInt.one);
      expect(calendar.microseconds, BigInt.from(60000000));
    },
  );
  test(
    'overflow checks include sums and calendar component magnitude',
    () async {
      final elapsed = DurationInput(
        'Duration',
        durationMode: DurationInputMode.elapsed,
      );
      expect(
        await elapsed.prompt(
          source: SuppliedAnswer('9223372036854775807us 1ms'),
        ),
        isA<Unavailable>(),
      );
      final calendar = DurationInput(
        'Period',
        durationMode: DurationInputMode.calendarRelative,
      );
      expect(
        await calendar.prompt(source: SuppliedAnswer('9223372036854775808y')),
        isA<Unavailable>(),
      );
      expect(
        await calendar.prompt(source: SuppliedAnswer('9223372036854775807y')),
        isA<Accepted<DurationValue>>(),
      );
    },
  );
}
