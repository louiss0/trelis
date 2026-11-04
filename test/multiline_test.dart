import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'linear oversized paste is rejected without changing existing lines',
    () async {
      final output = StringBuffer();
      final result = await Multiline('Notes', maxLength: 3).prompt(
        source: ScriptedInput(
          Stream.value('a\r\x1b[200~bcd\x1b[201~\r/done\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, 'a\n');
      expect(output.toString(), contains('limit'));
    },
  );
  test(
    'editing a command-looking line preserves its literal initial value',
    () async {
      final output = StringBuffer();
      final result = await Multiline('Notes').prompt(
        source: ScriptedInput(
          Stream.value('\\/done\r/edit\r1\r\r/done\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, '/done');
      expect(output.toString(), contains('Edit line:\nCurrent text: \\/done'));
    },
  );
  test('rich vertical navigation corrects a prior logical line', () async {
    final result = await Multiline('Notes', initialValue: 'abc\ndef').prompt(
      source: ScriptedInput(Stream.value('\x1b[A!\t\r'), StringBuffer()),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'abc!\ndef');
  });
  test(
    'rich editing moves and erases graphemes and pastes normalized lines',
    () async {
      final output = StringBuffer();
      final result = await Multiline('Notes', initialValue: 'ab').prompt(
        source: ScriptedInput(
          Stream.value('\x1b[D\x7f\x1b[200~x\r\ny\rz\x1b[201~\t\r'),
          output,
        ),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<String>).value, 'x\ny\nzb');
    },
  );
  test('invalid final value retains lines for correction', () async {
    final output = StringBuffer();
    final result =
        await Multiline(
          'Notes',
          required: true,
          validate: (value) => value == 'ok' ? null : 'Enter ok',
        ).prompt(
          source: ScriptedInput(
            Stream.value(
              '/done\rbad\r/done\r/edit\r1\r\x01\x1b[3~\x1b[3~\x1b[3~ok\r/done\r',
            ),
            output,
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'ok');
    expect(output.toString(), contains('Required'));
    expect(output.toString(), contains('Enter ok'));
  });
  test(
    'pasted multiline text normalizes CRLF and CR without executing commands',
    () async {
      final result = await Multiline('Notes').prompt(
        source: ScriptedInput(
          Stream.value('\x1b[200~a\r\n/done\rb\x1b[201~\r/done\r'),
          StringBuffer(),
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, 'a\n/done\nb');
    },
  );
  test('quoted and identified pasted command lines remain literal', () async {
    final result = await Multiline('Notes').prompt(
      source: ScriptedInput(
        Stream.value('\\/done\r\x1b[200~/cancel\x1b[201~\r/done\r'),
        StringBuffer(),
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, '/done\n/cancel');
  });
  test(
    'linear edit, insert, list and confirmed removal correct existing lines',
    () async {
      final output = StringBuffer();
      final result = await Multiline('Notes').prompt(
        source: ScriptedInput(
          Stream.value(
            'first\rsecond\r/list\r/edit\r2\r\x7f!\r/insert\r2\rmiddle\r/remove\r1\ry\r/done\r',
          ),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, 'middle\nsecon!');
      expect(output.toString(), contains('first'));
      expect(output.toString(), contains('second'));
    },
  );
  test('linear entry retains blank and final blank lines until done', () async {
    final output = StringBuffer();
    final result = await Multiline('Notes').prompt(
      source: ScriptedInput(Stream.value('one\r\r/done\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'one\n');
    expect(output.toString(), contains('/done'));
  });
  test('rich Enter adds a newline and Finish accepts it', () async {
    final output = StringBuffer();
    final result = await Multiline('Notes').prompt(
      source: ScriptedInput(Stream.value('one\rtwo\t\r'), output),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'one\ntwo');
    expect(output.toString(), contains('Finish'));
  });
}
