import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:characters/characters.dart';
import 'package:path/path.dart' as path;
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'output_profile.dart';
import 'color_theme.dart';
import 'native_resize.dart';
import 'presentation.dart';
import 'prompt_structure.dart';
import 'terminal_io.dart';
import 'text_measurement.dart';
import 'uts46.dart';

part 'masked_input.dart';
part 'network_input.dart';
part 'url_email_input.dart';
part 'color_input.dart';
part 'color_names.dart';
part 'cron_input.dart';
part 'timezone_snapshot.dart';
part 'timezone_select.dart';
part 'path_input.dart';
part 'filesystem_picker.dart';
part 'number_input.dart';
part 'autocomplete.dart';
part 'search_select.dart';
part 'tree_order.dart';

part 'command_palette.dart';
part 'key_capture.dart';

part 'duration_input.dart';
part 'date_input.dart';
part 'range_input.dart';

sealed class PromptResult<T> {}

final class Accepted<T> extends PromptResult<T> {
  Accepted(this.value);
  final T value;
}

final class InputEnded<T> extends PromptResult<T> {}

final class Cancelled<T> extends PromptResult<T> {}

final class Interrupted<T> extends PromptResult<T> {}

final class Unavailable<T> extends PromptResult<T> {
  Unavailable(this.reason);
  final String reason;
}

/// The kind of a meaningful, ordered TextInput presentation occurrence.
///
/// Repaints and current editable views are deliberately not events. Query and
/// results occurrences record the projection that was actually presented, so
/// acceptance, retry availability and help access are observed facts rather
/// than inferences from a painted snapshot.
enum TextInputPresentationEventKind {
  opened,
  help,
  validation,
  submitted,
  cancelled,
  interrupted,
  inputEnded,

  /// A query/results state was presented; the event's `results` carries the
  /// typed projection.
  results,

  /// The interaction moved from the query stage to a results stage.
  resultsFocused,

  /// A candidate or source-stable reference was accepted into the draft answer.
  /// It is not the prompt's acceptance outcome.
  candidateAccepted,

  /// The presented action was refused; the event's `reference` and `text`
  /// identify it when known.
  rejected,
}

/// An immutable current editable view. This is distinct from committed
/// presentation history: moving the caret updates this view without adding an
/// event to the transcript.
final class TextInputCurrentView {
  const TextInputCurrentView({
    required this.text,
    required this.caret,
    required this.containsPaste,
  });

  final String text;
  final int caret;
  final bool containsPaste;
}

/// A meaningful, identified presentation occurrence in a TextInput run.
final class TextInputPresentationEvent {
  const TextInputPresentationEvent({
    required this.id,
    required this.kind,
    this.text,
    this.isLiteral = false,
    this.containsPaste = false,
    this.reference,
    this.results,
  });

  final int id;
  final TextInputPresentationEventKind kind;
  final String? text;
  final bool isLiteral;
  final bool containsPaste;

  /// The displayed source-stable reference, when the occurrence concerns one.
  final int? reference;

  /// The typed query/results projection that was presented, when applicable.
  final QueryResultsPresentation? results;
}

/// Public recording seam for a scripted TextInput presentation.
///
/// [currentView] is replaced as the editor repaints. [events] records only
/// meaningful occurrences, in delivery order, with stable run-local ids.
final class TextInputTranscript {
  final List<TextInputPresentationEvent> _events = [];
  TextInputCurrentView? _currentView;

  List<TextInputPresentationEvent> get events => List.unmodifiable(_events);
  TextInputCurrentView? get currentView => _currentView;

  void _view(TextInputCurrentView view) => _currentView = view;
  void _event(
    TextInputPresentationEventKind kind, {
    String? text,
    bool isLiteral = false,
    bool containsPaste = false,
    int? reference,
    QueryResultsPresentation? results,
  }) {
    _events.add(
      TextInputPresentationEvent(
        id: _events.length + 1,
        kind: kind,
        text: text,
        isLiteral: isLiteral,
        containsPaste: containsPaste,
        reference: reference,
        results: results,
      ),
    );
  }
}

sealed class PromptSource {}

typedef _SessionPromptRunner<T> = Future<PromptResult<T>> Function(
  PromptSource source,
  PromptMode mode, {
  OutputProfile? outputProfile,
  _Keys? keys,
  TerminalSession? session,
});

final class SuppliedTags extends PromptSource {
  SuppliedTags(List<String> values) : values = List.unmodifiable(values);
  final List<String> values;
}

final class SuppliedAnswer extends PromptSource {
  SuppliedAnswer(this.value);
  final String value;
}

final class ScriptedInput extends PromptSource {
  ScriptedInput(
    this.input,
    this.output, {
    this.supportsRich = true,
    this.outputProfile = const OutputProfile(),
    this.transcript,
    this.resizeObserver,
    this._observedGeometry,
    this._hardColorDisabled = false,
  });
  final Stream<String> input;
  final StringSink output;

  /// Legacy cursor/rich hint retained for source compatibility.
  ///
  /// It is not evidence of dimensions, styles, colours, glyphs, or an
  /// alternate screen. Rich synthetic output additionally needs positive
  /// [outputProfile] geometry or invocation geometry.
  final bool supportsRich;

  /// Declared output facts for this scripted source.
  final OutputProfile outputProfile;

  /// Optional public recorder for the current view and meaningful events.
  final TextInputTranscript? transcript;

  /// Optional live selected-output geometry observation for idle rich prompts.
  final TerminalResizeObserver? resizeObserver;

  // Native code records actual selected-output dimensions separately so an
  // invocation declaration can fill unknown facts but cannot enlarge them.
  final OutputGeometry? _observedGeometry;

  final bool _hardColorDisabled;
}

OutputProfile _terminalOutputProfile(TerminalIo terminal) =>
    terminal is TerminalIoOutputProfile
    ? (terminal as TerminalIoOutputProfile).outputProfile
    : const OutputProfile();

TerminalResizeObserver? _terminalResizeObserver(TerminalIo terminal) =>
    terminal is TerminalIoResizeObserver
    ? (terminal as TerminalIoResizeObserver).resizeObserver
    : null;

OutputProfile _constrainToObservedGeometry(
  OutputProfile profile,
  OutputGeometry? observed,
) {
  if (observed == null ||
      observed.isAutomatic ||
      profile.geometry.isAutomatic) {
    return profile;
  }
  return profile.copyWith(
    geometry: OutputGeometry.fixed(
      columns: profile.geometry.columns! < observed.columns!
          ? profile.geometry.columns!
          : observed.columns!,
      rows: profile.geometry.rows! < observed.rows!
          ? profile.geometry.rows!
          : observed.rows!,
    ),
  );
}

/// Resolves the effective output profile of one scripted invocation.
///
/// The invocation declaration, the source declaration, the legacy rich hint
/// and the observed geometry are combined once, and a source that reports a
/// hard restriction (a non-empty `NO_COLOR`) cannot be styled by a declared
/// colour depth. Components call this instead of repeating the order.
OutputProfile _effectiveOutputProfile(
  ScriptedInput scripted,
  OutputProfile? invocation,
) {
  final resolved = _constrainToObservedGeometry(
    OutputProfile.resolve(
      invocation: invocation,
      source: scripted.outputProfile,
      supportsRich: scripted.supportsRich,
    ),
    scripted._observedGeometry,
  );
  return scripted._hardColorDisabled
      ? resolved.copyWith(colorDepth: ColorDepth.none)
      : resolved;
}

enum PromptMode { rich, linear, automatic }

/// Selects how much optional TextInput opening guidance is shown.
///
/// [themeDefault] preserves the reference presentation's expanded guidance.
/// Essential prompt context and a route to full help remain visible for every
/// value.
enum InstructionDisplay { themeDefault, compact, expanded, hidden }

/// Applies an instruction display policy to a labelled introduction.
///
/// The parts keep the label and its guidance separable so an enclosure can put
/// the label inside the frame and the guidance outside it without re-deriving
/// either from the joined reference string.
({String title, String guidance}) _instructionIntroParts(
  InstructionDisplay policy, {
  required ({String title, String guidance}) hidden,
  required ({String title, String guidance}) compact,
  required ({String title, String guidance}) expanded,
}) => switch (policy) {
  InstructionDisplay.hidden => hidden,
  InstructionDisplay.compact => compact,
  InstructionDisplay.themeDefault || InstructionDisplay.expanded => expanded,
};

/// Writes one component introduction: a label and its opening guidance.
///
/// The reference grammar is a single labelled block. A structure that frames
/// with a line prefix keeps that block, so a rail or branch reads exactly as it
/// does without the split. A structure that encloses the stage, or decorates its
/// heading, separates the two: the label is the stage heading and the guidance
/// is the compact hint under it, which is where the declared grammars put it.
void _writeStructureIntro(
  _StructureSpine spine,
  StringSink output, {
  required ({String title, String guidance}) parts,
  required TerminalColor foreground,
  bool rawWhenUnframed = false,
}) {
  final joined = parts.guidance.isEmpty
      ? parts.title
      : '${parts.title} ${parts.guidance}';
  if (!usesStructureFraming(spine.structure)) {
    // An unframed component keeps its reference introduction: the components
    // that never route through the spine keep their single unwrapped line, and
    // the ones that do keep the palette styling the spine applies.
    if (rawWhenUnframed) {
      output.writeln(joined);
    } else {
      spine.write(output, joined, foreground: foreground, closes: true);
    }
    return;
  }
  if (spine.encloses || spine.heads) {
    spine.heading(output, parts.title, foreground: foreground);
    spine.hint(output, parts.guidance, foreground: foreground);
    return;
  }
  spine.write(output, joined, foreground: foreground, closes: true);
}

/// Joins the non-empty parts of component help guidance.
String _joinHelp(Iterable<String> parts) =>
    parts.where((part) => part.isNotEmpty).join(' ');

/// Identifies the presentation facts a query/results occurrence records, so a
/// repaint of identical facts does not duplicate presentation history.
String _presentationSignature(QueryResultsPresentation presentation) => [
  presentation.phase.name,
  presentation.identityModel.name,
  presentation.query.value,
  presentation.totalResults,
  presentation.page,
  for (final notice in presentation.notices) notice.name,
  for (final row in presentation.rows)
    '${row.reference}/${row.position}/${row.label.value}/'
        '${row.focused}/${row.isDefault}/${row.unavailableReason?.value}',
].join('|');

final _noScreenOwner = Object();
final _screenOwners = Expando<Object>('prompty terminal screen owner');

/// One shared screen claim held by running standalone feedback.
///
/// Several independent feedback regions may present on one sink, so the claim
/// is reference-counted rather than exclusive. It still excludes a session: a
/// scoped owner requires the whole screen, while standalone feedback would
/// keep writing unscoped status lines into it.
final class _StandaloneFeedbackClaim {
  int _owners = 1;
}

Object? _screenOwner(StringSink output) {
  final owner = _screenOwners[output as Object];
  return identical(owner, _noScreenOwner) ? null : owner;
}

bool _hasSessionOwner(StringSink output) =>
    _screenOwner(output) is TerminalSession;

void _claimScreen(StringSink output, Object owner) {
  if (_screenOwner(output) != null) {
    throw StateError(
      'This output already has a terminal screen owner; attach to its TerminalSession instead.',
    );
  }
  _screenOwners[output as Object] = owner;
}

void _releaseScreen(StringSink output, Object owner) {
  if (identical(_screenOwner(output), owner)) {
    _screenOwners[output as Object] = _noScreenOwner;
  }
}

/// An opaque, session-local live-feedback registration.
///
/// Its identity belongs to the session rather than a feedback label, so a
/// retired registration cannot be revived by a late application update.
final class TerminalSessionFeedbackRegion {
  TerminalSessionFeedbackRegion._(this._session, this._id, this._generation);

  final TerminalSession _session;
  final int _id;
  final int _generation;
  bool _retired = false;

  bool get rich => _session._feedbackRich;

  void write(String line) {
    if (_retired) return;
    _session._writeFeedback(this, line);
  }

  void retire() {
    if (_retired) return;
    _retired = true;
    _session._retireFeedback(this);
  }
}

/// One feedback line that arrived while modal help owned painting.
///
/// Its identity is the occurrence, not the displayed text: a session delivers
/// every occurrence a producer reported, and comparing text to decide whether
/// two of them are the same event would silently merge independent regions and
/// repeated notifications. The sequence keeps their arrival order stable.
final class _DeferredFeedbackLine {
  const _DeferredFeedbackLine(this.sequence, this.line);

  final int sequence;
  final String line;
}

/// Coordinates sequential prompt and feedback invocations over one selected
/// terminal.
///
/// A session handle is only created by [run]. Attached components inherit its
/// input, output and presentation configuration; they cannot take competing
/// ownership of those resources.
///
/// A failed shared writer retires the scope: registrations are retired, no
/// further writes reach the selected output, and the pending prompt ends with
/// the original failure instead of waiting for input. A caller that catches the
/// writer failure must still await or handle that prompt. Recovery is only
/// claimed for supported exits; a forcible process termination or an
/// unmanaged external writer mutating the same terminal cannot be recovered.
final class TerminalSession {
  TerminalSession._(
    this._output,
    this._source,
    this._terminalIo,
    this._mode,
    this._userPreference,
    this._applicationPreference,
    this._outputProfile,
  );

  final StringSink _output;
  final ScriptedInput? _source;
  final TerminalIo? _terminalIo;
  final PromptMode? _mode;
  final PromptMode? _userPreference;
  final PromptMode? _applicationPreference;
  final OutputProfile? _outputProfile;
  _Keys? _keys;
  Stream<String>? _keysInput;
  final List<TerminalSessionFeedbackRegion> _feedback = [];
  final Map<int, int> _liveGenerations = {};

  /// The latest line of each live region, in registration order.
  ///
  /// A retired region has no live line: its outcome is transcript history, so
  /// it neither contributes a label to the compact summary nor replays when
  /// modal help returns.
  final Map<int, String> _feedbackSnapshots = {};

  /// The latest deferred line of each region that reported while help owned
  /// painting, in first-deferral order.
  ///
  /// Only the latest line is kept per region: the composite restores the
  /// current state, not a backlog. Important occurrences are retained
  /// separately, so a later ordinary update cannot displace a notice the
  /// transcript still owes the reader.
  final Map<int, _DeferredFeedbackLine> _deferredFeedback = {};

  /// Meaningful notices that arrived while help owned painting, in arrival
  /// order.
  ///
  /// A component may report several facts through one region (a task group
  /// reports every task through the session's single region), so a later
  /// ordinary update must not displace a failure the transcript still owes the
  /// reader. Each emission is retained as its own occurrence: two regions may
  /// report the same words, and one region may report the same words twice, and
  /// neither is a repaint of the other. Text is never compared to decide that.
  final List<_DeferredFeedbackLine> _deferredNotices = [];
  int _nextDeferredSequence = 1;

  /// Whether the newest emitted feedback line reported a warning, error or
  /// explicit outcome. A retired failure stays reviewable in the transcript
  /// without marking every later status.
  bool _lastFeedbackLineImportant = false;
  int _nextRegionId = 1;
  void Function()? _promptRepaint;
  bool _activePrompt = false;
  OutputGeometry? _promptGeometry;
  bool _modalHelp = false;
  bool _modalUsesAlternateScreen = false;
  bool _closed = false;
  Object? _sharedWriterFailure;
  StackTrace? _sharedWriterFailureStackTrace;

  bool get _feedbackRich {
    final selected =
        _mode ??
        _userPreference ??
        _applicationPreference ??
        PromptMode.automatic;
    if (selected == PromptMode.linear) return false;
    final sourceProfile =
        _source?.outputProfile ??
        (_terminalIo == null
            ? const OutputProfile()
            : _terminalOutputProfile(_terminalIo));
    final profile = OutputProfile.resolve(
      invocation: _outputProfile,
      source: sourceProfile,
      supportsRich: _source?.supportsRich ?? _terminalIo?.supportsRich ?? false,
    );
    return profile.supportsRichInteraction;
  }

  /// Closes all presentation registrations after the shared writer fails.
  ///
  /// No best-effort diagnostic is written here: the selected writer is the
  /// failed resource and diagnostics must not expose application data through
  /// an arbitrary fallback. Scope cleanup still stops the reader, releases the
  /// screen claim, and restores any prompt lease that was acquired.
  void _closeAfterSharedWriterFailure(Object error, StackTrace stackTrace) {
    if (_closed) return;
    _sharedWriterFailure = error;
    _sharedWriterFailureStackTrace = stackTrace;
    _closed = true;
    _modalHelp = false;
    _modalUsesAlternateScreen = false;
    _promptRepaint = null;
    _promptGeometry = null;
    for (final region in _feedback) {
      region._retired = true;
    }
    _feedback.clear();
    _liveGenerations.clear();
    _feedbackSnapshots.clear();
    _deferredFeedback.clear();
    _deferredNotices.clear();
    // The active prompt cannot be answered through a retired session, so it
    // must end with the original failure instead of waiting for input that can
    // never be acted on, even when the caller caught the write failure.
    _keys?.fail(error, stackTrace);
  }

  /// Returns the session-owned reader for [input].
  ///
  /// A session keeps one reader per selected input stream, so buffered input,
  /// open escape sequences and paste provenance survive sequential prompts
  /// without resubscribing. When the selected input changes — the real console
  /// selects a fresh stream for every prompt — the reader that retirement can
  /// fail has to follow it, and the replaced reader is closed so it stops
  /// observing a stream this session no longer offers.
  Future<_Keys> _readerFor(Stream<String> input) async {
    final current = _keys;
    if (current != null && identical(_keysInput, input)) return current;
    _keys = null;
    _keysInput = null;
    await current?.close();
    final keys = _Keys(input.transform(utf8.encoder));
    _keys = keys;
    _keysInput = input;
    final failure = _sharedWriterFailure;
    final failureStackTrace = _sharedWriterFailureStackTrace;
    if (_closed && failure != null && failureStackTrace != null) {
      // Retirement happened while the previous reader was being closed. The
      // new reader must still end rather than park a prompt on a dead session.
      keys.fail(failure, failureStackTrace);
    }
    return keys;
  }

