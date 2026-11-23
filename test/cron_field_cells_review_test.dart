import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

/// A one-day window straddling the 2023/2024 boundary: every midnight inside
/// it matches `0 0 0 * * ?`, so a six-field Quartz draft reports instants in
/// both years while a seven-field draft is bounded to its declared year.
CronPreviewConfig _yearConfig() => CronPreviewConfig(
  providerTimeout: const Duration(seconds: 5),
  zone: 'Etc/UTC',
  reference: DateTime.utc(2023, 12, 30),
  start: DateTime.utc(2023, 12, 31),
  end: DateTime.utc(2024, 1, 1),
  count: 5,
  budget: 200000,
);

/// A preview that cannot finish quickly: `0 0 31 2 *` never matches, so the
/// bounded search runs until cancelled or interrupted.
CronPreviewConfig _slowConfig() => CronPreviewConfig(
  providerTimeout: const Duration(seconds: 5),
  zone: 'Etc/UTC',
  reference: DateTime.utc(2024),
  start: DateTime.utc(2024),
  end: DateTime.utc(2030),
  count: 1,
  budget: 2000000,
);

/// Polls [ready] until it holds or roughly five seconds elapse.
Future<void> _until(bool Function() ready, String what) async {
  for (var i = 0; i < 500; i++) {
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('timed out waiting for $what');
}

void main() {
  group('rich review stage on field cells', () {
    test('quartz blank-year draft previews across the year boundary and '
        'submits six fields', () async {
      final output = StringBuffer();
      final result =
          await CronInput(
            'Schedule',
            profile: CronProfile.quartz,
            preview: _yearConfig(),
          ).prompt(
            source: ScriptedInput(
              // Cells 0-5 fill `0 0 0 * * ?`; cell 6 (year) stays blank, so
              // Enter from day-of-week submits a clean six-field expression.
              // Tab moves Review focus Edit -> Preview, Enter previews, the
              // next Tab/Enter pair lands on Submit and accepts.
              Stream.value('0\t0\t0\t*\t*\t?\r\t\r\t\r'),
              output,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '0 0 0 * * ?',
      );
      final text = output.toString();
      // The review stage announced the retained six-field draft.
      expect(text, contains('Review: 0 0 0 * * ?.'));
      expect(text, contains('Matching preview:'));
      // Midnight matches on both sides of the year boundary.
      expect(text, contains('2023-12-31 00:00:00.000Z'));
      expect(text, contains('2024-01-01 00:00:00.000Z'));
    });

    test('quartz year cell bounds the preview to the declared year', () async {
      final output = StringBuffer();
      final result =
          await CronInput(
            'Schedule',
            profile: CronProfile.quartz,
            preview: _yearConfig(),
          ).prompt(
            source: ScriptedInput(
              // The populated year cell produces a seven-field expression;
              // only the 2023 midnight inside the window may match.
              Stream.value('0\t0\t0\t*\t*\t?\t2023\r\t\r\t\r'),
              output,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '0 0 0 * * ? 2023',
      );
      final text = output.toString();
      expect(text, contains('Review: 0 0 0 * * ? 2023.'));
      expect(text, contains('2023-12-31 00:00:00.000Z'));
      // The 2024-01-01 bound in the status line uses ISO-8601 ('T'), so
      // the space-separated instant form proves year bounding.
      expect(text, isNot(contains('2024-01-01 00:00:00.000Z')));
    });

    test('Escape during a slow preview returns to Review and Submit accepts '
        'the retained draft', () async {
      final input = StreamController<String>();
      addTearDown(input.close);
      final output = StringBuffer();
      final result =
          CronInput(
            'Schedule',
            profile: CronProfile.unix,
            preview: _slowConfig(),
          ).prompt(
            source: ScriptedInput(
              input.stream,
              output,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      // Fill the five cells, submit into Review, Tab to Preview and
      // activate it; the unmatchable draft keeps the search running.
      input.add('0\t0\t31\t2\t*\r\t\r');
      await _until(
        () => output.toString().contains('Calculating preview'),
        'the preview calculation notice',
      );
      input.add('\x1b');
      await _until(
        () => output.toString().contains('Matching preview: cancelled'),
        'the cancelled preview report',
      );
      // Back in Review with the draft retained and focus still on
      // Preview: Tab to Submit and Enter accepts the assembled expression.
      input.add('\t\r');
      final accepted = await result.timeout(const Duration(seconds: 5));
      expect(accepted, isA<Accepted<CronExpression>>());
      expect(
        (accepted as Accepted<CronExpression>).value.expression,
        '0 0 31 2 *',
      );
      expect(output.toString(), contains('Review action: Submit.'));
    });

    test(
      'Ctrl+C interrupts a slow rich preview from the review stage',
      () async {
        final input = StreamController<String>();
        addTearDown(input.close);
        final output = StringBuffer();
        final result =
            CronInput(
              'Schedule',
              profile: CronProfile.unix,
              preview: _slowConfig(),
            ).prompt(
              source: ScriptedInput(
                input.stream,
                output,
                outputProfile: _richProfile,
              ),
              mode: PromptMode.rich,
            );
        input.add('0\t0\t31\t2\t*\r\t\r');
        await _until(
          () => output.toString().contains('Calculating preview'),
          'the preview calculation notice',
        );
        input.add('\x03');
        expect(
          await result.timeout(const Duration(seconds: 5)),
          isA<Interrupted<CronExpression>>(),
        );
      },
    );

    test(
      'Escape outside a preview still cancels the rich review prompt',
      () async {
        final input = StreamController<String>();
        addTearDown(input.close);
        final output = StringBuffer();
        final result =
            CronInput(
              'Schedule',
              profile: CronProfile.unix,
              preview: _slowConfig(),
            ).prompt(
              source: ScriptedInput(
                input.stream,
                output,
                outputProfile: _richProfile,
              ),
              mode: PromptMode.rich,
            );
        input.add('0\t0\t31\t2\t*\r');
        await _until(
          () => output.toString().contains('Review action: Edit.'),
          'the review stage announcement',
        );
        // No preview is in flight: Escape reaches the review editor and
        // cancels the whole prompt.
        input.add('\x1b');
        expect(
          await result.timeout(const Duration(seconds: 5)),
          isA<Cancelled<CronExpression>>(),
        );
      },
    );

    test('review help leads with the stage controls before the field map', () async {
      final output = StringBuffer();
      final result =
          await CronInput(
            'Schedule',
            profile: CronProfile.unix,
            preview: _yearConfig(),
          ).prompt(
            source: ScriptedInput(
              // Enter Review, open help with Ctrl+T, dismiss with Escape, then
              // interrupt to end the prompt after the help text is captured.
              Stream.value('*\t*\t*\t*\t*\r\t\x14\x1b\x03'),
              output,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(result, isA<Interrupted<CronExpression>>());
      final text = output.toString().replaceAll('\n', '');
      expect(text, contains('Help: Reviewing the retained expression'));
      expect(text, contains('Edit, Preview and Submit'));
      expect(text, contains('Field order:'));
      // Stage-led help puts the Review controls ahead of the field map.
      expect(
        text.indexOf('Edit, Preview and Submit'),
        lessThan(text.indexOf('Field order:')),
      );
    });
  });
}
