import 'dart:async';
import 'dart:convert';

import 'background_query.dart';
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

final class _BackgroundWait {
  _BackgroundWait(this.completer, this.timer);

  final Completer<BackgroundQueryResult> completer;
  final Timer timer;
}

final class SharedTerminalReader {
  final _controller = StreamController<String>();
  late final StreamSubscription<String> _subscription;
  late final StreamIterator<String> _iterator;
  bool Function(String)? onKey;
  Object? _failure;
  _BackgroundWait? _backgroundWait;
  void _emit(String key) {
    if (!(onKey?.call(key) ?? false)) _controller.add(key);
  }

  String _buffer = '';
  bool _discardPaste = false;
  Timer? _timer;
  SharedTerminalReader(
    Stream<List<int>> source, {
    bool flushEscapeOnEnd = false,
  }) {
    _iterator = StreamIterator(_controller.stream);
    _subscription = source
        .transform(utf8.decoder)
        .listen(
          (data) {
            _buffer += data;
            _parse();
          },
          onError: _controller.addError,
          onDone: () {
            _timer?.cancel();
            _finishBackground(null);
            if (flushEscapeOnEnd && _buffer == '\x1b') {
              _emit('\x1b');
              _buffer = '';
            }
            _controller.close();
          },
        );
  }

  /// Sends one background query through this reader and waits for its reply.
  ///
  /// A second caller joins the pending query instead of writing another
  /// request. The reply is consumed here; unrelated bytes keep their order.
  Future<BackgroundQueryResult> queryBackground({
    required void Function() writeRequest,
    Duration timeout = backgroundQueryTimeout,
  }) {
    final waiting = _backgroundWait;
    if (waiting != null) return waiting.completer.future;
    if (_closed || _controller.isClosed) {
      return Future.value(BackgroundQueryResult.unavailable);
    }
    final completer = Completer<BackgroundQueryResult>();
    final timer = Timer(timeout, () => _finishBackground(null));
    _backgroundWait = _BackgroundWait(completer, timer);
    try {
      writeRequest();
    } catch (error, stackTrace) {
      _backgroundWait = null;
      timer.cancel();
      Error.throwWithStackTrace(error, stackTrace);
    }
    return completer.future;
  }

  void _finishBackground(BackgroundQueryResult? result) {
    final waiting = _backgroundWait;
    if (waiting == null) return;
    _backgroundWait = null;
    waiting.timer.cancel();
    if (result == null) {
      // A partial reply is input, never a lost keystroke, when the bound ends.
      final held = _buffer;
      _buffer = '';
      _emitRaw(held);
    }
    if (!waiting.completer.isCompleted) {
      waiting.completer.complete(result ?? BackgroundQueryResult.unavailable);
    }
  }

  void _emitRaw(String raw) {
    for (final rune in raw.runes) {
      _emit(String.fromCharCode(rune));
    }
  }

  void _parse() {
    _timer?.cancel();
    while (_buffer.isNotEmpty) {
      if (_backgroundWait != null && _buffer.startsWith('\x1b]')) {
        final end = oscTerminatorEnd(_buffer);
        if (end != null) {
          final raw = _buffer.substring(0, end);
          _buffer = _buffer.substring(end);
          final result = parseOsc11BackgroundResponse(raw);
          if (result == null) {
            _emitRaw(raw);
          } else {
            _finishBackground(result);
          }
          continue;
        }
        if (isOsc11BackgroundPrefix(_buffer)) return;
      }
      if (_discardPaste) {
        final end = _buffer.indexOf('\x1b[201~');
        if (end < 0) {
          if (_buffer.length > 5) {
            _buffer = _buffer.substring(_buffer.length - 5);
          }
          return;
        }
        _buffer = _buffer.substring(end + 6);
        _discardPaste = false;
        _emit('\x1b[999~');
        continue;
      }
      if (_buffer.startsWith('\x1b[200~')) {
        final end = _buffer.indexOf('\x1b[201~', 6);
        if (end >= 0) {
          _emit(end - 6 > 4096 ? '\x1b[999~' : _buffer.substring(0, end + 6));
          _buffer = _buffer.substring(end + 6);
          continue;
        }
        if (_buffer.length > 4107) {
          _discardPaste = true;
          _buffer = _buffer.substring(_buffer.length - 5);
        }
        return;
      }
      if (_buffer.startsWith('\x1b')) {
        final match = RegExp(r'^\x1b(?:\[[0-9;]*[A-Za-z~]|O[A-Za-z])')
            .firstMatch(_buffer);
        if (match != null) {
          final s = match.group(0)!;
          _emit(
            s.startsWith('\x1bO') && 'ABCDHF'.contains(s[2])
                ? '\x1b[${s[2]}'
                : s,
          );
          _buffer = _buffer.substring(s.length);
          continue;
        }
        if (_buffer == '\x1b') {
          // A lone escape byte is the one genuinely ambiguous keypress: it
          // may be the Escape key or the first byte of a sequence. Flush it
          // after the disambiguation window if no further bytes arrive.
          _timer = Timer(const Duration(milliseconds: 80), () {
            _emit('\x1b');
            _buffer = _buffer.substring(1);
            _parse();
          });
          return;
        }
        if (_buffer == '\x1bO' || _buffer.startsWith('\x1b[')) {
          // An incomplete CSI/SS3 sequence is sequence bytes in transit,
          // never a keypress: pty, ssh and pseudoconsole transports may split
          // one sequence (for example a bracketed-paste opener) across reads
          // with arbitrarily long gaps. Wait for the remaining bytes instead
          // of corrupting the sequence into a bare escape plus typed text.
          // The traded-away ambiguity — a user pressing Escape and then
          // typing '[' or 'O' within the window — is byte-for-byte
          // indistinguishable from a sequence and cannot be recovered anyway.
          return;
        }
      }
      final rune = _buffer.runes.first;
      final s = String.fromCharCode(rune);
      final rest = _buffer.substring(s.length);
      _emit(s);
      // CRLF is one line-ending gesture only when both bytes are present in
      // this decoded input event. No carriage-return state crosses an event,
      // a read call or elapsed time: a later LF remains the finish gesture.
      _buffer = s == '\r' && rest.startsWith('\n') ? rest.substring(1) : rest;
    }
  }