  /// Performs one serialized shared-output action and retires the session if
  /// its writer fails. Local registration and validation failures never take
  /// this path, so unrelated regions remain usable.
  void _writeShared(void Function() action) {
    if (_closed) {
      final failure = _sharedWriterFailure;
      final failureStackTrace = _sharedWriterFailureStackTrace;
      if (failure != null && failureStackTrace != null) {
        Error.throwWithStackTrace(failure, failureStackTrace);
      }
      return;
    }
    try {
      action();
    } catch (error, stackTrace) {
      _closeAfterSharedWriterFailure(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Registers one feedback region with this session's serialized writer.
  /// Feedback components call this when they are started with `session:`.
  TerminalSessionFeedbackRegion startFeedbackRegion() {
    if (_closed) throw StateError('Terminal session is closed.');
    final region = TerminalSessionFeedbackRegion._(this, _nextRegionId++, 1);
    _feedback.add(region);
    _liveGenerations[region._id] = region._generation;
    return region;
  }

  void _retireFeedback(TerminalSessionFeedbackRegion region) {
    if (_liveGenerations[region._id] != region._generation) return;
    _liveGenerations.remove(region._id);
    _feedback.remove(region);
    _feedbackSnapshots.remove(region._id);
    if (!_modalHelp && _feedbackNeedsCompaction) {
      _paintCompactFeedback();
      _writeShared(() => _promptRepaint?.call());
    }
  }

  int? get _feedbackCapacity {
    if (!_feedbackRich || _promptRepaint == null) return null;
    final rows = _promptGeometry?.rows;
    if (rows == null) return null;
    // The active editable row is never feedback capacity. A one-row screen
    // therefore retains the prompt/caret and moves every background detail to
    // reviewable history.
    return rows - 1;
  }

  bool _isImportantFeedback(String line) =>
      line.startsWith('Warning: ') ||
      line.startsWith('Error: ') ||
      line.contains(': failed') ||
      line.contains(': skipped') ||
      line.contains(': cancelled') ||
      line.contains(': interrupted') ||
      line.contains(': completed');

  bool get _hasImportantFeedback =>
      _lastFeedbackLineImportant ||
      _feedbackSnapshots.values.any(_isImportantFeedback);

  bool get _feedbackNeedsCompaction {
    final capacity = _feedbackCapacity;
    if (capacity == null) return false;
    return _feedback.length > capacity ||
        (capacity == 0 && _hasImportantFeedback);
  }

  String _compactFeedbackLine() {
    final labels = <String>[
      for (final region in _feedback)
        if (_feedbackSnapshots[region._id] case final line?)
          line.split(':').first,
    ];
    var line =
        '${_hasImportantFeedback ? '[!] ' : ''}Feedback (${labels.length})';
    if (labels.isNotEmpty) {
      final columns = _promptGeometry?.columns;
      final available = columns == null ? null : columns - '[status] '.length;
      final visible = <String>[];
      for (var index = 0; index < labels.length; index++) {
        final remaining = labels.length - index - 1;
        final suffix = remaining == 0
            ? labels[index]
            : '${labels[index]} +$remaining';
        final candidate = '$line: ${[...visible, suffix].join(', ')}';
        if (available != null &&
            TextDisplayMap(candidate).cellWidth > available) {
          break;
        }
        visible.add(labels[index]);
      }
      if (visible.isEmpty) {
        line = '$line: ${labels.length} active';
      } else {
        final remaining = labels.length - visible.length;
        line =
            '$line: ${visible.join(', ')}${remaining == 0 ? '' : ' +$remaining'}';
      }
    }
    return line;
  }

  void _paintCompactFeedback() {
    _writeShared(() {
      if (_promptRepaint != null && _feedbackRich) _output.write('\r\x1b[2K');
      _output.writeln('[status] ${_compactFeedbackLine()}');
    });
  }

  void _writeFeedback(TerminalSessionFeedbackRegion region, String line) {
    if (_closed ||
        _liveGenerations[region._id] != region._generation ||
        !_feedback.contains(region)) {
      return;
    }
    // Retain the current region snapshot even while help owns painting. A
    // worker may keep reporting progress during help, but it must not write
    // into the alternate screen or transcript between help lines.
    _feedbackSnapshots[region._id] = line;
    _lastFeedbackLineImportant = _isImportantFeedback(line);
    if (_modalHelp) {
      final deferred = _DeferredFeedbackLine(_nextDeferredSequence++, line);
      _deferredFeedback[region._id] = deferred;
      if (_isImportantFeedback(line)) _deferredNotices.add(deferred);
      return;
    }
    // One session-owned writer delivers a complete region update before the
    // prompt repaint. Clearing the editable line first prevents a status
    // write from overwriting the physical caret; the editor retains the
    // logical draft and anchor used by its repaint closure.
    if (_feedbackNeedsCompaction) {
      // Failures and explicit outcomes remain full, reviewable transcript
      // records even when the live portion has no available rows.
      if (_isImportantFeedback(line)) {
        _writeShared(() {
          if (_promptRepaint != null && _feedbackRich) {
            _output.write('\r\x1b[2K');
          }
          _output.writeln('${_feedbackRich ? '[status] ' : ''}$line');
        });
      }
      _paintCompactFeedback();
    } else {
      _writeShared(() {
        if (_promptRepaint != null && _feedbackRich) {
          _output.write('\r\x1b[2K');
        }
        _output.writeln('${_feedbackRich ? '[status] ' : ''}$line');
      });
    }
    _writeShared(() => _promptRepaint?.call());
  }

  /// Makes component help the sole owner of session painting until dismissed.
  ///
  /// Background regions continue to update their retained snapshots, but only
  /// this session decides whether an alternate screen is entered or a
  /// transcript fallback is used.
  void _openModalHelp({required bool useAlternateScreen}) {
    if (_closed) throw StateError('Terminal session is closed.');
    if (_modalHelp) return;
    _modalHelp = true;
    _modalUsesAlternateScreen = useAlternateScreen;
    if (useAlternateScreen) {
      _writeShared(() => _output.write('\x1b[?1049h\x1b[H'));
    }
  }

  void _restoreLatestComposite() {
    final notices = _deferredNotices.toList();
    final noticeSequences = {for (final notice in notices) notice.sequence};
    // The latest line of a region is replayed only when it is a different
    // occurrence from the notices above. Identity, not text, decides that: a
    // region that reported the same words twice keeps both events.
    final restore = [
      ...notices,
      for (final latest in _deferredFeedback.values)
        if (!noticeSequences.contains(latest.sequence)) latest,
    ]..sort((a, b) => a.sequence.compareTo(b.sequence));
    _deferredNotices.clear();
    _deferredFeedback.clear();
    if (_feedbackNeedsCompaction) {
      // Full reviewable notices survive the modal interval even when the live
      // portion has no rows; ordinary updates are summarized by the compact
      // line instead of growing the transcript.
      if (notices.isNotEmpty) {
        _writeShared(() {
          if (_promptRepaint != null && _feedbackRich) {
            _output.write('\r\x1b[2K');
          }
          for (final notice in notices) {
            _output.writeln(
              '${_feedbackRich ? '[status] ' : ''}${notice.line}',
            );
          }
        });
      }
      _paintCompactFeedback();
      return;
    }
    if (restore.isEmpty) return;
    _writeShared(() {
      for (final deferred in restore) {
        _output.writeln('${_feedbackRich ? '[status] ' : ''}${deferred.line}');
      }
    });
  }

  /// Dismisses session help and reconstitutes current state rather than a
  /// frame captured when help opened.
  void _dismissModalHelp({
    required bool showTranscriptDismissal,
    required void Function() repaintPrompt,
  }) {
    if (!_modalHelp) return;
    final usedAlternateScreen = _modalUsesAlternateScreen;
    if (usedAlternateScreen) _writeShared(() => _output.write('\x1b[?1049l'));
    _modalHelp = false;
    _modalUsesAlternateScreen = false;
    if (showTranscriptDismissal && !usedAlternateScreen) {
      _writeShared(() => _output.writeln('Help dismissed.'));
    }
    _restoreLatestComposite();
    _writeShared(repaintPrompt);
  }

  /// Releases session-owned help on an interruption, EOF, or exceptional exit.
  /// There is no editor to repaint, but the latest notices remain observable.
  void _abortModalHelp() {
    if (!_modalHelp || _closed) return;
    if (_modalUsesAlternateScreen) {
      _writeShared(() => _output.write('\x1b[?1049l'));
    }
    _modalHelp = false;
    _modalUsesAlternateScreen = false;
    _restoreLatestComposite();
  }

  /// Emits an informational block through the session writer.
  void presentText(String line) {
    if (_closed) throw StateError('Terminal session is closed.');
    final region = TerminalSessionFeedbackRegion._(this, _nextRegionId++, 1);
    // Text is a coordinated informational block rather than an input-owning
    // live region. It receives an identity for ordered writer delivery.
    _feedback.add(region);
    _liveGenerations[region._id] = region._generation;
    region.write(line);
    region.retire();
  }

  void _setPromptRepaint(void Function()? repaint) {
    _promptRepaint = repaint;
    if (repaint == null) {
      _promptGeometry = null;
    } else if (!_modalHelp && _feedbackNeedsCompaction) {
      _paintCompactFeedback();
      _writeShared(repaint);
    }
  }

  void _setPromptGeometry(OutputGeometry geometry) {
    _promptGeometry = geometry;
  }

  /// Claims a standalone feedback lifetime on [output].
  ///
  /// This is used by the feedback components to reject an independent writer
  /// while a session owns the selected screen. It never creates a shared
  /// global session: callers must explicitly attach to [run].
  ///
  /// The returned token registers the claim, so a session cannot take the same
  /// screen while standalone feedback is writing it. Release it with
  /// [releaseStandaloneFeedbackOutput] when the feedback finishes.
  static void ensureStandaloneOutputAvailable(StringSink output) {
    if (_hasSessionOwner(output)) {
      throw StateError(
        'This output already has a terminal screen owner; attach to its TerminalSession instead.',
      );
    }
  }

  /// Registers standalone feedback as a writer of [output] and returns its
  /// release token.
  ///
  /// Standalone feedback remains source-compatible with other standalone
  /// feedback: a second region joins the existing claim and the sink is only
  /// released when the last region finishes. It must not, however, paint
  /// through an explicit session, or start one.
  static Object claimStandaloneFeedbackOutput(StringSink output) {
    final owner = _screenOwner(output);
    if (owner is _StandaloneFeedbackClaim) {
      owner._owners++;
      return owner;
    }
    ensureStandaloneOutputAvailable(output);
    final claim = _StandaloneFeedbackClaim();
    _screenOwners[output as Object] = claim;
    return claim;
  }

  /// Releases a claim returned by [claimStandaloneFeedbackOutput].
  static void releaseStandaloneFeedbackOutput(StringSink output, Object owner) {
    if (owner is! _StandaloneFeedbackClaim) return;
    if (!identical(_screenOwner(output), owner)) return;
    owner._owners--;
    if (owner._owners <= 0) {
      _screenOwners[output as Object] = _noScreenOwner;
    }
  }

  /// Runs [callback] with a scoped terminal owner and returns its result after
  /// releasing any session-owned scripted reader.
  static Future<T> run<T>(
    FutureOr<T> Function(TerminalSession session) callback, {
    StringSink? output,
    ScriptedInput? source,
    TerminalIo? terminal,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    OutputProfile? outputProfile,
  }) async {
    if (source != null && terminal != null) {
      throw ArgumentError('Specify either source or terminal, not both.');
    }
    final selectedOutput = source?.output ?? terminal?.output;
    if (output != null &&
        selectedOutput != null &&
        !identical(output, selectedOutput)) {
      throw ArgumentError(
        'Session output must be identical to its input adapter output.',
      );
    }
    final selectedSink = output ?? selectedOutput ?? stderr;
    _claimScreen(selectedSink, Object());
    final session = TerminalSession._(
      selectedSink,
      source,
      terminal,
      mode,
      userPreference,
      applicationPreference,
      outputProfile,
    );
    // Replace the temporary claim with the handle exposed to the callback.
    _screenOwners[selectedSink as Object] = session;
    Object? operationError;
    try {
      return await callback(session);
    } catch (error, stackTrace) {
      operationError = error;
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      try {
        await session._close();
      } catch (cleanupError, cleanupStackTrace) {
        if (operationError != null) {
          throw TerminalSessionCleanupException(operationError, cleanupError);
        }
        Error.throwWithStackTrace(cleanupError, cleanupStackTrace);
      } finally {
        _releaseScreen(selectedSink, session);
      }
    }
  }

  /// Releases every resource owned by this scope, continuing after a cleanup
  /// failure so late callbacks cannot retain the reader, output claim, or live
  /// registration. The first cleanup failure is reported after all supported
  /// cleanup has been attempted.
  Future<void> _close() async {
    Object? cleanupError;
    StackTrace? cleanupStackTrace;

    void recordFailure(Object error, StackTrace stackTrace) {
      cleanupError ??= error;
      cleanupStackTrace ??= stackTrace;
    }

    try {
      _abortModalHelp();
    } catch (error, stackTrace) {
      recordFailure(error, stackTrace);
    }
    _closed = true;
    _promptRepaint = null;
    _promptGeometry = null;
    for (final region in _feedback) {
      region._retired = true;
    }
    _feedback.clear();
    _liveGenerations.clear();
    _feedbackSnapshots.clear();
    _deferredFeedback.clear();
    _deferredNotices.clear();
    try {
      await _keys?.close();
    } catch (error, stackTrace) {
      recordFailure(error, stackTrace);
    } finally {
      _keys = null;
      _keysInput = null;
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError!, cleanupStackTrace!);
    }
  }

  Future<PromptResult<T>> _promptRunner<T>(
    _SessionPromptRunner<T> runner, {
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    _CaptureControl? capture,
  }) async {
    if (_closed) throw StateError('Terminal session is closed.');
    if (source != null ||
        output != null ||
        terminal != null ||
        (mode != null && mode != PromptMode.automatic) ||
        (userPreference != null && userPreference != PromptMode.automatic) ||
        (applicationPreference != null &&
            applicationPreference != PromptMode.automatic) ||
        (outputProfile != null && !outputProfile.isAutomatic)) {
      throw ArgumentError(
        'An attached prompt inherits session input, output, mode and profile; do not supply competing invocation configuration.',
      );
    }
    if (_activePrompt) {
      throw StateError('A terminal session already has an active prompt.');
    }
    _activePrompt = true;
    try {
      final selected =
          _mode ??
          _userPreference ??
          _applicationPreference ??
          PromptMode.automatic;
      if (_source != null) {
        return await runner(
          ScriptedInput(
            const Stream<String>.empty(),
            _SessionOutputSink(this),
            supportsRich: _source.supportsRich,
            outputProfile: _source.outputProfile,
            transcript: _source.transcript,
            resizeObserver: _source.resizeObserver,
          ),
          selected,
          outputProfile: _outputProfile,
          keys: await _readerFor(_source.input),
          session: this,
        );
      }
      if (_terminalIo != null) {
        final lease = _terminalIo.acquire();
        final input = _terminalIo.input;
        // A session-owned reader lets retirement end an idle prompt and keeps
        // buffered input across sequential prompts, exactly as it does for a
        // scripted source. An adapter that selects a fresh stream per prompt
        // gets a reader for that stream instead of a stale one.
        return await _restoreAfter(
          () async => runner(
            ScriptedInput(
              input,
              _SessionOutputSink(this),
              supportsRich: _terminalIo.supportsRich,
              outputProfile: _terminalOutputProfile(_terminalIo),
              hardColorDisabled:
                  _terminalIo.environment['NO_COLOR']?.isNotEmpty == true,
              resizeObserver: _terminalResizeObserver(_terminalIo),
            ),
            selected,
            outputProfile: _outputProfile,
            keys: await _readerFor(input),
            session: this,
          ),
          lease.restore,
        );
      }
      if (_output is! Stdout) {
        throw StateError(
          'Native input requires a terminal output destination.',
        );
      }
      return await _terminal<T>(
        selected,
        _output,
        (nativeSource, nativeMode, _) =>
            _promptOnNativeConsole(nativeSource, nativeMode, runner),
        capture: capture,
      );
    } finally {
      _activePrompt = false;
    }
  }

  /// Runs one prompt over the native console transport this session acquired.
  ///
  /// The console transport lives for exactly one prompt, so its reader is
  /// scoped to that prompt instead of being kept across prompts. The session
  /// still owns it, so a retired session ends an idle console read with the
  /// original failure instead of waiting for the next keystroke.
  Future<PromptResult<T>> _promptOnNativeConsole<T>(
    ScriptedInput nativeSource,
    PromptMode nativeMode,
    _SessionPromptRunner<T> runner,
  ) async {
    final keys = await _readerFor(nativeSource.input);
    try {
      return await runner(
        ScriptedInput(
          nativeSource.input,
          _SessionOutputSink(this),
          supportsRich: nativeSource.supportsRich,
          outputProfile: nativeSource.outputProfile,
          transcript: nativeSource.transcript,
          resizeObserver: nativeSource.resizeObserver,
          observedGeometry: nativeSource._observedGeometry,
          hardColorDisabled: nativeSource._hardColorDisabled,
        ),
        nativeMode,
        outputProfile: _outputProfile,
        keys: keys,
        session: this,
      );
    } finally {
      if (identical(_keys, keys)) {
        _keys = null;
        _keysInput = null;
      }
      await keys.close();
    }
  }
}

/// Routes all prompt rendering through its owning session's shared writer.
/// This includes help, history commits, and resize repaints performed by a
/// component, rather than only feedback writes initiated by the session.
final class _SessionOutputSink implements StringSink {
  _SessionOutputSink(this._session);

  final TerminalSession _session;

  @override
  void write(Object? object) =>
      _session._writeShared(() => _session._output.write(object));

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) => _session
      ._writeShared(() => _session._output.writeAll(objects, separator));

  @override
  void writeCharCode(int charCode) =>
      _session._writeShared(() => _session._output.writeCharCode(charCode));

  @override
  void writeln([Object? object = '']) =>
      _session._writeShared(() => _session._output.writeln(object));
}

final _textInputDeclaration = PresentationDeclaration({
  PresentationSlot.label,
  PresentationSlot.context,
  PresentationSlot.body,
});

PresentationComposition _composeTextInput(
  TextInputPresentationContent content,
) => const PresentationCompositor().composeTextInput(
  content,
  _textInputDeclaration,
);

PresentationContentNode _slot(
  PresentationComposition composition,
  PresentationSlot slot,
) => [
  ...composition.body,
  ...composition.safetyArea,
].singleWhere((node) => node.slot == slot);

/// A prompt never claims more than this many columns, even if a remote output
/// reports an implausibly large geometry. Narrower declared geometry wins.
const _textInputTotalWidthCap = 120;

int? _textInputWidth(OutputProfile profile) =>
    profile.geometry.columns?.clamp(1, _textInputTotalWidthCap);

void _writeWrappedText(
  StringSink output,
  String text,
  int? width, {
  Iterable<String> atomicText = const [],
}) {
  for (final line in _wrapText(text, width, atomicText: atomicText)) {
    output.writeln(line);
  }
}

/// Whether [profile] cannot be trusted to render a structure's Unicode
/// vocabulary, so its ASCII counterpart is used instead.
bool _structureAscii(OutputProfile? profile) =>
    profile == null ||
    profile.glyphs == GlyphSet.ascii ||
    profile.glyphs == GlyphSet.automatic;

/// Writes the read-only lines of one structural stage.
///
/// Every call emits one wrapped block. A rail or branch opens its spine with
/// the first block, continues it on later blocks, and a block that [closes]
/// ends it so the compact hint finishes the structure. A box, rounded or double
/// structure instead encloses the stage: the first block opens the top rule,
/// later blocks are body rows inside the frame, [hint] closes the bottom rule
/// and writes the compact hint outside it, and later events stay outside the
/// frame as compact indented blocks. A heading structure decorates [heading],
/// indents every other block as a body row and marks the compact hint, so its
/// grammar is the declared heading/body/hint arrangement rather than a frame.
/// Wrapping measures the structural prefix, the enclosure's side rules or the
/// heading's decoration as part of the line, so a framed line still fits the
/// declared width instead of overflowing it by the chrome.
final class _StructureSpine {
  _StructureSpine({
    required this.structure,
    required this.ascii,
    required this.width,
    required this.background,
    required this.border,
    required this.outputProfile,
  });

  final PromptStructure structure;
  final bool ascii;
  int? width;
  final TerminalColor background;
  final TerminalColor border;
  final OutputProfile? outputProfile;
  bool _open = false;
  bool _closed = false;

  /// A stage boundary deferred the previous frame's bottom rule.
  ///
  /// A repaint or a new page calls [reset] before writing its own top rule, so
  /// the previous frame's bottom rule is held until output continues instead of
  /// leaving a frame without its bottom edge.
  bool _pendingClose = false;

  EnclosureGlyphs? get _enclosure =>
      enclosureGlyphsFor(structure, ascii: ascii);

  HeadingGlyphs? get _heading => headingGlyphsFor(structure, ascii: ascii);

  /// Whether this stage is drawn by a heading grammar rather than a frame.
  bool get heads => _heading != null;

  /// Whether this stage is drawn as an enclosure rather than a line prefix.
  bool get encloses => _encloses;

  /// Whether this stage is drawn as an enclosure rather than a line prefix.
  ///
  /// Narrow output simplifies the chrome instead of replacing the structure:
  /// below [structureEnclosureCompactWidth] the enclosure keeps only its left
  /// rule, so the stage still shows the structure's marker.
  bool get _encloses {
    final glyphs = _enclosure;
    if (glyphs == null) return false;
    return enclosureTotalWidth(structure, width) >=
        structureEnclosureCompactWidth;
  }

  /// The total width the enclosure may claim, including its own chrome.
  int get _frameWidth => enclosureTotalWidth(structure, width);

  /// The width a body row or enclosed block may use.
  int get _contentWidth =>
      enclosureContentWidth(structure, ascii: ascii, width: _frameWidth);

  /// The width a hint or compact event outside the frame may use.
  int get _outsideWidth => (_frameWidth - 2).clamp(1, _frameWidth);

  void _emit(StringSink output, String line, TerminalColor foreground) {
    if (line.isEmpty) return;
    output.writeln(_colorText(line, foreground, background, outputProfile));
  }

  /// Opens the enclosure with the stage's first block.
  ///
  /// A block that already wrapped hands its first line to the top rule and
  /// keeps the rest as body rows, so a heading reads as part of the frame. A
  /// block of one line stays whole inside the frame: a stage whose only content
  /// is its title then still has a body, and no stage draws an empty enclosure.
  void _openEnclosure(
    StringSink output,
    String text,
    TerminalColor foreground,
    Iterable<String> atomicText,
  ) {
    _open = true;
    final lines = _wrapText(text, _contentWidth, atomicText: atomicText);
    final titleCells = lines.isEmpty
        ? 0
        : TextDisplayMap(lines.first).cellWidth;
    final title = lines.length > 1 && titleCells + 4 <= _frameWidth
        ? lines.first
        : null;
    final body = title == null ? lines : lines.sublist(1);
    // The chrome is the structure's border, not the block's own foreground:
    // both rules then read as one frame around content of any colour.
    _emit(
      output,
      enclosureTopRule(
        structure,
        ascii: ascii,
        title: title,
        width: _frameWidth,
      ),
      border,
    );
    for (final line in body) {
      _emit(
        output,
        enclosureBodyRow(
          structure,
          ascii: ascii,
          line: line,
          width: _frameWidth,
        ),
        foreground,
      );
    }
  }

  /// Writes one enclosed body block.
  void _writeEnclosed(
    StringSink output,
    String text,
    TerminalColor foreground,
    Iterable<String> atomicText,
  ) {
    if (!_open) {
      _openEnclosure(output, text, foreground, atomicText);
      return;
    }
    for (final line in _wrapText(text, _contentWidth, atomicText: atomicText)) {
      _emit(
        output,
        enclosureBodyRow(
          structure,
          ascii: ascii,
          line: line,
          width: _frameWidth,
        ),
        foreground,
      );
    }
  }

  /// Closes the bottom rule of an open enclosure.
  void _closeEnclosure(StringSink output) {
    if (!_open) return;
    _open = false;
    _emit(
      output,
      enclosureBottomRule(structure, ascii: ascii, width: _frameWidth),
      border,
    );
  }

  /// Emits a bottom rule that a stage boundary deferred.
  void _flushPendingClose(StringSink output) {
    if (!_pendingClose) return;
    _pendingClose = false;
    _emit(
      output,
      enclosureBottomRule(structure, ascii: ascii, width: _frameWidth),
      border,
    );
  }

  /// Writes a compact block outside a closed frame.
  void _writeOutside(
    StringSink output,
    String text,
    TerminalColor foreground, {
    Iterable<String> atomicText = const [],
  }) {
    for (final line in _wrapText(text, _outsideWidth, atomicText: atomicText)) {
      _emit(output, '  $line', foreground);
    }
  }

  /// Wraps [text] to the width left by the prefix and writes it styled.
  ///
  /// [compact] marks a sequential event block rather than stage content. A
  /// prefixed structure keeps its existing prefix and closure, while an
  /// enclosure renders the block outside the frame: a repeated keystroke report
  /// must not draw a new frame on every key.
  void write(
    StringSink output,
    String text, {
    required TerminalColor foreground,
    bool closes = false,
    bool compact = false,
    Iterable<String> atomicText = const [],
  }) {
    if (_encloses) {
      _flushPendingClose(output);
      if (compact || _closed) {
        // A stage that already reported its compact hint keeps later events
        // outside the frame, and they never repaint the frame above them.
        _closeEnclosure(output);
        _writeOutside(output, text, foreground, atomicText: atomicText);
        return;
      }
      _writeEnclosed(output, text, foreground, atomicText);
      if (closes) {
        _closeEnclosure(output);
        _closed = true;
      }
      return;
    }
    if (_heading != null) {
      _writeHeadedBody(output, text, foreground, atomicText);
      return;
    }
    final available = width == null
        ? null
        : (width! - structurePrefixCells(structure, ascii: ascii)).clamp(
            1,
            width!,
          );
    final narrowEnclosure = _enclosure != null && !_encloses;
    if (narrowEnclosure) {
      // Narrow output keeps the enclosure's left rule as its marker instead of
      // silently becoming an unframed component.
      final lines = _wrapText(text, available, atomicText: atomicText);
      _open = !closes;
      for (final line in lines) {
        if (line.isEmpty) continue;
        output.writeln(
          _colorText(
            '${_enclosure!.livePrefix}$line',
            foreground,
            background,
            outputProfile,
          ),
        );
      }
      return;
    }
    final framed = frameStructureLines(
      structure,
      ascii: ascii,
      lines: _wrapText(text, available, atomicText: atomicText),
      opens: !_open,
      closes: closes,
    );
    _open = !closes;
    for (final line in framed) {
      if (line.isEmpty) continue;
      output.writeln(_colorText(line, foreground, background, outputProfile));
    }
  }

