/// Ledger's adaptive sepia defaults and internal component seam.
///
/// The palettes here are authored defaults for the Ledger structural theme:
/// Atelier warm ink with Atelier Sepia as the light starting direction and
/// sepia as the primary accent in both variants. They are deliberately not
/// exported from the public barrel before the coordinated cutover. This
/// library performs no terminal I/O; component rendering goes through the
/// theme-owned session in [LedgerAdaptiveTheme].
library;

import 'dart:async';

import 'color_resolution.dart';
import 'color_theme.dart';
import 'interaction_resolution.dart' show InteractionPreferences;
import 'prompt_structure.dart';
import 'terminal_io.dart';
import 'text_input.dart'
    show
        Choice,
        InstructionDisplay,
        PromptMode,
        PromptResult,
        Select,
        TextInput;
import 'theme_session.dart';

abstract final class LedgerAdaptivePalettes {
  /// Both palettes leave [ColorTheme.background] at the terminal default:
  /// the reference backgrounds used for contrast authoring are not painted,
  /// so the terminal's own surface shows through.

  /// Light Ledger: Atelier Sepia paper with warm-ink normal text.
  static final light = ColorTheme(
    foreground: TerminalColor.rgb(66, 57, 47),
    background: const TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(107, 94, 76),
    accent: TerminalColor.rgb(131, 86, 45),
    selectionForeground: TerminalColor.rgb(255, 255, 255),
    selectionBackground: TerminalColor.rgb(131, 86, 45),
    success: TerminalColor.rgb(65, 106, 68),
    warning: TerminalColor.rgb(138, 90, 16),
    error: TerminalColor.rgb(173, 59, 55),
    border: TerminalColor.rgb(195, 179, 152),
  );

  /// Dark Ledger: deep warm ink with a light sepia accent.
  static final dark = ColorTheme(
    foreground: TerminalColor.rgb(243, 233, 216),
    background: const TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(192, 176, 154),
    accent: TerminalColor.rgb(210, 166, 121),
    selectionForeground: TerminalColor.rgb(33, 29, 25),
    selectionBackground: TerminalColor.rgb(210, 166, 121),
    success: TerminalColor.rgb(155, 201, 143),
    warning: TerminalColor.rgb(224, 180, 95),
    error: TerminalColor.rgb(240, 153, 140),
    border: TerminalColor.rgb(90, 77, 63),
  );

  /// The authored palette for [variant].
  static ColorTheme paletteFor(BackgroundVariant variant) => switch (variant) {
    BackgroundVariant.light => light,
    BackgroundVariant.dark => dark,
  };
}

/// The authored palette for [variant], without any application layer.
ColorTheme ledgerPaletteFor(BackgroundVariant variant) =>
    LedgerAdaptivePalettes.paletteFor(variant);

/// Resolves Ledger colours from injected facts only.
///
/// Application and component layers, capability degradation and the hard
/// `NO_COLOR` restriction follow the shared resolver; only the two theme
/// defaults are Ledger-specific.
ResolvedColors resolveLedgerColors({
  required ColorDetectionFacts facts,
  ColorPreferences preferences = const ColorPreferences(),
  ComponentColors? component,
}) => resolveColors(
  facts: facts,
  lightDefault: LedgerAdaptivePalettes.light,
  darkDefault: LedgerAdaptivePalettes.dark,
  preferences: preferences,
  component: component,
);

/// An internal Ledger theme that renders real components with its adaptive
/// defaults.
///
/// Components keep the Ledger structure and run through the shared
/// [ThemeSession], so interaction resolution, one-shot ownership and cleanup
/// stay in one place. This is deliberately not part of the public barrel
/// before the coordinated cutover.
final class LedgerAdaptiveTheme {
  LedgerAdaptiveTheme({
    required TerminalEnvironment io,
    InteractionPreferences interaction = const InteractionPreferences(
      mode: PromptMode.linear,
    ),
    ColorPreferences colors = const ColorPreferences(),
    this.component = const ComponentColors(),
  }) : _owner = ThemeSession(
         environment: io,
         interaction: interaction,
         colors: colors,
         lightDefault: LedgerAdaptivePalettes.light,
         darkDefault: LedgerAdaptivePalettes.dark,
       );

  final ThemeSession _owner;

  /// The application's component-level colour override.
  final ComponentColors component;

  /// Renders a real Ledger text input through the theme-owned session.
  Future<PromptResult<String>> promptTextInput(
    String label, {
    String initialValue = '',
    bool required = false,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
  }) => _owner.prompt((handle) {
    final palette = _componentPalette(handle).palette;
    return TextInput(
      label,
      initialValue: initialValue,
      required: required,
      instructions: instructions,
      structure: PromptStructure.ledger,
      colors: palette,
    ).prompt(session: handle.session);
  });

  /// Renders a real Ledger single-choice component through the owner.
  Future<PromptResult<T>> promptSelect<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
  }) => _owner.prompt((handle) {
    final palette = _componentPalette(handle).palette;
    return Select<T>(
      label,
      choices,
      defaultValue: defaultValue,
      instructions: instructions,
      structure: PromptStructure.ledger,
      colors: palette,
    ).prompt(session: handle.session);
  });

  /// Layers this theme's component override over the period's resolved
  /// palette without re-resolution of background or I/O.
  ResolvedColors _componentPalette(ThemeSessionHandle handle) {
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
