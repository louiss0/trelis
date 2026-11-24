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

/// One logical gesture declaration — `Ctrl+Shift+B` — composed one
/// **symbol cell** at a time.
///
/// Rich interaction presents a row of framed cells — a modifier cell and a
/// key cell to start — navigated like `CronInput`'s field cells. A cell's
/// catalog depends on its position: every cell but the last cycles the
/// [modifiers] catalog and the last cell cycles the [symbols] catalog.
/// `Up`/`Down` cycles the focused cell with wraparound, `+` inserts a cell
/// after the focused cell, `-` removes the focused cell (never below two),
/// and `Enter` accepts the ordered token list. Linear interaction keeps
/// single-line `Ctrl+Shift+B`-style declaration entry.
///
/// `Keybind` resolves `PromptResult<List<String>>` — the ordered cell
/// tokens (`['Ctrl', 'Shift', 'B']`). [Keybind.joined] is the flagged
/// variant resolving `PromptResult<String>` — the tokens joined with `+`
/// (`'Ctrl+Shift+B'`).
final class Keybind<T> {
  /// The minimum number of cells in a gesture.
  static const minimumCells = 2;

  /// The default modifier catalog: `Ctrl`, `Alt`, `Shift`, `Meta`.
  static const defaultModifiers = ['Ctrl', 'Alt', 'Shift', 'Meta'];

