import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

Future<CronPreview> preview(
  String expression,
  CronProfile profile,
  DateTime at,
) async {
  final result = await CronInput(
    'Schedule',
    profile: profile,
  ).prompt(source: SuppliedAnswer(expression));
  final value = (result as Accepted<CronExpression>).value;
  final reference = at.subtract(const Duration(seconds: 1));
  return value.preview(
    CronPreviewConfig(
      zone: 'Etc/UTC',
      reference: reference,
      start: reference,
      end: at,
      count: 1,
      budget: 60,
    ),
  );
}

void main() {
  test('Cronie-style stepped day wildcard uses conjunction, not OR', () async {
    final mondayEven = await preview(
      '0 0 */2 * MON',
      CronProfile.unix,
      DateTime.utc(2024, 1, 8),
    );
    final mondayOdd = await preview(
      '0 0 */2 * MON',
      CronProfile.unix,
      DateTime.utc(2024, 1, 15),
    );
    expect(mondayEven.instants, isEmpty);
    expect(mondayEven.status, CronPreviewStatus.horizonReached);
    expect(mondayOdd.instants, [DateTime.utc(2024, 1, 15)]);
  });
  test('Unix Sunday 0 and 7 match the same civil date', () async {
    for (final weekday in ['0', '7', 'SUN']) {
      final match = await preview(
        '0 0 * * $weekday',
        CronProfile.unix,
        DateTime.utc(2024, 1, 7),
      );
      expect(match.instants, [DateTime.utc(2024, 1, 7)], reason: weekday);
    }
  });
  test('Quartz weekday numbering starts with Sunday at 1', () async {
    for (final weekday in ['1', 'SUN']) {
      final match = await preview(
        '0 0 0 ? * $weekday',
        CronProfile.quartz,
        DateTime.utc(2024, 1, 7),
      );
      expect(match.instants, [DateTime.utc(2024, 1, 7)], reason: weekday);
    }
  });
  test('Quartz rejects two specified days and two unspecified days', () async {
    for (final expression in ['0 0 12 1 * MON', '0 0 12 ? * ?']) {
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.quartz,
      ).prompt(source: SuppliedAnswer(expression));
      expect(result, isA<Unavailable<CronExpression>>(), reason: expression);
    }
  });
}
