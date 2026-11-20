/// Internal theme-owned active period.
///
/// The first prompt or feedback operation resolves interaction, invokes the
/// application callback and acquires the owned terminal before anything is
/// rendered. Later operations join the same period; the last one to finish
/// restores the terminal and clears the published value. This library is not
/// exported from the public barrel.
library;

import 'dart:async';

import 'background_query.dart';
import 'color_resolution.dart';
import 'color_theme.dart';
import 'feedback.dart' show Text;
import 'hint_observations.dart';
import 'interaction_resolution.dart';
import 'shared_terminal.dart';
import 'terminal_io.dart';
import 'text_input.dart'
    show Cancelled, PromptMode, PromptResult, TerminalSession, Unavailable;

/// The read-only interaction published for one active period.
final class ThemeInteractionState {
  const ThemeInteractionState._({
    required this.mode,
    required this.screenReader,
  });

  final PromptMode mode;
  final bool screenReader;

  @override
  String toString() =>
      'ThemeInteractionState(mode: $mode, screenReader: $screenReader)';
}

/// Which kind of component entered an active period.
enum ThemeOperationKind { prompt, feedback }

/// Per-operation availability of the component that starts work.
final class ThemeComponentAvailability {
  const ThemeComponentAvailability({
    this.prompt = true,
    this.feedback = true,
    this.reason = 'The requested component is unavailable.',
  });

  final bool prompt;
  final bool feedback;
  final String reason;

  /// Whether this availability allows [kind].
  bool allows(ThemeOperationKind kind) => switch (kind) {
    ThemeOperationKind.prompt => prompt,
    ThemeOperationKind.feedback => feedback,
  };
}

/// A non-runnable or unavailable request reported through feedback.
final class ThemeSessionUnavailable implements Exception {
  const ThemeSessionUnavailable(this.reason);

  /// A human-readable explanation, safe to show without rendering output.
  final String reason;

  @override
  String toString() => 'ThemeSessionUnavailable: $reason';
}

/// A cancellation observed before an active period published its value.
final class ThemeSessionCancelled implements Exception {
  const ThemeSessionCancelled();

  @override
  String toString() => 'ThemeSessionCancelled: initialization was cancelled.';
}

final class _InitializationUnavailable implements Exception {
  const _InitializationUnavailable(this.reason);
  final String reason;
}

final class _InitializationCancelled implements Exception {
  const _InitializationCancelled();
}

/// Observes a successful resolution before the first output of a period.
typedef ThemeResolvedCallback = FutureOr<void> Function(
  ResolvedInteraction interaction,
);

/// Supplies injected interaction facts for one active period.
typedef ThemeInteractionFactsProvider = FutureOr<InteractionFacts> Function(
  TerminalEnvironment io,
);

final class _Participation {
  _Participation(this.owner, this.period, this.handle, this.kind);

  final ThemeSession owner;
  final _ThemePeriod period;
  final ThemeSessionHandle handle;
  final ThemeOperationKind kind;
  bool _released = false;

  /// Set when its runner has settled, even if cleanup is still awaited.
  bool runnerFinished = false;

  /// Ends this participation once, letting cleanup continue in the background.
  Future<void> release() async {
    if (_released) return;
    _released = true;
    try {
      await period.release();
    } finally {
      owner._endParticipation(this);
    }
  }
}

/// One live feedback participant in an active period.
///
/// The participant is independent of the prompt and stays active until it is
/// finished. Finishing runs the component's own end action and its stop
/// action, retires the region, and releases this participant; cleanup only
/// happens once the prompt and every feedback participant have left.
final class ThemeFeedbackHandle {
  ThemeFeedbackHandle._(this._owner, this._participation, this._stop);

  final ThemeSession _owner;
  final _Participation _participation;
  final FutureOr<void> Function() _stop;
  bool _finished = false;

  /// The handle created when this participant entered the period.
  ThemeSessionHandle get handle => _participation.handle;

