/// Internal theme-owned boolean and basic-choice component families.
///
/// Each instance captures immutable component configuration and binds to one
/// [ThemeSession]. The session resolves interaction and colour before the first
/// output and owns the reader, writer and lifecycle; the real components are
/// delegated to with that session, so no second external prompt, reader or
/// invocation-level I/O is introduced. State glyphs, the selection style and
/// restriction markers come from the shared state/help primitives and are
/// fixed by the theme, not by a prompt invocation. This library is deliberately
/// absent from the public export barrel; the breaking public cutover is a
/// later ticket.
library;

import 'dart:async';

import 'color_resolution.dart';
import 'hint_observations.dart';
import 'interaction_resolution.dart';
import 'output_profile.dart';
import 'prompt_structure.dart';
import 'state_help_presentation.dart'
    show
        ChoicePresentationConfig,
        ChoiceRestriction,
        ComponentRoute,
        PresentationMode,
        SingleSelectionStyle,
        StateGlyphs,
        compactHint,
        composePromptPresentation;
import 'terminal_io.dart';
import 'text_input.dart'
    show
        Checkbox,
        Choice,
        Confirm,
        InstructionDisplay,
        MultiSelect,
        PromptMode,
        PromptResult,
        Radio,
        Select,
        Toggle;
import 'theme_session.dart';

/// Which real boolean component a [ThemeBooleanPrompt] delegates to.
enum ThemeBooleanComponent { confirm, checkbox, toggle }

/// Which real single-choice component a [ThemeSingleChoicePrompt] delegates to.
enum ThemeSingleChoiceComponent { select, radio }

/// One option of a themed choice family.
///
/// A restriction remains focusable so its reason can be inspected, but the
/// delegated [Choice] is disabled: the real component refuses both toggling
/// and acceptance. [selected] is an actual draft selection, independent of
/// [isDefault] and of focus.
final class ThemeChoiceOption<T> {
  const ThemeChoiceOption(
    this.value,
    this.label, {
    this.isDefault = false,
    this.selected = false,
    this.lockedReason,
    this.unavailableReason,
  }) : assert(
         lockedReason == null || unavailableReason == null,
         'A choice has one restriction reason.',
       );

  final T value;
  final String label;
  final bool isDefault;
  final bool selected;
  final String? lockedReason;
  final String? unavailableReason;

  ChoiceRestriction get restriction =>
      switch ((lockedReason, unavailableReason)) {
        (String? locked, _) when locked != null => ChoiceRestriction.locked,
        (_, String? unavailable) when unavailable != null =>
          ChoiceRestriction.unavailable,
        _ => ChoiceRestriction.none,
      };

  String? get reason => lockedReason ?? unavailableReason;

  /// The public choice value handed to the real component.
  Choice<T> get choice => Choice<T>(
    value,
    label,
    disabledReason: switch (restriction) {
      ChoiceRestriction.locked => 'Locked: $reason',
      ChoiceRestriction.unavailable => 'Unavailable: $reason',
      ChoiceRestriction.none => null,
    },
  );
}

