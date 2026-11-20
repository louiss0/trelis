part of 'text_input.dart';

/// The interaction stage that requested component help from a tree prompt.
///
/// Help leads with the stage so navigating the visible nodes and entering a
/// stable reference do not share one undifferentiated paragraph.
enum _TreeHelpStage { navigating, reference }

/// The interaction stage that requested component help from an order prompt.
enum _OrderHelpStage { ordering, moving, reference, destination }

/// A node in a TreeSelect hierarchy. Branches are not selectable by default.
final class TreeNode<T> {
  TreeNode(
    this.value,
    this.label, {
    List<TreeNode<T>> children = const [],
    this.selectable,
    this.disabledReason,
    this.childrenUnavailableReason,
  }) : children = List.unmodifiable(children) {
    _checkChoiceText(label, disabledReason);
    if (childrenUnavailableReason != null) {
      _checkChoiceText(label, childrenUnavailableReason);
      if (children.isNotEmpty) {
        throw ArgumentError('Unavailable children cannot be supplied.');
      }
    }
  }
  final T value;
  final String label;
  final List<TreeNode<T>> children;
  final bool? selectable;
  final String? disabledReason;

  /// Explains why this branch's children are not currently available.
  final String? childrenUnavailableReason;
  bool get canSelect =>
      selectable ?? (children.isEmpty && childrenUnavailableReason == null);
}

