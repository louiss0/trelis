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
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
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
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final ColorTheme colors;
  final PromptStructure structure;
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

  /// The interpretation of the current draft, and whether it is available.
  ///
  /// The content is the same in both interaction modes: the elapsed total in
  /// microseconds, the unapplied calendar components with their sub-day elapsed
  /// total, or the reason the draft has no interpretation. Rich interaction
  /// rewrites the row under the editable row, so it replaces the previous
  /// draft's interpretation instead of piling up in the transcript.
  ({String text, bool unavailable}) _interpretation(String draft) {
    final value = _parse(draft);
    if (value == null) {
      return (
        text: 'Interpretation unavailable: enter a valid duration.',
        unavailable: true,
      );
    }
    return (
      text: durationMode == DurationInputMode.elapsed
          ? 'Elapsed interpretation: ${value.microseconds} microseconds.'
          : 'Unapplied calendar components: ${value.components}; elapsed sub-day: ${value.microseconds} microseconds.',
      unavailable: false,
    );
  }

  Future<PromptResult<DurationValue>> prompt({
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
      final description = durationMode == DurationInputMode.elapsed
          ? 'elapsed; units w d h m s ms us; d is 24 hours, w is 7 days; minimum ${minimumMicroseconds?.toString() ?? (signed ? "none" : "0")} microseconds'
          : 'calendar-relative; whole y mo w d and elapsed h m s ms us; unapplied period';
      final cue = durationMode == DurationInputMode.elapsed
          ? 'elapsed duration; units w d h m s ms us${signed ? '; one global sign allowed' : ''}'
          : 'calendar-relative duration; whole y mo w d plus elapsed h m s ms us; period is unapplied${signed ? '; one global sign allowed' : ''}';
      final sink = source is ScriptedInput
          ? source.output
          : source == null
          ? (session != null
                ? _SessionOutputSink(session)
                : output ?? terminal?.output ?? stdout)
          : null;
      final reviewSpine = _structureSpine(
        outputProfile,
        structure: structure,
        width: null,
        background: colors.background,
        border: colors.border,
      );
      void review(String draft) {
        if (sink == null) return;
        final interpretation = _interpretation(draft);
        reviewSpine.hint(
          sink,
          interpretation.text,
          foreground: interpretation.unavailable
              ? colors.warning
              : colors.muted,
        );
      }

      final result =
          await TextInput._(
            '$label ($cue).',
            onChanged: review,
            livePreview: (draft) => _interpretation(draft).text,
            required: true,
            initialValue: initialValue ?? '',
            maxLength: 1024,
            validate: (v) => _parse(v) == null
                ? 'Invalid duration: use unique case-sensitive unit tokens and exact microseconds within bounds.'
                : null,
            instructions: instructions,
            supplementaryHelp: [
              'Duration format: $description; ${signed ? 'one global sign is allowed' : 'amounts are nonnegative'}; ${allowZero ? 'zero is allowed unless below the minimum' : 'zero is forbidden'}. Use ASCII amounts, optional dot fractions where exact, and space-separated case-sensitive tokens; fractions must convert exactly to integer microseconds, with maximum magnitude 9223372036854775807. Calendar periods are unapplied and do not imply an elapsed total.',
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
