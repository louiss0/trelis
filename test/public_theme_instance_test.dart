import 'dart:async';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

final class _CountingAdapter implements TerminalIo, TerminalOwnershipIdentity {
  _CountingAdapter(this._sink, {Stream<String>? input})
    : _input = input ?? const Stream<String>.empty();

  final StringSink _sink;
  final Stream<String> _input;
  int acquired = 0;
  int restored = 0;

  @override
  Stream<String> get input => _input;

  @override
  StringSink get output => _sink;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const {};

  @override
  Object get ownershipIdentity => this;

  @override
  TerminalLease acquire() {
    acquired++;
    return TerminalLease(() => restored++);
  }
}

/// A selected output whose writes can be armed to fail on demand.
final class _SwitchableSink implements StringSink {
  final StringBuffer transcript = StringBuffer();
  Object? failure;

  /// Runs synchronously while [failure] is armed, before the write throws.
  /// The callback is cleared before it is invoked so it cannot recurse.
  void Function()? onFailure;

  void _write(Object? value) {
    final armed = failure;
    if (armed != null) {
      final callback = onFailure;
      if (callback != null) {
        onFailure = null;
        callback();
      }
      Error.throwWithStackTrace(armed, StackTrace.current);
    }
    transcript.write(value);
  }

  @override
  void write(Object? object) => _write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _write(objects.join(separator));

  @override
  void writeCharCode(int charCode) => _write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => _write('$object\n');
}

final class _RecordingClock implements FeedbackClock {
  final List<_RecordingTimer> timers = <_RecordingTimer>[];

  @override
  Duration get elapsed => Duration.zero;

  @override
  FeedbackTimer schedule(Duration delay, void Function() callback) {
    final timer = _RecordingTimer(callback);
    timers.add(timer);
    return timer;
  }
}

