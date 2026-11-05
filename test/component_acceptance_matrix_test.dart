import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  for (final mode in [PromptMode.rich, PromptMode.linear]) {
    test('TextInput / ${mode.name}: submit an edited answer', () async {
      final out = StringBuffer();
      final result = await TextInput(
        'Name',
      ).prompt(source: ScriptedInput(Stream.value('Ada\r'), out), mode: mode);
      expect((result as Accepted<String>).value, 'Ada');
      expect(out.toString(), contains('Name'));
    });
    test(
      'Password / ${mode.name}: validate without revealing the secret',
      () async {
        final out = StringBuffer();
        final result =
            await Password(
              'Password',
              validate: (v) => v == 'secret99' ? null : 'invalid',
            ).prompt(
              source: ScriptedInput(
                Stream.value('secret\rsubmit\redit\r99\rsubmit\r'),
                out,
              ),
              mode: mode,
            );
        expect((result as Accepted<String>).value, 'secret99');
        expect(out.toString(), isNot(contains('secret99')));
      },
    );
    test('Multiline / ${mode.name}: submit a line', () async {
      final out = StringBuffer();
      final result = await Multiline('Notes').prompt(
        source: ScriptedInput(
          Stream.value(mode == PromptMode.rich ? 'abc\t\r' : 'abc\r/done\r'),
          out,
        ),
        mode: mode,
      );
      expect(result, isA<Accepted<String>>());
      expect((result as Accepted<String>).value, 'abc');
      expect(out.toString(), contains('Notes'));
    });
    for (final component in ['Confirm', 'Checkbox', 'Toggle']) {
      test('$component / ${mode.name}: choose and submit yes', () async {
        final out = StringBuffer();
        final input = ScriptedInput(
          Stream.value(
            mode == PromptMode.rich
                ? (component == 'Confirm' ? 'y\r' : ' \r')
                : 'yes\r',
          ),
          out,
        );
        final PromptResult<bool> result = switch (component) {
          'Confirm' => await Confirm(
            'Decision',
          ).prompt(source: input, mode: mode),
          'Checkbox' => await Checkbox(
            'Decision',
          ).prompt(source: input, mode: mode),
          _ => await Toggle('Decision').prompt(source: input, mode: mode),
        };
        expect((result as Accepted<bool>).value, isTrue);
        expect(out.toString(), contains('Decision'));
      });
    }
    for (final component in ['Select', 'Radio']) {
      test('$component / ${mode.name}: select the second identity', () async {
        final out = StringBuffer();
        final input = ScriptedInput(
          Stream.value(mode == PromptMode.rich ? '\x1b[B\r' : '2\r'),
          out,
        );
        final choices = [Choice('a', 'First'), Choice('b', 'Second')];
        final result = component == 'Select'
            ? await Select<String>(
                'Choice',
                choices,
              ).prompt(source: input, mode: mode)
            : await Radio<String>(
                'Choice',
                choices,
              ).prompt(source: input, mode: mode);
        expect((result as Accepted<String>).value, 'b');
        expect(out.toString(), contains('Choice'));
      });
    }
  }
}
