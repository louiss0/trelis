import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

void main() {
  test('a supplied answer is accepted without interpreting commands', () async {
    final result = await TextInput('Name')
        .prompt(source: SuppliedAnswer('/cancel'));
    expect((result as Accepted<String>).value, '/cancel');
  });
  test('linear scripted entry submits a complete line', () async {
    final output = StringBuffer();
    final result = await TextInput('Name').prompt(
      source: ScriptedInput(Stream.value('Ada\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'Ada');
    expect(output.toString(), contains('Name'));
  });
  test('default is editable and required validation keeps the draft', () async {
    final output = StringBuffer();
    final result = await TextInput('Name', initialValue: 'ab', required: true)
        .prompt(
          source: ScriptedInput(
            Stream.value('\x01\x1b[3~\x1b[3~\rZ\r'),
            output,
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'Z');
    expect(output.toString(), contains('Required'));
  });
  test(
    'linear cancel, quoted commands, and incomplete EOF are distinct',
    () async {
      Future<PromptResult<String>> run(String keys) => TextInput('Name').prompt(
        source: ScriptedInput(Stream.value(keys), StringBuffer()),
        mode: PromptMode.linear,
      );
      expect(await run('/cancel\r'), isA<Cancelled<String>>());
      expect((await run('\\/cancel\r') as Accepted<String>).value, '/cancel');
      expect(await run('/cancel'), isA<InputEnded<String>>());
    },
  );
  test('validation retains the invalid draft for correction', () async {
    final output = StringBuffer();
    final result =
        await TextInput(
          'Name',
          validate: (value) => value == 'abc' ? null : 'Enter abc',
        ).prompt(
          source: ScriptedInput(Stream.value('ab\rc\r'), output),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'abc');
    expect(output.toString(), contains('Enter abc'));
  });
  test(
    'explicit rich mode fails before writing when output lacks capability',
    () async {
      final output = StringBuffer();
      final source = ScriptedInput(
        Stream.value('ok\r'),
        output,
        supportsRich: false,
      );
      final result = await TextInput('Name')
          .prompt(source: source, mode: PromptMode.rich);
      expect(result, isA<Unavailable<String>>());
      expect(output.toString(), isEmpty);
    },
  );
  test('oversized paste is rejected atomically', () async {
    final output = StringBuffer();
    final result = await TextInput('Name', maxLength: 3).prompt(
      source: ScriptedInput(
        Stream.value('a\x1b[200~bcd\x1b[201~\r'),
        output,
        outputProfile: richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'a');
    expect(output.toString(), contains('limit'));
  });
  test(
    'sessions cannot overlap and a completed instance can be reused',
    () async {
      final input = StreamController<String>();
      final prompt = TextInput('Name');
      final pending = prompt.prompt(
        source: ScriptedInput(input.stream, StringBuffer()),
      );
      await expectLater(
        prompt.prompt(source: SuppliedAnswer('x')),
        throwsStateError,
      );
      input.add('one\r');
      expect((await pending as Accepted<String>).value, 'one');
      await input.close();
      expect(
        (await prompt.prompt(
          source: SuppliedAnswer('two'),
        ) as Accepted<String>).value,
        'two',
      );
    },
  );
  test('redirected stdin is not consumed without explicit policy', () async {
    final result = await TextInput('Name').prompt();
    expect(result, isA<Unavailable<String>>());
  });
  test(
    'user preference overrides application preference before setup',
    () async {
      final output = StringBuffer();
      final result = await TextInput('Name').prompt(
        source: ScriptedInput(
          Stream.value('ok\r'),
          output,
          supportsRich: false,
        ),
        userPreference: PromptMode.rich,
        applicationPreference: PromptMode.linear,
      );
      expect(result, isA<Unavailable<String>>());
      expect(output.toString(), isEmpty);
    },
  );
  test('automatic mode falls back to command-aware linear entry', () async {
    final result = await TextInput('Name').prompt(
      source: ScriptedInput(
        Stream.value('/cancel\r'),
        StringBuffer(),
        supportsRich: false,
      ),
    );
    expect(result, isA<Cancelled<String>>());
  });
  test('linear instructions disclose required status and quoting', () async {
    final output = StringBuffer();
    await TextInput('Name', required: true).prompt(
      source: ScriptedInput(Stream.value('ok\r'), output),
      mode: PromptMode.linear,
    );
    expect(output.toString(), contains('Required'));
    expect(output.toString(), contains('/cancel'));
    expect(output.toString(), contains('backslash'));
  });
  test('supplied answers cannot bypass required validation', () async {
    final result = await TextInput(
      'Name',
      required: true,
    ).prompt(source: SuppliedAnswer(''));
    expect(result, isA<Unavailable<String>>());
  });
  test('incomplete escape at EOF does not cancel', () async {
    final result = await TextInput('Name').prompt(
      source: ScriptedInput(Stream.value('partial\x1b'), StringBuffer()),
      mode: PromptMode.linear,
    );
    expect(result, isA<InputEnded<String>>());
  });
  test('split VT navigation edits without function keys cancelling', () async {
    for (final mode in [PromptMode.linear, PromptMode.rich]) {
      final result = await TextInput('Name', initialValue: 'abx').prompt(
        source: ScriptedInput(
          Stream.fromIterable(
            '\x1bOP\x1bOH\x1bOC\x1bOC\x1b[3~c\x1bOF!\x1bOD\x1b[3~\r'.split(''),
          ),
          StringBuffer(),
          outputProfile: mode == PromptMode.rich
              ? richProfile
              : const OutputProfile(),
        ),
        mode: mode,
      );
      expect((result as Accepted<String>).value, 'abc');
    }
  });
  test('control C interrupts while help is open', () async {
    final result = await TextInput('Name').prompt(
      source: ScriptedInput(
        Stream.value('draft\x14\x03'),
        StringBuffer(),
        outputProfile: richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(result, isA<Interrupted<String>>());
  });
  test('identified pasted command remains literal after editing', () async {
    final result = await TextInput('Name').prompt(
      source: ScriptedInput(
        Stream.value('\x1b[200~/cancel\x1b[201~x\x7f\r'),
        StringBuffer(),
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, '/cancel');
  });
  test('backspace deletes a full grapheme', () async {
    final result = await TextInput('Name', initialValue: 'ae\u0301').prompt(
      source: ScriptedInput(
        Stream.value('\x7f\r'),
        StringBuffer(),
        outputProfile: richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'a');
  });
  test('CRLF is one submission when validation retains the draft', () async {
    final output = StringBuffer();
    final result =
        await TextInput(
          'Name',
          validate: (value) => value == 'ab' ? null : 'Enter ab',
        ).prompt(
          source: ScriptedInput(
            Stream.value('a\r\nb\r\n'),
            output,
            supportsRich: false,
          ),
        );
    expect((result as Accepted<String>).value, 'ab');
    expect(RegExp('Enter ab').allMatches(output.toString()).length, 1);
  });
  test(
    'rich rendering anchors the physical caret at the editable region',
    () async {
      final output = StringBuffer();
      final result = await TextInput('Name').prompt(
        source: ScriptedInput(
          Stream.value('ab\x1b[DX\r'),
          output,
          outputProfile: richProfile,
        ),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<String>).value, 'aXb');
      expect(output.toString(), contains('> aX\x1b[sb\x1b[u'));
    },
  );
  test('rich and linear output safely encodes display text without changing the accepted answer', () async {
    const answer = 'left\u202Eright';
    const unsafeValidation = 'unsafe \x1b[2J\u202E';
    for (final mode in [PromptMode.rich, PromptMode.linear]) {
      final output = StringBuffer();
      final result =
          await TextInput(
            'Name\u202E',
            validate: (value) => value == answer ? null : unsafeValidation,
          ).prompt(
            source: ScriptedInput(
              Stream.value('$answer\r'),
              output,
              outputProfile: richProfile,
            ),
            mode: mode,
          );

      expect((result as Accepted<String>).value, answer);
      expect(output.toString(), contains(r'Name\u{202E}'));
      expect(output.toString(), contains(r'left\u{202E}right'));
      expect(output.toString(), isNot(contains(answer)));

      final invalidOutput = StringBuffer();
      await TextInput('Name', validate: (_) => unsafeValidation).prompt(
        source: ScriptedInput(
          Stream.value('x\r\x03'),
          invalidOutput,
          outputProfile: richProfile,
        ),
        mode: mode,
      );
      expect(invalidOutput.toString(), contains(r'unsafe \u{001B}[2J\u{202E}'));
      expect(invalidOutput.toString(), isNot(contains(unsafeValidation)));
    }
  });
  test(
    'configuration rejects terminal control characters before a session',
    () {
      expect(
        () => TextInput('Name', initialValue: 'bad\x1b[2J'),
        throwsArgumentError,
      );
      expect(() => TextInput('bad\x1b[2J'), throwsArgumentError);
    },
  );
}
