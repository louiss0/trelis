part of 'text_input.dart';

/// Field order for an explicit proleptic Gregorian, full-year override.
enum DateFieldOrder { dayMonthYear, monthDayYear, yearMonthDay }

/// Explicit calendar interpretation for supplied answers.
enum DateCalendar { gregorian, buddhist }

/// Explicit decimal digit repertoire; ASCII is always accepted.
enum DateDigits { ascii, thai, arabicIndic }

/// A proleptic Gregorian date without a time or time zone.
final class CivilDate {
  CivilDate._(this.year, this.month, this.day, this.inputYear, this.calendar);
  final int year;
  final int month;
  final int day;
  final int inputYear;
  final DateCalendar calendar;
}

/// Date entry with an explicit calendar and field order. Automatic system
/// resolution is not yet available and fails closed rather than guessing.
final class DateInput {
  DateInput(
    this.label, {
    this.order,
    this.calendar = DateCalendar.gregorian,
    this.digits = DateDigits.ascii,
    this.initialValue,
  }) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    final initial = initialValue;
    final explicitOrder = order;
    if (initial != null &&
        (explicitOrder == null || _parse(initial, explicitOrder) == null)) {
      throw ArgumentError.value(initial, 'initialValue');
    }
  }

  final String label;
  final DateFieldOrder? order;
  final DateCalendar calendar;
  final DateDigits digits;
  final String? initialValue;
  bool _active = false;

  CivilDate? _parse(String text, DateFieldOrder order) {
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final yearIndex = order == DateFieldOrder.yearMonthDay ? 0 : 2;
    final fields = <int>[];
    final nativeZero = switch (digits) {
      DateDigits.ascii => 0x30,
      DateDigits.thai => 0x0e50,
      DateDigits.arabicIndic => 0x0660,
    };
    for (var i = 0; i < 3; i++) {
      final runes = parts[i].runes.toList();
      if (runes.isEmpty ||
          runes.length > (i == yearIndex ? 4 : 2) ||
          (i == yearIndex && runes.length != 4)) {
        return null;
      }
      int? repertoire;
      var number = 0;
      for (final rune in runes) {
        final base = rune >= 0x30 && rune <= 0x39
            ? 0x30
            : rune >= nativeZero && rune <= nativeZero + 9
            ? nativeZero
            : -1;
        if (base < 0 || (repertoire != null && repertoire != base)) return null;
        repertoire = base;
        number = number * 10 + rune - base;
      }
      fields.add(number);
    }
    final inputYear = fields[yearIndex];
    final year = calendar == DateCalendar.buddhist
        ? inputYear - 543
        : inputYear;
    // Restrict the Buddhist profile to the modern January-based era.
    if (calendar == DateCalendar.buddhist && year < 1941) return null;
    final month =
        fields[switch (order) {
          DateFieldOrder.dayMonthYear => 1,
          DateFieldOrder.monthDayYear => 0,
          DateFieldOrder.yearMonthDay => 1,
        }];
    final day =
        fields[switch (order) {
          DateFieldOrder.dayMonthYear => 0,
          DateFieldOrder.monthDayYear => 1,
          DateFieldOrder.yearMonthDay => 2,
        }];
    if (year < 1 || month < 1 || month > 12 || day < 1) return null;
    final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    final days = <int>[
      31,
      leap ? 29 : 28,
      31,
      30,
      31,
      30,
      31,
      31,
      30,
      31,
      30,
      31,
    ];
    if (day > days[month - 1]) return null;
    return CivilDate._(year, month, day, inputYear, calendar);
  }

  Future<PromptResult<CivilDate>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final resolvedOrder = order;
      if (resolvedOrder == null) {
        return Unavailable(
          'System date preferences are unresolved; specify a calendar and field order.',
        );
      }
      if (source is SuppliedAnswer) {
        final value = _parse(source.value, resolvedOrder);
        return value == null
            ? Unavailable('Invalid date for the explicit calendar profile.')
            : Accepted(value);
      }
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
          return await _terminal<CivilDate>(
            selected,
            output ?? stderr,
            (source, mode, restore) =>
                _run(source, mode, resolvedOrder, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, resolvedOrder);
    } finally {
      _active = false;
    }
  }

  Future<({String action, String value})> _editSegments(
    _Keys keys,
    String draft,
    StringSink out,
    DateFieldOrder order,
  ) async {
    final names = switch (order) {
      DateFieldOrder.dayMonthYear => ['day', 'month', 'year'],
      DateFieldOrder.monthDayYear => ['month', 'day', 'year'],
      DateFieldOrder.yearMonthDay => ['year', 'month', 'day'],
    };
    final split = draft.split('/');
    final segments = List.generate(3, (i) => i < split.length ? split[i] : '');
    var focus = 0;
    while (true) {
      final name = names[focus];
      out.writeln(
        'Focus: $name. Tab or slash moves forward; Shift-Tab moves back; Up/Down adjusts without carry. Enter advances or reviews.',
      );
      final edit = await _edit(
        keys,
        segments[focus],
        out,
        intercept: (key, text) {
          if (key == '\t') return 'next';
          if (key == '\x1b[Z') return 'previous';
          if (key == '/') {
            final valid =
                text.isNotEmpty &&
                text.runes.length <= (name == 'year' ? 4 : 2) &&
                (name != 'year' || text.runes.length == 4);
            if (valid && focus < 2) return 'next';
            out.writeln('Slash cannot skip an incomplete field or submit.');
            return 'handled';
          }
          if (key == '\x1b[A' || key == '+') return 'increase';
          if (key == '\x1b[B' || key == '-') return 'decrease';
          return null;
        },
      );
      if (edit.action == 'cancel' ||
          edit.action == 'interrupt' ||
          edit.action == 'eof') {
        return edit;
      }
      segments[focus] = edit.value;
      if (edit.action == 'increase' || edit.action == 'decrease') {
        final number = int.tryParse(edit.value);
        if (number == null) {
          out.writeln('Enter an ASCII segment before adjustment.');
        } else {
          final next = number + (edit.action == 'increase' ? 1 : -1);
          final max = name == 'year'
              ? 9999
              : name == 'month'
              ? 12
              : 31;
          if (next >= 1 && next <= max) {
            segments[focus] = next.toString().padLeft(edit.value.length, '0');
          }
        }
        continue;
      }
      if (edit.action == 'previous') {
        focus = (focus + 2) % 3;
        continue;
      }
      if (edit.action == 'next') {
        focus = (focus + 1) % 3;
        continue;
      }
      if (edit.action == 'submit') {
        if (focus < 2) {
          focus++;
          continue;
        }
        return (action: 'submit', value: segments.join('/'));
      }
    }
  }

  Future<PromptResult<CivilDate>> _run(
    PromptSource source,
    PromptMode mode,
    DateFieldOrder order, {
    void Function()? beforeClose,
  }) async {
    if (source is! ScriptedInput) {
      return Unavailable('Unsupported date input source.');
    }
    if (mode == PromptMode.rich && !source.supportsRich) {
      return Unavailable('Rich interaction unavailable.');
    }
    final linear =
        mode == PromptMode.linear ||
        (mode == PromptMode.automatic && !source.supportsRich);
    final out = source.output;
    final keys = _Keys(source.input.transform(utf8.encoder));
    final format = switch (order) {
      DateFieldOrder.dayMonthYear => 'day/month/year',
      DateFieldOrder.monthDayYear => 'month/day/year',
      DateFieldOrder.yearMonthDay => 'year/month/day',
    };
    var draft = initialValue ?? '';
    out.writeln(
      '$label. ${calendar.name} calendar; $format; ASCII and ${digits.name} digits (one repertoire per field); four-digit year, one or two digit month and day. Slash separators.',
    );
    out.writeln('Enter a date, then review. /cancel cancels in linear mode.');
    try {
      while (true) {
        final edit = linear
            ? await _edit(
                keys,
                draft,
                out,
                linear: true,
                sequential: true,
                maxLength: 10,
              )
            : await _editSegments(keys, draft, out, order);
        if (edit.action == 'cancel') return Cancelled();
        if (edit.action == 'interrupt') return Interrupted();
        if (edit.action != 'submit') return InputEnded();
        draft = edit.value;
        final value = _parse(draft, order);
        if (value == null) {
          out.writeln('Invalid date; correct the retained draft.');
          continue;
        }
        final iso =
            '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
        out.writeln(
          'Review: ${calendar.name} year ${value.inputYear}, month ${value.month}, day ${value.day}; ISO date: $iso.',
        );
        out.writeln(
          'Type /submit to accept or /edit to return to the draft; /cancel cancels.',
        );
        while (true) {
          final action = await _edit(
            keys,
            '',
            out,
            linear: true,
            sequential: linear,
            extraCommands: const {'/submit', '/edit'},
          );
          if (action.action == 'cancel') return Cancelled();
          if (action.action == 'interrupt') return Interrupted();
          if (action.action == 'eof') return InputEnded();
          if (action.action == 'command' && action.value == '/submit') {
            return Accepted(value);
          }
          if (action.action == 'command' && action.value == '/edit') break;
          out.writeln('Use /submit or /edit.');
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
