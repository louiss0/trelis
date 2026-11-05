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
  test('Quartz accepts last day of month', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(source: SuppliedAnswer('0 0 12 L * ?'));
    expect(result, isA<Accepted<CronExpression>>());
  });
}
