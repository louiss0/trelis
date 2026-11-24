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
        CronCellFrame,
        InstructionDisplay,
        KeyGesture,
        Keybind,
        Keypress,
        PromptMode,
        PromptResult;
import 'theme_session.dart';

/// Which real component a [ThemeKeyCapturePrompt] delegates to.
enum ThemeKeyCaptureKind { keypress, keybind }

/// A reusable, theme-owned keypress or keybind prompt.
final class ThemeKeyCapturePrompt<T> {
  ThemeKeyCapturePrompt._({
    required this.label,
    required this.kind,
    required TerminalEnvironment io,
    ThemeSession? session,
    this.requireObservation = false,
    List<String> modifiers = Keybind.defaultModifiers,
    List<String> symbols = Keybind.defaultSymbols,
    List<String> initialValue = const [],
    this.joined = false,
    this.cellFrame = CronCellFrame.square,
    this.colors = const ComponentColors(),
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
  }) : modifiers = List<String>.unmodifiable(modifiers),
       symbols = List<String>.unmodifiable(symbols),
       initialValue = List<String>.unmodifiable(initialValue),
       supplementaryHelp = List<String>.unmodifiable(supplementaryHelp),
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

  /// Composes one logical gesture declaration cell by cell — modifier
  /// symbols from [modifiers], then one key symbol from [symbols] — and
  /// resolves the ordered token list.
  static ThemeKeyCapturePrompt<List<String>> keybind(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    List<String> modifiers = Keybind.defaultModifiers,
    List<String> symbols = Keybind.defaultSymbols,
    List<String> initialValue = const [],
    CronCellFrame cellFrame = CronCellFrame.square,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
  }) => ThemeKeyCapturePrompt<List<String>>._(
    label: label,
    kind: ThemeKeyCaptureKind.keybind,
    io: io,
    session: session,
    modifiers: modifiers,
    symbols: symbols,
    initialValue: initialValue,
    cellFrame: cellFrame,
    colors: colors,
    structure: structure,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
  );

  /// The flagged variant: resolves the `+`-joined declaration string.
  static ThemeKeyCapturePrompt<String> joinedKeybind(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    List<String> modifiers = Keybind.defaultModifiers,
    List<String> symbols = Keybind.defaultSymbols,
    List<String> initialValue = const [],
    CronCellFrame cellFrame = CronCellFrame.square,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
  }) => ThemeKeyCapturePrompt<String>._(
    label: label,
    kind: ThemeKeyCaptureKind.keybind,
    io: io,
    session: session,
    modifiers: modifiers,
    symbols: symbols,
    initialValue: initialValue,
    joined: true,
    cellFrame: cellFrame,
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

  /// The modifier catalog for every keybind cell but the last.
  final List<String> modifiers;

  /// The key-symbol catalog for a keybind prompt's last cell.
  final List<String> symbols;

  /// Whether a keybind prompt resolves the `+`-joined declaration instead
  /// of the ordered tokens.
  final bool joined;

  /// Tokens presetting a keybind prompt's leading cells.
  final List<String> initialValue;
  final CronCellFrame cellFrame;
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
      case ThemeKeyCaptureKind.keybind:
        result = joined
            ? await Keybind<String>.joined(
                label,
                modifiers: modifiers,
                symbols: symbols,
                initialValue: initialValue,
                cellFrame: cellFrame,
                colors: palette,
                structure: structure,
                instructions: instructions,
                supplementaryHelp: supplementaryHelp,
              ).prompt(session: handle.session) as PromptResult<T>
            : await Keybind<List<String>>(
                label,
                modifiers: modifiers,
                symbols: symbols,
                initialValue: initialValue,
                cellFrame: cellFrame,
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
    shortPrimaryAction: 'Enter',
  );

  String _primaryAction(PresentationMode mode) =>
      kind == ThemeKeyCaptureKind.keypress
      ? '${mode == PresentationMode.rich ? 'Enter' : '/done'} submits'
      : 'Enter submits the sequence';

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
