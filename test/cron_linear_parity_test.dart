import 'dart:async';

import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/testing/compat_api.dart';
import 'package:trelis/src/theme_formatted_components.dart';
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

void main() {
  group('linear entry without a configured preview', () {
    test('accepts a full unix expression on one line', () async {
      final output = StringBuffer();
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(
        source: ScriptedInput(Stream.value('* * * * *\r'), output),
        mode: PromptMode.linear,
      );
      final accepted = result as Accepted<CronExpression>;
      expect(accepted.value.expression, '* * * * *');
      expect(accepted.value.profile, CronProfile.unix);
    });

    test('quartz accepts six-field and seven-field expressions verbatim',
        () async {
      final six = await CronInput(
        'Schedule',
        profile: CronProfile.quartz,
      ).prompt(
        source: ScriptedInput(Stream.value('0 0 12 ? * MON\r'), StringBuffer()),
        mode: PromptMode.linear,
      );
      expect(
        (six as Accepted<CronExpression>).value.expression,
        '0 0 12 ? * MON',
      );

      final seven = await CronInput(
        'Schedule',
        profile: CronProfile.quartz,
      ).prompt(
        source: ScriptedInput(
          Stream.value('0 0 12 L * ? 2025-2030\r'),
          StringBuffer(),
        ),
        mode: PromptMode.linear,
      );
      expect(
        (seven as Accepted<CronExpression>).value.expression,
        '0 0 12 L * ? 2025-2030',
      );
    });

    test('linear and rich modes accept the same expression', () async {
      Future<PromptResult<CronExpression>> run(PromptMode mode) =>
          CronInput('Schedule', profile: CronProfile.unix).prompt(
            source: ScriptedInput(
              // Rich interaction edits one field cell at a time, so the same
              // expression is typed across the five cells with Tab moves.
              Stream.value(
                mode == PromptMode.rich
                    ? '30\t9\t15\t6\tMON\r'
                    : '30 9 15 6 MON\r',
              ),
              StringBuffer(),
              outputProfile: mode == PromptMode.rich
                  ? _richProfile
                  : const OutputProfile(),
            ),
            mode: mode,
          );

      final linear = await run(PromptMode.linear) as Accepted<CronExpression>;
      final rich = await run(PromptMode.rich) as Accepted<CronExpression>;
      expect(linear.value.expression, rich.value.expression);
      expect(linear.value.profile, rich.value.profile);
    });

    test('/help shows cron guidance, clears the command and submits',
        () async {
      final output = StringBuffer();
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(
        source: ScriptedInput(
          Stream.value('/help\r* * * * *\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      final text = output.toString();
      expect(text, contains('five fields'));
      expect(text, contains('JAN-DEC'));
      expect(text, contains('SUN-SAT'));
      expect(text, contains('submit it'));
      expect(text, contains('No matching preview'));
      // The command itself must not leak into the retained draft.
      expect(text, isNot(contains('Invalid or unsupported cron expression')));
    });

    test('an invalid draft is retained for correction', () async {
      final output = StringBuffer();
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(
        source: ScriptedInput(
          Stream.value('bad\r\x7f\x7f\x7f* * * * *\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      expect(
        output.toString(),
        contains('Invalid or unsupported cron expression'),
      );
    });

    test('a backslash-quoted command submits as literal text', () async {
      final output = StringBuffer();
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(
        source: ScriptedInput(
          // The quoted command is rejected as data; the retained draft is
          // cleared before the real expression is entered.
          Stream.value(r'\/help' '\r\x7f\x7f\x7f\x7f\x7f* * * * *\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      // The quoted command was data, not help: no cron help block was shown.
      expect(output.toString(), isNot(contains('five fields')));
      expect(
        output.toString(),
        contains('Invalid or unsupported cron expression'),
      );
    });

    test('an identified paste enters the expression literally', () async {
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(
        source: ScriptedInput(
          Stream.value('\x1b[200~* * * * *\x1b[201~\r'),
          StringBuffer(),
        ),
        mode: PromptMode.linear,
      );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
    });

    test('/cancel ends the prompt from the entry line', () async {
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(
        source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer()),
        mode: PromptMode.linear,
      );
      expect(result, isA<Cancelled<CronExpression>>());
    });
  });

  group('linear review with a configured preview', () {
    test('quartz review accepts /preview, /edit and /submit', () async {
      final output = StringBuffer();
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.quartz,
        preview: _config(),
      ).prompt(
        source: ScriptedInput(
          // /preview computes, /edit returns to the retained entry draft,
          // Enter reviews it again and /submit accepts.
          Stream.value('0 0 12 ? * MON\r/preview\r/edit\r\r/submit\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '0 0 12 ? * MON',
      );
      expect(output.toString(), contains('Matching preview:'));
    });

    test('an invalid draft is retained and corrected before review',
        () async {
      final output = StringBuffer();
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.quartz,
        preview: _config(),
      ).prompt(
        source: ScriptedInput(
          // Neither day cell is '?', so the draft fails the day rule. The
          // retained draft is cleared and a corrected expression submitted.
          Stream.value(
            '0 0 12 * * *\r'
            '\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f'
            '0 0 12 ? * MON\r/submit\r',
          ),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '0 0 12 ? * MON',
      );
      expect(output.toString(), contains('Invalid cron expression'));
    });

    test('unknown review input is refused with the command guidance',
        () async {
      final output = StringBuffer();
      final result = await CronInput(
        'Schedule',
        profile: CronProfile.unix,
        preview: _config(),
      ).prompt(
        source: ScriptedInput(
          Stream.value('* * * * *\rbogus\r/submit\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      expect(
        output.toString(),
        contains('Use /preview, /edit, or /submit.'),
      );
    });

    test(
      '/cancel during an active preview survives intervening control keys',
      () async {
        final input = StreamController<String>();
        final output = StringBuffer();
        final longConfig = CronPreviewConfig(
          providerTimeout: const Duration(seconds: 5),
          zone: 'Etc/UTC',
          reference: DateTime.utc(2024),
          start: DateTime.utc(2024),
          end: DateTime.utc(2030),
          count: 1,
          budget: 2000000,
        );
        final result = CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: longConfig,
        ).prompt(
          source: ScriptedInput(input.stream, output),
          mode: PromptMode.linear,
        );
        input.add('0 0 31 2 *\r/preview\r');
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(output.toString(), contains('Calculating preview'));
        // A stray arrow key must not corrupt the /cancel line tracking.
        input.add('\x1b[A');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        input.add('/cancel\r');
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(
          output.toString(),
          contains('Matching preview: cancelled'),
        );
        input.add('/cancel\r');
        expect(
          await result.timeout(const Duration(seconds: 3)),
          isA<Cancelled<CronExpression>>(),
        );
        await input.close();
      },
    );
  });

  group('screen-reader presentation', () {
    test(
      'emits concise essential context before the prompt and accepts '
      'linearly',
      () async {
        final output = StringBuffer();
        final result = await ThemeFormattedPrompt.cron(
          'Schedule',
          io: TerminalEnvironment.scripted(
            input: Stream.value('* * * * *\r'),
            output: output,
            // A rich-capable profile proves screen-reader presentation still
            // resolves to the linear entry line.
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(
            mode: PromptMode.linear,
            screenReader: ScreenReaderPreference.on,
          ),
          profile: CronProfile.unix,
        ).prompt();

        expect(
          (result as Accepted<CronExpression>).value.expression,
          '* * * * *',
        );
        final text = output.toString();
        expect(text, contains('Schedule unix cron expression entry.'));
        expect(text, contains('Enter submits'));
        // Essential context precedes the prompt banner and the entry line.
        expect(
          text.indexOf('cron expression entry.'),
          lessThan(text.indexOf('expression limit')),
        );
      },
    );

    test('screen-reader review keeps the linear command set', () async {
      final output = StringBuffer();
      final result = await ThemeFormattedPrompt.cron(
        'Schedule',
        io: TerminalEnvironment.scripted(
          input: Stream.value('0 0 12 ? * MON\r/preview\r/submit\r'),
          output: output,
          profile: _richProfile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(
          mode: PromptMode.linear,
          screenReader: ScreenReaderPreference.on,
        ),
        profile: CronProfile.quartz,
        preview: _config(),
      ).prompt();

      expect(
        (result as Accepted<CronExpression>).value.expression,
        '0 0 12 ? * MON',
      );
      expect(output.toString(), contains('Matching preview:'));
    });
  });
}
