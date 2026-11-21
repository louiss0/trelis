/// Internal adaptive Bracket presentation seam.
///
/// This library is deliberately absent from the public export barrel. It pairs
/// Bracket's authored adaptive defaults with the already-merged owner and colour
/// resolution seams while the public factories keep their pre-cutover calls.
library;

import 'package:trelis/src/color_theme.dart';

/// One authored RGB triple.
typedef BracketRgb = ({int red, int green, int blue});

/// The semantic roles authored for Bracket's adaptive defaults.
enum BracketPaletteRole {
  foreground,
  muted,
  accent,
  success,
  warning,
  error,
  border,
  selectionForeground,
  selectionBackground,
}

/// Bracket's authored palette values and their contrast reference surfaces.
///
/// The palette requests the terminal's default background so the terminal
/// surface is never painted. The reference RGB values below are only the known
/// surfaces used for the 4.5:1 authored-pair calculation: Atelier Sepia for
/// light and a warm ink for dark. They are not a claim about any actual
/// terminal, custom palette, indexed colour or transparent surface.
final class BracketPaletteDefaults {
  static const lightReferenceBackground = (red: 250, green: 244, blue: 232);
  static const darkReferenceBackground = (red: 30, green: 27, blue: 25);

  static const lightRgb = <BracketPaletteRole, BracketRgb>{
    BracketPaletteRole.foreground: (red: 48, green: 39, blue: 30),
    BracketPaletteRole.muted: (red: 104, green: 88, blue: 72),
    BracketPaletteRole.accent: (red: 166, green: 69, blue: 38),
    BracketPaletteRole.success: (red: 44, green: 102, blue: 68),
    BracketPaletteRole.warning: (red: 133, green: 86, blue: 20),
    BracketPaletteRole.error: (red: 156, green: 45, blue: 42),
    BracketPaletteRole.border: (red: 116, green: 96, blue: 75),
    BracketPaletteRole.selectionForeground: (red: 255, green: 253, blue: 247),
    BracketPaletteRole.selectionBackground: (red: 166, green: 69, blue: 38),
  };

  static const darkRgb = <BracketPaletteRole, BracketRgb>{
    BracketPaletteRole.foreground: (red: 243, green: 233, blue: 220),
    BracketPaletteRole.muted: (red: 184, green: 166, blue: 148),
    BracketPaletteRole.accent: (red: 232, green: 135, blue: 90),
    BracketPaletteRole.success: (red: 155, green: 200, blue: 154),
    BracketPaletteRole.warning: (red: 227, green: 183, blue: 97),
    BracketPaletteRole.error: (red: 242, green: 148, blue: 134),
    BracketPaletteRole.border: (red: 156, green: 132, blue: 110),
    BracketPaletteRole.selectionForeground: (red: 30, green: 27, blue: 25),
    BracketPaletteRole.selectionBackground: (red: 232, green: 135, blue: 90),
  };

  static final light = _palette(lightRgb);
  static final dark = _palette(darkRgb);

  static ColorTheme _palette(Map<BracketPaletteRole, BracketRgb> rgb) =>
      ColorTheme(
        foreground: _rgb(rgb[BracketPaletteRole.foreground]!),
        background: const TerminalColor.terminalDefault(),
        muted: _rgb(rgb[BracketPaletteRole.muted]!),
        accent: _rgb(rgb[BracketPaletteRole.accent]!),
        selectionForeground: _rgb(rgb[BracketPaletteRole.selectionForeground]!),
        selectionBackground: _rgb(rgb[BracketPaletteRole.selectionBackground]!),
        success: _rgb(rgb[BracketPaletteRole.success]!),
        warning: _rgb(rgb[BracketPaletteRole.warning]!),
        error: _rgb(rgb[BracketPaletteRole.error]!),
        border: _rgb(rgb[BracketPaletteRole.border]!),
      );

  static TerminalColor _rgb(BracketRgb value) =>
      TerminalColor.rgb(value.red, value.green, value.blue);
}
