import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

ScriptedInput _scriptedInput(Stream<String> input, StringSink output) =>
    ScriptedInput(input, output, outputProfile: _richProfile);

void main() {
  test('command palette help retains application guidance when instructions are hidden', () async {
    final output = StringBuffer();
    final result =
        await CommandPalette(
          'Commands',
          [Choice('save', 'Save')],
          instructions: InstructionDisplay.hidden,
          supplementaryHelp: ['Commands do not run automatically.'],
        ).prompt(
          source: _scriptedInput(Stream.value('/help\rSave\r1\r'), output),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'save');
    expect(
      output.toString().replaceAll(RegExp(r'\s+'), ' '),
      contains('Commands do not run automatically.'),
    );
  });
  test('command palette accepts through the shared session', () async {
    final source = _scriptedInput(Stream.value('Save\r1\r'), StringBuffer());
    final result = await TerminalSession.run(
      (session) => CommandPalette('Commands', [
        Choice('save', 'Save'),
      ]).prompt(session: session),
      source: source,
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'save');
  });
  test(
    'accepts a command identity without executing application work',
    () async {
      var executions = 0;
      final actions = <String, void Function()>{'save': () => executions++};
      final out = StringBuffer();
      final result = await CommandPalette('Commands', [Choice('save', 'Save')])
          .prompt(
            source: _scriptedInput(Stream.value('sav\r\r'), out),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'save');
      expect(executions, 0);
      actions[result.value]!();
      expect(executions, 1);
      expect(out.toString(), contains('CommandPalette'));
    },
  );

  test(
    'linear filtering preserves source references and unavailable reasons',
    () async {
      final out = StringBuffer();
      final result =
          await CommandPalette('Commands', [
            Choice('save', 'Save file'),
            Choice('share', 'Share file', disabledReason: 'Offline'),
            Choice('close', 'Close file'),
          ]).prompt(
            source: _scriptedInput(Stream.value('file\r2\r3\r'), out),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'close');
      expect(out.toString(), contains('2. Share file [unavailable: Offline]'));
      expect(out.toString(), contains('Unavailable: Offline'));
      expect(
        out.toString().indexOf('1. Save file'),
        lessThan(out.toString().indexOf('3. Close file')),
      );
    },
  );

  test(
    'unmatched query and invalid reference never fabricate a command',
    () async {
      final out = StringBuffer();
      final result = await CommandPalette('Commands', [Choice('save', 'Save')])
          .prompt(
            source: _scriptedInput(Stream.value('missing\r1\r/cancel\r'), out),
            mode: PromptMode.linear,
          );
      expect(result, isA<Cancelled<String>>());
      expect(out.toString(), contains('No matching choices'));
      expect(out.toString(), isNot(contains('Accepted:')));
    },
  );

  test('failed search cannot fabricate a command', () async {
    final out = StringBuffer();
    final result =
        await CommandPalette('Commands', [
          Choice('save', 'Save'),
        ], search: (_) => throw StateError('offline')).prompt(
          source: _scriptedInput(Stream.value('x\r1\r/cancel\r'), out),
          mode: PromptMode.linear,
        );
    expect(result, isA<Cancelled<String>>());
    expect(out.toString(), contains('Search unavailable'));
    expect(out.toString(), isNot(contains('Accepted:')));
  });
  test(
    'rich empty query requests available commands before acceptance',
    () async {
      final out = StringBuffer();
      final result =
          await CommandPalette('Commands', [
            Choice('save', 'Save'),
          ], search: (_) => [Choice('save', 'Save')]).prompt(
            source: _scriptedInput(Stream.value('\r\r'), out),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'save');
    },
  );
}