  /// Writes one stage opening: a heading and the guidance that belongs to it.
  ///
  /// A structure without a heading grammar writes the single merged block it
  /// always wrote, so the reference, rail, branch and enclosing presentations
  /// keep their bytes. A heading structure separates the two: the title is the
  /// decorated heading and the guidance follows as its body rows.
  void opening(
    StringSink output, {
    required String title,
    required String body,
    required TerminalColor foreground,
    required TerminalColor bodyForeground,
    bool closes = false,
    Iterable<String> atomicText = const [],
  }) {
    if (_heading == null) {
      final joined = body.isEmpty ? title : '$title $body';
      write(
        output,
        joined,
        foreground: foreground,
        closes: closes,
        atomicText: atomicText,
      );
      return;
    }
    heading(output, title, foreground: foreground, atomicText: atomicText);
    if (body.isEmpty) return;
    write(
      output,
      body,
      foreground: bodyForeground,
      closes: closes,
      atomicText: atomicText,
    );
  }

  /// Writes the stage heading of one heading structure.
  ///
  /// A structure without a heading grammar writes the block exactly as [write]
  /// would, so a rail, branch, enclosure or the reference presentation keeps
  /// the bytes it had. A heading structure decorates the heading with its own
  /// vocabulary, spells it with the declared casing rule, and indents every
  /// wrapped continuation line as part of the same heading. Narrow output
  /// simplifies the decoration to its marker rather than replacing the
  /// structure with an unframed one.
  void heading(
    StringSink output,
    String text, {
    required TerminalColor foreground,
    Iterable<String> atomicText = const [],
  }) {
    final glyphs = _heading;
    if (glyphs == null) {
      write(output, text, foreground: foreground, atomicText: atomicText);
      return;
    }
    _open = true;
    final compact = width != null && width! <= glyphs.headingCells + 2;
    final decorate = compact ? glyphs.compactPrefixCells : glyphs.headingCells;
    // Wrapped heading lines take the body indent, so the heading budget is the
    // tighter of the decoration and that indent.
    final reserve = decorate > glyphs.bodyIndentCells
        ? decorate
        : glyphs.bodyIndentCells;
    final available = width == null
        ? null
        : (width! - reserve).clamp(1, width!);
    final lines = frameHeadingLines(
      structure,
      ascii: ascii,
      compact: compact,
      lines: _wrapText(
        glyphs.spelling(text),
        available,
        atomicText: atomicText,
      ),
    );
    for (final line in lines) {
      if (line.isEmpty) continue;
      _emit(output, line, foreground);
    }
  }

  /// Writes one body row of a heading structure under its heading.
  ///
  /// Body rows are the stage's read-only content, its choice rows and its
  /// events. They keep their own spelling: only the heading the component owns
  /// is decorated or case-transformed.
  void _writeHeadedBody(
    StringSink output,
    String text,
    TerminalColor foreground,
    Iterable<String> atomicText,
  ) {
    final glyphs = _heading!;
    final available = width == null
        ? null
        : (width! - glyphs.bodyIndentCells).clamp(1, width!);
    for (final line in _wrapText(text, available, atomicText: atomicText)) {
      if (line.isEmpty) continue;
      _emit(output, glyphs.body(line), foreground);
    }
  }

  /// Writes the compact hint that ends the stage.
  ///
  /// A rail or branch closes its structural line, exactly as a [write] with
  /// `closes` does. An enclosure closes the bottom rule first and keeps the
  /// hint outside the frame, which is where the declared grammars put it: the
  /// hint names the stage's actions, not its content.
  void hint(
    StringSink output,
    String text, {
    required TerminalColor foreground,
    Iterable<String> atomicText = const [],
  }) {
    final glyphs = _heading;
    if (glyphs != null) {
      // A heading structure keeps its hint under the body rows, marked with the
      // structure's own hint vocabulary and wrapped inside the width the same
      // marker leaves. No block above it is repainted.
      final lead = '${glyphs.bodyIndent}${glyphs.hintPrefix}';
      final leadCells = glyphs.bodyIndentCells + glyphs.hintPrefixCells;
      // Narrow output simplifies the marker instead of overflowing the width:
      // the structure keeps its hint vocabulary at the column it can afford.
      final narrow = width != null && leadCells + 1 > width!;
      final first = narrow ? glyphs.hintPrefix.trimRight() : lead;
      final continuation = narrow
          ? ' ' * TextDisplayMap(first).cellWidth
          : '${glyphs.bodyIndent}${' ' * glyphs.hintPrefixCells}';
      final available = width == null
          ? null
          : (width! - TextDisplayMap(first).cellWidth).clamp(1, width!);
      var firstLine = true;
      for (final line in _wrapText(text, available, atomicText: atomicText)) {
        if (line.isEmpty) continue;
        _emit(output, '${firstLine ? first : continuation}$line', foreground);
        firstLine = false;
      }
      return;
    }
    if (!_encloses) {
      write(
        output,
        text,
        foreground: foreground,
        closes: true,
        atomicText: atomicText,
      );
      return;
    }
    _flushPendingClose(output);
    _closeEnclosure(output);
    _writeOutside(output, text, foreground, atomicText: atomicText);
    _closed = true;
  }

  /// Emits the breathing row that separates a heading from its choices.
  ///
  /// An enclosure keeps that row inside the frame, so the side rules continue
  /// through it exactly as the declared grammar draws it. A rail or branch has
  /// no interior to breathe in and keeps the rows it already wrote, so this is
  /// silent for them rather than adding a line they never had.
  void breathingRow(StringSink output) {
    if (!_encloses || !_open || _closed) return;
    _emit(
      output,
      enclosureBodyRow(structure, ascii: ascii, line: '', width: _frameWidth),
      border,
    );
  }

  /// Starts a new stage, so a repainted frame opens the structure again.
  void reset() {
    if (_encloses && _open) _pendingClose = true;
    _open = false;
    _closed = false;
  }
}

/// Builds the structure writer for one prompt invocation.
_StructureSpine _structureSpine(
  OutputProfile? outputProfile, {
  required PromptStructure structure,
  required int? width,
  required TerminalColor background,
  TerminalColor border = const TerminalColor.terminalDefault(),
}) => _StructureSpine(
  structure: structure,
  ascii: _structureAscii(outputProfile),
  width: width,
  background: background,
  border: border,
  outputProfile: outputProfile,
);

/// Splits [text] into the display lines that fit [width] cells.
///
/// A source line break is document structure rather than display content, so
/// each paragraph it separates is wrapped on its own and reaches the terminal as
/// a real line. Controls inside a paragraph keep their visible spelling, which
/// is why a paragraph's own `\t` or `\x1b` still renders as `\\u{0009}` or
/// `\\u{001B}`. Both CRLF and LF separate paragraphs; a lone CR is content.
///
/// A null [width] keeps each paragraph on one line. Each returned line is
/// already display-safe; the caller may still add terminal controls around it.
List<String> _wrapText(
  String text,
  int? width, {
  Iterable<String> atomicText = const [],
}) {
  final paragraphs = text.split(_paragraphBreak);
  if (width == null) {
    return [for (final paragraph in paragraphs) displaySafe(paragraph)];
  }
  return [
    for (final paragraph in paragraphs)
      ..._wrapParagraph(paragraph, width, atomicText: atomicText),
  ];
}

final _paragraphBreak = RegExp('\r\n|\n');

List<String> _wrapParagraph(
  String text,
  int width, {
  Iterable<String> atomicText = const [],
}) {
  // DisplayText's visible control spelling is one protected display unit: a
  // wrap may precede it but must not split `\\u{202E}` into misleading pieces.
  // Callers may protect further meaningful units, such as a choice row's state
  // markers, so wrapping never detaches a marker from its meaning.
  final unit = RegExp(
    [r'\\u\{[0-9A-F]+\}', ...atomicText.map(RegExp.escape)].join('|'),
  );
  final pieces = <({String text, int cells})>[];
  var offset = 0;
  void addMeasured(String segment) {
    for (final entry in TextDisplayMap(segment).entries) {
      pieces.add((text: entry.display, cells: entry.cellWidth));
    }
  }

  for (final match in unit.allMatches(text)) {
    addMeasured(text.substring(offset, match.start));
    final whole = match.group(0)!;
    pieces.add((text: whole, cells: TextDisplayMap(whole).cellWidth));
    offset = match.end;
  }
  addMeasured(text.substring(offset));
  final lines = <String>[];
  var line = StringBuffer();
  var cells = 0;
  for (final piece in pieces) {
    if (cells > 0 && cells + piece.cells > width) {
      lines.add(line.toString());
      line = StringBuffer();
      cells = 0;
    }
    line.write(piece.text);
    cells += piece.cells;
  }
  lines.add(line.toString());
  return lines;
}

/// Terminates the editable line that a segmented field editor leaves current.
///
/// `_edit` ends its own line when it submits or accepts a command; a control
/// action such as `next` or `increase` deliberately leaves the field on screen
/// for the next repaint. Callers that write guidance afterwards must terminate
/// that line first, or the guidance would overwrite the field the user is
/// leaving and hide the stacked field order.
void _finishFieldLine(StringSink out, String action) {
  if (action != 'submit' &&
      action != 'command' &&
      action != 'cancel' &&
      action != 'interrupt' &&
      action != 'eof') {
    out.writeln();
  }
}

/// Resolves a TextInput instruction policy to the display it actually uses.
InstructionDisplay _resolvedInstructions(InstructionDisplay instructions) =>
    instructions == InstructionDisplay.themeDefault
    ? InstructionDisplay.expanded
    : instructions;

/// The opening guidance a TextInput instruction policy asks for.
///
/// The opening and a re-presented validation share this one text, so a warning
/// never repeats a differently worded hint.
String _textInputGuidance({
  required bool linear,
  required InstructionDisplay instructions,
}) {
  final route = linear ? '/help opens help.' : 'Ctrl+T opens help.';
  return switch (_resolvedInstructions(instructions)) {
    InstructionDisplay.compact => 'Enter submits; $route Escape cancels.',
    InstructionDisplay.expanded =>
      'Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. $route Escape cancels; Ctrl+C interrupts.',
    InstructionDisplay.hidden => route,
    InstructionDisplay.themeDefault => throw StateError(
      'Instructions resolved above.',
    ),
  };
}

/// The linear command hint that follows the guidance, when the policy shows it.
String? _textInputCommandHint({
  required bool linear,
  required InstructionDisplay instructions,
}) => linear && _resolvedInstructions(instructions) != InstructionDisplay.hidden
    ? r'Exact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.'
    : null;

void _renderTextInputOpening(
  StringSink output,
  String label, {
  required bool required,
  required int? maxLength,
  required bool linear,
  required InstructionDisplay instructions,
  OutputProfile? outputProfile,
  ColorTheme colors = ColorThemes.terminalDefault,
  PromptStructure structure = PromptStructure.plain,
}) {
  final composition = _composeTextInput(
    TextInputPresentationContent(
      label: DisplayText.from(label),
      context: DisplayText.from(
        '(${required ? 'Required' : 'Optional'}${maxLength == null ? '' : ', maximum $maxLength graphemes'}).',
      ),
      editable: TextInputEditableRegion(
        beforeCaret: DisplayText.from(''),
        afterCaret: DisplayText.from(''),
      ),
    ),
  );
  final width = outputProfile == null ? null : _textInputWidth(outputProfile);
  final header =
      '${_slot(composition, PresentationSlot.label).text!.value} ${_slot(composition, PresentationSlot.context).text!.value}';
  final guidance = _textInputGuidance(
    linear: linear,
    instructions: instructions,
  );
  final commandHint = _textInputCommandHint(
    linear: linear,
    instructions: instructions,
  );
  final spine = _structureSpine(
    outputProfile,
    structure: structure,
    width: width,
    background: colors.background,
    border: colors.border,
  );
  spine.heading(output, header, foreground: colors.foreground);
  if (spine.encloses || spine.heads) {
    // A frame or a decorated heading ends with its compact hint, so the
    // guidance and the command hint are both marked blocks below it.
    spine.hint(output, guidance, foreground: colors.muted);
  } else {
    // A rail or branch keeps its merged spine: the guidance continues the
    // structural line only when no command hint closes it.
    spine.write(
      output,
      guidance,
      foreground: colors.muted,
      closes: commandHint == null,
    );
  }
  if (commandHint != null) {
    spine.hint(output, commandHint, foreground: colors.muted);
  }
}

String _textInputHelp({
  required bool linear,
  required bool required,
  required int? maxLength,
  required List<String> supplementaryHelp,
}) {
  final constraints =
      '${required ? 'A value is required' : 'An empty value is allowed'}${maxLength == null ? '' : '; maximum $maxLength graphemes'}.';
  final controls = linear
      ? r'Enter text to submit. Exact /help and /cancel are commands. Use \/help or \/cancel for literal commands; double a leading backslash to enter one. Identified paste is literal; unframed paste cannot be distinguished from typing.'
      : 'Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. Escape dismisses help or cancels; Ctrl+C interrupts.';
  return [
    'Help: $controls Validation: $constraints',
    ...supplementaryHelp,
  ].join('\n');
}

String _renderEditableText(
  PresentationContentNode node, {
  required bool beforeCaret,
}) => (beforeCaret ? node.editable!.beforeCaret : node.editable!.afterCaret)
    .value;

void _renderTextInputValidation(
  StringSink output,
  String message, {
  bool linear = false,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  OutputProfile? outputProfile,
  ColorTheme colors = ColorThemes.terminalDefault,
  PromptStructure structure = PromptStructure.plain,
}) {
  final composition = _composeTextInput(
    TextInputPresentationContent(
      label: DisplayText.from(''),
      context: DisplayText.from(''),
      validation: DisplayText.from(message),
      editable: TextInputEditableRegion(
        beforeCaret: DisplayText.from(''),
        afterCaret: DisplayText.from(''),
      ),
    ),
  );
  final width = outputProfile == null ? null : _textInputWidth(outputProfile);
  final validation = _slot(
    composition,
    PresentationSlot.validation,
  ).text!.value;
  final spine = _structureSpine(
    outputProfile,
    structure: structure,
    width: width,
    background: colors.background,
    border: colors.border,
  );
  if (!spine.encloses && !spine.heads) {
    // A rail, branch or plain stage keeps its single closing validation block.
    spine.hint(output, validation, foreground: colors.error);
    return;
  }
  // A validation is stage content, not the compact hint: the message is the
  // stage's warning row and the stage's own compact hint closes it below, so a
  // warning is never read as the stage's last instruction.
  spine.write(output, validation, foreground: colors.error);
  spine.hint(
    output,
    _textInputGuidance(linear: linear, instructions: instructions),
    foreground: colors.muted,
  );
}

String _colorText(
  String text,
  TerminalColor foreground,
  TerminalColor background,
  OutputProfile? profile,
) {
  if (profile == null) return text;
  return terminalStyledText(
    text,
    foreground: foreground,
    background: background,
    depth: profile.colorDepth,
  );
}

bool _terminalActive = false;

Future<T> _restoreAfter<T>(
  Future<T> Function() operation,
  void Function() restore,
) async {
  try {
    final result = await operation();
    restore();
    return result;
  } catch (operationError, operationStackTrace) {
    try {
      restore();
    } catch (restorationError) {
      throw TerminalRestorationException(operationError, restorationError);
    }
    Error.throwWithStackTrace(operationError, operationStackTrace);
  }
}

/// Repaints one transcript-style rich prompt when the selected output resizes.
///
/// The caller keeps its own effective profile: [onGeometry] receives the
/// observed dimensions so subsequent guidance is wrapped for the new width.
/// A resize is a repaint only, so it neither edits a draft nor records a
/// presentation occurrence. Help owns the screen until it is dismissed, and a
/// failed repaint retires the watcher and ends the prompt with the original
/// failure instead of retrying a dead writer on every notification or poll.
///
/// Returns the callback that stops observation; every supported exit must call
/// it so the notification subscription and fallback timer are released.
void Function() _watchIdleResize({
  required TerminalResizeObserver? observer,
  required OutputProfile Function() profile,
  required void Function(OutputProfile) onGeometry,
  required void Function() repaint,
  required _Keys keys,
  required bool Function() helpOpen,
}) {
  if (observer == null) return () {};
  StreamSubscription<void>? subscription;
  Timer? fallback;
  var stopped = false;

  void stop() {
    if (stopped) return;
    stopped = true;
    fallback?.cancel();
    fallback = null;
    final active = subscription;
    subscription = null;
    if (active != null) unawaited(active.cancel());
  }

  void observe() {
    if (stopped) return;
    final ({int columns, int rows})? dimensions;
    try {
      dimensions = observer.readDimensions();
    } catch (_) {
      // Reading geometry is best-effort; keep the last known layout.
      return;
    }
    if (dimensions == null || dimensions.columns <= 0 || dimensions.rows <= 0) {
      return;
    }
    final current = profile();
    final old = current.geometry;
    if (!old.isAutomatic &&
        old.columns == dimensions.columns &&
        old.rows == dimensions.rows) {
      return;
    }
    onGeometry(
      OutputProfile(
        cursor: current.cursor,
        alternateScreen: current.alternateScreen,
        styles: current.styles,
        colorDepth: current.colorDepth,
        glyphs: current.glyphs,
        geometry: OutputGeometry.fixed(
          columns: dimensions.columns,
          rows: dimensions.rows,
        ),
        ambiguousWidth: current.ambiguousWidth,
      ),
    );
    if (helpOpen()) return;
    try {
      repaint();
    } catch (error, stackTrace) {
      stop();
      keys.fail(error, stackTrace);
    }
  }

  subscription = observer.notifications.listen(
    (_) => observe(),
    onError: (_, _) {},
  );
  final milliseconds = observer.fallbackInterval.inMilliseconds.clamp(
    100,
    30000,
  );
  fallback = Timer.periodic(
    Duration(milliseconds: milliseconds),
    (_) => observe(),
  );
  return stop;
}

final class TextInput {
  TextInput(
    String label, {
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorTheme colors = ColorThemes.terminalDefault,
    PromptStructure structure = PromptStructure.plain,
  }) : this._(
         label,
         initialValue: initialValue,
         required: required,
         validate: validate,
         maxLength: maxLength,
         instructions: instructions,
         supplementaryHelp: supplementaryHelp,
         colors: colors,
         structure: structure,
       );

  TextInput._(
    this.label, {
    this.initialValue = '',
    this.required = false,
    this.validate,
    this.maxLength,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this._onChanged,
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (maxLength != null && maxLength! < 0) {
      throw ArgumentError.value(maxLength, 'maxLength');
    }
    if (initialValue.runes.any((c) => c < 32 || c == 127) ||
        (maxLength != null && initialValue.characters.length > maxLength!)) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }
  final String label;
  final String initialValue;
  final bool required;
  final int? maxLength;
  final String? Function(String)? validate;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;

  /// Complete palette for this prompt; it never alters global terminal state.
  final ColorTheme colors;

  /// Structural grammar used to frame the prompt.
  final PromptStructure structure;
  final void Function(String)? _onChanged;
  bool _active = false;
  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      return session._promptRunner(
        _run,
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
      );
    }
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          if (terminal != null) {
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => _run(
                ScriptedInput(
                  terminal.input,
                  terminal.output,
                  supportsRich: terminal.supportsRich,
                  outputProfile: _terminalOutputProfile(terminal),
                  hardColorDisabled:
                      terminal.environment['NO_COLOR']?.isNotEmpty == true,
                  resizeObserver: _terminalResizeObserver(terminal),
                ),
                selected,
                outputProfile: outputProfile,
              ),
              lease.restore,
            );
          }
          return await _terminal<String>(
            selected,
            output ?? stderr,
            (source, mode, _) =>
                _run(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<String>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final value = source.value;
      if ((required && value.isEmpty) ||
          value.contains('\r') ||
          value.contains('\n') ||
          (maxLength != null && value.characters.length > maxLength!)) {
        return Unavailable(
          'Supplied answer does not satisfy text constraints.',
        );
      }
      final error = validate?.call(value);
      if (error != null) return Unavailable(error);
      return Accepted(value);
    }
    final scripted = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    _renderTextInputOpening(
      scripted.output,
      label,
      required: required,
      maxLength: maxLength,
      linear: mode == PromptMode.linear,
      instructions: instructions,
      outputProfile: effectiveProfile,
      colors: colors,
      structure: structure,
    );
    scripted.transcript?._event(
      TextInputPresentationEventKind.opened,
      text: label,
    );
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    var value = initialValue;
    try {
      while (true) {
        final result = await _edit(
          inputKeys,
          value,
          scripted.output,
          linear: mode == PromptMode.linear,
          sequential:
              mode != PromptMode.rich &&
              !effectiveProfile.supportsRichInteraction,
          transientHelp:
              effectiveProfile.alternateScreen == CapabilitySupport.supported,
          maxLength: maxLength,
          required: required,
          supplementaryHelp: supplementaryHelp,
          onChanged: _onChanged,
          transcript: scripted.transcript,
          outputProfile: effectiveProfile,
          colors: colors,
          structure: structure,
          resizeObserver: mode == PromptMode.rich
              ? scripted.resizeObserver
              : null,
          session: session,
        );
        if (result.action == 'cancel') {
          scripted.transcript?._event(TextInputPresentationEventKind.cancelled);
          return Cancelled();
        }
        if (result.action == 'interrupt') {
          scripted.transcript?._event(
            TextInputPresentationEventKind.interrupted,
          );
          return Interrupted();
        }
        if (result.action != 'submit') {
          scripted.transcript?._event(
            TextInputPresentationEventKind.inputEnded,
          );
          return InputEnded();
        }
        value = result.value;
        if (required && value.isEmpty) {
          const message = 'Required: enter a non-empty value and submit again.';
          _renderTextInputValidation(
            scripted.output,
            message,
            linear: mode == PromptMode.linear,
            instructions: instructions,
            outputProfile: effectiveProfile,
            colors: colors,
            structure: structure,
          );
          scripted.transcript?._event(
            TextInputPresentationEventKind.validation,
            text: message,
          );
          continue;
        }
        final error = validate?.call(value);
        if (error != null) {
          _renderTextInputValidation(
            scripted.output,
            error,
            linear: mode == PromptMode.linear,
            instructions: instructions,
            outputProfile: effectiveProfile,
            colors: colors,
            structure: structure,
          );
          scripted.transcript?._event(
            TextInputPresentationEventKind.validation,
            text: error,
          );
          continue;
        }
        return Accepted(value);
      }
    } finally {
      if (keys == null) await inputKeys.close();
    }
  }
}

