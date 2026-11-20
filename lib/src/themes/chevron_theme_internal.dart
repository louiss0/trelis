/// Internal adaptive Chevron presentation seam.
///
/// This library is deliberately absent from the public export barrel. It pairs
/// Chevron's authored adaptive defaults with the already-merged owner and
/// colour resolution seams while the public factories keep their pre-cutover
/// calls.
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

/// Drives real Chevron components through the internal theme owner.
final class ChevronInternalPresentation {
  ChevronInternalPresentation({
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
         lightDefault: ChevronPaletteDefaults.light,
         darkDefault: ChevronPaletteDefaults.dark,
       );

  final ThemeSession _owner;

  /// A real Chevron text input, with the Chevron heading and resolved palette.
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
      structure: PromptStructure.chevron,
      colors: _componentPalette(handle, colors),
      instructions: instructions,
    ).prompt(session: handle.session);
  });

  /// A real Chevron single-choice component under the Chevron heading.
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
      structure: PromptStructure.chevron,
      colors: _componentPalette(handle, colors),
      instructions: instructions,
    ).prompt(session: handle.session);
  });

  /// A real Chevron multi-selection, with separate default and draft markers.
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
      structure: PromptStructure.chevron,
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
