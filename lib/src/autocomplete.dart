part of 'text_input.dart';

/// Collects free-form text with suggestions.
final class Autocomplete {
  Autocomplete(
    this.label, {
    required this.suggestions,
    this.initialValue = '',
    this.required = false,
    this.validate,
    this.maxLength,
  }) : _input = TextInput(
         label,
         initialValue: initialValue,
         required: required,
         validate: validate,
         maxLength: maxLength,
       );

  final String label;
  final String initialValue;
  final bool required;
  final int? maxLength;
  final String? Function(String)? validate;
  final FutureOr<List<String>> Function(String) suggestions;
  final TextInput _input;
  bool _active = false;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      if (source is SuppliedAnswer) return await _input.prompt(source: source);
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
          return await _terminal<String>(
            selected,
            output ?? stderr,
            (source, mode, restore) => _run(source, mode, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source as ScriptedInput, selected);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<String>> _run(
    ScriptedInput source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    if (mode == PromptMode.rich && !source.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = source.supportsRich ? PromptMode.rich : PromptMode.linear;
    }
    if (mode == PromptMode.rich) {
      return _rich(source, beforeClose: beforeClose);
    }
    final out = source.output;
    out.writeln(
      '$label. Enter a query; select a number, /submit, /edit, /help or /cancel.',
    );
    final keys = _Keys(source.input.transform(utf8.encoder));
    var pending = initialValue;
    var editing = true;
    var candidates = <String>[];
    var generation = 0;
    var closed = false;
    try {
      while (true) {
        final result = await _edit(
          keys,
          editing ? pending : '',
          out,
          linear: true,
          sequential: true,
          maxLength: editing ? maxLength : null,
        );
        if (result.action == 'cancel') return Cancelled();
        if (result.action == 'interrupt') return Interrupted();
        if (result.action != 'submit') return InputEnded();
        if (editing) {
          pending = result.value;
          candidates = [];
          final request = ++generation;
          void apply(List<String> items) {
            if (closed || request != generation) return;
            candidates = items
                .where((item) => !item.runes.any((r) => r < 32 || r == 127))
                .toList();
            out.writeln('${candidates.length} suggestions.');
            for (var i = 0; i < candidates.length; i++) {
              out.writeln('${i + 1}. ${candidates[i]}');
            }
          }

          try {
            final response = suggestions(pending);
            if (response is List<String>) {
              apply(response);
            } else {
              out.writeln('Loading suggestions.');
              Future<List<String>>.value(response).then(
                apply,
                onError: (Object error) {
                  if (!closed && request == generation) {
                    out.writeln('Suggestions unavailable.');
                  }
                },
              );
            }
          } catch (_) {
            out.writeln('Suggestions unavailable.');
          }
          out.writeln(
            'Pending answer: $pending. Choose a number or /submit, /edit, /help, /cancel.',
          );
          editing = false;
        } else if (result.value == '/submit') {
          final error = _error(pending);
          if (error != null) {
            out.writeln(error);
            continue;
          }
          return Accepted(pending);
        } else if (result.value == '/edit') {
          generation++;
          candidates = [];
          editing = true;
        } else {
          final index = int.tryParse(result.value);
          if (index != null && index > 0 && index <= candidates.length) {
            final candidate = candidates[index - 1];
            if (maxLength != null && candidate.characters.length > maxLength!) {
              out.writeln('Candidate exceeds maximum length.');
              continue;
            }
            pending = candidate;
            out.writeln(
              'Accepted into pending answer: $pending. Use /submit to finish or /edit to change.',
            );
          } else {
            out.writeln(
              'Choose a listed number or /submit, /edit, /help, /cancel.',
            );
          }
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

  Future<PromptResult<String>> _rich(
    ScriptedInput source, {
    void Function()? beforeClose,
  }) async {
    final out = source.output;
    out.writeln(
      '$label. Type text; Up/Down inspect suggestions; Tab or Enter accepts a candidate; Enter submits; Escape dismisses suggestions, then cancels.',
    );
    final keys = _Keys(source.input.transform(utf8.encoder));
    var value = initialValue;
    var query = '\u0000';
    var candidates = <String>[];
    var focus = -1;
    var generation = 0;
    var open = true;
    var loading = false;
    var closed = false;
    void changed(String text) {
      if (text == query) return;
      query = text;
      focus = -1;
      open = true;
      candidates = [];
      loading = true;
      final request = ++generation;
      void apply(List<String> items) {
        if (closed || request != generation) return;
        loading = false;
        candidates = items
            .where((item) => !item.runes.any((r) => r < 32 || r == 127))
            .toList();
        out.writeln('${candidates.length} suggestions; none active.');
      }

      try {
        final result = suggestions(text);
        if (result is List<String>) {
          apply(result);
        } else {
          out.writeln('Loading suggestions.');
          Future<List<String>>.value(result).then(
            apply,
            onError: (Object error) {
              if (!closed && request == generation) {
                loading = false;
                out.writeln('Suggestions unavailable.');
              }
            },
          );
        }
      } catch (_) {
        loading = false;
        out.writeln('Suggestions unavailable.');
      }
    }

    try {
      while (true) {
        final result = await _edit(
          keys,
          value,
          out,
          onChanged: changed,
          maxLength: maxLength,
          intercept: (key, text) {
            if (key == '\x1b' && open && (loading || candidates.isNotEmpty)) {
              open = false;
              loading = false;
              focus = -1;
              generation++;
              out.writeln('Suggestions dismissed.');
              return 'handled';
            }
            if ((key == '\x1b[B' || key == '\x1b[A') &&
                open &&
                candidates.isNotEmpty) {
              if (key == '\x1b[B') {
                focus = (focus + 1).clamp(0, candidates.length - 1);
              } else {
                focus = focus < 0
                    ? candidates.length - 1
                    : (focus - 1).clamp(0, candidates.length - 1);
              }
              out.writeln(
                'Active candidate, not accepted: ${candidates[focus]}.',
              );
              return 'handled';
            }
            if (open &&
                candidates.isNotEmpty &&
                (key == '\t' || ((key == '\r' || key == '\n') && focus >= 0))) {
              return 'accept';
            }
            return null;
          },
        );
        if (result.action == 'cancel') return Cancelled();
        if (result.action == 'interrupt') return Interrupted();
        if (result.action == 'eof') return InputEnded();
        if (result.action == 'submit') {
          final error = _error(result.value);
          if (error == null) return Accepted(result.value);
          out.writeln(error);
          value = result.value;
          continue;
        }
        value = result.value;
        if (result.action == 'accept') {
          final candidate = candidates[focus < 0 ? 0 : focus];
          if (maxLength != null && candidate.characters.length > maxLength!) {
            out.writeln('Candidate exceeds maximum length.');
            continue;
          }
          value = candidate;
          query = value;
          focus = -1;
          open = false;
          generation++;
          out.writeln('Accepted into editable text: $value. Enter submits.');
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

  String? _error(String value) {
    if (required && value.isEmpty) {
      return 'Required: enter a non-empty value and submit again.';
    }
    return validate?.call(value);
  }
}