Future<({String action, String value})> _edit(
  _Keys keys,
  String initial,
  StringSink output, {
  bool linear = false,
  bool sequential = false,
  bool transientHelp = false,
  bool secret = false,
  bool mask = false,
  bool clearHelpCommand = false,
  bool allowCommandPrefixes = false,
  int? maxLength,
  bool required = false,
  List<String> supplementaryHelp = const [],
  String? helpText,
  String? linearHelpText,
  String Function()? liveHelpText,
  String Function()? liveLinearHelpText,
  String? Function(String key, String text)? intercept,
  void Function(String text)? onChanged,
  void Function()? onHelpDismissed,
  void Function(bool visible)? onHelpVisibilityChanged,
  TextInputTranscript? transcript,
  OutputProfile? outputProfile,
  ColorTheme colors = ColorThemes.terminalDefault,
  PromptStructure structure = PromptStructure.plain,
  TerminalResizeObserver? resizeObserver,
  TerminalSession? session,
  void Function(bool literal)? onSubmit,
  int? pasteMaxLength,
  Set<String> extraCommands = const {},
  bool multilinePaste = false,
}) async {
  var chars = initial.characters.toList();
  var pos = chars.length;
  var provenance = List<bool>.filled(chars.length, false, growable: true);
  var synthetic = -1;
  if (linear &&
      (initial == '/cancel' ||
          initial == '/help' ||
          extraCommands.contains(initial) ||
          initial.startsWith('\\'))) {
    chars.insert(0, '\\');
    provenance.insert(0, false);
    pos++;
    synthetic = 0;
  }
  var activeProfile = outputProfile;

  /// Writes one editor event through the component's structural grammar.
  ///
  /// Editor notices, help and sequential reports are deliberate events inside
  /// the current stage, so they keep the structure's continuation vocabulary
  /// rather than opening a new frame or dumping the whole view again. [compact]
  /// marks a repeated event such as a notice or a caret report: a prefixed
  /// structure renders it exactly as before, while an enclosure keeps it outside
  /// a frame so a keystroke does not draw a new enclosure.
  void writeEvent(String text, {bool closes = false, bool compact = false}) {
    final profile = activeProfile;
    _StructureSpine(
      structure: structure,
      ascii: _structureAscii(profile),
      width: profile == null ? null : _textInputWidth(profile),
      background: colors.background,
      border: colors.border,
      outputProfile: profile,
    ).write(
      output,
      text,
      foreground: colors.muted,
      closes: closes,
      compact: compact,
    );
  }

  void notice(String text) {
    if (!sequential && !secret) output.writeln();
    writeEvent(text, closes: true, compact: true);
  }

  /// Ends the editable row that the rich renderer leaves current.
  ///
  /// A rich editor paints `> draft` and parks the physical caret on that row,
  /// so anything written next would start at the caret and overwrite the draft.
  /// A block that owns painting (help) therefore clears the row first; when it
  /// releases painting, dismissal repaints the current draft and caret once
  /// instead of leaving a stale copy of the draft above the repaint.
  ///
  /// Sequential rendering has already ended its report lines, and a private
  /// entry never exposes a draft row to terminate.
  void finishEditableRow() {
    if (sequential || secret) return;
    void clear() => output.write('\r\x1b[2K\n');
    final activeSession = session;
    if (activeSession == null) {
      clear();
    } else {
      activeSession._writeShared(clear);
    }
  }

  void insert(String data, bool isPaste) {
    final candidate = chars.take(pos).join() + data + chars.skip(pos).join();
    final count = candidate.characters.length - (synthetic >= 0 ? 1 : 0);
    final limit = isPaste ? (pasteMaxLength ?? maxLength) : maxLength;
    final commandPrefix =
        !isPaste &&
        (extraCommands.isNotEmpty || allowCommandPrefixes) &&
        ({'/help', '/cancel', ...extraCommands}).any(
          (command) =>
              command.startsWith(candidate) ||
              ('\\$command').startsWith(candidate),
        );
    if (limit != null && count > limit && !commandPrefix) {
      notice('Insertion rejected: character limit is $limit graphemes.');
      return;
    }
    final added = data.characters.toList();
    chars.insertAll(pos, added);
    if (synthetic >= pos) synthetic += added.length;
    provenance.insertAll(pos, List<bool>.filled(added.length, isPaste));
    pos += added.length;
    final caretOffset = chars.take(pos).join().length;
    final syntheticOffset = synthetic < 0
        ? -1
        : chars.take(synthetic).join().length;
    final flags = <bool>[];
    for (var i = 0; i < chars.length; i++) {
      flags.addAll(List<bool>.filled(chars[i].length, provenance[i]));
    }
    chars = chars.join().characters.toList();
    provenance = <bool>[];
    var offset = 0;
    pos = 0;
    synthetic = -1;
    for (var i = 0; i < chars.length; i++) {
      final end = offset + chars[i].length;
      provenance.add(flags.sublist(offset, end).contains(true));
      if (offset < caretOffset) pos = i + 1;
      if (syntheticOffset >= offset && syntheticOffset < end) synthetic = i;
      offset = end;
    }
  }

  void display() {
    void writePrompt(void Function() action) {
      final activeSession = session;
      if (activeSession == null) {
        action();
      } else {
        activeSession._writeShared(action);
      }
    }

    final profile = activeProfile;
    if (profile != null) session?._setPromptGeometry(profile.geometry);
    if (secret) {
      // Private entries never cross the recording/presentation boundary as
      // their draft, length, caret, or paste provenance. Masking is an
      // explicit length disclosure, but recordings still use a safe marker.
      transcript?._view(
        const TextInputCurrentView(
          text: '<private entry>',
          caret: 0,
          containsPaste: false,
        ),
      );
      if (mask) writePrompt(() => output.writeln('*' * chars.length));
      return;
    }
    transcript?._view(
      TextInputCurrentView(
        text: chars.join(),
        caret: pos,
        containsPaste: provenance.contains(true),
      ),
    );
    if (sequential) {
      writePrompt(() {
        final spine = _StructureSpine(
          structure: structure,
          ascii: _structureAscii(profile),
          width: profile == null ? null : _textInputWidth(profile),
          background: colors.background,
          border: colors.border,
          outputProfile: profile,
        );
        spine.write(
          output,
          'Current text: ${DisplayText.from(chars.join()).value}',
          foreground: colors.muted,
          compact: true,
        );
        spine.write(
          output,
          'Cursor position: $pos of ${chars.length} graphemes.',
          foreground: colors.muted,
          compact: true,
          closes: true,
        );
      });
      return;
    }
    final displayMap = TextDisplayMap(chars.join());
    var start = 0;
    var end = chars.length;
    final livePrefix = structureLivePrefix(
      structure,
      ascii: _structureAscii(profile),
    );
    final liveCells = TextDisplayMap(livePrefix).cellWidth;
    final totalWidth = profile == null ? null : _textInputWidth(profile);
    if (totalWidth != null) {
      // The live marker is structural chrome; each truthful overflow marker
      // consumes one cell too. Reserve the declared marker and both markers
      // while centring around the actual caret, then add only whole graphemes
      // from the display map, so the row lines up with the frame interior and
      // still fits the declared width.
      final budget = (totalWidth - liveCells - 2).clamp(
        0,
        _textInputTotalWidthCap,
      );
      int cells(int index) => displayMap.entries[index].cellWidth;
      var used = displayMap.caretCells(pos);
      while (start < pos && used > budget) {
        used -= cells(start++);
      }
      end = pos;
      while (end < chars.length && used + cells(end) <= budget) {
        used += cells(end++);
      }
    }
    final composition = _composeTextInput(
      TextInputPresentationContent(
        label: DisplayText.from(''),
        context: DisplayText.from(''),
        editable: TextInputEditableRegion(
          beforeCaret: DisplayText.from(displayMap.displayBetween(start, pos)),
          afterCaret: DisplayText.from(displayMap.displayBetween(pos, end)),
        ),
      ),
    );
    final editable = _slot(composition, PresentationSlot.body);
    writePrompt(() {
      output.write(
        '\r\x1b[2K$livePrefix${start > 0 ? '<' : ''}${_colorText(_renderEditableText(editable, beforeCaret: true), colors.foreground, colors.background, outputProfile)}\x1b[s${_colorText(_renderEditableText(editable, beforeCaret: false), colors.foreground, colors.background, outputProfile)}${end < chars.length ? '>' : ''}\x1b[u',
      );
    });
  }

  onChanged?.call(chars.join());
  display();
  session?._setPromptRepaint(display);
  var help = false;
  StreamSubscription<void>? resizeSubscription;
  Timer? resizeFallback;
  if (resizeObserver != null) {
    void stopResizeObservation() {
      resizeFallback?.cancel();
      resizeFallback = null;
      final subscription = resizeSubscription;
      resizeSubscription = null;
      if (subscription != null) unawaited(subscription.cancel());
    }

    void observeResize() {
      final ({int columns, int rows})? dimensions;
      try {
        dimensions = resizeObserver.readDimensions();
      } catch (_) {
        // Reading geometry is best-effort; retain the last known layout.
        return;
      }
      if (dimensions == null ||
          dimensions.columns <= 0 ||
          dimensions.rows <= 0) {
        return;
      }
      final old = activeProfile?.geometry;
      if (old != null &&
          !old.isAutomatic &&
          old.columns == dimensions.columns &&
          old.rows == dimensions.rows) {
        return;
      }
      final profile = activeProfile;
      if (profile == null) {
        return;
      }
      activeProfile = OutputProfile(
        cursor: profile.cursor,
        alternateScreen: profile.alternateScreen,
        styles: profile.styles,
        colorDepth: profile.colorDepth,
        glyphs: profile.glyphs,
        geometry: OutputGeometry.fixed(
          columns: dimensions.columns,
          rows: dimensions.rows,
        ),
        ambiguousWidth: profile.ambiguousWidth,
      );
      // A resize is a repaint only: it neither edits the draft nor records
      // a presentation occurrence. Help owns the screen until dismissed.
      if (help) return;
      try {
        display();
      } catch (error, stackTrace) {
        // A failed repaint is not a geometry observation fault: the session
        // has retired its shared writer. Stop watching and end the prompt with
        // the original failure instead of retrying a dead writer on every
        // notification or poll.
        stopResizeObservation();
        keys.fail(error, stackTrace);
      }
    }

    resizeSubscription = resizeObserver.notifications.listen(
      (_) => observeResize(),
      onError: (_, _) {},
    );
    final milliseconds = resizeObserver.fallbackInterval.inMilliseconds.clamp(
      100,
      30000,
    );
    resizeFallback = Timer.periodic(Duration(milliseconds: milliseconds), (_) {
      observeResize();
    });
  }
  try {
    while (true) {
      final key = await keys.next();
      if (key == null || key == '\x1a') return (action: 'eof', value: '');
      if (key == '\x03') return (action: 'interrupt', value: '');
      if (!help) {
        final action = intercept?.call(key, chars.join());
        if (action == 'handled') {
          display();
          continue;
        }
        if (action != null) return (action: action, value: chars.join());
      }
      if (key == '\x1b') {
        if (!help) return (action: 'cancel', value: '');
        help = false;
        onHelpVisibilityChanged?.call(false);
        if (session != null) {
          session._dismissModalHelp(
            showTranscriptDismissal: !transientHelp,
            repaintPrompt: display,
          );
        } else if (transientHelp) {
          output.write('\x1b[?1049l');
        } else {
          output.writeln('Help dismissed.');
          display();
        }
        if (onHelpDismissed != null) {
          onHelpDismissed();
          display();
        }
        continue;
      }
      if (key == '\x14') {
        if (help) continue;
        help = true;
        onHelpVisibilityChanged?.call(true);
        if (session != null) {
          // The session decides whether help owns an alternate screen or the
          // transcript; only the transcript path leaves the draft row visible.
          session._openModalHelp(useAlternateScreen: transientHelp);
          if (!transientHelp) finishEditableRow();
        } else if (transientHelp) {
          output.write('\x1b[?1049h\x1b[H');
        } else {
          finishEditableRow();
        }
        writeEvent(
          liveHelpText?.call() ??
              helpText ??
              _textInputHelp(
                linear: false,
                required: required,
                maxLength: maxLength,
                supplementaryHelp: supplementaryHelp,
              ),
          closes: true,
        );
        transcript?._event(TextInputPresentationEventKind.help);
        continue;
      }
      if (help) continue;
      if (key == '\r' || key == '\n') {
        if (linear && !sequential && !secret) {
          final promptPrefix = structureLivePrefix(
            structure,
            ascii: _structureAscii(outputProfile),
          );
          output.write(
            '\r\x1b[2K$promptPrefix${DisplayText.from(chars.join()).value}',
          );
        }
        output.writeln();
        var text = chars.join();
        final literal =
            synthetic >= 0 ||
            provenance.contains(true) ||
            (linear &&
                (text.startsWith(r'\\') ||
                    (text.startsWith(r'\') &&
                        {
                          '/cancel',
                          '/help',
                          ...extraCommands,
                        }.contains(text.substring(1)))));
        if (synthetic >= 0) {
          final answer = chars.toList();
          answer[synthetic] = answer[synthetic].substring(1);
          text = answer.join();
        } else if (linear && !provenance.contains(true)) {
          if (text == '/help') {
            // Component help is evaluated when help is requested, so an
            // asynchronous stage or state that changed since the editor
            // opened is described truthfully instead of from a stale string.
            final componentHelp = liveLinearHelpText?.call() ?? linearHelpText;
            if (componentHelp != null) {
              // A component that supplies its own command-aware help keeps that
              // content; the exact command spellings are appended rather than
              // replacing it with the generic command list.
              writeEvent(
                extraCommands.isEmpty
                    ? componentHelp
                    : '$componentHelp Exact commands: ${extraCommands.join(', ')}, /help and /cancel. Quote a command with a backslash; double a leading backslash.',
                closes: true,
              );
              transcript?._event(TextInputPresentationEventKind.help);
            } else if (extraCommands.isNotEmpty) {
              writeEvent(
                'Help: ${extraCommands.join(', ')}, /help and /cancel are exact commands. Quote a command with a backslash; double a leading backslash. Identified paste is literal; unframed paste cannot be distinguished from typing.',
                closes: true,
              );
            } else {
              writeEvent(
                _textInputHelp(
                  linear: true,
                  required: required,
                  maxLength: maxLength,
                  supplementaryHelp: supplementaryHelp,
                ),
                closes: true,
              );
              transcript?._event(TextInputPresentationEventKind.help);
            }
            if (clearHelpCommand || extraCommands.isNotEmpty) {
              chars.clear();
              provenance.clear();
              pos = 0;
            }
            display();
            continue;
          }
          if (text == '/cancel') return (action: 'cancel', value: '');
          if (extraCommands.contains(text)) {
            return (action: 'command', value: text);
          }
          if (text.startsWith(r'\\') ||
              (text.startsWith(r'\') &&
                  ({
                    '/cancel',
                    '/help',
                    ...extraCommands,
                  }).contains(text.substring(1)))) {
            text = text.substring(1);
          }
        }
        onSubmit?.call(literal);
        transcript?._event(
          TextInputPresentationEventKind.submitted,
          text: secret ? null : text,
          isLiteral: secret ? false : literal,
          containsPaste: secret ? false : provenance.contains(true),
        );
        return (action: 'submit', value: text);
      }
      if (key == '\x1b[D') {
        if (pos > 0) pos--;
      } else if (key == '\x1b[C') {
        if (pos < chars.length) pos++;
      } else if (key == '\x1b[H' || key == '\x01') {
        pos = 0;
      } else if (key == '\x1b[F' || key == '\x05') {
        pos = chars.length;
      } else if (key == '\x7f' || key == '\x08') {
        if (pos > 0) {
          pos--;
          chars.removeAt(pos);
          provenance.removeAt(pos);
          if (pos == synthetic) {
            synthetic = -1;
          } else if (pos < synthetic) {
            synthetic--;
          }
        }
      } else if (key == '\x1b[3~') {
        if (pos < chars.length) {
          chars.removeAt(pos);
          provenance.removeAt(pos);
          if (pos == synthetic) {
            synthetic = -1;
          } else if (pos < synthetic) {
            synthetic--;
          }
        }
      } else if (key == '\x1b[999~') {
        notice('Paste rejected: exceeds 4096 UTF-16 code units.');
      } else if (key.startsWith('\x1b[200~')) {
        var data = key.substring(6, key.length - 6);
        if (multilinePaste) {
          data = data.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        }
        if (data.runes.any(
          (r) =>
              (r < 32 && !(multilinePaste && (r == 9 || r == 10))) || r == 127,
        )) {
          notice('Paste rejected: single-line printable text only.');
          display();
          continue;
        }
        insert(data, true);
      } else if (!key.startsWith('\x1b') && key.codeUnitAt(0) >= 32) {
        insert(key, false);
      }
      if (onChanged != null && !sequential && !secret) output.writeln();
      onChanged?.call(chars.join());
      display();
    }
  } finally {
    if (session != null) session._setPromptRepaint(null);
    resizeFallback?.cancel();
    await resizeSubscription?.cancel();
    if (help) {
      if (session != null) {
        session._abortModalHelp();
      } else if (transientHelp) {
        output.write('\x1b[?1049l');
      }
    }
  }
}

class _Keys {
  final _controller = StreamController<String>();
  late final StreamSubscription<String> _subscription;
  late final StreamIterator<String> _iterator;
  bool Function(String)? onKey;
  Object? _failure;
  void _emit(String key) {
    if (!(onKey?.call(key) ?? false)) _controller.add(key);
  }

  String _buffer = '';
  bool _discardPaste = false;
  bool _afterCarriageReturn = false;
  Timer? _timer;
  _Keys(Stream<List<int>> source, {bool flushEscapeOnEnd = false}) {
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
            if (flushEscapeOnEnd && _buffer == '\x1b') {
              _emit('\x1b');
              _buffer = '';
            }
            _controller.close();
          },
        );
  }
  void _parse() {
    _timer?.cancel();
    while (_buffer.isNotEmpty) {
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
        if (_buffer == '\x1b' ||
            _buffer == '\x1bO' ||
            _buffer.startsWith('\x1b[')) {
          _timer = Timer(const Duration(milliseconds: 80), () {
            _emit('\x1b');
            _buffer = _buffer.substring(1);
            _parse();
          });
          return;
        }
      }
      final rune = _buffer.runes.first;
      final s = String.fromCharCode(rune);
      _emit(s);
      _buffer = _buffer.substring(s.length);
    }
  }

  Future<String?> next() async {
    while (await _iterator.moveNext()) {
      final key = _iterator.current;
      if (_afterCarriageReturn && key == '\n') {
        _afterCarriageReturn = false;
        continue;
      }
      _afterCarriageReturn = key == '\r';
      return key;
    }
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
    await _subscription.cancel();
    await _iterator.cancel();
  }
}

class _Console {
  final _dll = DynamicLibrary.open('kernel32.dll');
  late final int Function(int) getHandle = _dll
      .lookupFunction<IntPtr Function(Int32), int Function(int)>(
        'GetStdHandle',
      );
  late final int Function(int, Pointer<Uint32>) getMode = _dll
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetConsoleMode');
  late final int Function(int, Pointer<Uint32>) numberOfEvents = _dll
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetNumberOfConsoleInputEvents');
  late final int Function(int, Pointer<Uint8>, int, Pointer<Uint32>) readInput =
      _dll.lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>),
        int Function(int, Pointer<Uint8>, int, Pointer<Uint32>)
      >('ReadConsoleInputW');
  late final int Function(int, int) setMode = _dll
      .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'SetConsoleMode',
      );
}

// Read from the already-authorized console handle without subscribing to stdin:
// cancelling Dart's stdin subscription closes the process handle on Windows.
final class _CaptureControl {
  bool armed = false;
}

