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

/// Injectable reader and locality observations for one resolution.
final class NativeHintObservations {
  const NativeHintObservations({
    this.environment = const <String, String?>{},
    this.platform = HintPlatform.unsupported,
    this.interactive = false,
    this.localSessionAttested = false,
    this.readerProbe,
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

  /// Collects facts for one observation period.
  Future<InteractionFacts> facts({
    OutputProfile output = const OutputProfile(),
    bool interactionAvailable = true,
  }) async {
    return InteractionFacts(
      output: output,
      nativeHint: await _observeReader(),
      locality: _classifyLocality(),
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

  TerminalLocality _classifyLocality() {
    if (!interactive) return TerminalLocality.unknown;
    return localSessionAttested
        ? TerminalLocality.local
        : TerminalLocality.unknown;
  }
}
