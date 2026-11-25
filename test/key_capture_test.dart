import 'dart:async';
import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test(
    'key capture instances reject overlapping sessions and can be reused',
    () async {
      for (final chord in [false, true]) {
        final input = StreamController<String>();
        final key = Keypress('Key');
        final sequence = Keybind<List<String>>('Sequence');
        final pending = chord
            ? sequence.prompt(
                source: ScriptedInput(input.stream, StringBuffer()),
              )
            : key.prompt(source: ScriptedInput(input.stream, StringBuffer()));
        if (chord) {
          await expectLater(
            sequence.prompt(source: SuppliedAnswer('Ctrl,B')),
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
            ? await sequence.prompt(source: SuppliedAnswer('Ctrl,B'))
            : await key.prompt(source: SuppliedAnswer('A'));
        expect(result, isA<Accepted>());
      }
    },
  );
  test('key capture rejects unsafe labels', () {
    expect(() => Keypress('\x1b[2J'), throwsArgumentError);
    expect(() => Keybind<List<String>>('  '), throwsArgumentError);
    expect(
      () => Keybind<List<String>>('Sequence', modifiers: const []),
      throwsArgumentError,
    );
    expect(
      () =>
          Keybind<List<String>>('Sequence', modifiers: const ['Ctrl', 'Ctrl']),
      throwsArgumentError,
    );
    expect(
      () => Keybind<List<String>>('Sequence', symbols: const []),
      throwsArgumentError,
    );
    expect(
      () => Keybind<List<String>>('Sequence', symbols: const ['NotAKey']),
      throwsArgumentError,
    );
    expect(
      () => Keybind<List<String>>('Sequence', symbols: const ['Ctrl+B']),
      throwsArgumentError,
    );
    expect(
      () => Keybind<List<String>>('Sequence', initialValue: const ['B']),
      throwsArgumentError,
    );
    expect(
      () => Keybind<List<String>>(
        'Sequence',
        initialValue: const ['Ctrl', 'Ctrl', 'B'],
      ),
      throwsArgumentError,
    );
    expect(
      () => Keybind<List<String>>('Sequence', modifierKeyLimit: 0),
      throwsArgumentError,
    );
    expect(
      () => Keybind<List<String>>('Sequence', modifierKeyLimit: 5),
      throwsArgumentError,
    );
    expect(
      () => Keybind<List<String>>(
        'Sequence',
        symbols: const ['a', 'b'],
        keyLimit: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => Keybind<List<String>>(
        'Sequence',
        symbols: const ['a', 'b'],
        keyLimit: 3,
      ),
      throwsArgumentError,
    );
    expect(
      () => Keybind<List<String>>(
        'Sequence',
        modifierKeyLimit: 1,
        initialValue: const ['Ctrl', 'Shift', 'B'],
      ),
      throwsArgumentError,
    );
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

      final sequence = await Keybind<List<String>>('Sequence')
          .prompt(source: SuppliedAnswer('Ctrl,a,b'));
      final tokens = (sequence as Accepted<List<String>>).value;
      expect(tokens, ['Ctrl', 'a', 'b']);
    },
  );

  test('scripted keybind selections retain received letter case', () async {
    final result =
        await Keybind<List<String>>(
          'Sequence',
          symbols: const ['a', 'A'],
        ).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B\t\x1b[B\x1b[B\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    final tokens = (result as Accepted<List<String>>).value;
    expect(tokens, ['Ctrl', 'A']);
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

  test('rich keybind cells can be added and removed before submit', () async {
    final result =
        await Keybind<List<String>>(
          'Sequence',
          symbols: const ['a', 'b'],
        ).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B+\x1b[B-\x1b[B\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['Ctrl', 'a']);
  });

  test('+ on a modifier cell grows the modifier region', () async {
    final result =
        await Keybind<List<String>>(
          'Sequence',
          symbols: const ['a', 'b'],
        ).prompt(
          source: ScriptedInput(
            // Down: cell0=Ctrl; +: new modifier cell focused; Down: Alt
            // (Ctrl is used); Tab: key cell; Down: a; Enter.
            Stream.value('\x1b[B+\x1b[B\t\x1b[B\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['Ctrl', 'Alt', 'a']);
  });

  test('+ on a modifier cell stops at modifierKeyLimit', () async {
    final out = StringBuffer();
    final result =
        await Keybind<List<String>>(
          'Sequence',
          symbols: const ['a', 'b'],
          modifierKeyLimit: 1,
        ).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B+\t\x1b[B\r'),
            out,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['Ctrl', 'a']);
    expect(out.toString(), contains('at most 1 modifier'));
  });

  test('+ on a key cell stops at keyLimit', () async {
    final out = StringBuffer();
    final result =
        await Keybind<List<String>>(
          'Sequence',
          symbols: const ['a', 'b'],
          keyLimit: 1,
        ).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B\t+\x1b[B\r'),
            out,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['Ctrl', 'a']);
    expect(out.toString(), contains('at most 1 key'));
  });

  test('- refuses to empty the modifier region', () async {
    final out = StringBuffer();
    final result =
        await Keybind<List<String>>(
          'Sequence',
          symbols: const ['a', 'b'],
        ).prompt(
          source: ScriptedInput(
            // cell0=Ctrl, cell1=a, + grows keys to [Ctrl,a,b]; focus back
            // on the lone modifier cell: - must refuse.
            Stream.value('\x1b[B\t\x1b[B+\x1b[B\x1b[Z\x1b[Z-\r'),
            out,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['Ctrl', 'a', 'b']);
    expect(out.toString(), contains('at least one modifier'));
  });

  test('- refuses to empty the key region', () async {
    final out = StringBuffer();
    final result =
        await Keybind<List<String>>(
          'Sequence',
          symbols: const ['a', 'b'],
        ).prompt(
          source: ScriptedInput(
            // cell0=Ctrl, + grows modifiers and Down sets Alt on it; focus
            // the lone key cell: - must refuse, then Down sets a.
            Stream.value('\x1b[B+\x1b[B\t-\x1b[B\r'),
            out,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['Ctrl', 'Alt', 'a']);
    expect(out.toString(), contains('at least one key'));
  });

  test('rich keybind never drops below two cells', () async {
    final out = StringBuffer();
    final result =
        await Keybind<List<String>>(
          'Sequence',
          symbols: const ['a', 'b'],
        ).prompt(
          source: ScriptedInput(
            Stream.value('---\x1b[B\t\x1b[B\r'),
            out,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['Ctrl', 'a']);
    expect(out.toString(), contains('at least one modifier'));
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

  test('a declared Ctrl+T binding is accepted now that F1 owns help', () async {
    final result = await Keypress('Shortcut').prompt(
      source: ScriptedInput(
        Stream.value('/declare\rCtrl+T\r/done\r'),
        StringBuffer(),
      ),
      mode: PromptMode.linear,
    );
    final gesture = (result as Accepted<KeyGesture>).value;
    expect(gesture.key, 'T');
    expect(gesture.modifiers, {KeyModifier.control});
    expect(gesture.provenance, KeyGestureProvenance.declared);
  });

  test('Ctrl+T no longer opens help in the rich action stage', () async {
    final out = StringBuffer();
    final result = await Keypress('Shortcut').prompt(
      source: ScriptedInput(
        Stream.value('\x14ca\r'),
        out,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<KeyGesture>).value.key, 'a');
    expect(out.toString(), isNot(contains('Help:')));
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

  test('linear keybind accepts comma-separated gesture tokens', () async {
    final out = StringBuffer();
    final result =
        await Keybind<List<String>>(
          'Sequence',
          symbols: const ['a', 'b'],
        ).prompt(
          source: ScriptedInput(Stream.value('Ctrl,b\r'), out),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<List<String>>).value, ['Ctrl', 'b']);
    expect(out.toString(), contains('Sequence'));
  });

  test('linear keybind joins the tokens when the flag is set', () async {
    final result =
        await Keybind<String>.joined(
          'Sequence',
          symbols: const ['a', 'b'],
        ).prompt(
          source: ScriptedInput(Stream.value('Ctrl,a,b\r'), StringBuffer()),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'Ctrl+a+b');
  });

  test('rich keybind selects ordered symbols and submits explicitly', () async {
    final result =
        await Keybind<List<String>>(
          'Sequence',
          symbols: const ['a', 'b'],
        ).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B\t\x1b[B\x1b[B\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['Ctrl', 'b']);
  });

  test('rich joined keybind returns the plus declaration', () async {
    final result =
        await Keybind<String>.joined(
          'Sequence',
          symbols: const ['a', 'b'],
        ).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B\t\x1b[B\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'Ctrl+a');
  });

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

  test('a supplied keybind declaration resolves its ordered tokens', () async {
    final result = await Keybind<List<String>>('Sequence')
        .prompt(source: SuppliedAnswer('Ctrl,B,C'));
    expect((result as Accepted<List<String>>).value, ['Ctrl', 'B', 'C']);
    expect(
      (await Keybind<String>.joined('Sequence')
              .prompt(source: SuppliedAnswer('Ctrl+B+C')))
          as Accepted<String>,
      isA<Accepted<String>>().having((a) => a.value, 'value', 'Ctrl+B+C'),
    );
  });

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
      final terminal = _KeyTerminal(
        Stream.value('\x1b[B\t\x1b[B\r'),
        output,
        _richProfile,
      );
      final result = await Keybind<List<String>>(
        'Sequence',
        symbols: const ['a', 'b'],
      ).prompt(terminal: terminal, mode: PromptMode.rich);
      expect((result as Accepted<List<String>>).value, ['Ctrl', 'a']);
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
          final pending = Keybind<List<String>>(
            'Sequence',
            symbols: const ['a', 'b'],
          ).prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          input.add('\x1b[B');
          await Future<void>.delayed(Duration.zero);
          input.add('\t');
          await Future<void>.delayed(Duration.zero);
          spinner.update('checking');
          await Future<void>.delayed(Duration.zero);
          input.add('\x1b[B\r');
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

      expect((result as Accepted<List<String>>).value, ['Ctrl', 'a']);
      expect(output.toString(), contains('[status] - Policy: checking'));
      expect(output.toString(), contains('Sequence'));
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
          Stream.value('\x1bOP\x1bca\r'),
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

      final keybindOutput = StringBuffer();
      final keybind =
          await Keybind<List<String>>(
            'Sequence',
            symbols: const ['a', 'b'],
          ).prompt(
            source: ScriptedInput(
              Stream.value('\x1bOP\x1b\x1b[B\t\x1b[B\r'),
              keybindOutput,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((keybind as Accepted<List<String>>).value, ['Ctrl', 'a']);
      final keybindHelp = keybindOutput.toString();
      expect(keybindHelp, contains('Help:'));
      expect(keybindHelp, contains('cell 1 of 2'));
      expect(keybindHelp, contains('modifier cell'));
    },
  );

  test(
    'rich stage labels cell roles and groups key help by category',
    () async {
      final out = StringBuffer();
      final result = await Keybind<List<String>>('Sequence').prompt(
        source: ScriptedInput(
          Stream.value('\t\x1bOP\x1b\x1b[B\x02\x1b[B\r'),
          out,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<List<String>>).value, ['Ctrl', 'A']);
      final transcript = out.toString();
      expect(transcript, contains(RegExp(r'modifier *key')));
      expect(transcript, contains('letters'));
      expect(transcript, contains('function keys'));
      expect(transcript, contains('named keys'));
    },
  );

  test('linear help names the keybind workflow and catalog rules', () async {
    final out = StringBuffer();
    final result =
        await Keybind<List<String>>(
          'Sequence',
          symbols: const ['a', 'b'],
        ).prompt(
          source: ScriptedInput(Stream.value('/help\rCtrl,b\r'), out),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<List<String>>).value, ['Ctrl', 'b']);
    final help = out.toString();
    expect(help, contains('modifier symbol'));
    expect(help, contains('key symbol'));
    expect(help, contains('/cancel'));
    expect(help, contains('backslash'));
    expect(help, contains('unverified'));
  });

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

  test('linear keybind cancels through the shared text contract', () async {
    final out = StringBuffer();
    final result = await Keybind<List<String>>('Sequence').prompt(
      source: ScriptedInput(Stream.value('/cancel\r'), out),
      mode: PromptMode.linear,
    );
    expect(result, isA<Cancelled<List<String>>>());
  });

  test('synthetic native records keep observed provenance', () async {
    final result = await Keypress('Shortcut', requireObservation: true).prompt(
      source: ScriptedInput(
        Stream.value('c\x1b[901;84;20;12~\r'),
        StringBuffer(),
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    final gesture = (result as Accepted<KeyGesture>).value;
    expect(gesture.key, 'T');
    expect(gesture.modifiers, {KeyModifier.control});
    expect(gesture.provenance, KeyGestureProvenance.observed);
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
          input.add('\x1bOP');
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
    'observation policy rejects ambiguous reviews until one remains',
    () async {
      final out = StringBuffer();
      final result = await Keypress('Shortcut', requireObservation: true)
          .prompt(
            source: ScriptedInput(
              Stream.value('ca\rrc\x1b[901;66;0;0~\r'),
              out,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      final gesture = (result as Accepted<KeyGesture>).value;
      expect(gesture.key, 'B');
      expect(gesture.provenance, KeyGestureProvenance.observed);
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
