import 'dart:io';
import 'dart:async';

import 'color_theme.dart';
import 'output_profile.dart';
import 'terminal_io.dart';
import 'text_input.dart'
    show PromptMode, TerminalSession, TerminalSessionFeedbackRegion;

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

OutputProfile _outputProfile({TerminalIo? terminal}) {
  final t = terminal;
  if (t is TerminalIoOutputProfile) {
    final profile = (t as TerminalIoOutputProfile).outputProfile;
    return profile;
  }
  return const OutputProfile(colorDepth: ColorDepth.rgb);
}

StringSink _selectedOutput({StringSink? output, TerminalIo? terminal}) {
  if (output != null && terminal != null) {
    throw ArgumentError('Specify either output or terminal, not both.');
  }
  return output ?? terminal?.output ?? stderr;
}

bool _supportsRich({
  required StringSink output,
  required bool? declared,
  required TerminalIo? terminal,
}) =>
    declared ??
    terminal?.supportsRich ??
    (output is Stdout && output.hasTerminal);

TerminalSessionFeedbackRegion _startInSession(
  TerminalSession session, {
  StringSink? output,
  TerminalIo? terminal,
  PromptMode? mode,
  PromptMode? userPreference,
  PromptMode? applicationPreference,
  bool? supportsRich,
}) {
  if (output != null ||
      terminal != null ||
      (mode != null && mode != PromptMode.automatic) ||
      (userPreference != null && userPreference != PromptMode.automatic) ||
      (applicationPreference != null &&
          applicationPreference != PromptMode.automatic) ||
      supportsRich != null) {
    throw ArgumentError(
      'Feedback attached to a session inherits its output and presentation configuration.',
    );
  }
  return session.startFeedbackRegion();
}

/// Literal, feedback-only text.
final class Text {
  Text(
    this.content, {
    this.kind = TextKind.ordinary,
    this.colors = ColorThemes.terminalDefault,
  });
  final String content;
  final TextKind kind;
  final ColorTheme colors;

  void present({
    StringSink? output,
    TerminalIo? terminal,
    TerminalSession? session,
  }) {
    final prefix = switch (kind) {
      TextKind.ordinary => '',
      TextKind.hint => 'Hint: ',
      TextKind.success => 'Success: ',
      TextKind.warning => 'Warning: ',
      TextKind.error => 'Error: ',
    };
    final role = switch (kind) {
      TextKind.ordinary => colors.foreground,
      TextKind.hint => colors.muted,
      TextKind.success => colors.success,
      TextKind.warning => colors.warning,
      TextKind.error => colors.error,
    };
    final background = colors.background;
    final line = '$prefix${_safe(content)}';
    final profile = _outputProfile(terminal: terminal);
    final styled = terminalStyledText(
      line,
      foreground: role,
      background: background,
      depth: profile.colorDepth,
    );
    if (session != null) {
      if (output != null || terminal != null) {
        throw ArgumentError(
          'Text attached to a session inherits its output; do not supply output or terminal.',
        );
      }
      session.presentText(styled);
      return;
    }
    final sink = _selectedOutput(output: output, terminal: terminal);
    TerminalSession.ensureStandaloneOutputAvailable(sink);
    sink.writeln(styled);
  }
}

/// The operation's reported outcome; reaching a value never implies one.
enum FeedbackOutcome { completed, failed, skipped, cancelled, interrupted }

/// A cancellable feedback cadence callback.
abstract interface class FeedbackTimer {
  /// Prevents the scheduled callback from running.
  void cancel();
}

/// Time and delayed-callback ownership for feedback cadence.
///
/// Applications normally use the default system clock. Supplying a clock makes
/// Progress and MultiSpinner cadence deterministic without making rendering
/// responsible for advancing time.
abstract interface class FeedbackClock {
  /// The elapsed time used to decide whether a pending update may be shown.
  Duration get elapsed;

  /// Schedules [callback] after [delay].
  FeedbackTimer schedule(Duration delay, void Function() callback);
}

final class _SystemFeedbackClock implements FeedbackClock {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  FeedbackTimer schedule(Duration delay, void Function() callback) =>
      _SystemFeedbackTimer(Timer(delay, callback));
}

