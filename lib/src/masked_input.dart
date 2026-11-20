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
    : elements = List.unmodifiable(elements) {
    if (name.trim().isEmpty ||
        name.runes.any((c) => c < 32 || c == 127) ||
        elements.whereType<MaskSlot>().isEmpty) {
      throw ArgumentError('Invalid template.');
    }
  }
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

final class _MaskWorkLimit implements Exception {}

/// The interaction stage that requested component help from [MaskedInput].
///
/// Help leads with the stage so slot editing, submission, interpretation and
/// template choice do not share one undifferentiated generic editor page.
enum _MaskHelpStage { slot, submit, interpretation, template, review }

/// The display cells of one mask fragment using the shared measurement policy.
int _maskCells(String text) =>
    TextDisplayMap(text).entries
        .fold(0, (total, entry) => total + entry.cellWidth);

/// Wraps transcript notices so each one stays inside the declared width.
///
/// Inline editor repaints use [write] and are unaffected: only whole notices
/// start a new line, so wrapping them cannot overwrite an editable line. When
/// the component declares a rail or branch structure, each notice is also a
/// block inside that spine: [hint] closes the structural line for the compact
/// hint, and later notices continue it.
final class _WrappedNotices implements StringSink {
  _WrappedNotices(
    this._output,
    this._width, {
    PromptStructure structure = PromptStructure.plain,
    bool ascii = true,
    ColorTheme colors = ColorThemes.terminalDefault,
  }) : _spine = usesStructureFraming(structure)
           ? _StructureSpine(
               structure: structure,
               ascii: ascii,
               width: _width(),
               background: colors.background,
               border: colors.border,
               outputProfile: null,
             )
           : null,
       _colors = colors;

  final StringSink _output;
  final int? Function() _width;
  final _StructureSpine? _spine;
  final ColorTheme _colors;

  @override
  void write(Object? object) => _output.write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _output.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _output.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => _emit('$object');

  /// Writes one refusal or validation notice.
  ///
  /// The component's words are unchanged: a grammar that declares typed
  /// prefixes presents the line as a `warning:` row, and every other structure
  /// writes the block it always wrote, because only the diagnostic grammar
  /// spells a label for the event kind.
  void warning(Object? object) => _emit('$object', event: StageEvent.warning);

  /// Writes the compact hint that closes the current structural line.
  ///
  /// A heading structure keeps the hint under its body rows with its own marker,
  /// which is the declared hint placement. Every other structure keeps the block
  /// it always wrote, so the rail, branch and enclosing bytes are unchanged.
  void hint(Object? object) {
    final spine = _spine;
    if (spine != null && spine.heads) {
      spine.width = _width();
      spine.hint(_output, '$object', foreground: _colors.foreground);
      return;
    }
    _emit('$object', closes: true);
  }

  /// Whether a heading structure decorates this component's output.
  bool get heads => _spine?.heads ?? false;

  /// Writes one stage heading, decorated by a heading structure.
  ///
  /// A structure without a heading grammar keeps the single block it always
  /// wrote, so the reference, rail, branch and enclosing presentations keep
  /// their bytes.
  void heading(Object? object) {
    final spine = _spine;
    final text = '$object';
    if (spine == null) {
      _emit(text);
      return;
    }
    spine.width = _width();
    spine.heading(_output, text, foreground: _colors.foreground);
  }

  /// Writes one stage opening: a heading and the text that belongs under it.
  void opening(Object? title, Object? body) {
    final spine = _spine;
    if (spine == null) {
      _emit('$title $body');
      return;
    }
    spine.width = _width();
    spine.opening(
      _output,
      title: '$title',
      body: '$body',
      foreground: _colors.foreground,
      bodyForeground: _colors.foreground,
    );
  }