  Future<String?> next() async {
    if (await _iterator.moveNext()) return _iterator.current;
    return null;
  }

  /// Ends the pending prompt iteration with [error].
  ///
  /// Resize notifications and other detached work cannot return a value to the
  /// awaiting prompt, so a failure they observe is delivered through the key
  /// stream. The prompt then ends with the original failure instead of waiting
  /// for input that can no longer be answered safely. Only the first failure is
  /// delivered: a detached repaint and its session can observe the same writer
  /// failure, and the reader must not receive it twice.
  void fail(Object error, StackTrace stackTrace) {
    if (_failure != null || _closed || _controller.isClosed) return;
    _failure = error;
    _controller.addError(error, stackTrace);
  }

  bool _closed = false;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    final waiting = _backgroundWait;
    _backgroundWait = null;
    waiting?.timer.cancel();
    if (waiting != null && !waiting.completer.isCompleted) {
      waiting.completer.complete(BackgroundQueryResult.unavailable);
    }
    await _subscription.cancel();
    await _iterator.cancel();
  }
}

/// Owns one shared reader for a selected input stream.
///
/// Participants in one active period ask for the reader by stream identity;
/// they never open their own stdin subscription. Changing the selected stream
/// closes the previous reader, and retirement or closure ends a pending read
/// with the original failure instead of leaving a prompt waiting for input.
final class SharedReaderCoordinator {
  SharedReaderCoordinator();

  SharedTerminalReader? _reader;
  Stream<String>? _input;
  Object? _failure;
  StackTrace? _failureStackTrace;
  bool _closed = false;

  /// Whether a participant currently owns a reader.
  bool get hasActiveReader => _reader != null;

  /// Returns the session-owned reader for [input], replacing a stale reader
  /// when the selected input stream changes.
  Future<SharedTerminalReader> readerFor(Stream<String> input) async {
    if (_closed) throw StateError('Terminal reader owner is closed.');
    final current = _reader;
    if (current != null && identical(_input, input)) return current;
    _reader = null;
    _input = null;
    await current?.close();
    final reader = SharedTerminalReader(input.transform(utf8.encoder));
    _reader = reader;
    _input = input;
    final failure = _failure;
    final stackTrace = _failureStackTrace;
    if (failure != null && stackTrace != null) {
      reader.fail(failure, stackTrace);
    }
    return reader;
  }

  /// Ends the current read with [error] and remembers it for a reader that
  /// arrives while cleanup is still in progress.
  void retire(Object error, StackTrace stackTrace) {
    _failure ??= error;
    _failureStackTrace ??= stackTrace;
    _reader?.fail(error, stackTrace);
  }

  /// Gives up participation in the active reader without closing it.
  void release(SharedTerminalReader reader) {
    if (identical(_reader, reader)) {
      _reader = null;
      _input = null;
    }
  }

  /// Closes the owned reader and prevents further acquisition.
  Future<void> close() async {
    _closed = true;
    final reader = _reader;
    _reader = null;
    _input = null;
    await reader?.close();
  }
}

/// Serializes writes to one selected output for all active participants.
///
/// A failed write retires the coordinator, records the original error and
/// invokes [onFailure] once so an owner can stop readers and feedback regions.
/// Later writes replay the recorded error rather than touching a dead sink.
final class SharedOutputCoordinator {
  SharedOutputCoordinator(this.output, {this.onFailure});

  final StringSink output;
  final void Function(Object error, StackTrace stackTrace)? onFailure;

  Object? _failure;
  StackTrace? _failureStackTrace;
  bool _closed = false;

  /// The first writer failure, retained for programmatic handling.
  Object? get failure => _failure;

  /// Performs one write while the coordinator is open.
  void write(void Function(StringSink output) action) {
    final failure = _failure;
    if (failure != null) {
      Error.throwWithStackTrace(failure, _failureStackTrace!);
    }
    if (_closed) return;
    try {
      action(output);
    } catch (error, stackTrace) {
      _failure = error;
      _failureStackTrace = stackTrace;
      onFailure?.call(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Stops writes without inventing a failure.
  void close() {
    _closed = true;
  }
}
