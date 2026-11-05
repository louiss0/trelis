import 'dart:async';

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
  test('control-C interrupts an active preview', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final longConfig = CronPreviewConfig(
      zone: 'Etc/UTC',
      reference: DateTime.utc(2024),
      start: DateTime.utc(2024),
      end: DateTime.utc(2030),
      count: 1,
      budget: 2000000,
    );
    final result =
        CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: longConfig,
        ).prompt(
          source: ScriptedInput(input.stream, output),
          mode: PromptMode.linear,
        );
    input.add('0 0 31 2 *\r/preview\r');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(output.toString(), contains('Calculating preview'));
    input.add('\x03');
    expect(
      await result.timeout(const Duration(seconds: 3)),
      isA<Interrupted<CronExpression>>(),
    );
    await input.close();
  });
  test('linear cancel command cancels an active preview', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final longConfig = CronPreviewConfig(
      zone: 'Etc/UTC',
      reference: DateTime.utc(2024),
      start: DateTime.utc(2024),
      end: DateTime.utc(2030),
      count: 1,
      budget: 2000000,
    );
    final result =
        CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: longConfig,
        ).prompt(
          source: ScriptedInput(input.stream, output),
          mode: PromptMode.linear,
        );
    input.add('0 0 31 2 *\r/preview\r');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(output.toString(), contains('Calculating preview'));
    input.add('/cancel\r');
    expect(
      await result.timeout(const Duration(seconds: 3)),
      isA<Cancelled<CronExpression>>(),
    );
    expect(output.toString(), isNot(contains('Matching preview:')));
    await input.close();
  });
  test('hostile valid list remains interruptible during preview', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final longConfig = CronPreviewConfig(
      zone: 'Etc/UTC',
      reference: DateTime.utc(2024),
      start: DateTime.utc(2024),
      end: DateTime.utc(2030),
      count: 1,
      budget: 2000000,
    );
    final expression = '${'59,' * 1300}59 0 31 2 *';
    final result =
        CronInput(
          'Schedule',
          profile: CronProfile.unix,
          initialValue: expression,
          preview: longConfig,
        ).prompt(
          source: ScriptedInput(input.stream, output),
          mode: PromptMode.linear,
        );
    final watch = Stopwatch()..start();
    input.add('\r/preview\r');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(watch.elapsed, lessThan(const Duration(milliseconds: 750)));
    expect(output.toString(), contains('Calculating preview'));
    input.add('/cancel\r');
    expect(
      await result.timeout(const Duration(seconds: 3)),
      isA<Cancelled<CronExpression>>(),
    );
    expect(output.toString(), isNot(contains('Matching preview:')));
    await input.close();
  });
  test('escape cancels an active rich preview', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final longConfig = CronPreviewConfig(
      zone: 'Etc/UTC',
      reference: DateTime.utc(2024),
      start: DateTime.utc(2024),
      end: DateTime.utc(2030),
      count: 1,
      budget: 2000000,
    );
    final result =
        CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: longConfig,
        ).prompt(
          source: ScriptedInput(input.stream, output),
          mode: PromptMode.rich,
        );
    input.add('0 0 31 2 *\r\t\r');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(output.toString(), contains('Calculating preview'));
    input.add('\x1b');
    expect(
      await result.timeout(const Duration(seconds: 3)),
      isA<Cancelled<CronExpression>>(),
    );
    await input.close();
  });
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
