import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

import 'support/backend_baseline_fixture.dart';

void main() {
  test(
    'scripted fixture drives a public prompt and records selected output',
    () async {
      final fixture = PromptFixture();
      final result = TextInput('Name')
          .prompt(source: fixture.source, mode: PromptMode.linear);
      fixture.add('Ada\r');
      await fixture.close();

      expect((await result as Accepted<String>).value, 'Ada');
      expect(fixture.selectedOutput.text, contains('Name'));
    },
  );

  test('environment, geometry, and time fixtures are declared explicitly', () {
    final clock = ManualClock(DateTime.utc(2030, 1, 2, 3, 4, 5));
    final fixture = PromptFixture(
      environment: EnvironmentFixture({
        'TERM': 'dumb',
        'COLORTERM': null,
        'NO_COLOR': '1',
      }),
      geometry: TerminalGeometryFixture(columns: 132, rows: 43),
      clock: clock,
    );

    expect(fixture.environment['TERM'], 'dumb');
    expect(fixture.environment['COLORTERM'], isNull);
    expect(fixture.geometry, TerminalGeometryFixture(columns: 132, rows: 43));
    expect(clock.now, DateTime.utc(2030, 1, 2, 3, 4, 5));
    clock.elapse(const Duration(seconds: 3));
    expect(clock.now, DateTime.utc(2030, 1, 2, 3, 4, 8));
    expect(
      () => TerminalGeometryFixture(columns: 0, rows: 43),
      throwsArgumentError,
    );
  });

  test(
    'failure fixtures inject input and output errors at public seams',
    () async {
      final input = PromptFixture();
      final prompt = TextInput('Name').prompt(source: input.source);
      final inputFailure = StateError('scripted input failure');
      input.fail(inputFailure);

      await expectLater(prompt, throwsA(same(inputFailure)));

      final outputFailure = StateError('selected output failure');
      final output = FailingOutput(outputFailure);
      expect(
        () => Text('Status').present(output: output),
        throwsA(same(outputFailure)),
      );
      expect(output.writeAttempts, 1);
    },
  );
}
