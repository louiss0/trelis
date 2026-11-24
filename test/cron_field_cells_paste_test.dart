import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

void main() {
  test(
    'unix paste distributes five tokens and focuses the last cell',
    () async {
      final output = StringBuffer();
      final result = await CronInput('Schedule', profile: CronProfile.unix)
          .prompt(
            source: ScriptedInput(
              Stream.value('\x1b[200~1 2 3 4 5\x1b[201~\r'),
              output,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '1 2 3 4 5',
      );
      final text = output.toString();
      // Focus lands on the last populated cell (day-of-week, 5/5) with the
      // caret at its end, so a bare Enter submits the pasted draft.
      expect(text, contains('unix · 5/5 day-of-week'));
      expect(text, isNot(contains('Paste rejected')));
    },
  );

  test('quartz six-token paste clears the year cell', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.quartz)
        .prompt(
          source: ScriptedInput(
            Stream.value('\x1b[200~0 0 0 ? * MON\x1b[201~\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    final expression = (result as Accepted<CronExpression>).value.expression;
    expect(expression, '0 0 0 ? * MON');
    expect(expression.split(' '), hasLength(6));
    expect(output.toString(), contains('quartz · 6/7 day-of-week'));
  });

  test('quartz seven-token paste focuses the year cell', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.quartz)
        .prompt(
          source: ScriptedInput(
            Stream.value('\x1b[200~0 0 0 15 * ? 2024\x1b[201~\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '0 0 0 15 * ? 2024',
    );
    expect(output.toString(), contains('quartz · 7/7 year'));
  });

  test('single-token paste inserts at the cell caret', () async {
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            // '5', caret left, paste '1' -> '15', then fill the rest.
            Stream.value('5\x1b[D\x1b[200~1\x1b[201~\t*\t*\t*\t*\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<CronExpression>).value.expression, '15 * * * *');
  });

  test('invalid pasted tokens stay drafts until submit validation', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            // Every token is out of range for its cell but still distributes;
            // Enter reports the first invalid cell and refocuses it.
            Stream.value('\x1b[200~99 99 99 99 99\x1b[201~\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(result, isA<InputEnded<CronExpression>>());
    final text = output.toString();
    expect(text, contains("'minute' is invalid"));
    expect(text, contains('unix · 1/5 minute'));
  });

  test('wrong token count rejects and preserves drafts and focus', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            // cell0 '7', Tab to cell1, a 3-token paste is rejected, '8' still
            // lands in cell1, and the remaining cells fill normally.
            Stream.value('7\t\x1b[200~1 2 3\x1b[201~8\t*\t*\t*\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<CronExpression>).value.expression, '7 8 * * *');
    final text = output.toString();
    expect(text, contains('Paste rejected'));
    expect(text, contains('unix · 2/5 hour'));
  });

  test(
    'padded and newline pastes reject while a clean paste succeeds',
    () async {
      final output = StringBuffer();
      final result = await CronInput('Schedule', profile: CronProfile.unix)
          .prompt(
            source: ScriptedInput(
              // Leading space, trailing space and an embedded newline are all
              // rejected; the same five tokens without padding distribute.
              Stream.value(
                '\x1b[200~ 1 2 3 4 5\x1b[201~'
                '\x1b[200~1 2 3 4 5 \x1b[201~'
                '\x1b[200~1 2\n3 4 5\x1b[201~'
                '\x1b[200~1 2 3 4 5\x1b[201~\r',
              ),
              output,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '1 2 3 4 5',
      );
      final text = output.toString();
      expect('Paste rejected'.allMatches(text).length, 3);
    },
  );

  test('a tab inside a multi-token paste rejects it', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            Stream.value('\x1b[200~1\t2 3 4 5\x1b[201~*\t*\t*\t*\t*\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<CronExpression>).value.expression, '* * * * *');
    expect(output.toString(), contains('Paste rejected'));
  });

  test('an oversized paste is rejected without touching drafts', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            // 5000 UTF-16 units exceeds the reader's paste bound and arrives
            // as the oversized-paste marker; drafts stay untouched.
            Stream.value(
              '5\t\x1b[200~${'x' * 5000}\x1b[201~'
              '*\t*\t*\t*\r',
            ),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<CronExpression>).value.expression, '5 * * * *');
    expect(output.toString(), contains('Paste rejected'));
  });

  test('quartz rejects a four-token paste count', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.quartz)
        .prompt(
          source: ScriptedInput(
            Stream.value('\x1b[200~0 0 0 ?\x1b[201~\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(result, isA<InputEnded<CronExpression>>());
    expect(output.toString(), contains('Paste rejected'));
  });
}
