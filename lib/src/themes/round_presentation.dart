/// Internal adaptive presentation seam for the Round structural theme.
///
/// This library is deliberately absent from the public export barrel. It lets
/// the Round family exercise its authored defaults through real components
/// before the coordinated public cutover; it is not a stable public API.
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
import 'package:trelis/src/theme_session.dart'
    show
        ThemeInteractionFactsProvider,
        ThemeResolvedCallback,
        ThemeSession,
        ThemeSessionHandle;

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

/// Creates real Round components that resolve their colours through the
/// internal theme owner.
///
/// [colors] and [componentColors] keep the application and component override
/// layers separate; neither can change the environment or background query.
/// The theme defaults are composed into the application layer before the owner
/// resolves them, so every existing [ThemeSession] caller keeps its previous
/// terminal-native starting palette.
final class RoundPresentationTracer {
  RoundPresentationTracer({
    required this.io,
    this.colors = const ColorPreferences(),
    this.componentColors = const ComponentColors(),
    this.interaction = const InteractionPreferences(),
    this.instructions = InstructionDisplay.themeDefault,
    this.onResolved,
    this.factsForPeriod,
  });

  final TerminalEnvironment io;
  final ColorPreferences colors;
  final ComponentColors componentColors;
  final InteractionPreferences interaction;
  final InstructionDisplay instructions;
  final ThemeResolvedCallback? onResolved;
  final ThemeInteractionFactsProvider? factsForPeriod;

  late final ThemeSession _owner = ThemeSession(
    environment: io,
    colors: ColorPreferences(
      background: colors.background,
      allowBackgroundQuery: colors.allowBackgroundQuery,
      colors: _applicationColors,
    ),
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
  );

  /// The authored defaults with the application's whole-palette replacement
  /// and shared/variant role overrides already applied.
  ///
  /// Both variants are composed up front because a query may still select the
  /// other one after the period starts.
  ComponentColors get _applicationColors {
    ColorTheme forBackground(BackgroundVariant variant) => resolveColors(
      facts: ColorDetectionFacts(outputProfile: io.profile),
      lightDefault: RoundPresentation.lightDefault,
      darkDefault: RoundPresentation.darkDefault,
      preferences: ColorPreferences(
        background: switch (variant) {
          BackgroundVariant.light => BackgroundPreference.light,
          BackgroundVariant.dark => BackgroundPreference.dark,
        },
        colors: colors.colors,
      ),
    ).palette;

    return ComponentColors(
      lightPalette: forBackground(BackgroundVariant.light),
      darkPalette: forBackground(BackgroundVariant.dark),
    );
  }

  /// Applies a component override inside the palette the period resolved.
  ///
  /// A component whole palette replaces the complete effective application
  /// palette; its variant roles win over shared roles. The final `NO_COLOR`
  /// restriction is enforced by the owner before the component receives this.
  ColorTheme _componentPalette(ThemeSessionHandle handle) {
    final period = handle.colors;
    return resolveColors(
      facts: ColorDetectionFacts(
        outputProfile: period.outputProfile,
        noColor: handle.environment.environment['NO_COLOR'],
      ),
      lightDefault: period.palette,
      darkDefault: period.palette,
      preferences: ColorPreferences(
        background: switch (period.background) {
          BackgroundVariant.light => BackgroundPreference.light,
          BackgroundVariant.dark => BackgroundPreference.dark,
        },
      ),
      component: componentColors,
    ).palette;
  }

  /// Renders a real Round text input in the owner's resolved palette.
  Future<PromptResult<String>> textInput(
    String label, {
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
  }) => _owner.prompt((handle) {
    return TextInput(
      label,
      initialValue: initialValue,
      required: required,
      validate: validate,
      maxLength: maxLength,
      instructions: instructions,
      colors: _componentPalette(handle),
      structure: RoundPresentation.structure,
    ).prompt(session: handle.session);
  });

  /// Renders a real Round single-choice component.
  Future<PromptResult<T>> select<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
  }) => _owner.prompt((handle) {
    return Select<T>(
      label,
      choices,
      defaultValue: defaultValue,
      instructions: instructions,
      colors: _componentPalette(handle),
      structure: RoundPresentation.structure,
    ).prompt(session: handle.session);
  });

  /// Renders a real Round multi-choice component.
  Future<PromptResult<List<T>>> multiSelect<T>(
    String label,
    List<Choice<T>> choices, {
    List<T> defaultValues = const [],
    int min = 0,
    int? max,
  }) => _owner.prompt((handle) {
    return MultiSelect<T>(
      label,
      choices,
      defaultValues: defaultValues,
      min: min,
      max: max,
      instructions: instructions,
      colors: _componentPalette(handle),
      structure: RoundPresentation.structure,
    ).prompt(session: handle.session);
  });
}