Stream<String> _consoleInput(
  _Console console,
  int handle, [
  _CaptureControl? capture,
]) {
  late StreamController<String> controller;
  Timer? timer;
  StreamSubscription<ProcessSignal>? signals;
  int? highSurrogate;
  final held = <int>{};
  final count = calloc<Uint32>();
  final read = calloc<Uint32>();
  final records = calloc<Uint8>(20 * 64);
  void poll(Timer _) {
    if (console.numberOfEvents(handle, count) == 0) {
      controller.addError(StateError('Cannot inspect console input.'));
      return;
    }
    final available = count.value.clamp(0, 1);
    if (available == 0) return;
    if (console.readInput(handle, records, available, read) == 0) {
      controller.addError(StateError('Cannot read console input.'));
      return;
    }
    final bytes = ByteData.sublistView(records.asTypedList(20 * read.value));
    for (var i = 0; i < read.value; i++) {
      final base = i * 20;
      if (bytes.getUint16(base, Endian.little) != 1) continue;
      final vk = bytes.getUint16(base + 10, Endian.little);
      if (bytes.getInt32(base + 4, Endian.little) == 0) {
        held.remove(vk);
        continue;
      }
      final firstDown = held.add(vk);
      final code = bytes.getUint16(base + 14, Endian.little);
      final state =
          bytes.getUint32(base + 16, Endian.little) |
          (held.contains(0x5b) || held.contains(0x5c) ? 0x1000000 : 0);
      if (capture != null && !firstDown) continue;
      if (capture != null &&
          ((vk == 0x43 && (state & 0x0c) != 0) || code == 3)) {
        controller.add('\x03');
        continue;
      }
      if (capture?.armed == true) {
        if (vk == 0x10 ||
            vk == 0x11 ||
            vk == 0x12 ||
            vk == 0x5b ||
            vk == 0x5c) {
          continue;
        }
        capture!.armed = false;
        if (vk == 0x1b) {
          controller.add('\x1b');
        } else {
          controller.add('\x1b[901;$vk;$code;$state~');
        }
        continue;
      }
      if (code >= 0xd800 && code <= 0xdbff) {
        highSurrogate = code;
        continue;
      }
      if (highSurrogate != null && code >= 0xdc00 && code <= 0xdfff) {
        controller.add(String.fromCharCodes([highSurrogate!, code]));
        highSurrogate = null;
        continue;
      }
      if (highSurrogate != null) {
        controller.add('\ufffd');
        highSurrogate = null;
      }
      final key = code != 0
          ? String.fromCharCode(code)
          : switch (vk) {
              0x25 => '\x1b[D',
              0x26 => '\x1b[A',
              0x27 => '\x1b[C',
              0x28 => '\x1b[B',
              0x24 => '\x1b[H',
              0x23 => '\x1b[F',
              0x2e => '\x1b[3~',
              _ => '',
            };
      if (key.isNotEmpty) controller.add(key);
    }
  }

  controller = StreamController<String>(
    onListen: () {
      signals = ProcessSignal.sigint.watch().listen(
        (_) => controller.add('\x03'),
      );
      timer = Timer.periodic(const Duration(milliseconds: 5), poll);
    },
    onCancel: () async {
      timer?.cancel();
      await signals?.cancel();
      calloc.free(count);
      calloc.free(read);
      calloc.free(records);
    },
  );
  return controller.stream;
}

// Use the authorized terminal descriptor directly so cancelling one session
// does not close Dart's process-wide stdin stream before the next session.
Stream<String> _posixInput() {
  final libc = DynamicLibrary.process();
  final poll = libc
      .lookupFunction<
        Int32 Function(Pointer<Void>, UintPtr, Int32),
        int Function(Pointer<Void>, int, int)
      >('poll');
  final read = libc
      .lookupFunction<
        IntPtr Function(Int32, Pointer<Uint8>, UintPtr),
        int Function(int, Pointer<Uint8>, int)
      >('read');
  final descriptor = calloc<Uint8>(8);
  final data = ByteData.sublistView(descriptor.asTypedList(8));
  data.setInt32(0, 0, Endian.host);
  data.setInt16(4, 1, Endian.host); // POLLIN
  final buffer = calloc<Uint8>(4096);
  Timer? timer;
  StreamSubscription<ProcessSignal>? signals;
  late StreamController<List<int>> controller;
  controller = StreamController<List<int>>(
    onListen: () {
      signals = ProcessSignal.sigint.watch().listen((_) {
        if (!controller.isClosed) controller.add([3]);
      });
      timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
        final ready = poll(descriptor.cast(), 1, 0);
        if (ready < 0) {
          controller.addError(StateError('Cannot poll terminal input.'));
          timer?.cancel();
        } else if (ready > 0) {
          final count = read(0, buffer, 4096);
          if (count < 0) {
            controller.addError(StateError('Cannot read terminal input.'));
            timer?.cancel();
          } else if (count == 0) {
            timer?.cancel();
            controller.close();
          } else {
            // Ctrl+D in raw mode is the conventional terminal EOF gesture.
            controller.add([
              for (final byte in buffer.asTypedList(count))
                byte == 4 ? 26 : byte,
            ]);
          }
        }
      });
    },
    onCancel: () async {
      timer?.cancel();
      await signals?.cancel();
      calloc.free(descriptor);
      calloc.free(buffer);
    },
  );
  return controller.stream.transform(utf8.decoder);
}

OutputProfile _nativeOutputProfile(Stdout output, bool supportsRich) {
  OutputGeometry geometry = const OutputGeometry.automatic();
  if (output.hasTerminal) {
    try {
      final columns = output.terminalColumns;
      final rows = output.terminalLines;
      if (columns > 0 && rows > 0) {
        geometry = OutputGeometry.fixed(columns: columns, rows: rows);
      }
    } on FileSystemException {
      // Capability probing is fallible; geometry remains unknown.
    } on UnsupportedError {
      // Capability probing is fallible; geometry remains unknown.
    }
  }
  final term = Platform.environment['TERM'] ?? '';
  return OutputProfile(
    cursor: supportsRich
        ? CapabilitySupport.supported
        : CapabilitySupport.unsupported,
    alternateScreen:
        supportsRich &&
            (Platform.isWindows ||
                RegExp(r'^(xterm|screen|tmux|rxvt)(-|$)').hasMatch(term))
        ? CapabilitySupport.supported
        : CapabilitySupport.unsupported,
    geometry: geometry,
  );
}

Future<PromptResult<T>> _posixTerminal<T>(
  PromptMode mode,
  Stdout outputStream,
  Future<PromptResult<T>> Function(ScriptedInput, PromptMode, void Function())
  run,
) async {
  final capable =
      outputStream.hasTerminal && Platform.environment['TERM'] != 'dumb';
  final rich =
      mode == PromptMode.rich || (mode == PromptMode.automatic && capable);
  if (rich && !capable) {
    return Unavailable(
      'Rich interaction unavailable on the selected output; use linear or automatic mode.',
    );
  }
  final libc = DynamicLibrary.process();
  final get = libc
      .lookupFunction<
        Int32 Function(Int32, Pointer<Void>),
        int Function(int, Pointer<Void>)
      >('tcgetattr');
  final set = libc
      .lookupFunction<
        Int32 Function(Int32, Int32, Pointer<Void>),
        int Function(int, int, Pointer<Void>)
      >('tcsetattr');
  final makeRaw = libc
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('cfmakeraw');
  // termios is platform-specific; reserve more than its size on both supported
  // POSIX platforms and let libc interpret the opaque storage.
  final original = calloc<Uint64>(64);
  final raw = calloc<Uint64>(64);
  var acquired = false;
  var pasteEnabled = false;
  void restore() {
    try {
      if (pasteEnabled) {
        pasteEnabled = false;
        outputStream.write('\x1b[?2004l\n');
      }
    } finally {
      if (acquired) {
        acquired = false;
        if (set(0, 0, original.cast()) != 0) {
          throw StateError('Cannot restore terminal input.');
        }
      }
    }
  }

  try {
    if (get(0, original.cast()) != 0 || get(0, raw.cast()) != 0) {
      return Unavailable('Terminal capability unavailable.');
    }
    makeRaw(raw.cast());
    if (set(0, 0, raw.cast()) != 0) {
      return Unavailable('Cannot acquire terminal input.');
    }
    acquired = true;
    if (rich) {
      outputStream.write('\x1b[?2004h');
      pasteEnabled = true;
    }
    final profile = _nativeOutputProfile(outputStream, capable);
    return await _restoreAfter(
      () => run(
        ScriptedInput(
          _posixInput(),
          outputStream,
          supportsRich: capable,
          outputProfile: profile,
          observedGeometry: profile.geometry,
          resizeObserver: nativeConsoleResizeObserver(outputStream),
          hardColorDisabled:
              !outputStream.hasTerminal ||
              Platform.environment['NO_COLOR']?.isNotEmpty == true,
        ),
        rich ? PromptMode.rich : PromptMode.linear,
        restore,
      ),
      restore,
    );
  } finally {
    try {
      restore();
    } finally {
      calloc.free(original);
      calloc.free(raw);
    }
  }
}

Future<PromptResult<T>> _terminal<T>(
  PromptMode mode,
  Stdout outputStream,
  Future<PromptResult<T>> Function(ScriptedInput, PromptMode, void Function())
  run, {
  _CaptureControl? capture,
}) async {
  if (!stdin.hasTerminal) {
    return Unavailable(
      'Interactive console input is unavailable; supply an explicit input source.',
    );
  }
  if (Platform.isLinux || Platform.isMacOS) {
    return _posixTerminal(mode, outputStream, run);
  }
  if (!Platform.isWindows) {
    return Unavailable(
      'Interactive console input is unavailable on this platform.',
    );
  }
  var capable =
      outputStream.hasTerminal && Platform.environment['TERM'] != 'dumb';
  var rich =
      mode == PromptMode.rich || (mode == PromptMode.automatic && capable);
  if (rich && !capable) {
    return Unavailable(
      'Rich interaction unavailable on the selected output; use linear or automatic mode.',
    );
  }
  final console = _Console();
  final input = console.getHandle(-10);
  final output = console.getHandle(identical(outputStream, stdout) ? -11 : -12);
  final inputMode = calloc<Uint32>();
  final outputMode = calloc<Uint32>();
  var inputAcquired = false;
  var outputAcquired = false;
  void restore() {
    try {
      if (outputAcquired) {
        outputAcquired = false;
        try {
          outputStream.write('\x1b[?2004l\n');
        } finally {
          if (console.setMode(output, outputMode.value) == 0) {
            throw StateError('Cannot restore console output.');
          }
        }
      }
    } finally {
      if (inputAcquired) {
        inputAcquired = false;
        if (console.setMode(input, inputMode.value) == 0) {
          throw StateError('Cannot restore console input.');
        }
      }
    }
  }

  try {
    if (console.getMode(input, inputMode) == 0) {
      return Unavailable('Console capability unavailable.');
    }
    if (console.setMode(input, inputMode.value & ~0x207) == 0) {
      return Unavailable('Cannot acquire console input.');
    }
    inputAcquired = true;
    if (capable) {
      if (console.getMode(output, outputMode) == 0 ||
          console.setMode(output, outputMode.value | 4) == 0) {
        if (mode == PromptMode.rich) {
          return Unavailable('Cannot enable terminal cursor addressing.');
        }
        capable = false;
        rich = false;
      } else {
        outputAcquired = true;
        // ConPTY strips bracketed-paste markers unless VT input is enabled.
        // Gesture capture still needs native virtual-key and modifier records.
        if (capture == null) {
          // If unsupported, retain native input and the unframed-paste grammar.
          console.setMode(input, (inputMode.value & ~0x207) | 0x200);
        }
        outputStream.write('\x1b[?2004h');
      }
    }
    final profile = _nativeOutputProfile(outputStream, capable);
    return await _restoreAfter(
      () => run(
        ScriptedInput(
          _consoleInput(console, input, capture),
          outputStream,
          supportsRich: capable,
          outputProfile: profile,
          observedGeometry: profile.geometry,
          resizeObserver: nativeConsoleResizeObserver(outputStream),
          hardColorDisabled:
              !outputStream.hasTerminal ||
              Platform.environment['NO_COLOR']?.isNotEmpty == true,
        ),
        rich ? PromptMode.rich : PromptMode.linear,
        restore,
      ),
      restore,
    );
  } finally {
    try {
      restore();
    } finally {
      calloc.free(inputMode);
      calloc.free(outputMode);
    }
  }
}

/// A secret prompt. Masking discloses the secret's length; prefill retains a
/// caller-provided secret in memory. Terminal and screen-reader echo behavior
/// requires independent verification.
final class Password {
  Password(
    this.label, {
    this.initialValue = '',
    this.mask = false,
    this.required = false,
    this.validate,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (initialValue.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError('Invalid secret prefill.');
    }
  }
  final String label;
  final String initialValue;
  final bool mask;
  final bool required;
  final String? Function(String)? validate;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  bool _active = false;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      try {
        return await session._promptRunner(
          _run,
          source: source,
          mode: mode,
          userPreference: userPreference,
          applicationPreference: applicationPreference,
          output: output,
          terminal: terminal,
          outputProfile: outputProfile,
        );
      } on _SecretValidationException {
        return Unavailable('Secret validation failed.');
      }
    }
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          if (terminal != null) {
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => _run(
                ScriptedInput(
                  terminal.input,
                  terminal.output,
                  supportsRich: terminal.supportsRich,
                  outputProfile: _terminalOutputProfile(terminal),
                  hardColorDisabled:
                      terminal.environment['NO_COLOR']?.isNotEmpty == true,
                  resizeObserver: _terminalResizeObserver(terminal),
                ),
                selected,
                outputProfile: outputProfile,
              ),
              lease.restore,
            );
          }
          return await _terminal<String>(
            selected,
            output ?? stderr,
            (source, mode, _) =>
                _run(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, outputProfile: outputProfile);
    } on _SecretValidationException {
      return Unavailable('Secret validation failed.');
    } finally {
      _active = false;
    }
  }

  bool _validationFailed(String value) {
    try {
      return validate?.call(value) != null;
    } catch (_) {
      throw const _SecretValidationException();
    }
  }

  Future<PromptResult<String>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final value = source.value;
      if ((required && value.isEmpty) ||
          value.contains('\r') ||
          value.contains('\n') ||
          _validationFailed(value)) {
        return Unavailable('Secret does not satisfy the requirements.');
      }
      return Accepted(value);
    }
    final scripted = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    final width = _textInputWidth(effectiveProfile);
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: width,
      background: colors.background,
      border: colors.border,
    );
    void write(String text, TerminalColor foreground, {bool closes = false}) =>
        spine.write(
          scripted.output,
          text,
          foreground: foreground,
          closes: closes,
        );
    spine.opening(
      scripted.output,
      title: '$label (${required ? 'Required' : 'Optional'}).',
      body: 'Hidden entry; Enter opens actions. Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
      foreground: colors.foreground,
      bodyForeground: colors.muted,
      closes: !mask && initialValue.isEmpty,
    );
    if (mask) {
      write(
        'Masking is enabled and discloses length.',
        colors.muted,
        closes: initialValue.isEmpty,
      );
    }
    if (initialValue.isNotEmpty) {
      write(
        'Secret prefill is enabled; the secret is retained in memory.',
        colors.muted,
        closes: true,
      );
    }
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    var value = initialValue;
    try {
      while (true) {
        final edit = await _edit(
          inputKeys,
          value,
          scripted.output,
          sequential:
              mode != PromptMode.rich &&
              !effectiveProfile.supportsRichInteraction,
          secret: true,
          mask: mask,
          transientHelp:
              effectiveProfile.alternateScreen == CapabilitySupport.supported,
          transcript: scripted.transcript,
          outputProfile: effectiveProfile,
          structure: structure,
          resizeObserver: mode == PromptMode.rich
              ? scripted.resizeObserver
              : null,
          session: session,
          helpText: 'Help: Enter opens Password actions. Use the listed submit, edit, clear, help or cancel action after entry. Ctrl+T opens this help without treating secret text as a command.',
        );
        if (edit.action == 'cancel') return Cancelled();
        if (edit.action == 'interrupt') return Interrupted();
        if (edit.action != 'submit') return InputEnded();
        value = edit.value;
        while (true) {
          spine.hint(
            scripted.output,
            'Actions: submit, edit, clear, help, cancel. /help and /cancel are also available. Enter an action:',
            foreground: colors.foreground,
          );
          final action = await _edit(
            inputKeys,
            '',
            scripted.output,
            sequential:
                mode != PromptMode.rich &&
                !effectiveProfile.supportsRichInteraction,
            secret: true,
            transientHelp:
                effectiveProfile.alternateScreen == CapabilitySupport.supported,
            transcript: scripted.transcript,
            outputProfile: effectiveProfile,
            structure: structure,
            resizeObserver: mode == PromptMode.rich
                ? scripted.resizeObserver
                : null,
            session: session,
            helpText: 'Help: submit validates; edit reopens the secret; clear starts empty; cancel ends the prompt.',
          );
          if (action.action == 'cancel') return Cancelled();
          if (action.action == 'interrupt') return Interrupted();
          if (action.action != 'submit') return InputEnded();
          switch (action.value) {
            case 'submit':
              if ((required && value.isEmpty) || _validationFailed(value)) {
                write(
                  'Secret does not satisfy the requirements. Choose edit or clear and try again.',
                  colors.error,
                  closes: true,
                );
                continue;
              }
              return Accepted(value);
            case 'edit':
              break;
            case 'clear':
              value = '';
              break;
            case 'cancel':
            case '/cancel':
              return Cancelled();
            case 'help':
            case '/help':
              write(
                'Submit validates; edit reopens the secret; clear starts empty; cancel ends the prompt.',
                colors.muted,
                closes: true,
              );
              continue;
            default:
              write(
                'Choose one of the listed actions.',
                colors.warning,
                closes: true,
              );
              continue;
          }
          break;
        }
      }
    } finally {
      if (keys == null) await inputKeys.close();
    }
  }
}

final class _SecretValidationException implements Exception {
  const _SecretValidationException();
}

/// A Yes/No question whose draft is not submitted by a shortcut.
final class Confirm extends _BooleanPrompt {
  Confirm(
    super.label, {
    super.initialValue = false,
    super.colors = ColorThemes.terminalDefault,
    super.structure = PromptStructure.plain,
    super.instructions = InstructionDisplay.themeDefault,
    super.supplementaryHelp = const [],
  }) : super(kind: _BooleanKind.confirm);
}

final class Checkbox extends _BooleanPrompt {
  Checkbox(
    super.label, {
    super.initialValue = false,
    super.colors = ColorThemes.terminalDefault,
    super.structure = PromptStructure.plain,
    super.instructions = InstructionDisplay.themeDefault,
    super.supplementaryHelp = const [],
  }) : super(kind: _BooleanKind.checkbox);
}

final class Toggle extends _BooleanPrompt {
  Toggle(
    super.label, {
    super.initialValue = false,
    super.colors = ColorThemes.terminalDefault,
    super.structure = PromptStructure.plain,
    super.instructions = InstructionDisplay.themeDefault,
    super.supplementaryHelp = const [],
  }) : super(kind: _BooleanKind.toggle);
}

enum _BooleanKind { confirm, checkbox, toggle }

abstract class _BooleanPrompt {
  _BooleanPrompt(
    this.label, {
    required this.initialValue,
    required this.kind,
    required this.colors,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
  }
  final String label;
  final bool initialValue;
  final _BooleanKind kind;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  bool _active = false;

  Future<PromptResult<bool>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      return session._promptRunner<bool>(
        _run,
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
      );
    }
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          if (terminal != null) {
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => _run(
                ScriptedInput(
                  terminal.input,
                  terminal.output,
                  supportsRich: terminal.supportsRich,
                  outputProfile: _terminalOutputProfile(terminal),
                  hardColorDisabled:
                      terminal.environment['NO_COLOR']?.isNotEmpty == true,
                  resizeObserver: _terminalResizeObserver(terminal),
                ),
                selected,
                outputProfile: outputProfile,
              ),
              lease.restore,
            );
          }
          return await _terminal<bool>(
            selected,
            output ?? stderr,
            (source, mode, _) =>
                _run(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  String _state(bool value) => switch (kind) {
    _BooleanKind.confirm => value ? 'Yes' : 'No',
    _BooleanKind.checkbox => value ? 'checked' : 'unchecked',
    _BooleanKind.toggle => value ? 'on' : 'off',
  };

  String get _kindName => switch (kind) {
    _BooleanKind.confirm => 'Confirm',
    _BooleanKind.checkbox => 'Checkbox',
    _BooleanKind.toggle => 'Toggle',
  };

  String get _richControl => kind == _BooleanKind.confirm
      ? 'Y/N changes the draft'
      : 'Space toggles the draft';

  String _help({required bool linear}) {
    final defaultMeaning =
        'The displayed default is ${_state(initialValue)}; the current draft changes only when you use a control.';
    if (linear) {
      return 'Help: $_kindName accepts yes/y or no/n. An empty line submits the displayed default. Exact /help and /cancel are commands; quote commands with a backslash and double a leading backslash. Identified paste is literal. $defaultMeaning';
    }
    return 'Help: $_richControl; Enter submits. Escape dismisses help or cancels; Ctrl+C interrupts. $defaultMeaning';
  }

  bool? _parse(String value) => switch (value.toLowerCase()) {
    'yes' || 'y' => true,
    'no' || 'n' => false,
    _ => null,
  };

  Future<PromptResult<bool>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final value = _parse(source.value);
      return value == null ? Unavailable('Supply yes or no.') : Accepted(value);
    }
    final scripted = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    final out = scripted.output;
    final width = _textInputWidth(effectiveProfile);
    var draft = initialValue;

    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: width,
      background: colors.background,
      border: colors.border,
    );

    // Measure and escape application text before adding terminal controls;
    // otherwise the safety renderer would correctly spell the controls out as
    // visible text instead of applying this component-owned style.
    void writeStyled(
      String text,
      TerminalColor foreground, {
      bool closes = false,
    }) => spine.write(out, text, foreground: foreground, closes: closes);

    void renderDraft() =>
        writeStyled('Draft: ${_state(draft)}.', colors.accent);

    spine.opening(
      out,
      title: '$label.',
      body: 'Default: ${_state(initialValue)}. Draft: ${_state(draft)}.',
      foreground: colors.foreground,
      bodyForeground: colors.foreground,
    );
    spine.hint(
      out,
      mode == PromptMode.linear
          ? r'Enter yes/y or no/n, or an empty line for the displayed default. Exact /help and /cancel are commands; quote commands with a backslash and double a leading backslash. Identified paste is literal.'
          : '$_richControl; Enter submits. Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
      foreground: colors.muted,
    );
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    session?._setPromptRepaint(renderDraft);
    try {
      if (mode == PromptMode.linear) {
        var entry = '';
        while (true) {
          final result = await _edit(
            inputKeys,
            entry,
            out,
            linear: true,
            sequential: !effectiveProfile.supportsRichInteraction,
            clearHelpCommand: true,
            linearHelpText: _help(linear: true),
            outputProfile: effectiveProfile,
            structure: structure,
            session: session,
          );
          if (result.action == 'cancel') return Cancelled();
          if (result.action == 'interrupt') return Interrupted();
          if (result.action != 'submit') return InputEnded();
          entry = result.value;
          final answer = entry.isEmpty ? draft : _parse(entry);
          if (answer != null) {
            writeStyled('Accepted: ${_state(answer)}.', colors.success);
            return Accepted(answer);
          }
          writeStyled(
            'Enter yes/y or no/n, or erase the line and submit the displayed default.',
            colors.warning,
          );
        }
      }
      var help = false;
      while (true) {
        final key = await inputKeys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          writeStyled(
            'Help dismissed. Default: ${_state(initialValue)}. Draft: ${_state(draft)}.',
            colors.foreground,
          );
          continue;
        }
        if (key == '\x14') {
          if (help) continue;
          help = true;
          writeStyled(_help(linear: false), colors.foreground);
          continue;
        }
        if (help) continue;
        if (key == '\r' || key == '\n') {
          writeStyled('Accepted: ${_state(draft)}.', colors.success);
          return Accepted(draft);
        }
        if (kind == _BooleanKind.confirm &&
            (key == 'y' || key == 'Y' || key == 'n' || key == 'N')) {
          draft = key.toLowerCase() == 'y';
          renderDraft();
        } else if (kind != _BooleanKind.confirm && key == ' ') {
          draft = !draft;
          renderDraft();
        }
      }
    } finally {
      if (session != null) session._setPromptRepaint(null);
      if (keys == null) await inputKeys.close();
    }
  }
}