  void _emit(
    String text, {
    bool closes = false,
    StageEvent event = StageEvent.body,
  }) {
    final spine = _spine;
    if (spine == null) {
      final width = _width();
      if (width == null) {
        _output.writeln(text);
        return;
      }
      _writeWrappedText(_output, text, width);
      return;
    }
    spine.width = _width();
    spine.write(
      _output,
      text,
      foreground: _colors.foreground,
      closes: closes,
      event: event,
    );
  }
}

/// One mutable effective profile for a single prompt run.
///
/// An idle resize replaces the geometry while every helper keeps reading the
/// same holder, so notices, layout and nested editors share one width policy.
final class _ProfileBox {
  _ProfileBox(this.value);
  OutputProfile value;
}

final class MaskedInput {
  MaskedInput(
    this.label, {
    required List<MaskTemplate> templates,
    this.initialValue,
    this.interpretation = MaskInterpretation.automatic,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : templates = List.unmodifiable(templates),
       supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty ||
        label.runes.any((c) => c < 32 || c == 127) ||
        templates.isEmpty ||
        templates.map((t) => t.name).toSet().length != templates.length) {
      throw ArgumentError('Invalid label or templates.');
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
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;

  bool _active = false;

  Future<PromptResult<MaskedValue>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      try {
        return await session._promptRunner<MaskedValue>(
          _run,
          source: source,
          mode: mode,
          userPreference: userPreference,
          applicationPreference: applicationPreference,
          output: output,
          terminal: terminal,
          outputProfile: outputProfile,
        );
      } on _MaskWorkLimit {
        return Unavailable('Mask decoding work limit exceeded.');
      }
    }
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source != null) {
        return await _run(source, selected, outputProfile: outputProfile);
      }
      if (_terminalActive) {
        throw StateError('A terminal session is already active.');
      }
      _terminalActive = true;
      try {
        if (terminal != null) {
          return await SharedTerminalLease.run(terminal, () async {
            return _run(
              ScriptedInput(
                terminal.input,
                terminal.output,
                supportsRich: terminal.supportsRich,
                outputProfile: _terminalOutputProfile(terminal),
                hardColorDisabled:
                    terminal.environment['NO_COLOR']?.isNotEmpty == true,
                resizeObserver: _terminalResizeObserver(terminal),
              ),
              selected,
              outputProfile: outputProfile,
            );
          });
        }
        return await _terminal<MaskedValue>(
          selected,
          output ?? stdout,
          (nativeSource, nativeMode, _) =>
              _run(nativeSource, nativeMode, outputProfile: outputProfile),
        );
      } finally {
        _terminalActive = false;
      }
    } on _MaskWorkLimit {
      return Unavailable('Mask decoding work limit exceeded.');
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<MaskedValue>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final matches = _decode(source.value);
      return matches.length == 1
          ? Accepted(matches.single)
          : Unavailable('Invalid or ambiguous mask.');
    }
    final scripted = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    final profileBox = _ProfileBox(effectiveProfile);
    final out = _WrappedNotices(
      scripted.output,
      () => _textInputWidth(profileBox.value),
      structure: structure,
      ascii: _structureAscii(effectiveProfile),
      colors: colors,
    );
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    try {
      return await _interactive(
        scripted,
        mode,
        out,
        inputKeys,
        profileBox,
        session,
      );
    } finally {
      if (keys == null) await inputKeys.close();
    }
  }

  String _slotDescriptions(MaskedValue value) => value.slots.indexed
      .map((e) => 'slot ${e.$1 + 1}: ${e.$2.isEmpty ? "empty" : e.$2}')
      .join(', ');

  List<MaskedValue> _decode(String text, {MaskInterpretation? as}) {
    final activeInterpretation = as ?? interpretation;
    final matches = <MaskedValue>[];
    if (text.length > 4096 || templates.length > 256) throw _MaskWorkLimit();
    final chars = text.characters.toList();
    var work = 0;
    for (final template in templates) {
      if (template.elements.length > 256) throw _MaskWorkLimit();
      for (final formatted in [false, true]) {
        if ((activeInterpretation == MaskInterpretation.raw && formatted) ||
            (activeInterpretation == MaskInterpretation.formatted &&
                !formatted)) {
          continue;
        }
        final slots = <String>[];
        void decode(int elementIndex, int offset) {
          if (++work > 10000 || matches.length >= 256) throw _MaskWorkLimit();
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
    _WrappedNotices out,
    _Keys keys,
    _ProfileBox profileBox,
    TerminalSession? session,
  ) async {
    if (templates.length == 1) {
      if (mode == PromptMode.rich) {
        return _richFixed(source, out, keys, profileBox, session);
      }
      return _linearFixed(source, out, keys, profileBox, session);
    }
    if (mode == PromptMode.linear) {
      return _linearAdaptive(source, out, keys, profileBox, session);
    }
    var draft = initialValue?.formatted ?? '';
    out.heading('$label.');
    out.hint(
      'Enter raw or formatted value. Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
    );
    while (true) {
      final edit = await _edit(
        keys,
        draft,
        out,
        helpText: _help(linear: false, stage: _MaskHelpStage.interpretation),
        outputProfile: profileBox.value,
        structure: structure,
        session: session,
        resizeObserver: source.resizeObserver,
      );
      if (edit.action == 'cancel') return Cancelled();
      if (edit.action == 'interrupt') return Interrupted();
      if (edit.action != 'submit') return InputEnded();
      draft = edit.value;
      late final List<MaskedValue> matches;
      try {
        matches = _decode(draft);
      } on _MaskWorkLimit {
        out.warning(
          'Mask decoding work limit exceeded; draft preserved: $draft',
        );
        continue;
      }
      if (matches.length == 1) {
        final result = Accepted(matches.single);
        out.writeln(
          'Selected template: ${result.value.template}. Raw: ${result.value.raw}. Formatted: ${result.value.formatted}.',
        );
        return await _richFixed(
          source,
          out,
          keys,
          profileBox,
          session,
          selectedTemplate: templates.singleWhere(
            (candidate) => candidate.name == result.value.template,
          ),
          initial: result.value,
        );
      }
      if (matches.length < 2) {
        out.warning('Invalid mask; draft preserved: $draft');
        continue;
      }
      out.warning('Ambiguous value. Draft preserved: $draft');
      for (var i = 0; i < matches.length; i++) {
        out.writeln(
          '${i + 1}. ${matches[i].template}: ${_slotDescriptions(matches[i])}',
        );
      }
      out.writeln('Choose a template number:');
      final choice = await _edit(
        keys,
        '',
        out,
        helpText: _help(linear: false, stage: _MaskHelpStage.template),
        outputProfile: profileBox.value,
        structure: structure,
        session: session,
        resizeObserver: source.resizeObserver,
      );
      if (choice.action == 'cancel') return Cancelled();
      if (choice.action == 'interrupt') return Interrupted();
      if (choice.action != 'submit') return InputEnded();
      final index = int.tryParse(choice.value);
      if (index == null || index < 1 || index > matches.length) {
        out.warning('Invalid template number; draft preserved: $draft');
        continue;
      }
      final selected = matches[index - 1];
      out.writeln(
        'Selected template: ${selected.template}. Raw: ${selected.raw}. Formatted: ${selected.formatted}.',
      );
      return await _richFixed(
        source,
        out,
        keys,
        profileBox,
        session,
        selectedTemplate: templates.singleWhere(
          (candidate) => candidate.name == selected.template,
        ),
        initial: selected,
      );
    }
  }

  Future<PromptResult<MaskedValue>> _linearAdaptive(
    ScriptedInput source,
    _WrappedNotices out,
    _Keys keys,
    _ProfileBox profileBox,
    TerminalSession? session,
  ) async {
    var draft = initialValue?.formatted ?? '';
    var selected = initialValue;
    var matches = <MaskedValue>[];
    void showTemplates() {
      for (var i = 0; i < matches.length; i++) {
        out.writeln(
          '${i + 1}. ${matches[i].template}: ${_slotDescriptions(matches[i])}',
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
      sequential: !profileBox.value.supportsRichInteraction,
      extraCommands: commands,
      linearHelpText: _help(linear: true, template: _activeTemplate(selected)),
      helpText: _help(
        linear: false,
        stage: _MaskHelpStage.interpretation,
        template: _activeTemplate(selected),
      ),
      outputProfile: profileBox.value,
      structure: structure,
      session: session,
    );
    out.heading('$label.');
    out.hint(
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
        try {
          matches = _decode(draft);
        } on _MaskWorkLimit {
          matches = [];
          out.warning(
            'Mask decoding work limit exceeded; draft preserved: $draft',
          );
          continue;
        }
        if (matches.length == 1) {
          selected = matches.single;
          out.writeln(
            'Template: ${selected.template}. Raw: ${selected.raw}. Formatted: ${selected.formatted}.',
          );
        } else {
          if (matches.length > 1) {
            out.warning('Ambiguous value; choose a template with /template:');
            showTemplates();
          } else {
            out.warning('Invalid mask; draft preserved: $draft');
          }
        }
        continue;
      }
      if (editResult.value == '/edit') {
        if (selected == null) {
          out.warning('Choose a template before correcting a slot.');
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
          out.warning('Invalid slot number.');
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
          out.warning('Invalid slot value.');
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
        selected = null;
        try {
          matches = _decode(slots.join());
        } on _MaskWorkLimit {
          matches = [];
          out.warning(
            'Mask decoding work limit exceeded; draft preserved: $draft',
          );
          continue;
        }
        selected = MaskedValue(current.template, slots, draft);
        if (matches.length > 1) {
          selected = null;
          out.warning('Ambiguity reopened; draft preserved: $draft');
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
          out.warning('Choose an unambiguous template before submitting.');
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
          out.warning('Required slots are incomplete.');
          continue;
        }
        return Accepted(selected);
      }
      if (matches.isEmpty) {
        out.warning('Submit a value with multiple valid templates first.');
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
        out.warning('Invalid template number.');
        continue;
      }
      selected = matches[index - 1];
      draft = selected.formatted;
      out.writeln(
        'Selected template: ${selected.template}. Raw: ${selected.raw}. Formatted: ${selected.formatted}.',
      );
    }
  }

  /// The selected template for the current draft, when it is known.
  MaskTemplate? _activeTemplate(MaskedValue? value) {
    if (value == null) return null;
    for (final template in templates) {
      if (template.name == value.template) return template;
    }
    return null;
  }

  /// The declared slot and literal rules of one template.
  String _templateShape(MaskTemplate template) {
    final parts = <String>[];
    var index = 0;
    for (final element in template.elements) {
      if (element is MaskLiteral) {
        parts.add('literal "${element.text}"');
      } else if (element is MaskSlot) {
        index++;
        parts.add(
          'slot $index (${element.description}${element.required ? ', required' : ', optional'})',
        );
      }
    }
    return parts.join(', ');
  }

  /// Component help for the requesting interaction stage.
  ///
  /// The opening sentence names the stage so slot editing, submission,
  /// interpretation and template choice do not share one undifferentiated
  /// generic editor page; the slot and literal rules stay available with it.
  String _help({
    required bool linear,
    _MaskHelpStage stage = _MaskHelpStage.slot,
    MaskTemplate? template,
    int? slot,
  }) {
    final shape = template == null
        ? ''
        : 'Template ${template.name}: ${_templateShape(template)}. ';
    final names = templates.map((t) => t.name).join(', ');
    if (linear) {
      return 'Help: Entering a masked value. $shape/template chooses one of $names; /edit corrects a single slot; /value replaces the whole raw or formatted value; /review lists the draft; /done accepts only when every required slot is filled. Literal characters are fixed formatting, not slot data. Exact /help and /cancel are commands; quote a command with a backslash. Identified paste is literal.';
    }
    return switch (stage) {
      _MaskHelpStage.submit =>
        'Help: Submitting. Enter accepts only when every required slot is filled; the accepted value keeps its template, raw slots, formatted spelling and interpretation. ${shape}Escape cancels and Ctrl+C interrupts.',
      _MaskHelpStage.interpretation =>
        'Help: Entering a raw or formatted value. Raw input is slot data only; formatted input must also match the literal characters. An ambiguous entry lists every template and interpretation instead of guessing. ${shape}Escape cancels and Ctrl+C interrupts.',
      _MaskHelpStage.template =>
        'Help: Choosing a template. Enter the number of the listed template; the chosen template applies its own literal formatting to the same slot data and reopens ambiguity if it still matches more than one. ${shape}Escape cancels and Ctrl+C interrupts.',
      _MaskHelpStage.review =>
        'Help: Reviewing the draft. The draft, template, raw and formatted spellings stay visible; correct one slot or the whole value before submitting. ${shape}Escape cancels and Ctrl+C interrupts.',
      _MaskHelpStage.slot =>
        'Help: Editing ${slot == null ? 'a slot' : 'slot $slot'}. One grapheme per slot; literal characters are fixed formatting rather than slot data. Left/Right move the caret between slots, Backspace clears the previous slot, Delete clears the focused slot and paste fills slots atomically. ${shape}Enter submits and Escape cancels; Ctrl+C interrupts.',
    };
  }

  /// Renders the current masked draft at the declared width.
  ///
  /// The inline layout keeps the field-local caret inside the focused slot. A
  /// narrow output clips around that slot with truthful overflow markers so the
  /// focused field stays visible, and a stacked layout lists every slot and
  /// literal when the focused field cannot fit on one line.
  void _showMaskDraft({
    required _WrappedNotices out,
    required String label,
    required MaskTemplate template,
    required List<MaskSlot> rules,
    required List<String> slots,
    required int focus,
    required int? width,
  }) {
    final caretAtEnd = focus >= slots.length;
    final focusCue = caretAtEnd
        ? 'slot ${slots.length} complete; caret after the last slot'
        : 'slot ${focus + 1} of ${slots.length} (${rules[focus].description}); caret inside that slot';
    out.opening('$label.', 'Template: ${template.name}. Focus: $focusCue.');
    final pieces = <({String text, int cells, bool focused})>[];
    var slotIndex = 0;
    for (final element in template.elements) {
      if (element is MaskLiteral) {
        pieces.add((
          text: element.text,
          cells: _maskCells(element.text),
          focused: false,
        ));
      } else {
        final isFocused = slotIndex == focus;
        final value = slots[slotIndex];
        final text = isFocused ? '[$value]' : value;
        pieces.add((text: text, cells: _maskCells(text), focused: isFocused));
        slotIndex++;
      }
    }
    final inline = pieces.map((piece) => piece.text).join();
    final inlineCells =
        pieces.fold<int>(0, (total, piece) => total + piece.cells) +
        (caretAtEnd ? 1 : 0);
    if (width == null || inlineCells <= width) {
      out.writeln('> $inline${caretAtEnd ? '|' : ''}');
    } else {
      var focusedIndex = pieces.indexWhere((piece) => piece.focused);
      if (focusedIndex < 0) {
        focusedIndex = pieces.isEmpty ? 0 : pieces.length - 1;
      }
      final budget = width - 2;
      final focusedCells = pieces.isEmpty ? 0 : pieces[focusedIndex].cells;
      if (budget < focusedCells + (caretAtEnd ? 1 : 0)) {
        var index = 0;
        for (final element in template.elements) {
          if (element is MaskLiteral) {
            out.writeln('  literal "${element.text}"');
          } else {
            final isFocused = index == focus;
            final value = slots[index];
            out.writeln(
              'Slot ${index + 1}: ${value.isEmpty ? 'empty' : value} (${rules[index].description})${isFocused ? ' [focused]' : ''}.',
            );
            index++;
          }
        }
      } else {
        var start = focusedIndex;
        var end = focusedIndex + 1;
        var used = focusedCells;
        var grew = true;
        while (grew) {
          grew = false;
          if (start > 0 && used + pieces[start - 1].cells <= budget) {
            start--;
            used += pieces[start].cells;
            grew = true;
          }
          if (end < pieces.length && used + pieces[end].cells <= budget) {
            used += pieces[end].cells;
            end++;
            grew = true;
          }
        }
        final window = pieces
            .sublist(start, end)
            .map((piece) => piece.text)
            .join();
        out.writeln(
          '> ${start > 0 ? '<' : ''}$window${caretAtEnd ? '|' : ''}${end < pieces.length ? '>' : ''}',
        );
      }
    }
    out.hint(
      caretAtEnd
          ? 'Enter submits; Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.'
          : 'Left/Right move the caret; Enter submits; Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
    );
  }

  Future<PromptResult<MaskedValue>> _richFixed(
    ScriptedInput source,
    _WrappedNotices out,
    _Keys keys,
    _ProfileBox profileBox,
    TerminalSession? session, {
    MaskTemplate? selectedTemplate,
    MaskedValue? initial,
  }) async {
    final template = selectedTemplate ?? templates.single;
    initial ??= initialValue;
    final rules = template.elements.whereType<MaskSlot>().toList();
    final slots = initial == null
        ? List<String>.filled(rules.length, '')
        : List<String>.of(initial.slots);
    var focus = initial == null ? 0 : slots.length;
    var provenance = initial?.interpretation ?? MaskInterpretation.automatic;
    int? lastTyped;
    var edited = false;
    var ambiguityAnnounced = false;
    var help = false;
    void show() => _showMaskDraft(
      out: out,
      label: label,
      template: template,
      rules: rules,
      slots: slots,
      focus: focus,
      width: _textInputWidth(profileBox.value),
    );

    show();
    session?._setPromptRepaint(show);
    final stopResize = _watchIdleResize(
      observer: source.resizeObserver,
      profile: () => profileBox.value,
      onGeometry: (geometry) => profileBox.value = geometry,
      repaint: show,
      keys: keys,
      helpOpen: () => help,
    );
    try {
      while (true) {
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          out.writeln('Help dismissed.');
          show();
          continue;
        }
        if (key == '\x14') {
          if (help) continue;
          help = true;
          out.writeln(
            focus >= slots.length
                ? _help(
                    linear: false,
                    stage: _MaskHelpStage.submit,
                    template: template,
                  )
                : _help(linear: false, template: template, slot: focus + 1),
          );
          continue;
        }
        if (help) continue;
        if (key == '\x1b[999~') {
          out.warning('Paste rejected: exceeds 4096 UTF-16 code units.');
          continue;
        }
        if (key.startsWith('\x1b[200~')) {
          var paste = key.substring(6, key.length - 6);
          if (paste.runes.any((c) => c < 32 || c == 127)) {
            out.warning('Paste rejected: single-line printable text only.');
            continue;
          }
          late List<MaskedValue> matches;
          while (true) {
            try {
              matches = _decode(paste);
              break;
            } on _MaskWorkLimit {
              out.warning(
                'Mask decoding work limit exceeded; edit preserved paste: $paste',
              );
              final correction = await _edit(
                keys,
                paste,
                out,
                helpText: _help(
                  linear: false,
                  template: template,
                  slot: focus < slots.length ? focus + 1 : null,
                ),
                outputProfile: profileBox.value,
                structure: structure,
                session: session,
                resizeObserver: source.resizeObserver,
              );
              session?._setPromptRepaint(show);
              if (correction.action == 'cancel') return Cancelled();
              if (correction.action == 'interrupt') return Interrupted();
              if (correction.action != 'submit') return InputEnded();
              paste = correction.value;
            }
          }
          if (matches.length > 1 ||
              (matches.length == 1 &&
                  matches.single.template != template.name)) {
            out.warning(
              'Paste requires template or interpretation resolution. Draft preserved: $paste',
            );
            for (var i = 0; i < matches.length; i++) {
              final positions = matches[i].slots.indexed
                  .map(
                    (e) => 'slot ${e.$1 + 1}: ${e.$2.isEmpty ? "empty" : e.$2}',
                  )
                  .join(', ');
              out.writeln(
                '${i + 1}. ${matches[i].template}: ${matches[i].interpretation.name}, raw ${matches[i].raw}, formatted ${matches[i].formatted}; $positions',
              );
            }
            out.writeln(
              'Choose a number, or press Enter to keep the current value:',
            );
            final choice = await _edit(
              keys,
              '',
              out,
              helpText: _help(
                linear: false,
                stage: _MaskHelpStage.template,
                template: template,
              ),
              outputProfile: profileBox.value,
              structure: structure,
              session: session,
              resizeObserver: source.resizeObserver,
            );
            if (choice.action == 'cancel') return Cancelled();
            if (choice.action == 'interrupt') return Interrupted();
            if (choice.action != 'submit') return InputEnded();
            final index = int.tryParse(choice.value);
            if (index != null && index >= 1 && index <= matches.length) {
              final selected = matches[index - 1];
              out.writeln('Selected template: ${selected.template}.');
              return await _richFixed(
                source,
                out,
                keys,
                profileBox,
                session,
                selectedTemplate: templates.singleWhere(
                  (t) => t.name == selected.template,
                ),
                initial: selected,
              );
            }
            show();
            session?._setPromptRepaint(show);
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
              out.warning('Paste rejected: exceeds template capacity.');
            } else {
              out.warning(
                'Paste requires template or interpretation resolution.',
              );
            }
            out.warning('Draft preserved: $paste');
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
            out.warning('Required slots are incomplete.');
          } else {
            if (edited && templates.length > 1) {
              late final List<MaskedValue> matches;
              try {
                matches = _decode(slots.join(), as: MaskInterpretation.raw);
              } on _MaskWorkLimit {
                out.warning(
                  'Mask decoding work limit exceeded; slots preserved for correction.',
                );
                show();
                continue;
              }
              if (matches.length > 1) {
                out.warning(
                  'Ambiguity reopened; draft preserved: ${slots.join()}',
                );
                for (var i = 0; i < matches.length; i++) {
                  out.writeln(
                    '${i + 1}. ${matches[i].template}: ${matches[i].formatted}; ${_slotDescriptions(matches[i])}',
                  );
                }
                out.writeln('Choose a template number:');
                final choice = await _edit(
                  keys,
                  '',
                  out,
                  helpText: _help(
                    linear: false,
                    stage: _MaskHelpStage.template,
                    template: template,
                  ),
                  outputProfile: profileBox.value,
                  structure: structure,
                  session: session,
                  resizeObserver: source.resizeObserver,
                );
                if (choice.action == 'cancel') return Cancelled();
                if (choice.action == 'interrupt') return Interrupted();
                if (choice.action != 'submit') return InputEnded();
                final index = int.tryParse(choice.value);
                if (index == null || index < 1 || index > matches.length) {
                  out.warning('Invalid template number.');
                  continue;
                }
                final selected = matches[index - 1];
                out.writeln('Selected template: ${selected.template}.');
                return await _richFixed(
                  source,
                  out,
                  keys,
                  profileBox,
                  session,
                  selectedTemplate: templates.singleWhere(
                    (t) => t.name == selected.template,
                  ),
                  initial: selected,
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
              out.warning('Slot does not accept that grapheme.');
            }
          } else if (focus < slots.length && rules[focus].accepts(key)) {
            edited = true;
            slots[focus] = key;
            lastTyped = focus++;
          } else {
            lastTyped = null;
            out.warning('Slot does not accept that grapheme.');
          }
        }
        if (edited && templates.length > 1) {
          try {
            final ambiguous =
                _decode(slots.join(), as: MaskInterpretation.raw).length > 1;
            if (ambiguous && !ambiguityAnnounced) {
              out.warning(
                'Ambiguity reopened; draft preserved: ${slots.join()}',
              );
            }
            ambiguityAnnounced = ambiguous;
          } on _MaskWorkLimit {
            out.warning(
              'Mask decoding work limit exceeded; slots preserved for correction.',
            );
          }
        }
        show();
      }
    } finally {
      stopResize();
      if (session != null) session._setPromptRepaint(null);
    }
  }

  Future<PromptResult<MaskedValue>> _linearFixed(
    ScriptedInput source,
    _WrappedNotices out,
    _Keys keys,
    _ProfileBox profileBox,
    TerminalSession? session,
  ) async {
    final template = templates.single;
    final rules = template.elements.whereType<MaskSlot>().toList();
    var slots = initialValue == null
        ? List<String>.filled(rules.length, '')
        : List<String>.of(initialValue!.slots);
    String? pendingDraft;
    String formatted() {
      var index = 0;
      return template.elements
          .map((e) => e is MaskLiteral ? e.text : slots[index++])
          .join();
    }

    void show() {
      out.opening(
        '$label.',
        'Template: ${template.name}. Raw: ${slots.join()}. Formatted: ${formatted()}.',
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
      sequential: !profileBox.value.supportsRichInteraction,
      extraCommands: commands,
      linearHelpText: _help(linear: true, template: template),
      outputProfile: profileBox.value,
      structure: structure,
      session: session,
    );
    const compactHint =
        r'/edit corrects a slot; /value edits the formatted value; /done submits. /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal.';
    // A heading structure keeps its compact hint under the stage content; every
    // other structure keeps the order it always had.
    if (!out.heads) out.hint(compactHint);
    show();
    if (out.heads) out.hint(compactHint);
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
        if (pendingDraft != null) {
          out.warning(
            'Resolve the preserved draft with /value before submitting.',
          );
          continue;
        }
        if (slots.indexed.any((e) => rules[e.$1].required && e.$2.isEmpty)) {
          out.warning('Required slots are incomplete.');
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
          out.warning('Invalid slot number.');
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
          out.warning('Invalid slot value.');
          continue;
        }
        slots[index - 1] = replacement.value;
        show();
        continue;
      }
      var value = command.value;
      if (command.action == 'command' && command.value == '/value') {
        out.writeln('Edit formatted value:');
        final entry = await edit(pendingDraft ?? formatted());
        if (entry.action == 'cancel') return Cancelled();
        if (entry.action == 'interrupt') return Interrupted();
        if (entry.action != 'submit') return InputEnded();
        value = entry.value;
      }
      pendingDraft = value;
      late final List<MaskedValue> matches;
      try {
        matches = _decode(value);
      } on _MaskWorkLimit {
        out.warning(
          'Mask decoding work limit exceeded; draft preserved: $value',
        );
        continue;
      }
      if (matches.length == 1) {
        pendingDraft = null;
        slots = List.of(matches.single.slots);
        show();
      } else if (matches.length > 1) {
        out.warning('Choose an interpretation; draft preserved: $value');
        for (var i = 0; i < matches.length; i++) {
          final description = matches[i].slots.indexed
              .map((e) => 'slot ${e.$1 + 1}: ${e.$2.isEmpty ? "empty" : e.$2}')
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
          out.warning('Invalid interpretation number; draft preserved: $value');
        } else {
          pendingDraft = null;
          slots = List.of(matches[index - 1].slots);
          show();
        }
      } else {
        out.warning('Invalid value; draft: $value');
      }
    }
  }
}
