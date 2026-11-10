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
  Keypress(this.label, {this.requireObservation = false}) {
    _validateKeyLabel(label);
  }
  final String label;
  final bool requireObservation;
  bool _active = false;

  Future<PromptResult<KeyGesture>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      if (source is SuppliedAnswer) {
        if (requireObservation) {
          return Unavailable(
            'A declared gesture does not satisfy the observation requirement.',
          );
        }
        final parts = source.value.split('+');
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
        return Accepted(
          KeyGesture._(key, modifiers, KeyGestureProvenance.declared),
        );
      }
      return await _singleInteractive(
        label,
        requireObservation,
        source,
        mode ?? userPreference ?? applicationPreference ?? PromptMode.automatic,
        output,
      );
    } finally {
      _active = false;
    }
  }
}

/// An ordered, non-empty sequence of logical key gestures.
final class KeyChordInput {
  KeyChordInput(this.label, {this.requireObservation = false}) {
    _validateKeyLabel(label);
  }
  final String label;
  final bool requireObservation;
  bool _active = false;

  Future<PromptResult<List<KeyGesture>>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      if (source is SuppliedAnswer) {
        final gestures = <KeyGesture>[];
        for (final declaration in source.value.split(',')) {
          final result = await Keypress(
            label,
            requireObservation: requireObservation,
          ).prompt(source: SuppliedAnswer(declaration));
          if (result is Unavailable<KeyGesture>) {
            return Unavailable(result.reason);
          }
          gestures.add((result as Accepted<KeyGesture>).value);
        }
        return Accepted(List.unmodifiable(gestures));
      }
      return await _sequenceInteractive(
        label,
        requireObservation,
        source,
        mode ?? userPreference ?? applicationPreference ?? PromptMode.automatic,
        output,
        single: false,
      );
    } finally {
      _active = false;
    }
  }
}

Future<PromptResult<KeyGesture>> _singleInteractive(
  String label,
  bool requireObservation,
  PromptSource? source,
  PromptMode mode,
  Stdout? output,
) async {
  final result = await _sequenceInteractive(
    label,
    requireObservation,
    source,
    mode,
    output,
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
  PromptSource? source,
  PromptMode mode,
  Stdout? output, {
  required bool single,
}) async {
  final capture = _CaptureControl();
  Future<PromptResult<List<KeyGesture>>> run(
    ScriptedInput input,
    PromptMode selected, {
    void Function()? beforeClose,
  }) async {
    if (selected == PromptMode.rich && !input.supportsRich) {
      return Unavailable('Rich interaction unavailable.');
    }
    if (selected == PromptMode.automatic) {
      selected = input.supportsRich ? PromptMode.rich : PromptMode.linear;
    }
    final keys = _Keys(
      input.input.transform(utf8.encoder),
      flushEscapeOnEnd: true,
    );
    final gestures = <KeyGesture>[];
    var armed = false;
    final out = input.output;
    void review() {
      out.writeln(
        'Review: ${gestures.isEmpty ? "empty" : gestures.map((g) => "${g.modifiers.map((m) => m.name).join('+')} ${g.key} (${g.provenance.name})").join(', ')}',
      );
    }

    out.writeln(
      '$label: ${selected == PromptMode.rich ? "c capture; d declare; r remove last; x clear; Enter submit; Escape cancel." : "/capture, /declare, /remove, /clear, /done, /cancel."}',
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
          final observed = source == null ? _nativeGesture(key) : null;
          final legacy = _legacyGesture(key);
          if (key == '\x1b') {
            out.writeln('Capture cancelled.');
          } else if (observed != null) {
            if (single) gestures.clear();
            gestures.add(observed);
          } else if (legacy != null) {
            if (single) gestures.clear();
            gestures.add(legacy);
            out.writeln('Modifiers are ambiguous in this input stream.');
          } else {
            out.writeln('Gesture unavailable.');
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
          );
          if (r.action == 'interrupt') return Interrupted();
          if (r.action == 'cancel') return Cancelled();
          if (r.action != 'command') {
            if (r.action != 'submit') return InputEnded();
            out.writeln('Use an action command.');
            continue;
          }
          action = r.value;
        } else {
          final key = await keys.next();
          if (key == null || key == '\x1a') return InputEnded();
          if (key == '\x03') return Interrupted();
          if (key == '\x1b') return Cancelled();
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
            out.writeln('Capture next gesture; Escape cancels capture.');
          case '/remove':
            if (gestures.isNotEmpty) gestures.removeLast();
            review();
          case '/clear':
            gestures.clear();
            review();
          case '/declare':
            out.writeln(
              'Enter a declaration (for example Ctrl+A). Declarations are unverified; Ctrl+C and Escape are reserved.',
            );
            final r = await _edit(
              keys,
              '',
              out,
              linear: true,
              sequential: true,
            );
            if (r.action == 'interrupt') return Interrupted();
            if (r.action == 'cancel') {
              review();
              continue;
            }
            if (r.action != 'submit') return InputEnded();
            final result = await Keypress(
              label,
              requireObservation: requireObservation,
            ).prompt(source: SuppliedAnswer(r.value));
            if (result is Accepted<KeyGesture>) {
              if (single) gestures.clear();
              gestures.add(result.value);
            } else {
              out.writeln((result as Unavailable<KeyGesture>).reason);
            }
            review();
          case '/done':
            if (gestures.isEmpty) {
              out.writeln('Capture or declare a gesture first.');
            } else if (requireObservation &&
                gestures.any(
                  (g) => g.provenance != KeyGestureProvenance.observed,
                )) {
              out.writeln(
                'Observation required; ambiguous or declared input cannot be accepted.',
              );
            } else {
              return Accepted(List.unmodifiable(gestures));
            }
        }
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }

  if (source is ScriptedInput) return run(source, mode);
  if (_terminalActive) {
    throw StateError('A terminal session is already active.');
  }
  _terminalActive = true;
  try {
    return await _terminal<List<KeyGesture>>(
      mode,
      output ?? stderr,
      (input, selected, restore) => run(input, selected, beforeClose: restore),
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
