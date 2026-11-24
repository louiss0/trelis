import 'dart:io';
import 'dart:async';

import 'color_theme.dart';
import 'output_profile.dart';
import 'prompt_structure.dart';
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
    return t?.environment['NO_COLOR']?.isNotEmpty == true
        ? profile.copyWith(colorDepth: ColorDepth.none)
        : profile;
  }
  if (t == null) {
    // Direct `output:` calls keep their existing explicit-colour behavior;
    // NO_COLOR remains a hard restriction at this final output boundary.
    return Platform.environment['NO_COLOR']?.isNotEmpty == true
        ? const OutputProfile(colorDepth: ColorDepth.none)
        : const OutputProfile(colorDepth: ColorDepth.rgb);
  }
  final output = t.output;
  if (t.environment['NO_COLOR']?.isNotEmpty == true) {
    return const OutputProfile(colorDepth: ColorDepth.none);
  }
  return output is Stdout && output.hasTerminal
      ? const OutputProfile(colorDepth: ColorDepth.rgb)
      : const OutputProfile();
}

StringSink _selectedOutput({StringSink? output, TerminalIo? terminal}) {
  if (output != null && terminal != null) {
    throw ArgumentError('Specify either output or terminal, not both.');
  }
  return output ?? terminal?.output ?? stdout;
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

/// The semantic state of one feedback line before presentation.
///
/// These values describe what happened, not which glyph or colour renders it;
/// the theme renderer chooses display-safe indicators from the owned period.
enum FeedbackState {
  information,
  hint,
  running,
  progress,
  success,
  warning,
  failure,
}

/// One display-safe feedback line awaiting theme-owned rendering.
final class FeedbackLine {
  const FeedbackLine(this.message, {required this.state, this.frame = -1});

  /// Already-escaped semantic content, without a structural prefix.
  final String message;
  final FeedbackState state;

  /// Live-activity frame for spinner lines.
  ///
  /// A nonnegative value cycles the structure's spinner family anchored at
  /// this index; [feedbackFrameWaiting] marks a task still waiting for work;
  /// -1 leaves the state's ordinary label.
  final int frame;
}

/// [FeedbackLine.frame] value for a task that has not started working.
const int feedbackFrameWaiting = -2;

/// The marker a spinner line carries before its message.
///
/// A live frame cycles the structure's spinner family; a waiting task takes
/// the structure's waiting marker; an outcome takes the matching state
/// symbol; an informational line keeps no marker. The marker is display text
/// composed before structural framing, so a rail or enclosure wraps it with
/// the line.
String _liveMarker(
  PromptStructure structure,
  FeedbackState state,
  int frame,
  OutputProfile? profile,
) {
  final ascii =
      profile == null ||
      profile.glyphs == GlyphSet.ascii ||
      profile.glyphs == GlyphSet.automatic;
  if (frame >= 0) {
    return '${structureSpinFrame(structure, frame, ascii: ascii)} ';
  }
  if (frame == feedbackFrameWaiting) {
    return '${structureWaitGlyph(structure, ascii: ascii)} ';
  }
  return switch (state) {
    FeedbackState.success => ascii ? '+ ' : '✓ ',
    FeedbackState.warning => '! ',
    FeedbackState.failure => ascii ? 'x ' : '× ',
    _ => '',
  };
}

/// Whether the marker above renders a glyph a `[status]` tag would duplicate.
bool _hasLiveMarker(FeedbackState state, int frame) =>
    frame >= 0 ||
    frame == feedbackFrameWaiting ||
    state == FeedbackState.success ||
    state == FeedbackState.warning ||
    state == FeedbackState.failure;

/// Renders structured feedback for one theme-owned active period.
///
/// Components keep their own value and lifecycle semantics; this seam only
/// replaces their direct terminal formatting when a theme owns the output.
abstract interface class FeedbackRenderer {
  /// Whether rendered lines are announced text rather than painted frames.
  ///
  /// Screen-reader output must stay a linear transcript: repainting a live
  /// row re-delivers the same words as control sequences a reader cannot
  /// present as animation, so live regions fall back to appended lines.
  bool get screenReader => false;

  String render(FeedbackLine line);
}

FeedbackState _textState(TextKind kind) => switch (kind) {
  TextKind.ordinary => FeedbackState.information,
  TextKind.hint => FeedbackState.hint,
  TextKind.success => FeedbackState.success,
  TextKind.warning => FeedbackState.warning,
  TextKind.error => FeedbackState.failure,
};

FeedbackState _outcomeState(FeedbackOutcome outcome) => switch (outcome) {
  FeedbackOutcome.completed => FeedbackState.success,
  FeedbackOutcome.failed => FeedbackState.failure,
  FeedbackOutcome.skipped ||
  FeedbackOutcome.cancelled ||
  FeedbackOutcome.interrupted => FeedbackState.warning,
};

/// Literal, feedback-only text.
final class Text {
  Text(
    this.content, {
    this.kind = TextKind.ordinary,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
  }) : themeRenderer = null;

  /// Internal construction seam for theme-owned feedback.
  ///
  /// This is not a stable public authoring path: the coordinated cutover
  /// replaces static factories with theme instance methods. Existing direct
  /// construction and invocation parameters remain unchanged.
  Text.themed(
    this.content, {
    this.kind = TextKind.ordinary,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    required this.themeRenderer,
  });

  final FeedbackRenderer? themeRenderer;
  final String content;
  final TextKind kind;
  final ColorTheme colors;
  final PromptStructure structure;

  void present({
    StringSink? output,
    TerminalIo? terminal,
    TerminalSession? session,
  }) {
    final renderer = themeRenderer;
    if (renderer != null) {
      if (session == null || output != null || terminal != null) {
        throw StateError(
          'Themed feedback renders only through its theme-owned session.',
        );
      }
      session.presentText(
        renderer.render(FeedbackLine(_safe(content), state: _textState(kind))),
      );
      return;
    }
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
    final line = structureFeedbackLine(
      '$prefix${_safe(content)}',
      structure: structure,
      profile: _outputProfile(terminal: terminal),
    );
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

/// Applies the declared structure's event vocabulary to one feedback line.
///
/// Feedback owns its own lifecycle and cadence, so a structural theme only
/// frames the line it already reports: the rail or branch prefix, or an
/// enclosure's side marker, is added to the display text before styling, never
/// to the semantic content, and a plain structure leaves the line
/// byte-for-byte unchanged. An enclosure never draws a frame around a single
/// feedback event; the compact marker keeps the structure recognisable without
/// claiming the event is a task stage.
String structureFeedbackLine(
  String line, {
  required PromptStructure structure,
  required OutputProfile? profile,
}) {
  final ascii =
      profile == null ||
      profile.glyphs == GlyphSet.ascii ||
      profile.glyphs == GlyphSet.automatic;
  if (usesStructureEnclosure(structure) || usesStructureHeading(structure)) {
    return '${structureLivePrefix(structure, ascii: ascii)}$line';
  }
  if (!usesStructurePrefix(structure)) return line;
  return frameStructureLines(structure, ascii: ascii, lines: [line]).single;
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
    this.structure = PromptStructure.plain,
  }) : themeRenderer = null,
       _total = total,
       _clock = clock ?? _SystemFeedbackClock() {
    if (interval.isNegative || milestone <= 0 || milestone > 100) {
      throw ArgumentError('Invalid progress cadence');
    }
    if (total != null && total <= 0) throw ArgumentError.value(total, 'total');
  }

  /// Internal construction seam for theme-owned feedback.
  Progress.themed(
    this.label, {
    int? total,
    this.interval = const Duration(seconds: 5),
    this.milestone = 10,
    FeedbackClock? clock,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    required this.themeRenderer,
  }) : _total = total,
       _clock = clock ?? _SystemFeedbackClock() {
    if (interval.isNegative || milestone <= 0 || milestone > 100) {
      throw ArgumentError('Invalid progress cadence');
    }
    if (total != null && total <= 0) throw ArgumentError.value(total, 'total');
  }

  final FeedbackRenderer? themeRenderer;
  final String label;
  final Duration interval;
  final int milestone;
  final FeedbackClock _clock;
  final ColorTheme colors;
  final PromptStructure structure;
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
    _emit(
      '${_safe(label)}: running, $value',
      state: _total == null ? FeedbackState.running : FeedbackState.progress,
    );
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
    _emit(
      '${_safe(label)}: running, ${_safe(description)}',
      state: FeedbackState.running,
    );
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
    _emit(
      '${_safe(label)}: recalculated, $value',
      state: FeedbackState.progress,
    );
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

  void _emit(
    String line, {
    FeedbackState state = FeedbackState.information,
    bool finalLine = false,
  }) {
    final region = _sessionRegion;
    final renderer = themeRenderer;
    final styled = renderer != null
        ? renderer.render(FeedbackLine(line, state: state))
        : _styleLine(line, finalLine: finalLine);
    if (region != null) {
      region.write(styled);
    } else {
      _output!.writeln(_rich ? '[status] $styled' : styled);
    }
  }

  String _styleLine(String line, {required bool finalLine}) {
    final framed = structureFeedbackLine(
      line,
      structure: structure,
      profile: _profile,
    );
    return terminalStyledText(
      framed,
      foreground: finalLine && framed.contains(': failed')
          ? colors.error
          : colors.foreground,
      background: colors.background,
      depth: _profile?.colorDepth ?? ColorDepth.none,
    );
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
      state: _outcomeState(outcome),
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

/// The repaint cadence of a live spinner on a repaintable screen.
const Duration _spinnerFrameTick = Duration(milliseconds: 125);

/// Feedback for activity whose total work is unknown.
final class Spinner {
  Spinner(
    this.label, {
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    FeedbackClock? clock,
  }) : themeRenderer = null,
       _clock = clock ?? _SystemFeedbackClock();

  /// Internal construction seam for theme-owned feedback.
  Spinner.themed(
    this.label, {
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    FeedbackClock? clock,
    required this.themeRenderer,
  }) : _clock = clock ?? _SystemFeedbackClock();

  final FeedbackRenderer? themeRenderer;
  final String label;
  final ColorTheme colors;
  final PromptStructure structure;
  final FeedbackClock _clock;
  OutputProfile? _profile;
  StringSink? _output;
  Object? _standaloneOwner;
  TerminalSessionFeedbackRegion? _sessionRegion;
  bool _rich = false;
  bool _inPlace = false;
  bool _livePainted = false;
  FeedbackTimer? _frameTimer;
  String _state = 'running';
  int _frame = 0;
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
      _inPlace =
          _rich &&
          (terminal?.supportsRich == true ||
              (sink is Stdout && sink.hasTerminal));
      _output = sink;
      _standaloneOwner = TerminalSession.claimStandaloneFeedbackOutput(sink);
      _profile = profile;
    }
    _emit(
      '${_safe(label)}: $_state',
      state: FeedbackState.running,
      frame: _frame++,
    );
    if (_inPlace ||
        ((_sessionRegion?.rich ?? false) &&
            !(themeRenderer?.screenReader ?? false))) {
      _scheduleFrameTick();
    }
  }

  void update(String state) {
    if (_finished) return;
    if (_output == null && _sessionRegion == null) {
      throw StateError('Not started');
    }
    if (state == _state) return;
    _state = state;
    _emit(
      '${_safe(label)}: ${_safe(state)}',
      state: FeedbackState.running,
      frame: _frame++,
    );
  }

  /// Spins until [work] resolves, then finishes.
  ///
  /// This is the common case: the spinner's lifetime is exactly the future's.
  /// [active] becomes the middle word while the work is pending — one
  /// [update] before awaiting — and [detail] becomes the end word on the
  /// completed line. When [work] throws the spinner finishes as failed with
  /// the error as its detail before the error propagates.
  Future<T> run<T>(
    FutureOr<T> Function() work, {
    String? active,
    String? detail,
  }) async {
    if (active != null) update(active);
    try {
      final value = await work();
      finish(FeedbackOutcome.completed, detail: detail);
      return value;
    } catch (error) {
      finish(FeedbackOutcome.failed, detail: error.toString());
      rethrow;
    }
  }

  /// Whether the session region currently repaints live lines in place.
  bool get _regionLive {
    final region = _sessionRegion;
    return region != null &&
        region.live &&
        !(themeRenderer?.screenReader ?? false);
  }

  void _scheduleFrameTick() {
    if (_finished) return;
    _frameTimer = _clock.schedule(_spinnerFrameTick, _onFrameTick);
  }

  /// Advances the spinner family while the screen can actually repaint.
  ///
  /// A session that cannot paint the bottom row (a prompt or modal owns it)
  /// keeps cadence without emitting: an appended frame line every tick would
  /// grow the transcript without animating anything.
  void _onFrameTick() {
    _frameTimer = null;
    if (_finished) return;
    if (_sessionRegion != null && !_regionLive) {
      _scheduleFrameTick();
      return;
    }
    _emit(
      '${_safe(label)}: ${_safe(_state)}',
      state: FeedbackState.running,
      frame: _frame++,
    );
    _scheduleFrameTick();
  }

  /// Repaints the live standalone row, or commits it on the final line.
  void _paintLive(String styled, {required bool finalLine}) {
    final out = _output!;
    if (_livePainted) out.write('\r\x1b[2K');
    if (finalLine) {
      out.writeln(styled);
      _livePainted = false;
    } else {
      out.write(styled);
      _livePainted = true;
    }
  }

  void _emit(
    String line, {
    FeedbackState state = FeedbackState.information,
    int frame = -1,
    bool finalLine = false,
  }) {
    final region = _sessionRegion;
    final renderer = themeRenderer;
    final styled = renderer != null
        ? renderer.render(FeedbackLine(line, state: state, frame: frame))
        : _styleLine(line, state: state, frame: frame, finalLine: finalLine);
    if (region != null) {
      if (frame >= 0 && _regionLive) {
        region.writeLive(styled);
      } else {
        region.write(styled);
      }
    } else if (_inPlace) {
      _paintLive(styled, finalLine: finalLine);
    } else {
      _output!.writeln(
        _rich && !_hasLiveMarker(state, frame) ? '[status] $styled' : styled,
      );
    }
  }

  String _styleLine(
    String line, {
    required FeedbackState state,
    required int frame,
    required bool finalLine,
  }) {
    final framed = structureFeedbackLine(
      '${_liveMarker(structure, state, frame, _profile)}$line',
      structure: structure,
      profile: _profile,
    );
    return terminalStyledText(
      framed,
      foreground: finalLine && framed.contains(': failed')
          ? colors.error
          : colors.foreground,
      background: colors.background,
      depth: _profile?.colorDepth ?? ColorDepth.none,
    );
  }

  /// Release presentation resources without inventing an outcome.
  void dispose() {
    if (_finished) return;
    _finished = true;
    _frameTimer?.cancel();
    _frameTimer = null;
    if (_livePainted) {
      // The unterminated live row becomes transcript history.
      _output!.write('\n');
      _livePainted = false;
    }
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
    _frameTimer?.cancel();
    _frameTimer = null;
    _emit(
      '${_safe(label)}: ${outcome.name}${detail == null ? '' : ': ${_safe(detail)}'}',
      state: _outcomeState(outcome),
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
    this.structure = PromptStructure.plain,
  }) : themeRenderer = null,
       _clock = clock ?? _SystemFeedbackClock() {
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

  /// Internal construction seam for theme-owned feedback.
  MultiSpinner.themed(
    Iterable<String> tasks, {
    this.interval = const Duration(seconds: 5),
    FeedbackClock? clock,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    required this.themeRenderer,
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

  final FeedbackRenderer? themeRenderer;
  final Duration interval;
  final Map<String, _GroupTask> _tasks = {};
  final Set<String> _pending = {};
  final FeedbackClock _clock;
  final ColorTheme colors;
  final PromptStructure structure;
  OutputProfile? _profile;
  Duration? _lastBatch;
  FeedbackTimer? _timer;
  FeedbackTimer? _frameTimer;
  int _frame = 0;
  StringSink? _output;
  Object? _standaloneOwner;
  TerminalSessionFeedbackRegion? _sessionRegion;
  bool _rich = false;
  bool _inPlace = false;
  int _liveRows = 0;
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
      _inPlace =
          _rich &&
          (terminal?.supportsRich == true ||
              (sink is Stdout && sink.hasTerminal));
      _output = sink;
      _standaloneOwner = TerminalSession.claimStandaloneFeedbackOutput(sink);
      _profile = profile;
    }
    _emitLiveTasks();
    if (_inPlace ||
        ((_sessionRegion?.rich ?? false) &&
            !(themeRenderer?.screenReader ?? false))) {
      _scheduleFrameTick();
    }
  }

  /// The tasks still occupying the live block; finished tasks are transcript.
  Iterable<MapEntry<String, _GroupTask>> get _liveTasks =>
      _tasks.entries.where((entry) => entry.value.outcome == null);

  /// Whether the session region currently repaints the live block in place.
  bool get _regionLive {
    final region = _sessionRegion;
    return region != null &&
        region.live &&
        !(themeRenderer?.screenReader ?? false);
  }

  String _styledTaskRow(MapEntry<String, _GroupTask> entry) {
    final state = entry.value;
    final line = '${_safe(entry.key)}: ${state.description}';
    final feedbackState = state.outcome == null
        ? FeedbackState.running
        : _outcomeState(state.outcome!);
    final frame = state.outcome == null
        ? (state.activity == TaskActivity.running
              ? _frame++
              : feedbackFrameWaiting)
        : -1;
    final renderer = themeRenderer;
    return renderer != null
        ? renderer.render(FeedbackLine(line, state: feedbackState, frame: frame))
        : _styleLine(line, state: feedbackState, frame: frame);
  }

  /// Shows the current live tasks: a repaint of the whole block when the
  /// screen can hold it, otherwise one appended line per reported task.
  ///
  /// With [pendingOnly] the transcript fallback emits only the tasks whose
  /// shown description changed, matching the batched flush contract; live
  /// repaints always redraw the whole block either way.
  void _emitLiveTasks({bool pendingOnly = false}) {
    final region = _sessionRegion;
    if (_inPlace) {
      _paintBlock();
      for (final entry in _tasks.entries) {
        entry.value.shown = entry.value.description;
      }
      return;
    }
    if (region != null && _regionLive) {
      region.writeLive(_liveTasks.map(_styledTaskRow).join('\n'));
      for (final entry in _tasks.entries) {
        entry.value.shown = entry.value.description;
      }
      return;
    }
    for (final entry in _tasks.entries) {
      if (entry.value.outcome == null &&
          (!pendingOnly || _pending.contains(entry.key))) {
        _emit(
          '${_safe(entry.key)}: ${entry.value.description}',
          state: FeedbackState.running,
          frame: entry.value.activity == TaskActivity.running
              ? _frame++
              : feedbackFrameWaiting,
        );
        entry.value.shown = entry.value.description;
      }
    }
  }

  /// Repaints the standalone live block at the screen bottom.
  void _paintBlock() {
    final out = _output!;
    final buffer = StringBuffer();
    if (_liveRows > 0) {
      buffer.write('\r');
      if (_liveRows > 1) buffer.write('\x1b[${_liveRows - 1}A');
      buffer.write('\x1b[0J');
    }
    final rows = [for (final entry in _liveTasks) _styledTaskRow(entry)];
    buffer.write(rows.join('\n'));
    out.write(buffer);
    _liveRows = rows.length;
  }

  /// Terminates the painted standalone block, leaving it as transcript.
  void _commitBlock() {
    if (_liveRows == 0) return;
    _output!.write('\n');
    _liveRows = 0;
  }

  void _scheduleFrameTick() {
    if (_closed || !_tasks.values.any((task) => task.outcome == null)) return;
    _frameTimer = _clock.schedule(_spinnerFrameTick, _onFrameTick);
  }

  /// Advances running task frames while the screen can actually repaint.
  void _onFrameTick() {
    _frameTimer = null;
    if (_closed) return;
    final region = _sessionRegion;
    if (region != null && !_regionLive) {
      _scheduleFrameTick();
      return;
    }
    if (_tasks.values.any(
      (task) => task.activity == TaskActivity.running && task.outcome == null,
    )) {
      _emitLiveTasks();
    }
    _scheduleFrameTick();
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
    _emitLiveTasks(pendingOnly: true);
    _pending.clear();
    _lastBatch = _clock.elapsed;
  }

  /// Runs [task] until [work] resolves, then finishes it.
  ///
  /// One promise per spin: the task starts running when called and finishes
  /// exactly when its future settles. [phase] is the middle word shown while
  /// pending and [detail] the end word on the completed line. When [work]
  /// throws the task finishes failed with the error as detail before the
  /// error propagates.
  Future<T> run<T>(
    String task,
    FutureOr<T> Function() work, {
    String? phase,
    String? detail,
  }) async {
    update(task, TaskActivity.running, phase: phase);
    try {
      final value = await work();
      finishTask(task, FeedbackOutcome.completed, detail: detail);
      return value;
    } catch (error) {
      finishTask(task, FeedbackOutcome.failed, detail: error.toString());
      rethrow;
    }
  }

  /// Runs every task in [work] until its own future resolves.
  ///
  /// One promise per spin: each entry starts its task running immediately
  /// and finishes it when that future settles — the whole group is done when
  /// the slowest promise is. Returns the results keyed by task. When work
  /// throws, that task finishes failed and the first error propagates only
  /// after every task has reached a final state.
  Future<Map<String, Object?>> runAll(
    Map<String, FutureOr<Object?> Function()> work,
  ) async {
    final entries = work.entries.toList();
    final results = await Future.wait(
      [for (final entry in entries) run(entry.key, entry.value)],
      eagerError: false,
    );
    return {
      for (var i = 0; i < entries.length; i++) entries[i].key: results[i],
    };
  }

  void finishTask(String task, FeedbackOutcome outcome, {String? detail}) {
    if (_closed) return;
    final state = _task(task);
    if (state.outcome != null) return;
    state.outcome = outcome;
    state.detail = detail;
    _pending.remove(task);
    _emit(
      '${_safe(task)}: ${state.description}',
      state: _outcomeState(outcome),
    );
    final region = _sessionRegion;
    if (region != null && _regionLive && _liveTasks.isNotEmpty) {
      // The committed outcome row ended this region's live block; repaint the
      // tasks still running beneath it.
      region.writeLive(_liveTasks.map(_styledTaskRow).join('\n'));
    }
    if (_tasks.values.every((value) => value.outcome != null)) {
      _summary();
      _closed = true;
      _timer?.cancel();
      _frameTimer?.cancel();
      _frameTimer = null;
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
      final outcome = entry.value.outcome;
      _emit(
        '${_safe(entry.key)}: ${entry.value.description}',
        state: outcome == null
            ? FeedbackState.information
            : _outcomeState(outcome),
      );
    }
  }

  void _emit(
    String line, {
    FeedbackState state = FeedbackState.information,
    int frame = -1,
  }) {
    final region = _sessionRegion;
    final renderer = themeRenderer;
    final styled = renderer != null
        ? renderer.render(FeedbackLine(line, state: state, frame: frame))
        : _styleLine(line, state: state, frame: frame);
    if (region != null) {
      region.write(styled);
    } else if (_inPlace && _liveRows > 0) {
      // A committed line lands above the live block; the tasks still running
      // repaint beneath it.
      final out = _output!;
      out.write('\r');
      if (_liveRows > 1) out.write('\x1b[${_liveRows - 1}A');
      out.write('\x1b[0J');
      out.writeln(styled);
      _liveRows = 0;
      _paintBlock();
    } else {
      _output!.writeln(
        _rich && !_hasLiveMarker(state, frame) ? '[status] $styled' : styled,
      );
    }
  }

  String _styleLine(
    String line, {
    required FeedbackState state,
    required int frame,
  }) {
    final framed = structureFeedbackLine(
      '${_liveMarker(structure, state, frame, _profile)}$line',
      structure: structure,
      profile: _profile,
    );
    return terminalStyledText(
      framed,
      foreground: framed.contains(': failed')
          ? colors.error
          : (framed.contains(': completed')
                ? colors.success
                : colors.foreground),
      background: colors.background,
      depth: _profile?.colorDepth ?? ColorDepth.none,
    );
  }

  /// Stop presentation without assigning outcomes to unfinished tasks.
  void dispose() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _frameTimer?.cancel();
    _frameTimer = null;
    _pending.clear();
    _commitBlock();
    if (_output != null || _sessionRegion != null) _summary();
    _sessionRegion?.retire();
    final owner = _standaloneOwner;
    if (owner != null && _output != null) {
      TerminalSession.releaseStandaloneFeedbackOutput(_output!, owner);
      _standaloneOwner = null;
    }
  }
}
