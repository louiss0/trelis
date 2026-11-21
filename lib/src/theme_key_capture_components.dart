/// Internal theme-owned key-capture family.
///
/// Each instance captures immutable component configuration and binds to one
/// [ThemeSession]. The session resolves interaction and colour before the
/// first output and owns the reader, writer and lifecycle; the real components
/// are delegated to with that session so literal captures and their safe help
/// routes keep their existing semantics. This library is deliberately absent
/// from the public export barrel; the breaking public cutover is a later
/// ticket.
library;

import 'dart:async';

import 'color_resolution.dart';
import 'interaction_resolution.dart';
import 'prompt_structure.dart';
import 'state_help_presentation.dart'
    show
        CompactHint,
        ComponentRoute,
        PresentationMode,
        compactHint,
        composePromptPresentation;
import 'terminal_io.dart';
import 'text_input.dart'
    show
        InstructionDisplay,
        KeyChordInput,
        KeyGesture,
        Keypress,
        PromptMode,
        PromptResult;
import 'theme_session.dart';

/// Which real component a [ThemeKeyCapturePrompt] delegates to.
enum ThemeKeyCaptureKind { keypress, keyChordInput }

/// A reusable, theme-owned key or chord capture prompt.
final class ThemeKeyCapturePrompt<T> {
  ThemeKeyCapturePrompt._({
    required this.label,
    required this.kind,
    required TerminalEnvironment io,
    ThemeSession? session,
    this.requireObservation = false,
    this.colors = const ComponentColors(),
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
  }) : supplementaryHelp = List<String>.unmodifiable(supplementaryHelp),
       _owner =
           session ??
           ThemeSession(
             environment: io,
             colors: themeColors,
             interaction: interaction,
             onResolved: onResolved,
             factsForPeriod: factsForPeriod,
           );

  /// Captures one logical gesture.
  static ThemeKeyCapturePrompt<KeyGesture> keypress(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    bool requireObservation = false,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
  }) => ThemeKeyCapturePrompt<KeyGesture>._(
    label: label,
    kind: ThemeKeyCaptureKind.keypress,
    io: io,
    session: session,
    requireObservation: requireObservation,
    colors: colors,
    structure: structure,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
  );

  /// Captures an ordered, non-empty sequence of logical gestures.
  static ThemeKeyCapturePrompt<List<KeyGesture>> keyChordInput(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    bool requireObservation = false,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
  }) => ThemeKeyCapturePrompt<List<KeyGesture>>._(
    label: label,
    kind: ThemeKeyCaptureKind.keyChordInput,
    io: io,
    session: session,
    requireObservation: requireObservation,
    colors: colors,
    structure: structure,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
  );

  final String label;
  final ThemeKeyCaptureKind kind;
  final bool requireObservation;
  final ComponentColors colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final ThemeSession _owner;

  /// Restoration failures retained after a successful primary operation.
  List<Object> get cleanupFailures => _owner.cleanupFailures;

  /// Runs this component with the period's resolved interaction and palette.
  Future<PromptResult<T>> prompt() => _owner.prompt((handle) async {
    final palette = _componentPalette(handle, colors).palette;
    final mode = _presentationMode(handle);
    if (mode == PresentationMode.screenReader) {
      final presentation = composePromptPresentation(
        mode: mode,
        prompt: label,
        essential: '$label capture.',
        hint: _hint(mode),
      );
      handle.session.presentText(presentation.essentialBefore!);
    }
    final PromptResult<T> result;
    switch (kind) {
      case ThemeKeyCaptureKind.keypress:
        result = await Keypress(
          label,
          requireObservation: requireObservation,
          colors: palette,
          structure: structure,
          instructions: instructions,
          supplementaryHelp: supplementaryHelp,
        ).prompt(session: handle.session) as PromptResult<T>;
      case ThemeKeyCaptureKind.keyChordInput:
        result = await KeyChordInput(
          label,
          requireObservation: requireObservation,
          colors: palette,
          structure: structure,
          instructions: instructions,
          supplementaryHelp: supplementaryHelp,
        ).prompt(session: handle.session) as PromptResult<T>;
    }
    if (mode != PresentationMode.screenReader) {
      // The real component advertises its actions while the prompt is live;
      // the themed presentation closes it with the mandatory compact hint in
      // the transcript, after the reviewed state.
      handle.session.presentText(_hint(mode).text);
    }
    return result;
  });

  /// Starts live feedback that shares this component's active period.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
  }) => _owner.startFeedback(start, stop: stop);

  /// The presentation direction this period resolved.
  PresentationMode _presentationMode(ThemeSessionHandle handle) =>
      switch ((handle.interaction.mode, handle.interaction.screenReader)) {
        (_, true) => PresentationMode.screenReader,
        (PromptMode.rich, false) => PresentationMode.rich,
        (_, false) => PresentationMode.linear,
      };

  CompactHint _hint(PresentationMode mode) => compactHint(
    mode: mode,
    component: ComponentRoute.keyCapture,
    primaryAction: _primaryAction(mode),
    shortPrimaryAction: kind == ThemeKeyCaptureKind.keypress
        ? 'Enter'
        : '/done',
  );

  String _primaryAction(PresentationMode mode) {
    final action = mode == PresentationMode.rich ? 'Enter' : '/done';
    return kind == ThemeKeyCaptureKind.keypress
        ? '$action submits'
        : '$action submits the sequence';
  }

  /// Layers the component override over the palette the period resolved.
  ResolvedColors _componentPalette(
    ThemeSessionHandle handle,
    ComponentColors override,
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
      component: override,
    );
  }
}
