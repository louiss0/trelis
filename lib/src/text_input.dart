sealed class PromptResult<T> {}
final class Accepted<T> extends PromptResult<T> {
  Accepted(this.value);
  final T value;
}
final class InputEnded<T> extends PromptResult<T> {}
sealed class PromptSource {}
final class SuppliedAnswer extends PromptSource {
  SuppliedAnswer(this.value);
  final String value;
}
final class ScriptedInput extends PromptSource {
  ScriptedInput(this.input, this.output);
  final Stream<String> input;
  final StringBuffer output;
}
enum PromptMode { rich, linear, automatic }
final class TextInput {
  TextInput(this.label);
  final String label;
  Future<PromptResult<String>> prompt({required PromptSource source, PromptMode mode = PromptMode.automatic}) async {
    if (source is SuppliedAnswer) return Accepted(source.value);
    final scripted = source as ScriptedInput;
    scripted.output.writeln(label);
    var text = '';
    await for (final chunk in scripted.input) {
      for (final char in chunk.split('')) {
        if (char == '\r' || char == '\n') return Accepted(text);
        text += char;
      }
    }
    return InputEnded();
  }
}
