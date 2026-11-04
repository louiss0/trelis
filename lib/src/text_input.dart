/// The result of a prompt session.
sealed class PromptResult<T> {}

/// An answer accepted by the prompt.
final class Accepted<T> extends PromptResult<T> {
  Accepted(this.value);
  final T value;
}

/// A caller-supplied answer, treated as literal data.
final class SuppliedAnswer {
  SuppliedAnswer(this.value);
  final String value;
}

/// A prompt for a single line of text.
final class TextInput {
  TextInput(this.label);
  final String label;

  Future<PromptResult<String>> prompt({required SuppliedAnswer source}) async =>
      Accepted(source.value);
}