  /// The session-owned terminal used by the feedback component.
  TerminalSession get session => handle.session;

  /// Ends this participant once, preserving [end]'s primary failure.
  Future<void> finish([FutureOr<void> Function()? end]) async {
    if (_finished) return;
    _finished = true;
    Object? primary;
    StackTrace? primaryStackTrace;

    Future<void> capture(FutureOr<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        primary ??= error;
        primaryStackTrace ??= stackTrace;
      }
    }

    if (end != null) await capture(end);
    await capture(_stop);
    await _owner._releaseAfter(_participation, primary, primaryStackTrace);
    if (primary != null) {
      Error.throwWithStackTrace(primary!, primaryStackTrace!);
    }
  }
}

/// The internal handle a component uses while it participates in a period.
final class ThemeSessionHandle {
  const ThemeSessionHandle._(this._period);

  final _ThemePeriod _period;

  /// The session that owns input, output and live feedback for this period.
  TerminalSession get session => _period.session;

  /// The validated interaction resolved before this period's first output.
  ResolvedInteraction get interaction => _period.interaction;

  /// The environment selected for this theme.
  TerminalEnvironment get environment => _period.owner.environment;

  /// The color decision resolved from injected facts for this period.
  ResolvedColors get colors => _period.colors;

  /// Runs internal delegation without opening another active prompt.
  Future<T> delegate<T>(
    FutureOr<T> Function(ThemeSessionHandle handle) operation,
  ) async => await operation(this);
}

final class _ThemePeriod {
  _ThemePeriod(this.owner, this.interaction, this.state, this.colors);

  final ThemeSession owner;
  final ResolvedInteraction interaction;
  final ThemeInteractionState state;
  // Set once from resolver facts before the period publishes its value.
  ResolvedColors colors;
  final Completer<void> idle = Completer<void>();

  late final TerminalSession session;
  late final Future<void> done;
  Object? cleanupError;
  StackTrace? cleanupStackTrace;
  int _participants = 0;
  bool _accepting = false;

  /// Whether a new operation may join this period.
  ///
  /// A period is not accepting while it initializes or while its last
  /// participant has released but cleanup is still running.
  bool get accepting => _accepting;

  void attach(TerminalSession value) => session = value;

  void setColors(ResolvedColors value) => colors = value;

  void publish() => owner._published = state;

  void beginAccepting() => _accepting = true;

  void stopAccepting() => _accepting = false;

  _Participation participate(ThemeOperationKind kind) {
    _participants++;
    return _Participation(owner, this, ThemeSessionHandle._(this), kind);
  }

  /// Marks the period as idle immediately, before cleanup starts.
  ///
  /// The owner stops handing out this period as soon as its last participant
  /// ends, so a new start waits for [_closing] instead of joining one that is
  /// already releasing its resources.
  Future<void> release() async {
    _participants--;
    if (_participants <= 0) {
      stopAccepting();
      owner._periodIdle(this);
      if (!idle.isCompleted) idle.complete();
      await done;
    }
  }

  /// Ends a period that failed before it acquired a participant.
  void abandon() {
    stopAccepting();
    owner._periodIdle(this);
    if (!idle.isCompleted) idle.complete();
  }
}

/// Owns one environment and its lazily acquired active period.
final class ThemeSession {
  ThemeSession({
    required this.environment,
    this.interaction = const InteractionPreferences(),
    this.colors = const ColorPreferences(),
    this.onResolved,
    this.onCleanupError,
    this.factsForPeriod,
    this.hints,
    InteractionFacts? facts,
    ColorDetectionFacts? colorFacts,
  }) : _fixedFacts = facts,
       _fixedColorFacts = colorFacts;

  final TerminalEnvironment environment;
  final InteractionPreferences interaction;
  final ColorPreferences colors;
  final ThemeResolvedCallback? onResolved;

  /// Observes a cleanup failure that did not replace a primary result.
  final void Function(Object error, StackTrace stackTrace)? onCleanupError;

