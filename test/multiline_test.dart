import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

/// Synthetic rich output declares positive geometry; the legacy rich hint is
/// not geometry evidence.
final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

void main() {
  test('supplied answers are literal, normalized and validated', () async {
    final prompt = Multiline('Notes', required: true);
    final accepted = await prompt.prompt(source: SuppliedAnswer('/done\r\n\r'));
    expect((accepted as Accepted<String>).value, '/done\n\n');
    expect(
      await prompt.prompt(source: SuppliedAnswer('')),
      isA<Unavailable<String>>(),
    );
  });
  test(
    'rich mode capability and incomplete outcomes remain distinct',
    () async {
      final output = StringBuffer();
      final unavailable = await Multiline('Notes').prompt(
        source: ScriptedInput(Stream.value(''), output, supportsRich: false),
        mode: PromptMode.rich,
      );
      expect(unavailable, isA<Unavailable<String>>());
      expect(output.toString(), isEmpty);
      Future<PromptResult<String>> run(String input) =>
          Multiline('Notes').prompt(
            source: ScriptedInput(
              Stream.value(input),
              StringBuffer(),
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect(await run('a\x1b\t'), isA<Cancelled<String>>());
      expect(await run('a\x03'), isA<Interrupted<String>>());
      expect(await run('a'), isA<InputEnded<String>>());
    },
  );
  test('declining line deletion preserves the draft', () async {
    final result = await Multiline('Notes', initialValue: 'first\nsecond')
        .prompt(
          source: ScriptedInput(
            Stream.value('/remove\r1\rn\r/done\r'),
            StringBuffer(),
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'first\nsecond');
  });
  test('linear character limit rejects oversized insertion while keeping command access', () async {
    final output = StringBuffer();
    final result = await Multiline('Notes', maxLength: 3).prompt(
      source: ScriptedInput(Stream.value('a\rxy\r/done\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'a\nx');
    expect(output.toString(), contains('limit'));
  });
  test(
    'linear cancellation interruption and partial EOF never submit',
    () async {
      Future<PromptResult<String>> run(String input) =>
          Multiline('Notes').prompt(
            source: ScriptedInput(Stream.value(input), StringBuffer()),
            mode: PromptMode.linear,
          );
      expect(await run('draft\r/cancel\r'), isA<Cancelled<String>>());
      expect(await run('draft\r\x03'), isA<Interrupted<String>>());
      expect(await run('draft\r/done'), isA<InputEnded<String>>());
    },
  );
  test('rich editing updates the focused line in place', () async {
    final output = StringBuffer();
    await Multiline('Notes').prompt(
      source: ScriptedInput(
        Stream.value('ab\t\r'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(output.toString(), contains('\r\x1b[2K'));
    expect(output.toString(), contains('\x1b[s'));
  });
  test(
    'oversized paste into an existing line is rejected atomically',
    () async {
      final output = StringBuffer();
      final result =
          await Multiline('Notes', initialValue: 'a\nb', maxLength: 4).prompt(
            source: ScriptedInput(
              Stream.value('/edit\r1\r\x1b[200~xx\x1b[201~\r/done\r'),
              output,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'a\nb');
      expect(output.toString(), contains('limit'));
    },
  );
  test(
    'rich Insert tab action inserts a literal tab before finishing',
    () async {
      final output = StringBuffer();
      final result = await Multiline('Notes').prompt(
        source: ScriptedInput(
          Stream.value('a\t\t\rb\t\r'),
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<String>).value, 'a\tb');
      expect(output.toString(), contains('Insert tab'));
      expect(output.toString(), contains(r'a\tb'));
      expect(output.toString(), isNot(contains('a?b')));
      expect(output.toString(), isNot(contains('â‡¥')));
    },
  );
  test(
    'plain rich review distinguishes tabs question marks and backslashes',
    () async {
      Future<String> render(String initial) async {
        final output = StringBuffer();
        final result = await Multiline('Notes', initialValue: initial).prompt(
          source: ScriptedInput(
            Stream.value('\x1a'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
        expect(result, isA<InputEnded<String>>());
        return output.toString();
      }

      final tab = await render('a\tb');
      final question = await render('a?b');
      final backslash = await render(r'a\tb');
      expect(tab, contains(r'a\tb'));
      expect(question, contains('a?b'));
      expect(backslash, contains(r'a\\tb'));
      expect(tab, isNot(question));
      expect(tab, isNot(backslash));
    },
  );
  test('linear help advertises all commands and quoting', () async {
    final output = StringBuffer();
    await Multiline('Notes').prompt(
      source: ScriptedInput(Stream.value('/help\r/done\r'), output),
      mode: PromptMode.linear,
    );
    expect(output.toString(), contains('Help:'));
    final help = output.toString().split('Help:').last;
    expect(help, contains('/list'));
    expect(help, contains('/done'));
    expect(help, contains('backslash'));
  });
  test('rich help is dismissible without cancelling the draft', () async {
    final output = StringBuffer();
    final result = await Multiline('Notes').prompt(
      source: ScriptedInput(
        Stream.value('x\x1bOP\x1b\t\r'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'x');
    expect(output.toString(), contains('Help:'));
  });
  test('F1 opens rich help in both spellings and Ctrl+T is retired', () async {
    Future<(PromptResult<String>, String)> run(String input) async {
      final output = StringBuffer();
      final result = await Multiline('Notes').prompt(
        source: ScriptedInput(
          Stream.value(input),
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      return (result, output.toString());
    }

    for (final f1 in ['\x1bOP', '\x1b[11~']) {
      final (result, transcript) = await run('x$f1\x1b\t\r');
      expect((result as Accepted<String>).value, 'x', reason: f1);
      expect(transcript, contains('Help:'), reason: f1);
    }
    final (result, transcript) = await run('x\x14\t\r');
    expect((result as Accepted<String>).value, 'x');
    expect(transcript, isNot(contains('Help:')));
  });
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
      source: ScriptedInput(
        Stream.value('\x1b[A!\t\r'),
        StringBuffer(),
        outputProfile: _richProfile,
      ),
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
          outputProfile: _richProfile,
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
      source: ScriptedInput(
        Stream.value('one\rtwo\t\r'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'one\ntwo');
    expect(output.toString(), contains('Finish'));
  });
  test('rich Ctrl+J finishes immediately regardless of the focused action', () async {
    Future<PromptResult<String>> run(String input) =>
        Multiline('Notes').prompt(
          source: ScriptedInput(
            Stream.value(input),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    // LF finishes from the Edit action and from a focused Finish action;
    // it never waits for the action row to be reached with Tab.
    expect((await run('one\rtwo\n') as Accepted<String>).value, 'one\ntwo');
    expect((await run('done\t\n') as Accepted<String>).value, 'done');
  });
  test('rich Ctrl+J honours validation and keeps the draft for correction', () async {
    final output = StringBuffer();
    final result = await Multiline(
      'Notes',
      required: true,
      validate: (value) => value == 'ok' ? null : 'Enter ok',
    ).prompt(
      source: ScriptedInput(
        Stream.value('bad\n\x01\x1b[3~\x1b[3~\x1b[3~ok\n'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'ok');
    expect(output.toString(), contains('Enter ok'));
  });
}
