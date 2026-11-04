part of 'text_input.dart';

/// Supported noncurrency negative number layouts.
enum NumericNegativePattern {
  leading,
  trailing,
  leadingSpace,
  trailingSpace,
  parentheses,
}

/// An explicitly selected numeric entry convention.
final class NumericConvention {
  NumericConvention({
    required this.decimalSeparator,
    required this.groupingSeparator,
    required List<int> grouping,
    required this.nativeDigits,
    this.negativeSign = '-',
    this.negativePattern = NumericNegativePattern.leading,
  }) : grouping = List.unmodifiable(grouping) {
    final digits = nativeDigits.runes.toList();
    const supportedDigitZeros = [
      0x30,
      0x660,
      0x6f0,
      0x966,
      0x9e6,
      0xa66,
      0xae6,
      0xb66,
      0xbe6,
      0xc66,
      0xce6,
      0xd66,
      0xe50,
      0xed0,
      0xf20,
      0xff10,
    ];
    bool unsafeSeparator(String separator) => separator.runes.any(
      (r) => r < 32 || r == 127 || (r >= 48 && r <= 57) || r == 45 || r == 43,
    );
    if (negativeSign.runes.length != 1 ||
        negativeSign.runes.single < 33 ||
        negativeSign == decimalSeparator ||
        negativeSign == groupingSeparator ||
        RegExp(r'^[0-9()]$').hasMatch(negativeSign) ||
        digits.contains(negativeSign.runes.single) ||
        decimalSeparator.runes.length != 1 ||
        groupingSeparator.runes.length != 1 ||
        unsafeSeparator(decimalSeparator) ||
        unsafeSeparator(groupingSeparator) ||
        !supportedDigitZeros.any(
          (zero) =>
              digits.length == 10 &&
              List.generate(
                10,
                (i) => zero + i,
              ).asMap().entries.every((e) => digits[e.key] == e.value),
        ) ||
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
  final String negativeSign;
  final NumericNegativePattern negativePattern;

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
    final (prefix, suffix) = switch (negativePattern) {
      NumericNegativePattern.leading => (negativeSign, ''),
      NumericNegativePattern.trailing => ('', negativeSign),
      NumericNegativePattern.leadingSpace => ('$negativeSign ', ''),
      NumericNegativePattern.trailingSpace => ('', ' $negativeSign'),
      NumericNegativePattern.parentheses => ('(', ')'),
    };
    if ((prefix.isNotEmpty &&
            text.startsWith(prefix) &&
            text.endsWith(suffix)) ||
        (suffix.isNotEmpty &&
            text.endsWith(suffix) &&
            text.startsWith(prefix))) {
      sign = '-';
      text = text.substring(prefix.length, text.length - suffix.length);
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

/// An entered spelling and its exact base-ten coefficient and scale.
final class NumericAnswer {
  NumericAnswer._(this.spelling, this.coefficient, this.scale);
  final String spelling;
  final BigInt coefficient;
  final int scale;
}

NumericConvention? _systemNumericConvention() {
  if (!Platform.isWindows) return null;
  try {
    final get = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<
          Int32 Function(Pointer<Utf16>, Uint32, Pointer<Utf16>, Int32),
          int Function(Pointer<Utf16>, int, Pointer<Utf16>, int)
        >('GetLocaleInfoEx');
    String? field(int type) {
      final length = get(nullptr, type, nullptr, 0);
      if (length <= 1 || length > 128) return null;
      final buffer = calloc<Uint16>(length);
      try {
        if (get(nullptr, type, buffer.cast<Utf16>(), length) != length) {
          return null;
        }
        return buffer.cast<Utf16>().toDartString();
      } finally {
        calloc.free(buffer);
      }
    }

    List<String>? snapshot() {
      final values = [0xe, 0xf, 0x10, 0x13, 0x51, 0x1010].map(field).toList();
      return values.any((v) => v == null) ? null : values.cast<String>();
    }

    final a = snapshot();
    final b = snapshot();
    if (a == null || b == null || a.join('\u0000') != b.join('\u0000')) {
      return null;
    }
    final groups = a[2].split(';');
    if (groups.length < 2 || groups.last != '0') return null;
    final sizes = groups.take(groups.length - 1).map(int.tryParse).toList();
    if (sizes.any((n) => n == null)) return null;
    final pattern = int.tryParse(a[5]);
    if (pattern == null || pattern < 0 || pattern > 4) return null;
    return NumericConvention(
      decimalSeparator: a[0],
      groupingSeparator: a[1],
      grouping: sizes.cast<int>(),
      nativeDigits: a[3],
      negativeSign: a[4],
      negativePattern: [
        NumericNegativePattern.parentheses,
        NumericNegativePattern.leading,
        NumericNegativePattern.leadingSpace,
        NumericNegativePattern.trailing,
        NumericNegativePattern.trailingSpace,
      ][pattern],
    );
  } catch (_) {
    return null;
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

  Future<PromptResult<NumericAnswer?>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final resolved =
          convention ?? (conventionProvider ?? _systemNumericConvention)();
      if (resolved == null) {
        return Unavailable(
          'System numeric conventions could not be resolved; supply an explicit supported convention.',
        );
      }
      final negativeExample = switch (resolved.negativePattern) {
        NumericNegativePattern.leading => '${resolved.negativeSign}123',
        NumericNegativePattern.trailing => '123${resolved.negativeSign}',
        NumericNegativePattern.leadingSpace => '${resolved.negativeSign} 123',
        NumericNegativePattern.trailingSpace => '123 ${resolved.negativeSign}',
        NumericNegativePattern.parentheses => '(123)',
      };
      final description =
          '$label (${convention == null ? 'system or provided' : 'explicit override'} convention; decimal separator ${resolved.decimalSeparator}; grouping separator ${resolved.groupingSeparator}; grouping ${resolved.grouping.join(',')}; native digits ${resolved.nativeDigits}; negative example $negativeExample)';
      final result =
          await TextInput(
            description,
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
        if (result.value.isEmpty) return Accepted(null);
        final exact = _decimal(resolved.canonical(result.value, decimal)!)!;
        return Accepted(NumericAnswer._(result.value, exact.$1, exact.$2));
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
