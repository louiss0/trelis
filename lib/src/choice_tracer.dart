/// Internal theme-owned seam for real choice components.
///
/// It gives a migrating structural family the same colour resolution, structure
/// and lifecycle as the text-input tracer without publishing a second public
/// component API. This library is deliberately absent from the public barrel.
library;

import 'dart:async';

import 'color_resolution.dart';
import 'color_theme.dart';
import 'component_color_application.dart' show applyComponentColors;
import 'interaction_resolution.dart';
import 'prompt_structure.dart' show PromptStructure;
import 'terminal_io.dart';
import 'text_input.dart'
    show Choice, InstructionDisplay, MultiSelect, PromptResult, Select;
import 'theme_session.dart'
    show
      ThemeInteractionFactsProvider,
      ThemeResolvedCallback,
      ThemeSession,
      ThemeSessionHandle;

final class ThemeChoiceTracer {
  ThemeChoiceTracer({
    required TerminalEnvironment io,
    this.colors = const ComponentColors(),
    this.themeColors = const ColorPreferences(),
    this.interaction = const InteractionPreferences(),
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    this.lightDefault = ColorThemes.terminalDefault,
    this.darkDefault = ColorThemes.terminalDefault,
    this.onResolved,
    this.factsForPeriod,
  }) : _owner = ThemeSession(
         environment: io,
         colors: themeColors,
         interaction: interaction,
         lightDefault: lightDefault,
         darkDefault: darkDefault,
         onResolved: onResolved,
         factsForPeriod: factsForPeriod,
       );

  final ComponentColors colors;
  final ColorPreferences themeColors;
  final InteractionPreferences interaction;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final ColorTheme lightDefault;
  final ColorTheme darkDefault;
  final ThemeResolvedCallback? onResolved;
  final ThemeInteractionFactsProvider? factsForPeriod;
  final ThemeSession _owner;

  /// Renders a real single-choice component in the resolved palette.
  Future<PromptResult<T>> select<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
  }) => _prompt(
    (handle, palette) => Select<T>(
      label,
      choices,
      defaultValue: defaultValue,
      structure: structure,
      instructions: instructions,
      colors: palette,
    ).prompt(session: handle.session),
  );

  /// Renders a real multi-choice component in the resolved palette.
  Future<PromptResult<List<T>>> multiSelect<T>(
    String label,
    List<Choice<T>> choices, {
    List<T> defaultValues = const [],
    int min = 0,
    int? max,
  }) => _prompt(
    (handle, palette) => MultiSelect<T>(
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
    ) build,
  ) => _owner.prompt(
    (handle) => build(handle, applyComponentColors(handle, colors).palette),
  );
}
