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
  test('Quartz last-day offset weekday resolves nearest weekday', () async {
    final match = await preview(
      '0 0 0 L-2W * ?',
      CronProfile.quartz,
      DateTime.utc(2024, 6, 28),
    );
    final nonmatch = await preview(
      '0 0 0 L-2W * ?',
      CronProfile.quartz,
      DateTime.utc(2024, 6, 29),
    );
    expect(match.instants, [DateTime.utc(2024, 6, 28)]);
    expect(nonmatch.instants, isEmpty);
  });
  test('Quartz standalone weekday L means Saturday', () async {
    final match = await preview(
      '0 0 0 ? * L',
      CronProfile.quartz,
      DateTime.utc(2024, 1, 6),
    );
    final nonmatch = await preview(
      '0 0 0 ? * L',
      CronProfile.quartz,
      DateTime.utc(2024, 1, 7),
    );
    expect(match.instants, [DateTime.utc(2024, 1, 6)]);
    expect(nonmatch.instants, isEmpty);
  });
  test('oversized Quartz expression is rejected before parsing', () async {
    final expression = '${'0,' * 2100}0 0 0 ? * MON';
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(source: SuppliedAnswer(expression));
    expect(result, isA<Unavailable<CronExpression>>());
  });
  test('hostile malformed fields do not become valid schedules', () async {
    final cases = <CronProfile, List<String>>{
      CronProfile.unix: [
        '*/0 * * * *',
        '0 0 0 * *',
        '0 0 * 13 *',
        '0 0 * * 8',
        '@daily',
        '0 0 * * * command',
        '9${'9' * 1000} 0 * * *',
      ],
      CronProfile.quartz: [
        '0/0 * * ? * MON',
        '*/999 * * ? * MON',
        '0 0 0 L-31W * ?',
        '0 0 0 ? * MON#6',
        '0 0 0 ? * 8',
        '0 0 0 ? * MON 2200',
        '0 0 0 ? * MON extra',
      ],
    };
    for (final entry in cases.entries) {
      for (final expression in entry.value) {
        final result = await CronInput(
          'Schedule',
          profile: entry.key,
        ).prompt(source: SuppliedAnswer(expression));
        expect(result, isA<Unavailable<CronExpression>>(), reason: expression);
      }
    }
  });
  test(
    'empty horizon at maximum UTC instant reports horizon, not overflow',
    () async {
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(source: SuppliedAnswer('* * * * *'));
      final expression = (result as Accepted<CronExpression>).value;
      final maximum = DateTime.fromMicrosecondsSinceEpoch(
        8640000000000000000,
        isUtc: true,
      );
      final resultPreview = await expression.preview(
        CronPreviewConfig(
          zone: 'Etc/UTC',
          reference: maximum,
          start: maximum,
          end: maximum,
          count: 1,
          budget: 1,
        ),
      );
      expect(resultPreview.status, CronPreviewStatus.horizonReached);
      expect(resultPreview.instants, isEmpty);
    },
  );
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
