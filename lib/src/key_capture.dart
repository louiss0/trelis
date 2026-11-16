part of 'text_input.dart';

enum KeyModifier { control, alt, shift, meta }

enum KeyGestureProvenance { observed, declared, ambiguous }

/// A logical key and modifiers, not a physical keyboard position.
final class KeyGesture {
  KeyGesture._(this.key, Set<KeyModifier> modifiers, this.provenance)
    : modifiers = Set.unmodifiable(modifiers);

  /// The key spelling supplied by the source, without case normalization.
  ///
  /// Declarations retain their spelling, legacy letter input retains the
  /// received character, and Windows observations use uppercase virtual-key
  /// letters regardless of Shift.
  final String key;
  final Set<KeyModifier> modifiers;
  final KeyGestureProvenance provenance;

  /// Limitations and reserved-key warnings that apply to this gesture.
  List<String> get warnings => [
    if (provenance == KeyGestureProvenance.declared) 'Declaration is unverified and does not establish delivery or conflict freedom.',
    if (provenance == KeyGestureProvenance.ambiguous)
      'Legacy input does not identify all modifiers.',
    if (key == 'Escape' ||
        (key.toUpperCase() == 'C' && modifiers.contains(KeyModifier.control)))
      'This gesture is reserved for cancellation or interruption.',
  ];
}

final class Keypress {
  Keypress(
    this.label, {
    this.requireObservation = false,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    _validateKeyLabel(label);
  }
  final String label;
  final bool requireObservation;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  bool _active = false;

  Future<PromptResult<KeyGesture>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      return await _singleInteractive(
        label,
        requireObservation,
        colors,
        structure,
        source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
        session: session,
      );
    } finally {
      _active = false;
    }
  }
}

/// An ordered, non-empty sequence of logical key gestures.
final class KeyChordInput {
  KeyChordInput(
    this.label, {
    this.requireObservation = false,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    _validateKeyLabel(label);
  }
  final String label;
  final bool requireObservation;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  bool _active = false;

  Future<PromptResult<List<KeyGesture>>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      return await _sequenceInteractive(
        label,
        requireObservation,
        colors,
        structure,
        source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
        session: session,
        single: false,
      );
    } finally {
      _active = false;
    }
  }
}

Future<PromptResult<KeyGesture>> _declaredGesture(
  String declaration, {
  required bool requireObservation,
}) async {
  if (requireObservation) {
    return Unavailable(
      'A declared gesture does not satisfy the observation requirement.',
    );
  }
  final parts = declaration.split('+');
  final modifiers = <KeyModifier>{};
  for (final part in parts.take(parts.length - 1)) {
    final modifier = switch (part) {
      'Ctrl' => KeyModifier.control,
      'Alt' => KeyModifier.alt,
      'Shift' => KeyModifier.shift,
      'Meta' => KeyModifier.meta,
      _ => null,
    };
    if (modifier == null || !modifiers.add(modifier)) {
      return Unavailable('Invalid logical gesture declaration.');
    }
  }
  final key = parts.last;
  if (!RegExp(
    r'^(?:[A-Za-z0-9]|F(?:[1-9]|1[0-2])|Enter|Tab|Escape|Space|Backspace|Delete|Insert|Home|End|PageUp|PageDown|ArrowUp|ArrowDown|ArrowLeft|ArrowRight)$',
  ).hasMatch(key)) {
    return Unavailable('Invalid logical gesture declaration.');
  }
  return Accepted(KeyGesture._(key, modifiers, KeyGestureProvenance.declared));
}

