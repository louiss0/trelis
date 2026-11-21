/// Internal end-to-end tracer for theme-owned choice prompts.
///
/// It renders real [MultiSelect] and [Select] components through [ThemeSession]
/// so structural themes can be exercised with their authored adaptive defaults
/// and fixed structure before the coordinated public cutover. It is
/// deliberately absent from the public export barrel.
library;

import 'dart:async';

import 'color_resolution.dart';
import 'color_theme.dart';
import 'component_color_application.dart' show applyComponentColors;
import 'interaction_resolution.dart';
import 'presentation.dart' show DisplayText;
import 'prompt_structure.dart' show PromptStructure;
import 'state_help_presentation.dart'
    show
        ComponentRoute,
        PresentationMode,
        compactHint,
        composePromptPresentation;
import 'terminal_io.dart';
import 'text_input.dart'
    show
        Choice,
        InstructionDisplay,
        MultiSelect,
        PromptMode,
        PromptResult,
        Select;
import 'theme_session.dart';

final class ThemeChoiceTracer<T> {
  ThemeChoiceTracer(
    this.label,
    this.choices, {
    required TerminalEnvironment io,
    this.structure = PromptStructure.plain,
    this.defaultValues = const [],
    this.min = 0,
    this.max,
    this.instructions = InstructionDisplay.themeDefault,
    this.colors = const ComponentColors(),
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    this.palettes = ThemePaletteDefaults.terminalNative,
  }) : _owner = ThemeSession(
         environment: io,
         colors: themeColors,
         interaction: interaction,
         onResolved: onResolved,
         factsForPeriod: factsForPeriod,
         palettes: palettes,
       );

  final String label;
  final List<Choice<T>> choices;
  final PromptStructure structure;
  final List<T> defaultValues;
  final int min;
  final int? max;
  final InstructionDisplay instructions;
  final ComponentColors colors;
  final ThemePaletteDefaults palettes;
  final ThemeSession _owner;

  /// Restoration failures retained after a successful primary operation.
  List<Object> get cleanupFailures => _owner.cleanupFailures;

  /// Renders the configured multi-choice prompt in the resolved palette.
  Future<PromptResult<List<T>>> prompt() => _owner.prompt((handle) {
    final palette = applyComponentColors(handle, colors).palette;
    final mode = handle.interaction.screenReader
        ? PresentationMode.screenReader
        : handle.interaction.mode == PromptMode.rich
        ? PresentationMode.rich
        : PresentationMode.linear;
    if (mode == PresentationMode.screenReader) {
      final presentation = composePromptPresentation(
        mode: mode,
        prompt: DisplayText.from(label).value,
        essential: DisplayText.from('$label selection.').value,
        hint: compactHint(
          mode: mode,
          component: ComponentRoute.standard,
          primaryAction: 'Space toggles; Enter submits',
          shortPrimaryAction: 'Space/Enter',
        ),
      );
      handle.session.presentText(presentation.essentialBefore!);
    }
    return MultiSelect<T>(
      label,
      choices,
      defaultValues: defaultValues,
      min: min,
      max: max,
      instructions: instructions,
      colors: palette,
      structure: structure,
    ).prompt(session: handle.session);
  });

  /// Renders a real single-choice component with the supplied configuration.
  Future<PromptResult<R>> select<R>(
    String label,
    List<Choice<R>> choices, {
    R? defaultValue,
  }) => _prompt(
    (handle, palette) => Select<R>(
      label,
      choices,
      defaultValue: defaultValue,
      structure: structure,
      instructions: instructions,
      colors: palette,
    ).prompt(session: handle.session),
  );

  /// Renders a real multi-choice component with the supplied configuration.
  Future<PromptResult<List<R>>> multiSelect<R>(
    String label,
    List<Choice<R>> choices, {
    List<R> defaultValues = const [],
    int min = 0,
    int? max,
  }) => _prompt(
    (handle, palette) => MultiSelect<R>(
      label,
      choices,
      defaultValues: defaultValues,
      min: min,
      max: max,
      structure: structure,
      instructions: instructions,
      colors: palette,
    ).prompt(session: handle.session),
  );

  Future<PromptResult<R>> _prompt<R>(
    Future<PromptResult<R>> Function(
      ThemeSessionHandle handle,
      ColorTheme palette,
    )
    build,
  ) => _owner.prompt(
    (handle) => build(handle, applyComponentColors(handle, colors).palette),
  );

  /// Starts live feedback that shares this tracer's active period.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
  }) => _owner.startFeedback(start, stop: stop);
}
