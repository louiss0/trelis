part of 'text_input.dart';

enum KeyModifier { control, alt, shift, meta }

enum KeyGestureProvenance { observed, declared }

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
    return Unavailable('Interactive key capture is not yet available.');
  }
}
