part of 'text_input.dart';

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
    Choice(value, label, disabledReason: disabledReason);
    if (childrenUnavailableReason != null) {
      Choice(value, label, disabledReason: childrenUnavailableReason);
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
  }) : nodes = List.unmodifiable(nodes) {
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
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => _run(
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
              ),
              lease.restore,
            );
          }
          return await _terminal<T>(
            selectedMode,
            output ?? stderr,
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
    var effectiveProfile = _constrainToObservedGeometry(
      OutputProfile.resolve(
        invocation: outputProfile,
        source: scripted.outputProfile,
        supportsRich: scripted.supportsRich,
      ),
      scripted._observedGeometry,
    );
    if (scripted._hardColorDisabled) {
      effectiveProfile = effectiveProfile.copyWith(colorDepth: ColorDepth.none);
    }
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
    const linearHelp =
        r'Help: TreeSelect. /open asks for a stable node reference in the current path and enters its children; /up returns to the parent. /choose asks for a stable node reference and accepts it only if selectable and available. Expandability and selectability are independent. /help and /cancel are exact commands; quote commands with a backslash; double a leading backslash. Identified paste is literal.';
    void show() {
      out.writeln('$label TreeSelect:');
      if (all.isEmpty) out.writeln('No nodes available.');
      if (mode == PromptMode.linear) {
        out.writeln('Path: ${current.isEmpty ? 'root' : path(current)}');
        if (defaultValue != null) {
          final row = all.firstWhere((r) => r.$1.value == defaultValue);
          out.writeln(
            'Default: ${path(row.$2)} (reference ${all.indexOf(row) + 1})${row.$1.canSelect ? '' : ' [not selectable]'}${row.$1.disabledReason == null ? '' : ' [unavailable: ${row.$1.disabledReason}]'}${currentPath(row.$2) ? '' : ' [unavailable: no longer available]'}',
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
      for (final row in rows) {
        final node = row.$1;
        out.writeln(
          '${all.indexOf(row) + 1}. ${path(row.$2)}${mode == PromptMode.rich && identical(node, focus) ? ' [focused]' : ''}${defaultValue != null && node.value == defaultValue ? ' [default]' : ''} ${node.childrenUnavailableReason != null
              ? '[children unavailable: ${node.childrenUnavailableReason}]'
              : node.children.isEmpty
              ? '[leaf]'
              : expanded.contains(node.value)
              ? '[expanded]'
              : '[collapsed]'} ${node.canSelect ? '[selectable]' : '[not selectable]'}${node.disabledReason == null ? '' : ' [unavailable: ${node.disabledReason}]'}${currentPath(row.$2) ? '' : ' [unavailable: no longer available]'}',
        );
      }
    }

    out.writeln(
      mode == PromptMode.linear
          ? r'/open, /up and /choose are exact commands. /open and /choose ask for a stable node reference. /help and /cancel are exact commands; quote commands with a backslash; double a leading backslash. Identified paste is literal.'
          : 'Up/Down navigate; Right expands or enters; Left collapses or goes to parent; Enter chooses. Ctrl+T help; Escape cancels; Ctrl+C interrupts.',
    );
    show();
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
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
            linearHelpText: linearHelp,
            outputProfile: effectiveProfile,
            session: session,
          );
          if (action.action == 'cancel') return Cancelled();
          if (action.action == 'interrupt') return Interrupted();
          if (action.action != 'command' && action.action != 'submit') {
            return InputEnded();
          }
          if (action.action != 'command') {
            out.writeln('Use /open, /up or /choose.');
            continue;
          }
          if (action.value == '/up') {
            if (current.isNotEmpty) {
              current = current.sublist(0, current.length - 1);
            } else {
              out.writeln('Already at root.');
            }
            show();
            continue;
          }
          out.writeln('Enter node reference:');
          final reference = await _edit(
            inputKeys,
            '',
            out,
            linear: true,
            sequential: true,
            extraCommands: const {'/open', '/up', '/choose'},
            linearHelpText: linearHelp,
            outputProfile: effectiveProfile,
            session: session,
          );
          if (reference.action == 'cancel') return Cancelled();
          if (reference.action == 'interrupt') return Interrupted();
          if (reference.action == 'command') {
            out.writeln('Enter a node reference.');
            continue;
          }
          if (reference.action != 'submit') return InputEnded();
          final n = int.tryParse(reference.value);
          if (n == null || n < 1 || n > all.length) {
            out.writeln('Enter a valid node reference.');
            continue;
          }
          final row = all[n - 1];
          final node = row.$1;
          if (!currentPath(row.$2)) {
            out.writeln('Node is no longer available.');
            continue;
          }
          if (action.value == '/open') {
            if (row.$2.length != current.length + 1 ||
                (current.isNotEmpty &&
                    !identical(row.$2[current.length - 1], current.last))) {
              out.writeln('Open a node in the current path.');
              continue;
            }
            if (node.childrenUnavailableReason != null) {
              out.writeln(
                'Children unavailable: ${node.childrenUnavailableReason}.',
              );
              continue;
            }
            if (node.children.isEmpty) {
              out.writeln('Node has no children.');
              continue;
            }
            expanded.add(node.value);
            current = row.$2;
            show();
            continue;
          }
          if (!node.canSelect) {
            out.writeln('Node is not selectable.');
            continue;
          }
          if (node.disabledReason != null) {
            out.writeln('Unavailable: ${node.disabledReason}.');
            continue;
          }
          out.writeln('Accepted: ${path(row.$2)}.');
          return Accepted(node.value);
        }
      }
      var help = false;
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
          out.writeln(
            'Help: Up/Down navigate; Right expands or enters; Left collapses or goes to parent; Enter chooses; Escape dismisses help.',
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
          out.writeln('Node is no longer available.');
          continue;
        }
        if (key == '\x1b[C' && focus?.childrenUnavailableReason != null) {
          out.writeln(
            'Children unavailable: ${focus!.childrenUnavailableReason}.',
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
            out.writeln('No node available.');
            continue;
          }
          if (index < 0 || !currentPath(rows[index].$2)) {
            out.writeln('Node is no longer available.');
            continue;
          }
          if (!focus.canSelect) {
            out.writeln('Node is not selectable.');
            continue;
          }
          if (focus.disabledReason != null) {
            out.writeln('Unavailable: ${focus.disabledReason}.');
            continue;
          }
          out.writeln(
            'Accepted: ${path(all.firstWhere((r) => identical(r.$1, focus)).$2)}.',
          );
          return Accepted(focus.value);
        }
        show();
      }
    } finally {
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
  }) : choices = List.unmodifiable(choices) {
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
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => _run(
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
              ),
              lease.restore,
            );
          }
          return await _terminal<List<T>>(
            selectedMode,
            output ?? stderr,
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
    var effectiveProfile = _constrainToObservedGeometry(
      OutputProfile.resolve(
        invocation: outputProfile,
        source: scripted.outputProfile,
        supportsRich: scripted.supportsRich,
      ),
      scripted._observedGeometry,
    );
    if (scripted._hardColorDisabled) {
      effectiveProfile = effectiveProfile.copyWith(colorDepth: ColorDepth.none);
    }
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
    var focus = 0;
    var moving = false;
    List<int>? moveStart;
    void show() {
      out.writeln('$label SortableSelect: ${order.length} choices.');
      for (var p = 0; p < order.length; p++) {
        final ref = order[p];
        final c = choices[ref];
        out.writeln(
          '${ref + 1}. ${c.label} [position ${p + 1} of ${order.length}]${mode == PromptMode.rich && p == focus ? ' [focused]' : ''}${c.disabledReason == null ? '' : ' [locked: ${c.disabledReason}]'}${moving && p == focus ? ' [moving]' : ''}',
        );
      }
    }

    bool move(int from, int to) {
      if (choices[order[from]].disabledReason != null) {
        out.writeln('Locked: ${choices[order[from]].disabledReason}.');
        return false;
      }
      final low = from < to ? from : to;
      final high = from > to ? from : to;
      if (order
          .sublist(low, high + 1)
          .any((i) => choices[i].disabledReason != null)) {
        out.writeln('Cannot cross a locked anchor.');
        return false;
      }
      final item = order.removeAt(from);
      order.insert(to, item);
      out.writeln(
        '${choices[item].label} moved to position ${to + 1} of ${order.length}.',
      );
      return true;
    }

    show();
    out.writeln(
      mode == PromptMode.rich
          ? 'Up/Down navigate or move; Space picks up or drops; Enter drops while moving or submits while idle; Escape reverts a move or cancels; Ctrl+T help; Ctrl+C interrupts.'
          : r'/move requests a stable choice reference and destination position; /done submits; /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal.',
    );
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
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
            outputProfile: effectiveProfile,
            session: session,
          );
          if (r.action == 'cancel') return Cancelled();
          if (r.action == 'interrupt') return Interrupted();
          if (r.action == 'command') {
            entry = '';
            if (r.value == '/done') {
              out.writeln('Accepted order.');
              return Accepted(answer());
            }
            if (r.value == '/move') {
              stage = 1;
              out.writeln('Enter stable choice reference:');
            }
            continue;
          }
          if (r.action != 'submit') return InputEnded();
          entry = r.value;
          final n = int.tryParse(entry);
          if (stage == 1) {
            if (n == null || n < 1 || n > choices.length) {
              out.writeln('Enter a valid choice reference.');
              continue;
            }
            ref = n - 1;
            if (choices[ref].disabledReason != null) {
              out.writeln('Locked: ${choices[ref].disabledReason}.');
              continue;
            }
            stage = 2;
            entry = '';
            out.writeln('Enter destination position (1 to ${order.length}):');
          } else if (stage == 2) {
            if (n == null || n < 1 || n > order.length) {
              out.writeln('Enter a valid destination position.');
              continue;
            }
            move(order.indexOf(ref!), n - 1);
            stage = 0;
            entry = '';
            show();
          } else {
            out.writeln('Use /move or /done.');
          }
        }
      }
      var help = false;
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
            out.writeln('Move reverted.');
            show();
            continue;
          }
          return Cancelled();
        }
        if (key == '\x14') {
          help = true;
          out.writeln(
            'Help: Up/Down navigate or move; Space picks up or drops; Enter drops or submits; Escape reverts or cancels.',
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
            out.writeln('Dropped.');
          } else if (choices[order[focus]].disabledReason != null) {
            out.writeln('Locked: ${choices[order[focus]].disabledReason}.');
          } else {
            moving = true;
            moveStart = List.of(order);
            out.writeln('Picked up ${choices[order[focus]].label}.');
          }
          show();
        } else if (key == '\r' || key == '\n') {
          if (moving) {
            moving = false;
            out.writeln('Dropped.');
            show();
          } else {
            out.writeln('Accepted order.');
            return Accepted(answer());
          }
        }
      }
    } finally {
      if (session != null) session._setPromptRepaint(null);
      if (keys == null) await inputKeys.close();
    }
  }
}
