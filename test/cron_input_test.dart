import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
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
  test('Quartz accepts last day of month', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(source: SuppliedAnswer('0 0 12 L * ?'));
    expect(result, isA<Accepted<CronExpression>>());
  });
}
