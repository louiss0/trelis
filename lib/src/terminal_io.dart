import 'dart:async';

import 'output_profile.dart';

/// A replaceable terminal boundary for prompt input and selected output.
///
/// A caller supplies the input stream, selected output sink, observed rich
/// capability, and declared environment. The prompt acquires the adapter only
/// for an invocation that needs interactive input, then restores the returned
/// lease exactly once. This is an additive alternative to the legacy native
/// terminal path; it does not make a synthetic adapter a native terminal.
abstract interface class TerminalIo {
  /// The input selected by this adapter.
  ///
  /// The prompt listens lazily, after [acquire] succeeds.
  Stream<String> get input;

  /// The output selected by this adapter.
  StringSink get output;

  /// Whether this adapter currently supports the existing rich interaction.
  ///
  /// Finer output capabilities and geometry are intentionally not inferred at
  /// this seam; they are resolved by the output-profile layer.
  bool get supportsRich;

  /// Environment observations declared by this adapter.
  ///
  /// The map is exposed so adapters can be deterministic without consulting
  /// the host process. Current prompt behavior does not yet resolve profiles
  /// from these values.
  Map<String, String?> get environment;

  /// Acquires interactive terminal state for one prompt invocation.
  ///
  /// Implementations may throw when acquisition fails. The caller restores
  /// the returned lease after every supported invocation exit.
  TerminalLease acquire();
}

/// Optional declared output facts for a [TerminalIo] implementation.
///
/// Implement this alongside [TerminalIo] when an adapter owns a synthetic or
/// otherwise explicitly declared output profile. It remains separate so
/// existing terminal adapters keep their source-compatible contract.
abstract interface class TerminalIoOutputProfile {
  OutputProfile get outputProfile;
}

/// Optional live geometry observation for a selected terminal output.
///
/// Notifications are only hints: callers must read dimensions again and ignore
/// unknown, zero, or otherwise incomplete results. [fallbackInterval] is a
/// bounded polling backstop for terminals that lose a notification; it is not
/// a promise that every terminal can report resize events.
abstract interface class TerminalResizeObserver {
  /// Resize notifications from the selected output, if the platform supports
  /// them. A stream error is treated as a lost notification, not geometry.
  Stream<void> get notifications;

  /// The latest raw dimensions. Null, zero, and negative values are unusable.
  ({int columns, int rows})? readDimensions();

  /// Requested polling cadence. Prompt code bounds it before scheduling.
  Duration get fallbackInterval;
}

/// Optional live geometry observation owned by a [TerminalIo] adapter.
abstract interface class TerminalIoResizeObserver {
  TerminalResizeObserver get resizeObserver;
}

/// Reports both a prompt failure and a failure while restoring its terminal.
///
/// The original operation error remains available to callers instead of being
/// replaced by a cleanup error. Its diagnostic deliberately does not stringify
/// either error because application failures can contain sensitive input.
final class TerminalRestorationException implements Exception {
  TerminalRestorationException(this.operationError, this.restorationError);

  final Object operationError;
  final Object restorationError;

  @override
  String toString() =>
      'TerminalRestorationException: prompt operation and terminal restoration failed.';
}

/// Reports both a scoped-session operation failure and a cleanup failure.
///
/// A session may have already acquired a reader, registered live regions, or
/// entered a temporary screen when its callback fails. Callers retain both
/// errors for programmatic handling; the diagnostic intentionally omits their
/// text so a failure does not expose application data or secret drafts.
final class TerminalSessionCleanupException implements Exception {
  TerminalSessionCleanupException(this.operationError, this.cleanupError);

  final Object operationError;
  final Object cleanupError;

  @override
  String toString() =>
      'TerminalSessionCleanupException: session operation and cleanup failed.';
}

/// A native or synthetic terminal acquisition that must be restored.
final class TerminalLease {
  TerminalLease(this._onRestore);

  final void Function()? _onRestore;
  bool _restored = false;

  /// Restores acquired state once, even when nested cleanup reaches this lease.
  void restore() {
    if (_restored) return;
    _restored = true;
    _onRestore?.call();
  }
}
