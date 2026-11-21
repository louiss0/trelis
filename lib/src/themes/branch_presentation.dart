/// Internal adaptive presentation seam for the Branch structural theme.
///
/// This library is deliberately absent from the public export barrel. It lets
/// the Branch family exercise its authored defaults through real components
/// before the coordinated public cutover; it is not a stable public API.
library;

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/color_theme.dart';
import 'package:trelis/src/prompt_structure.dart';

/// The authored Branch defaults and the reference surfaces they were designed
/// against.
abstract final class BranchPresentation {
  /// Atelier Sepia warm ink with a deep plum primary accent.
  ///
  /// The terminal surface is not painted: [ColorTheme.background] stays
  /// terminal-native, and [referenceBackground] is only the documented RGB
  /// surface used for the authored-pair contrast target.
  static final lightDefault = ColorTheme(
    foreground: TerminalColor.rgb(55, 45, 40),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(98, 83, 77),
    accent: TerminalColor.rgb(125, 43, 96),
    selectionForeground: TerminalColor.rgb(255, 251, 246),
    selectionBackground: TerminalColor.rgb(125, 43, 96),
    success: TerminalColor.rgb(34, 103, 65),
    warning: TerminalColor.rgb(126, 74, 14),
    error: TerminalColor.rgb(157, 39, 50),
    border: TerminalColor.rgb(112, 92, 84),
  );

  /// Warm ink on a dark plum-tinted neutral with a bright plum accent.
  static final darkDefault = ColorTheme(
    foreground: TerminalColor.rgb(238, 232, 235),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(177, 165, 173),
    accent: TerminalColor.rgb(216, 150, 205),
    selectionForeground: TerminalColor.rgb(27, 24, 29),
    selectionBackground: TerminalColor.rgb(216, 150, 205),
    success: TerminalColor.rgb(150, 214, 172),
    warning: TerminalColor.rgb(240, 190, 120),
    error: TerminalColor.rgb(255, 145, 155),
    border: TerminalColor.rgb(145, 126, 140),
  );

  /// The authored reference surface for [background], not a surface request.
  static TerminalColor referenceBackground(BackgroundVariant background) =>
      switch (background) {
        BackgroundVariant.light => TerminalColor.rgb(246, 241, 232),
        BackgroundVariant.dark => TerminalColor.rgb(27, 24, 29),
      };

  /// Branch's title/continuation-line grammar.
  static const structure = PromptStructure.branch;
}
