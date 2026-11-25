import 'dart:async';

import 'package:test/test.dart';

/// Bounded-polls [condition] until it holds or [timeout] elapses.
///
/// This is the deterministic replacement for a fixed sleep that merely hopes
/// asynchronous work finished: the test passes as soon as the observable
/// condition holds and fails with a diagnostic naming the missing condition
/// when the deadline expires. The condition must be observable behavior —
/// output text, a completion or a state seam — never private implementation.
Future<void> awaitCondition(
  bool Function() condition, {
  required String description,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) {
      fail('Timed out waiting for $description.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// Bounded-polls until [output] contains [marker].
///
/// Output text written through the prompt's own sink is observable behavior,
/// so awaiting a marker is awaiting behavior rather than implementation.
Future<void> awaitOutputContains(
  StringBuffer output,
  String marker, {
  Duration timeout = const Duration(seconds: 10),
}) => awaitCondition(
  () => output.toString().contains(marker),
  description: 'output to contain "$marker" (saw: $output)',
  timeout: timeout,
);

/// Awaits the shared editor's lone-Escape disambiguation timer.
///
/// This is not a sleep that hopes asynchronous work finished: a lone escape
/// byte is genuinely ambiguous with escape-sequence input for one real-time
/// decoder window, so input that must not merge into the same chunk has to
/// wait out that window. Prefer bounded-waiting for the observable effect of
/// the escape (dismissal, repaint) whenever such an effect exists.
Future<void> awaitLoneEscape() =>
    Future<void>.delayed(const Duration(milliseconds: 120));