final class _RecordingTimer implements FeedbackTimer {
  _RecordingTimer(this.callback);

  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

/// Public-surface tracer for the coordinated theme-instance cutover.
///
/// This file imports only the public barrel. It deliberately avoids the
/// internal component construction seam used by component-level tests.
void main() {
  group('public theme instances', () {
    test('a theme instance creates reusable parameterless prompts', () async {
      final output = StringBuffer();
      final theme = RailTheme(
        io: TerminalEnvironment.scripted(
          input: Stream.fromIterable(['Ada\n']),
          output: output,
        ),
      );
      final prompt = theme.textInput('Name', initialValue: 'seed');
      expect(prompt, isA<ThemePrompt<String>>());
      expect(prompt.structure, PromptStructure.rail);

      expect(await prompt.prompt(), isA<Accepted<String>>());
      expect(await prompt.prompt(), isA<Accepted<String>>());
      final transcript = output.toString();
      // Both invocations restart from the configured initial value rather
      // than retaining the answer from the previous run.
      expect('| Current text: seed\n'.allMatches(transcript), hasLength(2));
    });

    test('all themes construct through instance methods', () {
      final io = TerminalEnvironment.scripted(
        input: const Stream<String>.empty(),
        output: StringBuffer(),
      );
      final themes = <StructuralTheme>[
        PlainTheme(io: io),
        RailTheme(io: io),
        AsciiTheme(io: io),
        DoubleTheme(io: io),
        ChevronTheme(io: io),
        ColonTheme(io: io),
        BoxTheme(io: io),
        BracketTheme(io: io),
        BlockTheme(io: io),
        BranchTheme(io: io),
        RoundTheme(io: io),
        LineTheme(io: io),
        MinimalTheme(io: io),
        FormTheme(io: io),
        LedgerTheme(io: io),
      ];
      expect(themes, hasLength(15));
      for (final theme in themes) {
        expect(theme.textInput('Name'), isA<ThemePrompt<String>>());
        expect(
          theme.select<int>('Choice', [Choice(1, 'One')]),
          isA<ThemePrompt<int>>(),
        );
        expect(theme.text('Done'), isA<ThemeFeedback>());
      }
    });

    test(
      'EOF returns InputEnded and concurrent prompts are rejected',
      () async {
        final theme = PlainTheme(
          io: TerminalEnvironment.scripted(
            input: const Stream<String>.empty(),
            output: StringBuffer(),
          ),
        );
        final first = theme.textInput('Name').prompt();
        expect(await first, isA<InputEnded<String>>());
        final second = theme.textInput('Name');
        final runner = second.prompt();
        final competing = second.prompt();
        expect(await runner, isA<InputEnded<String>>());
        expect(await competing, isA<Unavailable<String>>());
      },
    );

    test('live controls update their own feedback component', () async {
      final output = StringBuffer();
      final theme = PlainTheme(
        io: TerminalEnvironment.scripted(
          input: const Stream<String>.empty(),
          output: output,
        ),
      );
      final progress = await theme
          .progress('Index', total: 4, milestone: 1)
          .start();
      final spinner = await theme.spinner('Scan').start();
      final group = await theme.multiSpinner(['Download', 'Extract']).start();
      progress.update(2);
      spinner.update('looking for files');
      group.update('Download', TaskActivity.running, phase: 'fetching');
      group.finishTask('Download', FeedbackOutcome.completed, detail: 'saved');
      await group.finish(FeedbackOutcome.completed);
      await spinner.finish(FeedbackOutcome.completed);
      await progress.finish(FeedbackOutcome.completed);
      expect(output.toString(), contains('50%'));
      expect(output.toString(), contains('looking for files'));
      expect(output.toString(), contains('fetching'));
      expect(output.toString(), contains('saved'));
    });

    test(
      'a created prompt keeps its configured choices and defaults',
      () async {
        final output = StringBuffer();
        final theme = PlainTheme(
          io: TerminalEnvironment.scripted(
            input: Stream.fromIterable(['/done\r', '/done\r']),
            output: output,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );
        final choices = [Choice('a', 'A'), Choice('b', 'B')];
        final defaults = ['b'];
        final prompt = theme.multiSelect<String>(
          'Choices',
          choices,
          defaultValues: defaults,
        );

        choices.add(Choice('x', 'X'));
        defaults.clear();
        expect(
          await prompt.prompt(),
          isA<Accepted<List<String>>>().having(
            (result) => result.value,
            'value',
            ['b'],
          ),
        );

        choices.clear();
        defaults.add('a');
        expect(
          await prompt.prompt(),
          isA<Accepted<List<String>>>().having(
            (result) => result.value,
            'value',
            ['b'],
          ),
        );
      },
    );

    test('maskedInput keeps the templates supplied at creation', () async {
      final output = StringBuffer();
      final theme = PlainTheme(
        io: TerminalEnvironment.scripted(
          input: Stream.fromIterable(['5\r', '/done\r']),
          output: output,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );
      final templates = [
        MaskTemplate('digit', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ];
      final prompt = theme.maskedInput('Code', templates: templates);
      templates.clear();

      final result = await prompt.prompt();
      expect(result, isA<Accepted<MaskedValue>>());
      expect((result as Accepted<MaskedValue>).value.formatted, '5');
    });

    test('supplementary help is captured at prompt creation', () async {
      final output = StringBuffer();
      final theme = PlainTheme(
        io: TerminalEnvironment.scripted(
          input: Stream.fromIterable(['/help\r', 'Ada\r']),
          output: output,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );
      final help = ['Original application help.'];
      final prompt = theme.textInput('Name', supplementaryHelp: help);
      help
        ..clear()
        ..add('Mutated help text.');

      expect(await prompt.prompt(), isA<Accepted<String>>());
      final transcript = output.toString();
      expect(transcript, contains('Original application help.'));
      expect(transcript, isNot(contains('Mutated help text.')));
    });

    test('multiSpinner keeps the task names supplied at creation', () async {
      final output = StringBuffer();
      final theme = PlainTheme(
        io: TerminalEnvironment.scripted(
          input: const Stream<String>.empty(),
          output: output,
        ),
      );
      final tasks = ['Download', 'Extract'];
      final live = theme.multiSpinner(tasks);
      tasks
        ..clear()
        ..add('Tampered');

      final control = await live.start();
      control.update('Download', TaskActivity.running, phase: 'fetching');
      await control.finish(FeedbackOutcome.completed);

      final transcript = output.toString();
      expect(transcript, contains('Download'));
      expect(transcript, contains('Extract'));
      expect(transcript, isNot(contains('Tampered')));
    });

    group('the passive COLORFGBG hint', () {
      ColorTheme themed(int r, int g, int b) => ColorTheme(
        foreground: TerminalColor.rgb(r, g, b),
        background: const TerminalColor.terminalDefault(),
        muted: const TerminalColor.terminalDefault(),
        accent: const TerminalColor.terminalDefault(),
        selectionForeground: const TerminalColor.terminalDefault(),
        selectionBackground: const TerminalColor.terminalDefault(),
        success: const TerminalColor.terminalDefault(),
        warning: const TerminalColor.terminalDefault(),
        error: const TerminalColor.terminalDefault(),
        border: const TerminalColor.terminalDefault(),
      );
      final light = themed(1, 2, 3);
      final dark = themed(4, 5, 6);

      Future<String> present(
        Map<String, String?> environment, {
        ColorPreferences colors = const ColorPreferences(),
      }) async {
        final output = StringBuffer();
        final theme = PlainTheme(
          io: TerminalEnvironment.scripted(
            input: const Stream<String>.empty(),
            output: output,
            profile: const OutputProfile(colorDepth: ColorDepth.rgb),
            environment: environment,
          ),
          colors: colors,
        );
        await theme
            .text(
              'Probe',
              colors: ComponentColors(lightPalette: light, darkPalette: dark),
            )
            .present();
        return output.toString();
      }

      test('a light hint selects the light palette', () async {
        expect(
          await present(const {'COLORFGBG': '0;15'}),
          contains('38;2;1;2;3'),
        );
      });

      test('a dark hint selects the dark palette', () async {
        expect(
          await present(const {'COLORFGBG': '15;0'}),
          contains('38;2;4;5;6'),
        );
      });

      test('a malformed or unmodelled hint falls back to dark', () async {
        for (final value in ['bogus', '15', '0;15;7;2', '15;3']) {
          expect(
            await present({'COLORFGBG': value}),
            contains('38;2;4;5;6'),
            reason: value,
          );
        }
      });

      test('an explicit background beats the light hint', () async {
        expect(
          await present(
            const {'COLORFGBG': '0;15'},
            colors: const ColorPreferences(
              background: BackgroundPreference.dark,
            ),
          ),
          contains('38;2;4;5;6'),
        );
      });

      test('NO_COLOR strips colours even with a light hint', () async {
        final output = await present(const {
          'COLORFGBG': '0;15',
          'NO_COLOR': '1',
        });
        expect(output, isNot(contains('38;2;1;2;3')));
        expect(output, isNot(contains('38;2;4;5;6')));
      });
    });

    test('locked choices are focusable and show a readable reason', () async {
      final output = StringBuffer();
      final theme = PlainTheme(
        io: TerminalEnvironment.scripted(
          input: Stream.value('2\r'),
          output: output,
          profile: const OutputProfile(
            cursor: CapabilitySupport.supported,
            colorDepth: ColorDepth.none,
            glyphs: GlyphSet.ascii,
          ),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      await theme.select<String>('Deploy target', [
        Choice('staging', 'Staging'),
        Choice.locked('production', 'Production', reason: 'needs approval'),
      ]).prompt();

      expect(output.toString(), contains('[L]'));
      expect(output.toString(), contains('needs approval'));
    });

    test('a live feedback component can outlive its prompt', () async {
      final output = StringBuffer();
      final theme = PlainTheme(
        io: TerminalEnvironment.scripted(
          input: Stream.fromIterable(['Ada\n']),
          output: output,
          ownershipIdentity: const Object(),
        ),
      );
      final feedback = theme.spinner('Working');
      final control = await feedback.start();
      expect(await theme.textInput('Name').prompt(), isA<Accepted<String>>());
      expect(output.toString(), contains('Working'));
      await control.finish(FeedbackOutcome.completed);
      expect(await theme.textInput('After').prompt(), isA<Accepted<String>>());
    });

    test(
      'terminal resources are acquired and restored per active period',
      () async {
        final sink = StringBuffer();
        final adapter = _CountingAdapter(sink);
        final theme = PlainTheme(
          io: TerminalEnvironment.custom(adapter: adapter),
        );
        expect(
          await theme.textInput('First').prompt(),
          isA<InputEnded<String>>(),
        );
        final first = adapter.acquired;
        expect(first, greaterThan(0));
        expect(adapter.restored, first);
        expect(
          await theme.textInput('Second').prompt(),
          isA<InputEnded<String>>(),
        );
        expect(adapter.acquired, greaterThan(first));
        expect(adapter.restored, adapter.acquired);
      },
    );

    test('resolution is published only after the callback succeeds', () async {
      late final PlainTheme theme;
      final entered = Completer<void>();
      final callback = Completer<void>();
      theme = PlainTheme(
        io: TerminalEnvironment.scripted(
          input: const Stream<String>.empty(),
          output: StringBuffer(),
        ),
        onResolved: (_) {
          entered.complete();
          return callback.future;
        },
      );
      expect(theme.resolvedInteraction, isNull);
      final pending = theme.spinner('Working').start();
      await entered.future;
      expect(theme.resolvedInteraction, isNull);
      callback.complete();
      final control = await pending;
      final ThemeInteractionState? active = theme.resolvedInteraction;
      expect(active?.mode, PromptMode.linear);
      await control.stop();
      expect(theme.resolvedInteraction, isNull);
    });

    test(
      'a session writer failure stops every live feedback participant',
      () async {
        final sink = _SwitchableSink();
        final adapter = _CountingAdapter(sink);
        final clock = _RecordingClock();
        var resolutions = 0;
        final theme = PlainTheme(
          io: TerminalEnvironment.custom(adapter: adapter),
          onResolved: (_) => resolutions++,
        );
        final progress = await theme
            .progress('Index', total: 4, clock: clock)
            .start();
        final spinner = await theme.spinner('Scan').start();
        // The first update flushes immediately; a second within the interval
        // leaves a pending flush scheduled on the injected clock.
        progress.update(1);
        progress.update(2);
        expect(clock.timers, isNotEmpty);

        final failure = StateError('armed writer failure');
        sink.failure = failure;
        Object? thrown;
        try {
          spinner.update('fail');
        } catch (error) {
          thrown = error;
        }
        expect(thrown, same(failure));

        // Without touching either control, the failed writer ends the active
        // period: the next operation resolves a fresh period on the restored
        // terminal.
        sink.failure = null;
        await theme
            .text('Recovered')
            .present()
            .timeout(const Duration(seconds: 5));
        expect(resolutions, 2);
        expect(adapter.restored, adapter.acquired);
        expect(clock.timers.every((timer) => timer.cancelled), isTrue);

        // Finishing an automatically stopped participant stays idempotent.
        await spinner.stop();
        await progress.stop();
      },
    );

    test('a session writer failure ends a prompt parked on input', () async {
      final sink = _SwitchableSink();
      final input = StreamController<String>();
      final adapter = _CountingAdapter(sink, input: input.stream);
      final resolved = Completer<void>();
      final theme = PlainTheme(
        io: TerminalEnvironment.custom(adapter: adapter),
        onResolved: (_) {
          if (!resolved.isCompleted) resolved.complete();
        },
      );

      final spinner = await theme.spinner('Scan').start();
      await resolved.future;
      final pending = theme.textInput('Name').prompt();
      // Wait for the prompt to paint before failing the shared writer.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!sink.transcript.toString().contains('Name')) {
        if (DateTime.now().isAfter(deadline)) {
          fail('prompt did not paint: ${sink.transcript}');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final failure = StateError('armed writer failure');
      sink.failure = failure;
      Object? thrown;
      try {
        spinner.update('fail');
      } catch (error) {
        thrown = error;
      }
      expect(thrown, same(failure));
      // The retired reader fails the parked prompt with the original
      // writer error rather than letting it wait for input that can never
      // arrive.
      await expectLater(pending, throwsA(same(failure)));

      sink.failure = null;
      await theme
          .text('Recovered')
          .present()
          .timeout(const Duration(seconds: 5));
      expect(adapter.restored, adapter.acquired);
      await spinner.stop();
    });

    test(
      'a reentrant stop during a finish write failure shares the cleanup',
      () async {
        final sink = _SwitchableSink();
        final adapter = _CountingAdapter(sink);
        final theme = PlainTheme(
          io: TerminalEnvironment.custom(adapter: adapter),
        );
        final spinner = await theme.spinner('Scan').start();

        final failure = StateError('armed writer failure');
        final reentrant = Completer<void>();
        sink.failure = failure;
        sink.onFailure = () {
          unawaited(
            spinner.stop().then(
              (_) => reentrant.complete(),
              onError: (Object error, StackTrace stackTrace) =>
                  reentrant.completeError(error, stackTrace),
            ),
          );
        };

        // The outer finish fails on its final output write; the sink callback
        // stops the same control reentrantly while finish is still running.
        // Both calls must observe the same original failure.
        await expectLater(
          spinner.finish(FeedbackOutcome.completed),
          throwsA(same(failure)),
        );
        await expectLater(reentrant.future, throwsA(same(failure)));

        sink.failure = null;
        await theme
            .text('Recovered')
            .present()
            .timeout(const Duration(seconds: 5));
        expect(adapter.restored, adapter.acquired);
      },
    );

    test('the resolution callback runs once per active period', () async {
      final resolutions = <ResolvedInteraction>[];
      final io = TerminalEnvironment.scripted(
        input: const Stream<String>.empty(),
        output: StringBuffer(),
        ownershipIdentity: const Object(),
      );
      final theme = PlainTheme(io: io, onResolved: resolutions.add);
      final feedback = await theme.spinner('Working').start();
      expect(resolutions, hasLength(1));
      expect(await theme.textInput('Name').prompt(), isA<InputEnded<String>>());
      expect(resolutions, hasLength(1));
      await feedback.finish(FeedbackOutcome.completed);
      expect(
        await theme.textInput('Again').prompt(),
        isA<InputEnded<String>>(),
      );
      expect(resolutions, hasLength(2));
    });
  });
}
