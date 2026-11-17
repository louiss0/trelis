import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

void main() {
  test('instruction displays vary optional opening guidance but retain context and help route', () async {
    final compact = StringBuffer();
    await TextInput(
      'Name',
      maxLength: 3,
      instructions: InstructionDisplay.compact,
    ).prompt(
      source: ScriptedInput(
        Stream.value('\x03'),
        compact,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(
      compact.toString(),
      contains('Name (Optional, maximum 3 graphemes).'),
    );
    expect(compact.toString(), contains('Enter submits; Ctrl+T opens help.'));
    expect(compact.toString(), isNot(contains('Home/End go to boundaries')));

    final expanded = StringBuffer();
    await TextInput('Name', instructions: InstructionDisplay.expanded).prompt(
      source: ScriptedInput(
        Stream.value('\x03'),
        expanded,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(expanded.toString(), contains('Home/End go to boundaries'));

    final hidden = StringBuffer();
    await TextInput(
      'Name',
      required: true,
      instructions: InstructionDisplay.hidden,
    ).prompt(
      source: ScriptedInput(
        Stream.value('\x03'),
        hidden,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(hidden.toString(), contains('Name (Required).'));
    expect(hidden.toString(), contains('Ctrl+T opens help.'));
    expect(hidden.toString(), isNot(contains('Enter submits')));
  });

  test(
    'full help is additive, accurate, and restores rich draft and caret',
    () async {
      final output = StringBuffer();
      final transcript = TextInputTranscript();
      final result =
          await TextInput(
            'Name',
            maxLength: 3,
            supplementaryHelp: ['Names are shown to collaborators.'],
          ).prompt(
            source: ScriptedInput(
              Stream.value('ab\x1b[D\x14\x1bX\r'),
              output,
              outputProfile: _richProfile,
              transcript: transcript,
            ),
            mode: PromptMode.rich,
          );

      expect((result as Accepted<String>).value, 'aXb');
      expect(output.toString(), contains('Home/End'));
      expect(output.toString(), contains('maximum 3 graphemes'));
      expect(output.toString(), contains('Names are shown to collaborators.'));
      expect(
        transcript.events.map((event) => event.kind),
        contains(TextInputPresentationEventKind.help),
      );
      expect(transcript.currentView!.text, 'aXb');
      expect(transcript.currentView!.caret, 2);
    },
  );

  test('linear transcript help is reviewable and keeps validation draft and command semantics', () async {
    final output = StringBuffer();
    final transcript = TextInputTranscript();
    final result =
        await TextInput(
          'Name',
          validate: (value) => value == 'ok' ? null : 'Enter ok',
          instructions: InstructionDisplay.hidden,
          supplementaryHelp: ['Use your usual name.'],
        ).prompt(
          source: ScriptedInput(
            Stream.value(
              '/help\rno\r\x01\x1b[3~\x1b[3~\x1b[3~\x1b[3~\x1b[3~\x1b[3~\x1b[3~ok\r',
            ),
            output,
            transcript: transcript,
          ),
          mode: PromptMode.linear,
        );

    expect((result as Accepted<String>).value, 'ok');
    expect(output.toString(), contains('Use your usual name.'));
    expect(output.toString(), contains('Identified paste is literal'));
    expect(output.toString(), contains('Enter ok'));
    expect(
      transcript.events.map((event) => event.kind),
      containsAll([
        TextInputPresentationEventKind.help,
        TextInputPresentationEventKind.validation,
      ]),
    );
  });

  test('help keeps source line breaks and still escapes other controls', () async {
    final output = StringBuffer();
    await TextInput(
      'Name',
      supplementaryHelp: const [
        'Names are shown to collaborators.',
        'Tab\there and \x1b escape.',
        'First\r\nsecond.',
      ],
    ).prompt(
      source: ScriptedInput(
        Stream.value('\x14\x03'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );

    final text = output.toString();
    // A source line break is document structure, so each paragraph reaches the
    // terminal as a real line instead of the `\u{000A}` spelling.
    expect(text, contains('Names are shown to collaborators.\nTab'));
    expect(text, contains('First\nsecond.'));
    expect(text, isNot(contains(r'\u{000A}')));
    // Controls that are content rather than structure keep their visible
    // spelling, so help never emits a live tab or escape.
    expect(text, contains(r'Tab\u{0009}here and \u{001B} escape.'));
  });

  test('help preserves interruption and EOF outcomes', () async {
    for (final entry in <({String keys, Matcher matcher})>[
      (keys: '\x14\x03', matcher: isA<Interrupted<String>>()),
      (keys: '\x14', matcher: isA<InputEnded<String>>()),
    ]) {
      final result = await TextInput('Name').prompt(
        source: ScriptedInput(
          Stream.value(entry.keys),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect(result, entry.matcher);
    }
  });
}
