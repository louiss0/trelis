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
        (grouping.isEmpty
            ? groupingSeparator.isNotEmpty
            : groupingSeparator.runes.length != 1) ||
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
    final groups = grouping.isEmpty
        ? [parts[0]]
        : parts[0].split(groupingSeparator);
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

final class _LConv extends Struct {
  external Pointer<Utf8> decimalPoint;
  external Pointer<Utf8> thousandsSeparator;
  external Pointer<Utf8> grouping;
  external Pointer<Utf8> internationalCurrencySymbol;
  external Pointer<Utf8> currencySymbol;
  external Pointer<Utf8> monetaryDecimalPoint;
  external Pointer<Utf8> monetaryThousandsSeparator;
  external Pointer<Utf8> monetaryGrouping;
  external Pointer<Utf8> positiveSign;
  external Pointer<Utf8> negativeSign;
  @Uint8()
  external int internationalFractionDigits;
  @Uint8()
  external int fractionDigits;
  @Uint8()
  external int positiveCurrencyPrecedes;
  @Uint8()
  external int positiveCurrencySeparated;
  @Uint8()
  external int negativeCurrencyPrecedes;
  @Uint8()
  external int negativeCurrencySeparated;
  @Uint8()
  external int positiveSignPosition;
  @Uint8()
  external int negativeSignPosition;
  @Uint8()
  external int internationalPositiveCurrencyPrecedes;
  @Uint8()
  external int internationalPositiveCurrencySeparated;
  @Uint8()
  external int internationalNegativeCurrencyPrecedes;
  @Uint8()
  external int internationalNegativeCurrencySeparated;
  @Uint8()
  external int internationalPositiveSignPosition;
  @Uint8()
  external int internationalNegativeSignPosition;
}

NumericConvention? _linuxNumericConvention() {
  final env = Platform.environment;
  final localeName =
      [
        env['LC_ALL'],
        env['LC_NUMERIC'],
        env['LANG'],
      ].whereType<String>().where((value) => value.isNotEmpty).firstOrNull ??
      'C';
  if (localeName == 'C' ||
      localeName == 'POSIX' ||
      localeName.toUpperCase() == 'C.UTF-8' ||
      localeName.toUpperCase() == 'C.UTF8') {
    return NumericConvention(
      decimalSeparator: '.',
      groupingSeparator: '',
      grouping: [],
      nativeDigits: '0123456789',
    );
  }
  Pointer locale = nullptr;
  Pointer previous = nullptr;
  try {
    final libc = DynamicLibrary.open('libc.so.6');
    final newlocale = libc
        .lookupFunction<
          Pointer Function(Int32, Pointer<Utf8>, Pointer),
          Pointer Function(int, Pointer<Utf8>, Pointer)
        >('newlocale');
    final uselocale = libc
        .lookupFunction<Pointer Function(Pointer), Pointer Function(Pointer)>(
          'uselocale',
        );
    final localeconv = libc
        .lookupFunction<Pointer<_LConv> Function(), Pointer<_LConv> Function()>(
          'localeconv',
        );
    final snprintf = libc
        .lookupFunction<
          Int32 Function(Pointer<Utf8>, IntPtr, Pointer<Utf8>, Int32),
          int Function(Pointer<Utf8>, int, Pointer<Utf8>, int)
        >('snprintf');
    final name = localeName.toNativeUtf8();
    try {
      locale = newlocale(2, name, nullptr);
    } finally {
      calloc.free(name);
    }
    if (locale == nullptr) return null;
    previous = uselocale(locale);
    if (previous == nullptr) return null;
    final values = localeconv().ref;
    final decimal = values.decimalPoint.toDartString();
    final thousands = values.thousandsSeparator.toDartString();
    final groupingBytes = values.grouping.cast<Uint8>();
    final grouping = <int>[];
    for (var i = 0; ; i++) {
      final size = groupingBytes[i];
      if (size == 0 || size == 127) break;
      grouping.add(size);
    }
    final negativeSign = values.negativeSign.toDartString();
    final separated = values.negativeCurrencySeparated != 0;
    final negativePattern = switch (values.negativeSignPosition) {
      0 => NumericNegativePattern.parentheses,
      1 || 3 =>
        separated
            ? NumericNegativePattern.leadingSpace
            : NumericNegativePattern.leading,
      2 || 4 =>
        separated
            ? NumericNegativePattern.trailingSpace
            : NumericNegativePattern.trailing,
      _ => null,
    };
    if (negativePattern == null) return null;
    final digits = <int>[];
    final format = '%Id'.toNativeUtf8();
    final buffer = calloc<Uint8>(64);
    try {
      for (var i = 0; i < 10; i++) {
        final length = snprintf(buffer.cast<Utf8>(), 64, format, i);
        if (length < 1 || length >= 64) return null;
        final digit = buffer.cast<Utf8>().toDartString(length: length);
        if (digit.runes.length != 1) return null;
        digits.add(digit.runes.single);
      }
    } finally {
      calloc.free(format);
      calloc.free(buffer);
    }
    return NumericConvention(
      decimalSeparator: decimal,
      groupingSeparator: grouping.isEmpty ? '' : thousands,
      grouping: grouping,
      nativeDigits: String.fromCharCodes(digits),
      negativeSign: negativeSign,
      negativePattern: negativePattern,
    );
  } catch (_) {
    return null;
  } finally {
    if (previous != nullptr) {
      try {
        final libc = DynamicLibrary.open('libc.so.6');
        libc.lookupFunction<
          Pointer Function(Pointer),
          Pointer Function(Pointer)
        >('uselocale')(previous);
      } catch (_) {}
    }
    if (locale != nullptr) {
      try {
        final libc = DynamicLibrary.open('libc.so.6');
        libc.lookupFunction<Void Function(Pointer), void Function(Pointer)>(
          'freelocale',
        )(locale);
      } catch (_) {}
    }
  }
}

