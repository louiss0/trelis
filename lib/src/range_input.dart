part of 'text_input.dart';

/// Exact decimal slider input. Decimal values are represented as strings.
final class Slider {
  Slider(
    this.label, {
    required this.minimum,
    required this.maximum,
    required this.step,
    this.initialValue,
    this.precision,
    this.units,
  }) {
    if (label.trim().isEmpty ||
        label.runes.any((c) => c < 32 || c == 127) ||
        (units != null && units!.runes.any((c) => c < 32 || c == 127))) {
      throw ArgumentError('Invalid label or units.');
    }
    final min = _decimal(minimum);
    final max = _decimal(maximum);
    final increment = _decimal(step);
    if (min == null ||
        max == null ||
        increment == null ||
        _compare(min, max) > 0 ||
        increment.$1 <= BigInt.zero ||
        (precision != null &&
            (precision! < 0 ||
                min.$2 > precision! ||
                max.$2 > precision! ||
                increment.$2 > precision!))) {
      throw ArgumentError('Invalid slider bounds or step.');
    }
    if (initialValue != null && _validate(initialValue!) != null) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }

  final String label;
  final String minimum;
  final String maximum;
  final String step;
  final String? initialValue;
  final int? precision;
  final String? units;
  String get _description =>
      '$label (minimum $minimum, maximum $maximum, step $step${units == null ? '' : ', units $units'}${precision == null ? '' : ', maximum $precision decimal places'})';

