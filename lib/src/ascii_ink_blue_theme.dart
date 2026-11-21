/// Internal, unstable Ascii presentation seam with authored adaptive palettes.
///
/// This is not the public cutover: the structural factories remain static and
/// the public barrel does not export this library. It exercises real Ascii
/// components through a theme-owned active period so palette, structure and
/// help behavior can be verified before the coordinated API change.
library;

import 'dart:async';

import 'color_resolution.dart';
import 'color_theme.dart';
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
import 'text_input.dart' show Choice, InstructionDisplay, PromptResult;
import 'theme_session.dart';
import 'text_input.dart' show MultiSelect, Select, TextInput;

part 'ascii_ink_blue_palettes.g.dart';

final class AsciiInkBlueTheme {
  AsciiInkBlueTheme({
    required TerminalEnvironment io,
    ColorPreferences colors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ColorDetectionFacts? colorFacts,
  }) : _colorFacts = colorFacts,
       _owner = ThemeSession(
         environment: io,
         colors: colors,
         interaction: interaction,
         onResolved: onResolved,
         colorFacts: colorFacts,
         lightDefault: AsciiAdaptivePalettes.light,
         darkDefault: AsciiAdaptivePalettes.dark,
       );

  final ThemeSession _owner;
  final ColorDetectionFacts? _colorFacts;

  /// Cleanup failures retained after a successful component operation.
  List<Object> get cleanupFailures => _owner.cleanupFailures;

  Future<PromptResult<String>> textInput(
    String label, {
    ComponentColors colors = const ComponentColors(),
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _owner.prompt((handle) {
    final palette = _componentPalette(handle, colors).palette;
    _presentEssential(
      handle,
      label: label,
      essential: '$label entry.',
      route: ComponentRoute.standard,
      primaryAction: 'Enter submits',
      shortPrimaryAction: 'Enter',
    );
    return TextInput(
      label,
      initialValue: initialValue,
      required: required,
      validate: validate,
      maxLength: maxLength,
      colors: palette,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
      structure: PromptStructure.ascii,
    ).prompt(session: handle.session);
  });

  Future<PromptResult<T>> select<T>(
    String label,
    List<Choice<T>> choices, {
    ComponentColors colors = const ComponentColors(),
    T? defaultValue,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _owner.prompt((handle) {
    final palette = _componentPalette(handle, colors).palette;
    _presentEssential(
      handle,
      label: label,
      essential: '$label selection.',
      route: ComponentRoute.standard,
      primaryAction: 'Enter selects',
      shortPrimaryAction: 'Enter',
    );
    return Select<T>(
      label,
      choices,
      defaultValue: defaultValue,
      colors: palette,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
      structure: PromptStructure.ascii,
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
    List<String> supplementaryHelp = const [],
  }) => _owner.prompt((handle) {
    final palette = _componentPalette(handle, colors).palette;
    _presentEssential(
      handle,
      label: label,
      essential: '$label selection.',
      route: ComponentRoute.standard,
      primaryAction: 'Space toggles, Enter submits',
      shortPrimaryAction: 'Enter',
    );
    return MultiSelect<T>(
      label,
      choices,
      defaultValues: defaultValues,
      min: min,
      max: max,
      colors: palette,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
      structure: PromptStructure.ascii,
    ).prompt(session: handle.session);
  });

  /// Reuses the period's resolved background and ownership while layering the
  /// component override over the effective app palette.
  ResolvedColors _componentPalette(
    ThemeSessionHandle handle,
    ComponentColors colors,
  ) {
    final period = handle.colors;
    final background = switch (period.background) {
      BackgroundVariant.light => BackgroundPreference.light,
      BackgroundVariant.dark => BackgroundPreference.dark,
    };
    return resolveColors(
      facts: ColorDetectionFacts(
        outputProfile: period.outputProfile,
        noColor:
            _colorFacts?.noColor ?? handle.environment.environment['NO_COLOR'],
      ),
      lightDefault: period.palette,
      darkDefault: period.palette,
      preferences: ColorPreferences(background: background),
      component: colors,
    );
  }

  void _presentEssential(
    ThemeSessionHandle handle, {
    required String label,
    required String essential,
    required ComponentRoute route,
    required String primaryAction,
    required String shortPrimaryAction,
  }) {
    if (!handle.interaction.screenReader) return;
    final presentation = composePromptPresentation(
      mode: PresentationMode.screenReader,
      prompt: DisplayText.from(label).value,
      essential: DisplayText.from(essential).value,
      hint: compactHint(
        mode: PresentationMode.screenReader,
        component: route,
        primaryAction: primaryAction,
        shortPrimaryAction: shortPrimaryAction,
      ),
    );
    handle.session.presentText(presentation.essentialBefore!);
  }
}
