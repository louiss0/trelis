part of 'text_input.dart';

/// Reorders all choices; choices with a disabled reason are locked anchors.
final class SortableSelect<T> {
  SortableSelect(this.label, List<Choice<T>> choices)
    : choices = List.unmodifiable(choices) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (choices.map((c) => c.value).toSet().length != choices.length) {
      throw ArgumentError('Choice identities must be unique.');
    }
  }
  final String label;
  final List<Choice<T>> choices;
  bool _active = false;

  Future<PromptResult<List<T>>> prompt({
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
      if (source == null) {
        if (_terminalActive)
          throw StateError('A terminal session is already active.');
        _terminalActive = true;
        try {
          return await _terminal<List<T>>(
            selected,
            output ?? stderr,
            (s, m, restore) => _run(s, m, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<List<T>>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    final order = List.generate(choices.length, (i) => i);
    bool validOrder(List<int> candidate) {
      if (candidate.length != choices.length ||
          candidate.toSet().length != choices.length ||
          candidate.any((i) => i < 0 || i >= choices.length))
        return false;
      for (var i = 0; i < choices.length; i++) {
        if (choices[i].disabledReason != null && candidate[i] != i)
          return false;
        for (var a = 0; a < choices.length; a++) {
          if (choices[a].disabledReason != null &&
              ((i < a) != (candidate.indexOf(i) < a)))
            return false;
        }
      }
      return true;
    }

    List<T> answer() => [for (final i in order) choices[i].value];
    if (source is SuppliedAnswer) {
      final parts = source.value.isEmpty ? <String>[] : source.value.split(',');
      final refs = parts.map(int.tryParse).toList();
      if (refs.any((n) => n == null) ||
          !validOrder([for (final n in refs) n! - 1]))
        return Unavailable(
          'Supply a complete permutation of choice references respecting locked anchors.',
        );
      order.setAll(0, [for (final n in refs) n! - 1]);
      return Accepted(answer());
    }
    final input = source as ScriptedInput;
    if (mode == PromptMode.rich && !input.supportsRich)
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    if (mode == PromptMode.automatic)
      mode = input.supportsRich ? PromptMode.rich : PromptMode.linear;
    final out = input.output;
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
    final keys = _Keys(input.input.transform(utf8.encoder));
    try {
      if (mode == PromptMode.linear) {
        var stage = 0;
        int? ref;
        while (true) {
          final r = await _edit(
            keys,
            '',
            out,
            linear: true,
            sequential: true,
            extraCommands: const {'/move', '/done'},
          );
          if (r.action == 'cancel') return Cancelled();
          if (r.action == 'interrupt') return Interrupted();
          if (r.action == 'command') {
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
          final n = int.tryParse(r.value);
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
            out.writeln('Enter destination position (1 to ${order.length}):');
          } else if (stage == 2) {
            if (n == null || n < 1 || n > order.length) {
              out.writeln('Enter a valid destination position.');
              continue;
            }
            move(order.indexOf(ref!), n - 1);
            stage = 0;
            show();
          } else {
            out.writeln('Use /move or /done.');
          }
        }
      }
      var help = false;
      while (true) {
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (help) {
            help = false;
            show();
            continue;
          }
          if (moving) {
            order.setAll(0, moveStart!);
            focus = order.indexOf(order[focus]);
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
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }
}
