part of 'text_input.dart';

/// Field order for an explicit proleptic Gregorian, full-year override.
enum DateFieldOrder { dayMonthYear, monthDayYear, yearMonthDay }

/// Explicit calendar interpretation for supplied answers.
enum DateCalendar { gregorian, buddhist }

/// Explicit decimal digit repertoire; ASCII is always accepted.
enum DateDigits { ascii, thai, arabicIndic }

// Windows GetLocaleInfoEx with user overrides enabled. Reject unknown patterns,
// calendars and numeral systems instead of guessing from a locale name.
({
  DateFieldOrder order,
  DateCalendar calendar,
  DateDigits digits,
  String pattern,
})?
_windowsDateProfile() {
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
      final fields = [0x1f, 0x1009, 0x13].map(field).toList();
      return fields.any((s) => s == null) ? null : fields.cast<String>();
    }

    final first = snapshot();
    final second = snapshot();
    if (first == null ||
        second == null ||
        first.join('\u0000') != second.join('\u0000')) {
      return null;
    }
    // Full year only: reduced-year windows require additional native data.
    final pattern = first[0];
    final match = RegExp(r'^(M|d|yyyy)([/.-])(M|d|yyyy)\2(M|d|yyyy)$')
        .firstMatch(pattern);
    if (match == null) return null;
    final fields = [match[1], match[3], match[4]].join('/');
    final order = switch (fields) {
      'M/d/yyyy' => DateFieldOrder.monthDayYear,
      'd/M/yyyy' => DateFieldOrder.dayMonthYear,
      'yyyy/M/d' => DateFieldOrder.yearMonthDay,
      _ => null,
    };
    final calendar = switch (first[1]) {
      '1' => DateCalendar.gregorian,
      '7' => DateCalendar.buddhist,
      _ => null,
    };
    final digits = switch (first[2]) {
      '0123456789' => DateDigits.ascii,
      '\u0e50\u0e51\u0e52\u0e53\u0e54\u0e55\u0e56\u0e57\u0e58\u0e59' =>
        DateDigits.thai,
      '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669' =>
        DateDigits.arabicIndic,
      _ => null,
    };
    if (order == null || calendar == null || digits == null) return null;
    return (order: order, calendar: calendar, digits: digits, pattern: pattern);
  } catch (_) {
    return null;
  }
}

// glibc 2.x: use a separate locale object, never mutate the process locale.
({
  DateFieldOrder order,
  DateCalendar calendar,
  DateDigits digits,
  String pattern,
})?
_linuxDateProfile() {
  if (!Platform.isLinux) return null;
  Pointer locale = nullptr;
  try {
    final libc = DynamicLibrary.open('libc.so.6');
    final create = libc
        .lookupFunction<
          Pointer Function(Int32, Pointer<Utf8>, Pointer),
          Pointer Function(int, Pointer<Utf8>, Pointer)
        >('newlocale');
    final info = libc
        .lookupFunction<
          Pointer<Utf8> Function(Int32, Pointer),
          Pointer<Utf8> Function(int, Pointer)
        >('nl_langinfo_l');
    final env = Platform.environment;
    final name =
        [
          env['LC_ALL'],
          env['LC_TIME'],
          env['LANG'],
        ].whereType<String>().where((s) => s.isNotEmpty).firstOrNull ??
        'C';
    final native = name.toNativeUtf8();
    try {
      locale = create(4, native, nullptr);
    } finally {
      calloc.free(native);
    }
    if (locale == nullptr) return null;
    String? field(int index) {
      final result = info((2 << 16) | index, locale);
      return result == nullptr ? null : result.toDartString();
    }

    final pattern = field(41); // D_FMT
    final era = field(46); // ERA_D_FMT
    final alternate = field(47); // ALT_DIGITS
    if (pattern == null ||
        era == null ||
        alternate == null ||
        era.isNotEmpty ||
        alternate.isNotEmpty) {
      return null;
    }
    final match = RegExp(r'^(%d|%m|%Y)([/.-])(%d|%m|%Y)\2(%d|%m|%Y)$')
        .firstMatch(pattern);
    if (match == null) return null;
    final fields = [match[1], match[3], match[4]].join('/');
    final order = switch (fields) {
      '%d/%m/%Y' => DateFieldOrder.dayMonthYear,
      '%m/%d/%Y' => DateFieldOrder.monthDayYear,
      '%Y/%m/%d' => DateFieldOrder.yearMonthDay,
      _ => null,
    };
    return order == null
        ? null
        : (
            order: order,
            calendar: DateCalendar.gregorian,
            digits: DateDigits.ascii,
            pattern: pattern,
          );
  } catch (_) {
    return null;
  } finally {
    if (locale != nullptr) {
      try {
        DynamicLibrary.open('libc.so.6')
            .lookupFunction<Void Function(Pointer), void Function(Pointer)>(
              'freelocale',
            )(locale);
      } catch (_) {}
    }
  }
}

