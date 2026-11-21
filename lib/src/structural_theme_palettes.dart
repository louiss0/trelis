/// Adaptive light/dark default palettes for structural themes.
///
/// These values are internal until the coordinated public cutover. They are
/// authored in the Atelier warm-ink family: Atelier Sepia sets the light
/// direction and a warm charcoal balances the dark one, with rust as the Box
/// primary accent. The terminal surface role stays terminal-native so a theme
/// never paints the whole screen; the reference backgrounds below are the
/// declared surfaces for the authored normal-text contrast checks, not a claim
/// about any real terminal's background.
library;

import 'color_resolution.dart';
import 'color_theme.dart';

/// One structural theme's authored light and dark defaults.
final class StructuralThemePalettes {
  const StructuralThemePalettes._(this.light, this.dark);

  final ColorTheme light;
  final ColorTheme dark;

  /// The resolver defaults for this theme.
  ThemePaletteDefaults get defaults =>
      ThemePaletteDefaults(light: light, dark: dark);

  /// Box: square ruled enclosure with a rust accent.
  static final box = StructuralThemePalettes._(
    ColorTheme(
      foreground: TerminalColor.rgb(51, 41, 31),
      background: const TerminalColor.terminalDefault(),
      muted: TerminalColor.rgb(110, 96, 81),
      accent: TerminalColor.rgb(166, 69, 38),
      selectionForeground: TerminalColor.rgb(255, 253, 247),
      selectionBackground: TerminalColor.rgb(166, 69, 38),
      success: TerminalColor.rgb(47, 107, 70),
      warning: TerminalColor.rgb(138, 90, 22),
      error: TerminalColor.rgb(158, 47, 43),
      border: TerminalColor.rgb(122, 102, 80),
    ),
    ColorTheme(
      foreground: TerminalColor.rgb(243, 233, 220),
      background: const TerminalColor.terminalDefault(),
      muted: TerminalColor.rgb(187, 168, 150),
      accent: TerminalColor.rgb(232, 135, 90),
      selectionForeground: TerminalColor.rgb(30, 27, 25),
      selectionBackground: TerminalColor.rgb(232, 135, 90),
      success: TerminalColor.rgb(155, 200, 154),
      warning: TerminalColor.rgb(227, 183, 97),
      error: TerminalColor.rgb(242, 148, 134),
      border: TerminalColor.rgb(156, 132, 110),
    ),
  );
}

/// Declared reference surfaces for Box's authored normal-text pairs.
///
/// These are the RGB backgrounds used to check the 4.5:1 reference target. A
/// passing pair does not guarantee contrast on a terminal, a custom palette,
/// an indexed colour or a transparent surface.
abstract final class BoxPaletteReference {
  /// Atelier Sepia direction: warm paper, not a painted terminal surface.
  static const lightBackground = (red: 250, green: 244, blue: 232);

  /// Warm-ink dark direction.
  static const darkBackground = (red: 30, green: 27, blue: 25);
}
