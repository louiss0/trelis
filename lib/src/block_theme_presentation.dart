/// Internal Block-specific adaptive presentation seam.
///
/// The public [BlockTheme] factory namespace stays unchanged until the
/// coordinated cutover. This library composes the existing theme owner with
/// Block's adaptive defaults and real components so palette and structure
/// behavior can be exercised before the public API changes.
library;

import 'dart:async';

import 'color_resolution.dart';
import 'color_theme.dart';
import 'interaction_resolution.dart';
import 'prompt_structure.dart';
import 'terminal_io.dart';
import 'text_input.dart'
    show
        Choice,
        InstructionDisplay,
        MultiSelect,
        PromptMode,
        PromptResult,
        TextInput;
import 'theme_session.dart';

/// One authored normal-text role and the reference surface it was chosen for.
///
/// The reference background is a documented test surface, not a claim about an
/// actual terminal's background. Chrome roles such as [ColorTheme.border] are
/// deliberately excluded from the normal-text contrast target.
final class BlockTextSwatch {
  const BlockTextSwatch({
    required this.role,
    required this.color,
    required this.rgb,
    required this.reference,
  });

  final String role;
  final TerminalColor color;
  final (int, int, int) rgb;
  final (int, int, int) reference;
}

/// Block's Atelier warm-ink defaults, with rust as the primary accent.
///
/// Both palettes leave the terminal's own background alone; the recorded
/// reference backgrounds are the known RGB surfaces used for the authored-pair
/// contrast test. Explicit terminal-native colors remain available through
/// [ColorThemes.terminalDefault].
final class BlockAdaptivePalettes {
  BlockAdaptivePalettes._();

  /// Atelier Sepia's warm parchment starting point for the light variant.
  static const lightReference = (0xf4, 0xee, 0xdf);

  /// A warm ink surface for the dark variant.
  static const darkReference = (0x1b, 0x1a, 0x18);

  static const _lightForeground = (0x40, 0x38, 0x2e);
  static const _lightMuted = (0x6d, 0x62, 0x54);
  static const _lightAccent = (0x9a, 0x43, 0x25);
  static const _lightSelectionForeground = (0xff, 0xf8, 0xee);
  static const _lightSelectionBackground = (0x8a, 0x3f, 0x24);
  static const _lightSuccess = (0x4f, 0x6e, 0x31);
  static const _lightWarning = (0x8a, 0x5a, 0x00);
  static const _lightError = (0xa0, 0x2f, 0x25);
  static const _lightBorder = (0x8a, 0x7c, 0x68);

  static const _darkForeground = (0xe8, 0xe0, 0xd1);
  static const _darkMuted = (0xb3, 0xa8, 0x94);
  static const _darkAccent = (0xe0, 0x8b, 0x5f);
  static const _darkSelectionForeground = (0x1b, 0x1a, 0x18);
  static const _darkSelectionBackground = (0xe0, 0x8b, 0x5f);
  static const _darkSuccess = (0x9f, 0xbf, 0x7a);
  static const _darkWarning = (0xe4, 0xbd, 0x72);
  static const _darkError = (0xf0, 0x8f, 0x7f);
  static const _darkBorder = (0x75, 0x69, 0x5a);

  static final light = ColorTheme(
    foreground: _rgb(_lightForeground),
    background: const TerminalColor.terminalDefault(),
    muted: _rgb(_lightMuted),
    accent: _rgb(_lightAccent),
    selectionForeground: _rgb(_lightSelectionForeground),
    selectionBackground: _rgb(_lightSelectionBackground),
    success: _rgb(_lightSuccess),
    warning: _rgb(_lightWarning),
    error: _rgb(_lightError),
    border: _rgb(_lightBorder),
  );

  static final dark = ColorTheme(
    foreground: _rgb(_darkForeground),
    background: const TerminalColor.terminalDefault(),
    muted: _rgb(_darkMuted),
    accent: _rgb(_darkAccent),
    selectionForeground: _rgb(_darkSelectionForeground),
    selectionBackground: _rgb(_darkSelectionBackground),
    success: _rgb(_darkSuccess),
    warning: _rgb(_darkWarning),
    error: _rgb(_darkError),
    border: _rgb(_darkBorder),
  );

