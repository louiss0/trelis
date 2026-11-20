/// Internal, injectable observations for automatic screen-reader hints.
///
/// Nothing in this library queries a native API, reads a file, launches a
/// subprocess, or changes the public barrel. Callers inject already-observed
/// outcomes; the library classifies them into the facts consumed by the
/// deterministic interaction resolver.
library;

import 'dart:async';

import 'interaction_resolution.dart';
import 'output_profile.dart';

/// Platform families with distinct documented reader-signal support.
enum HintPlatform { windows, macos, linux, unsupported }

/// Maps a platform name to a documented hint family; anything else is
/// unsupported. Linux has no established general-purpose signal here.
HintPlatform platformFromName(String name) => switch (name.toLowerCase()) {
  'windows' => HintPlatform.windows,
  'macos' => HintPlatform.macos,
  'linux' => HintPlatform.linux,
  _ => HintPlatform.unsupported,
};

/// An injected native reader query for one observation period.
///
/// Only [ScreenReaderObservation.positive] can enable an automatic hint.
/// A thrown query is recorded as [ScreenReaderObservation.failed].
typedef NativeReaderProbe = FutureOr<ScreenReaderObservation> Function(
  HintPlatform platform,
);

/// The outcome of an injected Windows remote-session locality check.
///
/// [RemoteSessionObservation.remote] is a positive remote observation.
/// [RemoteSessionObservation.failed] is a failed required supported check and
/// is therefore ambiguous. Every other value is neutral, never proof of a
/// local session.
enum RemoteSessionObservation {
  remote,
  notRemote,
  failed,
  unavailable,
  unknown,
}

/// The outcome of an injected container-indicator check.
///
/// Only [ContainerObservation.detected] is ambiguous. An unavailable or
/// absent check does not veto another locality observation or an application
/// hint.
enum ContainerObservation { detected, absent, unavailable, unknown }

/// An injected Windows remote-session query for one observation period.
typedef RemoteSessionProbe = FutureOr<RemoteSessionObservation> Function(
  HintPlatform platform,
);

/// An injected container-indicator query for one observation period.
typedef ContainerProbe = FutureOr<ContainerObservation> Function();

/// Injectable reader and locality observations for one resolution.
///
/// Exact indicators classified here: non-empty `SSH_CONNECTION`, `SSH_CLIENT`
/// or `SSH_TTY` are remote; a positive Windows remote-session probe is remote.
/// Non-empty `TMUX`, `TMUX_PANE`, `STY`, `WINDOW` or systemd `container`, a
/// positive container probe, or a failed required remote-session probe are
/// ambiguous. No `/.dockerenv`, cgroup parsing, or subprocess check is used.
/// These are inherited, forgeable indicators of a transport layer, not
/// authentication of the current viewer; their absence proves no locality.
final class NativeHintObservations {
  const NativeHintObservations({
    this.environment = const <String, String?>{},
    this.platform = HintPlatform.unsupported,
    this.interactive = false,
    this.localSessionAttested = false,
    this.readerProbe,
    this.remoteSessionProbe,
    this.containerProbe,
  });

  /// Environment values supplied by the caller, never read here.
  final Map<String, String?> environment;

  /// The platform whose native signals the caller may have observed.
  final HintPlatform platform;

  /// Whether the terminal session accepts interactive input.
  final bool interactive;

  /// Positive caller-supplied evidence that output is consumed locally.
  ///
  /// Missing SSH, multiplexer, RDP, and container indicators are not proof of
  /// locality; therefore this defaults to false and leaves native hints
  /// ineligible until such evidence is supplied.
  final bool localSessionAttested;

  /// An optional native reader query, called only on Windows or macOS.
  final NativeReaderProbe? readerProbe;

  /// An optional Windows remote-session query, called only on Windows.
  final RemoteSessionProbe? remoteSessionProbe;

  /// An optional container-indicator query, never backed by a subprocess.
  final ContainerProbe? containerProbe;

  /// Collects facts for one observation period.
  Future<InteractionFacts> facts({
    OutputProfile output = const OutputProfile(),
    Map<String, String?>? environment,
    bool interactionAvailable = true,
  }) async {
    final effectiveEnvironment = environment ?? this.environment;
    return InteractionFacts(
      output: output,
      nativeHint: await _observeReader(),
      locality: await _classifyLocality(effectiveEnvironment),
      interactive: interactive,
      interactionAvailable: interactionAvailable,
    );
  }

  Future<ScreenReaderObservation> _observeReader() async {
    if (platform != HintPlatform.windows && platform != HintPlatform.macos) {
      return ScreenReaderObservation.unknown;
    }
    final probe = readerProbe;
    if (probe == null) return ScreenReaderObservation.unknown;
    try {
      return await probe(platform);
    } catch (_) {
      return ScreenReaderObservation.failed;
    }
  }

  Future<TerminalLocality> _classifyLocality(
    Map<String, String?> environment,
  ) async {
    if (!interactive) return TerminalLocality.unknown;

    // Non-empty OpenSSH variables identify SSH provenance. Their absence is
    // never treated as positive evidence of locality.
    if (_hasAny(environment, const [
      'SSH_CONNECTION',
      'SSH_CLIENT',
      'SSH_TTY',
    ])) {
      return TerminalLocality.remote;
    }

    final remoteSession = await _observeRemoteSession();
    if (remoteSession == RemoteSessionObservation.remote) {
      return TerminalLocality.remote;
    }

    // tmux and GNU screen can have multiple clients or later reattachment,
    // so inherited indicators cannot establish who currently reads output.
    if (_hasAny(environment, const ['TMUX', 'TMUX_PANE', 'STY', 'WINDOW']) ||
        await _observeContainer(environment) == ContainerObservation.detected ||
        remoteSession == RemoteSessionObservation.failed) {
      return TerminalLocality.ambiguous;
    }

    return localSessionAttested
        ? TerminalLocality.local
        : TerminalLocality.unknown;
  }

  bool _hasAny(Map<String, String?> environment, List<String> keys) =>
      keys.any((key) => (environment[key] ?? '').trim().isNotEmpty);

  Future<RemoteSessionObservation> _observeRemoteSession() async {
    if (platform != HintPlatform.windows) {
      return RemoteSessionObservation.unavailable;
    }
    final probe = remoteSessionProbe;
    if (probe == null) return RemoteSessionObservation.unavailable;
    try {
      return await probe(platform);
    } catch (_) {
      return RemoteSessionObservation.failed;
    }
  }

  Future<ContainerObservation> _observeContainer(
    Map<String, String?> environment,
  ) async {
    if (_hasAny(environment, const ['container'])) {
      return ContainerObservation.detected;
    }
    final probe = containerProbe;
    if (probe == null) return ContainerObservation.unknown;
    try {
      return await probe();
    } catch (_) {
      return ContainerObservation.unavailable;
    }
  }
}
