import 'dart:async';

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
