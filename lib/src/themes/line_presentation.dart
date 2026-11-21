/// Internal adaptive presentation seam for the Line structural theme.
///
/// This library is deliberately absent from the public export barrel. It lets
/// the Line family exercise its authored defaults through real components
/// before the coordinated public cutover; it is not a stable public API.
library;

import '../color_resolution.dart';
import '../color_theme.dart';

/// The authored Line defaults and the reference surfaces they were designed
/// against.
abstract final class LinePresentation {
  /// Atelier Sepia warm ink with a deep plum primary accent.
  ///
  /// The terminal surface is not painted: [ColorTheme.background] stays
  /// terminal-native, and [referenceBackground] is only the documented RGB
  /// surface used for the authored-pair contrast target.
  static final lightDefault = ColorTheme(
    foreground: TerminalColor.rgb(52, 40, 36),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(92, 78, 72),
    accent: TerminalColor.rgb(112, 34, 88),
    selectionForeground: TerminalColor.rgb(255, 250, 246),
    selectionBackground: TerminalColor.rgb(112, 34, 88),
    success: TerminalColor.rgb(28, 96, 60),
    warning: TerminalColor.rgb(120, 68, 10),
    error: TerminalColor.rgb(146, 32, 44),
    border: TerminalColor.rgb(101, 82, 76),
  );

  /// Warm ink on a dark plum-tinted neutral with a brighter plum accent.
  static final darkDefault = ColorTheme(
    foreground: TerminalColor.rgb(242, 234, 238),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(182, 168, 177),
    accent: TerminalColor.rgb(214, 139, 196),
    selectionForeground: TerminalColor.rgb(29, 25, 31),
    selectionBackground: TerminalColor.rgb(214, 139, 196),
    success: TerminalColor.rgb(148, 212, 168),
    warning: TerminalColor.rgb(238, 186, 116),
    error: TerminalColor.rgb(252, 142, 152),
    border: TerminalColor.rgb(151, 132, 146),
  );

  /// The authored reference surface for [background], not a surface request.
  static TerminalColor referenceBackground(BackgroundVariant background) =>
      switch (background) {
        BackgroundVariant.light => TerminalColor.rgb(246, 241, 232),
        BackgroundVariant.dark => TerminalColor.rgb(29, 25, 31),
      };
}
