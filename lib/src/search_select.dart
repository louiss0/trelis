part of 'text_input.dart';

/// Searchable single choice. References always identify source choices.
final class SearchSelect<T> {
  SearchSelect(this.label, List<Choice<T>> choices, {this.defaultValue})
    : choices = List.unmodifiable(choices) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (choices.map((c) => c.value).toSet().length != choices.length) {
      throw ArgumentError('Choice identities must be unique.');
    }
    if (defaultValue != null && !choices.any((c) => c.value == defaultValue)) {
      throw ArgumentError('Default identity is not a choice.');
    }
  }
  final String label;
  final List<Choice<T>> choices;
  final T? defaultValue;
  bool _active = false;

  Future<PromptResult<T>> prompt({
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
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          return await _terminal<T>(
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

  Future<PromptResult<T>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    if (source is SuppliedAnswer) {
      final n = int.tryParse(source.value);
      if (n == null ||
          n < 1 ||
          n > choices.length ||
          choices[n - 1].disabledReason != null) {
        return Unavailable('Supply an enabled choice reference.');
      }
      return Accepted(choices[n - 1].value);
    }
    final input = source as ScriptedInput;
    if (mode == PromptMode.rich && !input.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = input.supportsRich ? PromptMode.rich : PromptMode.linear;
    }
    final out = input.output;
    final keys = _Keys(input.input.transform(utf8.encoder));
    var query = '';
    var focus = defaultValue == null
        ? -1
        : choices.indexWhere((c) => c.value == defaultValue);
    var page = 0;
    const size = 10;
    List<int> visible() => [
      for (var i = 0; i < choices.length; i++)
        if (choices[i].label.toLowerCase().contains(query.toLowerCase())) i,
    ];
    void show() {
      final matches = visible();
      out.writeln(
        '$label SearchSelect: ${matches.length} results for "$query".',
      );
      if (matches.isEmpty) out.writeln('No matching choices; edit the query.');
      if (mode == PromptMode.linear && matches.isNotEmpty) {
        out.writeln(
          'Page ${page + 1} of ${(matches.length + size - 1) ~/ size}.',
        );
      }
      for (final i
          in mode == PromptMode.linear
              ? matches.skip(page * size).take(size)
              : matches) {
        final c = choices[i];
        out.writeln(
          '${i + 1}. ${c.label}${i == focus ? ' [focused]' : ''}${defaultValue != null && c.value == defaultValue ? ' [default]' : ''}${c.disabledReason == null ? '' : ' [unavailable: ${c.disabledReason}]'}',
        );
      }
    }

    void enterResults() {
      final items = visible();
      if (!items.contains(focus)) {
        focus = items.indexWhere((i) => choices[i].disabledReason == null);
        focus = focus < 0 ? (items.isEmpty ? -1 : items.first) : items[focus];
      }
      out.writeln('Results focused.');
      show();
    }

    PromptResult<T>? accept(int index) {
      if (!visible().contains(index)) {
        out.writeln('Choose a current result reference.');
        return null;
      }
      final c = choices[index];
      if (c.disabledReason != null) {
        out.writeln('Unavailable: ${c.disabledReason}.');
        return null;
      }
      out.writeln('Accepted: ${c.label}.');
      return Accepted(c.value);
    }

    out.writeln(
      mode == PromptMode.linear
          ? '$label. Enter a query, then a result reference. /search edits query; /next, /previous, /list, /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal; unframed paste cannot be distinguished from typing.'
          : '$label. Edit query; Enter or Up/Down enters results without accepting. Tab moves between query and results. Enter accepts a focused enabled result; typing edits query. Escape cancels; Ctrl+C interrupts.',
    );
    try {
      if (mode == PromptMode.linear) {
        var editing = true;
        while (true) {
          var literal = false;
          final r = await _edit(
            keys,
            editing ? query : '',
            out,
            linear: true,
            sequential: true,
            extraCommands: editing
                ? const {}
                : const {'/search', '/next', '/previous', '/list'},
            onSubmit: (v) => literal = v,
          );
          if (r.action == 'cancel') return Cancelled();
          if (r.action == 'interrupt') return Interrupted();
          if (r.action == 'eof') return InputEnded();
          if (editing) {
            query = r.value;
            page = 0;
            editing = false;
            enterResults();
            continue;
          }
          if (r.action == 'command') {
            switch (r.value) {
              case '/search':
                editing = true;
              case '/next':
                if ((page + 1) * size < visible().length) page++;
                show();
              case '/previous':
                if (page > 0) page--;
                show();
              case '/list':
                show();
            }
            continue;
          }
          final n = literal ? null : int.tryParse(r.value);
          final result = n == null || n < 1 || n > choices.length
              ? null
              : accept(n - 1);
          if (result != null) return result;
          if (n == null || n < 1 || n > choices.length) {
            out.writeln('Enter a current result reference.');
          }
        }
      }
      var editing = true;
      while (true) {
        if (editing) {
          final r = await _edit(
            keys,
            query,
            out,
            onChanged: (v) {
              query = v;
              show();
            },
            intercept: (key, text) {
              if (key == '\t' || key == '\x1b[A' || key == '\x1b[B') {
                return 'results';
              }
              return null;
            },
          );
          if (r.action == 'cancel') return Cancelled();
          if (r.action == 'interrupt') return Interrupted();
          if (r.action == 'eof') return InputEnded();
          query = r.value;
          editing = false;
          enterResults();
          continue;
        }
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') return Cancelled();
        if (key == '\t') {
          editing = true;
          out.writeln('Query focused.');
          continue;
        }
        final items = visible();
        if (key == '\x1b[A' || key == '\x1b[B') {
          final index = items.indexOf(focus);
          if (items.isNotEmpty) {
            focus =
                items[(index + (key == '\x1b[A' ? -1 : 1)).clamp(
                  0,
                  items.length - 1,
                )];
          }
          show();
        } else if (key == '\r' || key == '\n') {
          final result = accept(focus);
          if (result != null) return result;
        } else if (key.startsWith('\x1b[200~')) {
          final data = key.substring(6, key.length - 6);
          if (data.runes.any((r) => r < 32 || r == 127)) {
            out.writeln('Paste rejected: single-line printable text only.');
          } else {
            query += data;
            editing = true;
          }
        } else if (!key.startsWith('\x1b') && key.codeUnitAt(0) >= 32) {
          query += key;
          editing = true;
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