final class _ObjectiveC {
  _ObjectiveC() : runtime = DynamicLibrary.open('/usr/lib/libobjc.A.dylib') {
    DynamicLibrary.open(
      '/System/Library/Frameworks/Foundation.framework/Foundation',
    );
  }
  final DynamicLibrary runtime;

  Pointer classNamed(String name) {
    final native = name.toNativeUtf8();
    try {
      return runtime.lookupFunction<
        Pointer Function(Pointer<Utf8>),
        Pointer Function(Pointer<Utf8>)
      >('objc_getClass')(native);
    } finally {
      calloc.free(native);
    }
  }

  Pointer selector(String name) {
    final native = name.toNativeUtf8();
    try {
      return runtime.lookupFunction<
        Pointer Function(Pointer<Utf8>),
        Pointer Function(Pointer<Utf8>)
      >('sel_registerName')(native);
    } finally {
      calloc.free(native);
    }
  }

  Pointer send(Pointer receiver, String name, [Pointer? argument]) {
    final select = selector(name);
    if (argument == null) {
      return runtime.lookupFunction<
        Pointer Function(Pointer, Pointer),
        Pointer Function(Pointer, Pointer)
      >('objc_msgSend')(receiver, select);
    }
    return runtime.lookupFunction<
      Pointer Function(Pointer, Pointer, Pointer),
      Pointer Function(Pointer, Pointer, Pointer)
    >('objc_msgSend')(receiver, select, argument);
  }

  Pointer sendInteger(Pointer receiver, String name, int value) =>
      runtime.lookupFunction<
        Pointer Function(Pointer, Pointer, Int32),
        Pointer Function(Pointer, Pointer, int)
      >('objc_msgSend')(receiver, selector(name), value);

  int integer(Pointer receiver, String name) =>
      runtime.lookupFunction<
        IntPtr Function(Pointer, Pointer),
        int Function(Pointer, Pointer)
      >('objc_msgSend')(receiver, selector(name));

  void setInteger(Pointer receiver, String name, int value) {
    runtime.lookupFunction<
      Void Function(Pointer, Pointer, IntPtr),
      void Function(Pointer, Pointer, int)
    >('objc_msgSend')(receiver, selector(name), value);
  }

  String? string(Pointer receiver, String name) {
    final string = send(receiver, name);
    if (string == nullptr) return null;
    final characters = send(string, 'UTF8String');
    return characters == nullptr
        ? null
        : characters.cast<Utf8>().toDartString();
  }
}

