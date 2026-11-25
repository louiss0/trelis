/// Internal theme-owned text, secret and multiline component family.
///
/// Each instance captures immutable component configuration and binds to one
/// [ThemeSession]. The session resolves interaction and colour before the
/// first output and owns the reader, writer and lifecycle; the real components
/// are delegated to with that session so they never open a competing reader or
/// accept per-invocation configuration. This library is deliberately absent
/// from the public export barrel; the breaking public cutover is a later
/// ticket.
library;

import 'dart:async';

import 'color_resolution.dart';
import 'hint_observations.dart';
import 'interaction_resolution.dart';
import 'prompt_structure.dart';
import 'state_help_presentation.dart'
    show
        ComponentRoute,
        PresentationMode,
        compactHint,
        composePromptPresentation;
import 'terminal_io.dart';
import 'text_input.dart'
    show InstructionDisplay, Multiline, Password, PromptResult, TextInput;
import 'theme_session.dart';

/// Which real component a [ThemeTextPrompt] delegates to.
enum ThemeTextComponentKind { text, secret, multiline }

/// A reusable prompt from the text, secret and multiline family.
final class ThemeTextPrompt {
  ThemeTextPrompt._({
    required this.label,
    required this.kind,
    required TerminalEnvironment io,
    ThemeSession? session,
    this.initialValue = '',
    this.required = false,
    this.validate,
    this.maxLength,
    this.mask = false,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    this.colors = const ComponentColors(),
    this.structure = PromptStructure.plain,
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) : supplementaryHelp = List<String>.unmodifiable(supplementaryHelp),
       _owner =
           session ??
           ThemeSession(
             environment: io,
             colors: themeColors,
             interaction: interaction,
             onResolved: onResolved,
             factsForPeriod: factsForPeriod,
             hints: hints,
           );

  /// A single-line text answer.
  factory ThemeTextPrompt.text(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeTextPrompt._(
    label: label,
    kind: ThemeTextComponentKind.text,
    io: io,
    session: session,
    initialValue: initialValue,
    required: required,
    validate: validate,
    maxLength: maxLength,
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

  /// A hidden answer with its own safe help and action route.
  factory ThemeTextPrompt.secret(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    String initialValue = '',
    bool mask = false,
    bool required = false,
    String? Function(String)? validate,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeTextPrompt._(
    label: label,
    kind: ThemeTextComponentKind.secret,
    io: io,
    session: session,
    initialValue: initialValue,
    mask: mask,
    required: required,
    validate: validate,
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

  /// A multiline answer retaining the real component's line editing.
  factory ThemeTextPrompt.multiline(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeTextPrompt._(
    label: label,
    kind: ThemeTextComponentKind.multiline,
    io: io,
    session: session,
    initialValue: initialValue,
    required: required,
    validate: validate,
    maxLength: maxLength,
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
  final ThemeTextComponentKind kind;
  final String initialValue;
  final bool required;
  final String? Function(String)? validate;
  final int? maxLength;
  final bool mask;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final ComponentColors colors;
  final PromptStructure structure;
  final ThemeSession _owner;

  /// Restoration failures retained after a successful primary operation.
  List<Object> get cleanupFailures => _owner.cleanupFailures;

  /// Runs this component with the period's resolved interaction and palette.
  Future<PromptResult<String>> prompt() => _owner.prompt((handle) async {
    final palette = handle.componentColors(colors).palette;
    final mode = handle.presentationMode;
    if (mode == PresentationMode.screenReader) {
      handle.session.presentText(_essentialBefore(mode));
    }
    return switch (kind) {
      ThemeTextComponentKind.text => TextInput(
        label,
        initialValue: initialValue,
        required: required,
        validate: validate,
        maxLength: maxLength,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
        colors: palette,
        structure: structure,
      ).prompt(session: handle.session),
      ThemeTextComponentKind.secret => Password(
        label,
        initialValue: initialValue,
        mask: mask,
        required: required,
        validate: validate,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
        colors: palette,
        structure: structure,
      ).prompt(session: handle.session),
      ThemeTextComponentKind.multiline => Multiline(
        label,
        initialValue: initialValue,
        required: required,
        validate: validate,
        maxLength: maxLength,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
        colors: palette,
        structure: structure,
      ).prompt(session: handle.session),
    };
  });

  /// Starts live feedback that shares this component's active period.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
  }) => _owner.startFeedback(start, stop: stop);

  /// Sequential text for a screen reader, before the component's own prompt.
  String _essentialBefore(PresentationMode mode) {
    final (primary, short) = switch (kind) {
      ThemeTextComponentKind.text => ('Enter submits', 'Enter'),
      ThemeTextComponentKind.secret => ('Enter opens actions', 'Enter'),
      ThemeTextComponentKind.multiline => switch (mode) {
        PresentationMode.rich => (
          'Enter inserts a newline; Ctrl+J finishes',
          'Ctrl+J',
        ),
        _ => ('Enter adds a line', 'Enter'),
      },
    };
    final presentation = composePromptPresentation(
      mode: mode,
      prompt: label,
      essential: switch (kind) {
        ThemeTextComponentKind.text => '$label entry.',
        ThemeTextComponentKind.secret => 'Hidden entry for $label.',
        ThemeTextComponentKind.multiline => '$label lines.',
      },
      hint: compactHint(
        mode: mode,
        component: kind == ThemeTextComponentKind.secret
            ? ComponentRoute.secret
            : ComponentRoute.standard,
        primaryAction: primary,
        shortPrimaryAction: short,
      ),
    );
    return presentation.essentialBefore!;
  }
}
