/// Internal adaptive Plain defaults in the Atelier warm-ink family.
///
/// Light starts from Atelier Sepia and both variants use sepia as the primary
/// accent. The palettes are deliberately not exported from the public barrel:
/// this is the pre-cutover internal seam, not a stable public API.
library;

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/color_theme.dart';

/// The documented light reference surface: warm sepia paper.
///
/// The palette leaves the terminal's real background untouched. This RGB value
/// is only the reference used for authored-pair contrast checks; it is never
/// painted by a default component.
const (int, int, int) plainLightReferenceRgb = (244, 236, 216);

/// The documented dark reference surface: warm Atelier ink.
const (int, int, int) plainDarkReferenceRgb = (27, 26, 24);

/// Resolves Plain's adaptive defaults through the shared colour resolver.
///
/// This is a pure decision: it reads only [facts] and never queries a terminal.
ResolvedColors resolvePlainColors({
  ColorDetectionFacts facts = const ColorDetectionFacts(),
  ColorPreferences preferences = const ColorPreferences(),
  ComponentColors? component,
}) => resolveColors(
  facts: facts,
  lightDefault: PlainSepiaPalettes.light,
  darkDefault: PlainSepiaPalettes.dark,
  preferences: preferences,
  component: component,
);

/// The adaptive default palettes for Plain.
final class PlainSepiaPalettes {
  const PlainSepiaPalettes._();

  /// Warm ink on sepia paper, with a dark sepia accent.
  ///
  /// [ColorTheme.background] remains terminal-default so no default rendering
  /// paints the terminal surface. The highlight pair is a localized exception.
  static final light = ColorTheme(
    foreground: TerminalColor.rgb(55, 45, 35),
    background: const TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(99, 84, 66),
    accent: TerminalColor.rgb(128, 74, 28),
    selectionForeground: TerminalColor.rgb(250, 244, 232),
    selectionBackground: TerminalColor.rgb(128, 74, 28),
    success: TerminalColor.rgb(48, 104, 67),
    warning: TerminalColor.rgb(126, 80, 18),
    error: TerminalColor.rgb(158, 49, 45),
    border: TerminalColor.rgb(116, 99, 78),
  );

  /// Light warm ink on dark Atelier ink, with a lit sepia accent.
  static final dark = ColorTheme(
    foreground: TerminalColor.rgb(236, 225, 207),
    background: const TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(181, 165, 141),
    accent: TerminalColor.rgb(222, 168, 103),
    selectionForeground: TerminalColor.rgb(37, 28, 20),
    selectionBackground: TerminalColor.rgb(222, 168, 103),
    success: TerminalColor.rgb(137, 200, 142),
    warning: TerminalColor.rgb(224, 179, 101),
    error: TerminalColor.rgb(238, 129, 118),
    border: TerminalColor.rgb(160, 142, 118),
  );
}
