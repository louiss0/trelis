part of 'text_input.dart';

/// An explicitly selected numeric entry convention.
final class NumericConvention {
  NumericConvention.ascii();
}

/// Finite base-ten numeric entry.
final class NumberInput {
  NumberInput(this.label, {required this.convention, this.decimal = false});
  final String label;
  final NumericConvention convention;
  final bool decimal;

  Future<PromptResult<String?>> prompt({PromptSource? source}) async {
    final result = await TextInput(
      label,
      required: true,
      validate: (value) =>
          RegExp(decimal ? r'^-?[0-9]+(?:\.[0-9]+)?$' : r'^-?[0-9]+$')
              .hasMatch(value)
          ? null
          : 'Enter a complete base-ten number.',
    ).prompt(source: source);
    if (result is Accepted<String>) return Accepted(result.value);
    if (result is Cancelled<String>) return Cancelled();
    if (result is Interrupted<String>) return Interrupted();
    if (result is InputEnded<String>) return InputEnded();
    return Unavailable((result as Unavailable<String>).reason);
  }
}
