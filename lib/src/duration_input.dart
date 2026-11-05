part of 'text_input.dart';

enum DurationInputMode { elapsed, calendarRelative }

/// A fixed elapsed span or an unapplied calendar period.
final class DurationValue {
  DurationValue._(this.draft, this.mode, this.microseconds, this.components);
  final String draft;
  final DurationInputMode mode;

  /// The elapsed total in elapsed mode; sub-day elapsed total in calendar mode.
  final BigInt microseconds;

  /// Signed whole calendar components, empty in elapsed mode.
  final Map<String, BigInt> components;
}

final class DurationInput {
  DurationInput(
    this.label, {
    required this.durationMode,
    this.signed = false,
    this.allowZero = true,
    this.minimumMicroseconds,
    this.initialValue,
  }) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (durationMode == DurationInputMode.calendarRelative &&
        minimumMicroseconds != null) {
      throw ArgumentError('Calendar periods do not have an elapsed minimum.');
    }
    if (initialValue != null && _parse(initialValue!) == null) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }
  final String label;
  final DurationInputMode durationMode;
  final bool signed;
  final bool allowZero;
  final int? minimumMicroseconds;
  final String? initialValue;
  bool _active = false;
  static final _limit = BigInt.parse('9223372036854775807');
  static const _units = <String, int>{
    'w': 604800000000,
    'd': 86400000000,
    'h': 3600000000,
    'm': 60000000,
    's': 1000000,
    'ms': 1000,
    'us': 1,
  };

  DurationValue? _parse(String text) {
    if (text.length > 1024 || text.isEmpty) return null;
    var body = text;
    var sign = BigInt.one;
    if (body.startsWith('-') || body.startsWith('+')) {
      if (!signed) return null;
      if (body.startsWith('-')) sign = -sign;
      body = body.substring(1);
    }
    final pattern = RegExp(r'([0-9]+(?:\.[0-9]+)?)(ms|us|mo|[ywdhms])');
    var at = 0;
    final seen = <String>{};
    final components = <String, BigInt>{};
    var total = BigInt.zero;
    while (at < body.length) {
      final match = pattern.matchAsPrefix(body, at);
      if (match == null) return null;
      final number = match[1]!;
      final unit = match[2]!;
      if (!seen.add(unit)) return null;
      final calendar =
          durationMode == DurationInputMode.calendarRelative &&
          {'y', 'mo', 'w', 'd'}.contains(unit);
      if (calendar) {
        if (number.contains('.')) return null;
        final n = BigInt.parse(number);
        if (n > _limit) return null;
        components[unit] = n * sign;
      } else {
        final factor = _units[unit];
        if (factor == null) return null;
        final parts = number.split('.');
        final numerator = BigInt.parse(parts.join()) * BigInt.from(factor);
        final denominator = BigInt.from(10)
            .pow(parts.length == 2 ? parts[1].length : 0);
        if (numerator % denominator != BigInt.zero) return null;
        total += numerator ~/ denominator;
        if (total > _limit) return null;
      }
      at = match.end;
      if (at < body.length) {
        if (body[at] != ' ') return null;
        while (at < body.length && body[at] == ' ') {
          at++;
        }
        if (at == body.length) return null;
      }
    }
    if (seen.isEmpty) return null;
    if (!allowZero &&
        total == BigInt.zero &&
        components.values.every((n) => n == BigInt.zero)) {
      return null;
    }
    total *= sign;
    if (durationMode == DurationInputMode.elapsed &&
        minimumMicroseconds != null &&
        total < BigInt.from(minimumMicroseconds!)) {
      return null;
    }
    return DurationValue._(
      text,
      durationMode,
      total,
      Map.unmodifiable(components),
    );
  }

  Future<PromptResult<DurationValue>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final description = durationMode == DurationInputMode.elapsed
          ? 'elapsed; units w d h m s ms us; d is 24 hours, w is 7 days; minimum ${minimumMicroseconds?.toString() ?? (signed ? "none" : "0")} microseconds'
          : 'calendar-relative; whole y mo w d and elapsed h m s ms us; unapplied period';
      final sink = source is ScriptedInput
          ? source.output
          : source == null
          ? (output ?? stderr)
          : null;
      void review(String draft) {
        if (sink == null) return;
        final value = _parse(draft);
        if (value == null) {
          sink.writeln('Interpretation unavailable: enter a valid duration.');
        } else if (durationMode == DurationInputMode.elapsed) {
          sink.writeln(
            'Elapsed interpretation: ${value.microseconds} microseconds.',
          );
        } else {
          sink.writeln(
            'Unapplied calendar components: ${value.components}; elapsed sub-day: ${value.microseconds} microseconds.',
          );
        }
      }

      final result =
          await TextInput._(
            '$label ($description; ${signed ? 'global sign allowed' : 'nonnegative'}; ${allowZero ? 'zero allowed unless below minimum' : 'zero forbidden'}; ASCII amounts with dot fractions, space-separated tokens, no grouping; exact integer microseconds; maximum 1024 characters; maximum magnitude 9223372036854775807)',
            onChanged: review,
            required: true,
            initialValue: initialValue ?? '',
            maxLength: 1024,
            validate: (v) => _parse(v) == null
                ? 'Invalid duration: use unique case-sensitive unit tokens and exact microseconds within bounds.'
                : null,
          ).prompt(
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
    } finally {
      _active = false;
    }
  }
}
