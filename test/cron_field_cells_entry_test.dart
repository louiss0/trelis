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

void main() {
  test('unix cells accept a left-to-right Tab entry', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            Stream.value('*\t*\t*\t*\t*\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '* * * * *',
    );
    final text = output.toString();
    // The active-format cue names the focused field cell as focus moves.
    expect(text, contains('unix · 1/5 minute (0-59)'));
    expect(text, contains('unix · 5/5 day-of-week'));
    // The trailing Submit stop joins the focus ring.
    expect(text, contains('[ Submit ]'));
  });

  test('Tab wraps from the last cell through Submit back to cell 0', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            Stream.value('*\t*\t*\t*\t*\t\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '* * * * *',
    );
    expect(output.toString(), contains('unix · Focus: Submit'));
  });

  test('Shift-Tab and Ctrl+B move focus backward across the ring', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            // cell0 '5', forward to cell1, back to cell0, append '0' -> '50'.
            Stream.value('5\t\x1b[Z0\t*\t*\t*\t*\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '50 * * * *',
    );

    final ctrlOutput = StringBuffer();
    final ctrl = await CronInput('Schedule', profile: CronProfile.unix).prompt(
      source: ScriptedInput(
        // cell1 --Ctrl+B--> cell0 --Ctrl+B--> Submit --Tab--> cell0.
        Stream.value('5\t\x02\x02\t\t*\t*\t*\t*\r'),
        ctrlOutput,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(
      (ctrl as Accepted<CronExpression>).value.expression,
      '5 * * * *',
    );
    expect(ctrlOutput.toString(), contains('unix · Focus: Submit'));
  });

  test('Enter from a middle cell validates the whole draft', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            // Fill minute and hour, submit early: the first empty mandatory
            // cell (day-of-month) is named and focused for correction.
            Stream.value('0\t0\r*\t*\t*\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '0 0 * * *',
    );
    final text = output.toString();
    expect(text, contains("'day-of-month' is required."));
    expect(text, contains('unix · 3/5 day-of-month'));
  });

  test('an invalid cell keeps every draft and refocuses the offender', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            // Every cell is filled but '99' is out of range for minute; fix
            // it in place and resubmit.
            Stream.value('99\t*\t*\t*\t*\r\x7f\x7f5\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '5 * * * *',
    );
    final text = output.toString();
    expect(text, contains("'minute' is invalid"));
    expect(text, contains('unix · 1/5 minute'));
  });

  test('quartz omits a blank year cell for a six-field expression', () async {
    final output = StringBuffer();
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(
      source: ScriptedInput(
        Stream.value('0\t0\t0\t?\t*\tMON\t\r'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    final expression = (result as Accepted<CronExpression>).value;
    expect(expression.expression, '0 0 0 ? * MON');
    expect(expression.expression.split(' '), hasLength(6));
    expect(output.toString(), contains('quartz · 7/7 year (1970-2199, optional)'));
  });

  test('quartz keeps a populated year cell as a seven-field expression', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(
      source: ScriptedInput(
        Stream.value('0\t0\t0\t15\t*\t?\t2024\r'),
        StringBuffer(),
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '0 0 0 15 * ? 2024',
    );
  });

  test('quartz day exclusivity failure focuses day-of-month', () async {
    final output = StringBuffer();
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
    ).prompt(
      source: ScriptedInput(
        // Both day cells restricted: the ? exclusivity rule fails and focus
        // lands on day-of-month (cell 3).
        Stream.value('0\t0\t0\t*\t*\t*\t\r'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(result, isA<InputEnded<CronExpression>>());
    final text = output.toString();
    expect(text, contains('quartz requires ? in exactly one'));
    expect(text, contains('quartz · 4/7 day-of-month'));
  });

  test('Space is rejected with Tab guidance and never inserts', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            // A stray space must not corrupt cell0 or skip a field.
            Stream.value(' *\t*\t*\t*\t*\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '* * * * *',
    );
    expect(output.toString(), contains('press Tab'));
  });

  test('Up and Down are no-ops inside a field cell', () async {
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            Stream.value('\x1b[A\x1b[B5\t*\t*\t*\t*\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '5 * * * *',
    );
  });

  test('dash and plus insert literally inside a field cell', () async {
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            Stream.value('1-5+2\t*\t*\t*\t*\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(result, isA<InputEnded<CronExpression>>());

    final accepted = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            Stream.value('1-5\t*\t*\t*\t*\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (accepted as Accepted<CronExpression>).value.expression,
      '1-5 * * * *',
    );
  });

  test('caret keys stay grapheme-bounded inside the focused cell', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            // '12' -> Left, Backspace removes '1' -> '2'; End, '3' -> '23'.
            // Editing never crosses into a neighbouring cell.
            Stream.value('12\x1b[D\x7f\x1b[F3\t*\t*\t*\t*\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '23 * * * *',
    );

    // Home + Delete removes the first grapheme without touching cell1.
    final deleted = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            Stream.value('12\x1b[H\x1b[3~\t*\t*\t*\t*\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (deleted as Accepted<CronExpression>).value.expression,
      '2 * * * *',
    );
  });

  test('a valid initialValue splits into editable cells', () async {
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.unix,
      initialValue: '0 12 * * MON',
    ).prompt(
      source: ScriptedInput(Stream.value('\r'), StringBuffer(), outputProfile: _richProfile),
      mode: PromptMode.rich,
    );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '0 12 * * MON',
    );
  });

  test('rich cells keep cancel interrupt and input-end outcomes', () async {
    CronInput input() => CronInput('Schedule', profile: CronProfile.unix);
    Future<PromptResult<CronExpression>> run(String keys) =>
        input().prompt(
          source: ScriptedInput(
            Stream.value(keys),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );

    // A trailing bare Escape is indistinguishable from an unterminated
    // sequence once the stream closes, so cancellation is driven while the
    // stream is still open.
    final inputController = StreamController<String>();
    addTearDown(inputController.close);
    final cancelled = input().prompt(
      source: ScriptedInput(
        inputController.stream,
        StringBuffer(),
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    inputController.add('\x1b');
    expect(await cancelled, isA<Cancelled<CronExpression>>());

    expect(await run('\x03'), isA<Interrupted<CronExpression>>());
    expect(await run(''), isA<InputEnded<CronExpression>>());
  });

  test('preview review Enter from a cell opens Review and Edit restores cells', () async {
    final output = StringBuffer();
    final result =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: _config(),
        ).prompt(
          source: ScriptedInput(
            // Tab onto the trailing Review stop (its cue is observable),
            // Enter opens the Review stage; Edit returns to cell 0 with every
            // cell draft preserved, then the draft is submitted and reviewed
            // again before Submit.
            Stream.value('*\t*\t*\t*\t*\t\r\r\r\t\r\t\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '* * * * *',
    );
    final text = output.toString();
    expect(text, contains('Review action: Edit.'));
    expect(text, contains('unix · Focus: Review'));
    // Both review rounds announce the retained draft.
    expect('Review: * * * * *.'.allMatches(text).length, 2);
    expect(text, contains('2024-01-01 00:01:00.000Z'));
  });

  test('rich cells reject a multi-token paste without touching drafts', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            Stream.value(
              '\x1b[200~1 2 3 4 5\x1b[201~*\t*\t*\t*\t*\r',
            ),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '* * * * *',
    );
    expect(output.toString(), contains('Paste rejected'));
  });
}
