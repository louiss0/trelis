part of 'text_input.dart';

/// Local ASCII decimal port entry. Zero requires an explicit bind-request opt-in.
final class PortInput {
  PortInput(String label, {this.allowZero = false, String initialValue = ''}) {
    _input = TextInput(
      '$label (ASCII decimal ${allowZero ? '0-65535; zero requests automatic allocation' : '1-65535'}; availability is not checked)',
      initialValue: initialValue,
      required: true,
      validate: (value) => _parse(value) == null
          ? 'Enter an ASCII decimal port from ${allowZero ? 0 : 1} to 65535.'
          : null,
    );
    if (initialValue.isNotEmpty && _parse(initialValue) == null) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }
  final bool allowZero;
  late final TextInput _input;
  int? _parse(String value) {
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return null;
    final number = int.tryParse(value);
    return number != null && number >= (allowZero ? 0 : 1) && number <= 65535
        ? number
        : null;
  }

  Future<PromptResult<int>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    final result = await _input.prompt(
      source: source,
      mode: mode,
      userPreference: userPreference,
      applicationPreference: applicationPreference,
      output: output,
    );
    if (result is Accepted<String>) return Accepted(_parse(result.value)!);
    if (result is Cancelled<String>) return Cancelled();
    if (result is Interrupted<String>) return Interrupted();
    if (result is InputEnded<String>) return InputEnded();
    return Unavailable((result as Unavailable<String>).reason);
  }
}
