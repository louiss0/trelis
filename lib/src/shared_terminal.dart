import 'dart:async';

import 'terminal_io.dart';

/// Internal terminal-ownership seam for theme-managed presentation.
///
/// This library is deliberately absent from the public export barrel. It
/// gathers the acquisition, reader and writer coordination that components
/// currently repeat so a future theme owner can own one terminal lifetime
/// without creating competing input subscriptions or unscoped writers.
final class SharedTerminalLease {
  const SharedTerminalLease._();

  /// Acquires one lease from [terminal] for exactly one [operation].
  ///
  /// Acquisition happens before the operation starts, so an acquisition
  /// failure starts nothing. A successful acquisition is restored on every
  /// exit, including a writer or prompt failure.
  static Future<T> run<T>(
    TerminalIo terminal,
    Future<T> Function() operation,
  ) async {
    final lease = terminal.acquire();
    return await restoreAfter(operation, lease.restore);
  }

  /// Runs [operation] and invokes [restore] once after it settles.
  ///
  /// Native transports build their own restoration callback for one prompt,
  /// so they use this entry point instead of an adapter lease. A primary
  /// failure stays observable when restoration also fails: both causes are
  /// retained by [TerminalRestorationException] without stringifying either.
  static Future<T> restoreAfter<T>(
    Future<T> Function() operation,
    void Function() restore,
  ) async {
    late final T result;
    try {
      result = await operation();
    } catch (operationError, operationStackTrace) {
      try {
        restore();
      } catch (restorationError) {
        throw TerminalRestorationException(operationError, restorationError);
      }
      Error.throwWithStackTrace(operationError, operationStackTrace);
    }
    restore();
    return result;
  }
}