final class _SystemFeedbackTimer implements FeedbackTimer {
  _SystemFeedbackTimer(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

/// Caller-owned progress presentation. Construction does not produce output.
final class Progress {
  Progress(
    this.label, {
    int? total,
    this.interval = const Duration(seconds: 5),
    this.milestone = 10,
    FeedbackClock? clock,
    this.colors = ColorThemes.terminalDefault,
  }) : _total = total,
       _clock = clock ?? _SystemFeedbackClock() {
    if (interval.isNegative || milestone <= 0 || milestone > 100) {
      throw ArgumentError('Invalid progress cadence');
    }
    if (total != null && total <= 0) throw ArgumentError.value(total, 'total');
  }
  final String label;
  final Duration interval;
  final int milestone;
  final FeedbackClock _clock;
  final ColorTheme colors;
  OutputProfile? _profile;
  Duration? _lastUpdate;
  FeedbackTimer? _timer;
  int _shownPercent = 0;
  int? _pending;
  String? _phase;
  int? _total;
  int? get total => _total;
  int _value = 0;
  StringSink? _output;
  Object? _standaloneOwner;
  TerminalSessionFeedbackRegion? _sessionRegion;
  bool _rich = false;
  bool _finished = false;

  void start({
    StringSink? output,
    TerminalIo? terminal,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    bool? supportsRich,
    TerminalSession? session,
  }) {
    if (_output != null || _sessionRegion != null) {
      throw StateError('Already started');
    }
    if (session != null) {
      _sessionRegion = _startInSession(
        session,
        output: output,
        terminal: terminal,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        supportsRich: supportsRich,
      );
      _rich = _sessionRegion!.rich;
      _profile = const OutputProfile(colorDepth: ColorDepth.rgb);
    } else {
      final sink = _selectedOutput(output: output, terminal: terminal);
      final profile = _outputProfile(terminal: terminal);
      final capable = _supportsRich(
        output: sink,
        declared: supportsRich,
        terminal: terminal,
      );
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (selected == PromptMode.rich && !capable) {
        throw StateError('Rich output unavailable');
      }
      _rich = capable && selected != PromptMode.linear;
      _output = sink;
      _standaloneOwner = TerminalSession.claimStandaloneFeedbackOutput(sink);
      _profile = profile;
    }
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
    if (_output == null && _sessionRegion == null) {
      throw StateError('Not started');
    }
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
      _timer ??= _clock.schedule(interval - elapsed, _flush);
    }
  }

  /// Report a meaningful phase without waiting for numeric throttling.
  void phase(String description) {
    if (_finished) return;
    if (_output == null && _sessionRegion == null) {
      throw StateError('Not started');
    }
    if (_phase == description) return;
    _phase = description;
    _emit('${_safe(label)}: running, ${_safe(description)}');
  }

  /// Change the work estimate, explicitly identifying the recalculation.
  void setTotal(int? total, {int completed = 0}) {
    if (_finished) return;
    if (_output == null && _sessionRegion == null) {
      throw StateError('Not started');
    }
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
    final region = _sessionRegion;
    final foreground = finalLine && line.contains(': failed')
        ? colors.error
        : colors.foreground;
    final styled = terminalStyledText(
      line,
      foreground: foreground,
      background: colors.background,
      depth: _profile?.colorDepth ?? ColorDepth.none,
    );
    if (region != null) {
      region.write(styled);
    } else {
      _output!.writeln(_rich ? '[status] $styled' : styled);
    }
  }

  /// Release presentation resources without inventing an outcome.
  void dispose() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    _pending = null;
    _sessionRegion?.retire();
    final owner = _standaloneOwner;
    if (owner != null && _output != null) {
      TerminalSession.releaseStandaloneFeedbackOutput(_output!, owner);
      _standaloneOwner = null;
    }
  }

  void finish(FeedbackOutcome outcome, {String? detail}) {
    if (_finished) return;
    if (_output == null && _sessionRegion == null) {
      throw StateError('Not started');
    }
    _finished = true;
    _timer?.cancel();
    _pending = null;
    _emit(
      '${_safe(label)}: ${outcome.name}${detail == null ? '' : ': ${_safe(detail)}'}',
      finalLine: true,
    );
    _sessionRegion?.retire();
    final owner = _standaloneOwner;
    if (owner != null && _output != null) {
      TerminalSession.releaseStandaloneFeedbackOutput(_output!, owner);
      _standaloneOwner = null;
    }
  }
}

/// Feedback for activity whose total work is unknown.
final class Spinner {
  Spinner(this.label, {this.colors = ColorThemes.terminalDefault});
  final String label;
  final ColorTheme colors;
  OutputProfile? _profile;
  StringSink? _output;
  Object? _standaloneOwner;
  TerminalSessionFeedbackRegion? _sessionRegion;
  bool _rich = false;
  String _state = 'running';
  bool _finished = false;

