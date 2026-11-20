/// Internal, deterministic interaction resolution.
///
/// Preferences are application configuration; facts are injected observations
/// and output capabilities. Nothing in this library detects a screen reader,
/// queries a terminal, or changes the public API.
library;

import 'output_profile.dart';
import 'text_input.dart' show PromptMode;

/// Whether screen-reader presentation is automatic, requested, or declined.
enum ScreenReaderPreference { automatic, on, off }

/// Immutable application interaction configuration for a theme.
final class InteractionPreferences {
  const InteractionPreferences({
    this.mode = PromptMode.automatic,
    this.screenReader = ScreenReaderPreference.automatic,
  });

  /// The requested rich, linear, or automatic interaction direction.
  final PromptMode mode;

  /// The screen-reader presentation request.
  final ScreenReaderPreference screenReader;
}

/// An outcome of resolving interaction; only [ResolvedInteraction] is runnable.
sealed class InteractionResolution {
  const InteractionResolution._();
}

/// A runnable rich or linear interaction with a validated reader flag.
final class ResolvedInteraction extends InteractionResolution {
  ResolvedInteraction({required this.mode, required this.screenReader})
    : super._() {
    if (screenReader && mode != PromptMode.linear) {
      throw ArgumentError(
        'Screen-reader presentation requires linear interaction.',
      );
    }
  }

  /// The resolved interaction direction, not a usability guarantee.
  final PromptMode mode;

  /// Whether presentation should use the linear screen-reader form.
  final bool screenReader;
}

/// A configuration conflict that prevents any interaction output.
final class InteractionConflict extends InteractionResolution {
  const InteractionConflict(this.reason) : super._();

  /// A human-readable explanation of the conflicting requests.
  final String reason;
}

/// Immutable injected facts used by the internal resolver.
final class InteractionFacts {
  const InteractionFacts({this.output = const OutputProfile()});

  /// Capabilities already resolved for the selected output.
  final OutputProfile output;
}

/// Resolves [preferences] against injected [facts] without side effects.
InteractionResolution resolveInteraction({
  required InteractionPreferences preferences,
  required InteractionFacts facts,
}) => _InteractionResolver(preferences, facts).resolve();

/// Private state machine: each transition produces a non-runnable outcome or a
/// validated runnable interaction. No transition is exposed to callers.
final class _InteractionResolver {
  const _InteractionResolver(this._preferences, this._facts);

  final InteractionPreferences _preferences;
  final InteractionFacts _facts;

  InteractionResolution resolve() {
    final explicitRich = _preferences.mode == PromptMode.rich;
    if (_preferences.screenReader == ScreenReaderPreference.on &&
        explicitRich) {
      return const InteractionConflict(
        'Screen-reader presentation cannot be combined with explicit rich '
        'interaction.',
      );
    }

    final screenReader = _preferences.screenReader == ScreenReaderPreference.on;
    final mode = screenReader
        ? PromptMode.linear
        : switch (_preferences.mode) {
            PromptMode.rich => PromptMode.rich,
            PromptMode.linear => PromptMode.linear,
            PromptMode.automatic =>
              _facts.output.supportsRichInteraction
                  ? PromptMode.rich
                  : PromptMode.linear,
          };
    return ResolvedInteraction(mode: mode, screenReader: screenReader);
  }
}
