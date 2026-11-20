import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/trelis.dart';

void main() {
  test(
    'a start racing cleanup waits for release, reacquires and re-detects',
    () async {
      final events = <String>[];
      final releaseCleanup = Completer<void>();
      final input = _SequentialInput(['Ada', 'Grace'], events, releaseCleanup);
      final terminal = _RecordingTerminal(input, StringBuffer(), events);
      var facts = 0;
      var callbacks = 0;
      final owner = ThemeSession(
        environment: _environment(terminal),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        factsForPeriod: (_) async {
          facts++;
          events.add('facts:$facts');
          return const InteractionFacts();
        },
        onResolved: (_) async {
          callbacks++;
          events.add('callback:$callbacks');
        },
      );

      final first = owner.prompt(
        (handle) => TextInput('First').prompt(session: handle.session),
      );
      await _waitUntil(() => events.contains('cleanup-start'));

      final second = owner.prompt((handle) async {
        events.add('second-started');
        return TextInput('Second').prompt(session: handle.session);
      });
      await _pump();
      expect(
        facts,
        1,
        reason: 'cleanup must finish before a new period starts',
      );
      expect(events, isNot(contains('second-started')));

      releaseCleanup.complete();
      expect((await first as Accepted<String>).value, 'Ada');
      expect((await second as Accepted<String>).value, 'Grace');
      expect(facts, 2);
      expect(callbacks, 2);
      expect(
        events.indexOf('acquire:3'),
        greaterThan(events.indexOf('cleanup-end')),
        reason: 'a reacquisition must not reuse a partially released owner',
      );
      expect(
        events.indexOf('second-started'),
        greaterThan(events.indexOf('cleanup-end')),
      );
    },
  );

  test(
    'only one external prompt runs while internal delegation stays local',
    () async {
      final events = <String>[];
      var callbacks = 0;
      final started = Completer<void>();
      final release = Completer<void>();
      final owner = ThemeSession(
        environment: _environment(
          _RecordingTerminal(
            const Stream<String>.empty(),
            StringBuffer(),
            events,
          ),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async {
          callbacks++;
          events.add('callback:$callbacks');
        },
      );

      final first = owner.prompt((handle) async {
        events.add('first');
        final nested = await handle.delegate((_) async {
          events.add('nested');
          return 'delegated';
        });
        expect(nested, 'delegated');
        started.complete();
        await release.future;
        return Accepted('one');
      });
      await started.future;

      final rejected = await owner.prompt((_) async {
        events.add('second');
        return Accepted('two');
      });
      expect(rejected, isA<Unavailable<String>>());
      expect(
        (rejected as Unavailable<String>).reason,
        contains('already active'),
      );
      expect(events, [
        'acquire:1',
        'callback:1',
        'first',
        'nested',
      ], reason: 'the rejected prompt must not acquire or start a new period');
      expect(callbacks, 1);

      release.complete();
      expect((await first as Accepted<String>).value, 'one');
      final later = await owner.prompt((_) async {
        events.add('later');
        return Accepted('three');
      });
      expect((later as Accepted<String>).value, 'three');
      expect(callbacks, 2);
    },
  );

  test(
    'identifiable themes reject overlap and permit sequential reuse',
    () async {
      final identity = Object();
      final events = <String>[];
      final release = Completer<void>();
      ThemeSession owner(Object? identity) => ThemeSession(
        environment: _environment(
          _RecordingTerminal(
            const Stream<String>.empty(),
            StringBuffer(),
            events,
          ),
          ownershipIdentity: identity,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );
      final first = owner(identity);
      final overlapping = owner(identity);
      // Distinct wrappers without an identity cannot be proven to share a
      // physical terminal, so they are not rejected by this seam.
      final unidentifiable = owner(null);

      final active = first.prompt((_) async {
        await release.future;
        return Accepted('first');
      });
      await _waitUntil(() => events.contains('acquire:1'));

      final rejected = await overlapping.prompt((_) async {
        events.add('overlap');
        return Accepted('overlap');
      });
      expect(rejected, isA<Unavailable<String>>());
      expect(
        (rejected as Unavailable<String>).reason,
        contains('active theme owner'),
      );
      expect(unidentifiable.resolvedInteraction, isNull);
      expect(events, isNot(contains('overlap')));

      release.complete();
      expect((await active as Accepted<String>).value, 'first');
      final later = await overlapping.prompt((_) async {
        events.add('later');
        return Accepted('later');
      });
      expect((later as Accepted<String>).value, 'later');
    },
  );

  test(
    'a primary failure and a restoration failure are both observable',
    () async {
      const canary = 'CANARY-primary-and-cleanup';
      final primary = StateError('primary failed: $canary');
      final cleanup = StateError('restore failed: $canary');
      final owner = ThemeSession(
        environment: _environment(
          _FailingTerminal(
            const Stream<String>.empty(),
            StringBuffer(),
            restoreError: cleanup,
          ),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      final failure = await owner
          .prompt<String>((_) async => throw primary)
          .then<Object?>(
            (value) => value,
            onError: (Object error, StackTrace _) => error,
          );

      expect(
        failure,
        isA<TerminalSessionCleanupException>()
            .having((error) => error.operationError, 'primary', same(primary))
            .having((error) => error.cleanupError, 'cleanup', same(cleanup)),
      );
      expect(
        failure.toString(),
        isNot(contains(canary)),
        reason: 'failure text must not expose application data',
      );
    },
  );

  test(
    'a committed answer survives cleanup failure and reports it once',
    () async {
      final cleanup = StateError('restore failed');
      final observed = <Object>[];
      final owner = ThemeSession(
        environment: _environment(
          _FailingTerminal(
            const Stream<String>.empty(),
            StringBuffer(),
            restoreError: cleanup,
          ),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onCleanupError: (error, _) => observed.add(error),
      );

      final result = await owner.prompt((_) async => Accepted('answer'));

      expect((result as Accepted<String>).value, 'answer');
      expect(owner.lastCleanupError, same(cleanup));
      expect(owner.cleanupFailures, [same(cleanup)]);
      expect(observed, [same(cleanup)]);
    },
  );

  test(
    'a callback failure keeps both causes when restoration also fails',
    () async {
      final primary = StateError('callback refused');
      final cleanup = StateError('restore failed');
      var callbacks = 0;
      final owner = ThemeSession(
        environment: _environment(
          _FailingTerminal(
            const Stream<String>.empty(),
            StringBuffer(),
            restoreError: cleanup,
          ),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async {
          callbacks++;
          throw primary;
        },
      );

      final failure = await owner
          .prompt((_) async => Accepted('unreachable'))
          .then<Object?>(
            (value) => value,
            onError: (Object error, StackTrace _) => error,
          );

      expect(callbacks, 1);
      expect(
        failure,
        isA<TerminalSessionCleanupException>()
            .having((error) => error.operationError, 'primary', same(primary))
            .having((error) => error.cleanupError, 'cleanup', same(cleanup)),
      );
    },
  );
}

Future<void> _pump([int rounds = 4]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition was not met before the test deadline');
}

TerminalEnvironment _environment(
  TerminalIo terminal, {
  Object? ownershipIdentity,
}) => TerminalEnvironment.custom(
  adapter: terminal,
  profile: const OutputProfile(glyphs: GlyphSet.ascii),
  ownershipIdentity: ownershipIdentity,
);

/// A stream that answers one prompt per subscription and can delay listener
/// cancellation to hold a period in cleanup.
final class _SequentialInput extends Stream<String> {
  _SequentialInput(this._answers, this.events, this._firstCancelGate);

  final List<String> _answers;
  final List<String> events;
  final Completer<void> _firstCancelGate;
  var _listens = 0;

  @override
  StreamSubscription<String> listen(
    void Function(String event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final index = _listens++;
    final controller = StreamController<String>();
    final subscription = controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    controller.add('${_answers[index]}\r');
    return _GatedSubscription(
      subscription,
      events,
      label: index == 0 ? 'cleanup-start' : 'cleanup',
      gate: index == 0 ? _firstCancelGate.future : null,
    );
  }
}

final class _GatedSubscription implements StreamSubscription<String> {
  _GatedSubscription(this._inner, this.events, {this.gate, this.label});

  final StreamSubscription<String> _inner;
  final List<String> events;
  final Future<void>? gate;
  final String? label;
  var _cancelled = false;

  @override
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    if (label != null) events.add(label!);
    if (gate != null) {
      await gate!;
      events.add('cleanup-end');
    }
    await _inner.cancel();
  }

  @override
  void onData(void Function(String event)? handleData) =>
      _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  bool get isPaused => _inner.isPaused;

  @override
  void pause([Future<void>? resume]) => _inner.pause(resume);

  @override
  void resume() => _inner.resume();

  @override
  Future<T> asFuture<T>([T? value]) => _inner.asFuture<T>(value);
}

final class _RecordingTerminal implements TerminalIo {
  _RecordingTerminal(this.input, this.output, this.events);

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final List<String> events;
  var _acquired = 0;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const <String, String?>{};

  @override
  TerminalLease acquire() {
    _acquired++;
    final number = _acquired;
    events.add('acquire:$number');
    return TerminalLease(() => events.add('restore:$number'));
  }
}

final class _FailingTerminal implements TerminalIo {
  _FailingTerminal(this.input, this.output, {this.restoreError});

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final Object? restoreError;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const <String, String?>{};

  @override
  TerminalLease acquire() => TerminalLease(() {
    if (restoreError != null) throw restoreError!;
  });
}
