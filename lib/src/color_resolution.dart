import 'color_theme.dart';

/// The application's choice of terminal background for colour selection.
enum BackgroundPreference { automatic, light, dark }

/// The background variant a palette was resolved for.
enum BackgroundVariant { light, dark }

/// An injected observation about the terminal background.
///
/// Observations never query a terminal. Unavailable and malformed facts are
/// distinct from a valid variant so a bad observation cannot select a palette.
enum BackgroundObservation { light, dark, unavailable, malformed }

extension BackgroundObservationVariant on BackgroundObservation {
  /// The usable background variant, if this observation supplies one.
  BackgroundVariant? get variant => switch (this) {
    BackgroundObservation.light => BackgroundVariant.light,
    BackgroundObservation.dark => BackgroundVariant.dark,
    BackgroundObservation.unavailable ||
    BackgroundObservation.malformed => null,
  };
}

/// Converts a raw injected background fact without touching the terminal.
BackgroundObservation parseBackgroundObservation(String? fact) =>
    switch (fact) {
      'light' => BackgroundObservation.light,
      'dark' => BackgroundObservation.dark,
      null => BackgroundObservation.unavailable,
      _ => BackgroundObservation.malformed,
    };

/// Immutable facts supplied to colour resolution by its caller.
final class ColorDetectionFacts {
  const ColorDetectionFacts({this.passiveBackground, this.queriedBackground});

  /// A passive hint about the terminal background.
  final BackgroundObservation? passiveBackground;

  /// An observation from a bounded background query owned by the caller.
  ///
  /// Null means no observation was supplied. A malformed or unavailable
  /// observation must not select a background.
  final BackgroundObservation? queriedBackground;
}

/// Theme-level colour preferences.
///
/// These values are configured on a theme, never on a component invocation.
/// They do not own input, output, or terminal detection.
final class ColorPreferences {
  const ColorPreferences({this.background = BackgroundPreference.automatic});

  /// Explicit background choice, or automatic selection from injected facts.
  final BackgroundPreference background;
}

/// The resolved palette decision for one theme and component.
final class ResolvedColors {
  const ResolvedColors._({required this.background, required this.palette});

  final BackgroundVariant background;
  final ColorTheme palette;
}

/// Resolves colours from injected facts only.
///
/// [lightDefault] and [darkDefault] are the selected structural theme's
/// adaptive defaults. This function performs no terminal I/O and does not
/// author or qualify palettes.
ResolvedColors resolveColors({
  required ColorDetectionFacts facts,
  required ColorTheme lightDefault,
  required ColorTheme darkDefault,
  ColorPreferences preferences = const ColorPreferences(),
}) {
  final background = switch (preferences.background) {
    BackgroundPreference.light => BackgroundVariant.light,
    BackgroundPreference.dark => BackgroundVariant.dark,
    BackgroundPreference.automatic =>
      facts.queriedBackground?.variant ??
          facts.passiveBackground?.variant ??
          BackgroundVariant.dark,
  };
  return ResolvedColors._(
    background: background,
    palette: switch (background) {
      BackgroundVariant.light => lightDefault,
      BackgroundVariant.dark => darkDefault,
    },
  );
}
