import 'package:prompty/prompty.dart';
import 'package:test/test.dart';
import 'package:timezone/timezone.dart' as timezone;

void failInitialization() => throw timezone.TimeZoneInitException('injected');
void hangInitialization() {
  while (true) {}
}

CronPreviewConfig config(void Function() initializer) => CronPreviewConfig(
  zone: 'Etc/UTC',
  reference: DateTime.utc(2024),
  start: DateTime.utc(2024),
  end: DateTime.utc(2024, 1, 1, 0, 3),
  count: 1,
  budget: 3,
  providerTimeout: const Duration(milliseconds: 200),
  providerInitializer: initializer,
);

void main() {
  test('provider timeout must be explicitly positive', () {
    expect(
      () => CronPreviewConfig(
        zone: 'Etc/UTC',
        reference: DateTime.utc(2024),
        start: DateTime.utc(2024),
        end: DateTime.utc(2025),
        count: 1,
        budget: 1,
        providerTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
  test(
    'initialization failure reports provider error and preserves draft',
    () async {
      final out = StringBuffer();
      final result =
          await CronInput(
            'Schedule',
            profile: CronProfile.unix,
            preview: config(failInitialization),
          ).prompt(
            source: ScriptedInput(
              Stream.value('* * * * *\r/preview\r/submit\r'),
              out,
            ),
            mode: PromptMode.linear,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      expect(out.toString(), contains('providerError'));
    },
  );
  test('cancellation stops waiting on a hung provider', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.unix,
    ).prompt(source: SuppliedAnswer('* * * * *'));
    final expression = (result as Accepted<CronExpression>).value;
    var cancelled = false;
    final preview = expression.preview(
      CronPreviewConfig(
        zone: 'Etc/UTC',
        reference: DateTime.utc(2024),
        start: DateTime.utc(2024),
        end: DateTime.utc(2024, 1, 1, 0, 3),
        count: 1,
        budget: 3,
        providerTimeout: const Duration(seconds: 5),
        providerInitializer: hangInitialization,
        isCancelled: () => cancelled,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    cancelled = true;
    expect(
      (await preview.timeout(const Duration(seconds: 2))).status,
      CronPreviewStatus.cancelled,
    );
  });
  test('hung provider is stopped and reported as timed out', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.unix,
    ).prompt(source: SuppliedAnswer('* * * * *'));
    final expression = (result as Accepted<CronExpression>).value;
    final preview = await expression
        .preview(config(hangInitialization))
        .timeout(const Duration(seconds: 3));
    expect(preview.status, CronPreviewStatus.providerTimedOut);
    expect(preview.instants, isEmpty);
  });
}
