import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 40, rows: 8),
);

final _narrowProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 30, rows: 8),
);

/// Renders the emitted transcript as physical terminal lines: a carriage
/// return followed by an erase-line sequence leaves only the rewritten tail of
/// that line, so a repainted editable line is measured once.
Iterable<String> _visibleLines(String text) => text
    .split('\n')
    .map(
      (line) => line
          .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '')
          .split('\r')
          .last,
    )
    .where((line) => line.isNotEmpty);

/// Prose guidance wraps inside the declared width, so phrases are compared
/// without whitespace.
String _withoutWrapping(String transcript) =>
    transcript.replaceAll(RegExp(r'\s+'), '');

void main() {
  test(
    'time keeps incomplete field drafts local before explicit review submit',
    () async {
      final output = StringBuffer();

      final result = await TimeInput('Departure').prompt(
        source: ScriptedInput(
          Stream.value('12\r34\r\t\r'),
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );

      expect(
        (result as Accepted<({int hour, int minute, int? second})>).value,
        (hour: 12, minute: 34, second: null),
      );
      expect(output.toString(), contains('Focus: Hour'));
      expect(output.toString(), contains('Focus: Minute'));
      expect(output.toString(), contains('Review: 12:34'));
      expect(output.toString(), contains('Format: HH:mm'));
    },
  );

  test(
    'date uses the session profile and preserves feedback during edit',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();

      final result = await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Calendar');
          spinner.start(session: session);
          final pending = DateInput(
            'Date',
            order: DateFieldOrder.dayMonthYear,
            initialValue: '29/2/2024',
          ).prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          spinner.update('checking');
          input.add('\t\t\t\r\t\r');
          await input.close();
          final answer = await pending;
          spinner.finish(FeedbackOutcome.completed);
          return answer;
        },
        source: ScriptedInput(
          input.stream,
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<CivilDate>).value.day, 29);
      expect(output.toString(), contains('[status] Calendar: checking'));
      expect(output.toString(), contains('Focus: Review'));
    },
  );

  test('narrow declared width wraps date guidance without losing it', () async {
    final output = StringBuffer();

    final result = await DateInput('Date', order: DateFieldOrder.dayMonthYear)
        .prompt(
          source: ScriptedInput(
            Stream.value('29\t2\t2024\t\r\t\r'),
            output,
            outputProfile: _narrowProfile,
          ),
          mode: PromptMode.rich,
        );

    expect((result as Accepted<CivilDate>).value.day, 29);
    final lines = _visibleLines(output.toString()).toList();
    for (final line in lines) {
      expect(
        line.length,
        lessThanOrEqualTo(30),
        reason: 'line exceeds the declared width: "$line"',
      );
    }
    final guidance = _withoutWrapping(lines.join());
    expect(guidance, contains(_withoutWrapping('CE 0001-9999')));
    expect(
      guidance,
      contains(_withoutWrapping('Arithmetic profile; date only, no timezone.')),
    );
    // Guidance never overwrites the field the user just left.
    expect(
      lines.where(
        (line) => line.contains('> 29') && line.contains('Focus: month'),
      ),
      isEmpty,
    );
  });

  test('narrow time guidance wraps in both interaction modes', () async {
    for (final mode in [PromptMode.rich, PromptMode.linear]) {
      final output = StringBuffer();

      final result = await TimeInput('Departure').prompt(
        source: ScriptedInput(
          Stream.value(mode == PromptMode.rich ? '12\t34\t\r\t\r' : '12:34\r'),
          output,
          outputProfile: _narrowProfile,
        ),
        mode: mode,
      );

      expect(
        (result as Accepted<({int hour, int minute, int? second})>).value,
        (hour: 12, minute: 34, second: null),
      );
      final lines = _visibleLines(output.toString()).toList();
      for (final line in lines) {
        expect(
          line.length,
          lessThanOrEqualTo(30),
          reason: '${mode.name} line exceeds the declared width: "$line"',
        );
      }
      expect(lines.join(), contains('minutes only; 24-hour clock'));
    }
  });

  test(
    'rich time fields repaint at new idle geometry and release the watcher',
    () async {
      final keys = StreamController<String>();
      var watcherCancelled = false;
      final resized = StreamController<void>.broadcast(
        onCancel: () => watcherCancelled = true,
      );
      final output = StringBuffer();
      final observer = _ResizeObserver(
        resized.stream,
        () => (columns: 18, rows: 6),
      );

      final pending = TimeInput('Departure').prompt(
        source: ScriptedInput(
          keys.stream,
          output,
          outputProfile: _richProfile,
          resizeObserver: observer,
        ),
        mode: PromptMode.rich,
      );
      await pumpEventQueue();
      keys.add('12');
      await pumpEventQueue();
      final beforeResize = output.length;

      resized.add(null);
      await pumpEventQueue();

      // A resize is a repaint only: the hour draft stays in the field and the
      // editable line is redrawn at the observed geometry.
      expect(output.length, greaterThan(beforeResize));
      expect(_visibleLines(output.toString()).last, contains('12'));

      keys.add('\t34\t\r\t\r');
      expect(
        (await pending as Accepted<({int hour, int minute, int? second})>)
            .value,
        (hour: 12, minute: 34, second: null),
      );
      await keys.close();
      await resized.close();
      expect(watcherCancelled, isTrue);
    },
  );

  test(
    'idle resize in the date review stage repaints without accepting the draft',
    () async {
      final keys = StreamController<String>();
      final resized = StreamController<void>.broadcast();
      final output = StringBuffer();
      final observer = _ResizeObserver(
        resized.stream,
        () => (columns: 18, rows: 6),
      );

      final pending = DateInput('Date', order: DateFieldOrder.dayMonthYear)
          .prompt(
            source: ScriptedInput(
              keys.stream,
              output,
              outputProfile: _richProfile,
              resizeObserver: observer,
            ),
            mode: PromptMode.rich,
          );
      await pumpEventQueue();
      keys.add('29\t2\t2024\t\r');
      await pumpEventQueue();
      final beforeResize = output.length;

      resized.add(null);
      await pumpEventQueue();

      var completed = false;
      unawaited(pending.then((_) => completed = true));

      expect(output.length, greaterThan(beforeResize));
      await pumpEventQueue();
      expect(completed, isFalse, reason: 'a repaint must not accept the draft');

      keys.add('\t\r');
      expect((await pending as Accepted<CivilDate>).value.day, 29);
      await keys.close();
      await resized.close();
    },
  );

  test(
    'session help leads with the current date stage while feedback updates',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();

      final result = await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Calendar');
          spinner.start(session: session);
          final pending = DateInput(
            'Date',
            order: DateFieldOrder.dayMonthYear,
            initialValue: '29/2/2024',
          ).prompt(session: session);
          await pumpEventQueue();
          input.add('\t\t\t\r');
          await pumpEventQueue();
          input.add('\x14');
          await pumpEventQueue();
          spinner.update('checking');
          await pumpEventQueue();
          input.add('\x1b');
          await pumpEventQueue();
          input.add('\t\r');
          await input.close();
          final answer = await pending;
          spinner.finish(FeedbackOutcome.completed);
          return answer;
        },
        source: ScriptedInput(
          input.stream,
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<CivilDate>).value.day, 29);
      final text = output.toString();
      // Help leads with the review stage that requested it.
      expect(text, contains('Help: Review'));
      expect(text, contains('/submit accepts'));
      expect(text, contains('day/month/year'));
      // Background feedback continued while help owned the screen, and the
      // retained draft survived dismissal.
      expect(text, contains('[status] Calendar: checking'));
      expect(text, contains('Help dismissed.'));
    },
  );

  test('rich field help names the focused date and time fields', () async {
    final dateOutput = StringBuffer();
    await DateInput('Date', order: DateFieldOrder.dayMonthYear).prompt(
      source: ScriptedInput(
        Stream.value('\x14\x1b\x03'),
        dateOutput,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(dateOutput.toString(), contains('Help: Editing the day field'));

    final timeOutput = StringBuffer();
    await TimeInput('Departure').prompt(
      source: ScriptedInput(
        Stream.value('\x14\x1b\x03'),
        timeOutput,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(timeOutput.toString(), contains('Help: Editing the Hour field'));
  });

  test(
    'both modes keep typed date results, validation and terminal outcomes',
    () async {
      Accepted<CivilDate> accepted(PromptResult<CivilDate> result) =>
          result as Accepted<CivilDate>;

      final rich =
          await DateInput(
            'Date',
            order: DateFieldOrder.dayMonthYear,
            initialValue: '29/2/2024',
          ).prompt(
            source: ScriptedInput(
              Stream.value('\t\t\t\r\t\r'),
              StringBuffer(),
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(accepted(rich).value.day, 29);
      expect(accepted(rich).value.era, 'CE');
      expect(accepted(rich).value.inputYear, 2024);

      final linear = await DateInput('Date', order: DateFieldOrder.dayMonthYear)
          .prompt(
            source: ScriptedInput(
              Stream.value('29/2/2024\r/submit\r'),
              StringBuffer(),
            ),
            mode: PromptMode.linear,
          );
      expect(accepted(linear).value.day, 29);

      // An invalid draft is retained for correction in both modes.
      final invalidRichOutput = StringBuffer();
      final invalidRich =
          await DateInput(
            'Date',
            order: DateFieldOrder.dayMonthYear,
            initialValue: '30/4/2024',
          ).prompt(
            source: ScriptedInput(
              Stream.value('\t\x7f2\t\t\r\t\x7f4\t\t\r\t\r'),
              invalidRichOutput,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(accepted(invalidRich).value.day, 30);
      expect(accepted(invalidRich).value.month, 4);
      expect(
        _withoutWrapping(_visibleLines(invalidRichOutput.toString()).join()),
        contains(
          _withoutWrapping('day does not exist in the selected month and year'),
        ),
      );

      final invalidLinearOutput = StringBuffer();
      final invalidLinear =
          await DateInput('Date', order: DateFieldOrder.dayMonthYear).prompt(
            source: ScriptedInput(
              Stream.value('29/2/2023\r\x7f\x7f\x7f\x7f2024\r/submit\r'),
              invalidLinearOutput,
            ),
            mode: PromptMode.linear,
          );
      expect(accepted(invalidLinear).value.day, 29);
      expect(accepted(invalidLinear).value.year, 2024);
      expect(
        _visibleLines(invalidLinearOutput.toString()).join(),
        contains('Correct the retained draft'),
      );

      expect(
        await DateInput('Date', order: DateFieldOrder.dayMonthYear).prompt(
          source: ScriptedInput(
            Stream.value('\x1bx'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        ),
        isA<Cancelled<CivilDate>>(),
      );
      expect(
        await DateInput('Date', order: DateFieldOrder.dayMonthYear).prompt(
          source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer()),
          mode: PromptMode.linear,
        ),
        isA<Cancelled<CivilDate>>(),
      );
      expect(
        await DateInput('Date', order: DateFieldOrder.dayMonthYear).prompt(
          source: ScriptedInput(
            Stream.value('\x03'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        ),
        isA<Interrupted<CivilDate>>(),
      );
      expect(
        await DateInput('Date', order: DateFieldOrder.dayMonthYear).prompt(
          source: ScriptedInput(const Stream.empty(), StringBuffer()),
          mode: PromptMode.linear,
        ),
        isA<InputEnded<CivilDate>>(),
      );
    },
  );

  test(
    'date and time provide field-specific help in rich and linear modes',
    () async {
      final dateOutput = StringBuffer();
      final date = await DateInput('Date', order: DateFieldOrder.yearMonthDay)
          .prompt(
            source: ScriptedInput(
              Stream.value('\x14\x1b\x03'),
              dateOutput,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(date, isA<Interrupted<CivilDate>>());
      expect(dateOutput.toString(), contains('year/month/day'));
      expect(dateOutput.toString(), contains('numeric field at a time'));

      final timeOutput = StringBuffer();
      final time = await TimeInput('Time', seconds: true).prompt(
        source: ScriptedInput(Stream.value('/help\r/cancel\r'), timeOutput),
        mode: PromptMode.linear,
      );
      expect(time, isA<Cancelled<({int hour, int minute, int? second})>>());
      expect(timeOutput.toString(), contains('HH:mm:ss'));
      expect(
        timeOutput.toString(),
        contains('time of day, not a date or timezone'),
      );
    },
  );
}

final class _ResizeObserver implements TerminalResizeObserver {
  _ResizeObserver(this.notifications, this._dimensions);

  @override
  final Stream<void> notifications;
  final ({int columns, int rows})? Function() _dimensions;

  @override
  ({int columns, int rows})? readDimensions() => _dimensions();

  @override
  Duration get fallbackInterval => const Duration(days: 1);
}