  String? _validate(String value) {
    final number = _decimal(value);
    final min = _decimal(minimum)!;
    final max = _decimal(maximum)!;
    final increment = _decimal(step)!;
    if (number == null ||
        (precision != null && number.$2 > precision!) ||
        _compare(number, min) < 0 ||
        _compare(number, max) > 0) {
      return 'Enter a value between $minimum and $maximum on the $step grid.';
    }
    final scale = [
      number.$2,
      min.$2,
      increment.$2,
    ].reduce((a, b) => a > b ? a : b);
    final n = number.$1 * BigInt.from(10).pow(scale - number.$2);
    final m = min.$1 * BigInt.from(10).pow(scale - min.$2);
    final s = increment.$1 * BigInt.from(10).pow(scale - increment.$2);
    return (n - m) % s == BigInt.zero
        ? null
        : 'Enter a value between $minimum and $maximum on the $step grid.';
  }

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
      return await _run(source, selected);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<String>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    if (source is SuppliedAnswer ||
        (source is ScriptedInput &&
            (mode == PromptMode.linear ||
                (mode == PromptMode.automatic && !source.supportsRich)))) {
      try {
        return await TextInput(
          _description,
          required: true,
          initialValue: initialValue ?? '',
          validate: _validate,
        ).prompt(source: source, mode: PromptMode.linear);
      } finally {
        beforeClose?.call();
      }
    }
    final scripted = source as ScriptedInput;
    if (!scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    final out = scripted.output;
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    var value = initialValue ?? '';
    var focus = 0;
    var help = false;
    void show() {
      out.writeln(
        '$_description. Value: ${value.isEmpty ? 'not set' : value}.',
      );
      out.writeln(
        'Focus: ${['Slider', 'Edit', 'Submit'][focus]}. Tab moves; arrows adjust Slider; Enter activates Edit or Submit; Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
      );
    }

    show();
    try {
      while (true) {
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          out.writeln('Help dismissed.');
          show();
          continue;
        }
        if (key == '\x14') {
          help = true;
          out.writeln(
            'Help: Tab moves through controls; arrows adjust a focused value; Enter activates Edit or Submit. Escape dismisses help; Ctrl+C interrupts.',
          );
          continue;
        }
        if (help) continue;
        if (key == '\t') {
          focus = (focus + 1) % 3;
          show();
          continue;
        }
        if (focus == 0 &&
            (key == '\x1b[C' ||
                key == '\x1b[A' ||
                key == '\x1b[D' ||
                key == '\x1b[B')) {
          if (_validate(value) == null) {
            final candidate = _addDecimal(
              value,
              step,
              key == '\x1b[C' || key == '\x1b[A' ? 1 : -1,
            );
            if (_validate(candidate) == null) value = candidate;
          } else {
            out.writeln('Edit a valid value before adjusting.');
          }
          show();
          continue;
        }
        if ((key == '\r' || key == '\n') && focus == 1) {
          out.writeln('Edit value; Enter finishes editing.');
          final edit = await _edit(keys, value, out);
          if (edit.action == 'interrupt') return Interrupted();
          if (edit.action == 'cancel') {
            out.writeln('Edit dismissed.');
            show();
            continue;
          }
          if (edit.action != 'submit') return InputEnded();
          value = edit.value;
          final error = _validate(value);
          if (error != null) out.writeln(error);
          show();
          continue;
        }
        if ((key == '\r' || key == '\n') && focus == 2) {
          final error = _validate(value);
          if (error == null) return Accepted(value);
          out.writeln(error);
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

(BigInt, int)? _decimal(String text) {
  if (!RegExp(r'^-?[0-9]+(?:\.[0-9]+)?$').hasMatch(text)) return null;
  final parts = text.split('.');
  return (BigInt.parse(parts.join()), parts.length == 2 ? parts[1].length : 0);
}

int _compare((BigInt, int) a, (BigInt, int) b) {
  final scale = a.$2 > b.$2 ? a.$2 : b.$2;
  return (a.$1 * BigInt.from(10).pow(scale - a.$2)).compareTo(
    b.$1 * BigInt.from(10).pow(scale - b.$2),
  );
}

String _addDecimal(String value, String step, int direction) {
  final a = _decimal(value)!;
  final b = _decimal(step)!;
  final scale = a.$2 > b.$2 ? a.$2 : b.$2;
  final number =
      a.$1 * BigInt.from(10).pow(scale - a.$2) +
      b.$1 * BigInt.from(10).pow(scale - b.$2) * BigInt.from(direction);
  final negative = number.isNegative;
  var digits = number.abs().toString().padLeft(scale + 1, '0');
  if (scale > 0) {
    digits =
        '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
  }
  return '${negative ? '-' : ''}$digits';
}

/// An exact pair of slider endpoints.
final class RangeSlider {
  RangeSlider(
    String label, {
    required String minimum,
    required String maximum,
    required String step,
    this.minimumGap = '0',
    this.initialLower,
    this.initialUpper,
    int? precision,
    String? units,
  }) : _slider = Slider(
         label,
         minimum: minimum,
         maximum: maximum,
         step: step,
         precision: precision,
         units: units,
       ) {
    final gap = _decimal(minimumGap);
    if (gap == null ||
        gap.$1.isNegative ||
        (precision != null && gap.$2 > precision)) {
      throw ArgumentError.value(minimumGap, 'minimumGap');
    }
    if ((initialLower == null) != (initialUpper == null) ||
        (initialLower != null &&
            _pairError(initialLower!, initialUpper!) != null)) {
      throw ArgumentError('Invalid initial range.');
    }
  }

  final String minimumGap;
  final String? initialLower;
  final String? initialUpper;

  String? _pairError(String lower, String upper) {
    final l = _slider._validate(lower);
    if (l != null) return 'Lower: $l';
    final u = _slider._validate(upper);
    if (u != null) return 'Upper: $u';
    if (_compare(
          _decimal(_addDecimal(lower, minimumGap, 1))!,
          _decimal(upper)!,
        ) >
        0) {
      return 'Lower and Upper must remain ordered with minimum gap $minimumGap.';
    }
    return null;
  }

  final Slider _slider;
  bool _active = false;

  Future<PromptResult<(String, String)>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
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
          return await _terminal<(String, String)>(
            selected,
            output ?? stderr,
            (source, mode, restore) => _run(source, mode, restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, null);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<(String, String)>> _run(
    PromptSource source,
    PromptMode mode,
    void Function()? beforeClose,
  ) async {
    if (source is SuppliedAnswer) {
      final parts = source.value.split(',');
      if (parts.length != 2) {
        return Unavailable(
          'Supply Lower,Upper as two decimal values separated by a comma.',
        );
      }
      final error = _pairError(parts[0], parts[1]);
      return error == null
          ? Accepted((parts[0], parts[1]))
          : Unavailable(error);
    }
    final scripted = source as ScriptedInput;
    if (mode == PromptMode.rich && !scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.rich ||
        (mode == PromptMode.automatic && scripted.supportsRich)) {
      return _rich(scripted, beforeClose);
    }
    final out = scripted.output;
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    var lower = initialLower ?? '';
    var upper = initialUpper ?? '';
    try {
      out.writeln('${_slider._description}, minimum gap $minimumGap.');
      while (true) {
        out.writeln('Lower endpoint:');
        final l = await _edit(keys, lower, out, linear: true, sequential: true);
        if (l.action == 'cancel') return Cancelled();
        if (l.action == 'interrupt') return Interrupted();
        if (l.action != 'submit') return InputEnded();
        lower = l.value;
        final lowerError = _slider._validate(lower);
        if (lowerError != null) {
          out.writeln(lowerError);
          continue;
        }
        while (true) {
          out.writeln('Upper endpoint:');
          final u = await _edit(
            keys,
            upper,
            out,
            linear: true,
            sequential: true,
          );
          if (u.action == 'cancel') return Cancelled();
          if (u.action == 'interrupt') return Interrupted();
          if (u.action != 'submit') return InputEnded();
          upper = u.value;
          final upperError = _slider._validate(upper);
          if (upperError != null) {
            out.writeln(upperError);
            continue;
          }
          final pairError = _pairError(lower, upper);
          if (pairError != null) {
            out.writeln(pairError);
            break;
          }
          out.writeln(
            'Review Lower $lower, Upper $upper. Submit: press Enter.',
          );
          final confirm = await _edit(
            keys,
            '',
            out,
            linear: true,
            sequential: true,
          );
          if (confirm.action == 'cancel') return Cancelled();
          if (confirm.action == 'interrupt') return Interrupted();
          if (confirm.action != 'submit') return InputEnded();
          if (confirm.value.isEmpty) return Accepted((lower, upper));
          out.writeln('Enter an empty line to submit, or edit the pair.');
          break;
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

  Future<PromptResult<(String, String)>> _rich(
    ScriptedInput source,
    void Function()? beforeClose,
  ) async {
    final out = source.output;
    final keys = _Keys(source.input.transform(utf8.encoder));
    var lower = initialLower ?? '';
    var upper = initialUpper ?? '';
    var focus = 0;
    var help = false;
    const names = ['Lower', 'Upper', 'Edit Lower', 'Edit Upper', 'Submit'];
    void show() {
      out.writeln(
        '${_slider._description}, minimum gap $minimumGap. Lower: ${lower.isEmpty ? 'not set' : lower}; Upper: ${upper.isEmpty ? 'not set' : upper}.',
      );
      out.writeln(
        'Focus: ${names[focus]}. Tab moves; arrows adjust endpoints; Enter activates Edit or Submit; Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
      );
    }

    try {
      show();
      while (true) {
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          out.writeln('Help dismissed.');
          show();
          continue;
        }
        if (key == '\x14') {
          help = true;
          out.writeln(
            'Help: Tab moves through controls; arrows adjust a focused value; Enter activates Edit or Submit. Escape dismisses help; Ctrl+C interrupts.',
          );
          continue;
        }
        if (help) continue;
        if (key == '\t') {
          focus = (focus + 1) % names.length;
          show();
          continue;
        }
        if (focus < 2 &&
            (key == '\x1b[A' ||
                key == '\x1b[B' ||
                key == '\x1b[C' ||
                key == '\x1b[D')) {
          if (_pairError(lower, upper) == null) {
            final current = focus == 0 ? lower : upper;
            final next = _addDecimal(
              current,
              _slider.step,
              key == '\x1b[A' || key == '\x1b[C' ? 1 : -1,
            );
            if (_pairError(
                  focus == 0 ? next : lower,
                  focus == 1 ? next : upper,
                ) ==
                null) {
              if (focus == 0) {
                lower = next;
              } else {
                upper = next;
              }
            }
          } else {
            out.writeln(
              'Edit both endpoints to valid values before adjustment.',
            );
          }
          show();
          continue;
        }
        if ((key == '\r' || key == '\n') && (focus == 2 || focus == 3)) {
          out.writeln('${names[focus]}: Enter finishes editing.');
          final edit = await _edit(keys, focus == 2 ? lower : upper, out);
          if (edit.action == 'cancel') {
            out.writeln('Edit dismissed.');
            show();
            continue;
          }
          if (edit.action == 'interrupt') return Interrupted();
          if (edit.action != 'submit') return InputEnded();
          if (focus == 2) {
            lower = edit.value;
          } else {
            upper = edit.value;
          }
          final error = _pairError(lower, upper);
          if (error != null) out.writeln(error);
          show();
          continue;
        }
        if ((key == '\r' || key == '\n') && focus == 4) {
          final error = _pairError(lower, upper);
          if (error == null) return Accepted((lower, upper));
          out.writeln(error);
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
