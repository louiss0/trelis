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
  const _Participation(this.period, this.handle);

  final _ThemePeriod period;
  final ThemeSessionHandle handle;

  Future<void> release() => period.release();
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
  int _participants = 0;
  bool _accepting = true;

  bool get accepting => _accepting;

  void attach(TerminalSession value) => session = value;

  void setColors(ResolvedColors value) => colors = value;

  void publish() => owner._published = state;

  _Participation participate() {
    _participants++;
    return _Participation(this, ThemeSessionHandle._(this));
  }

  Future<void> release() async {
    _participants--;
    if (_participants <= 0) {
      if (!idle.isCompleted) idle.complete();
      await done;
    }
  }

  void stopAccepting() => _accepting = false;
}

/// Owns one environment and its lazily acquired active period.
final class ThemeSession {
  ThemeSession({
    required this.environment,
    this.interaction = const InteractionPreferences(),
    this.colors = const ColorPreferences(),
    this.onResolved,
    this.factsForPeriod,
    InteractionFacts? facts,
    ColorDetectionFacts? colorFacts,
  }) : _fixedFacts = facts,
       _fixedColorFacts = colorFacts;

  final TerminalEnvironment environment;
  final InteractionPreferences interaction;
  final ColorPreferences colors;
  final ThemeResolvedCallback? onResolved;
  final ThemeInteractionFactsProvider? factsForPeriod;
  final InteractionFacts? _fixedFacts;
  final ColorDetectionFacts? _fixedColorFacts;

  ThemeInteractionState? _published;
  _ThemePeriod? _active;
  Future<void>? _closing;

  /// The value published for the current active period, if one is running.
  ThemeInteractionState? get resolvedInteraction => _published;

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
      return await _finish(participation, runner);
    } on _InitializationUnavailable catch (error) {
      return Unavailable<T>(error.reason);
    } on _InitializationCancelled catch (_) {
      return Cancelled<T>();
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
      late final T result;
      try {
        result = await runner(participation.handle);
      } finally {
        await participation.release();
      }
      return result;
    } on _InitializationUnavailable catch (error) {
      throw ThemeSessionUnavailable(error.reason);
    } on _InitializationCancelled catch (_) {
      throw const ThemeSessionCancelled();
    }
  }

  Future<PromptResult<T>> _finish<T>(
    _Participation participation,
    Future<PromptResult<T>> Function(ThemeSessionHandle handle) runner,
  ) async {
    late final PromptResult<T> result;
    try {
      result = await runner(participation.handle);
    } finally {
      await participation.release();
    }
    return result;
  }

  Future<_Participation> _enter(
    ThemeOperationKind kind,
    ThemeComponentAvailability availability,
    Future<void>? cancellation,
  ) async {
    final current = _active;
    if (current != null && current.accepting) {
      if (!availability.allows(kind)) {
        throw _InitializationUnavailable(availability.reason);
      }
      return current.participate();
    }
    final closing = _closing;
    if (closing != null) await closing;
    return await _start(kind, availability, cancellation);
  }

  Future<_Participation> _start(
    ThemeOperationKind kind,
    ThemeComponentAvailability availability,
    Future<void>? cancellation,
  ) async {
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
      onError: (Object _, StackTrace _) => _finishPeriod(period, closed),
    );
    try {
      await started.future;
      return period.participate();
    } catch (_) {
      await closed.future;
      rethrow;
    }
  }

  Future<InteractionFacts> _facts(Future<void>? cancellation) async {
    try {
      final provider = factsForPeriod;
      if (provider == null) {
        return _fixedFacts ?? _defaultFacts;
      }
      return await _race(() => provider(environment), cancellation);
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

  void _finishPeriod(_ThemePeriod period, Completer<void> closed) {
    period.stopAccepting();
    if (identical(_published, period.state)) _published = null;
    if (identical(_active, period)) _active = null;
    if (identical(_closing, closed.future)) _closing = null;
    if (!closed.isCompleted) closed.complete();
  }
}
