import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('linear transcript retains distinct repeated validation occurrences without repaint duplicates', () async {
    final transcript = TextInputTranscript();
    final result =
        await TextInput(
          'Name',
          validate: (value) => value == 'abc' ? null : 'Enter abc',
        ).prompt(
          source: ScriptedInput(
            Stream.value('a\rb\rc\r'),
            StringBuffer(),
            transcript: transcript,
          ),
          mode: PromptMode.linear,
        );

    expect((result as Accepted<String>).value, 'abc');
    expect(transcript.events.map((event) => event.kind), [
      TextInputPresentationEventKind.opened,
      TextInputPresentationEventKind.submitted,
      TextInputPresentationEventKind.validation,
      TextInputPresentationEventKind.submitted,
      TextInputPresentationEventKind.validation,
      TextInputPresentationEventKind.submitted,
    ]);
    expect(
      transcript.events
          .where(
            (event) => event.kind == TextInputPresentationEventKind.validation,
          )
          .map((event) => event.text),
      ['Enter abc', 'Enter abc'],
    );
    expect(transcript.events.map((event) => event.id), [1, 2, 3, 4, 5, 6]);
  });

  test('fresh identical help requests retain distinct event identities', () async {
    final transcript = TextInputTranscript();
    final result = await TextInput('Name').prompt(
      source: ScriptedInput(
        Stream.value('\x14\x1b\x14\x1banswer\r'),
        StringBuffer(),
        transcript: transcript,
      ),
      mode: PromptMode.linear,
    );

    expect((result as Accepted<String>).value, 'answer');
    expect(
      transcript.events.where((event) => event.kind == TextInputPresentationEventKind.help).map((event) => event.id),
      [2, 3],
    );
  });

  test(
    'current view records a caret-only edit without creating history',
    () async {
      final transcript = TextInputTranscript();
      final result = await TextInput('Name', initialValue: 'ab').prompt(
        source: ScriptedInput(
          Stream.value('\x1b[D\r'),
          StringBuffer(),
          transcript: transcript,
        ),
        mode: PromptMode.linear,
      );

      expect((result as Accepted<String>).value, 'ab');
      expect(transcript.currentView!.text, 'ab');
      expect(transcript.currentView!.caret, 1);
      expect(transcript.events.map((event) => event.kind), [
        TextInputPresentationEventKind.opened,
        TextInputPresentationEventKind.submitted,
      ]);
    },
  );

  test(
    'submission records literal-command and identified-paste provenance',
    () async {
      final transcript = TextInputTranscript();
      final result = await TextInput('Name').prompt(
        source: ScriptedInput(
          Stream.value('\x1b[200~/cancel\x1b[201~\r'),
          StringBuffer(),
          transcript: transcript,
        ),
        mode: PromptMode.linear,
      );

      expect((result as Accepted<String>).value, '/cancel');
      final submission = transcript.events.last;
      expect(submission.kind, TextInputPresentationEventKind.submitted);
      expect(submission.isLiteral, isTrue);
      expect(submission.containsPaste, isTrue);
    },
  );
}