Future<PromptResult<KeyGesture>> _singleInteractive(
  String label,
  bool requireObservation,
  ColorTheme colors,
  PromptStructure structure,
  PromptSource? source, {
  PromptMode? mode,
  PromptMode? userPreference,
  PromptMode? applicationPreference,
  Stdout? output,
  TerminalIo? terminal,
  OutputProfile? outputProfile,
  TerminalSession? session,
}) async {
  final result = await _sequenceInteractive(
    label,
    requireObservation,
    colors,
    structure,
    source,
    mode: mode,
    userPreference: userPreference,
    applicationPreference: applicationPreference,
    output: output,
    terminal: terminal,
    outputProfile: outputProfile,
    session: session,
    single: true,
  );
  return switch (result) {
    Accepted<List<KeyGesture>>(:final value) => Accepted(value.single),
    Cancelled<List<KeyGesture>>() => Cancelled(),
    Interrupted<List<KeyGesture>>() => Interrupted(),
    InputEnded<List<KeyGesture>>() => InputEnded(),
    Unavailable<List<KeyGesture>>(:final reason) => Unavailable(reason),
  };
}

Future<PromptResult<List<KeyGesture>>> _sequenceInteractive(
  String label,
  bool requireObservation,
  ColorTheme colors,
  PromptStructure structure,
  PromptSource? source, {
  PromptMode? mode,
  PromptMode? userPreference,
  PromptMode? applicationPreference,
  Stdout? output,
  TerminalIo? terminal,
  OutputProfile? outputProfile,
  TerminalSession? session,
  required bool single,
}) async {
  final capture = _CaptureControl();
  Future<PromptResult<List<KeyGesture>>> run(
    ScriptedInput input,
    PromptMode selected, {
    void Function()? beforeClose,
    OutputProfile? invocationProfile,
    _Keys? sharedKeys,
    TerminalSession? promptSession,
  }) async {
    final effectiveProfile = _effectiveOutputProfile(input, invocationProfile);
    if (selected == PromptMode.rich &&
        !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (selected == PromptMode.automatic) {
      selected = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    final keys =
        sharedKeys ??
        _Keys(input.input.transform(utf8.encoder), flushEscapeOnEnd: true);
    final gestures = <KeyGesture>[];
    var armed = false;
    var help = false;
    final out = input.output;
    final width = _textInputWidth(effectiveProfile);
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: width,
      background: colors.background,
      border: colors.border,
    );
    void write(String text, TerminalColor foreground, {bool closes = false}) =>
        spine.write(out, text, foreground: foreground, closes: closes);
    final richFocusedAction = (
      title: '$label:',
      guidance: 'c capture; d declare; r remove last; x clear; Enter submit; Ctrl+T help; Escape cancel.',
    );
    final linearFocusedAction = (
      title: '$label:',
      guidance: '/capture, /declare, /remove, /clear, /done, /help, /cancel.',
    );
    void review() {
      spine.reset();
      write(
        'Review: ${gestures.isEmpty ? "empty" : gestures.map((g) => "${g.modifiers.map((m) => m.name).join('+')} ${g.key} (${g.provenance.name})").join(', ')}',
        colors.foreground,
        closes: true,
      );
    }

    _writeStructureIntro(
      spine,
      out,
      parts: selected == PromptMode.rich
          ? richFocusedAction
          : linearFocusedAction,
      foreground: colors.foreground,
    );
    try {
      while (true) {
        if (armed) {
          capture.armed = true;
          final key = await keys.next();
          capture.armed = false;
          if (key == null || key == '\x1a') return InputEnded();
          if (key == '\x03') return Interrupted();
          armed = false;
          // The native record format is produced by the Windows console
          // adapter; a scripted source that replays the same record exercises
          // the observation path without claiming a physical keyboard.
          final observed = _nativeGesture(key);
          final legacy = _legacyGesture(key);
          if (key == '\x1b') {
            write('Capture cancelled.', colors.muted);
          } else if (observed != null) {
            if (single) gestures.clear();
            gestures.add(observed);
          } else if (legacy != null) {
            if (single) gestures.clear();
            gestures.add(legacy);
            write(
              'Modifiers are ambiguous in this input stream.',
              colors.warning,
            );
          } else {
            write('Gesture unavailable.', colors.error);
          }
          review();
          continue;
        }
        String action;
        if (selected == PromptMode.linear) {
          final r = await _edit(
            keys,
            '',
            out,
            linear: true,
            sequential: true,
            extraCommands: const {
              '/capture',
              '/declare',
              '/remove',
              '/clear',
              '/done',
            },
            linearHelpText: _keyCaptureHelp(
              linear: true,
              single: single,
              requireObservation: requireObservation,
            ),
            outputProfile: effectiveProfile,
            structure: structure,
            session: promptSession,
          );
          if (r.action == 'interrupt') return Interrupted();
          if (r.action == 'cancel') return Cancelled();
          if (r.action != 'command') {
            if (r.action != 'submit') return InputEnded();
            write('Use an action command.', colors.error);
            continue;
          }
          action = r.value;
        } else {
          final key = await keys.next();
          if (key == null || key == '\x1a') return InputEnded();
          if (key == '\x03') return Interrupted();
          if (key == '\x14') {
            if (help) continue;
            help = true;
            promptSession?._openModalHelp(useAlternateScreen: false);
            write(
              _keyCaptureHelp(
                linear: false,
                single: single,
                requireObservation: requireObservation,
              ),
              colors.muted,
            );
            continue;
          }
          if (key == '\x1b') {
            if (!help) return Cancelled();
            help = false;
            void repaintFocusedAction() => write(
              '${richFocusedAction.title} ${richFocusedAction.guidance}',
              colors.foreground,
            );
            final activePrompt = promptSession;
            if (activePrompt != null) {
              activePrompt._dismissModalHelp(
                showTranscriptDismissal: true,
                repaintPrompt: repaintFocusedAction,
              );
            } else {
              write('Help dismissed.', colors.muted);
              repaintFocusedAction();
            }
            continue;
          }
          if (help) continue;
          action = switch (key) {
            'c' => '/capture',
            'd' => '/declare',
            'r' => '/remove',
            'x' => '/clear',
            '\r' || '\n' => '/done',
            _ => '',
          };
        }
        switch (action) {
          case '/capture':
            armed = true;
            write(
              selected == PromptMode.rich
                  ? 'Capture next gesture; Escape cancels capture and returns to review. Ctrl+T is a candidate while capture is armed.'
                  : 'Capture next gesture; Escape cancels capture and returns to review. /help is captured as a gesture rather than opening help.',
              colors.muted,
            );
          case '/remove':
            if (gestures.isNotEmpty) gestures.removeLast();
            review();
          case '/clear':
            gestures.clear();
            review();
          case '/declare':
            write(
              'Enter a declaration (for example Ctrl+A). Declarations are unverified; Ctrl+C and Escape are reserved.',
              colors.muted,
            );
            final r = await _edit(
              keys,
              '',
              out,
              linear: true,
              sequential: true,
              linearHelpText: _keyCaptureDeclarationHelp(
                requireObservation: requireObservation,
              ),
              outputProfile: effectiveProfile,
              structure: structure,
              session: promptSession,
            );
            if (r.action == 'interrupt') return Interrupted();
            if (r.action == 'cancel') {
              review();
              continue;
            }
            if (r.action != 'submit') return InputEnded();
            final result = await _declaredGesture(
              r.value,
              requireObservation: requireObservation,
            );
            if (result is Accepted<KeyGesture>) {
              if (single) gestures.clear();
              gestures.add(result.value);
            } else {
              write(
                (result as Unavailable<KeyGesture>).reason,
                colors.error,
                closes: true,
              );
            }
            review();
          case '/done':
            if (gestures.isEmpty) {
              write(
                'Capture or declare a gesture first.',
                colors.error,
                closes: true,
              );
            } else if (requireObservation &&
                gestures.any(
                  (g) => g.provenance != KeyGestureProvenance.observed,
                )) {
              write(
                'Observation required; ambiguous or declared input cannot be accepted.',
                colors.error,
                closes: true,
              );
            } else {
              return Accepted(List.unmodifiable(gestures));
            }
        }
      }
    } finally {
      try {
        if (help) promptSession?._abortModalHelp();
      } finally {
        try {
          beforeClose?.call();
        } finally {
          if (sharedKeys == null) await keys.close();
        }
      }
    }
  }

  if (session != null) {
    return session._promptRunner<List<KeyGesture>>(
      (source, selected, {outputProfile, keys, session}) => run(
        source as ScriptedInput,
        selected,
        invocationProfile: outputProfile,
        sharedKeys: keys,
        promptSession: session,
      ),
      source: source,
      mode: mode,
      userPreference: userPreference,
      applicationPreference: applicationPreference,
      output: output,
      terminal: terminal,
      outputProfile: outputProfile,
      capture: capture,
    );
  }

  if (source != null && terminal != null) {
    throw ArgumentError('Specify either source or terminal, not both.');
  }
  if (output != null && terminal != null) {
    throw ArgumentError('Specify either output or terminal, not both.');
  }
  if (source is SuppliedAnswer) {
    if (single) {
      return switch (await _declaredGesture(
        source.value,
        requireObservation: requireObservation,
      )) {
        Accepted<KeyGesture>(:final value) => Accepted([value]),
        Unavailable<KeyGesture>(:final reason) => Unavailable(reason),
        _ => InputEnded<List<KeyGesture>>(),
      };
    }
    final gestures = <KeyGesture>[];
    for (final declaration in source.value.split(',')) {
      final result = await _declaredGesture(
        declaration,
        requireObservation: requireObservation,
      );
      if (result is Unavailable<KeyGesture>) {
        return Unavailable(result.reason);
      }
      gestures.add((result as Accepted<KeyGesture>).value);
    }
    return Accepted(List.unmodifiable(gestures));
  }
  final selected =
      mode ?? userPreference ?? applicationPreference ?? PromptMode.automatic;
  if (source is ScriptedInput) {
    return run(source, selected, invocationProfile: outputProfile);
  }
  if (_terminalActive) {
    throw StateError('A terminal session is already active.');
  }
  _terminalActive = true;
  try {
    if (terminal != null) {
      final lease = terminal.acquire();
      return await _restoreAfter(
        () => run(
          ScriptedInput(
            terminal.input,
            terminal.output,
            supportsRich: terminal.supportsRich,
            outputProfile: _terminalOutputProfile(terminal),
            hardColorDisabled:
                terminal.environment['NO_COLOR']?.isNotEmpty == true,
          ),
          selected,
          invocationProfile: outputProfile,
        ),
        lease.restore,
      );
    }
    return await _terminal<List<KeyGesture>>(
      selected,
      output ?? stderr,
      (input, selected, restore) => run(
        input,
        selected,
        beforeClose: restore,
        invocationProfile: outputProfile,
      ),
      capture: capture,
    );
  } finally {
    _terminalActive = false;
  }
}

KeyGesture? _nativeGesture(String input) {
  final match = RegExp(r'^\x1b\[901;(\d+);(\d+);(\d+)~$').firstMatch(input);
  if (match == null) return null;
  final vk = int.parse(match[1]!);
  final code = int.parse(match[2]!);
  final state = int.parse(match[3]!);
  final key = switch (vk) {
    >= 0x41 && <= 0x5a => String.fromCharCode(vk),
    >= 0x30 && <= 0x39 => String.fromCharCode(vk),
    >= 0x70 && <= 0x7b => 'F${vk - 0x6f}',
    0x0d => 'Enter',
    0x09 => 'Tab',
    0x20 => 'Space',
    0x08 => 'Backspace',
    0x2e => 'Delete',
    0x2d => 'Insert',
    0x24 => 'Home',
    0x23 => 'End',
    0x21 => 'PageUp',
    0x22 => 'PageDown',
    0x25 => 'ArrowLeft',
    0x26 => 'ArrowUp',
    0x27 => 'ArrowRight',
    0x28 => 'ArrowDown',
    _ => '',
  };
  if (key.isEmpty || (code >= 0xd800 && code <= 0xdfff)) return null;
  return KeyGesture._(key, {
    if ((state & 0x0c) != 0) KeyModifier.control,
    if ((state & 0x03) != 0) KeyModifier.alt,
    if ((state & 0x10) != 0) KeyModifier.shift,
    if ((state & 0x1000000) != 0) KeyModifier.meta,
  }, KeyGestureProvenance.observed);
}

KeyGesture? _legacyGesture(String input) {
  final key = switch (input) {
    '\x1b[A' => 'ArrowUp',
    '\x1b[B' => 'ArrowDown',
    '\x1b[C' => 'ArrowRight',
    '\x1b[D' => 'ArrowLeft',
    '\x1b[H' => 'Home',
    '\x1b[F' => 'End',
    '\x1b[2~' => 'Insert',
    '\x1b[3~' => 'Delete',
    '\x1b[5~' => 'PageUp',
    '\x1b[6~' => 'PageDown',
    ' ' => 'Space',
    _ => RegExp(r'^[A-Za-z0-9]$').hasMatch(input) ? input : '',
  };
  return key.isEmpty
      ? null
      : KeyGesture._(key, {}, KeyGestureProvenance.ambiguous);
}

void _validateKeyLabel(String label) {
  if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
    throw ArgumentError.value(label, 'label');
  }
}

