/// Internal adaptive presentation seam for the Minimal structural theme.
///
/// This library is deliberately absent from the public export barrel. It lets
/// the Minimal family exercise its authored defaults through real components
/// before the coordinated public cutover; it is not a stable public API.
library;

import '../color_resolution.dart';
import '../color_theme.dart';
import '../interaction_resolution.dart';
import '../prompt_structure.dart';
import '../terminal_io.dart';
import '../text_input.dart' show InstructionDisplay, PromptResult, TextInput;
import '../theme_session.dart'
    show
        ThemeInteractionFactsProvider,
        ThemeResolvedCallback,
        ThemeSession,
        ThemeSessionHandle;

/// The authored Minimal defaults and the reference surfaces they were designed
/// against.
abstract final class MinimalPresentation {
  /// Atelier Sepia warm ink with a deep sepia primary accent.
  ///
  /// The terminal surface is not painted: [ColorTheme.background] stays
  /// terminal-native, and [referenceBackground] is only the documented RGB
  /// surface used for the authored-pair contrast target.
  static final lightDefault = ColorTheme(
    foreground: TerminalColor.rgb(54, 43, 34),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(96, 80, 68),
    accent: TerminalColor.rgb(126, 72, 20),
    selectionForeground: TerminalColor.rgb(255, 251, 244),
    selectionBackground: TerminalColor.rgb(126, 72, 20),
    success: TerminalColor.rgb(26, 92, 57),
    warning: TerminalColor.rgb(128, 74, 8),
    error: TerminalColor.rgb(150, 36, 40),
    border: TerminalColor.rgb(112, 92, 74),
  );

  /// Warm ink on a dark sepia-tinted neutral with a brighter sepia accent.
  static final darkDefault = ColorTheme(
    foreground: TerminalColor.rgb(244, 236, 224),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(190, 174, 156),
    accent: TerminalColor.rgb(214, 158, 97),
    selectionForeground: TerminalColor.rgb(30, 26, 22),
    selectionBackground: TerminalColor.rgb(214, 158, 97),
    success: TerminalColor.rgb(146, 210, 164),
    warning: TerminalColor.rgb(238, 188, 112),
    error: TerminalColor.rgb(250, 146, 138),
    border: TerminalColor.rgb(158, 138, 118),
  );

  /// The authored reference surface for [background], not a surface request.
  static TerminalColor referenceBackground(BackgroundVariant background) =>
      switch (background) {
        BackgroundVariant.light => TerminalColor.rgb(245, 238, 225),
        BackgroundVariant.dark => TerminalColor.rgb(30, 26, 22),
      };

  /// Minimal's unframed conversational question and answer.
  static const structure = PromptStructure.minimal;
}

/// Creates real Minimal components that resolve their colours through the
/// internal theme owner.
///
/// [colors] and [componentColors] keep the application and component override
/// layers separate; neither can change the environment or background query.
/// The theme defaults are composed into the application layer before the owner
/// resolves them, so every existing [ThemeSession] caller keeps its previous
/// terminal-native starting palette.
final class MinimalPresentationTracer {
  MinimalPresentationTracer({
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
      lightDefault: MinimalPresentation.lightDefault,
      darkDefault: MinimalPresentation.darkDefault,
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

  /// Renders a real Minimal text input in the owner's resolved palette.
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
      structure: MinimalPresentation.structure,
    ).prompt(session: handle.session);
  });
}
