/// Internal adaptive presentation seam for the Form structural theme.
///
/// This library is deliberately absent from the public export barrel. It lets
/// the Form family exercise its authored defaults through real components
/// before the coordinated public cutover; it is not a stable public API.
library;

import '../color_resolution.dart';
import '../color_theme.dart';
import '../interaction_resolution.dart';
import '../presentation.dart' show DisplayText;
import '../prompt_structure.dart';
import '../state_help_presentation.dart'
    show
        ComponentRoute,
        PresentationMode,
        compactHint,
        composePromptPresentation;
import '../terminal_io.dart';
import '../text_input.dart'
    show
        Choice,
        InstructionDisplay,
        MultiSelect,
        PromptResult,
        Select,
        TextInput;
import '../theme_session.dart'
    show
        ThemeInteractionFactsProvider,
        ThemeResolvedCallback,
        ThemeSession,
        ThemeSessionHandle;

/// The authored Form defaults and the reference surfaces they were designed
/// against.
abstract final class FormPresentation {
  /// Warm sepia ink with a deep sepia primary accent.
  ///
  /// The terminal surface is not painted: [ColorTheme.background] stays
  /// terminal-native, and [referenceBackground] is only the documented RGB
  /// surface used for the authored-pair contrast target.
  static final lightDefault = ColorTheme(
    foreground: TerminalColor.rgb(49, 39, 31),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(92, 76, 62),
    accent: TerminalColor.rgb(133, 76, 24),
    selectionForeground: TerminalColor.rgb(255, 252, 246),
    selectionBackground: TerminalColor.rgb(115, 66, 20),
    success: TerminalColor.rgb(24, 88, 56),
    warning: TerminalColor.rgb(124, 72, 10),
    error: TerminalColor.rgb(145, 38, 38),
    border: TerminalColor.rgb(101, 84, 68),
  );

  /// Warm ink on a dark sepia-tinted neutral with a brighter sepia accent.
  static final darkDefault = ColorTheme(
    foreground: TerminalColor.rgb(242, 233, 218),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.rgb(185, 169, 150),
    accent: TerminalColor.rgb(218, 163, 101),
    selectionForeground: TerminalColor.rgb(32, 27, 22),
    selectionBackground: TerminalColor.rgb(218, 163, 101),
    success: TerminalColor.rgb(140, 205, 158),
    warning: TerminalColor.rgb(232, 181, 105),
    error: TerminalColor.rgb(246, 141, 132),
    border: TerminalColor.rgb(158, 139, 119),
  );

  /// The authored reference surface for [background], not a surface request.
  static TerminalColor referenceBackground(BackgroundVariant background) =>
      switch (background) {
        BackgroundVariant.light => TerminalColor.rgb(243, 236, 221),
        BackgroundVariant.dark => TerminalColor.rgb(34, 29, 25),
      };

  /// Form's uppercase label, rule and left edge.
  static const structure = PromptStructure.form;
}

/// Creates real Form components that resolve their colours through the
/// internal theme owner.
///
/// [colors] and [componentColors] keep the application and component override
/// layers separate; neither can change the environment or background query.
/// The theme defaults are composed into the application layer before the owner
/// resolves them, so every existing [ThemeSession] caller keeps its previous
/// terminal-native starting palette.
final class FormPresentationTracer {
  FormPresentationTracer({
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
      lightDefault: FormPresentation.lightDefault,
      darkDefault: FormPresentation.darkDefault,
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

  /// Places the essential instructions before a screen-reader prompt.
  ///
  /// The compact help route stays mandatory in every presentation mode; only
  /// its placement changes. Screen-reader guidance is written through the
  /// owned session before the real component renders.
  void _presentEssential(ThemeSessionHandle handle, String label) {
    if (!handle.interaction.screenReader) return;
    final safeLabel = DisplayText.from(label).value;
    final presentation = composePromptPresentation(
      mode: PresentationMode.screenReader,
      prompt: safeLabel,
      essential: DisplayText.from('$safeLabel entry.').value,
      hint: compactHint(
        mode: PresentationMode.screenReader,
        component: ComponentRoute.standard,
        primaryAction: 'Enter submits',
        shortPrimaryAction: 'Enter',
      ),
    );
    handle.session.presentText(presentation.essentialBefore!);
  }

  /// Renders a real Form text input in the owner's resolved palette.
  Future<PromptResult<String>> textInput(
    String label, {
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
  }) => _owner.prompt((handle) {
    _presentEssential(handle, label);
    return TextInput(
      label,
      initialValue: initialValue,
      required: required,
      validate: validate,
      maxLength: maxLength,
      instructions: instructions,
      colors: _componentPalette(handle),
      structure: FormPresentation.structure,
    ).prompt(session: handle.session);
  });

  /// Renders a real Form single-choice component.
  Future<PromptResult<T>> select<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
  }) => _owner.prompt((handle) {
    _presentEssential(handle, label);
    return Select<T>(
      label,
      choices,
      defaultValue: defaultValue,
      instructions: instructions,
      colors: _componentPalette(handle),
      structure: FormPresentation.structure,
    ).prompt(session: handle.session);
  });

  /// Renders a real Form multi-choice component.
  Future<PromptResult<List<T>>> multiSelect<T>(
    String label,
    List<Choice<T>> choices, {
    List<T> defaultValues = const [],
    int min = 0,
    int? max,
  }) => _owner.prompt((handle) {
    _presentEssential(handle, label);
    return MultiSelect<T>(
      label,
      choices,
      defaultValues: defaultValues,
      min: min,
      max: max,
      instructions: instructions,
      colors: _componentPalette(handle),
      structure: FormPresentation.structure,
    ).prompt(session: handle.session);
  });
}