/// Selects one node independently of expanding or traversing branches.
final class TreeSelect<T> {
  TreeSelect(
    this.label,
    List<TreeNode<T>> nodes, {
    this.isCurrent,
    this.defaultValue,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : nodes = List.unmodifiable(nodes),
       supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    final identities = <T>{};
    void validate(List<TreeNode<T>> nodes) {
      for (final node in nodes) {
        if (!identities.add(node.value)) {
          throw ArgumentError('Node identities must be unique.');
        }
        validate(node.children);
      }
    }

    validate(this.nodes);
    if (defaultValue != null && !identities.contains(defaultValue)) {
      throw ArgumentError('Default identity is not a node.');
    }
  }
  final String label;
  final List<TreeNode<T>> nodes;
  final T? defaultValue;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;

  /// Optional currentness check for nodes that can disappear during a prompt.
  final bool Function(T value)? isCurrent;
  bool _active = false;

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
      final selectedMode =
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
                selectedMode,
                outputProfile: outputProfile,
              );
            });
          }
          return await _terminal<T>(
            selectedMode,
            output ?? stdout,
            (source, mode, _) =>
                _run(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selectedMode, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<T>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    final all = <(TreeNode<T>, List<TreeNode<T>>)>[];
    void collect(List<TreeNode<T>> level, List<TreeNode<T>> path) {
      for (final node in level) {
        final current = [...path, node];
        all.add((node, current));
        collect(node.children, current);
      }
    }

    collect(nodes, []);
    bool currentPath(List<TreeNode<T>> path) =>
        isCurrent == null || path.every((node) => isCurrent!(node.value));
    if (source is SuppliedAnswer) {
      final n = int.tryParse(source.value);
      if (n == null ||
          n < 1 ||
          n > all.length ||
          !all[n - 1].$1.canSelect ||
          all[n - 1].$1.disabledReason != null ||
          !currentPath(all[n - 1].$2)) {
        return Unavailable('Supply an enabled selectable node reference.');
      }
      return Accepted(all[n - 1].$1.value);
    }
    final scripted = source as ScriptedInput;
    var effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
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
    final out = scripted.output;
    final expanded = <T>{};
    final enabledRoot = nodes.indexWhere((node) => node.disabledReason == null);
    var focus = nodes.isEmpty ? null : nodes[enabledRoot < 0 ? 0 : enabledRoot];
    if (defaultValue != null) {
      final row = all.firstWhere((r) => r.$1.value == defaultValue);
      focus = row.$1;
      expanded.addAll(row.$2.take(row.$2.length - 1).map((node) => node.value));
    }
    var current = <TreeNode<T>>[];
    List<(TreeNode<T>, List<TreeNode<T>>)> visible() => all
        .where(
          (row) => row.$2
              .take(row.$2.length - 1)
              .every((n) => expanded.contains(n.value)),
        )
        .toList();
    String path(List<TreeNode<T>> nodes) =>
        nodes.map((n) => n.label).join(' / ');

    /// Component help for the requesting interaction stage.
    ///
    /// The current path, the focused row and the displayed default stay beside
    /// the controls, and every node that cannot be accepted is named with its
    /// protected reason.
    String helpText({
      required bool linear,
      _TreeHelpStage stage = _TreeHelpStage.navigating,
      _ChoiceRow? focusRow,
    }) {
      final titles = switch (stage) {
        _TreeHelpStage.navigating =>
          linear ? 'Choosing a node' : 'Navigating the tree',
        _TreeHelpStage.reference => 'Entering a node reference',
      };
      final controls = switch (stage) {
        _TreeHelpStage.reference => 'A node reference is the number displayed for a node. References are assigned once in preorder and stay stable while branches open and close, so a reference is checked against the current path before anything happens. /open accepts only a direct child of the current path and enters its children; /choose accepts the referenced node only when it is selectable and currently available. Exact /help and /cancel are commands; quote a command with a backslash and double a leading backslash. Identified paste is literal.',
        _TreeHelpStage.navigating when linear => 'Enter an exact command: /open asks for a stable node reference in the current path and enters its children; /up returns to the parent; /choose asks for a stable node reference and accepts it only when it is selectable and available. Expandability and selectability are independent. Exact /help and /cancel are commands; quote a command with a backslash and double a leading backslash. Identified paste is literal.',
        _TreeHelpStage.navigating => 'Up/Down move the focus between visible nodes; Right expands a branch or enters its first child; Left collapses a branch or moves to the parent; Enter accepts the focused node only when it is selectable and available; Ctrl+T dismisses help; Escape cancels and Ctrl+C interrupts.',
      };
      final defaultText = defaultValue == null
          ? 'No node is marked as the default.'
          : () {
              final row = all.firstWhere((r) => r.$1.value == defaultValue);
              return 'Default: ${path(row.$2)} (reference ${all.indexOf(row) + 1}).';
            }();
      final blocked = <String>[];
      for (final row in all) {
        final node = row.$1;
        final label = '${all.indexOf(row) + 1}. ${path(row.$2)}';
        if (node.disabledReason != null) {
          blocked.add(
            '$label is unavailable (${node.disabledReason}) and cannot be accepted',
          );
        } else if (node.childrenUnavailableReason != null) {
          blocked.add(
            '$label has unavailable children (${node.childrenUnavailableReason}) and cannot be opened',
          );
        } else if (!node.canSelect) {
          blocked.add('$label is not selectable and cannot be accepted');
        }
        if (!currentPath(row.$2)) {
          blocked.add('$label is no longer available');
        }
      }
      final blockedText = blocked.isEmpty
          ? 'Every node is currently selectable and available.'
          : 'Not acceptable: ${blocked.join('; ')}.';
      return [
        'Help: $titles.',
        if (focusRow != null) 'Focus: ${focusRow.text}.',
        if (linear)
          'Current path: ${current.isEmpty ? 'root' : path(current)}.',
        controls,
        defaultText,
        blockedText,
      ].join(' ');
    }

    // Guidance and rows follow the current output geometry, so a resize repaint
    // wraps to the observed width instead of the invocation width.
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: _textInputWidth(effectiveProfile),
      background: colors.background,
      border: colors.border,
      rich: mode == PromptMode.rich,
    );
    void write(
      String text,
      TerminalColor foreground, {
      bool closes = false,
      StageEvent event = StageEvent.body,
    }) {
      spine.width = _textInputWidth(effectiveProfile);
      spine.write(
        out,
        DisplayText.from(text).value,
        foreground: foreground,
        closes: closes,
        event: event,
      );
    }

    int referenceOf((TreeNode<T>, List<TreeNode<T>>) row) =>
        all.indexOf(row) + 1;

    // The compact hint ends the stage. An enclosure writes it outside the
    // closed frame; a rail or branch keeps the order it always had and writes
    // it before the list.
    final hint = mode == PromptMode.linear
        ? r'/open, /up and /choose are exact commands. /open and /choose ask for a stable node reference. /help and /cancel are exact commands; quote commands with a backslash; double a leading backslash. Identified paste is literal.'
        : 'Up/Down navigate; Right expands or enters; Left collapses or goes to parent; Enter chooses. Ctrl+T help; Escape cancels; Ctrl+C interrupts.';

    /// One typed tree row: the stable reference, the full path, focus, the
    /// displayed default, the expansion state, selectability and staleness stay
    /// separate facts. Expansion never implies selectability, and every marker
    /// is an atomic unit under wrapping.
    _ChoiceRow rowFor((TreeNode<T>, List<TreeNode<T>>) row) {
      final node = row.$1;
      return _ChoiceRow(
        reference: referenceOf(row),
        label: path(row.$2),
        focused: mode == PromptMode.rich && identical(node, focus),
        isDefault: defaultValue != null && node.value == defaultValue,
        treeState: node.childrenUnavailableReason != null
            ? _TreeRowState.childrenUnavailable
            : node.children.isEmpty
            ? _TreeRowState.leaf
            : expanded.contains(node.value)
            ? _TreeRowState.expanded
            : _TreeRowState.collapsed,
        childrenUnavailableReason: node.childrenUnavailableReason,
        selectable: node.canSelect,
        disabledReason: node.disabledReason,
        current: currentPath(row.$2),
      );
    }

    void show() {
      spine.reset(out);
      session?._setPromptGeometry(effectiveProfile.geometry);
      spine.width = _textInputWidth(effectiveProfile);
      spine.heading(
        out,
        DisplayText.from('$label TreeSelect:').value,
        foreground: colors.foreground,
      );
      if (all.isEmpty) {
        write('No nodes available.', colors.warning, event: StageEvent.warning);
      }
      if (mode == PromptMode.linear) {
        write(
          'Path: ${current.isEmpty ? 'root' : path(current)}',
          colors.muted,
          event: StageEvent.state,
        );
        if (defaultValue != null) {
          final row = all.firstWhere((r) => r.$1.value == defaultValue);
          write(
            'Default: ${path(row.$2)} (reference ${referenceOf(row)})'
            '${row.$1.canSelect ? '' : ' [not selectable]'}'
            '${row.$1.disabledReason == null ? '' : ' [unavailable: ${row.$1.disabledReason}]'}'
            '${currentPath(row.$2) ? '' : ' [unavailable: no longer available]'}',
            colors.muted,
            event: StageEvent.state,
          );
        }
      }
      final rows = mode == PromptMode.linear
          ? all.where(
              (r) =>
                  (current.isNotEmpty && identical(r.$1, current.last)) ||
                  (r.$2.length == current.length + 1 &&
                      (current.isEmpty ||
                          identical(r.$2[current.length - 1], current.last))),
            )
          : visible();
      if (rows.isNotEmpty) spine.breathingRow(out);
      for (final row in rows) {
        _writeChoiceRow(
          out,
          rowFor(row),
          width: _textInputWidth(effectiveProfile),
          foreground: mode == PromptMode.rich && identical(row.$1, focus)
              ? colors.accent
              : colors.foreground,
          colors: colors,
          profile: effectiveProfile,
          spine: spine,
        );
      }
      if (spine.encloses || spine.heads) {
        // An enclosure keeps the compact hint outside the closed frame on every
        // repaint, and a heading structure keeps it under the body rows, so a
        // navigation never leaves the stage without its declared hint.
        spine.hint(out, hint, foreground: colors.muted);
      }
    }

    // A rail or branch opens its stage with the compact hint, exactly as it did
    // before enclosures existed; an enclosure or a heading structure writes it
    // after its own content.
    if (!spine.encloses && !spine.heads) write(hint, colors.muted);
    show();
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    session?._setPromptRepaint(show);
    void Function() stopResize = () {};
    try {
      if (mode == PromptMode.linear) {
        while (true) {
          final action = await _edit(
            inputKeys,
            '',
            out,
            linear: true,
            sequential: true,
            extraCommands: const {'/open', '/up', '/choose'},
            linearHelpText: helpText(linear: true),
            outputProfile: effectiveProfile,
            structure: structure,
            session: session,
          );
          // A nested editor clears the session repaint registration on exit, so
          // the tree restores its own repaint before continuing.
          session?._setPromptRepaint(show);
          if (action.action == 'cancel') return Cancelled();
          if (action.action == 'interrupt') return Interrupted();
          if (action.action != 'command' && action.action != 'submit') {
            return InputEnded();
          }
          if (action.action != 'command') {
            write(
              'Use /open, /up or /choose.',
              colors.warning,
              event: StageEvent.warning,
            );
            continue;
          }
          if (action.value == '/up') {
            if (current.isNotEmpty) {
              current = current.sublist(0, current.length - 1);
            } else {
              write(
                'Already at root.',
                colors.warning,
                event: StageEvent.warning,
              );
            }
            show();
            continue;
          }
          write('Enter node reference:', colors.foreground);
          final reference = await _edit(
            inputKeys,
            '',
            out,
            linear: true,
            sequential: true,
            extraCommands: const {'/open', '/up', '/choose'},
            linearHelpText: helpText(
              linear: true,
              stage: _TreeHelpStage.reference,
            ),
            outputProfile: effectiveProfile,
            structure: structure,
            session: session,
          );
          session?._setPromptRepaint(show);
          if (reference.action == 'cancel') return Cancelled();
          if (reference.action == 'interrupt') return Interrupted();
          if (reference.action == 'command') {
            write(
              'Enter a node reference.',
              colors.warning,
              event: StageEvent.warning,
            );
            continue;
          }
          if (reference.action != 'submit') return InputEnded();
          final n = int.tryParse(reference.value);
          if (n == null || n < 1 || n > all.length) {
            write(
              'Enter a valid node reference.',
              colors.warning,
              event: StageEvent.warning,
            );
            continue;
          }
          final row = all[n - 1];
          final node = row.$1;
          if (!currentPath(row.$2)) {
            write(
              'Node is no longer available.',
              colors.warning,
              event: StageEvent.warning,
            );
            continue;
          }
          if (action.value == '/open') {
            if (row.$2.length != current.length + 1 ||
                (current.isNotEmpty &&
                    !identical(row.$2[current.length - 1], current.last))) {
              write(
                'Open a node in the current path.',
                colors.warning,
                event: StageEvent.warning,
              );
              continue;
            }
            if (node.childrenUnavailableReason != null) {
              write(
                'Children unavailable: ${node.childrenUnavailableReason}.',
                colors.warning,
                event: StageEvent.warning,
              );
              continue;
            }
            if (node.children.isEmpty) {
              write(
                'Node has no children.',
                colors.warning,
                event: StageEvent.warning,
              );
              continue;
            }
            expanded.add(node.value);
            current = row.$2;
            show();
            continue;
          }
          if (!node.canSelect) {
            write(
              'Node is not selectable.',
              colors.warning,
              event: StageEvent.warning,
            );
            continue;
          }
          if (node.disabledReason != null) {
            write(
              'Unavailable: ${node.disabledReason}.',
              colors.warning,
              event: StageEvent.warning,
            );
            continue;
          }
          write(
            'Accepted: ${path(row.$2)}.',
            colors.success,
            event: StageEvent.result,
          );
          return Accepted(node.value);
        }
      }
      var help = false;
      stopResize = _watchIdleResize(
        observer: scripted.resizeObserver,
        profile: () => effectiveProfile,
        onGeometry: (geometry) => effectiveProfile = geometry,
        repaint: show,
        keys: inputKeys,
        helpOpen: () => help,
      );
      while (true) {
        final key = await inputKeys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          show();
          continue;
        }
        if (key == '\x14') {
          help = true;
          final items = visible();
          final focused = items.indexWhere((r) => identical(r.$1, focus));
          write(
            helpText(
              linear: false,
              focusRow: focused < 0 ? null : rowFor(items[focused]),
            ),
            colors.foreground,
          );
          continue;
        }
        if (help) continue;
        final rows = visible();
        final index = rows.indexWhere((r) => identical(r.$1, focus));
        if (key == '\x1b[A' && index > 0) focus = rows[index - 1].$1;
        if (key == '\x1b[B' && index >= 0 && index + 1 < rows.length) {
          focus = rows[index + 1].$1;
        }
        if (key == '\x1b[C' && index >= 0 && !currentPath(rows[index].$2)) {
          write(
            'Node is no longer available.',
            colors.warning,
            event: StageEvent.warning,
          );
          continue;
        }
        if (key == '\x1b[C' && focus?.childrenUnavailableReason != null) {
          write(
            'Children unavailable: ${focus!.childrenUnavailableReason}.',
            colors.warning,
            event: StageEvent.warning,
          );
        }
        if (key == '\x1b[C' && focus != null && focus.children.isNotEmpty) {
          if (!expanded.add(focus.value)) focus = focus.children.first;
        }
        if (key == '\x1b[D' && focus != null) {
          if (!expanded.remove(focus.value) &&
              index >= 0 &&
              rows[index].$2.length > 1) {
            focus = rows[index].$2[rows[index].$2.length - 2];
          }
        }
        if (key == '\r' || key == '\n') {
          if (focus == null) {
            write(
              'No node available.',
              colors.warning,
              event: StageEvent.warning,
            );
            continue;
          }
          if (index < 0 || !currentPath(rows[index].$2)) {
            write(
              'Node is no longer available.',
              colors.warning,
              event: StageEvent.warning,
            );
            continue;
          }
          if (!focus.canSelect) {
            write(
              'Node is not selectable.',
              colors.warning,
              event: StageEvent.warning,
            );
            continue;
          }
          if (focus.disabledReason != null) {
            write(
              'Unavailable: ${focus.disabledReason}.',
              colors.warning,
              event: StageEvent.warning,
            );
            continue;
          }
          write(
            'Accepted: ${path(all.firstWhere((r) => identical(r.$1, focus)).$2)}.',
            colors.success,
            event: StageEvent.result,
          );
          return Accepted(focus.value);
        }
        show();
      }
    } finally {
      stopResize();
      if (session != null) session._setPromptRepaint(null);
      if (keys == null) await inputKeys.close();
    }
  }
}