/// ThemeSession-backed Confirm, Checkbox and Toggle prompts.
final class ThemeBooleanPrompt {
  ThemeBooleanPrompt._({
    required this.label,
    required this.kind,
    required TerminalEnvironment io,
    this.initialValue = false,
    this.instructions = InstructionDisplay.themeDefault,
    this.supplementaryHelp = const [],
    this.colors = const ComponentColors(),
    this.structure = PromptStructure.plain,
    InteractionPreferences interaction = const InteractionPreferences(),
    ColorPreferences themeColors = const ColorPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) : _owner = _newOwner(
         io: io,
         interaction: interaction,
         themeColors: themeColors,
         onResolved: onResolved,
         factsForPeriod: factsForPeriod,
         hints: hints,
       );

  factory ThemeBooleanPrompt.confirm(
    String label, {
    required TerminalEnvironment io,
    bool initialValue = false,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeBooleanPrompt._(
    label: label,
    kind: ThemeBooleanComponent.confirm,
    io: io,
    initialValue: initialValue,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    colors: colors,
    structure: structure,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  factory ThemeBooleanPrompt.checkbox(
    String label, {
    required TerminalEnvironment io,
    bool initialValue = false,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeBooleanPrompt._(
    label: label,
    kind: ThemeBooleanComponent.checkbox,
    io: io,
    initialValue: initialValue,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    colors: colors,
    structure: structure,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  factory ThemeBooleanPrompt.toggle(
    String label, {
    required TerminalEnvironment io,
    bool initialValue = false,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeBooleanPrompt._(
    label: label,
    kind: ThemeBooleanComponent.toggle,
    io: io,
    initialValue: initialValue,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    colors: colors,
    structure: structure,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  final String label;
  final ThemeBooleanComponent kind;
  final bool initialValue;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final ComponentColors colors;
  final PromptStructure structure;
  final ThemeSession _owner;

  List<Object> get cleanupFailures => _owner.cleanupFailures;

  Future<PromptResult<bool>> prompt() => _owner.prompt((handle) {
    final mode = _presentationMode(handle);
    if (mode == PresentationMode.screenReader) {
      handle.session.presentText(_essential(mode));
    }
    final palette = _componentPalette(handle, colors).palette;
    return switch (kind) {
      ThemeBooleanComponent.confirm => Confirm(
        label,
        initialValue: initialValue,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
        colors: palette,
        structure: structure,
      ).prompt(session: handle.session),
      ThemeBooleanComponent.checkbox => Checkbox(
        label,
        initialValue: initialValue,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
        colors: palette,
        structure: structure,
      ).prompt(session: handle.session),
      ThemeBooleanComponent.toggle => Toggle(
        label,
        initialValue: initialValue,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
        colors: palette,
        structure: structure,
      ).prompt(session: handle.session),
    };
  });

  /// Starts live feedback sharing this prompt's active period.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
  }) => _owner.startFeedback(start, stop: stop);

  String _essential(PresentationMode mode) {
    final (primary, short) = switch ((kind, mode)) {
      (_, PresentationMode.screenReader) || (_, PresentationMode.linear) => (
        'Enter yes or no; an empty line accepts the default',
        'Enter yes/no',
      ),
      (ThemeBooleanComponent.confirm, _) => (
        'Y or N changes the draft; Enter submits',
        'Y/N; Enter',
      ),
      (ThemeBooleanComponent.checkbox, _) ||
      (
        ThemeBooleanComponent.toggle,
        _,
      ) => ('Space changes the draft; Enter submits', 'Space; Enter'),
    };
    return composePromptPresentation(
      mode: mode,
      prompt: label,
      essential: '$label, ${kind.name} question.',
      hint: compactHint(
        mode: mode,
        component: ComponentRoute.standard,
        primaryAction: primary,
        shortPrimaryAction: short,
      ),
    ).essentialBefore!;
  }
}

/// ThemeSession-backed Select and Radio prompts.
final class ThemeSingleChoicePrompt<T> {
  ThemeSingleChoicePrompt._({
    required this.label,
    required this.kind,
    required List<ThemeChoiceOption<T>> options,
    required this.defaultValue,
    required this.selectionStyle,
    required TerminalEnvironment io,
    this.instructions = InstructionDisplay.themeDefault,
    this.supplementaryHelp = const [],
    this.colors = const ComponentColors(),
    this.structure = PromptStructure.plain,
    InteractionPreferences interaction = const InteractionPreferences(),
    ColorPreferences themeColors = const ColorPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
    StateGlyphs glyphs = StateGlyphs.unicode,
    T? selectedValue,
  }) : choices = List.unmodifiable(options.map((option) => option.choice)),
       _config = ChoicePresentationConfig(
         glyphs: glyphs,
         style: selectionStyle,
         selectedReference: _referenceOf(options, selectedValue),
         restrictions: {
           for (var index = 0; index < options.length; index++)
             if (options[index].restriction != ChoiceRestriction.none)
               index + 1: options[index].restriction,
         },
       ),
       _optionCount = options.length,
       _owner = _newOwner(
         io: io,
         interaction: interaction,
         themeColors: themeColors,
         onResolved: onResolved,
         factsForPeriod: factsForPeriod,
         hints: hints,
       );

  factory ThemeSingleChoicePrompt.select(
    String label,
    List<ThemeChoiceOption<T>> choices, {
    required TerminalEnvironment io,
    T? defaultValue,
    T? selectedValue,
    StateGlyphs glyphs = StateGlyphs.unicode,
    SingleSelectionStyle selectionStyle = SingleSelectionStyle.circles,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeSingleChoicePrompt._(
    label: label,
    kind: ThemeSingleChoiceComponent.select,
    options: choices,
    defaultValue: defaultValue ?? _defaultOf(choices),
    selectedValue: selectedValue ?? _selectedOf(choices),
    glyphs: glyphs,
    selectionStyle: selectionStyle,
    io: io,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    colors: colors,
    structure: structure,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  factory ThemeSingleChoicePrompt.radio(
    String label,
    List<ThemeChoiceOption<T>> choices, {
    required TerminalEnvironment io,
    T? defaultValue,
    T? selectedValue,
    StateGlyphs glyphs = StateGlyphs.unicode,
    SingleSelectionStyle selectionStyle = SingleSelectionStyle.circles,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeSingleChoicePrompt._(
    label: label,
    kind: ThemeSingleChoiceComponent.radio,
    options: choices,
    defaultValue: defaultValue ?? _defaultOf(choices),
    selectedValue: selectedValue ?? _selectedOf(choices),
    glyphs: glyphs,
    selectionStyle: selectionStyle,
    io: io,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    colors: colors,
    structure: structure,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  final String label;
  final ThemeSingleChoiceComponent kind;
  final List<Choice<T>> choices;
  final SingleSelectionStyle selectionStyle;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final ComponentColors colors;
  final PromptStructure structure;
  final T? defaultValue;
  final ChoicePresentationConfig _config;
  final int _optionCount;
  final ThemeSession _owner;

  List<Object> get cleanupFailures => _owner.cleanupFailures;

  Future<PromptResult<T>> prompt() => _owner.prompt((handle) {
    final mode = _presentationMode(handle);
    if (mode == PresentationMode.screenReader) {
      handle.session.presentText(_essential(mode));
    }
    final palette = _componentPalette(handle, colors).palette;
    final presentation = _outputConfig(handle, _config);
    return switch (kind) {
      ThemeSingleChoiceComponent.select => Select<T>(
        label,
        choices,
        defaultValue: defaultValue,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
        colors: palette,
        structure: structure,
        presentation: presentation,
      ).prompt(session: handle.session),
      ThemeSingleChoiceComponent.radio => Radio<T>(
        label,
        choices,
        defaultValue: defaultValue,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
        colors: palette,
        structure: structure,
        presentation: presentation,
      ).prompt(session: handle.session),
    };
  });

  /// Starts live feedback sharing this prompt's active period.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
  }) => _owner.startFeedback(start, stop: stop);

  String _essential(PresentationMode mode) {
    final kindName = switch (kind) {
      ThemeSingleChoiceComponent.select => 'selection',
      ThemeSingleChoiceComponent.radio => 'radio selection',
    };
    return composePromptPresentation(
      mode: mode,
      prompt: label,
      essential: '$label, $kindName of $_optionCount choices.',
      hint: compactHint(
        mode: mode,
        component: ComponentRoute.standard,
        primaryAction: 'Up or Down moves focus; Enter accepts',
        shortPrimaryAction: 'Arrows; Enter',
      ),
    ).essentialBefore!;
  }

  static int? _referenceOf<T>(List<ThemeChoiceOption<T>> options, T? selected) {
    if (selected == null) return null;
    final index = options.indexWhere((option) => option.value == selected);
    return index < 0 ? null : index + 1;
  }

  static T? _defaultOf<T>(List<ThemeChoiceOption<T>> options) {
    final defaults = options.where((option) => option.isDefault).toList();
    return defaults.length == 1 ? defaults.single.value : null;
  }

  static T? _selectedOf<T>(List<ThemeChoiceOption<T>> options) {
    final selected = options.where((option) => option.selected).toList();
    return selected.length == 1 ? selected.single.value : null;
  }
}

/// ThemeSession-backed MultiSelect prompt.
final class ThemeMultiSelectPrompt<T> {
  ThemeMultiSelectPrompt(
    this.label,
    List<ThemeChoiceOption<T>> options, {
    required TerminalEnvironment io,
    Iterable<T>? initialSelection,
    this.min = 0,
    this.max,
    StateGlyphs glyphs = StateGlyphs.unicode,
    this.selectionStyle = SingleSelectionStyle.circles,
    this.instructions = InstructionDisplay.themeDefault,
    this.supplementaryHelp = const [],
    this.colors = const ComponentColors(),
    this.structure = PromptStructure.plain,
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) : choices = List.unmodifiable(options.map((option) => option.choice)),
       _defaults = List.unmodifiable([
         for (final option in options)
           if (option.isDefault) option.value,
       ]),
       _initialSelection = List.unmodifiable(
         initialSelection ??
             [
               for (final option in options)
                 if (option.selected) option.value,
             ],
       ),
       _config = ChoicePresentationConfig(
         glyphs: glyphs,
         style: selectionStyle,
         restrictions: {
           for (var index = 0; index < options.length; index++)
             if (options[index].restriction != ChoiceRestriction.none)
               index + 1: options[index].restriction,
         },
       ),
       _optionCount = options.length,
       _owner = _newOwner(
         io: io,
         interaction: interaction,
         themeColors: themeColors,
         onResolved: onResolved,
         factsForPeriod: factsForPeriod,
         hints: hints,
       );

  final String label;
  final List<Choice<T>> choices;
  final int min;
  final int? max;
  final SingleSelectionStyle selectionStyle;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final ComponentColors colors;
  final PromptStructure structure;
  final List<T> _defaults;
  final List<T> _initialSelection;
  final ChoicePresentationConfig _config;
  final int _optionCount;
  final ThemeSession _owner;

  List<Object> get cleanupFailures => _owner.cleanupFailures;

  Future<PromptResult<List<T>>> prompt() => _owner.prompt((handle) {
    final mode = _presentationMode(handle);
    if (mode == PresentationMode.screenReader) {
      handle.session.presentText(_essential(mode));
    }
    final palette = _componentPalette(handle, colors).palette;
    return MultiSelect<T>(
      label,
      choices,
      defaultValues: _defaults,
      initialSelection: _initialSelection,
      min: min,
      max: max,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
      colors: palette,
      structure: structure,
      presentation: _outputConfig(handle, _config),
    ).prompt(session: handle.session);
  });

  /// Starts live feedback sharing this prompt's active period.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
  }) => _owner.startFeedback(start, stop: stop);

  String _essential(PresentationMode mode) => composePromptPresentation(
    mode: mode,
    prompt: label,
    essential: '$label, multiple selection of $_optionCount choices.',
    hint: compactHint(
      mode: mode,
      component: ComponentRoute.standard,
      primaryAction: 'Space toggles; Enter submits',
      shortPrimaryAction: 'Space; Enter',
    ),
  ).essentialBefore!;
}

ThemeSession _newOwner({
  required TerminalEnvironment io,
  required InteractionPreferences interaction,
  required ColorPreferences themeColors,
  ThemeResolvedCallback? onResolved,
  ThemeInteractionFactsProvider? factsForPeriod,
  NativeHintObservations? hints,
}) => ThemeSession(
  environment: io,
  interaction: interaction,
  colors: themeColors,
  onResolved: onResolved,
  factsForPeriod: factsForPeriod,
  hints: hints,
);

PresentationMode _presentationMode(ThemeSessionHandle handle) =>
    switch ((handle.interaction.mode, handle.interaction.screenReader)) {
      (_, true) => PresentationMode.screenReader,
      (PromptMode.rich, false) => PresentationMode.rich,
      (_, false) => PresentationMode.linear,
    };

/// Layers the component override over the palette resolved for this period.
ResolvedColors _componentPalette(
  ThemeSessionHandle handle,
  ComponentColors colors,
) {
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
    component: colors,
  );
}

/// ASCII output never receives a Unicode state vocabulary, even when a caller
/// supplied one; the theme-wide style itself is preserved.
ChoicePresentationConfig _outputConfig(
  ThemeSessionHandle handle,
  ChoicePresentationConfig config,
) {
  final glyphs = handle.environment.profile.glyphs == GlyphSet.ascii
      ? StateGlyphs.ascii
      : config.glyphs;
  if (glyphs == config.glyphs) return config;
  return ChoicePresentationConfig(
    glyphs: glyphs,
    style: config.style,
    selectedReference: config.selectedReference,
    restrictions: config.restrictions,
  );
}
