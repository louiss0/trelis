import 'dart:async';
import 'dart:io';

import 'terminal_io.dart';

/// Polling cadence requested from a native console that cannot notify.
///
/// It is a request, not a guarantee: the prompt bounds the value before it
/// schedules anything, so a console without a resize event still reflows
/// within a fraction of a second instead of waiting for a keystroke.
const nativeConsoleResizeCadence = Duration(milliseconds: 250);

/// Live geometry of the native console that a prompt is painting to.
///
/// A prompt paints through its selected output, so that stream is the only
/// truthful geometry source for a native invocation: it reports the console
/// actually attached to this process instead of a guessed size. A read that is
/// unknown, zero or failing is not geometry, and it never invents one.
///
/// Notifications are platform-limited. A POSIX console raises `SIGWINCH` on a
/// window change and the observer forwards that hint; the Windows console has
/// no resize event a prompt can watch without consuming the very input records
/// it also reads, so Windows relies on the bounded [fallbackInterval] poll. Both
/// paths read the dimensions again, because a notification is a hint rather
/// than a measurement.
final class NativeConsoleResizeObserver implements TerminalResizeObserver {
  NativeConsoleResizeObserver(
    this._read, {
    Stream<void>? notifications,
    this.fallbackInterval = nativeConsoleResizeCadence,
  }) : notifications = notifications ?? const Stream<void>.empty();

  /// Reads the dimensions of the console selected by the prompt.
  final ({int columns, int rows})? Function() _read;

  @override
  final Stream<void> notifications;

  @override
  final Duration fallbackInterval;

  @override
  ({int columns, int rows})? readDimensions() {
    final ({int columns, int rows})? dimensions;
    try {
      dimensions = _read();
    } catch (_) {
      // A console that cannot report its size is unknown, not zero-sized.
      return null;
    }
    if (dimensions == null || dimensions.columns <= 0 || dimensions.rows <= 0) {
      return null;
    }
    return dimensions;
  }
}

/// Observes the console that [output] selects for one native prompt.
NativeConsoleResizeObserver nativeConsoleResizeObserver(Stdout output) =>
    NativeConsoleResizeObserver(
      () => consoleDimensions(output),
      notifications: _consoleResizeNotifications(),
    );

/// The usable dimensions of the console [output] is attached to.
///
/// The selected output owns the answer: a caller that paints to `stderr` must
/// not be laid out against a redirected `stdout`. A stream that is not attached
/// to a terminal reports nothing at all rather than a fabricated viewport.
({int columns, int rows})? consoleDimensions(Stdout output) {
  if (!output.hasTerminal) return null;
  try {
    return (columns: output.terminalColumns, rows: output.terminalLines);
  } on StdoutException {
    return null;
  } on FileSystemException {
    return null;
  } on UnsupportedError {
    return null;
  }
}

/// Window-change notifications the current platform's console can raise.
Stream<void> _consoleResizeNotifications() => Platform.isWindows
    ? const Stream<void>.empty()
    : ProcessSignal.sigwinch.watch().map<void>((_) {});
