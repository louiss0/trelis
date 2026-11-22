import 'dart:async';
import 'dart:io';

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
  /// the host process. A non-empty `NO_COLOR` is applied as a hard colour
  /// restriction before an invocation resolves its profile, so a declared
  /// colour depth cannot re-enable colour. The remaining values are
  /// observations: no profile fact is resolved from them yet.
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

/// An internal binding of input, one selected output, that output's declared
/// profile, acquisition and a stable ownership identity when one is available.
///
/// This is a theme-owner seam, not invocation-level prompt configuration: the
/// future public API passes one environment to a theme instance. Callers of
/// the current component API can still pass it as a [TerminalIo] adapter until
/// the coordinated cutover. A null [ownershipIdentity] means the environment
/// cannot identify the shared terminal; two such wrappers may overlap
/// unnoticed.
///
/// Externally supplied streams stay open by default. Supplying [closeInput]
/// transfers ownership: the environment then closes it at most once when the
/// acquired lease is restored or acquisition fails. Cancelling the reader's
/// subscription can still invoke the caller stream's own cancellation behavior;
/// that is distinct from the environment closing the stream.
final class TerminalEnvironment implements TerminalIo, TerminalIoOutputProfile {
  TerminalEnvironment._({
    required this.input,
    required this.output,
    this._profile,
    required this.ownershipIdentity,
    this.environment = const <String, String?>{},
    this._supportsRich,
    required this._acquire,
    this.closeInput,
    this.usesNativeConsole = false,
  });

  /// Declares the conservative profile for observed native-output facts.
  ///
  /// A redirected or otherwise non-interactive output does not gain cursor,
  /// geometry, alternate-screen or colour capability from a caller's rich
  /// hint. Geometry and terminal-style observations are hints; they never
  /// enlarge an output that reports itself as redirected.
  static OutputProfile nativeProfile({
    required bool hasTerminal,
    required bool supportsRich,
    String term = '',
    int? columns,
    int? rows,
    bool colorDisabled = false,
  }) {
    final capable = hasTerminal && term != 'dumb';
    final rich = capable && supportsRich;
    final usableGeometry =
        hasTerminal &&
        columns != null &&
        columns > 0 &&
        rows != null &&
        rows > 0;
    return OutputProfile(
      cursor: rich
          ? CapabilitySupport.supported
          : CapabilitySupport.unsupported,
      alternateScreen:
          rich &&
              (Platform.isWindows ||
                  RegExp(r'^(xterm|screen|tmux|rxvt)(-|$)').hasMatch(term))
          ? CapabilitySupport.supported
          : CapabilitySupport.unsupported,
      geometry: usableGeometry
          ? OutputGeometry.fixed(columns: columns, rows: rows)
          : const OutputGeometry.automatic(),
      colorDepth: capable && !colorDisabled
          ? ColorDepth.automatic
          : ColorDepth.none,
    );
  }

  /// Observes terminal facts for one native [output] under [observations].
  ///
  /// A redirected or otherwise non-interactive output reports no terminal
  /// capability. Geometry probing is fallible; a failed probe leaves geometry
  /// unknown rather than failing the environment.
  static OutputProfile _observedNativeProfile(
    Stdout output,
    Map<String, String?> observations, {
    String? term,
    bool? supportsRich,
  }) {
    final selectedTerm = term ?? observations['TERM'] ?? '';
    int? columns;
    int? rows;
    if (output.hasTerminal) {
      try {
        columns = output.terminalColumns;
        rows = output.terminalLines;
      } on FileSystemException {
        // Capability probing is fallible; geometry remains unknown.
      } on UnsupportedError {
        // Capability probing is fallible; geometry remains unknown.
      }
    }
    return nativeProfile(
      hasTerminal: output.hasTerminal,
      supportsRich:
          supportsRich ?? (output.hasTerminal && selectedTerm != 'dumb'),
      term: selectedTerm,
      columns: columns,
      rows: rows,
      colorDisabled:
          !output.hasTerminal || observations['NO_COLOR']?.isNotEmpty == true,
    );
  }

  /// Binds an observed native selected output and its acquisition callback.
  ///
  /// Acquisition belongs to the shared terminal seam; this environment records
  /// its lease without creating a second native reader. The selected [output]
  /// is the default identity because it is a stable object for one process.
  factory TerminalEnvironment.native({
    required Stream<String> input,
    required Stdout output,
    required TerminalLease Function() acquire,
    Object? ownershipIdentity,
    void Function()? closeInput,
    Map<String, String?>? environment,
    OutputProfile? profile,
    String? term,
    bool? supportsRich,
  }) {
    final observations = environment ?? Platform.environment;
    final selectedProfile =
        profile ??
        _observedNativeProfile(
          output,
          observations,
          term: term,
          supportsRich: supportsRich,
        );
    return TerminalEnvironment._(
      input: input,
      output: output,
      profile: selectedProfile,
      ownershipIdentity: ownershipIdentity ?? output,
      environment: observations,
      supportsRich:
          supportsRich ?? selectedProfile.cursor == CapabilitySupport.supported,
      acquire: acquire,
      closeInput: closeInput,
    );
  }

