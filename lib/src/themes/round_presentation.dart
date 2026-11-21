/// Internal adaptive presentation seam for the Round structural theme.
///
/// This library is deliberately absent from the public export barrel. It lets
/// the Round family exercise its authored defaults through real components
/// before the coordinated public cutover; it is not a stable public API.
library;

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/color_theme.dart';
import 'package:trelis/src/prompt_structure.dart';

/// The authored Round defaults and the reference surfaces they were designed
/// against.
abstract final class RoundPresentation {
  /// Atelier Sepia warm ink with a deep plum primary accent.
  ///
  /// The terminal surface is not painted: [ColorTheme.background] stays
  /// terminal-native, and [referenceBackground] is only the documented RGB
  /// surface used for the authored-pair contrast target.
  static final lightDefault = ColorTheme(
    foreground: TerminalColor.rgb(58, 46, 42),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(100, 84, 78),
    accent: TerminalColor.rgb(119, 39, 94),
    selectionForeground: TerminalColor.rgb(255, 250, 246),
    selectionBackground: TerminalColor.rgb(119, 39, 94),
    success: TerminalColor.rgb(30, 100, 62),
    warning: TerminalColor.rgb(124, 72, 12),
    error: TerminalColor.rgb(150, 35, 48),
    border: TerminalColor.rgb(107, 88, 82),
  );

  /// Warm ink on a dark plum-tinted neutral with a brighter plum accent.
  static final darkDefault = ColorTheme(
    foreground: TerminalColor.rgb(240, 232, 236),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(180, 166, 175),
    accent: TerminalColor.rgb(222, 146, 202),
    selectionForeground: TerminalColor.rgb(27, 24, 29),
    selectionBackground: TerminalColor.rgb(222, 146, 202),
    success: TerminalColor.rgb(150, 214, 172),
    warning: TerminalColor.rgb(240, 190, 120),
    error: TerminalColor.rgb(255, 145, 155),
    border: TerminalColor.rgb(147, 128, 142),
  );

  /// The authored reference surface for [background], not a surface request.
  static TerminalColor referenceBackground(BackgroundVariant background) =>
      switch (background) {
        BackgroundVariant.light => TerminalColor.rgb(246, 241, 232),
        BackgroundVariant.dark => TerminalColor.rgb(27, 24, 29),
      };

  /// Round's title/body enclosure grammar.
  static const structure = PromptStructure.round;
}
