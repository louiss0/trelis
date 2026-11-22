import 'color_theme.dart';
import 'output_profile.dart';
import 'text_input.dart' show PromptMode;

/// A screen-reader presentation request, independent of output capabilities.
enum ScreenReaderPreference { automatic, on, off }

/// A background request; automatic uses the supplied hint or falls back to dark.
enum BackgroundPreference { automatic, light, dark }

/// An observed or selected terminal background variant.
enum BackgroundVariant { light, dark }

/// Partial semantic palette values. Null means that the underlying role wins.
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

  /// Applies only the roles declared in this layer.
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

/// Presentation declarations for a session or invocation.
///
/// Null means inherited, including for the automatic settings: explicitly
/// requesting automatic at invocation level overrides a session declaration.
/// Palette and role declarations are selected independently. Invocation role
/// values win over session values; within each scope, variant roles win over
/// shared roles.
final class PresentationPreferences {
  const PresentationPreferences({
    this.screenReader,
    this.background,
    this.palette,
    this.lightPalette,
    this.darkPalette,
    this.roles,
    this.lightRoles,
    this.darkRoles,
  });

  final ScreenReaderPreference? screenReader;
  final BackgroundPreference? background;

  /// A replacement for either variant unless a more specific value is supplied.
  final ColorTheme? palette;
  final ColorTheme? lightPalette;
  final ColorTheme? darkPalette;
  final ColorRoleOverrides? roles;
  final ColorRoleOverrides? lightRoles;
  final ColorRoleOverrides? darkRoles;
}

/// Deterministic presentation decisions, not terminal detection or rendering.
final class ResolvedPresentation {
  const ResolvedPresentation._({
    required this.screenReader,
    required this.mode,
    required this.background,
    required this.palette,
    required this.outputProfile,
  });

  final bool screenReader;

  /// The selected interaction mode, not a guarantee that it is available.
  /// Explicit rich requests still require the existing availability checks.
  final PromptMode mode;
  final BackgroundVariant background;
  final ColorTheme palette;

  /// The supplied output facts with the non-empty NO_COLOR restriction applied.
  final OutputProfile outputProfile;
}

/// Resolves presentation from injected facts and declarations only.
///
/// [lightDefault] and [darkDefault] are the selected structural theme's
/// defaults; authoring and wiring those defaults is outside this resolver.
/// [screenReaderHint] is true, false, or unknown (null). [noColor] is the
/// environment value, not a request to read the process environment. The
/// [outputProfile] should already be resolved from output capability sources.
/// Automatic interaction uses its existing rich-interaction capability test.
/// Explicit rich interaction remains requested even when output does not
/// support it; integration must still run the existing availability checks.
/// An explicitly enabled screen reader conflicts with an explicit rich mode.
ResolvedPresentation resolvePresentation({
  required OutputProfile outputProfile,
  required ColorTheme lightDefault,
  required ColorTheme darkDefault,
  PresentationPreferences session = const PresentationPreferences(),
  PresentationPreferences invocation = const PresentationPreferences(),
  PromptMode sessionMode = PromptMode.automatic,
  PromptMode? invocationMode,
  bool? screenReaderHint,
  BackgroundVariant? backgroundHint,
  String? noColor,
}) {
  final preference =
      invocation.screenReader ??
      session.screenReader ??
      ScreenReaderPreference.automatic;
  final requestedMode = invocationMode ?? sessionMode;
  if (preference == ScreenReaderPreference.on &&
      requestedMode == PromptMode.rich) {
    throw ArgumentError(
      'Screen-reader presentation cannot be combined with explicit rich interaction.',
    );
  }
  final screenReader = switch (preference) {
    ScreenReaderPreference.on => true,
    ScreenReaderPreference.off => false,
    ScreenReaderPreference.automatic =>
      screenReaderHint == true && requestedMode != PromptMode.rich,
  };
  final mode = screenReader
      ? PromptMode.linear
      : switch (requestedMode) {
          PromptMode.rich => PromptMode.rich,
          PromptMode.linear => PromptMode.linear,
          PromptMode.automatic =>
            outputProfile.supportsRichInteraction
                ? PromptMode.rich
                : PromptMode.linear,
        };
  final background = switch (invocation.background ??
      session.background ??
      BackgroundPreference.automatic) {
    BackgroundPreference.light => BackgroundVariant.light,
    BackgroundPreference.dark => BackgroundVariant.dark,
    BackgroundPreference.automatic => backgroundHint ?? BackgroundVariant.dark,
  };
  final light = background == BackgroundVariant.light;
  var palette =
      (light ? invocation.lightPalette : invocation.darkPalette) ??
      invocation.palette ??
      (light ? session.lightPalette : session.darkPalette) ??
      session.palette ??
      (light ? lightDefault : darkDefault);
  for (final layer in [
    session.roles,
    light ? session.lightRoles : session.darkRoles,
    invocation.roles,
    light ? invocation.lightRoles : invocation.darkRoles,
  ]) {
    if (layer != null) palette = layer.apply(palette);
  }
  return ResolvedPresentation._(
    screenReader: screenReader,
    mode: mode,
    background: background,
    palette: palette,
    outputProfile: noColor?.isNotEmpty == true
        ? outputProfile.copyWith(colorDepth: ColorDepth.none)
        : outputProfile,
  );
}
