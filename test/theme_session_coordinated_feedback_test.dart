import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/src/testing/compat_api.dart';

void main() {
  test('one-shot feedback waits for asynchronous detection before its first output', () async {
    final events = <String>[];
    final output = StringBuffer();
    final facts = Completer<InteractionFacts>();
    final owner = ThemeSession(
      environment: _environment(output, events),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      factsForPeriod: (_) => facts.future,
      onResolved: (_) async => events.add('callback'),
    );

    final pending = owner.presentFeedback(Text('Ready'));
    await _pump();
    expect(output.toString(), isEmpty);
    expect(events, isEmpty);

    facts.complete(const InteractionFacts());
    await pending;

    expect(output.toString(), contains('Ready'));
    expect(events, ['acquire:1', 'callback', 'restore:1']);
    expect(owner.resolvedInteraction, isNull);
  });

  test(
    'multiple live feedback instances share one prompt period and cleanup',
    () async {
      final events = <String>[];
      final output = StringBuffer();
      final input = StreamController<String>();
      var facts = 0;
      var callbacks = 0;
      final owner = ThemeSession(
        environment: _environment(output, events, input: input.stream),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        factsForPeriod: (_) async {
          facts++;
          return const InteractionFacts();
        },
        onResolved: (_) async {
          callbacks++;
          events.add('callback:$callbacks');
        },
      );

      late final Spinner index;
      final first = await owner.startFeedback((handle) {
        index = Spinner('Index')..start(session: handle.session);
      }, stop: () => index.dispose());
      late final Progress upload;
      final second = await owner.startFeedback((handle) {
        upload = Progress('Upload', total: 2)..start(session: handle.session);
      }, stop: () => upload.dispose());

      final promptStarted = Completer<void>();
      final prompt = owner.prompt((handle) async {
        promptStarted.complete();
        return await TextInput('Name').prompt(session: handle.session);
      });
      await promptStarted.future;
      input.add('Ada\r');
      await input.close();

      await first.finish(() => index.finish(FeedbackOutcome.completed));
      expect(events, isNot(contains('restore:1')));
      expect(owner.resolvedInteraction, isNotNull);
      await second.finish(() => upload.finish(FeedbackOutcome.failed));
      expect(events, contains('restore:1'));
      expect(owner.resolvedInteraction, isNull);

      expect((await prompt as Accepted<String>).value, 'Ada');
      expect(events.where((event) => event.startsWith('acquire')), [
        'acquire:1',
        'acquire:2',
      ], reason: 'the period and the prompt each acquire a lease');
      expect(events.last, 'restore:1');
      expect(facts, 1);
      expect(callbacks, 1);
      expect(output.toString(), contains('Index: completed'));
      expect(output.toString(), contains('Upload: failed'));

      await owner.presentFeedback(Text('Later'));
      expect(facts, 2);
      expect(callbacks, 2);
      expect(events.last, 'restore:3');
    },
  );

  for (final ending in ['stopped', 'completed', 'failed']) {
    for (final promptActive in [true, false]) {
      test(
        'feedback $ending with the prompt $promptActive cancels its producer',
        () async {
          final events = <String>[];
          final output = StringBuffer();
          final input = StreamController<String>();
          final clock = _FakeFeedbackClock();
          final owner = ThemeSession(
            environment: _environment(output, events, input: input.stream),
            interaction: const InteractionPreferences(mode: PromptMode.linear),
          );

          late final Progress upload;
          final feedback = await owner.startFeedback((handle) {
            upload = Progress(
              'Upload',
              total: 100,
              interval: const Duration(seconds: 5),
              clock: clock,
            )..start(session: handle.session);
            upload.update(10);
            upload.update(20);
            upload.update(30);
          }, stop: () => upload.dispose());
          expect(clock.timers, hasLength(1));
          expect(clock.timers.single.cancelled, isFalse);

          final promptStarted = Completer<void>();
          final prompt = owner.prompt((handle) async {
            promptStarted.complete();
            return await TextInput('Name').prompt(session: handle.session);
          });
          await promptStarted.future;
          input.add('Ada\r');
          await input.close();
          if (!promptActive) await prompt;

          switch (ending) {
            case 'stopped':
              await feedback.finish();
            case 'completed':
              await feedback.finish(
                () => upload.finish(FeedbackOutcome.completed),
              );
            case 'failed':
              await feedback.finish(
                () => upload.finish(FeedbackOutcome.failed, detail: 'offline'),
              );
          }
          if (promptActive) await prompt;

          expect(clock.timers.single.cancelled, isTrue);
          final settled = output.toString();
          clock.elapse(const Duration(seconds: 10));
          upload.update(40);
          expect(output.toString(), settled);
          switch (ending) {
            case 'stopped':
              expect(settled, isNot(contains('completed')));
            case 'completed':
              expect(settled, contains('Upload: completed'));
            case 'failed':
              expect(settled, contains('Upload: failed: offline'));
          }
          expect(events.last, 'restore:1');
          expect(owner.resolvedInteraction, isNull);
        },
      );
    }
  }

  test('unavailable feedback produces a clear error and no output', () async {
    final events = <String>[];
    final output = StringBuffer();
    final owner = ThemeSession(
      environment: _environment(output, events),
      interaction: const InteractionPreferences(
        mode: PromptMode.rich,
        screenReader: ScreenReaderPreference.on,
      ),
      onResolved: (_) async => events.add('callback'),
    );

    await expectLater(
      owner.presentFeedback(Text('unreachable')),
      throwsA(
        isA<ThemeSessionUnavailable>().having(
          (error) => error.reason,
          'reason',
          contains('cannot be combined'),
        ),
      ),
    );
    await expectLater(
      owner.startFeedback(
        (_) async => throw StateError('unreachable'),
        stop: () {},
      ),
      throwsA(isA<ThemeSessionUnavailable>()),
    );

    expect(events, isEmpty);
    expect(output.toString(), isEmpty);
    expect(owner.resolvedInteraction, isNull);
  });

  test('cancellation during feedback initialization emits nothing', () async {
    final events = <String>[];
    final output = StringBuffer();
    final facts = Completer<InteractionFacts>();
    final cancel = Completer<void>();
    var callbacks = 0;
    final owner = ThemeSession(
      environment: _environment(output, events),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      factsForPeriod: (_) => facts.future,
      onResolved: (_) async => callbacks++,
    );

    final pending = owner.presentFeedback(
      Text('unreachable'),
      cancellation: cancel.future,
    );
    await _pump();
    cancel.complete();

    await expectLater(pending, throwsA(isA<ThemeSessionCancelled>()));
    expect(events, isEmpty);
    expect(output.toString(), isEmpty);
    expect(callbacks, 0);
    facts.complete(const InteractionFacts());
  });

  test(
    'a feedback failure keeps its primary error when restoration also fails',
    () async {
      final primary = StateError('feedback end failed');
      final cleanup = StateError('restore failed');
      final owner = ThemeSession(
        environment: _environment(
          StringBuffer(),
          <String>[],
          restoreError: cleanup,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      final feedback = await owner.startFeedback((_) {}, stop: () {});
      final failure = await feedback
          .finish(() => throw primary)
          .then<Object?>((value) => value, onError: (error, _) => error);

      expect(
        failure,
        isA<TerminalSessionCleanupException>()
            .having((error) => error.operationError, 'primary', same(primary))
            .having((error) => error.cleanupError, 'cleanup', same(cleanup)),
      );
      expect(owner.cleanupFailures, [same(cleanup)]);
    },
  );

  test('a failed writer reaches the caller after restoration', () async {
    final events = <String>[];
    final sink = _FailingSink(events);
    final owner = ThemeSession(
      environment: _environment(sink, events),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    await expectLater(
      owner.presentFeedback(Text('Boom')),
      throwsA(same(sink.failure)),
    );
    expect(events, ['acquire:1', 'restore:1']);
    expect(owner.resolvedInteraction, isNull);
  });

  test(
    'modal help preserves coordinated feedback and the prompt draft',
    () async {
      final events = <String>[];
      final output = StringBuffer();
      final input = StreamController<String>();
      final owner = ThemeSession(
        environment: _environment(
          output,
          events,
          input: input.stream,
          profile: _richProfile(rows: 8, alternateScreen: true),
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
      );

      late final Spinner index;
      final feedback = await owner.startFeedback((handle) {
        index = Spinner('Index')..start(session: handle.session);
      }, stop: () => index.dispose());
      final promptStarted = Completer<void>();
      final prompt = owner.prompt((handle) async {
        promptStarted.complete();
        return await TextInput('Project').prompt(session: handle.session);
      });
      await promptStarted.future;
      input.add('de\x1bOP');
      await _pump();
      index.update('reading cache');
      input.add('\x1bmo\r');
      await input.close();

      expect((await prompt as Accepted<String>).value, 'demo');
      await feedback.finish(() => index.finish(FeedbackOutcome.completed));

      final text = output.toString();
      expect(text, contains('\x1b[?1049h'));
      expect(text, contains('\x1b[?1049l'));
      expect(text, contains('[status] - Index: reading cache'));
      expect(
        text.indexOf('\x1b[?1049l'),
        lessThan(text.lastIndexOf('Index: completed')),
      );
    },
  );

  test(
    'a short screen compacts live feedback while keeping failures reviewable',
    () async {
      final events = <String>[];
      final output = StringBuffer();
      final input = StreamController<String>();
      final owner = ThemeSession(
        environment: _environment(
          output,
          events,
          input: input.stream,
          profile: _richProfile(rows: 1),
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
      );

      late final Spinner index;
      late final Progress upload;
      final first = await owner.startFeedback((handle) {
        index = Spinner('Index')..start(session: handle.session);
      }, stop: () => index.dispose());
      final second = await owner.startFeedback((handle) {
        upload = Progress('Upload', total: 10)..start(session: handle.session);
      }, stop: () => upload.dispose());
      final promptStarted = Completer<void>();
      final prompt = owner.prompt((handle) async {
        promptStarted.complete();
        return await TextInput('Project').prompt(session: handle.session);
      });
      await promptStarted.future;
      index.update('reading cache');
      upload.update(1);
      input.add('demo\r');
      await input.close();
      await prompt;
      await first.finish(
        () => index.finish(FeedbackOutcome.failed, detail: 'offline'),
      );
      await second.finish(() => upload.finish(FeedbackOutcome.completed));

      final text = output.toString();
      expect(text, contains('[status] Feedback (2): - Index, Upload'));
      expect(text, contains('[status] x Index: failed: offline'));
      expect(text, contains('[status] Upload: completed'));
    },
  );

  test(
    'prompt-first work publishes once before a joined feedback participant',
    () async {
      final events = <String>[];
      final output = StringBuffer();
      final input = StreamController<String>();
      final facts = Completer<InteractionFacts>();
      var detections = 0;
      var callbacks = 0;
      final owner = ThemeSession(
        environment: _environment(output, events, input: input.stream),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        factsForPeriod: (_) async {
          detections++;
          return facts.future;
        },
        onResolved: (_) async {
          callbacks++;
          events.add('callback:$callbacks');
        },
      );

      final promptStarted = Completer<void>();
      final releasePrompt = Completer<void>();
      final prompt = owner.prompt((handle) async {
        promptStarted.complete();
        await releasePrompt.future;
        return await TextInput('Name').prompt(session: handle.session);
      });
      await _pump();
      expect(output.toString(), isEmpty);
      expect(events, isEmpty);

      facts.complete(const InteractionFacts());
      await promptStarted.future;

      late final Spinner index;
      final feedback = await owner.startFeedback((handle) {
        index = Spinner('Index')..start(session: handle.session);
      }, stop: () => index.dispose());
      expect(detections, 1);
      expect(callbacks, 1);
      expect(events, contains('callback:1'));
      expect(owner.resolvedInteraction, isNotNull);

      input.add('Ada\r');
      releasePrompt.complete();
      expect((await prompt as Accepted<String>).value, 'Ada');
      await input.close();
      await feedback.finish(() => index.finish(FeedbackOutcome.completed));
      expect(events.last, 'restore:1');
      expect(owner.resolvedInteraction, isNull);
      expect(output.toString(), contains('Name'));
      expect(output.toString(), contains('Index: completed'));
    },
  );

  test('caller-owned input stays open after coordinated cleanup', () async {
    var cancellations = 0;
    final callerInput = StreamController<String>(
      onCancel: () => cancellations++,
    );
    callerInput.add('Ada\r');
    final events = <String>[];
    final owner = ThemeSession(
      environment: _environment(
        StringBuffer(),
        events,
        input: callerInput.stream,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    late final Spinner index;
    final feedback = await owner.startFeedback((handle) {
      index = Spinner('Index')..start(session: handle.session);
    }, stop: () => index.dispose());
    final answer = await owner.prompt(
      (handle) => TextInput('Name').prompt(session: handle.session),
    );
    await feedback.finish();

    expect((answer as Accepted<String>).value, 'Ada');
    expect(callerInput.isClosed, isFalse);
    expect(cancellations, greaterThan(0));
    await callerInput.close();
  });

  test('a failed detection source falls back for feedback output', () async {
    final events = <String>[];
    final output = StringBuffer();
    final owner = ThemeSession(
      environment: _environment(output, events),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      factsForPeriod: (_) => throw StateError('observation failed'),
      onResolved: (_) async => events.add('callback'),
    );

    await owner.presentFeedback(Text('Fallback'));

    expect(output.toString(), contains('Fallback'));
    expect(events, ['acquire:1', 'callback', 'restore:1']);
  });

  test('explicit rich feedback fails clearly on a non-rich output', () async {
    final events = <String>[];
    final output = StringBuffer();
    final owner = ThemeSession(
      environment: _environment(output, events),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      onResolved: (_) async => events.add('callback'),
    );

    await expectLater(
      owner.presentFeedback(Text('unreachable')),
      throwsA(
        isA<ThemeSessionUnavailable>().having(
          (error) => error.reason,
          'reason',
          contains('unavailable on the selected output'),
        ),
      ),
    );
    await expectLater(
      owner.startFeedback((_) {}, stop: () {}),
      throwsA(isA<ThemeSessionUnavailable>()),
    );

    expect(events, isEmpty);
    expect(output.toString(), isEmpty);
  });
}

OutputProfile _richProfile({required int rows, bool alternateScreen = false}) =>
    OutputProfile(
      cursor: CapabilitySupport.supported,
      alternateScreen: alternateScreen
          ? CapabilitySupport.supported
          : CapabilitySupport.unsupported,
      styles: CapabilitySupport.supported,
      colorDepth: ColorDepth.none,
      glyphs: GlyphSet.ascii,
      geometry: OutputGeometry.fixed(columns: 40, rows: rows),
    );

final class _FailingSink implements StringSink {
  _FailingSink(this.events);

  final List<String> events;
  final Object failure = StateError('writer failed');

  @override
  void write(Object? object) {
    if (object.toString().contains('Boom')) {
      Error.throwWithStackTrace(failure, StackTrace.empty);
    }
    events.add('write:$object');
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    for (final object in objects) {
      write(object);
      if (separator.isNotEmpty) write(separator);
    }
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) {
    write(object);
    write('\n');
  }
}

final class _FakeFeedbackClock implements FeedbackClock {
  final Duration _elapsed = Duration.zero;
  final List<_FakeFeedbackTimer> timers = [];

  @override
  Duration get elapsed => _elapsed;

  @override
  FeedbackTimer schedule(Duration delay, void Function() callback) {
    final timer = _FakeFeedbackTimer(callback);
    timers.add(timer);
    return timer;
  }

  void elapse(Duration duration) {
    for (final timer in timers) {
      if (!timer.cancelled) timer.callback();
    }
  }
}

final class _FakeFeedbackTimer implements FeedbackTimer {
  _FakeFeedbackTimer(this.callback);

  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

Future<void> _pump([int rounds = 4]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

TerminalEnvironment _environment(
  StringSink output,
  List<String> events, {
  Stream<String>? input,
  Object? ownershipIdentity,
  Object? restoreError,
  bool supportsRich = false,
  OutputProfile profile = const OutputProfile(glyphs: GlyphSet.ascii),
}) => TerminalEnvironment.custom(
  adapter: _RecordingTerminal(
    input ?? const Stream<String>.empty(),
    output,
    events,
    restoreError: restoreError,
  ),
  profile: profile,
  supportsRich: supportsRich,
  ownershipIdentity: ownershipIdentity,
);

final class _RecordingTerminal implements TerminalIo {
  _RecordingTerminal(this.input, this.output, this.events, {this.restoreError});

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final List<String> events;
  final Object? restoreError;
  var _acquired = 0;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const <String, String?>{};

  @override
  TerminalLease acquire() {
    final number = ++_acquired;
    events.add('acquire:$number');
    return TerminalLease(() {
      if (restoreError != null) throw restoreError!;
      events.add('restore:$number');
    });
  }
}
