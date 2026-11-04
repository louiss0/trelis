import 'dart:async';
import 'dart:io';

import 'text_input.dart';

/// Collects free-form text with suggestions.
final class Autocomplete {
  Autocomplete(this.label, {required this.suggestions})
    : _input = TextInput(label);

  final String label;
  final FutureOr<List<String>> Function(String) suggestions;
  final TextInput _input;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) {
    if (source is SuppliedAnswer) {
      return _input.prompt(source: source);
    }
    return Future.value(
      Unavailable('Interactive autocomplete is not yet available.'),
    );
  }
}
