import 'dart:async';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a scoped session routes one scripted source through successive prompts',
    () async {
      final output = StringBuffer();
      final source = ScriptedInput(Stream.value('Ada\rLovelace\r'), output);

      final answers = await TerminalSession.run(
        (session) async {
          final first = await TextInput('First').prompt(session: session);
          final second = await TextInput('Second').prompt(session: session);
          return [
            (first as Accepted<String>).value,
            (second as Accepted<String>).value,
          ];
        },
        source: source,
        mode: PromptMode.linear,
      );

      expect(answers, ['Ada', 'Lovelace']);
    },
  );

  test('a session rejects a second prompt before it consumes input', () async {
    final input = StreamController<String>();
    final output = StringBuffer();

    await TerminalSession.run(
      (session) async {
        final first = TextInput('First').prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        await expectLater(
          TextInput('Second').prompt(session: session),
          throwsStateError,
        );
        input.add('Ada\r');
        await input.close();
        expect((await first as Accepted<String>).value, 'Ada');
      },
      source: ScriptedInput(input.stream, output),
      mode: PromptMode.linear,
    );
  });

  test('session configuration is inherited and conflicting invocation settings fail', () async {
    final output = StringBuffer();
    await TerminalSession.run(
      (session) async {
        await expectLater(
          TextInput('Name').prompt(
            session: session,
            source: ScriptedInput(Stream.value('wrong\r'), StringBuffer()),
          ),
          throwsArgumentError,
        );
        final result = await TextInput('Name').prompt(session: session);
        expect((result as Accepted<String>).value, 'Ada');
      },
      source: ScriptedInput(Stream.value('Ada\r'), output),
      mode: PromptMode.linear,
    );
  });

  test('session terminal input is acquired only by an attached prompt and restored', () async {
    final terminal = _RecordingTerminal(Stream.value('Ada\r'));

    await TerminalSession.run(
      (session) async {
        expect(
          terminal.events,
          isEmpty,
          reason: 'feedback-only scope has no input lease',
        );
        final result = await TextInput('Name').prompt(session: session);
        expect((result as Accepted<String>).value, 'Ada');
      },
      terminal: terminal,
      mode: PromptMode.linear,
    );

    expect(terminal.events, ['acquire', 'restore']);
  });

  test(
    'closed session handles reject new prompts and callback errors propagate',
    () async {
      late TerminalSession closed;
      final failure = StateError('callback failed');
      await expectLater(
        TerminalSession.run((session) {
          closed = session;
          throw failure;
        }),
        throwsA(same(failure)),
      );
      await expectLater(
        TextInput('Name').prompt(session: closed),
        throwsStateError,
      );
    },
  );
}

final class _RecordingTerminal implements TerminalIo {
  _RecordingTerminal(this.input);

  @override
  final Stream<String> input;
  @override
  final output = StringBuffer();
  @override
  bool get supportsRich => false;
  @override
  Map<String, String?> get environment => const {};

  final List<String> events = [];

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}
