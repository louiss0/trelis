part of 'text_input.dart';

/// An explicitly selected numeric entry convention.
final class NumericConvention {
  NumericConvention({
    required this.decimalSeparator,
    required this.groupingSeparator,
    required List<int> grouping,
    required this.nativeDigits,
  }) : grouping = List.unmodifiable(grouping) {
    final digits = nativeDigits.runes.toList();
    if (decimalSeparator.runes.length != 1 ||
        groupingSeparator.runes.length != 1 ||
        decimalSeparator == groupingSeparator ||
        digits.length != 10 ||
        digits.toSet().length != 10 ||
        grouping.isEmpty ||
        grouping.any((n) => n < 1 || n > 9) ||
        digits.any(
          (r) =>
              decimalSeparator.runes.contains(r) ||
              groupingSeparator.runes.contains(r),
        )) {
      throw ArgumentError('Unsupported numeric convention.');
    }
  }
  NumericConvention.ascii()
    : this(
        decimalSeparator: '.',
        groupingSeparator: ',',
        grouping: [3],
        nativeDigits: '0123456789',
      );
  final String decimalSeparator;
  final String groupingSeparator;
  final List<int> grouping;
  final String nativeDigits;

  String? canonical(String value, bool decimal) {
    final native = nativeDigits.runes.toList();
    final result = StringBuffer();
    var script = 0;
    for (final rune in value.runes) {
      final ascii = rune >= 48 && rune <= 57;
      final index = native.indexOf(rune);
      if (ascii || index >= 0) {
        final next = ascii ? 1 : 2;
        if (script != 0 && script != next) return null;
        script = next;
        result.write(ascii ? String.fromCharCode(rune) : index.toString());
      } else {
        result.writeCharCode(rune);
      }
    }
    var text = result.toString();
    var sign = '';
    if (text.startsWith('-')) {
      sign = '-';
      text = text.substring(1);
    }
    final parts = text.split(decimalSeparator);
    if (parts.length > (decimal ? 2 : 1)) return null;
    if (parts.length == 2 && !RegExp(r'^[0-9]+$').hasMatch(parts[1])) {
      return null;
    }
    final groups = parts[0].split(groupingSeparator);
    if (groups.any((g) => !RegExp(r'^[0-9]+$').hasMatch(g))) return null;
    if (groups.length > 1) {
      for (var i = groups.length - 1; i >= 0; i--) {
        final distance = groups.length - 1 - i;
        final size =
            grouping[distance < grouping.length
                ? distance
                : grouping.length - 1];
        if (i == 0 ? groups[i].length > size : groups[i].length != size) {
          return null;
        }
      }
    }
    return '$sign${groups.join()}${parts.length == 2 ? '.${parts[1]}' : ''}';
  }
}

/// Finite base-ten numeric entry.
final class NumberInput {
  NumberInput(
    this.label, {
    this.convention,
    this.conventionProvider,
    this.decimal = false,
    this.minimum,
    this.maximum,
    this.precision,
    this.required = true,
  }) {
    if (precision != null && precision! < 0) {
      throw ArgumentError.value(precision, 'precision');
    }
    for (final bound in [minimum, maximum]) {
      if (bound != null &&
          (_decimal(bound) == null || (!decimal && bound.contains('.')))) {
        throw ArgumentError.value(bound, 'bound');
      }
    }
    if (minimum != null &&
        maximum != null &&
        _compare(_decimal(minimum!)!, _decimal(maximum!)!) > 0) {
      throw ArgumentError('Minimum exceeds maximum.');
    }
  }
  final String label;
  final NumericConvention? convention;
  final NumericConvention? Function()? conventionProvider;
  final bool decimal;
  final String? minimum;
  final String? maximum;
  final int? precision;
  final bool required;
  bool _active = false;

  String? _validate(String value, NumericConvention convention) {
    if (value.isEmpty && !required) return null;
    final canonical = convention.canonical(value, decimal);
    if (canonical == null) {
      return 'Enter a complete base-ten number using the stated convention.';
    }
    final number = _decimal(canonical)!;
    if ((precision != null && number.$2 > precision!) ||
        (minimum != null && _compare(number, _decimal(minimum!)!) < 0) ||
        (maximum != null && _compare(number, _decimal(maximum!)!) > 0)) {
      return 'Value exceeds the declared bounds or precision.';
    }
    return null;
  }

  Future<PromptResult<String?>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final resolved = convention ?? conventionProvider?.call();
      if (resolved == null) {
        return Unavailable(
          'System numeric conventions could not be resolved; supply an explicit supported convention.',
        );
      }
      final result =
          await TextInput(
            label,
            required: required,
            validate: (value) => _validate(value, resolved),
          ).prompt(
            source: source,
            mode: mode,
            userPreference: userPreference,
            applicationPreference: applicationPreference,
            output: output,
          );
      if (result is Accepted<String>) {
        return Accepted(result.value.isEmpty ? null : result.value);
      }
      if (result is Cancelled<String>) return Cancelled();
      if (result is Interrupted<String>) return Interrupted();
      if (result is InputEnded<String>) return InputEnded();
      return Unavailable((result as Unavailable<String>).reason);
    } finally {
      _active = false;
    }
  }
}