/// Reorders all choices; choices with a disabled reason are locked anchors.
final class SortableSelect<T> {
  SortableSelect(
    this.label,
    List<Choice<T>> choices, {
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : choices = List.unmodifiable(choices),
       supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (choices.map((c) => c.value).toSet().length != choices.length) {
      throw ArgumentError('Choice identities must be unique.');
    }
  }
  final String label;
  final List<Choice<T>> choices;

  /// The component palette for order rows, guidance and notices.
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  bool _active = false;

  Future<PromptResult<List<T>>> prompt({
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
      return session._promptRunner<List<T>>(
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
      final selectedMode =
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
                selectedMode,
                outputProfile: outputProfile,
              );
            });
          }
          return await _terminal<List<T>>(
            selectedMode,
            output ?? stdout,
            (source, mode, _) =>
                _run(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selectedMode, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<List<T>>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    final order = List.generate(choices.length, (i) => i);
    bool validOrder(List<int> candidate) {
      if (candidate.length != choices.length ||
          candidate.toSet().length != choices.length ||
          candidate.any((i) => i < 0 || i >= choices.length)) {
        return false;
      }
      for (var i = 0; i < choices.length; i++) {
        if (choices[i].disabledReason != null && candidate[i] != i) {
          return false;
        }
        for (var a = 0; a < choices.length; a++) {
          if (choices[a].disabledReason != null &&
              ((i < a) != (candidate.indexOf(i) < a))) {
            return false;
          }
        }
      }
      return true;
    }

    List<T> answer() => [for (final i in order) choices[i].value];
    if (source is SuppliedAnswer) {
      final parts = source.value.isEmpty ? <String>[] : source.value.split(',');
      final refs = parts.map(int.tryParse).toList();
      if (refs.any((n) => n == null) ||
          !validOrder([for (final n in refs) n! - 1])) {
        return Unavailable(
          'Supply a complete permutation of choice references respecting locked anchors.',
        );
      }
      order.setAll(0, [for (final n in refs) n! - 1]);
      return Accepted(answer());
    }
    final scripted = source as ScriptedInput;
    var effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
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
    final out = scripted.output;
    // Guidance and rows follow the current output geometry, so a resize repaint
    // wraps to the observed width instead of the invocation width.
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: _textInputWidth(effectiveProfile),
      background: colors.background,
      border: colors.border,
      rich: mode == PromptMode.rich,
    );
    void write(
      String text,
      TerminalColor foreground, {
      bool closes = false,
      StageEvent event = StageEvent.body,
    }) {
      spine.width = _textInputWidth(effectiveProfile);
      spine.write(
        out,
        DisplayText.from(text).value,
        foreground: foreground,
        closes: closes,
        event: event,
      );
    }

    var focus = 0;
    var moving = false;
    List<int>? moveStart;
    final hint = mode == PromptMode.rich
        ? 'Up/Down navigate or move; Space picks up or drops; Enter drops while moving or submits while idle; Escape reverts a move or cancels; Ctrl+T help; Ctrl+C interrupts.'
        : r'/move requests a stable choice reference and destination position; /done submits; /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal.';

    /// One typed order row: the stable reference, the current position, focus,
    /// the locked-anchor reason and a pick-up state stay separate facts, and
    /// every marker is an atomic unit under wrapping.
    void writeRow(int index) {
      final ref = order[index];
      final choice = choices[ref];
      final focused = mode == PromptMode.rich && index == focus;
      _writeChoiceRow(
        out,
        _ChoiceRow(
          reference: ref + 1,
          label: choice.label,
          position: index + 1,
          positionCount: order.length,
          focused: focused,
          lockedReason: choice.disabledReason,
          moving: moving && focused,
        ),
        width: _textInputWidth(effectiveProfile),
        foreground: focused ? colors.accent : colors.foreground,
        colors: colors,
        profile: effectiveProfile,
        spine: spine,
      );
    }

    void show() {
      spine.reset(out);
      session?._setPromptGeometry(effectiveProfile.geometry);
      spine.width = _textInputWidth(effectiveProfile);
      spine.heading(
        out,
        DisplayText.from('$label SortableSelect: ${order.length} choices.')
            .value,
        foreground: colors.foreground,
      );
      if (order.isNotEmpty) spine.breathingRow(out);
      for (var p = 0; p < order.length; p++) {
        writeRow(p);
      }
      if (spine.encloses || spine.heads) {
        // An enclosure keeps the compact hint outside the closed frame on every
        // repaint, and a heading structure keeps it under the body rows, so a
        // move never leaves the stage without its declared hint.
        spine.hint(out, hint, foreground: colors.muted);
      }
    }

    bool move(int from, int to) {
      if (choices[order[from]].disabledReason != null) {
        write(
          'Locked: ${choices[order[from]].disabledReason}.',
          colors.warning,
          event: StageEvent.warning,
        );
        return false;
      }
      final low = from < to ? from : to;
      final high = from > to ? from : to;
      if (order
          .sublist(low, high + 1)
          .any((i) => choices[i].disabledReason != null)) {
        write(
          'Cannot cross a locked anchor.',
          colors.warning,
          event: StageEvent.warning,
        );
        return false;
      }
      final item = order.removeAt(from);
      order.insert(to, item);
      write(
        '${choices[item].label} moved to position ${to + 1} of ${order.length}.',
        colors.success,
        event: StageEvent.result,
      );
      return true;
    }

    /// Component help for the requesting interaction stage.
    ///
    /// The stage title names what the prompt is asking for, the stable reference
    /// and destination rules stay beside it, and every locked anchor is named
    /// with its protected reason.
    String helpText({
      required bool linear,
      _OrderHelpStage stage = _OrderHelpStage.ordering,
    }) {
      final focusedLabel = order.isEmpty ? '' : choices[order[focus]].label;
      final titles = switch (stage) {
        _OrderHelpStage.ordering => 'Ordering the list',
        _OrderHelpStage.moving => 'Moving $focusedLabel',
        _OrderHelpStage.reference => 'Entering a reference',
        _OrderHelpStage.destination => 'Entering a destination position',
      };
      final controls = switch (stage) {
        _OrderHelpStage.moving => 'Up/Down move the picked-up identity one position at a time; Space or Enter drops it where it is; Escape reverts the whole move to where it started; Ctrl+T dismisses help and Ctrl+C interrupts.',
        _OrderHelpStage.reference => 'Enter the stable number of the identity to move. References never change when positions do, so a reference always names the same identity; a locked anchor cannot be moved. Exact /help and /cancel are commands; quote a command with a backslash and double a leading backslash. Identified paste is literal.',
        _OrderHelpStage.destination =>
          'Enter a destination position from 1 to ${order.length}. The identity moves to that position and the identities between them shift one place; a move may not cross a locked anchor, and a refused move keeps the current order. Exact /help and /cancel are commands.',
        _OrderHelpStage.ordering when linear => 'Enter an exact command: /move asks for a stable choice reference and then a destination position; /done submits the order shown. Every row keeps its own position and locked state. Exact /help and /cancel are commands; quote a command with a backslash and double a leading backslash. Identified paste is literal.',
        _OrderHelpStage.ordering => 'Up/Down move the focus; Space picks up or drops an identity; while moving, Up/Down move it and Enter drops it; while idle, Enter submits the shown order; Escape reverts a move before it cancels; Ctrl+T dismisses help and Ctrl+C interrupts.',
      };
      final locked = [
        for (var i = 0; i < choices.length; i++)
          if (choices[i].disabledReason != null)
            '${i + 1}. ${choices[i].label} is a locked anchor (${choices[i].disabledReason}) and keeps its position',
      ];
      final lockedText = locked.isEmpty
          ? 'No identity is locked.'
          : 'Locked anchors: ${locked.join('; ')}.';
      return [
        'Help: $titles.',
        controls,
        'Ordering ${order.length} identities.',
        lockedText,
      ].join(' ');
    }

    show();
    if (!spine.encloses && !spine.heads) {
      // A rail or branch reports its compact hint below the list, exactly as it
      // did before enclosures existed; an enclosure or a heading structure
      // writes it after its own content.
      write(hint, colors.muted);
    }
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    session?._setPromptRepaint(show);
    void Function() stopResize = () {};
    try {
      if (mode == PromptMode.linear) {
        var stage = 0;
        var entry = '';
        int? ref;
        while (true) {
          final r = await _edit(
            inputKeys,
            entry,
            out,
            linear: true,
            sequential: true,
            extraCommands: const {'/move', '/done'},
            linearHelpText: helpText(
              linear: true,
              stage: switch (stage) {
                1 => _OrderHelpStage.reference,
                2 => _OrderHelpStage.destination,
                _ => _OrderHelpStage.ordering,
              },
            ),
            outputProfile: effectiveProfile,
            structure: structure,
            session: session,
          );
          // A nested editor clears the session repaint registration on exit, so
          // the order prompt restores its own repaint before continuing.
          session?._setPromptRepaint(show);
          if (r.action == 'cancel') return Cancelled();
          if (r.action == 'interrupt') return Interrupted();
          if (r.action == 'command') {
            entry = '';
            if (r.value == '/done') {
              write(
                'Accepted order.',
                colors.success,
                event: StageEvent.result,
              );
              return Accepted(answer());
            }
            if (r.value == '/move') {
              stage = 1;
              write('Enter stable choice reference:', colors.foreground);
            }
            continue;
          }
          if (r.action != 'submit') return InputEnded();
          entry = r.value;
          final n = int.tryParse(entry);
          if (stage == 1) {
            if (n == null || n < 1 || n > choices.length) {
              write(
                'Enter a valid choice reference.',
                colors.warning,
                event: StageEvent.warning,
              );
              continue;
            }
            ref = n - 1;
            if (choices[ref].disabledReason != null) {
              write(
                'Locked: ${choices[ref].disabledReason}.',
                colors.warning,
                event: StageEvent.warning,
              );
              continue;
            }
            stage = 2;
            entry = '';
            write(
              'Enter destination position (1 to ${order.length}):',
              colors.foreground,
            );
          } else if (stage == 2) {
            if (n == null || n < 1 || n > order.length) {
              write(
                'Enter a valid destination position.',
                colors.warning,
                event: StageEvent.warning,
              );
              continue;
            }
            move(order.indexOf(ref!), n - 1);
            stage = 0;
            entry = '';
            show();
          } else {
            write(
              'Use /move or /done.',
              colors.warning,
              event: StageEvent.warning,
            );
          }
        }
      }
      var help = false;
      stopResize = _watchIdleResize(
        observer: scripted.resizeObserver,
        profile: () => effectiveProfile,
        onGeometry: (geometry) => effectiveProfile = geometry,
        repaint: show,
        keys: inputKeys,
        helpOpen: () => help,
      );
      while (true) {
        final key = await inputKeys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (help) {
            help = false;
            show();
            continue;
          }
          if (moving) {
            final item = order[focus];
            order.setAll(0, moveStart!);
            focus = order.indexOf(item);
            moving = false;
            write('Move reverted.', colors.muted);
            show();
            continue;
          }
          return Cancelled();
        }
        if (key == '\x14') {
          help = true;
          write(
            helpText(
              linear: false,
              stage: moving ? _OrderHelpStage.moving : _OrderHelpStage.ordering,
            ),
            colors.foreground,
          );
          continue;
        }
        if (help) continue;
        if (key == '\x1b[A' || key == '\x1b[B') {
          final next = focus + (key == '\x1b[A' ? -1 : 1);
          if (next >= 0 && next < order.length) {
            if (!moving || move(focus, next)) focus = next;
            show();
          }
        } else if (key == ' ' && order.isNotEmpty) {
          if (moving) {
            moving = false;
            write('Dropped.', colors.muted);
          } else if (choices[order[focus]].disabledReason != null) {
            write(
              'Locked: ${choices[order[focus]].disabledReason}.',
              colors.warning,
              event: StageEvent.warning,
            );
          } else {
            moving = true;
            moveStart = List.of(order);
            write('Picked up ${choices[order[focus]].label}.', colors.muted);
          }
          show();
        } else if (key == '\r' || key == '\n') {
          if (moving) {
            moving = false;
            write('Dropped.', colors.muted);
            show();
          } else {
            write('Accepted order.', colors.success, event: StageEvent.result);
            return Accepted(answer());
          }
        }
      }
    } finally {
      stopResize();
      if (session != null) session._setPromptRepaint(null);
      if (keys == null) await inputKeys.close();
    }
  }
}
