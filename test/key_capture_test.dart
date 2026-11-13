import 'dart:async';
import 'dart:io';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'key capture instances reject overlapping sessions and can be reused',
    () async {
      for (final chord in [false, true]) {
        final input = StreamController<String>();
        final key = Keypress('Key');
        final sequence = KeyChordInput('Sequence');
        final pending = chord
            ? sequence.prompt(
                source: ScriptedInput(input.stream, StringBuffer()),
              )
            : key.prompt(source: ScriptedInput(input.stream, StringBuffer()));
        if (chord) {
          await expectLater(
            sequence.prompt(source: SuppliedAnswer('A')),
            throwsStateError,
          );
        } else {
          await expectLater(
            key.prompt(source: SuppliedAnswer('A')),
            throwsStateError,
          );
        }
        await input.close();
        await pending;
        final result = chord
            ? await sequence.prompt(source: SuppliedAnswer('A'))
            : await key.prompt(source: SuppliedAnswer('A'));
        expect(result, isA<Accepted>());
      }
    },
  );
  test('key capture rejects unsafe labels', () {
    expect(() => Keypress('\x1b[2J'), throwsArgumentError);
    expect(() => KeyChordInput('  '), throwsArgumentError);
  });

  test(
    'declarations retain letter case in single and sequence prompts',
    () async {
      final single = await Keypress('Shortcut')
          .prompt(source: SuppliedAnswer('Shift+a'));
      final gesture = (single as Accepted<KeyGesture>).value;
      expect(gesture.key, 'a');
      expect(gesture.modifiers, {KeyModifier.shift});
      expect(gesture.provenance, KeyGestureProvenance.declared);

      final sequence = await KeyChordInput('Sequence')
          .prompt(source: SuppliedAnswer('Ctrl+a,Shift+A'));
      final gestures = (sequence as Accepted<List<KeyGesture>>).value;
      expect(gestures.map((g) => g.key), ['a', 'A']);
      expect(gestures.map((g) => g.provenance), [
        KeyGestureProvenance.declared,
        KeyGestureProvenance.declared,
      ]);
    },
  );

  test('scripted captures retain received letter case and ambiguity', () async {
    final result = await KeyChordInput('Sequence').prompt(
      source: ScriptedInput(
        Stream.value('cacA\r'),
        StringBuffer(),
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    final gestures = (result as Accepted<List<KeyGesture>>).value;
    expect(gestures.map((g) => g.key), ['a', 'A']);
    expect(gestures.map((g) => g.modifiers), [
      <KeyModifier>{},
      <KeyModifier>{},
    ]);
    expect(gestures.map((g) => g.provenance), [
      KeyGestureProvenance.ambiguous,
      KeyGestureProvenance.ambiguous,
    ]);
  });

  test('legacy arrow capture retains ambiguous provenance', () async {
    final result = await Keypress('Shortcut').prompt(
      source: ScriptedInput(
        Stream.value('c\x1b[A\r'),
        StringBuffer(),
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    final gesture = (result as Accepted<KeyGesture>).value;
    expect(gesture.key, 'ArrowUp');
    expect(gesture.provenance, KeyGestureProvenance.ambiguous);
  });

  test(
    'capture alone never submits and Ctrl+C interrupts when armed',
    () async {
      expect(
        await Keypress('Shortcut').prompt(
          source: ScriptedInput(
            Stream.value('ca'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        ),
        isA<InputEnded<KeyGesture>>(),
      );
      expect(
        await Keypress('Shortcut').prompt(
          source: ScriptedInput(
            Stream.value('c\x03'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        ),
        isA<Interrupted<KeyGesture>>(),
      );
    },
  );

  test('observation policy rejects ambiguous stream capture', () async {
    final out = StringBuffer();
    final result = await Keypress('Shortcut', requireObservation: true).prompt(
      source: ScriptedInput(
        Stream.value('ca\r'),
        out,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(result, isA<InputEnded<KeyGesture>>());
    expect(out.toString(), contains('Observation required'));
  });

  test('rich sequence can remove last and clear before review', () async {
    final result = await KeyChordInput('Sequence').prompt(
      source: ScriptedInput(
        Stream.value('cacbrxcz\r'),
        StringBuffer(),
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<List<KeyGesture>>).value.map((g) => g.key), [
      'z',
    ]);
  });

  test('Escape cancels armed capture before root cancellation', () async {
    final out = StringBuffer();
    final result = await Keypress('Shortcut').prompt(
      source: ScriptedInput(
        Stream.value('c\x1b\x1b'),
        out,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(result, isA<Cancelled<KeyGesture>>());
    expect(out.toString(), contains('Capture cancelled'));
  });

  test('linear declaration is reviewed and explicitly submitted', () async {
    final out = StringBuffer();
    final result = await Keypress('Shortcut').prompt(
      source: ScriptedInput(Stream.value('/declare\rCtrl+C\r/done\r'), out),
      mode: PromptMode.linear,
    );
    final gesture = (result as Accepted<KeyGesture>).value;
    expect(gesture.provenance, KeyGestureProvenance.declared);
    expect(gesture.warnings.join(' '), contains('reserved'));
    expect(out.toString(), contains('unverified'));
  });

  test(
    'reserved declarations retain unverified and reserved warnings',
    () async {
      final result = await Keypress('Shortcut')
          .prompt(source: SuppliedAnswer('Ctrl+C'));
      final gesture = (result as Accepted<KeyGesture>).value;
      expect(gesture.warnings.join(' '), contains('reserved'));
      expect(gesture.warnings.join(' '), contains('unverified'));
    },
  );

  test('linear capture reviews and submits an ordered sequence', () async {
    final out = StringBuffer();
    final result = await KeyChordInput('Sequence').prompt(
      source: ScriptedInput(Stream.value('/capture\ra/capture\rb/done\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<KeyGesture>>).value.map((g) => g.key), [
      'a',
      'b',
    ]);
    expect(out.toString(), contains('Review:'));
  });

  test(
    'rich key sequence captures ordered gestures and submits explicitly',
    () async {
      final result = await KeyChordInput('Sequence').prompt(
        source: ScriptedInput(
          Stream.value('cacb\r'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<List<KeyGesture>>).value.map((g) => g.key), [
        'a',
        'b',
      ]);
    },
  );

  test('rich capture returns to review before explicit submission', () async {
    final out = StringBuffer();
    final result = await Keypress('Shortcut').prompt(
      source: ScriptedInput(
        Stream.value('ca\r'),
        out,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<KeyGesture>).value.key, 'a');
    expect(out.toString(), contains('Review'));
  });

  test(
    'a supplied key sequence retains ordered declaration provenance',
    () async {
      final result = await KeyChordInput('Sequence')
          .prompt(source: SuppliedAnswer('Ctrl+A,Alt+B'));
      final gestures = (result as Accepted<List<KeyGesture>>).value;
      expect(gestures.map((g) => g.key), ['A', 'B']);
      expect(gestures.map((g) => g.modifiers), [
        {KeyModifier.control},
        {KeyModifier.alt},
      ]);
      expect(
        gestures.every((g) => g.provenance == KeyGestureProvenance.declared),
        isTrue,
      );
    },
  );

  test('observation-required policy rejects a supplied declaration', () async {
    final result = await Keypress(
      'Shortcut',
      requireObservation: true,
    ).prompt(source: SuppliedAnswer('Ctrl+A'));
    expect(result, isA<Unavailable<KeyGesture>>());
  });

  test('invalid logical key names are rejected rather than invented', () async {
    final result = await Keypress('Shortcut')
        .prompt(source: SuppliedAnswer('Ctrl+NotAKey'));
    expect(result, isA<Unavailable<KeyGesture>>());
  });

  test('supplied logical gesture remains a declaration', () async {
    final result = await Keypress('Shortcut')
        .prompt(source: SuppliedAnswer('Ctrl+A'));
    final gesture = (result as Accepted<KeyGesture>).value;
    expect(gesture.key, 'A');
    expect(gesture.modifiers, {KeyModifier.control});
    expect(gesture.provenance, KeyGestureProvenance.declared);
  });

  test('rich capture needs declared geometry and renders nothing when it is absent', () async {
    final unavailableOutput = StringBuffer();
    final unavailable = await Keypress('Shortcut').prompt(
      source: ScriptedInput(Stream.value('ca\r'), unavailableOutput),
      mode: PromptMode.rich,
    );
    expect(unavailable, isA<Unavailable<KeyGesture>>());
    expect(unavailableOutput.toString(), isEmpty);

    final accepted = await Keypress('Shortcut').prompt(
      source: ScriptedInput(
        Stream.value('ca\r'),
        StringBuffer(),
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((accepted as Accepted<KeyGesture>).value.key, 'a');
  });

  test(
    'an explicit terminal adapter is leased, restored and cannot be combined',
    () async {
      final output = StringBuffer();
      final terminal = _KeyTerminal(Stream.value('ca\r'), output, _richProfile);
      final result = await KeyChordInput('Sequence')
          .prompt(terminal: terminal, mode: PromptMode.rich);
      expect((result as Accepted<List<KeyGesture>>).value.single.key, 'a');
      expect(terminal.events, ['acquire', 'restore']);
      expect(output.toString(), contains('Sequence'));

      await expectLater(
        () => Keypress('Shortcut').prompt(
          source: ScriptedInput(Stream.value('ca\r'), StringBuffer()),
          terminal: terminal,
          mode: PromptMode.rich,
        ),
        throwsArgumentError,
      );
      await expectLater(
        () => Keypress(
          'Shortcut',
        ).prompt(terminal: terminal, output: stdout, mode: PromptMode.linear),
        throwsArgumentError,
      );
      expect(terminal.events, ['acquire', 'restore']);
    },
  );

  test(
    'a key capture prompt shares its session reader, writer and feedback',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();

      final result = await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Policy');
          spinner.start(session: session);
          final pending = KeyChordInput('Sequence').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          input.add('c');
          await Future<void>.delayed(Duration.zero);
          input.add('a');
          await Future<void>.delayed(Duration.zero);
          spinner.update('checking');
          await Future<void>.delayed(Duration.zero);
          input.add('\r');
          await input.close();
          spinner.finish(FeedbackOutcome.completed);
          return await pending;
        },
        source: ScriptedInput(
          input.stream,
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<List<KeyGesture>>).value.single.key, 'a');
      expect(output.toString(), contains('[status] Policy: checking'));
      expect(output.toString(), contains('Review:'));
    },
  );

  test(
    'an attached key capture rejects competing invocation options',
    () async {
      await TerminalSession.run((session) async {
        await expectLater(
          () =>
              Keypress('Shortcut')
                  .prompt(session: session, mode: PromptMode.rich),
          throwsArgumentError,
        );
        return null;
      }, source: ScriptedInput(const Stream.empty(), StringBuffer()));
    },
  );

  test(
    'rich help is explicit, dismissible and never steals a candidate',
    () async {
      final helpOutput = StringBuffer();
      final result = await Keypress('Shortcut').prompt(
        source: ScriptedInput(
          Stream.value('\x14\x1bca\r'),
          helpOutput,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<KeyGesture>).value.key, 'a');
      final help = helpOutput.toString();
      expect(help, contains('Help:'));
      expect(help, contains('Help dismissed'));
      expect(help, contains('reviewed'));
      expect(help, contains('reserved'));
      expect(help, contains('ambiguous'));
      expect(help, contains('unverified'));
      expect(help, contains('observation'));

      final armedOutput = StringBuffer();
      final armed = await KeyChordInput('Sequence').prompt(
        source: ScriptedInput(
          Stream.value('c\x14\r'),
          armedOutput,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect(armed, isA<InputEnded<List<KeyGesture>>>());
      expect(armedOutput.toString(), contains('Gesture unavailable.'));
      expect(armedOutput.toString(), isNot(contains('Help:')));
      expect(armedOutput.toString(), contains('candidate'));
    },
  );

  test(
    'linear help names the workflow, provenance and reserved keys',
    () async {
      final out = StringBuffer();
      final result = await KeyChordInput('Sequence').prompt(
        source: ScriptedInput(Stream.value('/help\r/capture\ra/done\r'), out),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<List<KeyGesture>>).value.single.key, 'a');
      final help = out.toString();
      expect(help, contains('/capture'));
      expect(help, contains('/done'));
      expect(help, contains('backslash'));
      expect(help, contains('Identified paste'));
      expect(help, contains('ambiguous'));
      expect(help, contains('unverified'));
      expect(help, contains('Observation is'));
    },
  );

  test('linear declaration entry has its own help and back-out', () async {
    final out = StringBuffer();
    final result = await Keypress('Shortcut').prompt(
      source: ScriptedInput(
        Stream.value('/declare\r/help\r\x1b/cancel\r'),
        out,
      ),
      mode: PromptMode.linear,
    );
    expect(result, isA<Cancelled<KeyGesture>>());
    expect(out.toString(), contains('F1 to F12'));
    expect(out.toString(), contains('cancels declaration entry'));
  });

  test(
    'linear capture advertises back-out instead of a help command',
    () async {
      final out = StringBuffer();
      final result = await KeyChordInput('Sequence').prompt(
        source: ScriptedInput(Stream.value('/capture\r\x1b/cancel\r'), out),
        mode: PromptMode.linear,
      );
      expect(result, isA<Cancelled<List<KeyGesture>>>());
      expect(out.toString(), contains('Escape cancels capture'));
      expect(out.toString(), contains('/help is captured as a gesture'));
      expect(out.toString(), contains('Capture cancelled.'));
    },
  );

  test('synthetic native records keep observed provenance', () async {
    final result = await KeyChordInput('Sequence', requireObservation: true)
        .prompt(
          source: ScriptedInput(
            Stream.value('c\x1b[901;84;20;12~c\x1b[901;65;0;0~\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    final gestures = (result as Accepted<List<KeyGesture>>).value;
    expect(gestures.map((g) => g.key), ['T', 'A']);
    expect(gestures.map((g) => g.modifiers), [
      {KeyModifier.control},
      <KeyModifier>{},
    ]);
    expect(gestures.map((g) => g.provenance), [
      KeyGestureProvenance.observed,
      KeyGestureProvenance.observed,
    ]);
  });

  test(
    'session help keeps background feedback until it is dismissed',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();

      final result = await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Policy');
          spinner.start(session: session);
          final pending = Keypress('Shortcut').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          input.add('\x14');
          await Future<void>.delayed(Duration.zero);
          spinner.update('checking');
          await Future<void>.delayed(Duration.zero);
          input.add('\x1b');
          await Future<void>.delayed(Duration.zero);
          input.add('ca\r');
          await input.close();
          spinner.finish(FeedbackOutcome.completed);
          return await pending;
        },
        source: ScriptedInput(
          input.stream,
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<KeyGesture>).value.key, 'a');
      final transcript = output.toString();
      expect(transcript, contains('Help dismissed.'));
      expect(transcript, contains('Policy: checking'));
      expect(
        transcript.indexOf('Help dismissed.'),
        lessThan(transcript.indexOf('Policy: checking')),
      );
    },
  );

  test(
    'an unrepresentable capture is unavailable rather than invented',
    () async {
      final out = StringBuffer();
      final result = await Keypress('Shortcut').prompt(
        source: ScriptedInput(
          Stream.value('c\x01\r'),
          out,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect(result, isA<InputEnded<KeyGesture>>());
      expect(out.toString(), contains('Gesture unavailable.'));
      expect(out.toString(), contains('Review: empty'));
    },
  );

  test(
    'observation policy rejects mixed reviews until only observations remain',
    () async {
      final out = StringBuffer();
      final result = await KeyChordInput('Sequence', requireObservation: true)
          .prompt(
            source: ScriptedInput(
              Stream.value('cac\x1b[901;65;0;0~\rrrc\x1b[901;66;0;0~\r'),
              out,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      final gestures = (result as Accepted<List<KeyGesture>>).value;
      expect(gestures.single.key, 'B');
      expect(gestures.single.provenance, KeyGestureProvenance.observed);
      expect(out.toString(), contains('Observation required'));
      expect(out.toString(), contains('ambiguous'));
    },
  );
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

final class _KeyTerminal implements TerminalIo, TerminalIoOutputProfile {
  _KeyTerminal(this.input, this.output, this.outputProfile);

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  @override
  final OutputProfile outputProfile;

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