  /// Adapts a native or custom [adapter] without changing its public contract.
  ///
  /// A [profile] override is the explicit seam for scripted declarations; an
  /// adapter without a declared profile remains automatic. An explicit
  /// [ownershipIdentity] overrides one the adapter exposes.
  factory TerminalEnvironment.custom({
    required TerminalIo adapter,
    OutputProfile? profile,
    Object? ownershipIdentity,
    Map<String, String?>? environment,
    bool? supportsRich,
    void Function()? closeInput,
  }) => TerminalEnvironment._(
    input: adapter.input,
    output: adapter.output,
    profile:
        profile ??
        (adapter is TerminalIoOutputProfile
            ? (adapter as TerminalIoOutputProfile).outputProfile
            : const OutputProfile()),
    ownershipIdentity:
        ownershipIdentity ??
        (adapter is TerminalOwnershipIdentity
            ? (adapter as TerminalOwnershipIdentity).ownershipIdentity
            : null),
    environment: environment ?? adapter.environment,
    supportsRich: supportsRich ?? adapter.supportsRich,
    acquire: adapter.acquire,
    closeInput: closeInput,
  );

  /// The default environment for public theme instances.
  ///
  /// This keeps native acquisition, geometry and colour derivation in the
  /// terminal seam so the public theme surface exposes no invocation-level I/O
  /// configuration.
  static TerminalEnvironment nativeThemeDefault({Stdout? output}) {
    final selected = output ?? stdout;
    return TerminalEnvironment._(
      input: const Stream<String>.empty(),
      output: selected,
      ownershipIdentity: selected,
      environment: Map.unmodifiable(Platform.environment),
      acquire: () => TerminalLease(null),
      usesNativeConsole: true,
    );
  }

  /// Binds scripted or explicitly declared I/O without native acquisition.
  factory TerminalEnvironment.scripted({
    required Stream<String> input,
    required StringSink output,
    OutputProfile profile = const OutputProfile(),
    Object? ownershipIdentity,
    Map<String, String?> environment = const <String, String?>{},
    bool? supportsRich,
    void Function()? closeInput,
  }) => TerminalEnvironment._(
    input: input,
    output: output,
    profile: profile,
    ownershipIdentity: ownershipIdentity,
    environment: environment,
    supportsRich: supportsRich,
    acquire: () => TerminalLease(null),
    closeInput: closeInput,
  );

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  final OutputProfile? _profile;

  /// The declared capabilities of [output].
  ///
  /// A native console marker has no stored profile: the getter re-observes
  /// the selected output each call so terminal, geometry and colour facts
  /// reflect the console at use rather than at theme creation.
  OutputProfile get profile {
    final stored = _profile;
    if (stored != null) return stored;
    return _observedNativeProfile(output as Stdout, environment);
  }

  /// Whether prompts must use the handle-preserving native console path.
  ///
  /// Only [nativeThemeDefault] selects this; scripted and custom adapters can
  /// never opt into native console input. The marker's empty input stream is
  /// never subscribed: each prompt acquires its own native transport.
  final bool usesNativeConsole;

  @override
  OutputProfile get outputProfile => profile;

  /// A stable identity for coordination, or null when unavailable.
  ///
  /// Callers that wrap the same resource should supply the same value. Distinct
  /// wrappers without a shared identity cannot be proven to refer to one
  /// physical terminal.
  final Object? ownershipIdentity;

  @override
  final Map<String, String?> environment;

  final bool? _supportsRich;

  @override
  bool get supportsRich =>
      _supportsRich ?? profile.cursor == CapabilitySupport.supported;

  /// Closes an externally supplied stream only when ownership was transferred.
  final void Function()? closeInput;

  final TerminalLease Function() _acquire;
  bool _inputClosed = false;

  void _closeInputOnce() {
    if (_inputClosed) return;
    _inputClosed = true;
    closeInput?.call();
  }

  @override
  TerminalLease acquire() {
    late final TerminalLease delegate;
    try {
      delegate = _acquire();
    } catch (error, stackTrace) {
      try {
        _closeInputOnce();
      } catch (_) {
        // The acquisition failure remains the primary error.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    return TerminalLease(() {
      Object? failure;
      StackTrace? failureStackTrace;
      try {
        delegate.restore();
      } catch (error, stackTrace) {
        failure = error;
        failureStackTrace = stackTrace;
      }
      try {
        _closeInputOnce();
      } catch (error, stackTrace) {
        failure ??= error;
        failureStackTrace ??= stackTrace;
      }
      if (failure != null) {
        Error.throwWithStackTrace(failure, failureStackTrace!);
      }
    });
  }
}

/// Optional stable identity for a terminal adapter.
///
/// Adapters that wrap the same physical terminal should expose the same value.
/// An adapter that cannot make that guarantee should not implement this
/// interface; distinct unidentifiable wrappers may overlap undetected.
abstract interface class TerminalOwnershipIdentity {
  Object? get ownershipIdentity;
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
