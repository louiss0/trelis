import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

CronPreviewConfig config() => CronPreviewConfig(
  zone: 'Etc/UTC',
  reference: DateTime.utc(2024),
  start: DateTime.utc(2024),
  end: DateTime.utc(2024, 1, 1, 0, 3),
  count: 1,
  budget: 3,
);

void main() {
  test('invalid linear draft remains editable and can be submitted', () async {
    final output = StringBuffer();
    final result =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: config(),
        ).prompt(
          source: ScriptedInput(
            Stream.value('bad\r\x7f\x7f\x7f* * * * *\r/submit\r'),
            output,
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<CronExpression>).value.expression, '* * * * *');
    expect(output.toString(), contains('Invalid cron expression'));
  });
  test('end of stream during review does not accept a draft', () async {
    final result =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: config(),
        ).prompt(
          source: ScriptedInput(Stream.value('* * * * *\r'), StringBuffer()),
          mode: PromptMode.linear,
        );
    expect(result, isA<InputEnded<CronExpression>>());
  });
  test('rich review interruption does not accept a draft', () async {
    final result =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: config(),
        ).prompt(
          source: ScriptedInput(
            Stream.value('* * * * *\r\x03'),
            StringBuffer(),
          ),
          mode: PromptMode.rich,
        );
    expect(result, isA<Interrupted<CronExpression>>());
  });
}
