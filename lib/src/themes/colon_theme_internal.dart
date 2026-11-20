/// Internal adaptive Colon presentation seam.
///
/// This library is deliberately absent from the public export barrel. It pairs
/// Colon's authored adaptive defaults with the already-merged owner and colour
/// resolution seams while the public factories keep their pre-cutover calls.
library;

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/color_theme.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/prompt_structure.dart';
import 'package:trelis/src/terminal_io.dart';
import 'package:trelis/src/text_input.dart'
    show InstructionDisplay, PromptResult, TextInput;
import 'package:trelis/src/theme_session.dart';

/// One authored RGB triple.
typedef ColonRgb = ({int red, int green, int blue});

/// The semantic roles authored for Colon's adaptive defaults.
enum ColonPaletteRole {
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

/// Colon's authored palette values and their contrast reference surfaces.
///
/// The palette itself requests the terminal's default background so the
/// terminal surface is never painted. The reference RGB values here are only
/// the known surfaces used for the 4.5:1 authored-pair calculation: Atelier
/// Sepia for light and a warm ink for dark. They are not a claim about any
/// actual terminal, custom palette, indexed colour or transparent surface.
final class ColonPaletteDefaults {
  static const lightReferenceBackground = (red: 244, green: 241, blue: 234);
  static const darkReferenceBackground = (red: 28, green: 30, blue: 36);

  static const lightRgb = <ColonPaletteRole, ColonRgb>{
    ColonPaletteRole.foreground: (red: 63, green: 58, blue: 51),
    ColonPaletteRole.muted: (red: 111, green: 103, blue: 92),
    ColonPaletteRole.accent: (red: 31, green: 95, blue: 139),
    ColonPaletteRole.success: (red: 63, green: 112, blue: 83),
    ColonPaletteRole.warning: (red: 138, green: 90, blue: 31),
    ColonPaletteRole.error: (red: 163, green: 59, blue: 59),
    ColonPaletteRole.border: (red: 117, green: 107, blue: 95),
    ColonPaletteRole.selectionForeground: (red: 255, green: 253, blue: 248),
    ColonPaletteRole.selectionBackground: (red: 31, green: 95, blue: 139),
  };

  static const darkRgb = <ColonPaletteRole, ColonRgb>{
    ColonPaletteRole.foreground: (red: 232, green: 226, blue: 215),
    ColonPaletteRole.muted: (red: 184, green: 175, blue: 163),
    ColonPaletteRole.accent: (red: 157, green: 195, blue: 240),
    ColonPaletteRole.success: (red: 159, green: 210, blue: 169),
    ColonPaletteRole.warning: (red: 229, green: 191, blue: 128),
    ColonPaletteRole.error: (red: 240, green: 164, blue: 164),
    ColonPaletteRole.border: (red: 146, green: 137, blue: 126),
    ColonPaletteRole.selectionForeground: (red: 16, green: 19, blue: 26),
    ColonPaletteRole.selectionBackground: (red: 157, green: 195, blue: 240),
  };

  static final light = _palette(lightRgb);
  static final dark = _palette(darkRgb);

  static ColorTheme _palette(Map<ColonPaletteRole, ColonRgb> rgb) => ColorTheme(
    foreground: _rgb(rgb[ColonPaletteRole.foreground]!),
    background: const TerminalColor.terminalDefault(),
    muted: _rgb(rgb[ColonPaletteRole.muted]!),
    accent: _rgb(rgb[ColonPaletteRole.accent]!),
    selectionForeground: _rgb(rgb[ColonPaletteRole.selectionForeground]!),
    selectionBackground: _rgb(rgb[ColonPaletteRole.selectionBackground]!),
    success: _rgb(rgb[ColonPaletteRole.success]!),
    warning: _rgb(rgb[ColonPaletteRole.warning]!),
    error: _rgb(rgb[ColonPaletteRole.error]!),
    border: _rgb(rgb[ColonPaletteRole.border]!),
  );

  static TerminalColor _rgb(ColonRgb value) =>
      TerminalColor.rgb(value.red, value.green, value.blue);
}

/// Drives real Colon components through the internal theme owner.
final class ColonInternalPresentation {
  ColonInternalPresentation({
    required TerminalEnvironment io,
    ColorPreferences colors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ColorDetectionFacts? colorFacts,
  }) : _owner = ThemeSession(
         environment: io,
         colors: colors,
         interaction: interaction,
         onResolved: onResolved,
         colorFacts: colorFacts,
         lightDefault: ColonPaletteDefaults.light,
         darkDefault: ColonPaletteDefaults.dark,
       );

  final ThemeSession _owner;

  /// A real Colon text input, with the typed diagnostic heading and palette.
  Future<PromptResult<String>> textInput(
    String label, {
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
  }) => _owner.prompt((handle) {
    return TextInput(
      label,
      initialValue: initialValue,
      required: required,
      validate: validate,
      maxLength: maxLength,
      structure: PromptStructure.colon,
      colors: _componentPalette(handle, colors),
      instructions: instructions,
    ).prompt(session: handle.session);
  });

  /// Layers one component's override over the period's resolved palette.
  ///
  /// Background and I/O stay owned by the period; a component cannot select a
  /// variant or change the environment through this seam.
  ColorTheme _componentPalette(
    ThemeSessionHandle handle,
    ComponentColors component,
  ) {
    final period = handle.colors;
    final background = switch (period.background) {
      BackgroundVariant.light => BackgroundPreference.light,
      BackgroundVariant.dark => BackgroundPreference.dark,
    };
    return resolveColors(
      facts: ColorDetectionFacts(
        outputProfile: period.outputProfile,
        noColor: handle.environment.environment['NO_COLOR'],
      ),
      lightDefault: period.palette,
      darkDefault: period.palette,
      preferences: ColorPreferences(background: background),
      component: component,
    ).palette;
  }
}