final class Multiline {
  Multiline(
    this.label, {
    this.initialValue = '',
    this.required = false,
    this.validate,
    this.maxLength,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (maxLength != null && maxLength! < 0) {
      throw ArgumentError.value(maxLength, 'maxLength');
    }
    if (maxLength != null &&
        _normalize(initialValue).characters.length > maxLength!) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }
  final String label;
  final String initialValue;
  final bool required;
  final String? Function(String)? validate;
  final int? maxLength;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  bool _active = false;
  static String _normalize(String value) =>
      value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  String? _error(String value) {
    if (required && value.isEmpty) return 'Required: enter a non-empty value.';
    if (maxLength != null && value.characters.length > maxLength!) {
      return 'Maximum $maxLength graphemes.';
    }
    return validate?.call(value);
  }

  ({String title, String guidance}) _openingParts({required bool linear}) => (
    title:
        '$label (${required ? 'Required' : 'Optional'}${maxLength == null ? '' : ', maximum $maxLength graphemes'}).',
    guidance: linear
        ? 'Enter a line; /list, /edit, /insert, /remove, /done, /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal; unframed paste cannot be distinguished from typing.'
        : 'Enter inserts a newline. Tab selects Finish or Insert tab; Enter activates the action. Arrows move, Home/End reach line boundaries, Backspace/Delete erase. Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
  );

  /// Current-stage help for this multiline answer.
  ///
  /// Both stages name the actions that actually accept or edit lines rather
  /// than generic text-submit wording, and keep the limits and caller
  /// validation reviewable.
  String _help({required bool linear}) {
    final constraints =
        '${required ? 'A value is required' : 'An empty value is allowed'}${maxLength == null ? '' : '; maximum $maxLength graphemes'}.';
    final validation = validate == null
        ? ''
        : ' Your validator runs when the lines are accepted.';
    if (linear) {
      return 'Help: one line per Enter; /list, /edit, /insert, /remove, /done, /help and /cancel are exact commands. Quote a command with a backslash; double a leading backslash. Identified paste is literal; unframed paste cannot be distinguished from typing. /done accepts the joined lines only after validation. $constraints$validation';
    }
    return 'Help: Enter inserts a newline; Tab selects Edit, Finish or Insert tab; Enter activates the selected action. Arrows move between lines; Home/End reach line boundaries; Backspace/Delete erase; identified paste keeps its line breaks and tabs. Ctrl+T opens this help; Escape returns to editing or cancels; Ctrl+C interrupts. Finish accepts the joined lines only after validation. $constraints$validation';
  }

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      return session._promptRunner<String>(
        _run,
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
      );
    }
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          if (terminal != null) {
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => _run(
                ScriptedInput(
                  terminal.input,
                  terminal.output,
                  supportsRich: terminal.supportsRich,
                  outputProfile: _terminalOutputProfile(terminal),
                  resizeObserver: _terminalResizeObserver(terminal),
                ),
                selected,
                outputProfile: outputProfile,
              ),
              lease.restore,
            );
          }
          return await _terminal<String>(
            selected,
            output ?? stderr,
            (source, mode, _) =>
                _run(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<String>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final value = _normalize(source.value);
      final error = _error(value);
      return error == null ? Accepted(value) : Unavailable(error);
    }
    final scripted = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    final out = scripted.output;
    final width = _textInputWidth(effectiveProfile);
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: width,
      background: colors.background,
      border: colors.border,
    );
    void write(String text, TerminalColor foreground, {bool closes = false}) =>
        spine.write(out, text, foreground: foreground, closes: closes);
    _writeStructureIntro(
      spine,
      out,
      parts: _openingParts(linear: mode == PromptMode.linear),
      foreground: colors.foreground,
    );
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    if (mode == PromptMode.linear) {
      final lines = initialValue.isEmpty
          ? <String>[]
          : _normalize(initialValue).split('\n');
      try {
        while (true) {
          final result = await _edit(
            inputKeys,
            '',
            out,
            linear: true,
            sequential: true,
            extraCommands: const {
              '/list',
              '/edit',
              '/insert',
              '/remove',
              '/done',
            },
            multilinePaste: true,
            outputProfile: effectiveProfile,
            structure: structure,
            session: session,
            linearHelpText: _help(linear: true),
            maxLength: maxLength == null
                ? null
                : (maxLength! -
                          (lines.isEmpty
                              ? 0
                              : lines.join('\n').characters.length + 1))
                      .clamp(0, maxLength!),
            pasteMaxLength: maxLength == null
                ? null
                : (maxLength! -
                          (lines.isEmpty
                              ? 0
                              : lines.join('\n').characters.length + 1))
                      .clamp(0, maxLength!),
          );
          if (result.action == 'cancel') return Cancelled();
          if (result.action == 'interrupt') return Interrupted();
          if (result.action != 'submit' && result.action != 'command') {
            return InputEnded();
          }
          if (result.action == 'submit') {
            lines.addAll(result.value.split('\n'));
            continue;
          }
          if (result.value == '/done') {
            final value = lines.join('\n');
            final error = _error(value);
            if (error == null) return Accepted(value);
            write(error, colors.error, closes: true);
            continue;
          }
          if (result.value == '/list') {
            for (var i = 0; i < lines.length; i++) {
              write(
                '${i + 1}: ${lines[i]}',
                colors.foreground,
                closes: i == lines.length - 1,
              );
            }
            continue;
          }
          if (result.value == '/edit' ||
              result.value == '/insert' ||
              result.value == '/remove') {
            write('Enter line number:', colors.foreground, closes: true);
            final number = await _edit(
              inputKeys,
              '',
              out,
              linear: true,
              sequential: true,
              outputProfile: effectiveProfile,
              structure: structure,
              session: session,
            );
            if (number.action == 'cancel') return Cancelled();
            if (number.action == 'interrupt') return Interrupted();
            if (number.action != 'submit') return InputEnded();
            final index = (int.tryParse(number.value) ?? 0) - 1;
            if (index < 0 ||
                index >= lines.length + (result.value == '/insert' ? 1 : 0)) {
              write('Invalid line number.', colors.error, closes: true);
              continue;
            }
            if (result.value == '/remove') {
              write(
                'Remove line ${index + 1}? Enter y to confirm.',
                colors.foreground,
                closes: true,
              );
              final confirm = await _edit(
                inputKeys,
                '',
                out,
                linear: true,
                sequential: true,
                outputProfile: effectiveProfile,
                structure: structure,
                session: session,
              );
              if (confirm.action == 'cancel') return Cancelled();
              if (confirm.action == 'interrupt') return Interrupted();
              if (confirm.action != 'submit') return InputEnded();
              if (confirm.value == 'y') lines.removeAt(index);
            } else {
              write('Edit line:', colors.foreground, closes: true);
              final edited = await _edit(
                inputKeys,
                result.value == '/edit' ? lines[index] : '',
                out,
                linear: true,
                sequential: true,
                extraCommands: const {
                  '/list',
                  '/edit',
                  '/insert',
                  '/remove',
                  '/done',
                },
                multilinePaste: true,
                outputProfile: effectiveProfile,
                structure: structure,
                session: session,
                linearHelpText: _help(linear: true),
                maxLength: maxLength == null
                    ? null
                    : (maxLength! -
                              (result.value == '/edit'
                                  ? lines.join('\n').characters.length -
                                        lines[index].characters.length
                                  : lines.isEmpty
                                  ? 0
                                  : lines.join('\n').characters.length + 1))
                          .clamp(0, maxLength!),
                pasteMaxLength: maxLength == null
                    ? null
                    : (maxLength! -
                              (result.value == '/edit'
                                  ? lines.join('\n').characters.length -
                                        lines[index].characters.length
                                  : lines.isEmpty
                                  ? 0
                                  : lines.join('\n').characters.length + 1))
                          .clamp(0, maxLength!),
              );
              if (edited.action == 'cancel') return Cancelled();
              if (edited.action == 'interrupt') return Interrupted();
              if (edited.action == 'command') {
                write(
                  'Quote commands to enter them as text.',
                  colors.warning,
                  closes: true,
                );
                continue;
              }
              if (edited.action != 'submit') return InputEnded();
              if (result.value == '/edit') lines.removeAt(index);
              lines.insertAll(index, edited.value.split('\n'));
            }
            continue;
          }
          lines.add(result.value);
        }
      } finally {
        if (keys == null) await inputKeys.close();
      }
    }
    var chars = _normalize(initialValue).characters.toList();
    var pos = chars.length;
    var action = 0;
    var help = false;
    var activeProfile = effectiveProfile;
    void insert(String text) {
      final before = chars.take(pos).join() + text;
      final candidate = before + chars.skip(pos).join();
      if (maxLength != null && candidate.characters.length > maxLength!) {
        spine.write(
          out,
          'Insertion rejected: character limit is $maxLength graphemes.',
          foreground: colors.error,
          closes: true,
        );
        return;
      }
      chars = candidate.characters.toList();
      var offset = 0;
      pos = 0;
      while (pos < chars.length && offset < before.length) {
        offset += chars[pos].length;
        pos++;
      }
    }

    void display() {
      session?._setPromptGeometry(activeProfile.geometry);
      var start = pos;
      while (start > 0 && chars[start - 1] != '\n') {
        start--;
      }
      var end = pos;
      while (end < chars.length && chars[end] != '\n') {
        end++;
      }
      final line = chars.take(start).where((c) => c == '\n').length + 1;
      String visible(Iterable<String> part) =>
          part.join().replaceAll(r'\', r'\\').replaceAll('\t', r'\t');
      final width = _textInputWidth(activeProfile);
      var shownStart = start;
      var shownEnd = end;
      if (width != null) {
        // The row prefix and both truthful overflow markers consume cells;
        // the remaining budget centres on the logical caret in the current
        // line, measured in display cells rather than code units.
        int cells(String cluster) => TextDisplayMap(cluster).cellWidth;
        final prefixCells = 'Line $line: '.length;
        final budget = (width - prefixCells - 2).clamp(
          0,
          _textInputTotalWidthCap,
        );
        var used = 0;
        for (var index = start; index < pos; index++) {
          used += cells(chars[index]);
        }
        while (shownStart < pos && used > budget) {
          used -= cells(chars[shownStart++]);
        }
        shownEnd = pos;
        while (shownEnd < end && used + cells(chars[shownEnd]) <= budget) {
          used += cells(chars[shownEnd++]);
        }
      }
      out.write(
        '\r\x1b[2KLine $line: ${shownStart > start ? '<' : ''}${visible(chars.getRange(shownStart, pos))}\x1b[s${visible(chars.getRange(pos, shownEnd))}${shownEnd < end ? '>' : ''}\x1b[u',
      );
    }

    display();
    session?._setPromptRepaint(display);
    StreamSubscription<void>? resizeSubscription;
    Timer? resizeFallback;
    final resizeObserver = scripted.resizeObserver;
    if (resizeObserver != null) {
      void stopResizeObservation() {
        resizeFallback?.cancel();
        resizeFallback = null;
        final subscription = resizeSubscription;
        resizeSubscription = null;
        if (subscription != null) unawaited(subscription.cancel());
      }

      void observeResize() {
        final ({int columns, int rows})? dimensions;
        try {
          dimensions = resizeObserver.readDimensions();
        } catch (_) {
          return;
        }
        if (dimensions == null ||
            dimensions.columns <= 0 ||
            dimensions.rows <= 0) {
          return;
        }
        final old = activeProfile.geometry;
        if (!old.isAutomatic &&
            old.columns == dimensions.columns &&
            old.rows == dimensions.rows) {
          return;
        }
        final profile = activeProfile;
        activeProfile = OutputProfile(
          cursor: profile.cursor,
          alternateScreen: profile.alternateScreen,
          styles: profile.styles,
          colorDepth: profile.colorDepth,
          glyphs: profile.glyphs,
          geometry: OutputGeometry.fixed(
            columns: dimensions.columns,
            rows: dimensions.rows,
          ),
          ambiguousWidth: profile.ambiguousWidth,
        );
        // A resize is a repaint only, and help owns the screen until it is
        // dismissed.
        if (help) return;
        try {
          display();
        } catch (error, stackTrace) {
          stopResizeObservation();
          inputKeys.fail(error, stackTrace);
        }
      }

      resizeSubscription = resizeObserver.notifications.listen(
        (_) => observeResize(),
        onError: (_, _) {},
      );
      final milliseconds = resizeObserver.fallbackInterval.inMilliseconds.clamp(
        100,
        30000,
      );
      resizeFallback = Timer.periodic(
        Duration(milliseconds: milliseconds),
        (_) => observeResize(),
      );
    }
    try {
      while (true) {
        final key = await inputKeys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x14') {
          if (help) continue;
          help = true;
          final transient =
              effectiveProfile.alternateScreen == CapabilitySupport.supported;
          if (session != null) {
            session._openModalHelp(useAlternateScreen: transient);
          } else if (transient) {
            out.write('\x1b[?1049h\x1b[H');
          }
          spine.write(
            out,
            _help(linear: false),
            foreground: colors.foreground,
            closes: true,
          );
          continue;
        }
        if (help) {
          if (key == '\x1b') {
            help = false;
            final transient =
                effectiveProfile.alternateScreen == CapabilitySupport.supported;
            if (session != null) {
              session._dismissModalHelp(
                showTranscriptDismissal: !transient,
                repaintPrompt: display,
              );
            } else if (transient) {
              out.write('\x1b[?1049l');
              display();
            } else {
              out.writeln('Help dismissed.');
              display();
            }
          }
          continue;
        }
        if (key == '\x1b') {
          if (action != 0) {
            action = 0;
            out.writeln('Edit');
            continue;
          }
          return Cancelled();
        }
        if (key == '\t') {
          action = (action + 1) % 3;
          out.writeln(['Edit', 'Finish', 'Insert tab'][action]);
          continue;
        }
        if (key == '\r' || key == '\n') {
          if (action == 1) {
            final value = chars.join();
            final error = _error(value);
            if (error == null) return Accepted(value);
            spine.write(out, error, foreground: colors.error, closes: true);
            action = 0;
            continue;
          }
          if (action == 2) {
            insert('\t');
            action = 0;
          } else {
            insert('\n');
          }
        } else if (action != 0) {
          continue;
        } else if (key == '\x1b[A' || key == '\x1b[B') {
          var start = pos;
          while (start > 0 && chars[start - 1] != '\n') {
            start--;
          }
          final column = pos - start;
          if (key == '\x1b[A' && start > 0) {
            final end = start - 1;
            var previous = end;
            while (previous > 0 && chars[previous - 1] != '\n') {
              previous--;
            }
            pos = (previous + column).clamp(previous, end);
          } else if (key == '\x1b[B') {
            var end = pos;
            while (end < chars.length && chars[end] != '\n') {
              end++;
            }
            if (end < chars.length) {
              final next = end + 1;
              var nextEnd = next;
              while (nextEnd < chars.length && chars[nextEnd] != '\n') {
                nextEnd++;
              }
              pos = (next + column).clamp(next, nextEnd);
            }
          }
        } else if (key == '\x1b[D') {
          if (pos > 0) pos--;
        } else if (key == '\x1b[C') {
          if (pos < chars.length) pos++;
        } else if (key == '\x1b[H' || key == '\x01') {
          while (pos > 0 && chars[pos - 1] != '\n') {
            pos--;
          }
        } else if (key == '\x1b[F' || key == '\x05') {
          while (pos < chars.length && chars[pos] != '\n') {
            pos++;
          }
        } else if (key == '\x7f' || key == '\x08') {
          if (pos > 0) {
            chars.removeAt(--pos);
          }
        } else if (key == '\x1b[3~') {
          if (pos < chars.length) {
            chars.removeAt(pos);
          }
        } else if (key == '\x1b[999~') {
          out.writeln('Paste rejected: exceeds 4096 UTF-16 code units.');
        } else if (key.startsWith('\x1b[200~')) {
          final data = _normalize(key.substring(6, key.length - 6));
          if (data.runes.any(
            (r) => (r < 32 && r != 9 && r != 10) || r == 127,
          )) {
            out.writeln('Paste rejected: unsupported control character.');
          } else {
            insert(data);
          }
        } else if (!key.startsWith('\x1b') &&
            key.codeUnitAt(0) >= 32 &&
            key.codeUnitAt(0) != 127) {
          insert(key);
        }
        display();
      }
    } finally {
      if (help) {
        if (session != null) {
          session._abortModalHelp();
        } else if (effectiveProfile.alternateScreen ==
            CapabilitySupport.supported) {
          out.write('\x1b[?1049l');
        }
      }
      session?._setPromptRepaint(null);
      resizeFallback?.cancel();
      await resizeSubscription?.cancel();
      if (keys == null) await inputKeys.close();
    }
  }
}

/// Rejects a choice-family label or reason that cannot be displayed.
///
/// The tree and order families validate through this too, instead of building
/// a throwaway [Choice] only to reach its checks.
void _checkChoiceText(String label, String? reason) {
  if (label.trim().isEmpty ||
      label.runes.any((c) => c < 32 || c == 127) ||
      (reason != null &&
          (reason.trim().isEmpty ||
              reason.runes.any((c) => c < 32 || c == 127)))) {
    throw ArgumentError(
      'Choice labels and reasons must be nonempty safe text.',
    );
  }
}

/// One choice, identified independently of its display label.
final class Choice<T> {
  Choice(this.value, this.label, {this.disabledReason}) {
    _checkChoiceText(label, disabledReason);
  }
  final T value;
  final String label;
  final String? disabledReason;
}

/// The expansion state a tree row presents, independent of selectability.
enum _TreeRowState { leaf, expanded, collapsed, childrenUnavailable }

/// One displayed choice row.
///
/// Every public choice family composes its rows through this typed record so a
/// stable reference, the family's selection marker, focus, the displayed
/// default and an unavailable reason stay separate facts. The markers are also
/// the row's atomic units: wrapping may move one to the next line but never
/// splits it.
///
/// The tree and order families extend the same record instead of inventing a
/// second row: a tree row adds its expansion state, its selectability and its
/// staleness beside focus and default, and an order row adds the identity's
/// current position, its locked anchor reason and a pick-up state. Marker order
/// is selection, position, focus, default, tree state, selectability, lock,
/// movement and unavailability.
final class _ChoiceRow {
  const _ChoiceRow({
    required this.reference,
    required this.label,
    this.radio = false,
    this.checked,
    this.focused = false,
    this.isDefault = false,
    this.disabledReason,
    this.treeState,
    this.childrenUnavailableReason,
    this.selectable,
    this.position,
    this.positionCount,
    this.lockedReason,
    this.moving = false,
    this.current = true,
  });

  /// The stable choice reference displayed for this row, independent of order.
  final int reference;
  final String label;

  /// Presents the single-choice marker beside the label.
  final bool radio;

  /// The draft selection state, or null for a family without one.
  final bool? checked;
  final bool focused;
  final bool isDefault;
  final String? disabledReason;

  /// The tree family's expansion state, or null for a non-tree row.
  final _TreeRowState? treeState;

  /// Explains a branch whose children are not currently available.
  final String? childrenUnavailableReason;

  /// Whether a tree node may be accepted, or null for a non-tree row.
  ///
  /// Expansion and selectability are independent: a selectable branch can be
  /// opened, and a leaf may still be unselectable.
  final bool? selectable;

  /// The order family's one-based display position for this identity.
  final int? position;
  final int? positionCount;

  /// The order family's permanent position that other identities cannot cross.
  final String? lockedReason;

  /// The identity is picked up and currently follows the focus.
  final bool moving;

  /// The source still reports this node in the current path.
  final bool current;

  String? get _treeStateMarker => switch (treeState) {
    null => null,
    _TreeRowState.leaf => '[leaf]',
    _TreeRowState.expanded => '[expanded]',
    _TreeRowState.collapsed => '[collapsed]',
    _TreeRowState.childrenUnavailable =>
      '[children unavailable: $childrenUnavailableReason]',
  };

  List<String> get markers => [
    if (checked != null) checked! ? '[checked]' : '[unchecked]',
    if (position != null) '[position $position of $positionCount]',
    if (focused) '[focused]',
    if (isDefault) '[default]',
    ?_treeStateMarker,
    if (selectable != null) selectable! ? '[selectable]' : '[not selectable]',
    if (lockedReason != null) '[locked: $lockedReason]',
    if (moving) '[moving]',
    if (disabledReason != null) '[unavailable: $disabledReason]',
    if (!current) '[unavailable: no longer available]',
  ];

  String get text =>
      '$reference. ${radio ? '( ) ' : ''}$label'
      '${markers.map((marker) => ' $marker').join()}';
}

