import 'dart:io';
import 'dart:async';

import 'text_input.dart' show PromptMode;

/// Semantic meaning that remains readable without color.
enum TextKind { ordinary, hint, success, warning, error }

String _safe(String value) => value.runes.map((c) {
  if (c < 32 ||
      (c >= 127 && c <= 159) ||
      c == 0x2028 ||
      c == 0x2029 ||
      (c >= 0x202a && c <= 0x202e) ||
      (c >= 0x2066 && c <= 0x2069)) {
    return r'\u' + c.toRadixString(16).padLeft(4, '0');
  }
  return String.fromCharCode(c);
}).join();

/// Literal, feedback-only text.
final class Text {
  Text(this.content, {this.kind = TextKind.ordinary});
  final String content;
  final TextKind kind;

  void present({StringSink? output}) {
    final prefix = switch (kind) {
      TextKind.ordinary => '',
      TextKind.hint => 'Hint: ',
      TextKind.success => 'Success: ',
      TextKind.warning => 'Warning: ',
      TextKind.error => 'Error: ',
    };
    (output ?? stderr).writeln('$prefix${_safe(content)}');
  }
}

/// The operation's reported outcome; reaching a value never implies one.
enum FeedbackOutcome { completed, failed, skipped, cancelled, interrupted }

/// Caller-owned progress presentation. Construction does not produce output.
final class Progress {
  Progress(
    this.label, {
    int? total,
    this.interval = const Duration(seconds: 5),
    this.milestone = 10,
  }) : _total = total {
    if (interval.isNegative || milestone <= 0 || milestone > 100) {
      throw ArgumentError('Invalid progress cadence');
    }
    if (total != null && total <= 0) throw ArgumentError.value(total, 'total');
  }
  final String label;
  final Duration interval;
  final int milestone;
  final Stopwatch _clock = Stopwatch()..start();
  Duration? _lastUpdate;
  Timer? _timer;
  int _shownPercent = 0;
  int? _pending;
  String? _phase;
  int? _total;
  int _value = 0;
  StringSink? _output;
  bool _rich = false;
  bool _finished = false;

  void start({
    StringSink? output,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    bool? supportsRich,
  }) {
    if (_output != null) throw StateError('Already started');
    final sink = output ?? stderr;
    final capable = supportsRich ?? (sink is Stdout && sink.hasTerminal);
    final selected =
        mode ?? userPreference ?? applicationPreference ?? PromptMode.automatic;
    if (selected == PromptMode.rich && !capable) {
      throw StateError('Rich output unavailable');
    }
    _rich = capable && selected != PromptMode.linear;
    _output = sink;
    _show();
  }

  void _show() {
    final value = _total == null
        ? 'indeterminate'
        : '${(_value * 100 ~/ _total!)}%${_rich ? ' ($_value/$_total)' : ''}';
    _emit('${_safe(label)}: running, $value');
  }

  void update(int completed) {
    if (_finished) return;
    if (_output == null) throw StateError('Not started');
    if (_total == null || completed < 0 || completed > _total!) {
      throw ArgumentError.value(completed, 'completed');
    }
    if (_rich) {
      if (completed == _value) return;
      _value = completed;
      _show();
      return;
    }
    _value = completed;
    final percent = completed * 100 ~/ _total!;
    if (percent == _shownPercent) {
      _timer?.cancel();
      _timer = null;
      _pending = null;
      return;
    }
    if (percent ~/ milestone <= _shownPercent ~/ milestone &&
        _pending == null) {
      return;
    }
    _pending = completed;
    final elapsed = _lastUpdate == null
        ? interval
        : _clock.elapsed - _lastUpdate!;
    if (elapsed >= interval) {
      _flush();
    } else {
      _timer ??= Timer(interval - elapsed, _flush);
    }
  }

  /// Report a meaningful phase without waiting for numeric throttling.
  void phase(String description) {
    if (_finished) return;
    if (_output == null) throw StateError('Not started');
    if (_phase == description) return;
    _phase = description;
    _emit('${_safe(label)}: running, ${_safe(description)}');
  }

  /// Change the work estimate, explicitly identifying the recalculation.
  void setTotal(int? total, {int completed = 0}) {
    if (_finished) return;
    if (_output == null) throw StateError('Not started');
    if ((total != null && (total <= 0 || completed < 0 || completed > total)) ||
        (total == null && completed != 0)) {
      throw ArgumentError('Invalid total or completed count');
    }
    if (total == _total && completed == _value) return;
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _total = total;
    _value = completed;
    _shownPercent = total == null ? 0 : completed * 100 ~/ total;
    final value = total == null ? 'indeterminate' : '$_shownPercent%';
    _emit('${_safe(label)}: recalculated, $value');
  }

  void _flush() {
    _timer?.cancel();
    _timer = null;
    if (_pending == null || _finished) return;
    _value = _pending!;
    _pending = null;
    _shownPercent = _value * 100 ~/ _total!;
    _lastUpdate = _clock.elapsed;
    _show();
  }

  void _emit(String line, {bool finalLine = false}) {
    _output!.writeln(_rich ? '[status] $line' : line);
  }

  /// Release presentation resources without inventing an outcome.
  void dispose() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    _pending = null;
  }

  void finish(FeedbackOutcome outcome, {String? detail}) {
    if (_finished) return;
    if (_output == null) throw StateError('Not started');
    _finished = true;
    _timer?.cancel();
    _pending = null;
    _emit(
      '${_safe(label)}: ${outcome.name}${detail == null ? '' : ': ${_safe(detail)}'}',
      finalLine: true,
    );
  }
}

/// Feedback for activity whose total work is unknown.
final class Spinner {
  Spinner(this.label);
  final String label;
  StringSink? _output;
  bool _rich = false;
  String _state = 'running';
  bool _finished = false;

  void start({
    StringSink? output,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    bool? supportsRich,
  }) {
    if (_output != null) throw StateError('Already started');
    final sink = output ?? stderr;
    final capable = supportsRich ?? (sink is Stdout && sink.hasTerminal);
    final selected =
        mode ?? userPreference ?? applicationPreference ?? PromptMode.automatic;
    if (selected == PromptMode.rich && !capable) {
      throw StateError('Rich output unavailable');
    }
    _rich = capable && selected != PromptMode.linear;
    _output = sink;
    _emit('${_safe(label)}: $_state');
  }

  void update(String state) {
    if (_finished) return;
    if (_output == null) throw StateError('Not started');
    if (state == _state) return;
    _state = state;
    _emit('${_safe(label)}: ${_safe(state)}');
  }

  void _emit(String line, {bool finalLine = false}) {
    _output!.writeln(_rich ? '[status] $line' : line);
  }

  /// Release presentation resources without inventing an outcome.
  void dispose() {
    if (_finished) return;
    _finished = true;
  }

  void finish(FeedbackOutcome outcome, {String? detail}) {
    if (_finished) return;
    if (_output == null) throw StateError('Not started');
    _finished = true;
    _emit(
      '${_safe(label)}: ${outcome.name}${detail == null ? '' : ': ${_safe(detail)}'}',
      finalLine: true,
    );
  }
}