NumericConvention? _macOSNumericConvention() {
  Pointer formatter = nullptr;
  try {
    final objc = _ObjectiveC();
    final type = objc.classNamed('NSNumberFormatter');
    if (type == nullptr) return null;
    formatter = objc.send(objc.send(type, 'alloc'), 'init');
    if (formatter == nullptr) return null;
    final locale = objc.send(objc.classNamed('NSLocale'), 'currentLocale');
    if (locale == nullptr) return null;
    objc.send(formatter, 'setLocale:', locale);
    objc.setInteger(formatter, 'setNumberStyle:', 1);
    final decimal = objc.string(formatter, 'decimalSeparator');
    final thousands = objc.string(formatter, 'groupingSeparator');
    final negativeSign = objc.string(formatter, 'minusSign');
    final negativePrefix = objc.string(formatter, 'negativePrefix');
    final negativeSuffix = objc.string(formatter, 'negativeSuffix');
    if (decimal == null ||
        thousands == null ||
        negativeSign == null ||
        negativePrefix == null ||
        negativeSuffix == null) {
      return null;
    }
    final primary = objc.integer(formatter, 'groupingSize');
    final secondary = objc.integer(formatter, 'secondaryGroupingSize');
    final grouped = objc.integer(formatter, 'usesGroupingSeparator') != 0;
    final grouping = !grouped || primary < 1
        ? <int>[]
        : secondary > 0 && secondary != primary
        ? [secondary, primary]
        : [primary];
    // The sign placement is read from the negative affixes. The decimal style
    // reports `negativeFormat` as the positive shape (`#,##0.###` on the macOS
    // runners) and keeps the sign in `negativePrefix`, so that format string
    // cannot describe where a negative sign goes.
    final negativePattern = negativePrefix == '(' && negativeSuffix == ')'
        ? NumericNegativePattern.parentheses
        : negativePrefix == negativeSign
        ? NumericNegativePattern.leading
        : negativePrefix == '$negativeSign '
        ? NumericNegativePattern.leadingSpace
        : negativeSuffix == negativeSign
        ? NumericNegativePattern.trailing
        : negativeSuffix == ' $negativeSign'
        ? NumericNegativePattern.trailingSpace
        : null;
    if (negativePattern == null) return null;
    objc.setInteger(formatter, 'setUsesGroupingSeparator:', 0);
    final number = objc.classNamed('NSNumber');
    if (number == nullptr) return null;
    final digits = <int>[];
    for (var i = 0; i < 10; i++) {
      final value = objc.sendInteger(number, 'numberWithInt:', i);
      final text = objc.string(
        objc.send(formatter, 'stringFromNumber:', value),
        'description',
      );
      if (text == null || text.runes.length != 1) return null;
      digits.add(text.runes.single);
    }
    return NumericConvention(
      decimalSeparator: decimal,
      groupingSeparator: grouping.isEmpty ? '' : thousands,
      grouping: grouping,
      nativeDigits: String.fromCharCodes(digits),
      negativeSign: negativeSign,
      negativePattern: negativePattern,
    );
  } catch (_) {
    return null;
  } finally {
    if (formatter != nullptr) {
      try {
        _ObjectiveC().send(formatter, 'release');
      } catch (_) {}
    }
  }
}

NumericConvention? _systemNumericConvention() {
  if (Platform.isLinux) return _linuxNumericConvention();
  if (Platform.isMacOS) return _macOSNumericConvention();
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
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
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
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final ColorTheme colors;
  final PromptStructure structure;
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
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
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
      const digits = '1234567';
      final plain = '$digits${decimal ? '${resolved.decimalSeparator}89' : ''}';
      String group() {
        if (resolved.grouping.isEmpty) return digits;
        final groups = <String>[];
        var end = digits.length;
        var index = 0;
        while (end > 0) {
          final size =
              resolved.grouping[index < resolved.grouping.length
                  ? index
                  : resolved.grouping.length - 1];
          final start = end - size < 0 ? 0 : end - size;
          groups.insert(0, digits.substring(start, end));
          end = start;
          index++;
        }
        return groups.join(resolved.groupingSeparator);
      }

      final grouped =
          '${group()}${decimal ? '${resolved.decimalSeparator}89' : ''}';
      final nativeExample = String.fromCharCodes(
        grouped.runes.map(
          (r) => r >= 48 && r <= 57
              ? resolved.nativeDigits.runes.elementAt(r - 48)
              : r,
        ),
      );
      final negativeExample = switch (resolved.negativePattern) {
        NumericNegativePattern.leading => '${resolved.negativeSign}$plain',
        NumericNegativePattern.trailing => '$plain${resolved.negativeSign}',
        NumericNegativePattern.leadingSpace =>
          '${resolved.negativeSign} $plain',
        NumericNegativePattern.trailingSpace =>
          '$plain ${resolved.negativeSign}',
        NumericNegativePattern.parentheses => '($plain)',
      };
      final details =
          '${required ? 'Required' : 'Optional'} ${decimal ? 'decimal' : 'integer'} mode; ${convention == null ? 'system or provided' : 'explicit override'} convention; decimal separator ${resolved.decimalSeparator}; ${resolved.grouping.isEmpty ? 'grouping not supported' : 'grouping separator ${resolved.groupingSeparator}; grouping ${resolved.grouping.join(',')}; grouped example $grouped'}; ungrouped example $plain; positive example $plain; negative example $negativeExample; ASCII digits 0123456789; native digits ${resolved.nativeDigits}; native example $nativeExample${minimum == null ? '' : '; minimum $minimum'}${maximum == null ? '' : '; maximum $maximum'}${precision == null ? '' : '; maximum $precision decimal places'}.';
      final cue =
          '$label (${decimal ? 'decimal' : 'integer'} numeric entry; decimal separator ${resolved.decimalSeparator}${resolved.grouping.isEmpty ? '; no grouping' : '; grouping separator ${resolved.groupingSeparator}'})';
      final result =
          await TextInput(
            cue,
            required: required,
            validate: (value) => _validate(value, resolved),
            instructions: instructions,
            supplementaryHelp: [
              'Number format: base-ten ${decimal ? 'decimal' : 'integer'} values use the active numeric convention. $details',
              ...supplementaryHelp,
            ],
            colors: colors,
            structure: structure,
          ).prompt(
            source: source,
            mode: mode,
            userPreference: userPreference,
            applicationPreference: applicationPreference,
            output: output,
            terminal: terminal,
            outputProfile: outputProfile,
            session: session,
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
