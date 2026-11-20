import 'color_theme.dart';
import 'output_profile.dart';

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
  const ColorDetectionFacts({
    this.outputProfile = const OutputProfile(),
    this.noColor,
    this.passiveBackground,
    this.queriedBackground,
  });

  /// The already-resolved output capabilities for the selected output.
  final OutputProfile outputProfile;

  /// The injected `NO_COLOR` environment value, never read from the process.
  final String? noColor;

  /// A passive hint about the terminal background.
  final BackgroundObservation? passiveBackground;

  /// An observation from a bounded background query owned by the caller.
  ///
  /// Null means no observation was supplied. A malformed or unavailable
  /// observation must not select a background.
  final BackgroundObservation? queriedBackground;
}

/// Partial semantic palette values. Null roles leave the underlying role.
final class ColorRoleOverrides {
  const ColorRoleOverrides({
    this.foreground,
    this.background,
    this.muted,
    this.accent,
    this.selectionForeground,
    this.selectionBackground,
    this.success,
    this.warning,
    this.error,
    this.border,
  });

  final TerminalColor? foreground;
  final TerminalColor? background;
  final TerminalColor? muted;
  final TerminalColor? accent;
  final TerminalColor? selectionForeground;
  final TerminalColor? selectionBackground;
  final TerminalColor? success;
  final TerminalColor? warning;
  final TerminalColor? error;
  final TerminalColor? border;

  /// Applies only the declared roles over [base].
  ColorTheme apply(ColorTheme base) => base.copyWith(
    foreground: foreground,
    background: background,
    muted: muted,
    accent: accent,
    selectionForeground: selectionForeground,
    selectionBackground: selectionBackground,
    success: success,
    warning: warning,
    error: error,
    border: border,
  );
}

/// Reusable colour declarations for one scope.
///
/// A whole-palette replacement discards the underlying palette and all of its
/// role overrides in the same scope. Role overrides without a replacement
/// layer over the inherited palette. Variant declarations apply only to the
/// selected background.
final class ComponentColors {
  const ComponentColors({
    this.palette,
    this.lightPalette,
    this.darkPalette,
    this.roles,
    this.lightRoles,
    this.darkRoles,
  });

  /// Convenience constructor for replacing a whole palette.
  const ComponentColors.palette(ColorTheme palette) : this(palette: palette);

  final ColorTheme? palette;
  final ColorTheme? lightPalette;
  final ColorTheme? darkPalette;
  final ColorRoleOverrides? roles;
  final ColorRoleOverrides? lightRoles;
  final ColorRoleOverrides? darkRoles;

  /// The whole-palette replacement for [background], if one was supplied.
  ColorTheme? replacementFor(BackgroundVariant background) =>
      switch (background) {
        BackgroundVariant.light => lightPalette ?? palette,
        BackgroundVariant.dark => darkPalette ?? palette,
      };

  /// The variant-specific role overrides for [background].
  ColorRoleOverrides? rolesFor(BackgroundVariant background) =>
      switch (background) {
        BackgroundVariant.light => lightRoles,
        BackgroundVariant.dark => darkRoles,
      };
}

/// Theme-level colour preferences.
///
/// These values are configured on a theme, never on a component invocation.
/// They do not own input, output, or terminal detection. [colors] carries the
/// application's palette replacement and role overrides.
final class ColorPreferences {
  const ColorPreferences({
    this.background = BackgroundPreference.automatic,
    this.allowBackgroundQuery = true,
    this.colors = const ComponentColors(),
  });

  /// Explicit background choice, or automatic selection from injected facts.
  final BackgroundPreference background;

  /// Whether the theme may request a bounded background query later.
  final bool allowBackgroundQuery;

  /// The application-level palette replacement and role overrides.
  final ComponentColors colors;
}

/// The resolved palette decision for one theme and component.
final class ResolvedColors {
  const ResolvedColors._({
    required this.background,
    required this.palette,
    required this.outputProfile,
    required this.shouldQueryBackground,
  });

  final BackgroundVariant background;
  final ColorTheme palette;

  /// The selected output facts with `NO_COLOR` and unknown depth applied.
  final OutputProfile outputProfile;

  /// Whether a caller may attempt a background query.
  ///
  /// This is resolver-level eligibility only: it does not query a terminal,
  /// own a session, or cache an attempt across active periods.
  final bool shouldQueryBackground;
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
  ComponentColors? component,
}) {
  final restricted = facts.noColor?.isNotEmpty == true;
  final declaredDepth = facts.outputProfile.colorDepth;
  final effectiveDepth = restricted || declaredDepth == ColorDepth.automatic
      ? ColorDepth.none
      : declaredDepth;
  final effectiveProfile = effectiveDepth == declaredDepth
      ? facts.outputProfile
      : facts.outputProfile.copyWith(colorDepth: effectiveDepth);

  final background = switch (preferences.background) {
    BackgroundPreference.light => BackgroundVariant.light,
    BackgroundPreference.dark => BackgroundVariant.dark,
    BackgroundPreference.automatic =>
      facts.queriedBackground?.variant ??
          facts.passiveBackground?.variant ??
          BackgroundVariant.dark,
  };

  final app = preferences.colors;
  final componentReplacement = component?.replacementFor(background);
  late ColorTheme palette;
  if (componentReplacement != null) {
    // A component replacement discards the complete effective app palette,
    // including its shared and variant role overrides.
    palette = componentReplacement;
  } else {
    palette =
        app.replacementFor(background) ??
        switch (background) {
          BackgroundVariant.light => lightDefault,
          BackgroundVariant.dark => darkDefault,
        };
    final appRoles = app.roles;
    if (appRoles != null) palette = appRoles.apply(palette);
    final appVariantRoles = app.rolesFor(background);
    if (appVariantRoles != null) palette = appVariantRoles.apply(palette);
  }

  final componentRoles = component?.roles;
  if (componentRoles != null) palette = componentRoles.apply(palette);
  final componentVariantRoles = component?.rolesFor(background);
  if (componentVariantRoles != null) {
    palette = componentVariantRoles.apply(palette);
  }

  final mayQuery =
      preferences.background == BackgroundPreference.automatic &&
      preferences.allowBackgroundQuery &&
      !restricted &&
      effectiveDepth != ColorDepth.none &&
      facts.queriedBackground == null;

  return ResolvedColors._(
    background: background,
    palette: palette,
    outputProfile: effectiveProfile,
    shouldQueryBackground: mayQuery,
  );
}
