/// Internal end-to-end tracer for one theme-owned choice prompt.
///
/// It renders a real [MultiSelect] through [ThemeSession] so structural themes
/// can be exercised with their authored adaptive defaults and fixed structure
/// before the coordinated public cutover. It is deliberately absent from the
/// public export barrel.
library;

import 'dart:async';

import 'color_resolution.dart';
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
    show Choice, InstructionDisplay, MultiSelect, PromptMode, PromptResult;
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

  Future<PromptResult<List<T>>> prompt() => _owner.prompt((handle) {
    final palette = _componentPalette(handle).palette;
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

  /// Starts live feedback that shares this tracer's active period.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
  }) => _owner.startFeedback(start, stop: stop);

  /// Layers the component override over the palette the period resolved.
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
      component: colors,
    );
  }
}