String _keyCaptureScope(bool single) => single
    ? 'Keypress captures one logical gesture'
    : 'KeyChordInput captures an ordered, non-empty sequence of gestures';

String _keyCaptureObservation(bool requireObservation) => requireObservation
    ? 'Observation is required: declared and ambiguous gestures cannot be accepted.'
    : 'Observation is not required: declared and ambiguous gestures are accepted with their provenance retained.';

String _keyCaptureProvenance() =>
    'Legacy byte-stream captures report ambiguous provenance, and an empty modifier set does not prove that no modifier was held; native console observations report virtual-key letters and modifier state.';

String _keyCaptureReserved() =>
    'Escape cancels and Ctrl+C interrupts, so neither reserved gesture can be captured live.';

String _keyCaptureHelp({
  required bool linear,
  required bool single,
  required bool requireObservation,
}) {
  final scope = _keyCaptureScope(single);
  final observation = _keyCaptureObservation(requireObservation);
  final reserved = _keyCaptureReserved();
  final provenance = _keyCaptureProvenance();
  if (!linear) {
    final reviewEdits = single
        ? 'A new capture or declaration replaces the reviewed gesture; r and x remove it.'
        : 'Each capture appends to the reviewed sequence; r removes the last gesture and x clears the sequence.';
    return 'Help: $scope. c arms exactly one raw capture; the captured gesture is reviewed and never submitted automatically. Escape backs out of capture and returns to the reviewed gestures. While capture is armed every key is a candidate, so Ctrl+T opens this help only before or after a capture. $reviewEdits d declares one logical gesture such as Ctrl+Shift+A from the modifiers Ctrl, Alt, Shift and Meta; declarations are unverified and do not prove delivery or freedom from conflicts. $reserved $provenance $observation Enter submits the reviewed state.';
  }
  final reviewEdits = single
      ? '/remove clears the reviewed gesture.'
      : '/remove deletes the last reviewed gesture; /clear deletes the sequence.';
  return 'Help: $scope. /capture arms exactly one raw capture and always returns to review; typing Escape during capture leaves capture and keeps the reviewed gestures. /declare enters one logical gesture such as Ctrl+Shift+A and Escape cancels declaration entry; declarations are unverified and do not prove delivery or freedom from conflicts. $reviewEdits /done submits the reviewed state; /cancel cancels; Ctrl+C interrupts. Exact /capture, /declare, /remove, /clear, /done, /help and /cancel are commands; quote a command with a backslash and double a leading backslash. Identified paste is literal and is not captured as a gesture. $reserved $provenance $observation';
}

String _keyCaptureDeclarationHelp({required bool requireObservation}) =>
    'Help: A declaration joins the modifiers Ctrl, Alt, Shift and Meta, each at most once, with + to one key: an ASCII letter or digit, F1 to F12, Enter, Tab, Escape, Space, Backspace, Delete, Insert, Home, End, PageUp, PageDown, ArrowUp, ArrowDown, ArrowLeft or ArrowRight. Enter submits the declaration for review; Escape cancels declaration entry and keeps the reviewed gestures; Ctrl+C interrupts. Declarations are unverified and do not prove delivery or freedom from conflicts. ${_keyCaptureObservation(requireObservation)}';