  /// The default key-symbol catalog: letters, digits, `F1`–`F12` and the
  /// named keys of the declaration grammar.
  static const defaultSymbols = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'F1',
    'F2',
    'F3',
    'F4',
    'F5',
    'F6',
    'F7',
    'F8',
    'F9',
    'F10',
    'F11',
    'F12',
    'Enter',
    'Tab',
    'Escape',
    'Space',
    'Backspace',
    'Delete',
    'Insert',
    'Home',
    'End',
    'PageUp',
    'PageDown',
    'ArrowUp',
    'ArrowDown',
    'ArrowLeft',
    'ArrowRight',
  ];

  /// The token-list variant: [prompt] resolves `PromptResult<List<String>>`.
  factory Keybind(
    String label, {
    List<String> modifiers = defaultModifiers,
    List<String> symbols = defaultSymbols,
    List<String> initialValue = const [],
    ColorTheme colors = ColorThemes.terminalDefault,
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    CronCellFrame cellFrame = CronCellFrame.square,
    List<String> supplementaryHelp = const [],
  }) => Keybind<List<String>>._(
    label,
    modifiers: modifiers,
    symbols: symbols,
    initialValue: initialValue,
    colors: colors,
    structure: structure,
    instructions: instructions,
    cellFrame: cellFrame,
    supplementaryHelp: supplementaryHelp,
    joined: false,
  ) as Keybind<T>;

  /// The joined variant: [prompt] resolves `PromptResult<String>` — the
  /// tokens joined with `+` (`'Ctrl+Shift+B'`).
  factory Keybind.joined(
    String label, {
    List<String> modifiers = defaultModifiers,
    List<String> symbols = defaultSymbols,
    List<String> initialValue = const [],
    ColorTheme colors = ColorThemes.terminalDefault,
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    CronCellFrame cellFrame = CronCellFrame.square,
    List<String> supplementaryHelp = const [],
  }) => Keybind<String>._(
    label,
    modifiers: modifiers,
    symbols: symbols,
    initialValue: initialValue,
    colors: colors,
    structure: structure,
    instructions: instructions,
    cellFrame: cellFrame,
    supplementaryHelp: supplementaryHelp,
    joined: true,
  ) as Keybind<T>;

  Keybind._(
    this.label, {
    required List<String> modifiers,
    required List<String> symbols,
    required this.initialValue,
    required this.colors,
    required this.structure,
    required this.instructions,
    required this.cellFrame,
    required List<String> supplementaryHelp,
    required this._joined,
  }) : modifiers = List.unmodifiable(modifiers),
       symbols = List.unmodifiable(symbols),
       supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    _validateKeyLabel(label);
    const canonical = {'Ctrl', 'Alt', 'Shift', 'Meta'};
    if (modifiers.isEmpty) {
      throw ArgumentError.value(
        modifiers,
        'modifiers',
        'at least one modifier is required',
      );
    }
    final modifierCatalog = <String>{};
    for (final entry in modifiers) {
      if (!canonical.contains(entry)) {
        throw ArgumentError.value(
          entry,
          'modifiers',
          'must be Ctrl, Alt, Shift or Meta',
        );
      }
      if (!modifierCatalog.add(entry)) {
        throw ArgumentError.value(entry, 'modifiers', 'duplicate modifier');
      }
    }
    if (symbols.isEmpty) {
      throw ArgumentError.value(
        symbols,
        'symbols',
        'at least one key symbol is required',
      );
    }
    final symbolCatalog = <String>{};
    for (final entry in symbols) {
      final gesture = _parseDeclaredGesture(entry);
      if (gesture == null ||
          gesture.modifiers.isNotEmpty ||
          modifiers.contains(entry)) {
        throw ArgumentError.value(entry, 'symbols', 'invalid key symbol');
      }
      if (!symbolCatalog.add(entry)) {
        throw ArgumentError.value(entry, 'symbols', 'duplicate key symbol');
      }
    }
    if (initialValue.isNotEmpty) {
      final seed = initialValue.length == 1
          ? [initialValue.single, null]
          : initialValue;
      final error = _tokensError(seed);
      if (error != null) {
        throw ArgumentError.value(initialValue, 'initialValue', error);
      }
    }
    _initialCells = [
      for (final token in initialValue) token,
      for (var i = initialValue.length; i < minimumCells; i++) null,
    ];
    _input = TextInput(
      '$label (gesture declaration like Ctrl+Shift+B)',
      initialValue: initialValue.join('+'),
      required: true,
      validate: (value) =>
          _tokenError(value) == null ? null : 'Invalid gesture declaration.',
      colors: colors,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    );
  }
  final String label;

  /// The ordered modifier catalog for every cell but the last
  /// (`'Ctrl'`, `'Alt'`, `'Shift'`, `'Meta'`).
  final List<String> modifiers;

  /// The ordered key-symbol catalog for the last cell (`'B'`, `'F5'`,
  /// `'ArrowUp'`, ...).
  final List<String> symbols;

  /// Tokens presetting the leading cells; every token but the last must be
  /// a [modifiers] member (without repetition) and the last must be a
  /// [symbols] member. Fewer than [minimumCells] tokens leave the remaining
  /// initial cells unset.
  final List<String> initialValue;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;

  /// Delimiter style for the rich symbol-cell editor's cells.
  final CronCellFrame cellFrame;
  final List<String> supplementaryHelp;
  final bool _joined;
  late final TextInput _input;

  /// Initial cell selections — token strings or null for unset — that
  /// every prompt run resets to.
  late final List<String?> _initialCells;
  bool _active = false;

  /// Splits a linear or pasted draft into candidate tokens, accepting both
  /// the `Ctrl+Shift+B` declaration spelling and comma separation.
  List<String> _tokenize(String value) => value.split(RegExp(r'[+,]'));

  /// Whole-gesture token validation shared by the linear editor, the
  /// supplied-answer path, paste distribution, `initialValue` seeding and
  /// the cell stage's submit: at least [minimumCells] tokens, every token
  /// but the last a unique [modifiers] member, and the last a [symbols]
  /// member. A trailing null marks the unset key cell of a seeded draft.
  String? _tokensError(List<String?> tokens) {
    if (tokens.length < minimumCells) {
      return 'a keybind needs at least a modifier and a key.';
    }
    final seen = <String>{};
    for (var i = 0; i < tokens.length - 1; i++) {
      final token = tokens[i];
      if (!modifiers.contains(token)) {
        return "'$token' is not a modifier symbol.";
      }
      if (!seen.add(token!)) {
        return "'$token' is already a modifier in this gesture.";
      }
    }
    final last = tokens.last;
    if (last != null && !symbols.contains(last)) {
      return "'$last' is not a bindable key symbol.";
    }
    return null;
  }

  /// The same validation for a raw text draft.
  String? _tokenError(String value) => _tokensError(_tokenize(value));

  /// The accepted payload: the ordered tokens for [Keybind] or their
  /// `+`-joined declaration for [Keybind.joined].
  T _assemble(List<String> tokens) =>
      (_joined ? tokens.join('+') : tokens) as T;

  /// Appends caller supplementary help to a component-help body.
  String _withSupplementary(String help) => supplementaryHelp.isEmpty
      ? help
      : '$help\n${supplementaryHelp.join('\n')}';

  String get _declaredNote =>
      'Selected symbols compose a declaration; declarations are '
      'unverified and do not prove delivery or freedom from conflicts. '
      'Ctrl+C and Escape are reserved for interruption and cancellation.';

  /// Stage help leading with the focused cell and the catalog rules.
  String _cellHelp(int focus, int cellCount) {
    final role = focus == cellCount - 1 ? 'key' : 'modifier';
    final catalog = focus == cellCount - 1 ? symbols : modifiers;
    return _withSupplementary(
      'Help: cell ${focus + 1} of $cellCount is a $role cell edited with '
      'Up and Down, which cycle it through its catalog with wraparound; an '
      'unset cell starts at the first entry. Every cell but the last is a '
      'modifier cell (${modifiers.join(', ')}); the last cell is the key '
      'cell. Tab, Shift+Tab, Ctrl+B, Left and Right move focus across the '
      'cells; + inserts an unset cell after the focused cell and - removes '
      'the focused cell (a keybind keeps at least two cells). Enter submits '
      'the gesture once every cell is set and no modifier repeats; Ctrl+T '
      'opens this help; Escape cancels. This cell\'s catalog: '
      '${catalog.join(', ')}. $_declaredNote',
    );
  }

  /// Help for the linear declaration entry.
  String get _linearHelp => _withSupplementary(
    'Help: enter one gesture declaration such as Ctrl+Shift+B: modifier '
    'symbols first (${modifiers.join(', ')}), each at most once, then one '
    'key symbol such as B, F5 or ArrowUp. Exact /help and /cancel are '
    'commands; quote a command with a backslash and double a leading '
    'backslash. $_declaredNote',
  );

  Future<PromptResult<T>> prompt({
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
      return session._promptRunner<T>(
        _run,
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
      );
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
      if (source == null) {
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
          return await _terminal<T>(
            selected,
            output ?? stdout,
            (source, mode, restore) => _run(
              source,
              mode,
              outputProfile: outputProfile,
              beforeClose: restore,
            ),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  PromptResult<T> _asTokens(PromptResult<String> result) {
    if (result is Accepted<String>) {
      return Accepted(_assemble(_tokenize(result.value)));
    }
    if (result is Cancelled<String>) return Cancelled();
    if (result is Interrupted<String>) return Interrupted();
    if (result is InputEnded<String>) return InputEnded();
    return Unavailable((result as Unavailable<String>).reason);
  }

  Future<PromptResult<T>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
    void Function()? beforeClose,
  }) async {
    if (source is! ScriptedInput || source is SuppliedAnswer) {
      // Supplied answers bypass interaction, and every non-scripted source
      // stays on the shared text contract.
      return _asTokens(
        await _input._run(
          source,
          mode,
          outputProfile: outputProfile,
          keys: keys,
          session: session,
          helpText: _linearHelp,
          linearHelpText: _linearHelp,
          clearHelpCommand: true,
        ),
      );
    }
    final effectiveProfile = _effectiveOutputProfile(source, outputProfile);
    var resolved = mode;
    if (resolved == PromptMode.automatic) {
      resolved = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    if (resolved == PromptMode.rich &&
        !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (resolved == PromptMode.linear) {
      return _asTokens(
        await _input._run(
          source,
          mode,
          outputProfile: outputProfile,
          keys: keys,
          session: session,
          helpText: _linearHelp,
          linearHelpText: _linearHelp,
          clearHelpCommand: true,
        ),
      );
    }
    final out = source.output;
    final inputKeys = keys ?? _Keys(source.input.transform(utf8.encoder));
    try {
      return await _gestureCells(
        inputKeys,
        out,
        effectiveProfile,
        session,
        source.resizeObserver,
      );
    } finally {
      try {
        beforeClose?.call();
      } finally {
        if (keys == null) await inputKeys.close();
      }
    }
  }

  /// Rich-interaction symbol-cell entry stage.
  ///
  /// Runs the focus ring `cell 0 -> ... -> cell N-1 -> cell 0` until the
  /// gesture validates. [cells] holds token strings or null for unset
  /// cells and starts from [_initialCells] on every run.
  Future<PromptResult<T>> _gestureCells(
    _Keys inputKeys,
    StringSink out,
    OutputProfile effectiveProfile,
    TerminalSession? session,
    TerminalResizeObserver? resizeObserver,
  ) async {
    final cells = List<String?>.of(_initialCells);
    var focus = 0;
    // The stage repaints against live geometry: resize hints update
    // [stageProfile] and the spine's measured width without touching the
    // cell selections.
    var stageProfile = effectiveProfile;
    var stageHelpOpen = false;
    final spine = _structureSpine(
      stageProfile,
      structure: structure,
      width: _textInputWidth(stageProfile),
      background: colors.background,
      border: colors.border,
      rich: true,
      session: session,
    );
    void write(
      String text, {
      bool closes = false,
      StageEvent event = StageEvent.body,
      Iterable<String> atomicText = const [],
    }) => spine.write(
      out,
      text,
      foreground: colors.foreground,
      closes: closes,
      event: event,
      atomicText: atomicText,
    );

    // A resize observer may expose a single-subscription notification stream,
    // but the stage watcher needs the hints for itself. One subscription
    // forwards them onto a broadcast stream both sides share.
    TerminalResizeObserver? stageObserver;
    StreamController<void>? resizeEvents;
    StreamSubscription<void>? resizeForward;
    if (resizeObserver != null) {
      resizeEvents = StreamController<void>.broadcast();
      resizeForward = resizeObserver.notifications.listen(
        (_) => resizeEvents!.add(null),
        onError: (_, _) {},
        onDone: resizeEvents.close,
      );
      stageObserver = _ForwardedResizeObserver(
        resizeEvents.stream,
        resizeObserver,
      );
    }

    /// A cell's catalog by position: every cell but the last is a modifier
    /// cell; the last cell is the key cell.
    List<String> catalogFor(int index) =>
        index == cells.length - 1 ? symbols : modifiers;

    /// Clears every selection that is not a member of its cell's current
    /// catalog — a structural edit can shift a set cell into the other
    /// role, where its old token is illegal.
    void renormalize() {
      for (var i = 0; i < cells.length; i++) {
        final token = cells[i];
        if (token != null && !catalogFor(i).contains(token)) cells[i] = null;
      }
    }

    /// The active-format cue always describes the focused symbol cell.
    String cue() =>
        'cell ${focus + 1}/${cells.length} · '
        '${cells[focus] ?? 'unset'} · '
        '${focus == cells.length - 1 ? 'key' : 'modifier'}';

    /// The delimiters around one row item, matching the field-cell frame:
    /// unfocused items keep symmetric padding (`[ value ]`, `[   ]` unset);
    /// the focused item swaps the inner padding for explicit non-colour
    /// focus markers. [cellFrame] switches the brackets to round parens.
    ({String open, String close}) rowFrame({required bool focused}) {
      final square = cellFrame == CronCellFrame.square;
      if (!focused) {
        return (open: square ? '[ ' : '( ', close: square ? ' ]' : ' )');
      }
      final markers = spine.ascii ? ('>', '<') : ('→', '←');
      return (
        open: '${square ? '[' : '('}${markers.$1}',
        close: '${markers.$2}${square ? ']' : ')'}',
      );
    }

    /// The tail of [map] that fits [budget] cells, kept whole-grapheme, and
    /// the entry index the window starts at.
    ({String text, int start}) tailWindow(TextDisplayMap map, int budget) {
      var used = 0;
      final tail = <String>[];
      var start = map.entries.length;
      for (var i = map.entries.length - 1; i >= 0; i--) {
        final entry = map.entries[i];
        if (used + entry.cellWidth > budget) break;
        used += entry.cellWidth;
        tail.insert(0, entry.original);
        start = i;
      }
      return (text: tail.join(), start: start);
    }

    /// Windows [inner] to [innerBudget] cells, marking each hidden side with
    /// an ellipsis. Only a single cell wider than the row ever reaches this;
    /// the selection has no caret, so the window favours the tail.
    ({String text}) fitInner(String inner, int innerBudget) {
      final map = TextDisplayMap(inner);
      if (map.cellWidth <= innerBudget) return (text: inner);
      if (innerBudget <= 0) return (text: '');
      final ellipsis = spine.ascii ? '...' : '…';
      final ellipsisCells = TextDisplayMap(ellipsis).cellWidth;
      if (ellipsisCells >= innerBudget) {
        return (text: tailWindow(map, innerBudget).text);
      }
      return (
        text: '$ellipsis${tailWindow(map, innerBudget - ellipsisCells).text}',
      );
    }

    /// One row item: a gesture cell windowed to the spine's body width when
    /// it alone would overflow. Returns the token text and the display cells
    /// before the resting caret position inside it (the content's end).
    ({String text, int caretCells}) rowToken(
      String inner, {
      required bool focused,
    }) {
      final frame = rowFrame(focused: focused);
      final openCells = TextDisplayMap(frame.open).cellWidth;
      final budget = spine.bodyWriteWidth;
      String shown;
      int innerCaret;
      if (budget == null) {
        shown = inner;
        innerCaret = TextDisplayMap(inner).cellWidth;
      } else {
        final fixed = openCells + TextDisplayMap(frame.close).cellWidth;
        final map = TextDisplayMap(inner);
        if (fixed + map.cellWidth <= budget) {
          shown = inner;
          innerCaret = map.cellWidth;
        } else {
          shown = fitInner(inner, budget - fixed).text;
          innerCaret = TextDisplayMap(shown).cellWidth;
        }
      }
      return (
        text: '${frame.open}$shown${frame.close}',
        caretCells: openCells + innerCaret,
      );
    }

    /// Display cells the structure's row prefix occupies, so the physical
    /// caret lands inside the framed content column.
    int rowPrefixCells() => structurePrefixCells(structure, ascii: spine.ascii);

    /// Lays out every gesture token into wrapped row lines, reporting the
    /// focused token's packed line and emitted column. A token is never
    /// split unless it alone exceeds the inner line width, which [rowToken]
    /// windows at its tail.
    ({List<String> lines, List<String> tokens, int caretLine, int caretColumn})
    layoutCellRows() {
      final tokens = <({String text, int caretCells})>[
        for (var i = 0; i < cells.length; i++)
          rowToken(cells[i] ?? ' ', focused: i == focus),
      ];
      final tokenTexts = [for (final token in tokens) token.text];
      final budget = spine.bodyWriteWidth;
      if (budget == null) {
        var column = 0;
        var caretColumn = 0;
        for (var t = 0; t < tokens.length; t++) {
          if (t == focus) caretColumn = column + tokens[t].caretCells;
          column += TextDisplayMap(tokens[t].text).cellWidth + (t == 0 ? 0 : 1);
        }
        return (
          lines: [tokenTexts.join(' ')],
          tokens: tokenTexts,
          caretLine: 0,
          caretColumn: rowPrefixCells() + caretColumn,
        );
      }
      final lines = <String>[];
      final line = StringBuffer();
      var used = 0;
      var started = false;
      var lineIndex = 0;
      var caretLine = 0;
      var caretColumn = 0;
      for (var t = 0; t < tokens.length; t++) {
        final token = tokens[t];
        final tokenCells = TextDisplayMap(token.text).cellWidth;
        if (started && used + 1 + tokenCells > budget) {
          lines.add(line.toString());
          line.clear();
          used = 0;
          started = false;
          lineIndex++;
        }
        final startColumn = started ? used + 1 : 0;
        if (t == focus) {
          caretLine = lineIndex;
          caretColumn = startColumn + token.caretCells;
        }
        if (started) {
          line.write(' ');
          used += 1;
        }
        line.write(token.text);
        used += tokenCells;
        started = true;
      }
      if (started) lines.add(line.toString());
      return (
        lines: lines,
        tokens: tokenTexts,
        caretLine: caretLine,
        caretColumn: rowPrefixCells() + caretColumn,
      );
    }

    /// Renders the editable region — the wrapped cell row, the active-format
    /// cue and the compact hint — through the spine into display lines,
    /// exactly as [show] paints them, plus the focused caret's emitted line
    /// and column for in-place caret placement.
    ({List<String> lines, int caretLine, int caretColumn}) renderRegion() {
      final layout = layoutCellRows();
      final buffer = StringBuffer();
      final savedLines = spine._lines;
      final savedOpen = spine._open;
      final savedClosed = spine._closed;
      final savedPendingClose = spine._pendingClose;
      spine._open = true;
      spine._closed = false;
      spine._pendingClose = false;
      try {
        for (final row in layout.lines) {
          spine.write(
            buffer,
            row,
            foreground: colors.foreground,
            atomicText: layout.tokens,
          );
        }
        spine.write(buffer, cue(), foreground: colors.foreground);
        // The cue is protected content and stays visible when optional
        // instructions are hidden; the hint keeps only the primary action
        // and help route, matching the shared text contract's hidden floor.
        spine.hint(
          buffer,
          _resolvedInstructions(instructions) == InstructionDisplay.hidden
              ? 'Enter submits; Ctrl+T opens help.'
              : 'Tab/Shift-Tab move; Up/Down change; + adds, - removes; '
                    'Enter submits; Ctrl+T help; Esc cancels.',
          foreground: colors.foreground,
        );
      } finally {
        spine._lines = savedLines;
        spine._open = savedOpen;
        spine._closed = savedClosed;
        spine._pendingClose = savedPendingClose;
      }
      final rendered = buffer.toString().split('\n');
      if (rendered.isNotEmpty && rendered.last.isEmpty) rendered.removeLast();
      return (
        lines: rendered,
        caretLine: layout.caretLine,
        caretColumn: layout.caretColumn,
      );
    }

    /// Physical cursor row relative to the stage's first row. Region repaints
    /// move the cursor with absolute row deltas, so every write path below
    /// keeps this value in step with the bytes it emits.
    var cursorBelowTop = 0;

    /// Spine-counted row where the editable region begins, its last rendered
    /// height, and the caret's position inside it.
    var regionTop = 0;
    var regionRows = 0;
    var caretRegionRow = 0;
    var caretColumn = 0;

    /// Session transcript rows already accounted for by [sessionRepaint].
    var lastPendingRows = 0;

    /// Session transcript rows recorded below the spine's counted rows; the
    /// physical bottom of the stage sits this far below [spine._lines].
    int bottomRow() => spine._lines + (session?._promptTranscriptRowCount ?? 0);

    /// Moves the cursor to [row] (relative to the stage's first row) at
    /// column zero.
    void moveCursorTo(int row) {
      final delta = row - cursorBelowTop;
      if (delta > 0) {
        out.write('\x1b[${delta}B');
      } else if (delta < 0) {
        out.write('\x1b[${-delta}A');
      }
      out.write('\r');
      cursorBelowTop = row;
    }

    /// Parks the cursor at the stage's bottom row, column zero.
    void parkBelowRegion() => moveCursorTo(bottomRow());

    /// Places the physical caret at the end of the focused cell's framed
    /// content: the packed row line plus the structure prefix and the
    /// content column inside the token.
    void positionCaret() {
      moveCursorTo(regionTop + caretRegionRow);
      if (caretColumn > 0) out.write('\x1b[${caretColumn}C');
    }

    void showNow() {
      session?._setPromptGeometry(stageProfile.geometry);
      // The cursor must sit one row below every row the spine counted —
      // including transcript rows the session recorded below the frame —
      // before the rewind repaint. Nothing has been drawn yet on the first
      // paint, so there is no bottom to move to.
      if (cursorBelowTop > 0 || bottomRow() > 0) moveCursorTo(bottomRow());
      spine.reset(out);
      spine.opening(
        out,
        title: '$label.',
        body: '',
        foreground: colors.foreground,
        bodyForeground: colors.foreground,
      );
      regionTop = spine._lines;
      final region = renderRegion();
      out.write('${region.lines.join('\n')}\n');
      spine.countRows(region.lines.length);
      regionRows = region.lines.length;
      caretRegionRow = region.caretLine;
      caretColumn = region.caretColumn;
      cursorBelowTop = regionTop + region.lines.length;
      out.write('\r');
      positionCaret();
    }

    void show() {
      final sessionRef = session;
      if (sessionRef == null) {
        showNow();
      } else {
        sessionRef._writeShared(showNow);
      }
    }

    /// Repaints only the editable region in place: the wrapped cell rows,
    /// cue and hint are rewritten row by row and any rows a taller previous
    /// render left behind are cleared, without touching the frame above or
    /// the notices and help below.
    void repaintRegionNow() {
      final region = renderRegion();
      final count = region.lines.length;
      moveCursorTo(regionTop);
      final buffer = StringBuffer();
      for (var i = 0; i < count; i++) {
        buffer.write('\x1b[2K${region.lines[i]}');
        if (i < count - 1) buffer.write('\n\r');
      }
      for (var row = count; row < regionRows; row++) {
        buffer.write('\n\r\x1b[2K');
      }
      out.write(buffer.toString());
      cursorBelowTop =
          regionTop + (count > regionRows ? count : regionRows) - 1;
      out.write('\r');
      regionRows = count;
      caretRegionRow = region.caretLine;
      caretColumn = region.caretColumn;
      positionCaret();
    }

    void repaintRegion() {
      final sessionRef = session;
      if (sessionRef == null) {
        repaintRegionNow();
      } else {
        sessionRef._writeShared(repaintRegionNow);
      }
    }

    /// The session's repaint hook: feedback writes transcript rows below the
    /// region and then asks for a repaint. The cursor advanced by exactly the
    /// newly recorded rows, so the tracked position stays exact.
    void sessionRepaint() {
      final pending = session?._promptTranscriptRowCount ?? 0;
      cursorBelowTop += pending - lastPendingRows;
      if (cursorBelowTop < 0) cursorBelowTop = 0;
      lastPendingRows = pending;
      repaintRegionNow();
    }

    final stopWatchingResize = _watchIdleResize(
      observer: stageObserver,
      profile: () => stageProfile,
      onGeometry: (resized) {
        stageProfile = resized;
        spine.width = _textInputWidth(resized);
      },
      repaint: show,
      keys: inputKeys,
      helpOpen: () => stageHelpOpen,
    );

    /// Emits a structural notice below the stage. The caret may sit inside
    /// the editable region, so the cursor first parks at the stage's bottom
    /// row before the notice is written; the caller repaints the region
    /// afterwards so the notice never corrupts it.
    void notice(String text) {
      moveCursorTo(bottomRow());
      out.write('\x1b[2K');
      write(text, closes: true, event: StageEvent.warning);
      cursorBelowTop = bottomRow();
    }

    /// Whether the currently open help owns the alternate screen; the exit
    /// path uses it to leave help the way it was entered.
    var helpUsedAltScreen = false;

    /// Writes stage help through a fresh spine, matching the shared event
    /// writer: muted content wrapped as its own structural block. The
    /// alternate-screen path uses this because those rows live on the other
    /// screen and must not count toward the stage's rewind.
    void writeHelpEvent(String text) {
      final profile = stageProfile;
      _StructureSpine(
        structure: structure,
        ascii: _structureAscii(profile),
        width: _textInputWidth(profile),
        background: colors.background,
        border: colors.border,
        outputProfile: profile,
      ).write(out, text, foreground: colors.muted, closes: true);
    }

    /// Opens the stage help screen for the current focus. While it is open
    /// every key is swallowed except Escape (dismiss), Ctrl+C (interrupt)
    /// and EOF; the selections and focus cannot change underneath it.
    void openHelp() {
      stageHelpOpen = true;
      helpUsedAltScreen =
          stageProfile.alternateScreen == CapabilitySupport.supported;
      final text = _cellHelp(focus, cells.length);
      final sessionRef = session;
      if (sessionRef != null) {
        sessionRef._openModalHelp(useAlternateScreen: helpUsedAltScreen);
        if (helpUsedAltScreen) {
          writeHelpEvent(text);
        } else {
          // Transcript help appends below the stage through the stage spine
          // so its rows stay inside the rewind count; the cursor parks at
          // the bottom row first, exactly as the shared editor's finished
          // editable row did.
          moveCursorTo(bottomRow());
          out.write('\x1b[2K');
          spine.write(out, text, foreground: colors.muted, closes: true);
          cursorBelowTop = bottomRow();
        }
      } else if (helpUsedAltScreen) {
        out.write('\x1b[?1049h\x1b[H');
        writeHelpEvent(text);
      } else {
        moveCursorTo(bottomRow());
        out.write('\x1b[2K');
        spine.write(out, text, foreground: colors.muted, closes: true);
        cursorBelowTop = bottomRow();
      }
    }

    /// Dismisses stage help and repaints the editable region. The alternate
    /// screen restores the saved cursor by itself; the transcript path leaves
    /// a dismissal row below the help and repaints over the region.
    void dismissHelp() {
      stageHelpOpen = false;
      final sessionRef = session;
      if (sessionRef != null) {
        final alt = helpUsedAltScreen;
        sessionRef._dismissModalHelp(
          showTranscriptDismissal: !alt,
          repaintPrompt: () {
            if (!alt) {
              // 'Help dismissed.' and any deferred transcript rows sit below
              // the spine's counted rows.
              cursorBelowTop = bottomRow();
            }
            repaintRegionNow();
          },
        );
      } else if (helpUsedAltScreen) {
        out.write('\x1b[?1049l');
        // The saved cursor returns to the focused cell's resting caret; the
        // region on the main screen was never touched.
      } else {
        out.writeln('Help dismissed.');
        spine.countWrappedRow('Help dismissed.');
        cursorBelowTop = bottomRow();
        repaintRegion();
      }
    }

    /// Ordered whole-draft validation: the first unset cell fails with a
    /// message naming its position, then the first repeated modifier.
    /// Returns the offending cell index and a message, or null when the
    /// tokens form a valid gesture.
    ({int index, String message})? failure() {
      for (var i = 0; i < cells.length; i++) {
        if (cells[i] == null) {
          return (
            index: i,
            message: 'cell ${i + 1} is unset; choose a symbol with Up or Down.',
          );
        }
      }
      final seen = <String>{};
      for (var i = 0; i < cells.length - 1; i++) {
        final token = cells[i]!;
        if (!seen.add(token)) {
          return (
            index: i,
            message:
                "cell ${i + 1} repeats modifier '$token'; each modifier is "
                'used at most once.',
          );
        }
      }
      return null;
    }

    /// Distributes an identified paste across the symbol cells. A single
    /// catalog symbol sets the focused cell; a `+`- or comma-separated
    /// token sequence repopulates the whole gesture when the tokens form a
    /// valid declaration. Returns a notice on rejection; [applied] reports
    /// whether the paste changed the cells.
    ({String? notice, bool applied}) applyPaste(String payload) {
      if (payload.isEmpty ||
          payload.runes.any((r) => r < 32 || r == 127) ||
          payload.trim() != payload) {
        return (
          notice: 'Paste rejected: declaration symbols only.',
          applied: false,
        );
      }
      final tokens = _tokenize(payload);
      if (tokens.length == 1) {
        final catalog = catalogFor(focus);
        return catalog.contains(tokens.single)
            ? (() {
                cells[focus] = tokens.single;
                return (notice: null, applied: true);
              })()
            : (
                notice:
                    "'${tokens.single}' is not a ${focus == cells.length - 1 ? 'key' : 'modifier'} symbol.",
                applied: false,
              );
      }
      final error = _tokensError(tokens);
      if (error != null) {
        return (notice: 'Paste rejected: $error', applied: false);
      }
      cells
        ..clear()
        ..addAll(tokens);
      focus = cells.length - 1;
      return (notice: null, applied: true);
    }

    try {
      show();
      session?._setPromptRepaint(sessionRepaint);
      while (true) {
        final key = await inputKeys.next();
        if (key == null || key == '\x1a') {
          parkBelowRegion();
          return InputEnded();
        }
        if (key == '\x03') {
          parkBelowRegion();
          return Interrupted();
        }
        if (stageHelpOpen) {
          // Help owns the screen: only Escape dismisses it; Ctrl+C and EOF
          // were already handled above. Every other key is swallowed so the
          // selections and focus cannot change underneath it.
          if (key == '\x1b') dismissHelp();
          continue;
        }
        if (key == '\x14') {
          openHelp();
          continue;
        }
        if (key == '\x1b') {
          parkBelowRegion();
          return Cancelled();
        }
        if (key == '\x1b[999~') {
          notice('Paste rejected: exceeds 4096 UTF-16 code units.');
          repaintRegion();
          continue;
        }
        if (key == '\r' || key == '\n') {
          final error = failure();
          if (error != null) {
            notice(error.message);
            focus = error.index;
            repaintRegion();
            continue;
          }
          parkBelowRegion();
          return Accepted(_assemble([for (final cell in cells) cell!]));
        }
        if (key == '\t' || key == '\x1b[C') {
          focus = (focus + 1) % cells.length;
          repaintRegion();
          continue;
        }
        if (key == '\x1b[Z' || key == '\x02' || key == '\x1b[D') {
          focus = (focus + cells.length - 1) % cells.length;
          repaintRegion();
          continue;
        }
        if (key == '\x1b[A' || key == '\x1b[B') {
          final catalog = catalogFor(focus);
          final current = cells[focus];
          final index = current == null ? -1 : catalog.indexOf(current);
          cells[focus] = index < 0
              ? catalog[key == '\x1b[B' ? 0 : catalog.length - 1]
              : catalog[(index + (key == '\x1b[B' ? 1 : catalog.length - 1)) %
                    catalog.length];
          repaintRegion();
          continue;
        }
        if (key == '+' || key == '=') {
          cells.insert(focus + 1, null);
          focus++;
          renormalize();
          repaintRegion();
          continue;
        }
        if (key == '-' || key == '_') {
          if (cells.length <= minimumCells) {
            notice('A keybind keeps at least $minimumCells symbol cells.');
          } else {
            cells.removeAt(focus);
            if (focus >= cells.length) focus = cells.length - 1;
            renormalize();
          }
          repaintRegion();
          continue;
        }
        if (key.startsWith('\x1b[200~')) {
          final payload = key.length >= 12
              ? key.substring(6, key.length - 6)
              : '';
          final paste = applyPaste(payload);
          if (paste.notice != null) notice(paste.notice!);
          repaintRegion();
          continue;
        }
        // Every other key — printable or escape — is a no-op inside a
        // select-based gesture cell.
        repaintRegion();
      }
    } finally {
      session?._setPromptRepaint(null);
      if (stageHelpOpen) {
        if (session != null) {
          session._abortModalHelp();
        } else if (helpUsedAltScreen) {
          out.write('\x1b[?1049l');
        }
      }
      stopWatchingResize();
      await resizeForward?.cancel();
      await resizeEvents?.close();
    }
  }
}

/// Parses a `Ctrl+Shift+A`-style declaration into a declared-provenance
/// gesture, or returns null when the spelling is not a valid declaration.
KeyGesture? _parseDeclaredGesture(String declaration) {
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
    if (modifier == null || !modifiers.add(modifier)) return null;
  }
  final key = parts.last;
  if (!RegExp(
    r'^(?:[A-Za-z0-9]|F(?:[1-9]|1[0-2])|Enter|Tab|Escape|Space|Backspace|Delete|Insert|Home|End|PageUp|PageDown|ArrowUp|ArrowDown|ArrowLeft|ArrowRight)$',
  ).hasMatch(key)) {
    return null;
  }
  return KeyGesture._(key, modifiers, KeyGestureProvenance.declared);
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
  final gesture = _parseDeclaredGesture(declaration);
  if (gesture == null) {
    return Unavailable('Invalid logical gesture declaration.');
  }
  return Accepted(gesture);
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
      rich: selected == PromptMode.rich,
      session: promptSession,
    );
    void write(
      String text,
      TerminalColor foreground, {
      bool closes = false,
      StageEvent event = StageEvent.body,
    }) => spine.write(
      out,
      text,
      foreground: foreground,
      closes: closes,
      event: event,
    );
    final richFocusedAction = (
      title: '$label:',
      guidance: 'c capture; d declare; r remove last; x clear; Enter submit; Ctrl+T help; Escape cancel.',
    );
    final linearFocusedAction = (
      title: '$label:',
      guidance: '/capture, /declare, /remove, /clear, /done, /help, /cancel.',
    );
    void review() {
      spine.reset(out);
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
            gestures
              ..clear()
              ..add(observed);
          } else if (legacy != null) {
            gestures
              ..clear()
              ..add(legacy);
            write(
              'Modifiers are ambiguous in this input stream.',
              colors.warning,
              event: StageEvent.warning,
            );
          } else {
            write(
              'Gesture unavailable.',
              colors.error,
              event: StageEvent.warning,
            );
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
            write(
              'Use an action command.',
              colors.error,
              event: StageEvent.warning,
            );
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
              gestures
                ..clear()
                ..add(result.value);
            } else {
              write(
                (result as Unavailable<KeyGesture>).reason,
                colors.error,
                closes: true,
                event: StageEvent.warning,
              );
            }
            review();
          case '/done':
            if (gestures.isEmpty) {
              write(
                'Capture or declare a gesture first.',
                colors.error,
                closes: true,
                event: StageEvent.warning,
              );
            } else if (requireObservation &&
                gestures.any(
                  (g) => g.provenance != KeyGestureProvenance.observed,
                )) {
              write(
                'Observation required; ambiguous or declared input cannot be accepted.',
                colors.error,
                closes: true,
                event: StageEvent.warning,
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
    return switch (await _declaredGesture(
      source.value,
      requireObservation: requireObservation,
    )) {
      Accepted<KeyGesture>(:final value) => Accepted([value]),
      Unavailable<KeyGesture>(:final reason) => Unavailable(reason),
      _ => InputEnded<List<KeyGesture>>(),
    };
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
      return await SharedTerminalLease.run(terminal, () async {
        return run(
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
        );
      });
    }
    return await _terminal<List<KeyGesture>>(
      selected,
      output ?? stdout,
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

String _keyCaptureScope() => 'Keypress captures one logical gesture';

String _keyCaptureObservation(bool requireObservation) => requireObservation
    ? 'Observation is required: declared and ambiguous gestures cannot be accepted.'
    : 'Observation is not required: declared and ambiguous gestures are accepted with their provenance retained.';

String _keyCaptureProvenance() =>
    'Legacy byte-stream captures report ambiguous provenance, and an empty modifier set does not prove that no modifier was held; native console observations report virtual-key letters and modifier state.';

String _keyCaptureReserved() =>
    'Escape cancels and Ctrl+C interrupts, so neither reserved gesture can be captured live.';

String _keyCaptureHelp({
  required bool linear,
  required bool requireObservation,
}) {
  final scope = _keyCaptureScope();
  final observation = _keyCaptureObservation(requireObservation);
  final reserved = _keyCaptureReserved();
  final provenance = _keyCaptureProvenance();
  if (!linear) {
    const reviewEdits =
        'A new capture or declaration replaces the reviewed gesture; r and x remove it.';
    return 'Help: $scope. c arms exactly one raw capture; the captured gesture is reviewed and never submitted automatically. Escape backs out of capture and returns to the reviewed gestures. While capture is armed every key is a candidate, so Ctrl+T opens this help only before or after a capture. $reviewEdits d declares one logical gesture such as Ctrl+Shift+A from the modifiers Ctrl, Alt, Shift and Meta; declarations are unverified and do not prove delivery or freedom from conflicts. $reserved $provenance $observation Enter submits the reviewed state.';
  }
  const reviewEdits = '/remove clears the reviewed gesture.';
  return 'Help: $scope. /capture arms exactly one raw capture and always returns to review; typing Escape during capture leaves capture and keeps the reviewed gestures. /declare enters one logical gesture such as Ctrl+Shift+A and Escape cancels declaration entry; declarations are unverified and do not prove delivery or freedom from conflicts. $reviewEdits /done submits the reviewed state; /cancel cancels; Ctrl+C interrupts. Exact /capture, /declare, /remove, /clear, /done, /help and /cancel are commands; quote a command with a backslash and double a leading backslash. Identified paste is literal and is not captured as a gesture. $reserved $provenance $observation';
}

String _keyCaptureDeclarationHelp({required bool requireObservation}) =>
    'Help: A declaration joins the modifiers Ctrl, Alt, Shift and Meta, each at most once, with + to one key: an ASCII letter or digit, F1 to F12, Enter, Tab, Escape, Space, Backspace, Delete, Insert, Home, End, PageUp, PageDown, ArrowUp, ArrowDown, ArrowLeft or ArrowRight. Enter submits the declaration for review; Escape cancels declaration entry and keeps the reviewed gestures; Ctrl+C interrupts. Declarations are unverified and do not prove delivery or freedom from conflicts. ${_keyCaptureObservation(requireObservation)}';
