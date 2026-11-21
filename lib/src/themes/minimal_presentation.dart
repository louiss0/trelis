/// Internal adaptive presentation seam for the Minimal structural theme.
///
/// This library is deliberately absent from the public export barrel. It lets
/// the Minimal family exercise its authored defaults through real components
/// before the coordinated public cutover; it is not a stable public API.
library;

import '../color_resolution.dart';
import '../color_theme.dart';
import '../prompt_structure.dart';

/// The authored Minimal defaults and the reference surfaces they were designed
/// against.
abstract final class MinimalPresentation {
  /// Atelier Sepia warm ink with a deep sepia primary accent.
  ///
  /// The terminal surface is not painted: [ColorTheme.background] stays
  /// terminal-native, and [referenceBackground] is only the documented RGB
  /// surface used for the authored-pair contrast target.
  static final lightDefault = ColorTheme(
    foreground: TerminalColor.rgb(54, 43, 34),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(96, 80, 68),
    accent: TerminalColor.rgb(126, 72, 20),
    selectionForeground: TerminalColor.rgb(255, 251, 244),
    selectionBackground: TerminalColor.rgb(126, 72, 20),
    success: TerminalColor.rgb(26, 92, 57),
    warning: TerminalColor.rgb(128, 74, 8),
    error: TerminalColor.rgb(150, 36, 40),
    border: TerminalColor.rgb(112, 92, 74),
  );

  /// Warm ink on a dark sepia-tinted neutral with a brighter sepia accent.
  static final darkDefault = ColorTheme(
    foreground: TerminalColor.rgb(244, 236, 224),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(190, 174, 156),
    accent: TerminalColor.rgb(214, 158, 97),
    selectionForeground: TerminalColor.rgb(30, 26, 22),
    selectionBackground: TerminalColor.rgb(214, 158, 97),
    success: TerminalColor.rgb(146, 210, 164),
    warning: TerminalColor.rgb(238, 188, 112),
    error: TerminalColor.rgb(250, 146, 138),
    border: TerminalColor.rgb(158, 138, 118),
  );

  /// The authored reference surface for [background], not a surface request.
  static TerminalColor referenceBackground(BackgroundVariant background) =>
      switch (background) {
        BackgroundVariant.light => TerminalColor.rgb(245, 238, 225),
        BackgroundVariant.dark => TerminalColor.rgb(30, 26, 22),
      };

  /// Minimal's unframed conversational question and answer.
  static const structure = PromptStructure.minimal;
}
