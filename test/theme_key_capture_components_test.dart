import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/state_help_presentation.dart'
    show ComponentRoute, HelpRouteKind, PresentationMode, helpRoute;
import 'package:trelis/src/theme_key_capture_components.dart';
import 'package:trelis/trelis.dart';

void main() {
  test(
    'a themed keypress renders its resolved palette and captures a literal key',
    () async {
      final output = StringBuffer();
      final environment = TerminalEnvironment.scripted(
        input: Stream.value('ca\r'),
        output: output,
        profile: _richProfile,
        supportsRich: true,
      );
      final palette = ColorThemes.terminalDefault.copyWith(
        foreground: TerminalColor.rgb(11, 22, 33),
        background: TerminalColor.rgb(1, 2, 3),
      );
      final prompt = ThemeKeyCapturePrompt.keypress(
        'Shortcut',
        io: environment,
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        colors: ComponentColors.palette(palette),
        themeColors: const ColorPreferences(
          background: BackgroundPreference.dark,
        ),
      );

      final result = await prompt.prompt();

      expect((result as Accepted<KeyGesture>).value.key, 'a');
      expect(output.toString(), contains('Shortcut'));
      expect(output.toString(), contains('\x1b[38;2;11;22;33;48;2;1;2;3m'));
      expect(output.toString(), contains('Review:'));
    },
  );

  test(
    'screen-reader capture puts essential instructions before the prompt',
    () async {
      final output = StringBuffer();
      final environment = TerminalEnvironment.scripted(
        input: Stream.value('/capture\ra/done\r'),
        output: output,
      );
      final prompt = ThemeKeyCapturePrompt.keypress(
        'Shortcut',
        io: environment,
        interaction: const InteractionPreferences(
          screenReader: ScreenReaderPreference.on,
        ),
        instructions: InstructionDisplay.hidden,
      );

      final result = await prompt.prompt();

      expect((result as Accepted<KeyGesture>).value.key, 'a');
      final transcript = output.toString();
      expect(transcript, contains('Shortcut capture.'));
      expect(transcript, contains('/done submits'));
      expect(transcript, contains('after capture'));
      expect(
        transcript.indexOf('Shortcut capture.'),
        lessThan(transcript.indexOf('Shortcut:')),
      );
    },
  );

  test(
    'a themed chord preserves order, modifiers and provenance across reuse',
    () async {
      final output = StringBuffer();
      final prompt = ThemeKeyCapturePrompt.keyChordInput(
        'Sequence',
        io: TerminalEnvironment.scripted(
          input: _AnswersPerListen(['cac\x1b[901;65;0;0~cb\r', 'cb\r']),
          output: output,
          profile: _richProfile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
      );

      final first = await prompt.prompt();
      final gestures = (first as Accepted<List<KeyGesture>>).value;
      expect(gestures.map((g) => g.key), ['a', 'A', 'b']);
      expect(gestures.map((g) => g.provenance), [
        KeyGestureProvenance.ambiguous,
        KeyGestureProvenance.observed,
        KeyGestureProvenance.ambiguous,
      ]);
      final again = await prompt.prompt();
      expect((again as Accepted<List<KeyGesture>>).value.map((g) => g.key), [
        'b',
      ]);
    },
  );

  test('linear capture reviews typed commands as literal data', () async {
    final output = StringBuffer();
    final prompt = ThemeKeyCapturePrompt.keyChordInput(
      'Sequence',
      io: TerminalEnvironment.scripted(
        input: Stream.value('/declare\rCtrl+Shift+A\r/capture\rb/done\r'),
        output: output,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    final result = await prompt.prompt();

    final gestures = (result as Accepted<List<KeyGesture>>).value;
    expect(gestures.map((g) => g.key), ['A', 'b']);
    expect(gestures.first.modifiers, {KeyModifier.control, KeyModifier.shift});
    expect(gestures.first.provenance, KeyGestureProvenance.declared);
    expect(gestures.last.provenance, KeyGestureProvenance.ambiguous);
    expect(output.toString(), contains('Review:'));
  });

  test(
    'ASCII narrow no-color capture keeps the hint and state readable',
    () async {
      final output = StringBuffer();
      final prompt = ThemeKeyCapturePrompt.keypress(
        'Shortcut',
        io: TerminalEnvironment.scripted(
          input: Stream.value('ca\r'),
          output: output,
          profile: OutputProfile(
            cursor: CapabilitySupport.supported,
            glyphs: GlyphSet.ascii,
            geometry: OutputGeometry.fixed(columns: 24, rows: 8),
          ),
          supportsRich: true,
          environment: const {'NO_COLOR': '1'},
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        structure: PromptStructure.rail,
        instructions: InstructionDisplay.hidden,
      );

      final result = await prompt.prompt();

      expect((result as Accepted<KeyGesture>).value.key, 'a');
      expect(output.toString(), isNot(contains('\x1b[38;2')));
      expect(output.toString(), contains('| '));
      expect(output.toString(), contains('c capture'));
      expect(output.toString(), contains('Ctrl+T help'));
      expect(output.toString(), contains('Review:'));
    },
  );

  test('rich and linear hidden instructions keep the compact hint', () async {
    final richOutput = StringBuffer();
    final rich = await ThemeKeyCapturePrompt.keypress(
      'Shortcut',
      io: TerminalEnvironment.scripted(
        input: Stream.value('ca\r'),
        output: richOutput,
        profile: _richProfile,
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      instructions: InstructionDisplay.hidden,
    ).prompt();
    expect(rich, isA<Accepted<KeyGesture>>());
    expect(richOutput.toString(), contains('Enter submit'));
    expect(richOutput.toString(), contains('Ctrl+T help'));

    final linearOutput = StringBuffer();
    final linear = await ThemeKeyCapturePrompt.keypress(
      'Shortcut',
      io: TerminalEnvironment.scripted(
        input: Stream.value('/capture\ra/done\r'),
        output: linearOutput,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      instructions: InstructionDisplay.hidden,
    ).prompt();
    expect(linear, isA<Accepted<KeyGesture>>());
    expect(linearOutput.toString(), contains('/done'));
    expect(linearOutput.toString(), contains('/help'));
    expect(
      linearOutput.toString().indexOf('Use /help after capture'),
      greaterThan(linearOutput.toString().indexOf('Review:')),
    );
  });

  test(
    'detailed help outside armed capture preserves the reviewed chord state',
    () async {
      final route = helpRoute(
        mode: PresentationMode.rich,
        component: ComponentRoute.keyCapture,
      );
      expect(route.kind, HelpRouteKind.outsideCapture);
      expect(route.gesture, isNull);

      final output = StringBuffer();
      final prompt = ThemeKeyCapturePrompt.keyChordInput(
        'Sequence',
        io: TerminalEnvironment.scripted(
          input: Stream.value('cacb\x14\x1bcz\r'),
          output: output,
          profile: _richProfile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
      );

      final result = await prompt.prompt();

      expect((result as Accepted<List<KeyGesture>>).value.map((g) => g.key), [
        'a',
        'b',
        'z',
      ]);
      expect(output.toString(), contains('Help:'));
      expect(output.toString(), contains('Help dismissed.'));
    },
  );

  test('a help gesture while capture is armed stays a candidate', () async {
    final output = StringBuffer();
    final result = await ThemeKeyCapturePrompt.keypress(
      'Shortcut',
      io: TerminalEnvironment.scripted(
        input: Stream.value('c\x14\r'),
        output: output,
        profile: _richProfile,
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
    ).prompt();

    expect(result, isA<InputEnded<KeyGesture>>());
    expect(output.toString(), isNot(contains('Help:')));
    expect(output.toString(), contains('candidate'));
  });

  test(
    'identified command-shaped paste stays literal through a declaration retry',
    () async {
      final output = StringBuffer();
      final result = await ThemeKeyCapturePrompt.keypress(
        'Shortcut',
        io: TerminalEnvironment.scripted(
          input: Stream.value(
            '/declare\r\x1b[200~/help\x1b[201~\r/declare\rCtrl+A\r/done\r',
          ),
          output: output,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      ).prompt();

      final gesture = (result as Accepted<KeyGesture>).value;
      expect(gesture.key, 'A');
      expect(gesture.modifiers, {KeyModifier.control});
      expect(gesture.provenance, KeyGestureProvenance.declared);
      expect(
        output.toString(),
        contains('Invalid logical gesture declaration.'),
      );
      expect(output.toString(), isNot(contains('Help:')));
    },
  );

  test('validation retries, cancellation, interruption and input exhaustion stay distinct', () async {
    final retryOutput = StringBuffer();
    final retry = await ThemeKeyCapturePrompt.keypress(
      'Shortcut',
      io: TerminalEnvironment.scripted(
        input: Stream.value('\rca\r'),
        output: retryOutput,
        profile: _richProfile,
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
    ).prompt();
    expect((retry as Accepted<KeyGesture>).value.key, 'a');
    expect(
      retryOutput.toString(),
      contains('Capture or declare a gesture first.'),
    );

    final cancelled = await ThemeKeyCapturePrompt.keypress(
      'Shortcut',
      io: TerminalEnvironment.scripted(
        input: Stream.value('\x1b'),
        output: StringBuffer(),
        profile: _richProfile,
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
    ).prompt();
    expect(cancelled, isA<Cancelled<KeyGesture>>());

    final interrupted = await ThemeKeyCapturePrompt.keypress(
      'Shortcut',
      io: TerminalEnvironment.scripted(
        input: Stream.value('c\x03'),
        output: StringBuffer(),
        profile: _richProfile,
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
    ).prompt();
    expect(interrupted, isA<Interrupted<KeyGesture>>());

    final ended = await ThemeKeyCapturePrompt.keyChordInput(
      'Sequence',
      io: TerminalEnvironment.scripted(
        input: const Stream<String>.empty(),
        output: StringBuffer(),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    ).prompt();
    expect(ended, isA<InputEnded<List<KeyGesture>>>());
  });

  test(
    'configuration conflicts and unavailable rich output render nothing',
    () async {
      final conflictOutput = StringBuffer();
      final conflict = await ThemeKeyCapturePrompt.keypress(
        'Shortcut',
        io: TerminalEnvironment.scripted(
          input: const Stream<String>.empty(),
          output: conflictOutput,
        ),
        interaction: const InteractionPreferences(
          mode: PromptMode.rich,
          screenReader: ScreenReaderPreference.on,
        ),
      ).prompt();
      expect(conflict, isA<Unavailable<KeyGesture>>());
      expect(
        (conflict as Unavailable<KeyGesture>).reason,
        contains('cannot be combined'),
      );
      expect(conflictOutput.toString(), isEmpty);

      final unavailableOutput = StringBuffer();
      final unavailable = await ThemeKeyCapturePrompt.keypress(
        'Shortcut',
        io: TerminalEnvironment.scripted(
          input: const Stream<String>.empty(),
          output: unavailableOutput,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
      ).prompt();
      expect(unavailable, isA<Unavailable<KeyGesture>>());
      expect(unavailableOutput.toString(), isEmpty);
    },
  );

  test('a concurrent prompt is rejected without a second rendering', () async {
    final output = StringBuffer();
    final input = StreamController<String>();
    var callbacks = 0;
    final prompt = ThemeKeyCapturePrompt.keypress(
      'Shortcut',
      io: TerminalEnvironment.scripted(input: input.stream, output: output),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      onResolved: (_) async => callbacks++,
    );

    final pending = prompt.prompt();
    await _waitUntil(() => output.toString().contains('Shortcut:'));
    final rejected = await prompt.prompt();
    expect(rejected, isA<Unavailable<KeyGesture>>());
    expect(
      (rejected as Unavailable<KeyGesture>).reason,
      contains('already active'),
    );
    input.add('/declare\rCtrl+A\r/done\r');
    await input.close();

    expect((await pending as Accepted<KeyGesture>).value.key, 'A');
    expect(callbacks, 1);
    expect(RegExp('Shortcut:').allMatches(output.toString()), hasLength(1));
  });

  test(
    'one reader subscription serves a prompt and its live feedback',
    () async {
      final output = StringBuffer();
      var listens = 0;
      final input = StreamController<String>(onListen: () => listens++);
      var callbacks = 0;
      final prompt = ThemeKeyCapturePrompt.keypress(
        'Shortcut',
        io: TerminalEnvironment.scripted(input: input.stream, output: output),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async => callbacks++,
      );

      late final Spinner spinner;
      final feedback = await prompt.startFeedback((handle) {
        spinner = Spinner('Policy')..start(session: handle.session);
      }, stop: () => spinner.dispose());
      final pending = prompt.prompt();
      await _waitUntil(() => output.toString().contains('Shortcut:'));
      input.add('/capture\r');
      await Future<void>.delayed(Duration.zero);
      spinner.update('checking');
      await Future<void>.delayed(Duration.zero);
      input.add('a/done\r');
      await input.close();

      expect((await pending as Accepted<KeyGesture>).value.key, 'a');
      await feedback.finish(() => spinner.finish(FeedbackOutcome.completed));
      expect(listens, 1);
      expect(callbacks, 1);
      expect(output.toString(), contains('Policy: checking'));
      expect(output.toString(), isNot(contains('\x1b[?1049h')));
    },
  );

  test(
    'special keys and escape back-out keep the reviewed sequence intact',
    () async {
      final output = StringBuffer();
      final result = await ThemeKeyCapturePrompt.keyChordInput(
        'Sequence',
        io: TerminalEnvironment.scripted(
          input: Stream.value('c\x1b[Ac\x1bca\r'),
          output: output,
          profile: _richProfile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
      ).prompt();

      expect((result as Accepted<List<KeyGesture>>).value.map((g) => g.key), [
        'ArrowUp',
        'a',
      ]);
      expect(output.toString(), contains('ArrowUp'));
      expect(output.toString(), contains('Capture cancelled.'));
    },
  );

  test('an observed record satisfies the observation requirement', () async {
    final result = await ThemeKeyCapturePrompt.keypress(
      'Shortcut',
      requireObservation: true,
      io: TerminalEnvironment.scripted(
        input: Stream.value('c\x1b[901;65;0;0~\r'),
        output: StringBuffer(),
        profile: _richProfile,
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
    ).prompt();

    final gesture = (result as Accepted<KeyGesture>).value;
    expect(gesture.key, 'A');
    expect(gesture.provenance, KeyGestureProvenance.observed);
  });

  test(
    'cleanup failure does not erase an accepted gesture or close caller input',
    () async {
      final output = StringBuffer();
      final events = <String>[];
      final cleanup = StateError('restore failed');
      final input = StreamController<String>();
      final prompt = ThemeKeyCapturePrompt.keypress(
        'Shortcut',
        io: TerminalEnvironment.custom(
          adapter: _FailingKeyTerminal(input.stream, output, events, cleanup),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      final pending = prompt.prompt();
      await _waitUntil(() => output.toString().contains('Shortcut:'));
      input.add('/declare\rCtrl+A\r/done\r');
      await input.close();
      final result = await pending;

      expect((result as Accepted<KeyGesture>).value.key, 'A');
      expect(prompt.cleanupFailures, [cleanup]);
      expect(events, ['acquire', 'acquire', 'restore', 'restore']);
    },
  );
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 120, rows: 24),
);

final class _FailingKeyTerminal implements TerminalIo {
  _FailingKeyTerminal(this.input, this.output, this.events, this.restoreError);

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  final List<String> events;
  final Object restoreError;
  var _leases = 0;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const <String, String?>{};

  @override
  TerminalLease acquire() {
    events.add('acquire');
    final failsOnRestore = ++_leases == 1;
    return TerminalLease(() {
      events.add('restore');
      if (failsOnRestore) throw restoreError;
    });
  }
}

final class _AnswersPerListen extends Stream<String> {
  _AnswersPerListen(this._answers);

  final List<String> _answers;
  var _next = 0;

  @override
  StreamSubscription<String> listen(
    void Function(String event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final answer = _answers[_next++];
    return Stream<String>.value(answer).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition was not met before the test deadline');
}
