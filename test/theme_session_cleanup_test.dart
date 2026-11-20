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

TerminalEnvironment _environment(TerminalIo terminal) =>
    TerminalEnvironment.custom(
      adapter: terminal,
      profile: const OutputProfile(glyphs: GlyphSet.ascii),
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
