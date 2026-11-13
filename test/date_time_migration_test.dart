import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 40, rows: 8),
);

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
      expect(dateOutput.toString(), contains('one numeric field at a time'));

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
