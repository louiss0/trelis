/// Internal adaptive Bracket presentation seam.
///
/// This library is deliberately absent from the public export barrel. It pairs
/// Bracket's authored adaptive defaults with the already-merged owner and colour
/// resolution seams while the public factories keep their pre-cutover calls.
library;

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/color_theme.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/prompt_structure.dart';
import 'package:trelis/src/terminal_io.dart';
import 'package:trelis/src/text_input.dart'
    show
        Choice,
        InstructionDisplay,
        MultiSelect,
        PromptResult,
        Select,
        TextInput;
import 'package:trelis/src/theme_session.dart';

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

/// Drives real Bracket components through the internal theme owner.
final class BracketInternalPresentation {
  BracketInternalPresentation({
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
         lightDefault: BracketPaletteDefaults.light,
         darkDefault: BracketPaletteDefaults.dark,
       );

  final ThemeSession _owner;

  /// A real Bracket text input under the bracketed heading and palette.
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
      structure: PromptStructure.bracket,
      colors: _componentPalette(handle, colors),
      instructions: instructions,
    ).prompt(session: handle.session);
  });

  /// A real Bracket single-choice component under the bracketed heading.
  Future<PromptResult<T>> select<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
  }) => _owner.prompt((handle) {
    return Select<T>(
      label,
      choices,
      defaultValue: defaultValue,
      structure: PromptStructure.bracket,
      colors: _componentPalette(handle, colors),
      instructions: instructions,
    ).prompt(session: handle.session);
  });

  /// A real Bracket multi-selection with independent state markers.
  Future<PromptResult<List<T>>> multiSelect<T>(
    String label,
    List<Choice<T>> choices, {
    List<T> defaultValues = const [],
    int min = 0,
    int? max,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
  }) => _owner.prompt((handle) {
    return MultiSelect<T>(
      label,
      choices,
      defaultValues: defaultValues,
      min: min,
      max: max,
      structure: PromptStructure.bracket,
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