  void start({
    StringSink? output,
    TerminalIo? terminal,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    bool? supportsRich,
    TerminalSession? session,
  }) {
    if (_output != null || _sessionRegion != null) {
      throw StateError('Already started');
    }
    if (session != null) {
      _sessionRegion = _startInSession(
        session,
        output: output,
        terminal: terminal,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        supportsRich: supportsRich,
      );
      _rich = _sessionRegion!.rich;
      _profile = const OutputProfile(colorDepth: ColorDepth.rgb);
    } else {
      final sink = _selectedOutput(output: output, terminal: terminal);
      final profile = _outputProfile(terminal: terminal);
      final capable = _supportsRich(
        output: sink,
        declared: supportsRich,
        terminal: terminal,
      );
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (selected == PromptMode.rich && !capable) {
        throw StateError('Rich output unavailable');
      }
      _rich = capable && selected != PromptMode.linear;
      _output = sink;
      _standaloneOwner = TerminalSession.claimStandaloneFeedbackOutput(sink);
      _profile = profile;
    }
    _emit('${_safe(label)}: $_state');
  }

  void update(String state) {
    if (_finished) return;
    if (_output == null && _sessionRegion == null) {
      throw StateError('Not started');
    }
    if (state == _state) return;
    _state = state;
    _emit('${_safe(label)}: ${_safe(state)}');
  }

  void _emit(String line, {bool finalLine = false}) {
    final region = _sessionRegion;
    final foreground = finalLine && line.contains(': failed')
        ? colors.error
        : colors.foreground;
    final styled = terminalStyledText(
      line,
      foreground: foreground,
      background: colors.background,
      depth: _profile?.colorDepth ?? ColorDepth.none,
    );
    if (region != null) {
      region.write(styled);
    } else {
      _output!.writeln(_rich ? '[status] $styled' : styled);
    }
  }

  /// Release presentation resources without inventing an outcome.
  void dispose() {
    if (_finished) return;
    _finished = true;
    _sessionRegion?.retire();
    final owner = _standaloneOwner;
    if (owner != null && _output != null) {
      TerminalSession.releaseStandaloneFeedbackOutput(_output!, owner);
      _standaloneOwner = null;
    }
  }

  void finish(FeedbackOutcome outcome, {String? detail}) {
    if (_finished) return;
    if (_output == null && _sessionRegion == null) {
      throw StateError('Not started');
    }
    _finished = true;
    _emit(
      '${_safe(label)}: ${outcome.name}${detail == null ? '' : ': ${_safe(detail)}'}',
      finalLine: true,
    );
    _sessionRegion?.retire();
    final owner = _standaloneOwner;
    if (owner != null && _output != null) {
      TerminalSession.releaseStandaloneFeedbackOutput(_output!, owner);
      _standaloneOwner = null;
    }
  }
}

/// A task's nonterminal activity, reported by the application.
enum TaskActivity { waiting, running }

final class _GroupTask {
  TaskActivity activity = TaskActivity.waiting;
  String? phase;
  FeedbackOutcome? outcome;
  String? detail;
  String? shown;

  String get description => outcome == null
      ? '${activity.name}${phase == null ? '' : ', ${_safe(phase!)}'}'
      : '${outcome!.name}${detail == null ? '' : ': ${_safe(detail!)}'}';
}

/// Feedback for a stable group of uniquely named tasks.
final class MultiSpinner {
  MultiSpinner(
    Iterable<String> tasks, {
    this.interval = const Duration(seconds: 5),
    FeedbackClock? clock,
    this.colors = ColorThemes.terminalDefault,
  }) : _clock = clock ?? _SystemFeedbackClock() {
    if (interval.isNegative) throw ArgumentError.value(interval, 'interval');
    final displayNames = <String>{};
    for (final task in tasks) {
      if (task.isEmpty || !displayNames.add(_safe(task))) {
        throw ArgumentError.value(
          task,
          'tasks',
          'Names must be nonempty and visually distinct',
        );
      }
      _tasks[task] = _GroupTask();
    }
    if (_tasks.isEmpty) throw ArgumentError('At least one task is required');
  }

