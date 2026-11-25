import 'package:trelis/src/testing/compat_api.dart';

/// A test-controlled [FeedbackClock] for cadence and batching tests.
///
/// Time advances only through [elapse], which runs every scheduled callback
/// whose deadline fell due, in deadline order, including callbacks those
/// callbacks themselves scheduled. No real milliseconds participate in the
/// behavior assertion.
final class FakeFeedbackClock implements FeedbackClock {
  Duration _elapsed = Duration.zero;

  /// Every timer ever scheduled, for cancellation assertions.
  final List<FakeFeedbackTimer> timers = [];

  @override
  Duration get elapsed => _elapsed;

  @override
  FeedbackTimer schedule(Duration delay, void Function() callback) {
    final scheduled = FakeFeedbackTimer(_elapsed + delay, callback);
    timers.add(scheduled);
    return scheduled;
  }

  /// Advances the clock, running due callbacks until none remain due.
  void elapse(Duration duration) {
    _elapsed += duration;
    while (true) {
      final due = timers.where((callback) {
        return !callback.cancelled && callback.when <= _elapsed;
      }).toList();
      if (due.isEmpty) return;
      for (final callback in due) {
        timers.remove(callback);
        if (!callback.cancelled) callback.callback();
      }
    }
  }
}

final class FakeFeedbackTimer implements FeedbackTimer {
  FakeFeedbackTimer(this.when, this.callback);

  final Duration when;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}
