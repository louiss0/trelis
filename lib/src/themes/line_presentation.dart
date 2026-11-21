/// Internal adaptive presentation seam for the Line structural theme.
///
/// This library is deliberately absent from the public export barrel. It lets
/// the Line family exercise its authored defaults through real components
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

/// The authored Line defaults and the reference surfaces they were designed
/// against.
abstract final class LinePresentation {
  /// Atelier Sepia warm ink with a deep plum primary accent.
  ///
  /// The terminal surface is not painted: [ColorTheme.background] stays
  /// terminal-native, and [referenceBackground] is only the documented RGB
  /// surface used for the authored-pair contrast target.
  static final lightDefault = ColorTheme(
    foreground: TerminalColor.rgb(52, 40, 36),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(92, 78, 72),
    accent: TerminalColor.rgb(112, 34, 88),
    selectionForeground: TerminalColor.rgb(255, 250, 246),
    selectionBackground: TerminalColor.rgb(112, 34, 88),
    success: TerminalColor.rgb(28, 96, 60),
    warning: TerminalColor.rgb(120, 68, 10),
    error: TerminalColor.rgb(146, 32, 44),
    border: TerminalColor.rgb(101, 82, 76),
  );

  /// Warm ink on a dark plum-tinted neutral with a brighter plum accent.
  static final darkDefault = ColorTheme(
    foreground: TerminalColor.rgb(242, 234, 238),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(182, 168, 177),
    accent: TerminalColor.rgb(214, 139, 196),
    selectionForeground: TerminalColor.rgb(29, 25, 31),
    selectionBackground: TerminalColor.rgb(214, 139, 196),
    success: TerminalColor.rgb(148, 212, 168),
    warning: TerminalColor.rgb(238, 186, 116),
    error: TerminalColor.rgb(252, 142, 152),
    border: TerminalColor.rgb(151, 132, 146),
  );

  /// The authored reference surface for [background], not a surface request.
  static TerminalColor referenceBackground(BackgroundVariant background) =>
      switch (background) {
        BackgroundVariant.light => TerminalColor.rgb(246, 241, 232),
        BackgroundVariant.dark => TerminalColor.rgb(29, 25, 31),
      };

  /// Line's underlined question with indented body and hint.
  static const structure = PromptStructure.line;
}

/// Creates real Line components that resolve their colours through the
/// internal theme owner.
///
/// [colors] and [componentColors] keep the application and component override
/// layers separate; neither can change the environment or background query.
/// The theme defaults are composed into the application layer before the owner
/// resolves them, so every existing [ThemeSession] caller keeps its previous
/// terminal-native starting palette.
final class LinePresentationTracer {
  LinePresentationTracer({
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
      lightDefault: LinePresentation.lightDefault,
      darkDefault: LinePresentation.darkDefault,
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

  /// Renders a real Line text input in the owner's resolved palette.
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
      structure: LinePresentation.structure,
    ).prompt(session: handle.session);
  });
}