  final Duration interval;
  final Map<String, _GroupTask> _tasks = {};
  final Set<String> _pending = {};
  final FeedbackClock _clock;
  final ColorTheme colors;
  OutputProfile? _profile;
  Duration? _lastBatch;
  FeedbackTimer? _timer;
  StringSink? _output;
  Object? _standaloneOwner;
  TerminalSessionFeedbackRegion? _sessionRegion;
  bool _rich = false;
  bool _closed = false;

  void start({
    StringSink? output,
    TerminalIo? terminal,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    bool? supportsRich,
    TerminalSession? session,
  }) {
    if (_output != null || _sessionRegion != null || _closed) {
      throw StateError('Already started or disposed');
    }
    if (session != null) {
      _sessionRegion = _startInSession(
        session,
        output: output,
        terminal: terminal,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        supportsRich: supportsRich,
      );
      _rich = _sessionRegion!.rich;
      _profile = const OutputProfile(colorDepth: ColorDepth.rgb);
    } else {
      final sink = _selectedOutput(output: output, terminal: terminal);
      final profile = _outputProfile(terminal: terminal);
      final capable = _supportsRich(
        output: sink,
        declared: supportsRich,
        terminal: terminal,
      );
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (selected == PromptMode.rich && !capable) {
        throw StateError('Rich output unavailable');
      }
      _rich = capable && selected != PromptMode.linear;
      _output = sink;
      _standaloneOwner = TerminalSession.claimStandaloneFeedbackOutput(sink);
      _profile = profile;
    }
    for (final entry in _tasks.entries) {
      _emit('${_safe(entry.key)}: ${entry.value.description}');
      entry.value.shown = entry.value.description;
    }
  }

  _GroupTask _task(String task) {
    if (_output == null && _sessionRegion == null) {
      throw StateError('Not started');
    }
    return _tasks[task] ??
        (throw ArgumentError.value(task, 'task', 'Unknown task'));
  }

  void update(String task, TaskActivity activity, {String? phase}) {
    if (_closed) return;
    final state = _task(task);
    if (state.outcome != null) return;
    state.activity = activity;
    state.phase = phase;
    if (state.description == state.shown) {
      _pending.remove(task);
      return;
    }
    _pending.add(task);
    final elapsed = _lastBatch == null
        ? interval
        : _clock.elapsed - _lastBatch!;
    if (elapsed >= interval) {
      _flush();
    } else {
      _timer ??= _clock.schedule(interval - elapsed, _flush);
    }
  }

  void _flush() {
    _timer?.cancel();
    _timer = null;
    if (_closed || _pending.isEmpty) return;
    for (final entry in _tasks.entries) {
      if (_pending.contains(entry.key)) {
        _emit('${_safe(entry.key)}: ${entry.value.description}');
        entry.value.shown = entry.value.description;
      }
    }
    _pending.clear();
    _lastBatch = _clock.elapsed;
  }

  void finishTask(String task, FeedbackOutcome outcome, {String? detail}) {
    if (_closed) return;
    final state = _task(task);
    if (state.outcome != null) return;
    state.outcome = outcome;
    state.detail = detail;
    _pending.remove(task);
    _emit('${_safe(task)}: ${state.description}');
    if (_tasks.values.every((value) => value.outcome != null)) {
      _summary();
      _closed = true;
      _timer?.cancel();
      _pending.clear();
      _sessionRegion?.retire();
      final owner = _standaloneOwner;
      if (owner != null && _output != null) {
        TerminalSession.releaseStandaloneFeedbackOutput(_output!, owner);
        _standaloneOwner = null;
      }
    }
  }

  void _summary() {
    _emit('Summary:');
    for (final entry in _tasks.entries) {
      _emit('${_safe(entry.key)}: ${entry.value.description}');
    }
  }

  void _emit(String line) {
    final region = _sessionRegion;
    final foreground = line.contains(': failed')
        ? colors.error
        : (line.contains(': completed') ? colors.success : colors.foreground);
    final styled = terminalStyledText(
      line,
      foreground: foreground,
      background: colors.background,
      depth: _profile?.colorDepth ?? ColorDepth.none,
    );
    if (region != null) {
      region.write(styled);
    } else {
      _output!.writeln(_rich ? '[status] $styled' : styled);
    }
  }

  /// Stop presentation without assigning outcomes to unfinished tasks.
  void dispose() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _pending.clear();
    if (_output != null || _sessionRegion != null) _summary();
    _sessionRegion?.retire();
    final owner = _standaloneOwner;
    if (owner != null && _output != null) {
      TerminalSession.releaseStandaloneFeedbackOutput(_output!, owner);
      _standaloneOwner = null;
    }
  }
}
