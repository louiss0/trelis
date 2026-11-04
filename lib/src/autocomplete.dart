part of 'text_input.dart';

/// Collects free-form text with suggestions.
final class Autocomplete {
  Autocomplete(this.label, {required this.suggestions})
    : _input = TextInput(label);

  final String label;
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
    if (mode != PromptMode.linear) {
      return Unavailable('Interactive rich autocomplete is not yet available.');
    }
    final out = source.output;
    out.writeln(
      '$label. Enter a query; select a number, /submit, /edit, /help or /cancel.',
    );
    final keys = _Keys(source.input.transform(utf8.encoder));
    var pending = '';
    var editing = true;
    var candidates = <String>[];
    try {
      while (true) {
        final result = await _edit(
          keys,
          editing ? pending : '',
          out,
          linear: true,
          sequential: true,
        );
        if (result.action == 'cancel') return Cancelled();
        if (result.action == 'interrupt') return Interrupted();
        if (result.action != 'submit') return InputEnded();
        if (editing) {
          pending = result.value;
          out.writeln('Loading suggestions.');
          try {
            candidates = await suggestions(pending);
          } catch (_) {
            candidates = [];
            out.writeln('Suggestions unavailable.');
          }
          out.writeln('${candidates.length} suggestions.');
          for (var i = 0; i < candidates.length; i++) {
            out.writeln('${i + 1}. ${candidates[i]}');
          }
          out.writeln(
            'Pending answer: $pending. Choose a number or /submit, /edit, /help, /cancel.',
          );
          editing = false;
        } else if (result.value == '/submit') {
          return Accepted(pending);
        } else if (result.value == '/edit') {
          editing = true;
        } else {
          final index = int.tryParse(result.value);
          if (index != null && index > 0 && index <= candidates.length) {
            pending = candidates[index - 1];
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
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }
}