  final ThemeInteractionFactsProvider? factsForPeriod;

  /// Injectable hint observations collected once for each active period.
  ///
  /// An explicit [factsForPeriod] source takes precedence; fixed facts remain
  /// available for deterministic tests that need no observations.
  final NativeHintObservations? hints;
  final InteractionFacts? _fixedFacts;
  final ColorDetectionFacts? _fixedColorFacts;

  ThemeInteractionState? _published;
  _ThemePeriod? _active;
  Future<void>? _closing;
  Future<void> _turn = Future<void>.value();
  _Participation? _promptParticipation;
  Object? _lastCleanupError;
  StackTrace? _lastCleanupStackTrace;
  final List<Object> _cleanupFailures = <Object>[];

  /// Identifiable environments cannot run overlapping active periods.
  static final Map<Object, _ThemePeriod> _identityOwners =
      <Object, _ThemePeriod>{};
  static Future<void> _identityTurn = Future<void>.value();

  /// The value published for the current active period, if one is running.
  ThemeInteractionState? get resolvedInteraction => _published;

  /// Cleanup failures retained after a successful primary operation.
  List<Object> get cleanupFailures =>
      List<Object>.unmodifiable(_cleanupFailures);

  Object? get lastCleanupError => _lastCleanupError;
  StackTrace? get lastCleanupStackTrace => _lastCleanupStackTrace;

  /// Runs one prompt through the common first-operation path.
  Future<PromptResult<T>> prompt<T>(
    Future<PromptResult<T>> Function(ThemeSessionHandle handle) runner, {
    ThemeComponentAvailability availability =
        const ThemeComponentAvailability(),
    Future<void>? cancellation,
  }) async {
    try {
      final participation = await _enter(
        ThemeOperationKind.prompt,
        availability,
        cancellation,
      );
      return await _runParticipation(participation, runner);
    } on _InitializationUnavailable catch (error) {
      return Unavailable<T>(error.reason);
    } on _InitializationCancelled catch (_) {
      return Cancelled<T>();
    }
  }

  /// Presents one informational feedback line through an owned session.
  ///
  /// The period is acquired and resolved before [feedback] renders, and is
  /// released once its write settles. This is the internal one-shot seam for
  /// theme-created feedback; it does not add a public call signature.
  Future<void> presentFeedback(
    Text feedback, {
    ThemeComponentAvailability availability =
        const ThemeComponentAvailability(),
    Future<void>? cancellation,
  }) async {
    try {
      final participation = await _enter(
        ThemeOperationKind.feedback,
        availability,
        cancellation,
      );
      await _runParticipation(participation, (handle) {
        feedback.present(session: handle.session);
      });
    } on _InitializationUnavailable catch (error) {
      throw ThemeSessionUnavailable(error.reason);
    } on _InitializationCancelled catch (_) {
      throw const ThemeSessionCancelled();
    }
  }