// Foundation current locale and short-style formatter. Only numeric full-year
// profiles with a verified calendar and decimal repertoire are mapped.
({
  DateFieldOrder order,
  DateCalendar calendar,
  DateDigits digits,
  String pattern,
})?
_macOSDateProfile() {
  if (!Platform.isMacOS) return null;
  Pointer formatter = nullptr;
  try {
    final objc = _ObjectiveC();
    final type = objc.classNamed('NSDateFormatter');
    if (type == nullptr) return null;
    formatter = objc.send(objc.send(type, 'alloc'), 'init');
    final locale = objc.send(objc.classNamed('NSLocale'), 'currentLocale');
    if (formatter == nullptr || locale == nullptr) return null;
    objc.send(formatter, 'setLocale:', locale);
    objc.setInteger(formatter, 'setDateStyle:', 1);
    objc.setInteger(formatter, 'setTimeStyle:', 0);
    final pattern = objc.string(formatter, 'dateFormat');
    final calendarObject = objc.send(formatter, 'calendar');
    if (pattern == null || calendarObject == nullptr) return null;
    final identifier = objc.string(calendarObject, 'calendarIdentifier');
    final match = RegExp(r'^(M|d|yyyy)([/.-])(M|d|yyyy)\2(M|d|yyyy)$')
        .firstMatch(pattern);
    if (match == null) return null;
    final fields = [match[1], match[3], match[4]].join('/');
    final order = switch (fields) {
      'd/M/yyyy' => DateFieldOrder.dayMonthYear,
      'M/d/yyyy' => DateFieldOrder.monthDayYear,
      'yyyy/M/d' => DateFieldOrder.yearMonthDay,
      _ => null,
    };
    final calendar = switch (identifier) {
      'gregorian' => DateCalendar.gregorian,
      'buddhist' => DateCalendar.buddhist,
      _ => null,
    };
    final nativeDigits = _macOSNumericConvention()?.nativeDigits;
    final digits = switch (nativeDigits) {
      '0123456789' => DateDigits.ascii,
      '\u0e50\u0e51\u0e52\u0e53\u0e54\u0e55\u0e56\u0e57\u0e58\u0e59' =>
        DateDigits.thai,
      '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669' =>
        DateDigits.arabicIndic,
      _ => null,
    };
    if (order == null || calendar == null || digits == null) return null;
    return (order: order, calendar: calendar, digits: digits, pattern: pattern);
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

({
  DateFieldOrder order,
  DateCalendar calendar,
  DateDigits digits,
  String pattern,
})?
_systemDateProfile() {
  if (Platform.isWindows) return _windowsDateProfile();
  if (Platform.isLinux) return _linuxDateProfile();
  if (!Platform.isMacOS) return null;
  // A formatter and number formatter are separate Foundation objects. Reject
  // changed effective profiles rather than combining two preference states.
  final first = _macOSDateProfile();
  final second = _macOSDateProfile();
  return first != null && first == second ? first : null;
}

/// A proleptic Gregorian date without a time or time zone.
final class CivilDate {
  CivilDate._(this.year, this.month, this.day, this.inputYear, this.calendar);
  final int year;
  final int month;
  final int day;
  final int inputYear;
  final DateCalendar calendar;

  /// Identity of the in-package date-only conversion rules.
  String get provider => 'prompty-civil-arithmetic-v1';
  String get era => calendar == DateCalendar.buddhist ? 'BE' : 'CE';
  String get monthIdentity => 'M${month.toString().padLeft(2, '0')}';
  bool get isLeapMonth => false;
}

// Date-only conversion boundary. The supported Buddhist profile is the modern
// January-based interval, with no leap-month or era ambiguity in this range.
final class _ArithmeticDateProvider {
  _ArithmeticDateProvider(this.calendar);
  final DateCalendar calendar;

  CivilDate? convert(int inputYear, int month, int day) {
    final year = calendar == DateCalendar.buddhist
        ? inputYear - 543
        : inputYear;
    if (calendar == DateCalendar.buddhist && year < 1941) return null;
    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
      return null;
    }
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
}

/// Date entry with explicit or narrowly supported system preferences.
/// Unresolved profiles fail closed rather than guessing.
final class DateInput {
  DateInput(
    this.label, {
    this.order,
    DateCalendar? calendar,
    DateDigits? digits,
    this.initialValue,
  }) : calendar = calendar ?? DateCalendar.gregorian,
       digits = digits ?? DateDigits.ascii {
    if (order == null && (calendar != null || digits != null)) {
      throw ArgumentError(
        'A calendar or digit override requires an explicit field order.',
      );
    }
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
    return _ArithmeticDateProvider(calendar).convert(inputYear, month, day);
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
        final profile = _systemDateProfile();
        if (profile == null) {
          return Unavailable(
            'System date preferences are unsupported or unresolved; specify a calendar and field order.',
          );
        }
        return await DateInput(
          '$label (effective system pattern ${profile.pattern}, adapted to slash)',
          order: profile.order,
          calendar: profile.calendar,
          digits: profile.digits,
        ).prompt(
          source: source,
          mode: mode,
          userPreference: userPreference,
          applicationPreference: applicationPreference,
          output: output,
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

  int get _nativeZero => switch (digits) {
    DateDigits.ascii => 0x30,
    DateDigits.thai => 0x0e50,
    DateDigits.arabicIndic => 0x0660,
  };

  int? _segmentNumber(String value) {
    if (value.isEmpty) return null;
    int? base;
    var result = 0;
    for (final rune in value.runes) {
      final current = rune >= 0x30 && rune <= 0x39
          ? 0x30
          : rune >= _nativeZero && rune <= _nativeZero + 9
          ? _nativeZero
          : -1;
      if (current < 0 || (base != null && base != current)) return null;
      base = current;
      result = result * 10 + rune - current;
    }
    return result;
  }

  String _dateError(String draft, DateFieldOrder order) {
    final parts = draft.split('/');
    if (parts.length != 3) {
      return 'Invalid date: enter all three slash-separated fields.';
    }
    final labels = switch (order) {
      DateFieldOrder.dayMonthYear => ['day', 'month', 'year'],
      DateFieldOrder.monthDayYear => ['month', 'day', 'year'],
      DateFieldOrder.yearMonthDay => ['year', 'month', 'day'],
    };
    final values = <String, int>{};
    for (var i = 0; i < 3; i++) {
      final label = labels[i];
      final value = _segmentNumber(parts[i]);
      final width = parts[i].runes.length;
      if (value == null ||
          (label == 'year' ? width != 4 : width < 1 || width > 2)) {
        return 'Invalid date: $label must use the indicated width and one digit repertoire.';
      }
      values[label] = value;
    }
    final year = values['year']!;
    final month = values['month']!;
    if (year < (calendar == DateCalendar.buddhist ? 2484 : 1)) {
      return 'Invalid date: year is outside the supported calendar range.';
    }
    if (month < 1 || month > 12) {
      return 'Invalid date: month must be 1 through 12.';
    }
    return 'Invalid date: day does not exist in the selected month and year.';
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
      if (focus == 3) {
        out.writeln(
          'Focus: Review. Enter reviews; Tab moves forward; Shift-Tab or Ctrl+B moves back.',
        );
        final action = await _edit(
          keys,
          '',
          out,
          intercept: (key, text) {
            if (key == '\t') return 'next';
            if (key == '\x1b[Z' || key == '\x02') return 'previous';
            if ((key == '\r' || key == '\n') && text.isEmpty) return 'review';
            return null;
          },
        );
        if (action.action == 'cancel' ||
            action.action == 'interrupt' ||
            action.action == 'eof') {
          return action;
        }
        if (action.action == 'review') {
          return (action: 'submit', value: segments.join('/'));
        }
        if (action.action == 'previous') focus = 2;
        if (action.action == 'next') focus = 0;
        continue;
      }
      final name = names[focus];
      out.writeln(
        'Focus: $name. Tab or slash moves forward; Shift-Tab or Ctrl+B moves back; Up/Down adjusts without carry. Enter advances or reviews.',
      );
      final edit = await _edit(
        keys,
        segments[focus],
        out,
        maxLength: name == 'year' ? 4 : 2,
        intercept: (key, text) {
          if (key.startsWith('\x1b[200~') && key.contains('/')) {
            out.writeln('Paste only one numeric segment at a time.');
            return 'handled';
          }
          if (key == '\t') return 'next';
          if (key == '\x1b[Z' || key == '\x02') return 'previous';
          if (key == '/') {
            final valid =
                _segmentNumber(text) != null &&
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
        final number = _segmentNumber(edit.value);
        if (number == null) {
          out.writeln('Enter a numeric segment before adjustment.');
        } else {
          final next = number + (edit.action == 'increase' ? 1 : -1);
          final max = name == 'year'
              ? 9999
              : name == 'month'
              ? 12
              : 31;
          if (next >= 1 && next <= max) {
            final ascii = next.toString().padLeft(edit.value.runes.length, '0');
            final first = edit.value.runes.first;
            final base = first >= 0x30 && first <= 0x39 ? 0x30 : _nativeZero;
            segments[focus] = String.fromCharCodes(
              ascii.runes.map((r) => r - 0x30 + base),
            );
          }
        }
        continue;
      }
      if (edit.action == 'previous') {
        focus = (focus + 3) % 4;
        continue;
      }
      if (edit.action == 'next') {
        focus = (focus + 1) % 4;
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
    final sampleYear = calendar == DateCalendar.buddhist ? '2567' : '2024';
    final example = switch (order) {
      DateFieldOrder.dayMonthYear => '29/2/$sampleYear',
      DateFieldOrder.monthDayYear => '2/29/$sampleYear',
      DateFieldOrder.yearMonthDay => '$sampleYear/2/29',
    };
    out.writeln(
      'Year is ${calendar == DateCalendar.buddhist ? 'Buddhist era 2484-9999' : 'CE 0001-9999'}; Gregorian-derived months, no leap-month context. Example: $example. Arithmetic profile; date only, no timezone.',
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
          out.writeln(
            '${_dateError(draft, order)} Correct the retained draft.',
          );
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
        var reviewFocus = 0;
        if (!linear) {
          out.writeln(
            'Review action: Edit. Tab or Ctrl+B changes action; Enter activates.',
          );
        }
        while (true) {
          final action = await _edit(
            keys,
            '',
            out,
            linear: true,
            sequential: linear,
            extraCommands: const {'/submit', '/edit'},
            intercept: linear
                ? null
                : (key, text) {
                    if (key == '\t' || key == '\x1b[Z' || key == '\x02') {
                      reviewFocus = 1 - reviewFocus;
                      out.writeln(
                        'Review action: ${reviewFocus == 0 ? 'Edit' : 'Submit'}.',
                      );
                      return 'handled';
                    }
                    if ((key == '\r' || key == '\n') && text.isEmpty) {
                      return reviewFocus == 0 ? 'review-edit' : 'review-submit';
                    }
                    return null;
                  },
          );
          if (action.action == 'cancel') return Cancelled();
          if (action.action == 'interrupt') return Interrupted();
          if (action.action == 'eof') return InputEnded();
          if (action.action == 'review-submit' ||
              (action.action == 'command' && action.value == '/submit')) {
            return Accepted(value);
          }
          if (action.action == 'review-edit' ||
              (action.action == 'command' && action.value == '/edit')) {
            break;
          }
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