/// Writes one shared choice row within the declared width.
///
/// The row keeps its stable reference, focus marker and unavailability reason
/// while gaining the structure's continuation prefix, so a framed list reads as
/// one spine rather than a stack of unrelated rows. When the structure encloses
/// its stage, the row is written through the stage's [spine] instead, so the
/// whole list stays inside one frame and keeps the structure's marker even when
/// the width is too narrow to frame it.
void _writeChoiceRow(
  StringSink output,
  _ChoiceRow row, {
  required int? width,
  required TerminalColor foreground,
  required ColorTheme colors,
  required OutputProfile? profile,
  PromptStructure structure = PromptStructure.plain,
  _StructureSpine? spine,
  bool opens = false,
  bool closes = false,
}) {
  if (spine != null && (spine._enclosure != null || spine.heads)) {
    // The stage's spine owns the row: a body row inside the frame, a body row
    // under a heading structure's heading, or the structure's live marker when
    // the width cannot frame the stage. Either way a choice row never silently
    // loses the structure the heading keeps.
    spine.write(
      output,
      DisplayText.from(row.text).value,
      foreground: foreground,
      atomicText: row.markers,
    );
    return;
  }
  final ascii = _structureAscii(profile);
  final available = width == null
      ? null
      : (width - structurePrefixCells(structure, ascii: ascii)).clamp(1, width);
  final lines = frameStructureLines(
    structure,
    ascii: ascii,
    opens: opens,
    closes: closes,
    lines: _wrapText(
      DisplayText.from(row.text).value,
      available,
      atomicText: row.markers,
    ),
  );
  for (final line in lines) {
    if (line.isEmpty) continue;
    output.writeln(_colorText(line, foreground, colors.background, profile));
  }
}

final class Select<T> extends _SingleChoice<T> {
  Select(
    super.label,
    super.choices, {
    super.defaultValue,
    super.colors = ColorThemes.terminalDefault,
    super.structure = PromptStructure.plain,
    super.instructions = InstructionDisplay.themeDefault,
    super.supplementaryHelp = const [],
  }) : super(radio: false);
}

final class Radio<T> extends _SingleChoice<T> {
  Radio(
    super.label,
    super.choices, {
    super.defaultValue,
    super.colors = ColorThemes.terminalDefault,
    super.structure = PromptStructure.plain,
    super.instructions = InstructionDisplay.themeDefault,
    super.supplementaryHelp = const [],
  }) : super(radio: true);
}

abstract class _SingleChoice<T> {
  _SingleChoice(
    this.label,
    List<Choice<T>> choices, {
    this.defaultValue,
    required this.radio,
    required this.colors,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : choices = List.unmodifiable(choices),
       supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (choices.map((c) => c.value).toSet().length != choices.length) {
      throw ArgumentError('Choice identities must be unique.');
    }
    if (defaultValue != null && !choices.any((c) => c.value == defaultValue)) {
      throw ArgumentError('Default identity is not a choice.');
    }
  }
  final String label;
  final List<Choice<T>> choices;
  final T? defaultValue;
  final bool radio;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  bool _active = false;

  /// Component help led by this family's controls.
  ///
  /// Unavailable reasons are protected: help names every unavailable choice
  /// with its reason, including pages that are not currently displayed.
  String _help({required bool linear}) {
    final kind = radio ? 'Radio' : 'Select';
    final unavailable = [
      for (var i = 0; i < choices.length; i++)
        if (choices[i].disabledReason != null)
          '${i + 1}. ${choices[i].label} is unavailable '
              '(${choices[i].disabledReason}) and cannot be accepted',
    ];
    final unavailableText = unavailable.isEmpty
        ? 'Every choice is currently available.'
        : '${unavailable.join('; ')}.';
    final defaultIndex = defaultValue == null
        ? -1
        : choices.indexWhere((c) => c.value == defaultValue);
    final defaultText = defaultIndex < 0
        ? 'No choice is marked as the default.'
        : 'Default: ${defaultIndex + 1}. ${choices[defaultIndex].label}.';
    final controls = linear
        ? r'Enter a stable choice number to accept that choice; /next and /previous show another page of ten. Exact /help and /cancel are commands; quote a command with a backslash and double a leading backslash. Identified paste is literal.'
        : 'Up/Down move the focus; Enter accepts the focused enabled choice; Escape dismisses help or cancels; Ctrl+C interrupts.';
    return 'Help: $kind. $unavailableText $controls $defaultText';
  }

  Future<PromptResult<T>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      return session._promptRunner<T>(
        _run,
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
      );
    }
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          if (terminal != null) {
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => _run(
                ScriptedInput(
                  terminal.input,
                  terminal.output,
                  supportsRich: terminal.supportsRich,
                  outputProfile: _terminalOutputProfile(terminal),
                  hardColorDisabled:
                      terminal.environment['NO_COLOR']?.isNotEmpty == true,
                  resizeObserver: _terminalResizeObserver(terminal),
                ),
                selected,
                outputProfile: outputProfile,
              ),
              lease.restore,
            );
          }
          return await _terminal<T>(
            selected,
            output ?? stderr,
            (source, mode, _) =>
                _run(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<T>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final n = int.tryParse(source.value);
      if (n == null ||
          n < 1 ||
          n > choices.length ||
          choices[n - 1].disabledReason != null) {
        return Unavailable('Supply an enabled choice reference.');
      }
      return Accepted(choices[n - 1].value);
    }
    final scripted = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    final out = scripted.output;
    final width = _textInputWidth(effectiveProfile);
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: width,
      background: colors.background,
      border: colors.border,
    );
    void write(String text, TerminalColor foreground, {bool closes = false}) =>
        spine.write(
          out,
          DisplayText.from(text).value,
          foreground: foreground,
          closes: closes,
        );

    var focus = defaultValue == null
        ? -1
        : choices.indexWhere((c) => c.value == defaultValue);
    if (focus < 0) focus = choices.indexWhere((c) => c.disabledReason == null);
    if (focus < 0 && choices.isNotEmpty) focus = 0;
    var page = 0;
    const pageSize = 10;
    final hint = mode == PromptMode.rich
        ? 'Up/Down navigate; Enter accepts the focused enabled choice. Ctrl+T help; Escape cancels; Ctrl+C interrupts.'
        : r'Enter a stable choice number to accept it. /next, /previous, /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal.';
    var hintShown = false;
    void show() {
      session?._setPromptGeometry(effectiveProfile.geometry);
      spine.reset();
      spine.heading(
        out,
        DisplayText.from(
          '$label ${radio ? 'Radio' : 'Select'}: ${choices.length} choices.',
        ).value,
        foreground: colors.foreground,
      );
      if (choices.isEmpty) write('No choices available.', colors.warning);
      final start = mode == PromptMode.linear ? page * pageSize : 0;
      final end = mode == PromptMode.linear
          ? (start + pageSize).clamp(0, choices.length)
          : choices.length;
      if (mode == PromptMode.linear && choices.isNotEmpty) {
        write(
          'Page ${page + 1} of ${(choices.length + pageSize - 1) ~/ pageSize}.',
          colors.muted,
        );
      }
      if (start < end) spine.breathingRow(out);
      for (var i = start; i < end; i++) {
        final c = choices[i];
        _writeChoiceRow(
          out,
          _ChoiceRow(
            reference: i + 1,
            label: c.label,
            radio: radio,
            focused: i == focus,
            isDefault: defaultValue != null && c.value == defaultValue,
            disabledReason: c.disabledReason,
          ),
          width: width,
          foreground: i == focus ? colors.accent : colors.foreground,
          colors: colors,
          profile: effectiveProfile,
          structure: structure,
          spine: spine,
        );
      }
      // An enclosure ends every presentation: the bottom rule closes the frame
      // and the compact hint stays outside it, so navigation never leaves the
      // stage framed but unclosed and an outcome is never a body row. A rail or
      // branch reports the hint once and continues its spine on a repaint.
      if (spine.encloses || !hintShown) {
        spine.hint(out, hint, foreground: colors.muted);
        hintShown = true;
      }
    }

    show();
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    session?._setPromptRepaint(show);
    try {
      if (mode == PromptMode.linear) {
        var entry = '';
        while (true) {
          final result = await _edit(
            inputKeys,
            entry,
            out,
            linear: true,
            sequential: true,
            extraCommands: const {'/next', '/previous'},
            linearHelpText: _help(linear: true),
            outputProfile: effectiveProfile,
            structure: structure,
            session: session,
          );
          if (result.action == 'cancel') return Cancelled();
          if (result.action == 'interrupt') return Interrupted();
          if (result.action == 'command') {
            if (result.value == '/next' &&
                (page + 1) * pageSize < choices.length) {
              page++;
            }
            if (result.value == '/previous' && page > 0) page--;
            entry = '';
            show();
            continue;
          }
          if (result.action != 'submit') return InputEnded();
          entry = result.value;
          final n = int.tryParse(entry);
          if (n == null || n < 1 || n > choices.length) {
            write(
              'Enter a valid choice reference.',
              colors.warning,
              closes: true,
            );
            continue;
          }
          final c = choices[n - 1];
          if (c.disabledReason != null) {
            write(
              'Unavailable: ${c.disabledReason}. Choose an enabled reference.',
              colors.warning,
              closes: true,
            );
            continue;
          }
          write('Accepted: ${c.label}.', colors.success, closes: true);
          return Accepted(c.value);
        }
      }
      var help = false;
      while (true) {
        final key = await inputKeys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          show();
          continue;
        }
        if (key == '\x14') {
          help = true;
          write(_help(linear: false), colors.foreground);
          continue;
        }
        if (help) continue;
        if (key == '\x1b[A' && focus > 0) {
          focus--;
          show();
        }
        if (key == '\x1b[B' && focus >= 0 && focus < choices.length - 1) {
          focus++;
          show();
        }
        if (key == '\r' || key == '\n') {
          if (focus < 0) {
            write('No choice available.', colors.warning);
            continue;
          }
          final c = choices[focus];
          if (c.disabledReason != null) {
            write(
              'Unavailable: ${c.disabledReason}. Navigate to an enabled choice.',
              colors.warning,
            );
            continue;
          }
          write('Accepted: ${c.label}.', colors.success);
          return Accepted(c.value);
        }
      }
    } finally {
      if (session != null) session._setPromptRepaint(null);
      if (keys == null) await inputKeys.close();
    }
  }
}

/// A draft set of choices, submitted in their original order.
final class MultiSelect<T> {
  MultiSelect(
    this.label,
    List<Choice<T>> choices, {
    List<T> defaultValues = const [],
    this.min = 0,
    this.max,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : choices = List.unmodifiable(choices),
       defaultValues = List.unmodifiable(defaultValues),
       supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (choices.map((c) => c.value).toSet().length != choices.length) {
      throw ArgumentError('Choice identities must be unique.');
    }
    if (min < 0 || (max != null && (max! < min || max! < 0))) {
      throw ArgumentError('Invalid selection bounds.');
    }
    if (defaultValues.toSet().length != defaultValues.length ||
        defaultValues.any(
          (v) => !choices.any((c) => c.value == v && c.disabledReason == null),
        ) ||
        (max != null && defaultValues.length > max!)) {
      throw ArgumentError('Invalid default choices.');
    }
  }
  final String label;
  final List<Choice<T>> choices;
  final List<T> defaultValues;
  final int min;
  final int? max;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  bool _active = false;

  /// Component help led by this family's toggle, review and filter actions.
  ///
  /// Unavailable reasons are protected: help names every unavailable choice
  /// with its reason, including filtered or paged-away choices.
  String _help({required bool linear}) {
    final unavailable = [
      for (var i = 0; i < choices.length; i++)
        if (choices[i].disabledReason != null)
          '${i + 1}. ${choices[i].label} is unavailable '
              '(${choices[i].disabledReason}) and cannot be toggled',
    ];
    final unavailableText = unavailable.isEmpty
        ? 'Every choice is currently available.'
        : '${unavailable.join('; ')}.';
    final bounds =
        'Bounds: minimum $min${max == null ? '' : ', maximum $max'}.';
    final controls = linear
        ? r'Enter a choice number to toggle it. /done submits; /selected reviews the selection; /filter edits the label filter; /select-visible and /clear-visible act on enabled results across pages; /next and /previous page. Exact /help and /cancel are commands; quote a command with a backslash and double a leading backslash. Identified paste is literal.'
        : 'Up/Down move the focus; Space toggles; Enter submits; / filters labels; Ctrl+A selects visible; Ctrl+X clears visible; Ctrl+R reviews; Escape dismisses help or cancels; Ctrl+C interrupts.';
    return 'Help: MultiSelect. $unavailableText $controls $bounds';
  }

  Future<PromptResult<List<T>>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      return session._promptRunner<List<T>>(
        _run,
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
      );
    }
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selectedMode =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          if (terminal != null) {
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => _run(
                ScriptedInput(
                  terminal.input,
                  terminal.output,
                  supportsRich: terminal.supportsRich,
                  outputProfile: _terminalOutputProfile(terminal),
                  hardColorDisabled:
                      terminal.environment['NO_COLOR']?.isNotEmpty == true,
                  resizeObserver: _terminalResizeObserver(terminal),
                ),
                selectedMode,
                outputProfile: outputProfile,
              ),
              lease.restore,
            );
          }
          return await _terminal<List<T>>(
            selectedMode,
            output ?? stderr,
            (source, mode, _) =>
                _run(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selectedMode, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<List<T>>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final refs = source.value.isEmpty ? <String>[] : source.value.split(',');
      final indices = <int>{};
      for (final ref in refs) {
        if (!RegExp(r'^[1-9][0-9]*$').hasMatch(ref)) {
          return Unavailable('Supply comma-separated choice references.');
        }
        final n = int.tryParse(ref);
        if (n == null ||
            n > choices.length ||
            choices[n - 1].disabledReason != null ||
            !indices.add(n - 1)) {
          return Unavailable('Supply unique enabled choice references.');
        }
      }
      if (indices.length < min || (max != null && indices.length > max!)) {
        return Unavailable('Selection count is outside the configured bounds.');
      }
      return Accepted([
        for (var i = 0; i < choices.length; i++)
          if (indices.contains(i)) choices[i].value,
      ]);
    }
    final scripted = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    final out = scripted.output;
    final width = _textInputWidth(effectiveProfile);
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: width,
      background: colors.background,
      border: colors.border,
    );
    void write(String text, TerminalColor foreground, {bool closes = false}) =>
        spine.write(
          out,
          DisplayText.from(text).value,
          foreground: foreground,
          closes: closes,
        );

    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    final selected = <int>{
      for (var i = 0; i < choices.length; i++)
        if (defaultValues.contains(choices[i].value)) i,
    };
    var filter = '';
    var focus = 0;
    var page = 0;
    const size = 10;
    List<int> visible() => [
      for (var i = 0; i < choices.length; i++)
        if (choices[i].label.toLowerCase().contains(filter.toLowerCase())) i,
    ];
    final hint = mode == PromptMode.linear
        ? 'Enter a choice number to toggle. /done, /selected, /filter, /select-visible, /clear-visible, /next, /previous, /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal; unframed paste cannot be distinguished from typing.'
        : 'Up/Down navigate; Space toggles; Enter submits; / filters; Ctrl+A select visible; Ctrl+X clear visible; Ctrl+R review; Ctrl+T help; Escape cancels; Ctrl+C interrupts.';
    var hintShown = false;
    void show() {
      session?._setPromptGeometry(effectiveProfile.geometry);
      spine.reset();
      final items = visible();
      final hidden = selected.where((i) => !items.contains(i)).length;
      spine.heading(
        out,
        DisplayText.from(
          '$label MultiSelect: ${selected.length} selected, $hidden hidden selected; ${items.length} results. Minimum $min${max == null ? '' : ', maximum $max'}.',
        ).value,
        foreground: colors.foreground,
      );
      if (items.isEmpty) write('No matching choices.', colors.warning);
      final shown = mode == PromptMode.linear
          ? items.skip(page * size).take(size)
          : items;
      if (mode == PromptMode.linear && items.isNotEmpty) {
        write(
          'Page ${page + 1} of ${(items.length + size - 1) ~/ size}.',
          colors.muted,
        );
      }
      if (shown.isNotEmpty) spine.breathingRow(out);
      for (final i in shown) {
        final c = choices[i];
        final focused =
            mode == PromptMode.rich && items.isNotEmpty && items[focus] == i;
        _writeChoiceRow(
          out,
          _ChoiceRow(
            reference: i + 1,
            label: c.label,
            checked: selected.contains(i),
            focused: focused,
            isDefault: defaultValues.contains(c.value),
            disabledReason: c.disabledReason,
          ),
          width: width,
          foreground: focused ? colors.accent : colors.foreground,
          colors: colors,
          profile: effectiveProfile,
          structure: structure,
          spine: spine,
        );
      }
      // An enclosure ends every presentation: the bottom rule closes the frame
      // and the compact hint stays outside it, so a toggle or navigation never
      // leaves the stage framed but unclosed and an outcome is never a body row.
      // A rail or branch reports the hint once and continues on a repaint.
      if (spine.encloses || !hintShown) {
        spine.hint(out, hint, foreground: colors.muted);
        hintShown = true;
      }
    }

    void review() {
      write('Selected: ${selected.length}.', colors.foreground);
      for (var i = 0; i < choices.length; i++) {
        if (selected.contains(i)) {
          write(
            '${i + 1}. ${choices[i].label}${visible().contains(i) ? '' : ' [hidden]'}',
            colors.foreground,
          );
        }
      }
    }

    void toggle(int i) {
      final c = choices[i];
      if (c.disabledReason != null) {
        write('Unavailable: ${c.disabledReason}.', colors.warning);
        return;
      }
      if (selected.contains(i)) {
        selected.remove(i);
      } else if (max != null && selected.length >= max!) {
        write('Maximum $max selections.', colors.warning);
        return;
      } else {
        selected.add(i);
      }
      final checked = selected.contains(i);
      write(
        '${c.label}: ${checked ? 'checked' : 'unchecked'}.',
        checked ? colors.success : colors.muted,
      );
    }

    void bulk(bool add) {
      final enabled = visible()
          .where((i) => choices[i].disabledReason == null)
          .toSet();
      if (add && max != null && selected.union(enabled).length > max!) {
        write('Maximum $max selections; no changes made.', colors.warning);
        return;
      }
      if (add) {
        selected.addAll(enabled);
      } else {
        selected.removeAll(enabled);
      }
    }

    PromptResult<List<T>>? submit() {
      if (selected.length < min) {
        write('Minimum $min selections required.', colors.warning);
        return null;
      }
      return Accepted([
        for (var i = 0; i < choices.length; i++)
          if (selected.contains(i)) choices[i].value,
      ]);
    }

    show();
    session?._setPromptRepaint(show);
    try {
      if (mode == PromptMode.linear) {
        while (true) {
          final r = await _edit(
            inputKeys,
            '',
            out,
            linear: true,
            sequential: true,
            extraCommands: const {
              '/done',
              '/selected',
              '/filter',
              '/select-visible',
              '/clear-visible',
              '/next',
              '/previous',
            },
            linearHelpText: _help(linear: true),
            outputProfile: effectiveProfile,
            structure: structure,
            session: session,
          );
          if (r.action == 'cancel') return Cancelled();
          if (r.action == 'interrupt') return Interrupted();
          if (r.action == 'eof') return InputEnded();
          if (r.action == 'command') {
            switch (r.value) {
              case '/done':
                final result = submit();
                if (result != null) return result;
              case '/selected':
                review();
              case '/select-visible':
                bulk(true);
                show();
              case '/clear-visible':
                bulk(false);
                show();
              case '/next':
                if ((page + 1) * size < visible().length) page++;
                show();
              case '/previous':
                if (page > 0) page--;
                show();
              case '/filter':
                write('Enter filter text (empty clears):', colors.muted);
                final f = await _edit(
                  inputKeys,
                  '',
                  out,
                  linear: true,
                  sequential: true,
                  outputProfile: effectiveProfile,
                  structure: structure,
                  session: session,
                );
                if (f.action == 'cancel') return Cancelled();
                if (f.action == 'interrupt') return Interrupted();
                if (f.action != 'submit') return InputEnded();
                filter = f.value;
                page = 0;
                focus = 0;
                show();
            }
          } else {
            final n = int.tryParse(r.value);
            if (n == null ||
                n < 1 ||
                n > choices.length ||
                !visible().contains(n - 1)) {
              out.writeln('Enter a visible choice reference.');
            } else {
              toggle(n - 1);
            }
          }
        }
      }
      var help = false;
      while (true) {
        final key = await inputKeys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          show();
          continue;
        }
        if (key == '\x14') {
          help = true;
          write(_help(linear: false), colors.foreground, closes: true);
          continue;
        }
        if (help) continue;
        final items = visible();
        if (key == '\x1b[A' && focus > 0) {
          focus--;
          show();
        }
        if (key == '\x1b[B' && focus < items.length - 1) {
          focus++;
          show();
        }
        if (key == ' ' && items.isNotEmpty) {
          toggle(items[focus]);
          show();
        }
        if (key == '\x01') {
          bulk(true);
          show();
        }
        if (key == '\x18') {
          bulk(false);
          show();
        }
        if (key == '\x12') review();
        if (key == '/') {
          write('Enter filter text (empty clears):', colors.muted);
          final f = await _edit(
            inputKeys,
            '',
            out,
            outputProfile: effectiveProfile,
            structure: structure,
            session: session,
          );
          if (f.action == 'interrupt') return Interrupted();
          if (f.action == 'eof') return InputEnded();
          if (f.action == 'submit') {
            filter = f.value;
            focus = 0;
            show();
          }
        }
        if (key == '\r' || key == '\n') {
          final result = submit();
          if (result != null) return result;
        }
      }
    } finally {
      if (session != null) session._setPromptRepaint(null);
      if (keys == null) await inputKeys.close();
    }
  }
}

/// The interaction stage that requested component help from [TimeInput].
///
/// Help leads with the stage so field editing, formatted entry and submission
/// do not share one undifferentiated paragraph.
enum _TimeHelpStage { field, formatted, submit }

