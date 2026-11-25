import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

CronPreviewConfig _config() => CronPreviewConfig(
  providerTimeout: const Duration(seconds: 5),
  zone: 'Etc/UTC',
  reference: DateTime.utc(2024),
  start: DateTime.utc(2024),
  end: DateTime.utc(2024, 1, 1, 0, 3),
  count: 1,
  budget: 3,
);

/// Reassembles text that guidance wrapping split at a display-cell
/// boundary so tests assert content independently of the declared width.
String _unwrapped(String text) => text.replaceAll('\n', '');

void main() {
  group('rich field-cell component help', () {
    test('F1 on a focused cell leads with that field and preserves the '
        'draft, caret and focus', () async {
      final output = StringBuffer();
      final result =
          await CronInput(
            'Schedule',
            profile: CronProfile.unix,
            supplementaryHelp: const ['Deployment windows: example.com/cron.'],
          ).prompt(
            source: ScriptedInput(
              // '5', caret moved to the start, help open/dismiss, then '1'
              // inserts before the '5' only if the caret survived -> '15'.
              Stream.value('5\x1b[D\x1bOP\x1b1\t*\t*\t*\t*\r'),
              output,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '15 * * * *',
      );
      final text = _unwrapped(output.toString());
      // Stage-led lead: the focused field's name, position and bounds.
      expect(text, contains('minute field cell 1/5'));
      expect(text, contains('0-59'));
      // Full ordered field map, day rules, length limit, preview
      // disclosure and caller supplementary help.
      expect(text, contains('Field order:'));
      expect(text, contains('day-of-week'));
      expect(text, contains('Day rule'));
      expect(text, contains('4096'));
      expect(text, contains('No matching preview'));
      expect(text, contains('example.com/cron'));
      // Help dismissed before the prompt continued.
      expect(text, contains('Help dismissed.'));
      // Focus returned to the same cell cue.
      expect(text, contains('unix · 1/5 minute'));
    });

    test('quartz year cell help flags the optional seventh field', () async {
      final output = StringBuffer();
      final result = await CronInput('Schedule', profile: CronProfile.quartz)
          .prompt(
            source: ScriptedInput(
              Stream.value('0\t0\t0\t?\t*\tMON\t\x1bOP\x1b\r'),
              output,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '0 0 0 ? * MON',
      );
      final text = _unwrapped(output.toString());
      expect(text, contains('year field cell 7/7'));
      expect(text, contains('1970-2199'));
      expect(text, contains('optional'));
      expect(text, contains('quartz requires ?'));
    });

    test('F1 on the last cell leads with that field', () async {
      final output = StringBuffer();
      final result = await CronInput('Schedule', profile: CronProfile.unix)
          .prompt(
            source: ScriptedInput(
              // The fifth star lands in the last cell (day-of-week); open
              // and dismiss help there, then submit the retained draft.
              Stream.value('*\t*\t*\t*\t*\x1bOP\x1b\r'),
              output,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      final text = _unwrapped(output.toString());
      expect(text, contains('day-of-week field cell 5/5'));
      expect(text, contains('Field order:'));
      expect(text, contains('No matching preview'));
    });

    test('F1 inside Review describes the stage controls', () async {
      final output = StringBuffer();
      final result =
          await CronInput(
            'Schedule',
            profile: CronProfile.unix,
            preview: _config(),
          ).prompt(
            source: ScriptedInput(
              // Enter opens Review; Review-stage help, dismiss, then Tab to
              // Submit and Enter accepts.
              Stream.value('*\t*\t*\t*\t*\r\x1bOP\x1b\t\t\r'),
              output,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      final text = _unwrapped(output.toString());
      expect(text, contains('Reviewing the retained expression'));
      expect(text, contains('Edit, Preview and Submit'));
      expect(text, contains('Etc/UTC'));
    });

    test('Escape dismisses help first, then cancels the prompt', () async {
      final output = StringBuffer();
      final result = await CronInput('Schedule', profile: CronProfile.unix)
          .prompt(
            source: ScriptedInput(
              // Help opens and dismisses on the first Escape; the second Escape
              // reaches the cell editor and cancels the prompt. The trailing tab
              // keeps the final Escape off the stream boundary.
              Stream.value('5\x1bOP\x1b\x1b\t'),
              output,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(result, isA<Cancelled<CronExpression>>());
      expect(output.toString(), contains('Help dismissed.'));
    });

    test('Ctrl+C interrupts from inside open help', () async {
      final result = await CronInput('Schedule', profile: CronProfile.unix)
          .prompt(
            source: ScriptedInput(
              Stream.value('5\x1bOP\x03'),
              StringBuffer(),
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(result, isA<Interrupted<CronExpression>>());
    });

    test('input exhaustion inside help returns InputEnded', () async {
      final result = await CronInput('Schedule', profile: CronProfile.unix)
          .prompt(
            source: ScriptedInput(
              Stream.value('5\x1bOP'),
              StringBuffer(),
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(result, isA<InputEnded<CronExpression>>());
    });
  });

  group('linear component help parity', () {
    test('/help without a preview carries the same stage content', () async {
      final output = StringBuffer();
      final result =
          await CronInput(
            'Schedule',
            profile: CronProfile.unix,
            supplementaryHelp: const ['Deployment windows: example.com/cron.'],
          ).prompt(
            source: ScriptedInput(Stream.value('/help\r* * * * *\r'), output),
            mode: PromptMode.linear,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      final text = _unwrapped(output.toString());
      expect(text, contains('Field order:'));
      expect(text, contains('Day rule'));
      expect(text, contains('4096'));
      expect(text, contains('No matching preview'));
      expect(text, contains('example.com/cron'));
    });

    test('/help inside linear review describes the review commands', () async {
      final output = StringBuffer();
      final result =
          await CronInput(
            'Schedule',
            profile: CronProfile.quartz,
            preview: _config(),
          ).prompt(
            source: ScriptedInput(
              Stream.value('0 0 12 ? * MON\r/help\r/submit\r'),
              output,
            ),
            mode: PromptMode.linear,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '0 0 12 ? * MON',
      );
      final text = _unwrapped(output.toString());
      expect(text, contains('/preview'));
      expect(text, contains('/edit'));
      expect(text, contains('/submit'));
      expect(text, contains('Field order:'));
      expect(text, contains('Etc/UTC'));
    });
  });
}
