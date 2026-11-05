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

/// Declares whether external text is raw slot data or formatted text.
enum MaskInterpretation { automatic, raw, formatted }

/// The selected template, raw slot data, and formatted representation.
final class MaskedValue {
  MaskedValue(
    this.template,
    List<String> slots,
    this.formatted, {
    this.interpretation = MaskInterpretation.automatic,
  }) : slots = List.unmodifiable(slots);
  final String template;
  final List<String> slots;
  final String formatted;
  final MaskInterpretation interpretation;
  String get raw => slots.join();
}

final class MaskedInput {
  MaskedInput(
    this.label, {
    required List<MaskTemplate> templates,
    this.initialValue,
    this.interpretation = MaskInterpretation.automatic,
  }) : templates = List.unmodifiable(templates) {
    if (label.trim().isEmpty ||
        label.runes.any((c) => c < 32 || c == 127) ||
        templates.isEmpty ||
        templates.map((t) => t.name).toSet().length != templates.length) {
      throw ArgumentError('Invalid label or templates.');
    }
    for (final template in templates) {
      if (template.name.trim().isEmpty ||
          template.name.runes.any((c) => c < 32 || c == 127) ||
          template.elements.whereType<MaskSlot>().isEmpty) {
        throw ArgumentError('Invalid template.');
      }
    }
    if (initialValue != null) {
      final matching = templates.where((t) => t.name == initialValue!.template);
      if (matching.length != 1) {
        throw ArgumentError.value(initialValue, 'initialValue');
      }
      final template = matching.single;
      final rules = template.elements.whereType<MaskSlot>().toList();
      final slots = initialValue!.slots;
      if (slots.length != rules.length ||
          slots.indexed.any(
            (e) =>
                e.$2.isNotEmpty &&
                (e.$2.characters.length != 1 ||
                    e.$2.runes.any((c) => c < 32 || c == 127) ||
                    !rules[e.$1].accepts(e.$2)),
          )) {
        throw ArgumentError.value(initialValue, 'initialValue');
      }
      var i = 0;
      final formatted = template.elements
          .map((e) => e is MaskLiteral ? e.text : slots[i++])
          .join();
      if (formatted != initialValue!.formatted) {
        throw ArgumentError.value(initialValue, 'initialValue');
      }
    }
  }
  final String label;
  final List<MaskTemplate> templates;
  final MaskedValue? initialValue;
  final MaskInterpretation interpretation;

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
    final matches = _decode(source.value);
    return matches.length == 1
        ? Accepted(matches.single)
        : Unavailable('Invalid or ambiguous mask.');
  }

  List<MaskedValue> _decode(String text, {MaskInterpretation? as}) {
    final activeInterpretation = as ?? interpretation;
    final matches = <MaskedValue>[];
    for (final template in templates) {
      for (final formatted in [false, true]) {
        if ((activeInterpretation == MaskInterpretation.raw && formatted) ||
            (activeInterpretation == MaskInterpretation.formatted &&
                !formatted)) {
          continue;
        }
        final chars = text.characters.toList();
        final slots = <String>[];
        void decode(int elementIndex, int offset) {
          if (elementIndex == template.elements.length) {
            if (offset != chars.length) return;
            var i = 0;
            final result = template.elements
                .map((e) => e is MaskLiteral ? e.text : slots[i++])
                .join();
            final value = MaskedValue(
              template.name,
              slots,
              result,
              interpretation: formatted
                  ? MaskInterpretation.formatted
                  : MaskInterpretation.raw,
            );
            if (!matches.any(
              (m) =>
                  m.template == value.template &&
                  m.slots.length == value.slots.length &&
                  m.slots.indexed.every((e) => e.$2 == value.slots[e.$1]),
            )) {
              matches.add(value);
            }
            return;
          }
          final element = template.elements[elementIndex];
          if (element is MaskLiteral) {
            if (!formatted) {
              decode(elementIndex + 1, offset);
            } else {
              final literal = element.text.characters.toList();
              if (offset + literal.length <= chars.length &&
                  literal.indexed.every((e) => e.$2 == chars[offset + e.$1])) {
                decode(elementIndex + 1, offset + literal.length);
              }
            }
          } else if (element is MaskSlot) {
            if (!element.required) {
              slots.add('');
              decode(elementIndex + 1, offset);
              slots.removeLast();
            }
            if (offset < chars.length && element.accepts(chars[offset])) {
              slots.add(chars[offset]);
              decode(elementIndex + 1, offset + 1);
              slots.removeLast();
            }
          }
        }

        decode(0, 0);
      }
    }
    return matches;
  }

  Future<PromptResult<MaskedValue>> _interactive(
    ScriptedInput source,
    PromptMode mode,
    void Function()? beforeClose,
  ) async {
    if (templates.length == 1) {
      if (mode == PromptMode.rich) return _richFixed(source, beforeClose);
      return _linearFixed(source, beforeClose);
    }
    if (mode == PromptMode.linear) return _linearAdaptive(source, beforeClose);
    final keys = _Keys(source.input.transform(utf8.encoder));
    final out = source.output;
    var draft = initialValue?.formatted ?? '';
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
        if (result is Accepted<MaskedValue>) {
          out.writeln(
            'Selected template: ${result.value.template}. Raw: ${result.value.raw}. Formatted: ${result.value.formatted}.',
          );
          return await _richFixed(
            source,
            null,
            selectedTemplate: templates.singleWhere(
              (candidate) => candidate.name == result.value.template,
            ),
            initial: result.value,
            keyInput: keys,
          );
        }
        final matches = _decode(draft);
        if (matches.length < 2) {
          out.writeln('Invalid mask; draft preserved: $draft');
          continue;
        }
        out.writeln('Ambiguous value. Draft preserved: $draft');
        for (var i = 0; i < matches.length; i++) {
          out.writeln('${i + 1}. ${matches[i].template}');
        }
        out.writeln('Choose a template number:');
        final choice = await _edit(keys, '', out);
        if (choice.action == 'cancel') return Cancelled();
        if (choice.action == 'interrupt') return Interrupted();
        if (choice.action != 'submit') return InputEnded();
        final index = int.tryParse(choice.value);
        if (index == null || index < 1 || index > matches.length) {
          out.writeln('Invalid template number; draft preserved: $draft');
          continue;
        }
        final selected = matches[index - 1];
        out.writeln(
          'Selected template: ${selected.template}. Raw: ${selected.raw}. Formatted: ${selected.formatted}.',
        );
        return Accepted(selected);
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }

  Future<PromptResult<MaskedValue>> _linearAdaptive(
    ScriptedInput source,
    void Function()? beforeClose,
  ) async {
    final keys = _Keys(source.input.transform(utf8.encoder));
    final out = source.output;
    var draft = initialValue?.formatted ?? '';
    var selected = initialValue;
    var matches = <MaskedValue>[];
    void showTemplates() {
      for (var i = 0; i < matches.length; i++) {
        out.writeln('${i + 1}. ${matches[i].template}');
      }
    }

    Future<({String action, String value})> edit([
      String initial = '',
      Set<String> commands = const {},
    ]) => _edit(
      keys,
      initial,
      out,
      linear: true,
      sequential: true,
      extraCommands: commands,
    );
    try {
      out.writeln(
        r'/template chooses an ambiguous template; /done submits. /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal.',
      );
      while (true) {
        final editResult = await edit('', {
          '/template',
          '/value',
          '/edit',
          '/done',
          '/review',
        });
        if (editResult.action == 'cancel') return Cancelled();
        if (editResult.action == 'interrupt') return Interrupted();
        if (editResult.action != 'submit' && editResult.action != 'command') {
          return InputEnded();
        }
        if (editResult.action == 'submit' || editResult.value == '/value') {
          if (editResult.value == '/value') {
            out.writeln('Edit raw or formatted value:');
            final entry = await edit(draft);
            if (entry.action == 'cancel') return Cancelled();
            if (entry.action == 'interrupt') return Interrupted();
            if (entry.action != 'submit') return InputEnded();
            draft = entry.value;
          } else {
            draft = editResult.value;
          }
          selected = null;
          final decoded = await _run(SuppliedAnswer(draft), PromptMode.linear);
          if (decoded is Accepted<MaskedValue>) {
            selected = decoded.value;
            matches = [selected];
            out.writeln(
              'Template: ${selected.template}. Raw: ${selected.raw}. Formatted: ${selected.formatted}.',
            );
          } else {
            matches = _decode(draft);
            if (matches.length > 1) {
              out.writeln('Ambiguous value; choose a template with /template:');
              showTemplates();
            } else {
              out.writeln('Invalid mask; draft preserved: $draft');
            }
          }
          continue;
        }
        if (editResult.value == '/edit') {
          if (selected == null) {
            out.writeln('Choose a template before correcting a slot.');
            continue;
          }
          final current = selected;
          final rules = templates
              .singleWhere((template) => template.name == current.template)
              .elements
              .whereType<MaskSlot>()
              .toList();
          out.writeln('Slot number:');
          final number = await edit();
          if (number.action == 'cancel') return Cancelled();
          if (number.action == 'interrupt') return Interrupted();
          if (number.action != 'submit') return InputEnded();
          final slot = int.tryParse(number.value);
          if (slot == null || slot < 1 || slot > rules.length) {
            out.writeln('Invalid slot number.');
            continue;
          }
          out.writeln('Enter replacement grapheme, or empty to clear:');
          final replacement = await edit();
          if (replacement.action == 'cancel') return Cancelled();
          if (replacement.action == 'interrupt') return Interrupted();
          if (replacement.action != 'submit') return InputEnded();
          if (replacement.value.isNotEmpty &&
              (replacement.value.characters.length != 1 ||
                  !rules[slot - 1].accepts(replacement.value))) {
            out.writeln('Invalid slot value.');
            continue;
          }
          final slots = List<String>.of(current.slots);
          slots[slot - 1] = replacement.value;
          var index = 0;
          final template = templates.singleWhere(
            (candidate) => candidate.name == current.template,
          );
          draft = template.elements
              .map(
                (element) =>
                    element is MaskLiteral ? element.text : slots[index++],
              )
              .join();
          matches = _decode(slots.join());
          selected = MaskedValue(current.template, slots, draft);
          if (matches.length > 1) {
            selected = null;
            out.writeln('Ambiguity reopened; draft preserved: $draft');
            showTemplates();
          }
          continue;
        }
        if (editResult.value == '/review') {
          out.writeln('Draft: $draft');
          if (selected != null) {
            out.writeln(
              'Template: ${selected.template}. Raw: ${selected.raw}. Formatted: ${selected.formatted}.',
            );
          }
          showTemplates();
          continue;
        }
        if (editResult.value == '/done') {
          if (selected == null) {
            out.writeln('Choose an unambiguous template before submitting.');
            continue;
          }
          final rules = templates
              .singleWhere((t) => t.name == selected!.template)
              .elements
              .whereType<MaskSlot>()
              .toList();
          if (selected.slots.indexed.any(
            (e) => rules[e.$1].required && e.$2.isEmpty,
          )) {
            out.writeln('Required slots are incomplete.');
            continue;
          }
          return Accepted(selected);
        }
        if (matches.isEmpty) {
          out.writeln('Submit a value with multiple valid templates first.');
          continue;
        }
        out.writeln('Template number:');
        showTemplates();
        final choice = await edit();
        if (choice.action == 'cancel') return Cancelled();
        if (choice.action == 'interrupt') return Interrupted();
        if (choice.action != 'submit') return InputEnded();
        final index = int.tryParse(choice.value);
        if (index == null || index < 1 || index > matches.length) {
          out.writeln('Invalid template number.');
          continue;
        }
        selected = matches[index - 1];
        draft = selected.formatted;
        out.writeln(
          'Selected template: ${selected.template}. Raw: ${selected.raw}. Formatted: ${selected.formatted}.',
        );
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
    void Function()? beforeClose, {
    MaskTemplate? selectedTemplate,
    MaskedValue? initial,
    _Keys? keyInput,
  }) async {
    final template = selectedTemplate ?? templates.single;
    initial ??= initialValue;
    final rules = template.elements.whereType<MaskSlot>().toList();
    final slots = initial == null
        ? List<String>.filled(rules.length, '')
        : List<String>.of(initial.slots);
    final keys = keyInput ?? _Keys(source.input.transform(utf8.encoder));
    final out = source.output;
    var focus = initial == null ? 0 : slots.length;
    var provenance = initial?.interpretation ?? MaskInterpretation.automatic;
    int? lastTyped;
    var edited = false;
    var ambiguityAnnounced = false;
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
        if (key == '\x1b[999~') {
          out.writeln('Paste rejected: exceeds 4096 UTF-16 code units.');
          continue;
        }
        if (key.startsWith('\x1b[200~')) {
          final paste = key.substring(6, key.length - 6);
          if (paste.runes.any((c) => c < 32 || c == 127)) {
            out.writeln('Paste rejected: single-line printable text only.');
            continue;
          }
          final matches = _decode(paste);
          if (matches.length > 1 ||
              (matches.length == 1 &&
                  matches.single.template != template.name)) {
            out.writeln(
              'Paste requires template or interpretation resolution. Draft preserved: $paste',
            );
            for (var i = 0; i < matches.length; i++) {
              out.writeln(
                '${i + 1}. ${matches[i].template}: ${matches[i].interpretation.name}, raw ${matches[i].raw}, formatted ${matches[i].formatted}',
              );
            }
            out.writeln(
              'Choose a number, or press Enter to keep the current value:',
            );
            final choice = await _edit(keys, '', out);
            if (choice.action == 'cancel') return Cancelled();
            if (choice.action == 'interrupt') return Interrupted();
            if (choice.action != 'submit') return InputEnded();
            final index = int.tryParse(choice.value);
            if (index != null && index >= 1 && index <= matches.length) {
              final selected = matches[index - 1];
              out.writeln('Selected template: ${selected.template}.');
              return await _richFixed(
                source,
                null,
                selectedTemplate: templates.singleWhere(
                  (t) => t.name == selected.template,
                ),
                initial: selected,
                keyInput: keys,
              );
            }
            show();
            continue;
          }
          if (matches.length == 1 && matches.single.template == template.name) {
            slots.setAll(0, matches.single.slots);
            provenance = matches.single.interpretation;
            focus = slots.length;
            lastTyped = null;
          } else {
            final capacity = template.elements.fold<int>(
              0,
              (total, element) =>
                  total +
                  (element is MaskLiteral ? element.text.characters.length : 1),
            );
            if (paste.characters.length > capacity) {
              out.writeln('Paste rejected: exceeds template capacity.');
            } else {
              out.writeln(
                'Paste requires template or interpretation resolution.',
              );
            }
            out.writeln('Draft preserved: $paste');
          }
          show();
          continue;
        }
        if (key.runes.first < 32 || key == '\x7f') lastTyped = null;
        if (key == '\x1b[D' && focus > 0) focus--;
        if (key == '\x1b[C' && focus < slots.length) focus++;
        if ((key == '\x7f' || key == '\x08') && focus > 0) {
          slots[--focus] = '';
          edited = true;
          provenance = MaskInterpretation.automatic;
        }
        if (key == '\x1b[3~' && focus < slots.length) {
          slots[focus] = '';
          edited = true;
          provenance = MaskInterpretation.automatic;
        }
        if ((key == '\r' || key == '\n')) {
          if (slots.indexed.any(
            (entry) => rules[entry.$1].required && entry.$2.isEmpty,
          )) {
            out.writeln('Required slots are incomplete.');
          } else {
            if (edited && templates.length > 1) {
              final matches = _decode(slots.join(), as: MaskInterpretation.raw);
              if (matches.length > 1) {
                out.writeln(
                  'Ambiguity reopened; draft preserved: ${slots.join()}',
                );
                for (var i = 0; i < matches.length; i++) {
                  out.writeln(
                    '${i + 1}. ${matches[i].template}: ${matches[i].formatted}',
                  );
                }
                out.writeln('Choose a template number:');
                final choice = await _edit(keys, '', out);
                if (choice.action == 'cancel') return Cancelled();
                if (choice.action == 'interrupt') return Interrupted();
                if (choice.action != 'submit') return InputEnded();
                final index = int.tryParse(choice.value);
                if (index == null || index < 1 || index > matches.length) {
                  out.writeln('Invalid template number.');
                  continue;
                }
                final selected = matches[index - 1];
                out.writeln('Selected template: ${selected.template}.');
                return await _richFixed(
                  source,
                  null,
                  selectedTemplate: templates.singleWhere(
                    (t) => t.name == selected.template,
                  ),
                  initial: selected,
                  keyInput: keys,
                );
              }
            }
            var index = 0;
            final formatted = template.elements
                .map((e) => e is MaskLiteral ? e.text : slots[index++])
                .join();
            return Accepted(
              MaskedValue(
                template.name,
                List.unmodifiable(slots),
                formatted,
                interpretation: provenance,
              ),
            );
          }
        } else if (!key.startsWith('\x1b') && key.runes.first >= 32) {
          provenance = MaskInterpretation.automatic;
          final prior = lastTyped;
          if (prior != null && (slots[prior] + key).characters.length == 1) {
            final combined = slots[prior] + key;
            if (rules[prior].accepts(combined)) {
              edited = true;
              slots[prior] = combined;
            } else {
              out.writeln('Slot does not accept that grapheme.');
            }
          } else if (focus < slots.length && rules[focus].accepts(key)) {
            edited = true;
            slots[focus] = key;
            lastTyped = focus++;
          } else {
            lastTyped = null;
            out.writeln('Slot does not accept that grapheme.');
          }
        }
        if (edited && templates.length > 1) {
          final ambiguous =
              _decode(slots.join(), as: MaskInterpretation.raw).length > 1;
          if (ambiguous && !ambiguityAnnounced) {
            out.writeln('Ambiguity reopened; draft preserved: ${slots.join()}');
          }
          ambiguityAnnounced = ambiguous;
        }
        show();
      }
    } finally {
      if (keyInput == null) {
        try {
          beforeClose?.call();
        } finally {
          await keys.close();
        }
      }
    }
  }

  Future<PromptResult<MaskedValue>> _linearFixed(
    ScriptedInput source,
    void Function()? beforeClose,
  ) async {
    final template = templates.single;
    final rules = template.elements.whereType<MaskSlot>().toList();
    var slots = initialValue == null
        ? List<String>.filled(rules.length, '')
        : List<String>.of(initialValue!.slots);
    final out = source.output;
    final keys = _Keys(source.input.transform(utf8.encoder));
    String formatted() {
      var index = 0;
      return template.elements
          .map((e) => e is MaskLiteral ? e.text : slots[index++])
          .join();
    }

    void show() {
      out.writeln(
        '$label. Template: ${template.name}. Raw: ${slots.join()}. Formatted: ${formatted()}.',
      );
      for (var i = 0; i < slots.length; i++) {
        out.writeln(
          'Slot ${i + 1}: ${slots[i].isEmpty ? "empty" : slots[i]} (${rules[i].description}).',
        );
      }
    }

    Future<({String action, String value})> edit([
      String initial = '',
      Set<String> commands = const {},
    ]) => _edit(
      keys,
      initial,
      out,
      linear: true,
      sequential: true,
      extraCommands: commands,
    );
    try {
      out.writeln(
        r'/edit corrects a slot; /value edits the formatted value; /done submits. /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal.',
      );
      show();
      while (true) {
        final command = await edit('', {'/edit', '/value', '/done', '/review'});
        if (command.action == 'cancel') return Cancelled();
        if (command.action == 'interrupt') return Interrupted();
        if (command.action != 'submit' && command.action != 'command') {
          return InputEnded();
        }
        if (command.action == 'command' && command.value == '/review') {
          show();
          continue;
        }
        if (command.action == 'command' && command.value == '/done') {
          if (slots.indexed.any((e) => rules[e.$1].required && e.$2.isEmpty)) {
            out.writeln('Required slots are incomplete.');
            continue;
          }
          return Accepted(
            MaskedValue(template.name, List.unmodifiable(slots), formatted()),
          );
        }
        if (command.action == 'command' && command.value == '/edit') {
          out.writeln('Slot number:');
          final number = await edit();
          if (number.action == 'cancel') return Cancelled();
          if (number.action == 'interrupt') return Interrupted();
          if (number.action != 'submit') return InputEnded();
          final index = int.tryParse(number.value);
          if (index == null || index < 1 || index > slots.length) {
            out.writeln('Invalid slot number.');
            continue;
          }
          out.writeln('Enter replacement grapheme, or empty to clear:');
          final replacement = await edit();
          if (replacement.action == 'cancel') return Cancelled();
          if (replacement.action == 'interrupt') return Interrupted();
          if (replacement.action != 'submit') return InputEnded();
          if (replacement.value.isNotEmpty &&
              (replacement.value.characters.length != 1 ||
                  !rules[index - 1].accepts(replacement.value))) {
            out.writeln('Invalid slot value.');
            continue;
          }
          slots[index - 1] = replacement.value;
          show();
          continue;
        }
        var value = command.value;
        if (command.action == 'command' && command.value == '/value') {
          out.writeln('Edit formatted value:');
          final entry = await edit(formatted());
          if (entry.action == 'cancel') return Cancelled();
          if (entry.action == 'interrupt') return Interrupted();
          if (entry.action != 'submit') return InputEnded();
          value = entry.value;
        }
        final matches = _decode(value);
        if (matches.length == 1) {
          slots = List.of(matches.single.slots);
          show();
        } else if (matches.length > 1) {
          out.writeln('Choose an interpretation; draft preserved: $value');
          for (var i = 0; i < matches.length; i++) {
            final description = matches[i].slots.indexed
                .map(
                  (e) => 'slot ${e.$1 + 1}: ${e.$2.isEmpty ? "empty" : e.$2}',
                )
                .join(', ');
            out.writeln(
              '${i + 1}. ${matches[i].interpretation.name}: $description',
            );
          }
          final choice = await edit();
          if (choice.action == 'cancel') return Cancelled();
          if (choice.action == 'interrupt') return Interrupted();
          if (choice.action != 'submit') return InputEnded();
          final index = int.tryParse(choice.value);
          if (index == null || index < 1 || index > matches.length) {
            out.writeln(
              'Invalid interpretation number; draft preserved: $value',
            );
          } else {
            slots = List.of(matches[index - 1].slots);
            show();
          }
        } else {
          out.writeln('Invalid value; draft: $value');
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
}