  /// Starts live feedback that participates in the current active period.
  ///
  /// Initialization completes before [start] can emit output. The returned
  /// handle must be finished when the component stops, completes or fails; its
  /// [ThemeFeedbackHandle.finish] also invokes [stop] so producers and their
  /// timers cannot outlive the participant.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
    ThemeComponentAvailability availability =
        const ThemeComponentAvailability(),
    Future<void>? cancellation,
  }) async {
    try {
      final participation = await _enter(
        ThemeOperationKind.feedback,
        availability,
        cancellation,
      );
      try {
        await start(participation.handle);
      } catch (error, stackTrace) {
        await _releaseAfter(participation, error, stackTrace);
        Error.throwWithStackTrace(error, stackTrace);
      }
      return ThemeFeedbackHandle._(this, participation, stop);
    } on _InitializationUnavailable catch (error) {
      throw ThemeSessionUnavailable(error.reason);
    } on _InitializationCancelled catch (_) {
      throw const ThemeSessionCancelled();
    }
  }

  /// Runs one feedback operation through the common first-operation path.
  Future<T> feedback<T>(
    FutureOr<T> Function(ThemeSessionHandle handle) runner, {
    ThemeComponentAvailability availability =
        const ThemeComponentAvailability(),
    Future<void>? cancellation,
  }) async {
    try {
      final participation = await _enter(
        ThemeOperationKind.feedback,
        availability,
        cancellation,
      );
      return await _runParticipation(participation, runner);
    } on _InitializationUnavailable catch (error) {
      throw ThemeSessionUnavailable(error.reason);
    } on _InitializationCancelled catch (_) {
      throw const ThemeSessionCancelled();
    }
  }

  /// Runs [runner], awaiting cleanup without erasing its primary outcome.
  Future<T> _runParticipation<T>(
    _Participation participation,
    FutureOr<T> Function(ThemeSessionHandle handle) runner,
  ) async {
    late final T result;
    Object? primaryError;
    StackTrace? primaryStackTrace;
    try {
      result = await runner(participation.handle);
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }
    participation.runnerFinished = true;
    await _releaseAfter(participation, primaryError, primaryStackTrace);
    if (primaryError != null) {
      Error.throwWithStackTrace(primaryError, primaryStackTrace!);
    }
    return result;
  }

  /// A successful result survives cleanup failure; a primary failure keeps
  /// both causes through [TerminalSessionCleanupException].
  Future<void> _releaseAfter(
    _Participation participation,
    Object? primaryError,
    StackTrace? primaryStackTrace,
  ) async {
    try {
      await participation.release();
    } catch (cleanupError, cleanupStackTrace) {
      if (!identical(cleanupError, participation.period.cleanupError)) {
        _recordCleanupFailure(cleanupError, cleanupStackTrace);
      }
      if (primaryError != null) {
        throw TerminalSessionCleanupException(primaryError, cleanupError);
      }
    }
  }

  Future<_Participation> _enter(
    ThemeOperationKind kind,
    ThemeComponentAvailability availability,
    Future<void>? cancellation,
  ) async {
    final turn = await _takeTurn();
    try {
      while (true) {
        final runningPrompt = _promptParticipation;
        if (kind == ThemeOperationKind.prompt &&
            runningPrompt != null &&
            !runningPrompt.runnerFinished) {
          throw const _InitializationUnavailable(
            'A prompt is already active for this theme.',
          );
        }
        final current = _active;
        if (current != null && current.accepting) {
          if (!availability.allows(kind)) {
            throw _InitializationUnavailable(availability.reason);
          }
          return _participate(current, kind);
        }
        final closing = _closing;
        if (closing != null) {
          await closing;
          continue;
        }
        return _participate(
          await _start(kind, availability, cancellation),
          kind,
        );
      }
    } finally {
      turn.complete();
    }
  }

  _Participation _participate(_ThemePeriod period, ThemeOperationKind kind) {
    final participation = period.participate(kind);
    if (kind == ThemeOperationKind.prompt) {
      _promptParticipation = participation;
    }
    return participation;
  }

  /// Serializes period entry and cleanup waiting for one theme.
  Future<Completer<void>> _takeTurn() async {
    final previous = _turn;
    final next = Completer<void>();
    _turn = next.future;
    await previous;
    return next;
  }

  Future<_ThemePeriod> _start(
    ThemeOperationKind kind,
    ThemeComponentAvailability availability,
    Future<void>? cancellation,
  ) async {
    // Conflicts are immutable preference errors, so no observation period
    // starts for them.
    final early = resolveInteraction(
      preferences: interaction,
      facts: const InteractionFacts(interactionAvailable: false),
    );
    if (early is InteractionConflict) {
      throw _InitializationUnavailable(early.reason);
    }

    final facts = await _facts(cancellation);
    final resolution = resolveInteraction(
      preferences: interaction,
      facts: facts,
    );
    final resolved = switch (resolution) {
      ResolvedInteraction() => resolution,
      InteractionConflict(:final reason) ||
      InteractionUnavailable(
        :final reason,
      ) => throw _InitializationUnavailable(reason),
    };
    if (resolved.mode == PromptMode.rich &&
        !environment.profile.supportsRichInteraction) {
      throw const _InitializationUnavailable(
        'Rich interaction is unavailable on the selected output.',
      );
    }
    if (!availability.allows(kind)) {
      throw _InitializationUnavailable(availability.reason);
    }

    final colorFacts = _fixedColorFacts ?? _defaultColorFacts;
    final initialColors = resolveColors(
      facts: colorFacts,
      lightDefault: ColorThemes.terminalDefault,
      darkDefault: ColorThemes.terminalDefault,
      preferences: colors,
    );
    final period = _ThemePeriod(
      this,
      resolved,
      ThemeInteractionState._(
        mode: resolved.mode,
        screenReader: resolved.screenReader,
      ),
      initialColors,
    );
    final identity = environment.ownershipIdentity;
    if (identity != null && !await _claimIdentity(identity, period)) {
      throw const _InitializationUnavailable(
        'This terminal already has an active theme owner.',
      );
    }
    _active = period;
    final started = Completer<_ThemePeriod>();
    final closed = Completer<void>();
    _closing = closed.future;
    final done = TerminalSession.run(
      (session) async {
        period.attach(session);
        try {
          final lease = environment.acquire();
          await SharedTerminalLease.restoreAfter(() async {
            var facts = colorFacts;
            if (_mayQueryBackground(initialColors)) {
              final observation = await _race(
                () => session.queryBackground(),
                cancellation,
              );
              if (observation != BackgroundQueryResult.unavailable) {
                facts = _withQueriedBackground(colorFacts, observation);
              }
            }
            period.setColors(
              resolveColors(
                facts: facts,
                lightDefault: ColorThemes.terminalDefault,
                darkDefault: ColorThemes.terminalDefault,
                preferences: colors,
              ),
            );
            final callback = onResolved;
            if (callback != null) {
              await _race<void>(() async {
                await callback(resolved);
              }, cancellation);
            }
            await _checkCancellation(cancellation);
            period.publish();
            period.beginAccepting();
            started.complete(period);
            await period.idle.future;
          }, lease.restore);
        } catch (error, stackTrace) {
          if (!started.isCompleted) started.completeError(error, stackTrace);
          rethrow;
        }
      },
      terminal: environment,
      mode: resolved.mode,
    );
    period.done = done;
    done.then(
      (_) => _finishPeriod(period, closed),
      onError: (Object error, StackTrace stackTrace) {
        period.cleanupError = error;
        period.cleanupStackTrace = stackTrace;
        _recordCleanupFailure(error, stackTrace);
        _finishPeriod(period, closed);
      },
    );
    try {
      await started.future;
      return period;
    } catch (error, stackTrace) {
      period.abandon();
      await closed.future;
      if (error is TerminalRestorationException) {
        throw TerminalSessionCleanupException(
          error.operationError,
          error.restorationError,
        );
      }
      final cleanup = period.cleanupError;
      if (cleanup != null && !identical(cleanup, error)) {
        throw TerminalSessionCleanupException(error, cleanup);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Claims an identifiable terminal for one period across theme instances.
  Future<bool> _claimIdentity(Object identity, _ThemePeriod period) async {
    final previous = _identityTurn;
    final next = Completer<void>();
    _identityTurn = next.future;
    await previous;
    try {
      if (_identityOwners.containsKey(identity)) return false;
      _identityOwners[identity] = period;
      return true;
    } finally {
      next.complete();
    }
  }

  Future<InteractionFacts> _facts(Future<void>? cancellation) async {
    try {
      final provider = factsForPeriod;
      if (provider != null) {
        return await _race(() => provider(environment), cancellation);
      }
      final hintSource = hints;
      if (hintSource != null) {
        return await _race(
          () => hintSource.facts(
            output: environment.profile,
            environment: environment.environment,
          ),
          cancellation,
        );
      }
      return _fixedFacts ?? _defaultFacts;
    } on _InitializationCancelled {
      rethrow;
    } catch (_) {
      // A failed observation source is unknown, never an interaction failure.
      return _defaultFacts;
    }
  }

  /// Runs [action], letting a cancellation win without publishing its value.
  Future<T> _race<T>(
    FutureOr<T> Function() action,
    Future<void>? cancellation,
  ) async {
    final computation = Future<T>.value(action());
    if (cancellation == null) return await computation;
    final cancelled = Completer<T>();
    final registration = cancellation.then(
      (_) {
        if (!cancelled.isCompleted) {
          cancelled.completeError(const _InitializationCancelled());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!cancelled.isCompleted) {
          cancelled.completeError(error, stackTrace);
        }
      },
    );
    try {
      return await Future.any<T>([computation, cancelled.future]);
    } finally {
      registration.ignore();
    }
  }

  /// Checks whether cancellation arrived while an earlier step was running.
  Future<void> _checkCancellation(Future<void>? cancellation) async {
    if (cancellation == null) return;
    var cancelled = false;
    final registration = cancellation.then(
      (_) => cancelled = true,
      onError: (Object _, StackTrace _) => cancelled = true,
    );
    await Future<void>.delayed(Duration.zero);
    registration.ignore();
    if (cancelled) throw const _InitializationCancelled();
  }

  /// Whether one bounded query is allowed in this active period.
  ///
  /// The resolver already applies explicit choice, query disablement,
  /// `NO_COLOR` and colour depth. The remaining facts ensure the selected
  /// output is an interactive terminal rather than a redirected sink.
  bool _mayQueryBackground(ResolvedColors initial) =>
      initial.shouldQueryBackground &&
      environment.environment['NO_COLOR']?.isNotEmpty != true &&
      environment.supportsRich &&
      environment.profile.supportsRichInteraction;

  ColorDetectionFacts _withQueriedBackground(
    ColorDetectionFacts base,
    BackgroundQueryResult result,
  ) {
    final observation = switch (result) {
      BackgroundQueryResult.light => BackgroundObservation.light,
      BackgroundQueryResult.dark => BackgroundObservation.dark,
      BackgroundQueryResult.unavailable => null,
    };
    return ColorDetectionFacts(
      outputProfile: base.outputProfile,
      noColor: base.noColor,
      passiveBackground: base.passiveBackground,
      queriedBackground: observation,
    );
  }

  ColorDetectionFacts get _defaultColorFacts => ColorDetectionFacts(
    outputProfile: environment.profile,
    noColor: environment.environment['NO_COLOR'],
  );

  InteractionFacts get _defaultFacts => InteractionFacts(
    output: environment.profile,
    interactive: environment.supportsRich,
  );

  /// Stops handing out a period as soon as its last participant leaves.
  void _periodIdle(_ThemePeriod period) {
    if (identical(_active, period)) _active = null;
  }

  void _endParticipation(_Participation participation) {
    if (identical(_promptParticipation, participation)) {
      _promptParticipation = null;
    }
  }

  void _recordCleanupFailure(Object error, StackTrace stackTrace) {
    _cleanupFailures.add(error);
    _lastCleanupError = error;
    _lastCleanupStackTrace = stackTrace;
    final callback = onCleanupError;
    if (callback == null) return;
    try {
      callback(error, stackTrace);
    } catch (_) {
      // A diagnostics callback must not change the cleanup outcome.
    }
  }

  void _finishPeriod(_ThemePeriod period, Completer<void> closed) {
    period.stopAccepting();
    if (identical(_published, period.state)) _published = null;
    if (identical(_active, period)) _active = null;
    if (identical(_closing, closed.future)) _closing = null;
    final identity = environment.ownershipIdentity;
    if (identity != null && identical(_identityOwners[identity], period)) {
      _identityOwners.remove(identity);
    }
    if (!closed.isCompleted) closed.complete();
  }
}