/// A time of day without a date or timezone.
final class TimeInput {
  TimeInput(
    this.label, {
    this.twelveHour = false,
    this.seconds = false,
    this.initialValue,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (initialValue != null && _parse(initialValue!) == null) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }
  final String label;
  final bool twelveHour;
  final bool seconds;
  final String? initialValue;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  bool _active = false;

  String get _format =>
      '${seconds ? 'HH:mm:ss' : 'HH:mm'}${twelveHour ? ' AM or PM (period required; hours 01-12)' : ' (hours 00-23)'}; minutes${seconds ? ' and seconds' : ''} 00-59';
  String get _error => 'Enter $_format.';

  ({int hour, int minute, int? second})? _parse(String value) {
    final pattern = seconds
        ? r'^([0-9]{2}):([0-9]{2}):([0-9]{2})'
        : r'^([0-9]{2}):([0-9]{2})';
    final match = RegExp('$pattern${twelveHour ? r' (AM|PM)' : ''}\$')
        .firstMatch(value);
    if (match == null) return null;
    var hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    final second = seconds ? int.parse(match[3]!) : null;
    if (minute > 59 ||
        (second != null && second > 59) ||
        (twelveHour ? hour < 1 || hour > 12 : hour > 23)) {
      return null;
    }
    if (twelveHour) {
      final period = match[seconds ? 4 : 3];
      hour = hour % 12 + (period == 'PM' ? 12 : 0);
    }
    return (hour: hour, minute: minute, second: second);
  }

  /// Component help for one interaction stage.
  ///
  /// The opening sentence names the stage that requested help; the accepted
  /// format and the wider workflow follow in the same block.
  String _help({
    required bool linear,
    String? field,
    _TimeHelpStage stage = _TimeHelpStage.field,
  }) {
    final cue =
        '$_format time of day, not a date or timezone; ${seconds ? 'seconds included' : 'minutes only'} on ${twelveHour ? 'a 12-hour clock with a required AM/PM period' : 'a 24-hour clock'}.';
    if (linear) {
      return 'Help: Entering a complete $_format time. This is a time of day, not a date or timezone. Exact /help and /cancel are commands; quote a command with a backslash. An invalid draft stays editable for correction. $cue';
    }
    if (stage == _TimeHelpStage.submit) {
      return 'Help: Submit. Enter accepts the completed $_format time, Tab moves to the fields, Shift-Tab or Ctrl+B moves back, and the retained draft stays available until it is accepted. $cue Escape cancels and Ctrl+C interrupts.';
    }
    if (stage == _TimeHelpStage.formatted) {
      return 'Help: Editing the formatted time. Enter the whole $_format value and press Enter to reload the labeled fields. $cue Escape cancels and Ctrl+C interrupts.';
    }
    return 'Help: Editing the ${field ?? 'focused'} field. One labeled field at a time; incomplete fields remain drafts. Tab moves between fields and actions. Up/Down or + and - adjust only the focused field without wrapping. Escape cancels and Ctrl+C interrupts. $cue';
  }

  Future<PromptResult<({int hour, int minute, int? second})>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      return session._promptRunner<({int hour, int minute, int? second})>(
        _run,
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
      );
    }
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          if (terminal != null) {
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => _run(
                ScriptedInput(
                  terminal.input,
                  terminal.output,
                  supportsRich: terminal.supportsRich,
                  outputProfile: _terminalOutputProfile(terminal),
                  hardColorDisabled:
                      terminal.environment['NO_COLOR']?.isNotEmpty == true,
                  resizeObserver: _terminalResizeObserver(terminal),
                ),
                selected,
                outputProfile: outputProfile,
              ),
              lease.restore,
            );
          }
          return await _terminal<({int hour, int minute, int? second})>(
            selected,
            output ?? stderr,
            (nativeSource, nativeMode, _) =>
                _run(nativeSource, nativeMode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<({int hour, int minute, int? second})>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final value = _parse(source.value);
      return value == null ? Unavailable(_error) : Accepted(value);
    }
    final scripted = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    final out = scripted.output;
    final width = _textInputWidth(effectiveProfile);
    final resizeObserver = mode == PromptMode.rich
        ? scripted.resizeObserver
        : null;
    var value = initialValue ?? '';
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: width,
      background: colors.background,
      border: colors.border,
    );
    void write(String text, {bool closes = false}) =>
        spine.write(out, text, foreground: colors.foreground, closes: closes);
    spine.opening(
      out,
      title: '$label.',
      body:
          'Format: $_format. Active format cue: ${seconds ? 'seconds included' : 'minutes only'}; ${twelveHour ? 'AM/PM period required' : '24-hour clock'}.',
      foreground: colors.foreground,
      bodyForeground: colors.foreground,
    );
    spine.hint(
      out,
      mode == PromptMode.linear
          ? 'Enter a time of day, not a date or timezone. /help describes the format; /cancel cancels.'
          : 'Edit one field at a time. Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
      foreground: colors.foreground,
    );
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    try {
      if (mode == PromptMode.linear) {
        while (true) {
          final edit = await _edit(
            inputKeys,
            value,
            out,
            linear: true,
            sequential: !effectiveProfile.supportsRichInteraction,
            clearHelpCommand: true,
            linearHelpText: _help(linear: true),
            outputProfile: effectiveProfile,
            structure: structure,
            resizeObserver: resizeObserver,
            session: session,
          );
          if (edit.action == 'cancel') return Cancelled();
          if (edit.action == 'interrupt') return Interrupted();
          if (edit.action != 'submit') return InputEnded();
          value = edit.value;
          final parsed = _parse(value);
          if (parsed != null) {
            write(
              'Review: $value is a time of day without date or timezone.',
              closes: true,
            );
            return Accepted(parsed);
          }
          write('$_error Correct the retained draft.', closes: true);
        }
      }
      return await _runRich(
        inputKeys,
        out,
        value,
        effectiveProfile,
        session,
        resizeObserver,
      );
    } finally {
      if (keys == null) await inputKeys.close();
    }
  }

  Future<PromptResult<({int hour, int minute, int? second})>> _runRich(
    _Keys keys,
    StringSink out,
    String draft,
    OutputProfile profile,
    TerminalSession? session,
    TerminalResizeObserver? resizeObserver,
  ) async {
    final width = _textInputWidth(profile);
    final labels = <String>['Hour', 'Minute', if (seconds) 'Second'];
    final clock = draft.split(' ').first.split(':');
    final fields = List<String>.generate(
      labels.length,
      (index) => index < clock.length ? clock[index] : '',
    );
    var period = draft.contains(' ') ? draft.split(' ').skip(1).join(' ') : '';
    final controls = [
      ...labels,
      if (twelveHour) 'Period',
      'Edit formatted time',
      'Submit',
    ];
    var focus = 0;
    final spine = _structureSpine(
      profile,
      structure: structure,
      width: width,
      background: colors.background,
      border: colors.border,
    );
    void write(String text, {bool closes = false}) =>
        spine.write(out, text, foreground: colors.foreground, closes: closes);

    String current() {
      if (fields.every((field) => field.isEmpty) && period.isEmpty) return '';
      final clockText = fields.join(':');
      return twelveHour ? '$clockText $period' : clockText;
    }

    void show() {
      spine.reset();
      spine.opening(
        out,
        title: '$label.',
        body:
            'Format: $_format. Draft: ${current().trim().isEmpty ? 'not set' : current()}.',
        foreground: colors.foreground,
        bodyForeground: colors.foreground,
      );
      spine.hint(
        out,
        'Focus: ${controls[focus]}. Tab moves; Up/Down or + and - adjust a segment without wrapping; Enter edits a field or activates an action; Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
        foreground: colors.foreground,
      );
    }

    show();
    while (true) {
      final segmentCount = labels.length + (twelveHour ? 1 : 0);
      if (focus < segmentCount) {
        final name = controls[focus];
        final isPeriod = name == 'Period';
        final old = isPeriod ? period : fields[focus];
        final edit = await _edit(
          keys,
          old,
          out,
          maxLength: isPeriod ? 2 : 2,
          transientHelp: profile.alternateScreen == CapabilitySupport.supported,
          helpText: _help(linear: false, field: name),
          outputProfile: profile,
          structure: structure,
          resizeObserver: resizeObserver,
          session: session,
          intercept: (key, text) {
            if (key.startsWith('\x1b[200~') &&
                (key.contains(':') || key.contains(' '))) {
              write('Paste only one time field at a time.', closes: true);
              return 'handled';
            }
            if (key == '\t') return 'next';
            if (key == '\x1b[Z' || key == '\x02') return 'previous';
            if (key == ':' || (isPeriod && key == ' ')) return 'next';
            if (key == '\x1b[A' || key == '+') return 'increase';
            if (key == '\x1b[B' || key == '-') return 'decrease';
            return null;
          },
        );
        if (edit.action == 'cancel') return Cancelled();
        if (edit.action == 'interrupt') return Interrupted();
        if (edit.action == 'eof') return InputEnded();
        _finishFieldLine(out, edit.action);
        if (isPeriod) {
          period = edit.value;
        } else {
          fields[focus] = edit.value;
        }
        if (edit.action == 'increase' || edit.action == 'decrease') {
          if (isPeriod) {
            period = edit.action == 'increase'
                ? (period == 'AM' ? 'PM' : period)
                : (period == 'PM' ? 'AM' : period);
          } else {
            final currentValue = int.tryParse(edit.value);
            if (currentValue == null) {
              write(
                'Enter a complete numeric field before adjustment.',
                closes: true,
              );
            } else {
              final min = focus == 0 && twelveHour ? 1 : 0;
              final max = focus == 0 ? (twelveHour ? 12 : 23) : 59;
              final next = currentValue + (edit.action == 'increase' ? 1 : -1);
              if (next >= min && next <= max) {
                fields[focus] = next.toString().padLeft(edit.value.length, '0');
              }
            }
          }
          show();
          continue;
        }
        if (edit.action == 'previous') {
          focus = (focus + controls.length - 1) % controls.length;
        } else if (edit.action == 'next' || edit.action == 'submit') {
          focus = (focus + 1) % controls.length;
        }
        show();
        continue;
      }
      if (focus == segmentCount) {
        write('Edit formatted time; Enter finishes editing.', closes: true);
        final edit = await _edit(
          keys,
          current(),
          out,
          transientHelp: profile.alternateScreen == CapabilitySupport.supported,
          helpText: _help(linear: false, stage: _TimeHelpStage.formatted),
          outputProfile: profile,
          structure: structure,
          resizeObserver: resizeObserver,
          session: session,
          intercept: (key, text) {
            if (key == '\t') return 'next';
            if (key == '\x1b[Z' || key == '\x02') return 'previous';
            return null;
          },
        );
        if (edit.action == 'interrupt') return Interrupted();
        if (edit.action == 'cancel') {
          show();
          continue;
        }
        _finishFieldLine(out, edit.action);
        if (edit.action == 'next') {
          focus++;
          show();
          continue;
        }
        if (edit.action == 'previous') {
          focus = (focus + controls.length - 1) % controls.length;
          show();
          continue;
        }
        if (edit.action != 'submit') return InputEnded();
        draft = edit.value;
        final parts = draft.split(' ');
        final editedClock = parts.first.split(':');
        for (var index = 0; index < fields.length; index++) {
          fields[index] = index < editedClock.length ? editedClock[index] : '';
        }
        period = twelveHour && parts.length > 1 ? parts.skip(1).join(' ') : '';
        if (_parse(current()) == null) {
          write(_error, closes: true);
        }
        show();
        continue;
      }
      final submit = await _edit(
        keys,
        '',
        out,
        transientHelp: profile.alternateScreen == CapabilitySupport.supported,
        helpText: _help(linear: false, stage: _TimeHelpStage.submit),
        outputProfile: profile,
        structure: structure,
        resizeObserver: resizeObserver,
        session: session,
        intercept: (key, text) {
          if (key == '\t') return 'next';
          if (key == '\x1b[Z' || key == '\x02') return 'previous';
          if ((key == '\r' || key == '\n') && text.isEmpty) return 'submit';
          return null;
        },
      );
      if (submit.action == 'cancel') return Cancelled();
      if (submit.action == 'interrupt') return Interrupted();
      if (submit.action == 'eof') return InputEnded();
      // Every `submit` here comes from the intercept above, which returns before
      // `_edit` terminates the editable line it displayed.
      out.writeln();
      if (submit.action == 'next') {
        focus = 0;
        show();
        continue;
      }
      if (submit.action == 'previous') {
        focus = segmentCount;
        show();
        continue;
      }
      if (submit.action == 'submit') {
        final parsed = _parse(current());
        if (parsed != null) {
          write(
            'Review: ${current()} is a time of day without date or timezone.',
            closes: true,
          );
          return Accepted(parsed);
        }
        write(_error, closes: true);
        show();
      }
    }
  }
}

enum TagStyle { kebabCase, snakeCase }

final class TagInput {
  TagInput(
    this.label, {
    this.style = TagStyle.kebabCase,
    this.maxLength,
    this.validate,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (maxLength != null && maxLength! < 0) {
      throw ArgumentError.value(maxLength, 'maxLength');
    }
  }
  final String label;
  final TagStyle style;
  final int? maxLength;
  final String? Function(String)? validate;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  bool _active = false;

  String _canonical(String text) {
    final value = text
        .replaceAllMapped(
          RegExp(r'(\p{Lu})(\p{Lu}\p{Ll})', unicode: true),
          (m) => '${m[1]}-${m[2]}',
        )
        .replaceAllMapped(
          RegExp(r'([\p{Ll}\p{Nd}]\p{M}*)(\p{Lu})', unicode: true),
          (m) => '${m[1]}-${m[2]}',
        )
        .replaceAll(RegExp(r'[\s_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .toLowerCase();
    return style == TagStyle.snakeCase ? value.replaceAll('-', '_') : value;
  }

  String get _styleName =>
      style == TagStyle.snakeCase ? 'snake_case' : 'kebab-case';

  ({String title, String guidance}) _openingParts({required bool linear}) => (
    title: '$label: $_styleName tags.',
    guidance:
        'Enter adds; Ctrl+X discards the draft. ${linear ? '/done finishes.' : 'Tab then Enter finishes; Backspace focuses a tag, arrows navigate, Enter edits, Delete removes.'}${maxLength == null ? '' : ' Maximum $maxLength graphemes per canonical tag.'}',
  );

  /// Current-stage help for this tag collection.
  ///
  /// The draft is never described as a submitted answer: adding, editing,
  /// removing and finishing are separate explicit actions, and the canonical
  /// casing plus the limits and caller validation stay reviewable.
  String _help({required bool linear}) {
    final constraints =
        '${maxLength == null ? '' : 'Maximum $maxLength graphemes per canonical tag. '}${validate == null ? '' : 'Your validator runs on each canonical tag. '}';
    if (linear) {
      return 'Help: Enter adds one canonical $_styleName tag and clears the draft; /list, /edit, /remove, /done, /help and /cancel are exact commands. Quote a command with a backslash; double a leading backslash. Identified paste is literal; unframed paste cannot be distinguished from typing. Ctrl+X discards the current draft; /done finishes with the accepted tags only. $constraints';
    }
    return 'Help: Enter adds the draft as a canonical $_styleName tag and clears the draft; Tab focuses Finish, where Enter submits with an empty draft. Backspace with an empty draft focuses the last accepted tag; Left/Right move between accepted tags; Enter edits the focused tag; Delete removes the focused tag; Ctrl+X discards the draft. Preview shows the current canonical tag. Ctrl+T opens this help; Escape cancels; Ctrl+C interrupts. $constraints';
  }

  Future<PromptResult<List<String>>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      return session._promptRunner<List<String>>(
        _runTags,
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
      );
    }
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          if (terminal != null) {
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => _runTags(
                ScriptedInput(
                  terminal.input,
                  terminal.output,
                  supportsRich: terminal.supportsRich,
                  outputProfile: _terminalOutputProfile(terminal),
                  resizeObserver: _terminalResizeObserver(terminal),
                ),
                selected,
                outputProfile: outputProfile,
              ),
              lease.restore,
            );
          }
          return await _terminal<List<String>>(
            selected,
            output ?? stderr,
            (source, mode, _) =>
                _runTags(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _runTags(source, selected, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<List<String>>> _runTags(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedTags) {
      final tags = <String>[];
      for (final draft in source.values) {
        if (!RegExp(
          r'^(?:[\p{L}\p{Nd}]\p{M}*|[\s_-])*$',
          unicode: true,
        ).hasMatch(draft)) {
          return Unavailable('Invalid tag characters.');
        }
        final canonical = _canonical(draft);
        if (canonical.isEmpty ||
            (maxLength != null && canonical.characters.length > maxLength!) ||
            tags.contains(canonical)) {
          return Unavailable('Invalid or duplicate canonical tag.');
        }
        final error = validate?.call(canonical);
        if (error != null) return Unavailable(error);
        tags.add(canonical);
      }
      return Accepted(tags);
    }
    if (source is SuppliedAnswer) {
      return Unavailable('Supply a collection using SuppliedTags.');
    }
    final input = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(input, outputProfile);
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    final inputKeys = keys ?? _Keys(input.input.transform(utf8.encoder));
    final tags = <String>[];
    var draft = '';
    var selectingRemoval = false;
    var selectingEdit = false;
    int? editing;
    int? focused;
    var finishFocused = false;
    final width = _textInputWidth(effectiveProfile);
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: width,
      background: colors.background,
      border: colors.border,
    );
    void write(String text, {bool closes = false}) => spine.write(
      input.output,
      text,
      foreground: colors.foreground,
      closes: closes,
    );
    _writeStructureIntro(
      spine,
      input.output,
      parts: _openingParts(linear: mode == PromptMode.linear),
      foreground: colors.foreground,
    );
    try {
      while (true) {
        final result = await _edit(
          inputKeys,
          draft,
          input.output,
          linear: mode == PromptMode.linear,
          sequential: mode == PromptMode.linear,
          extraCommands: const {'/done', '/list', '/edit', '/remove'},
          helpText: _help(linear: false),
          linearHelpText: _help(linear: true),
          outputProfile: effectiveProfile,
          structure: structure,
          session: session,
          transientHelp:
              effectiveProfile.alternateScreen == CapabilitySupport.supported,
          resizeObserver: mode == PromptMode.rich ? input.resizeObserver : null,
          intercept: (key, text) {
            if (key == '\x18' && text.isNotEmpty) {
              return 'discard-draft';
            }
            if (mode != PromptMode.rich) return null;
            if (key == '\t') {
              finishFocused = true;
              write('Finish focused; Enter submits.');
              return 'handled';
            }
            if (finishFocused && (key == '\r' || key == '\n')) {
              if (text.isNotEmpty) {
                write(
                  'Add the draft or press Ctrl+X to discard it before finishing.',
                );
                finishFocused = false;
                return 'handled';
              }
              return 'finish';
            }
            if (key == '\x7f' || key == '\x08') {
              if (text.isEmpty && tags.isNotEmpty) {
                focused ??= tags.length - 1;
                write('Focused: ${tags[focused!]}');
                return 'handled';
              }
            }
            if (text.isEmpty &&
                focused != null &&
                (key == '\x1b[D' || key == '\x1b[C')) {
              focused = (focused! + (key == '\x1b[D' ? -1 : 1)).clamp(
                0,
                tags.length - 1,
              );
              write('Focused: ${tags[focused!]}');
              return 'handled';
            }
            if ((key == '\r' || key == '\n') &&
                text.isEmpty &&
                focused != null) {
              return 'edit-focused';
            }
            if (key == '\x1b[3~' && text.isEmpty && focused != null) {
              write('Removed: ${tags.removeAt(focused!)}');
              focused = null;
              return 'handled';
            }
            finishFocused = false;
            return null;
          },
          onChanged: mode == PromptMode.rich
              ? (text) => write('Preview: ${_canonical(text)}')
              : null,
        );
        if (result.action == 'cancel') return Cancelled();
        if (result.action == 'interrupt') return Interrupted();
        if (result.action == 'finish') return Accepted(tags);
        if (result.action == 'discard-draft') {
          draft = '';
          editing = null;
          finishFocused = false;
          write('Draft discarded.');
          continue;
        }
        if (result.action == 'edit-focused') {
          editing = focused;
          draft = tags[editing!];
          write('Editing: $draft');
          focused = null;
          continue;
        }
        if (result.action != 'submit' && result.action != 'command') {
          return InputEnded();
        }
        if (selectingRemoval || selectingEdit) {
          final index = int.tryParse(result.value);
          if (index == null || index < 1 || index > tags.length) {
            write('Select a listed tag number.');
            continue;
          }
          if (selectingRemoval) {
            write('Removed: ${tags.removeAt(index - 1)}');
            selectingRemoval = false;
          } else {
            editing = index - 1;
            draft = tags[editing];
            selectingEdit = false;
          }
          continue;
        }
        if (result.action == 'command' && result.value == '/done') {
          return Accepted(tags);
        }
        if (result.action == 'command' &&
            (result.value == '/list' ||
                result.value == '/remove' ||
                result.value == '/edit')) {
          for (var i = 0; i < tags.length; i++) {
            write('${i + 1}. ${tags[i]}');
          }
          if (result.value == '/remove' && tags.isNotEmpty) {
            selectingRemoval = true;
            write('Enter the number of the tag to remove.');
          } else if (result.value == '/edit' && tags.isNotEmpty) {
            selectingEdit = true;
            write('Enter the number of the tag to edit.');
          }
          continue;
        }
        if (RegExp(
          r'[^\p{L}\p{M}\p{N}\s_-]',
          unicode: true,
        ).hasMatch(result.value)) {
          write('Unsupported punctuation; edit the draft.');
          draft = result.value;
          continue;
        }
        if (!RegExp(
          r'^(?:[\p{L}\p{Nd}]\p{M}*|[\s_-])*$',
          unicode: true,
        ).hasMatch(result.value)) {
          write(
            'Combining marks must follow a letter or digit; edit the draft.',
          );
          draft = result.value;
          continue;
        }
        final value = _canonical(result.value);
        if (value.isEmpty) {
          write('Enter a tag, or use Finish (/done).');
          draft = result.value;
          continue;
        }
        final canonical = style == TagStyle.snakeCase
            ? value.replaceAll('-', '_')
            : value;
        if (maxLength != null && canonical.characters.length > maxLength!) {
          write('Maximum $maxLength graphemes; edit the draft.');
          draft = result.value;
          continue;
        }
        final validationError = validate?.call(canonical);
        if (validationError != null) {
          write(validationError);
          draft = result.value;
          continue;
        }
        if (tags.asMap().entries.any(
          (entry) => entry.key != editing && entry.value == canonical,
        )) {
          write('Duplicate tag; edit the draft.');
          draft = result.value;
          continue;
        }
        if (editing == null) {
          tags.add(canonical);
        } else {
          tags[editing] = canonical;
          editing = null;
        }
        draft = '';
        write('Added: $canonical');
      }
    } finally {
      if (keys == null) await inputKeys.close();
    }
  }
}
