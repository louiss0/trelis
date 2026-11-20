/// Internal adaptive Chevron presentation seam.
///
/// This library is deliberately absent from the public export barrel. It pairs
/// Chevron's authored adaptive defaults with the already-merged owner and
/// colour resolution seams while the public factories keep their pre-cutover
/// calls.
library;

import 'package:trelis/src/color_theme.dart';

/// One authored RGB triple.
typedef ChevronRgb = ({int red, int green, int blue});

/// The semantic roles authored for Chevron's adaptive defaults.
enum ChevronPaletteRole {
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

/// Chevron's authored palette values and their contrast reference surfaces.
///
/// The palette itself requests the terminal's default background so the
/// terminal surface is never painted. The reference RGB values here are only
/// the known surfaces used for the 4.5:1 authored-pair calculation: Atelier
/// Sepia for light and a warm ink for dark. They are not a claim about any
/// actual terminal, custom palette, indexed colour or transparent surface.
final class ChevronPaletteDefaults {
  static const lightReferenceBackground = (red: 244, green: 241, blue: 234);
  static const darkReferenceBackground = (red: 28, green: 30, blue: 36);

  static const lightRgb = <ChevronPaletteRole, ChevronRgb>{
    ChevronPaletteRole.foreground: (red: 63, green: 58, blue: 51),
    ChevronPaletteRole.muted: (red: 111, green: 103, blue: 92),
    ChevronPaletteRole.accent: (red: 31, green: 95, blue: 139),
    ChevronPaletteRole.success: (red: 63, green: 112, blue: 83),
    ChevronPaletteRole.warning: (red: 138, green: 90, blue: 31),
    ChevronPaletteRole.error: (red: 163, green: 59, blue: 59),
    ChevronPaletteRole.border: (red: 117, green: 107, blue: 95),
    ChevronPaletteRole.selectionForeground: (red: 255, green: 253, blue: 248),
    ChevronPaletteRole.selectionBackground: (red: 31, green: 95, blue: 139),
  };

  static const darkRgb = <ChevronPaletteRole, ChevronRgb>{
    ChevronPaletteRole.foreground: (red: 232, green: 226, blue: 215),
    ChevronPaletteRole.muted: (red: 184, green: 175, blue: 163),
    ChevronPaletteRole.accent: (red: 157, green: 195, blue: 240),
    ChevronPaletteRole.success: (red: 159, green: 210, blue: 169),
    ChevronPaletteRole.warning: (red: 229, green: 191, blue: 128),
    ChevronPaletteRole.error: (red: 240, green: 164, blue: 164),
    ChevronPaletteRole.border: (red: 146, green: 137, blue: 126),
    ChevronPaletteRole.selectionForeground: (red: 16, green: 19, blue: 26),
    ChevronPaletteRole.selectionBackground: (red: 157, green: 195, blue: 240),
  };

  static final light = _palette(lightRgb);
  static final dark = _palette(darkRgb);

  static ColorTheme _palette(Map<ChevronPaletteRole, ChevronRgb> rgb) =>
      ColorTheme(
        foreground: _rgb(rgb[ChevronPaletteRole.foreground]!),
        background: const TerminalColor.terminalDefault(),
        muted: _rgb(rgb[ChevronPaletteRole.muted]!),
        accent: _rgb(rgb[ChevronPaletteRole.accent]!),
        selectionForeground: _rgb(rgb[ChevronPaletteRole.selectionForeground]!),
        selectionBackground: _rgb(rgb[ChevronPaletteRole.selectionBackground]!),
        success: _rgb(rgb[ChevronPaletteRole.success]!),
        warning: _rgb(rgb[ChevronPaletteRole.warning]!),
        error: _rgb(rgb[ChevronPaletteRole.error]!),
        border: _rgb(rgb[ChevronPaletteRole.border]!),
      );

  static TerminalColor _rgb(ChevronRgb value) =>
      TerminalColor.rgb(value.red, value.green, value.blue);
}
