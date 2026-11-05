part of 'text_input.dart';

/// One element of a mask template.
sealed class MaskElement {}

/// An editable grapheme and its caller-declared rule.
final class MaskSlot extends MaskElement {
  MaskSlot(this.description, this.accepts, {this.required = true});
  final String description;
  final bool Function(String) accepts;
  final bool required;
}

/// Literal presentation, not editable data.
final class MaskLiteral extends MaskElement {
  MaskLiteral(this.text);
  final String text;
}

/// A named finite arrangement of editable slots and literals.
final class MaskTemplate {
  MaskTemplate(this.name, List<MaskElement> elements)
    : elements = List.unmodifiable(elements);
  final String name;
  final List<MaskElement> elements;
}

/// The selected template, raw slot data, and formatted representation.
final class MaskedValue {
  MaskedValue(this.template, this.slots, this.formatted);
  final String template;
  final List<String> slots;
  final String formatted;
  String get raw => slots.join();
}

final class MaskedInput {
  MaskedInput(this.label, {required List<MaskTemplate> templates})
    : templates = List.unmodifiable(templates);
  final String label;
  final List<MaskTemplate> templates;

  bool _active = false;

  Future<PromptResult<MaskedValue>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null) return await _run(source, selected);
      if (_terminalActive) {
        throw StateError('A terminal session is already active.');
      }
      _terminalActive = true;
      try {
        return await _terminal<MaskedValue>(
          selected,
          output ?? stderr,
          (source, mode, restore) => _run(source, mode, beforeClose: restore),
        );
      } finally {
        _terminalActive = false;
      }
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<MaskedValue>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    if (source is ScriptedInput) {
      if (mode == PromptMode.rich && !source.supportsRich) {
        return Unavailable(
          'Rich interaction unavailable; use linear or automatic mode.',
        );
      }
      if (mode == PromptMode.automatic) {
        mode = source.supportsRich ? PromptMode.rich : PromptMode.linear;
      }
      return _interactive(source, mode, beforeClose);
    }
    source as SuppliedAnswer;
    final matches = <MaskedValue>[];
    for (final template in templates) {
      for (final formatted in [false, true]) {
        final chars = source.value.characters.toList();
        final slots = <String>[];
        var offset = 0;
        var valid = true;
        for (final element in template.elements) {
          if (element is MaskLiteral) {
            if (formatted) {
              for (final c in element.text.characters) {
                if (offset >= chars.length || chars[offset++] != c) {
                  valid = false;
                  break;
                }
              }
            }
          } else if (element is MaskSlot) {
            if (offset >= chars.length || !element.accepts(chars[offset])) {
              valid = false;
              break;
            }
            slots.add(chars[offset++]);
          }
        }
        if (valid && offset == chars.length) {
          var i = 0;
          final result = template.elements
              .map((e) => e is MaskLiteral ? e.text : slots[i++])
              .join();
          final value = MaskedValue(
            template.name,
            List.unmodifiable(slots),
            result,
          );
          if (!matches.any(
            (m) => m.template == value.template && m.raw == value.raw,
          )) {
            matches.add(value);
          }
        }
      }
    }
    return matches.length == 1
        ? Accepted(matches.single)
        : Unavailable('Invalid or ambiguous mask.');
  }

  Future<PromptResult<MaskedValue>> _interactive(
    ScriptedInput source,
    PromptMode mode,
    void Function()? beforeClose,
  ) async {
    if (mode == PromptMode.rich && templates.length == 1) {
      return _richFixed(source, beforeClose);
    }
    final keys = _Keys(source.input.transform(utf8.encoder));
    final out = source.output;
    var draft = '';
    out.writeln(
      '$label: Enter raw or formatted value. Escape cancels; Ctrl+C interrupts.',
    );
    try {
      while (true) {
        final edit = await _edit(
          keys,
          draft,
          out,
          linear: mode == PromptMode.linear,
          sequential: mode == PromptMode.linear,
        );
        if (edit.action == 'cancel') return Cancelled();
        if (edit.action == 'interrupt') return Interrupted();
        if (edit.action != 'submit') return InputEnded();
        draft = edit.value;
        final result = await _run(SuppliedAnswer(draft), mode);
        if (result is Accepted<MaskedValue>) return result;
        out.writeln('Invalid or ambiguous mask; edit and submit again.');
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }

  Future<PromptResult<MaskedValue>> _richFixed(
    ScriptedInput source,
    void Function()? beforeClose,
  ) async {
    final template = templates.single;
    final rules = template.elements.whereType<MaskSlot>().toList();
    final slots = List<String>.filled(rules.length, '');
    final keys = _Keys(source.input.transform(utf8.encoder));
    final out = source.output;
    var focus = 0;
    void show() {
      out.writeln('$label. Template: ${template.name}.');
      for (var i = 0; i < slots.length; i++) {
        out.writeln(
          'Slot ${i + 1}: ${slots[i].isEmpty ? "empty" : slots[i]} (${rules[i].description})${i == focus ? " [focused]" : ""}.',
        );
      }
    }

    try {
      show();
      while (true) {
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') return Cancelled();
        if (key == '\x1b[D' && focus > 0) focus--;
        if (key == '\x1b[C' && focus < slots.length) focus++;
        if ((key == '\x7f' || key == '\x08') && focus > 0) slots[--focus] = '';
        if (key == '\x1b[3~' && focus < slots.length) slots[focus] = '';
        if ((key == '\r' || key == '\n')) {
          if (slots.indexed.any(
            (entry) => rules[entry.$1].required && entry.$2.isEmpty,
          )) {
            out.writeln('Required slots are incomplete.');
          } else {
            var index = 0;
            final formatted = template.elements
                .map((e) => e is MaskLiteral ? e.text : slots[index++])
                .join();
            return Accepted(
              MaskedValue(template.name, List.unmodifiable(slots), formatted),
            );
          }
        } else if (!key.startsWith('\x1b') &&
            key.runes.first >= 32 &&
            focus < slots.length) {
          if (rules[focus].accepts(key)) {
            slots[focus++] = key;
          } else {
            out.writeln('Slot does not accept that grapheme.');
          }
        }
        show();
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }
}
