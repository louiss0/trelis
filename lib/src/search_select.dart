part of 'text_input.dart';

/// Searchable single choice. References always identify source choices.
final class SearchSelect<T> {
  SearchSelect(
    this.label,
    List<Choice<T>> choices, {
    this.defaultValue,
    this.search,
  }) : choices = List.unmodifiable(choices) {
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

  /// Optional search policy. Results must use identities from [choices]; their
  /// labels and availability may change. Results retain source order and stable
  /// source references. Pending and obsolete responses cannot be accepted.
  final FutureOr<List<Choice<T>>> Function(String query)? search;
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
    var current = <int, Choice<T>>{};
    var loading = false;
    var closed = false;
    var generation = 0;
    String? requestedQuery;
    var invalidFocus = false;
    var hadResultsFocus = false;
    List<int> visible() => search == null
        ? [
            for (var i = 0; i < choices.length; i++)
              if (choices[i].label.toLowerCase().contains(query.toLowerCase()))
                i,
          ]
        : [
            for (var i = 0; i < choices.length; i++)
              if (current.containsKey(i)) i,
          ];
    Choice<T> item(int i) => search == null ? choices[i] : current[i]!;
    void show() {
      final matches = visible();
      out.writeln(
        '$label SearchSelect: ${matches.length} results for "$query".',
      );
      if (loading) {
        out.writeln('Searching; results cannot be accepted yet.');
      } else if (matches.isEmpty) {
        out.writeln('No matching choices; edit the query.');
      }
      if (mode == PromptMode.linear && matches.isNotEmpty) {
        out.writeln(
          'Page ${page + 1} of ${(matches.length + size - 1) ~/ size}.',
        );
      }
      for (final i
          in mode == PromptMode.linear
              ? matches.skip(page * size).take(size)
              : matches) {
        final c = item(i);
        out.writeln(
          '${i + 1}. ${c.label}${i == focus ? ' [focused]' : ''}${defaultValue != null && c.value == defaultValue ? ' [default]' : ''}${c.disabledReason == null ? '' : ' [unavailable: ${c.disabledReason}]'}',
        );
      }
    }

    void request(String text) {
      if (search == null || requestedQuery == text) return;
      requestedQuery = text;
      final requestId = ++generation;
      current = {};
      loading = true;
      void apply(List<Choice<T>> results) {
        if (closed || requestId != generation) return;
        final next = <int, Choice<T>>{};
        for (final candidate in results) {
          final index = choices.indexWhere((c) => c.value == candidate.value);
          if (index < 0 || next.containsKey(index)) {
            loading = false;
            out.writeln('Search returned unknown or duplicate identities.');
            return;
          }
          next[index] = candidate;
        }
        current = next;
        loading = false;
        page = 0;
        if (hadResultsFocus &&
            focus >= 0 &&
            (!current.containsKey(focus) ||
                current[focus]!.disabledReason != null)) {
          invalidFocus = true;
          out.writeln(
            'Previously focused choice is removed or unavailable; navigate to choose another.',
          );
        } else if (current.containsKey(focus)) {
          invalidFocus = false;
        }
        show();
      }

      void fail(Object error) {
        if (closed || requestId != generation) return;
        loading = false;
        out.writeln('Search unavailable; edit the query to retry.');
      }

      try {
        final response = search!(text);
        if (response is List<Choice<T>>) {
          apply(response);
        } else {
          Future<List<Choice<T>>>.value(response).then(apply, onError: fail);
          out.writeln('Searching.');
        }
      } catch (error) {
        fail(error);
      }
    }

    void enterResults() {
      final items = visible();
      if (!loading &&
          !invalidFocus &&
          items.isNotEmpty &&
          !items.contains(focus)) {
        focus = items.indexWhere((i) => item(i).disabledReason == null);
        focus = focus < 0 ? (items.isEmpty ? -1 : items.first) : items[focus];
      }
      hadResultsFocus = true;
      out.writeln('Results focused.');
      show();
    }

    PromptResult<T>? accept(int index, {bool explicitReference = false}) {
      if (loading ||
          (!explicitReference && invalidFocus) ||
          !visible().contains(index)) {
        out.writeln('Choose a current result reference.');
        return null;
      }
      final c = item(index);
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
          : '$label. Edit query; Enter or Up/Down enters results without accepting. Tab moves through query, results and Cancel action. Enter accepts a focused enabled result; typing edits query. Escape cancels; Ctrl+C interrupts.',
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
            onChanged: editing
                ? (v) {
                    query = v;
                    request(v);
                  }
                : null,
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
              : accept(n - 1, explicitReference: true);
          if (result != null) return result;
          if (n == null || n < 1 || n > choices.length) {
            out.writeln('Enter a current result reference.');
          }
        }
      }
      var editing = true;
      var actionFocus = false;
      while (true) {
        if (editing) {
          final r = await _edit(
            keys,
            query,
            out,
            onChanged: (v) {
              query = v;
              request(v);
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
          if (actionFocus) {
            actionFocus = false;
            editing = true;
            out.writeln('Query focused.');
          } else {
            actionFocus = true;
            out.writeln('Cancel action focused; Enter cancels.');
          }
          continue;
        }
        if (actionFocus && (key == '\r' || key == '\n')) return Cancelled();
        if (actionFocus && (key == '\x1b[A' || key == '\x1b[B')) continue;
        final items = visible();
        if (key == '\x1b[A' || key == '\x1b[B') {
          final index = items.indexOf(focus);
          if (items.isNotEmpty) {
            invalidFocus = false;
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
            actionFocus = false;
            editing = true;
          }
        } else if (!key.startsWith('\x1b') && key.codeUnitAt(0) >= 32) {
          query += key;
          actionFocus = false;
          editing = true;
        }
      }
    } finally {
      closed = true;
      generation++;
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }
}
