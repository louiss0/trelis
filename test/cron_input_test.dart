import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('preview is strictly after the reference and stays in bounds', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.unix,
    ).prompt(source: SuppliedAnswer('* * * * *'));
    final expression = (result as Accepted<CronExpression>).value;
    final preview = await expression.preview(
      CronPreviewConfig(
        zone: 'Etc/UTC',
        reference: DateTime.utc(2024, 1, 1),
        start: DateTime.utc(2024, 1, 1),
        end: DateTime.utc(2024, 1, 1, 0, 3),
        count: 2,
        budget: 3,
      ),
    );
    expect(preview.instants, [
      DateTime.utc(2024, 1, 1, 0, 1),
      DateTime.utc(2024, 1, 1, 0, 2),
    ]);
  });
  test('preview rounds negative reference instants forward', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.unix,
    ).prompt(source: SuppliedAnswer('* * * * *'));
    final expression = (result as Accepted<CronExpression>).value;
    final preview = await expression.preview(
      CronPreviewConfig(
        zone: 'Etc/UTC',
        reference: DateTime.utc(1969, 12, 31, 23, 58, 30),
        start: DateTime.utc(1969, 12, 31, 23, 58),
        end: DateTime.utc(1970),
        count: 1,
        budget: 1,
      ),
    );
    expect(preview.instants, [DateTime.utc(1969, 12, 31, 23, 59)]);
  });
  test(
    'Unix restricted day fields match either day of month or weekday',
    () async {
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(source: SuppliedAnswer('0 0 2 * MON'));
      final expression = (result as Accepted<CronExpression>).value;
      final preview = await expression.preview(
        CronPreviewConfig(
          zone: 'Etc/UTC',
          reference: DateTime.utc(2023, 12, 31),
          start: DateTime.utc(2024),
          end: DateTime.utc(2024, 1, 8),
          count: 3,
          budget: 11000,
        ),
      );
      expect(preview.instants, [
        DateTime.utc(2024, 1, 1),
        DateTime.utc(2024, 1, 2),
        DateTime.utc(2024, 1, 8),
      ]);
    },
  );
  test(
    'preview skips a nonexistent New York spring-forward civil time',
    () async {
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(source: SuppliedAnswer('30 2 * * *'));
      final expression = (result as Accepted<CronExpression>).value;
      final preview = await expression.preview(
        CronPreviewConfig(
          zone: 'America/New_York',
          reference: DateTime.utc(2024, 3, 10, 5),
          start: DateTime.utc(2024, 3, 10, 5),
          end: DateTime.utc(2024, 3, 11, 8),
          count: 1,
          budget: 2000,
        ),
      );
      expect(preview.instants, [DateTime.utc(2024, 3, 11, 6, 30)]);
    },
  );
  test('preview distinguishes exhausted work budget from horizon', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.unix,
    ).prompt(source: SuppliedAnswer('0 0 * * *'));
    final expression = (result as Accepted<CronExpression>).value;
    CronPreviewConfig config(int budget) => CronPreviewConfig(
      zone: 'Etc/UTC',
      reference: DateTime.utc(2024),
      start: DateTime.utc(2024),
      end: DateTime.utc(2024, 1, 1, 0, 2),
      count: 1,
      budget: budget,
    );
    expect(
      (await expression.preview(config(1))).status,
      CronPreviewStatus.budgetExhausted,
    );
    expect(
      (await expression.preview(config(3))).status,
      CronPreviewStatus.horizonReached,
    );
  });
  test('preview includes both instants in a New York fall overlap', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.unix,
    ).prompt(source: SuppliedAnswer('30 1 * * *'));
    final expression = (result as Accepted<CronExpression>).value;
    final preview = await expression.preview(
      CronPreviewConfig(
        zone: 'America/New_York',
        reference: DateTime.utc(2024, 11, 3, 4),
        start: DateTime.utc(2024, 11, 3, 4),
        end: DateTime.utc(2024, 11, 3, 8),
        count: 2,
        budget: 240,
      ),
    );
    expect(preview.instants, [
      DateTime.utc(2024, 11, 3, 5, 30),
      DateTime.utc(2024, 11, 3, 6, 30),
    ]);
  });
  test('Quartz preview matches the last day in a leap year', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(source: SuppliedAnswer('0 0 0 L * ?'));
    final expression = (result as Accepted<CronExpression>).value;
    final preview = await expression.preview(
      CronPreviewConfig(
        zone: 'Etc/UTC',
        reference: DateTime.utc(2024, 2, 28, 23, 59),
        start: DateTime.utc(2024, 2, 28, 23, 59),
        end: DateTime.utc(2024, 2, 29, 0, 1),
        count: 1,
        budget: 61,
      ),
    );
    expect(preview.instants, [DateTime.utc(2024, 2, 29)]);
  });
  test('preview cancellation stops a bounded search', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.unix,
    ).prompt(source: SuppliedAnswer('0 0 31 2 *'));
    final expression = (result as Accepted<CronExpression>).value;
    var cancelled = false;
    Future<void>.delayed(Duration.zero, () {
      cancelled = true;
    });
    final preview = await expression.preview(
      CronPreviewConfig(
        zone: 'Etc/UTC',
        reference: DateTime.utc(2024),
        start: DateTime.utc(2024),
        end: DateTime.utc(2025),
        count: 1,
        budget: 100000,
        isCancelled: () => cancelled,
      ),
    );
    expect(preview.status, CronPreviewStatus.cancelled);
    expect(preview.instants, isEmpty);
  });
  test(
    'unknown zone reports provider error without returning a match',
    () async {
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(source: SuppliedAnswer('* * * * *'));
      final expression = (result as Accepted<CronExpression>).value;
      final preview = await expression.preview(
        CronPreviewConfig(
          zone: 'Invalid/Zone',
          reference: DateTime.utc(2024),
          start: DateTime.utc(2024),
          end: DateTime.utc(2024, 1, 2),
          count: 1,
          budget: 1,
        ),
      );
      expect(preview.status, CronPreviewStatus.providerError);
      expect(preview.instants, isEmpty);
    },
  );
  test('Quartz preview matches seconds lists and named weekdays', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(source: SuppliedAnswer('5,10 * * ? * MON'));
    final expression = (result as Accepted<CronExpression>).value;
    final preview = await expression.preview(
      CronPreviewConfig(
        zone: 'Etc/UTC',
        reference: DateTime.utc(2024, 1, 1),
        start: DateTime.utc(2024, 1, 1),
        end: DateTime.utc(2024, 1, 1, 0, 1),
        count: 2,
        budget: 60,
      ),
    );
    expect(preview.instants, [
      DateTime.utc(2024, 1, 1, 0, 0, 5),
      DateTime.utc(2024, 1, 1, 0, 0, 10),
    ]);
  });
  test('Quartz preview evaluates day special tokens', () async {
    final examples = <String, DateTime>{
      '0 0 0 L-1 * ?': DateTime.utc(2024, 2, 28),
      '0 0 0 LW * ?': DateTime.utc(2024, 8, 30),
      '0 0 0 1W * ?': DateTime.utc(2024, 6, 3),
      '0 0 0 ? * MON#1': DateTime.utc(2024, 7, 1),
      '0 0 0 ? * 6L': DateTime.utc(2024, 6, 28),
    };
    for (final entry in examples.entries) {
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.quartz,
      ).prompt(source: SuppliedAnswer(entry.key));
      final expression = (result as Accepted<CronExpression>).value;
      final start = entry.value.subtract(const Duration(seconds: 2));
      final preview = await expression.preview(
        CronPreviewConfig(
          zone: 'Etc/UTC',
          reference: start,
          start: start,
          end: entry.value,
          count: 1,
          budget: 2,
        ),
      );
      expect(preview.instants, [entry.value], reason: entry.key);
    }
  });
  test(
    'Unix preview finds historical sub-minute timezone offset matches',
    () async {
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(source: SuppliedAnswer('* * * * *'));
      final expression = (result as Accepted<CronExpression>).value;
      final preview = await expression.preview(
        CronPreviewConfig(
          zone: 'Africa/Monrovia',
          reference: DateTime.utc(1950, 1, 1),
          start: DateTime.utc(1950, 1, 1),
          end: DateTime.utc(1950, 1, 1, 0, 1),
          count: 1,
          budget: 60,
        ),
      );
      expect(preview.instants, [DateTime.utc(1950, 1, 1, 0, 0, 30)]);
    },
  );
  test('Quartz accepts second increments from a numeric start', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(source: SuppliedAnswer('0/15 * * ? * MON'));
    final expression = (result as Accepted<CronExpression>).value;
    final preview = await expression.preview(
      CronPreviewConfig(
        zone: 'Etc/UTC',
        reference: DateTime.utc(2024, 1, 1),
        start: DateTime.utc(2024, 1, 1),
        end: DateTime.utc(2024, 1, 1, 0, 1),
        count: 2,
        budget: 60,
      ),
    );
    expect(preview.instants, [
      DateTime.utc(2024, 1, 1, 0, 0, 15),
      DateTime.utc(2024, 1, 1, 0, 0, 30),
    ]);
  });
  test('Quartz preview reports out-of-profile search range', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(source: SuppliedAnswer('0 0 0 L * ?'));
    final expression = (result as Accepted<CronExpression>).value;
    final preview = await expression.preview(
      CronPreviewConfig(
        zone: 'Etc/UTC',
        reference: DateTime.utc(2200),
        start: DateTime.utc(2200),
        end: DateTime.utc(2201),
        count: 1,
        budget: 1,
      ),
    );
    expect(preview.status, CronPreviewStatus.unsupportedRange);
    expect(preview.instants, isEmpty);
  });
  test('Unix preview handles transitions into sub-minute offsets', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.unix,
    ).prompt(source: SuppliedAnswer('* * * * *'));
    final expression = (result as Accepted<CronExpression>).value;
    final preview = await expression.preview(
      CronPreviewConfig(
        zone: 'Africa/Lagos',
        reference: DateTime.utc(1908, 6, 30, 23, 59, 59),
        start: DateTime.utc(1908, 6, 30, 23, 59, 59),
        end: DateTime.utc(1908, 7, 1, 0, 1),
        count: 1,
        budget: 61,
      ),
    );
    expect(preview.instants, [DateTime.utc(1908, 7, 1, 0, 0, 25)]);
  });
  test('Unix expression retains its explicit profile and spelling', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.unix,
    ).prompt(source: SuppliedAnswer('0 12 * * MON'));
    final value = (result as Accepted<CronExpression>).value;
    expect(value.expression, '0 12 * * MON');
    expect(value.profile, CronProfile.unix);
  });
  test('Quartz accepts seconds and a question-mark day', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(source: SuppliedAnswer('0 0 12 ? * MON'));
    expect(result, isA<Accepted<CronExpression>>());
  });
  test('Quartz rejects out-of-range fields', () async {
    for (final expression in [
      '99 0 12 ? * MON',
      '0 0 12 ? 13 MON',
      '0 0 12 ? * MON 2200',
    ]) {
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.quartz,
      ).prompt(source: SuppliedAnswer(expression));
      expect(result, isA<Unavailable<CronExpression>>(), reason: expression);
    }
  });
  test('Quartz accepts a seconds range', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(source: SuppliedAnswer('0-10 0 12 ? * MON'));
    expect(result, isA<Accepted<CronExpression>>());
  });
  test('Quartz accepts bounded ranges in minute and hour fields', () async {
    final input = CronInput('Schedule', profile: CronProfile.quartz);
    final accepted = await input.prompt(
      source: SuppliedAnswer('0 10-20 8-17 ? * MON'),
    );
    expect(accepted, isA<Accepted<CronExpression>>());
    final rejected = await input.prompt(
      source: SuppliedAnswer('0 10-60 8 ? * MON'),
    );
    expect(rejected, isA<Unavailable<CronExpression>>());
  });
  test('Quartz accepts lists of seconds', () async {
    final input = CronInput('Schedule', profile: CronProfile.quartz);
    expect(
      await input.prompt(source: SuppliedAnswer('0,15,30,45 0 12 ? * MON')),
      isA<Accepted<CronExpression>>(),
    );
    expect(
      await input.prompt(source: SuppliedAnswer('0,60 0 12 ? * MON')),
      isA<Unavailable<CronExpression>>(),
    );
  });
  test('Quartz accepts last weekday of month', () async {
    final input = CronInput('Schedule', profile: CronProfile.quartz);
    expect(
      await input.prompt(source: SuppliedAnswer('0 0 12 LW * ?')),
      isA<Accepted<CronExpression>>(),
    );
    expect(
      await input.prompt(source: SuppliedAnswer('0 0 12 ? * LW')),
      isA<Unavailable<CronExpression>>(),
    );
  });
  test('Quartz nearest weekday is limited to days 1 through 31', () async {
    final input = CronInput('Schedule', profile: CronProfile.quartz);
    for (final day in ['1W', '15W', '31W']) {
      expect(
        await input.prompt(source: SuppliedAnswer('0 0 12 $day * ?')),
        isA<Accepted<CronExpression>>(),
        reason: day,
      );
    }
    for (final day in ['0W', '32W', '1W,2W']) {
      expect(
        await input.prompt(source: SuppliedAnswer('0 0 12 $day * ?')),
        isA<Unavailable<CronExpression>>(),
        reason: day,
      );
    }
  });
  test('Quartz nth weekday requires a valid weekday and ordinal', () async {
    final input = CronInput('Schedule', profile: CronProfile.quartz);
    for (final day in ['1#1', '7#5', 'MON#3']) {
      expect(
        await input.prompt(source: SuppliedAnswer('0 0 12 ? * $day')),
        isA<Accepted<CronExpression>>(),
        reason: day,
      );
    }
    for (final day in ['0#1', '8#1', 'MON#0', 'MON#6', 'MON#2,TUE#3']) {
      expect(
        await input.prompt(source: SuppliedAnswer('0 0 12 ? * $day')),
        isA<Unavailable<CronExpression>>(),
        reason: day,
      );
    }
  });
  test('Quartz last weekday token requires a valid weekday', () async {
    final input = CronInput('Schedule', profile: CronProfile.quartz);
    for (final day in ['1L', '7L', 'FRIL']) {
      expect(
        await input.prompt(source: SuppliedAnswer('0 0 12 ? * $day')),
        isA<Accepted<CronExpression>>(),
        reason: day,
      );
    }
    for (final day in ['0L', '8L', 'MONL,TUEL']) {
      expect(
        await input.prompt(source: SuppliedAnswer('0 0 12 ? * $day')),
        isA<Unavailable<CronExpression>>(),
        reason: day,
      );
    }
  });
  test('Quartz last day offset has bounded positive offset', () async {
    final input = CronInput('Schedule', profile: CronProfile.quartz);
    for (final day in ['L-1', 'L-30']) {
      expect(
        await input.prompt(source: SuppliedAnswer('0 0 12 $day * ?')),
        isA<Accepted<CronExpression>>(),
        reason: day,
      );
    }
    for (final day in ['L-0', 'L-31', 'L--1']) {
      expect(
        await input.prompt(source: SuppliedAnswer('0 0 12 $day * ?')),
        isA<Unavailable<CronExpression>>(),
        reason: day,
      );
    }
  });
  test('Quartz accepts last day of month', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(source: SuppliedAnswer('0 0 12 L * ?'));
    expect(result, isA<Accepted<CronExpression>>());
  });
}
