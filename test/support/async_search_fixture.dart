export 'bounded_wait.dart' show awaitLoneEscape;

import 'dart:async';

// Deterministic drivers for the asynchronous suggestion/search fixtures.
//
// Nothing here waits for the clock: a response is released by the test, and
// progress is observed through typed presentation state or the recorded
// transcript instead of an elapsed duration. The one exception is a lone
// Escape, which the shared editor's own key parser can only distinguish from
// the start of a longer sequence after its 80 ms disambiguation timer.

/// Pumps [turns] microtasks so completed futures and buffered key events are
/// delivered without depending on wall-clock time.
Future<void> settle({int turns = 8}) async {
  for (var turn = 0; turn < turns; turn++) {
    await Future<void>.microtask(() {});
  }
}

/// Pumps microtasks until [condition] holds.
///
/// The fixture fails loudly rather than hanging when the behavior never reaches
/// the expected state.
Future<void> settleUntil(
  bool Function() condition, {
  String? description,
  int maxTurns = 500,
}) async {
  for (var turn = 0; turn <= maxTurns; turn++) {
    if (condition()) return;
    await Future<void>.microtask(() {});
  }
  throw StateError(
    'Fixture did not settle within $maxTurns microtask turns'
    '${description == null ? '' : ': $description'}.',
  );
}

/// Requests recorded by query, so a test can complete or fail them in any
/// order.
final class PendingRequests<T> {
  final Map<String, Completer<T>> _pending = {};
  final List<String> _issued = [];

  Future<T> record(String query) {
    _issued.add(query);
    return _pending.putIfAbsent(query, Completer<T>.new).future;
  }

  List<String> get issued => List.unmodifiable(_issued);
  bool requested(String query) => _pending.containsKey(query);

  void complete(String query, T value) {
    _completer(query).complete(value);
  }

  void fail(String query, Object error) {
    _completer(query).completeError(error);
  }

  Completer<T> _completer(String query) {
    final pending = _pending[query];
    if (pending == null) {
      throw StateError('No request for "$query"; issued: $_issued.');
    }
    if (pending.isCompleted) {
      throw StateError('Request "$query" was already completed.');
    }
    return pending;
  }
}

/// A sink a test can make fail at a chosen moment, so a selected-output fault
/// is injected deterministically instead of by write count.
final class SwitchableSink implements StringSink {
  final StringBuffer _accepted = StringBuffer();
  Object? failure;

  /// Everything the sink accepted before the injected failure.
  @override
  String toString() => _accepted.toString();

  void _guard() {
    final injected = failure;
    if (injected != null) throw injected;
  }

  @override
  void write(Object? object) {
    _guard();
    _accepted.write(object);
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    _guard();
    _accepted.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    _guard();
    _accepted.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    _guard();
    _accepted.writeln(object);
  }
}