  static List<BlockTextSwatch> get lightTextRoles => [
    BlockTextSwatch(
      role: 'foreground',
      color: light.foreground,
      rgb: _lightForeground,
      reference: lightReference,
    ),
    BlockTextSwatch(
      role: 'muted',
      color: light.muted,
      rgb: _lightMuted,
      reference: lightReference,
    ),
    BlockTextSwatch(
      role: 'accent',
      color: light.accent,
      rgb: _lightAccent,
      reference: lightReference,
    ),
    BlockTextSwatch(
      role: 'selectionForeground',
      color: light.selectionForeground,
      rgb: _lightSelectionForeground,
      reference: _lightSelectionBackground,
    ),
    BlockTextSwatch(
      role: 'success',
      color: light.success,
      rgb: _lightSuccess,
      reference: lightReference,
    ),
    BlockTextSwatch(
      role: 'warning',
      color: light.warning,
      rgb: _lightWarning,
      reference: lightReference,
    ),
    BlockTextSwatch(
      role: 'error',
      color: light.error,
      rgb: _lightError,
      reference: lightReference,
    ),
  ];

  static List<BlockTextSwatch> get darkTextRoles => [
    BlockTextSwatch(
      role: 'foreground',
      color: dark.foreground,
      rgb: _darkForeground,
      reference: darkReference,
    ),
    BlockTextSwatch(
      role: 'muted',
      color: dark.muted,
      rgb: _darkMuted,
      reference: darkReference,
    ),
    BlockTextSwatch(
      role: 'accent',
      color: dark.accent,
      rgb: _darkAccent,
      reference: darkReference,
    ),
    BlockTextSwatch(
      role: 'selectionForeground',
      color: dark.selectionForeground,
      rgb: _darkSelectionForeground,
      reference: _darkSelectionBackground,
    ),
    BlockTextSwatch(
      role: 'success',
      color: dark.success,
      rgb: _darkSuccess,
      reference: darkReference,
    ),
    BlockTextSwatch(
      role: 'warning',
      color: dark.warning,
      rgb: _darkWarning,
      reference: darkReference,
    ),
    BlockTextSwatch(
      role: 'error',
      color: dark.error,
      rgb: _darkError,
      reference: darkReference,
    ),
  ];

  static TerminalColor _rgb((int, int, int) value) =>
      TerminalColor.rgb(value.$1, value.$2, value.$3);
}

/// Builds real Block components in a theme-owned active period.
final class BlockThemePresentation {
  BlockThemePresentation({
    required TerminalEnvironment io,
    ColorPreferences colors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
  }) : _owner = ThemeSession(
         environment: io,
         colors: colors,
         interaction: interaction,
         lightDefault: BlockAdaptivePalettes.light,
         darkDefault: BlockAdaptivePalettes.dark,
       );

  final ThemeSession _owner;

  Future<PromptResult<String>> textInput(
    String label, {
    ComponentColors colors = const ComponentColors(),
    String initialValue = '',
    bool required = false,
    int? maxLength,
    String? Function(String)? validate,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
  }) => _owner.prompt((handle) {
    final palette = _componentPalette(handle, colors);
    return TextInput(
      label,
      initialValue: initialValue,
      required: required,
      maxLength: maxLength,
      validate: validate,
      instructions: instructions,
      structure: PromptStructure.block,
      colors: palette.palette,
    ).prompt(session: handle.session);
  });

  Future<PromptResult<List<T>>> multiSelect<T>(
    String label,
    List<Choice<T>> choices, {
    ComponentColors colors = const ComponentColors(),
    List<T> defaultValues = const [],
    int min = 0,
    int? max,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
  }) => _owner.prompt((handle) {
    final palette = _componentPalette(handle, colors);
    return MultiSelect<T>(
      label,
      choices,
      defaultValues: defaultValues,
      min: min,
      max: max,
      instructions: instructions,
      structure: PromptStructure.block,
      colors: palette.palette,
    ).prompt(session: handle.session);
  });

  /// Layers a component override over the palette the period resolved.
  ResolvedColors _componentPalette(
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
    );
  }
}
