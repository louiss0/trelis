part of 'text_input.dart';

enum KeyModifier { control, alt, shift, meta }

enum KeyGestureProvenance { observed, declared, ambiguous }

/// A logical key and modifiers, not a physical keyboard position.
final class KeyGesture {
  KeyGesture._(this.key, Set<KeyModifier> modifiers, this.provenance)
    : modifiers = Set.unmodifiable(modifiers);
  final String key;
  final Set<KeyModifier> modifiers;
  final KeyGestureProvenance provenance;
}

final class Keypress {
  Keypress(this.label, {this.requireObservation = false});
  final String label;
  final bool requireObservation;

  Future<PromptResult<KeyGesture>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
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
    return _singleInteractive(
      label,
      requireObservation,
      source,
      mode ?? userPreference ?? applicationPreference ?? PromptMode.automatic,
      output,
    );
  }
}

/// An ordered, non-empty sequence of logical key gestures.
final class KeyChordInput {
  KeyChordInput(this.label, {this.requireObservation = false});
  final String label;
  final bool requireObservation;

  Future<PromptResult<List<KeyGesture>>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
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
    return Unavailable('Interactive key capture is not yet available.');
  }
}

Future<PromptResult<KeyGesture>> _singleInteractive(
  String label,
  bool requireObservation,
  PromptSource? source,
  PromptMode mode,
  Stdout? output,
) async {
  Future<PromptResult<KeyGesture>> run(
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
    if (selected == PromptMode.linear) {
      return Unavailable('Linear key capture is not yet available.');
    }
    final keys = _Keys(input.input.transform(utf8.encoder));
    KeyGesture? draft;
    var armed = false;
    input.output.writeln(
      '$label: c captures the next gesture; Enter submits; Escape cancels.',
    );
    try {
      while (true) {
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (armed) {
            armed = false;
            input.output.writeln('Capture cancelled; Review.');
            continue;
          }
          return Cancelled();
        }
        if (armed) {
          armed = false;
          if (RegExp(r'^[A-Za-z0-9]$').hasMatch(key)) {
            draft = KeyGesture._(key, {}, KeyGestureProvenance.ambiguous);
            input.output.writeln(
              'Review: $key. Modifiers are ambiguous in this input stream.',
            );
          } else {
            input.output.writeln('Gesture unavailable; Review.');
          }
          continue;
        }
        if (key == 'c') {
          armed = true;
          input.output.writeln('Capture next gesture; Escape cancels capture.');
        } else if (key == '\r' || key == '\n') {
          if (draft == null) {
            input.output.writeln('Capture a gesture first.');
          } else if (requireObservation) {
            input.output.writeln(
              'Observation required; ambiguous input cannot be accepted.',
            );
          } else {
            return Accepted(draft);
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
    return await _terminal<KeyGesture>(
      mode,
      output ?? stderr,
      (input, selected, restore) => run(input, selected, beforeClose: restore),
    );
  } finally {
    _terminalActive = false;
  }
}
