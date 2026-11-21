/// Internal theme-owned filesystem and network component family.
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
import 'color_theme.dart';
import 'hint_observations.dart';
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
        DirectoryPicker,
        EmailInput,
        FilePicker,
        IPAddressInput,
        IPAddressValue,
        InstructionDisplay,
        PathInput,
        PathTarget,
        PromptResult,
        URLInput;
import 'theme_session.dart';

/// Which real component a [ThemeFilesystemPrompt] delegates to.
enum ThemeFilesystemKind {
  path,
  filePicker,
  directoryPicker,
  ipAddress,
  url,
  email,
}

/// A reusable prompt from the filesystem and network family.
final class ThemeFilesystemPrompt<T> {
  ThemeFilesystemPrompt._({
    required this.label,
    required this.kind,
    required TerminalEnvironment io,
    ThemeSession? session,
    this.base,
    this.initialValue = '',
    this.allowNonexistent = false,
    this.target = PathTarget.any,
    this.cidr = false,
    this.scoped = false,
    this.allowedSchemes = const <String>{},
    this.smtpUtf8 = false,
    this.colors = const ComponentColors(),
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
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

  /// Browses for an existing file, reviewed before it is returned.
  static ThemeFilesystemPrompt<String> filePicker(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    String? base,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFilesystemPrompt<String>._(
    label: label,
    kind: ThemeFilesystemKind.filePicker,
    io: io,
    session: session,
    base: base,
    target: PathTarget.file,
    colors: colors,
    structure: structure,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Browses for an existing directory, reviewed before it is returned.
  static ThemeFilesystemPrompt<String> directoryPicker(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    String? base,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFilesystemPrompt<String>._(
    label: label,
    kind: ThemeFilesystemKind.directoryPicker,
    io: io,
    session: session,
    base: base,
    target: PathTarget.directory,
    colors: colors,
    structure: structure,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// A literal native path, reviewed before it is returned.
  static ThemeFilesystemPrompt<String> path(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    String? base,
    String initialValue = '',
    bool allowNonexistent = false,
    PathTarget target = PathTarget.any,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFilesystemPrompt<String>._(
    label: label,
    kind: ThemeFilesystemKind.path,
    io: io,
    session: session,
    base: base,
    initialValue: initialValue,
    allowNonexistent: allowNonexistent,
    target: target,
    colors: colors,
    structure: structure,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// A numeric address with an optional family-specific prefix.
  static ThemeFilesystemPrompt<IPAddressValue> ipAddress(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    bool cidr = false,
    bool scoped = false,
    String initialValue = '',
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFilesystemPrompt<IPAddressValue>._(
    label: label,
    kind: ThemeFilesystemKind.ipAddress,
    io: io,
    session: session,
    cidr: cidr,
    scoped: scoped,
    initialValue: initialValue,
    colors: colors,
    structure: structure,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// An absolute URL restricted to the configured web schemes.
  static ThemeFilesystemPrompt<String> url(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    required Set<String> allowedSchemes,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFilesystemPrompt<String>._(
    label: label,
    kind: ThemeFilesystemKind.url,
    io: io,
    session: session,
    allowedSchemes: Set<String>.unmodifiable(allowedSchemes),
    colors: colors,
    structure: structure,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// One bare SMTP mailbox, with optional SMTPUTF8 local parts.
  static ThemeFilesystemPrompt<String> email(
    String label, {
    required TerminalEnvironment io,
    ThemeSession? session,
    bool smtpUtf8 = false,
    String initialValue = '',
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFilesystemPrompt<String>._(
    label: label,
    kind: ThemeFilesystemKind.email,
    io: io,
    session: session,
    smtpUtf8: smtpUtf8,
    initialValue: initialValue,
    colors: colors,
    structure: structure,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  final String label;
  final ThemeFilesystemKind kind;
  final String? base;
  final String initialValue;
  final bool allowNonexistent;
  final PathTarget target;
  final bool cidr;
  final bool scoped;
  final Set<String> allowedSchemes;
  final bool smtpUtf8;
  final ComponentColors colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final ThemeSession _owner;

  /// Restoration failures retained after a successful primary operation.
  List<Object> get cleanupFailures => _owner.cleanupFailures;

  /// Runs this component with the period's resolved interaction and palette.
  Future<PromptResult<T>> prompt() => _owner.prompt((handle) async {
    final palette = handle.componentColors(colors).palette;
    final mode = handle.presentationMode;
    if (mode == PresentationMode.screenReader) {
      handle.session.presentText(_essentialBefore(mode));
    }
    final PromptResult<T> result = switch (kind) {
      ThemeFilesystemKind.path => await PathInput(
        label,
        base: base,
        initialValue: initialValue,
        allowNonexistent: allowNonexistent,
        target: target,
        colors: palette,
        structure: structure,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
      ).prompt(session: handle.session) as PromptResult<T>,
      ThemeFilesystemKind.filePicker ||
      ThemeFilesystemKind.directoryPicker => await _browse(handle, palette),
      ThemeFilesystemKind.ipAddress ||
      ThemeFilesystemKind.url ||
      ThemeFilesystemKind.email => await _network(handle, palette),
    };
    if (mode != PresentationMode.screenReader) {
      // The real component describes its stage while it is live; the themed
      // presentation closes it with the mandatory compact primary-action and
      // help hint.
      handle.session.presentText(_hintText(handle, mode));
    }
    return result;
  });

  /// Starts live feedback that shares this component's active period.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
  }) => _owner.startFeedback(start, stop: stop);

  Future<PromptResult<T>> _browse(
    ThemeSessionHandle handle,
    ColorTheme palette,
  ) async {
    final PromptResult<String> result = switch (kind) {
      ThemeFilesystemKind.filePicker => await FilePicker(
        label,
        base: base,
        colors: palette,
        structure: structure,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
      ).prompt(session: handle.session),
      ThemeFilesystemKind.directoryPicker => await DirectoryPicker(
        label,
        base: base,
        colors: palette,
        structure: structure,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
      ).prompt(session: handle.session),
      _ => throw StateError('Not a browser: $kind'),
    };
    return result as PromptResult<T>;
  }

  Future<PromptResult<T>> _network(
    ThemeSessionHandle handle,
    ColorTheme palette,
  ) async {
    final PromptResult<dynamic> result = switch (kind) {
      ThemeFilesystemKind.ipAddress => await IPAddressInput(
        label,
        cidr: cidr,
        scoped: scoped,
        initialValue: initialValue,
        colors: palette,
        structure: structure,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
      ).prompt(session: handle.session),
      ThemeFilesystemKind.url => await URLInput(
        label,
        allowedSchemes: allowedSchemes,
        colors: palette,
        structure: structure,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
      ).prompt(session: handle.session),
      ThemeFilesystemKind.email => await EmailInput(
        label,
        smtpUtf8: smtpUtf8,
        initialValue: initialValue,
        colors: palette,
        structure: structure,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
      ).prompt(session: handle.session),
      _ => throw StateError('Not a network input: $kind'),
    };
    return result as PromptResult<T>;
  }

  /// Sequential instructions for a screen reader, before the prompt.
  String _essentialBefore(PresentationMode mode) {
    final (essential, primary) = switch (kind) {
      ThemeFilesystemKind.path => (
        '$label entry. Enter reviews the resolved path.',
        'Enter reviews the path',
      ),
      ThemeFilesystemKind.filePicker || ThemeFilesystemKind.directoryPicker => (
        '$label browser. Enter runs an action, then confirms the reviewed entry.',
        'Enter runs an action',
      ),
      ThemeFilesystemKind.ipAddress => (
        '$label numeric address entry. Enter validates the address.',
        'Enter validates the address',
      ),
      ThemeFilesystemKind.url => (
        '$label URL entry. The draft is hidden. Enter validates the URL.',
        'Enter validates the URL',
      ),
      ThemeFilesystemKind.email => (
        '$label mailbox entry. Enter validates the address.',
        'Enter validates the address',
      ),
    };
    final composition = composePromptPresentation(
      mode: mode,
      prompt: label,
      essential: essential,
      hint: _hint(mode, primary: primary),
    );
    return composition.essentialBefore!;
  }

  /// The full hint, shortened to its action and help route on narrow output.
  String _hintText(ThemeSessionHandle handle, PresentationMode mode) {
    final hint = _hint(mode);
    final columns = handle.colors.outputProfile.geometry.columns;
    return columns != null && columns < hint.text.length
        ? hint.shortText
        : hint.text;
  }

  CompactHint _hint(PresentationMode mode, {String? primary}) => compactHint(
    mode: mode,
    component: ComponentRoute.standard,
    primaryAction: primary ?? _primaryAction(mode),
    shortPrimaryAction: 'Enter',
  );

  String _primaryAction(PresentationMode mode) => switch (kind) {
    ThemeFilesystemKind.path => 'Enter reviews the path',
    ThemeFilesystemKind.filePicker ||
    ThemeFilesystemKind.directoryPicker => 'Enter runs an action',
    ThemeFilesystemKind.url => 'Enter validates the URL',
    _ => 'Enter validates the address',
  };
}
