import 'package:trelis/src/testing/compat_api.dart';

Future<void> main() async {
  final accepted = await CronInput(
    'Schedule',
    profile: CronProfile.unix,
  ).prompt(source: SuppliedAnswer('0 0 1-31/9223372036854775807 * *'));
  final expression = (accepted as Accepted<CronExpression>).value;
  final result = await expression.preview(
    CronPreviewConfig(
      providerTimeout: const Duration(seconds: 5),
      zone: 'Etc/UTC',
      reference: DateTime.utc(2023, 12, 31, 23, 59),
      start: DateTime.utc(2023, 12, 31, 23, 59),
      end: DateTime.utc(2024),
      count: 1,
      budget: 1,
    ),
  );
  print(result.instants.single.toIso8601String());
}
