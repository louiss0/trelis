/// Internal field-cell model for cron expression entry.
///
/// This library is intentionally absent from `package:trelis/trelis.dart`.
/// It is the shared seam used by `CronInput`'s cell editor and by tests that
/// exercise the per-profile field-cell schema, per-cell validation, the
/// Quartz `?` day-exclusivity rule, verbatim expression assembly and
/// `initialValue` splitting directly.
library;

import 'text_input.dart' show CronProfile;

/// Maximum assembled cron expression length in UTF-16 code units.
const int cronMaxExpressionLength = 4096;

/// One ordered cron field cell in a profile's entry schema.
final class CronFieldCell {
  const CronFieldCell({
    required this.name,
    required this.index,
    required this.position,
    required this.total,
    required this.rangeCue,
    required this.optional,
    required this.min,
    required this.max,
  });

  /// 0-based position in the cell list and in the assembled expression.
  final int index;

  /// Cron field name ('minute', 'day-of-month', 'year', ...).
  final String name;

  /// 1-based position shown by the active-format cue (`i/N`).
  final int position;

  /// Total number of cells in the profile's schema.
  final int total;

  /// Concise range/syntax cue shown for the cell.
  final String rangeCue;

  /// Whether the cell may stay empty (only the Quartz `year` cell).
  final bool optional;

  /// Lowest value a bare numeric cell draft may take (Up/Down stepping).
  final int min;

  /// Highest value a bare numeric cell draft may take (Up/Down stepping).
  final int max;
}

const _unixCells = [
  CronFieldCell(
    name: 'minute',
    index: 0,
    position: 1,
    total: 5,
    rangeCue: '0-59',
    optional: false,
    min: 0,
    max: 59,
  ),
  CronFieldCell(
    name: 'hour',
    index: 1,
    position: 2,
    total: 5,
    rangeCue: '0-23',
    optional: false,
    min: 0,
    max: 23,
  ),
  CronFieldCell(
    name: 'day-of-month',
    index: 2,
    position: 3,
    total: 5,
    rangeCue: '1-31',
    optional: false,
    min: 1,
    max: 31,
  ),
  CronFieldCell(
    name: 'month',
    index: 3,
    position: 4,
    total: 5,
    rangeCue: '1-12 or JAN-DEC',
    optional: false,
    min: 1,
    max: 12,
  ),
  CronFieldCell(
    name: 'day-of-week',
    index: 4,
    position: 5,
    total: 5,
    rangeCue: '0-7 or SUN-SAT (0 and 7 are Sunday)',
    optional: false,
    min: 0,
    max: 7,
  ),
];

const _quartzCells = [
  CronFieldCell(
    name: 'second',
    index: 0,
    position: 1,
    total: 7,
    rangeCue: '0-59',
    optional: false,
    min: 0,
    max: 59,
  ),
  CronFieldCell(
    name: 'minute',
    index: 1,
    position: 2,
    total: 7,
    rangeCue: '0-59',
    optional: false,
    min: 0,
    max: 59,
  ),
  CronFieldCell(
    name: 'hour',
    index: 2,
    position: 3,
    total: 7,
    rangeCue: '0-23',
    optional: false,
    min: 0,
    max: 23,
  ),
  CronFieldCell(
    name: 'day-of-month',
    index: 3,
    position: 4,
    total: 7,
    rangeCue: '1-31, ?, L, LW, L-n, L-nW or nW',
    optional: false,
    min: 1,
    max: 31,
  ),
  CronFieldCell(
    name: 'month',
    index: 4,
    position: 5,
    total: 7,
    rangeCue: '1-12 or JAN-DEC',
    optional: false,
    min: 1,
    max: 12,
  ),
  CronFieldCell(
    name: 'day-of-week',
    index: 5,
    position: 6,
    total: 7,
    rangeCue: '1-7, ?, L, dL or d#n',
    optional: false,
    min: 1,
    max: 7,
  ),
  CronFieldCell(
    name: 'year',
    index: 6,
    position: 7,
    total: 7,
    rangeCue: '1970-2199',
    optional: true,
    min: 1970,
    max: 2199,
  ),
];

/// The ordered field-cell schema for [profile] in canonical cron order.
List<CronFieldCell> cronFieldCells(CronProfile profile) => switch (profile) {
  CronProfile.unix => _unixCells,
  CronProfile.quartz => _quartzCells,
};

/// The cell drafts that take part in the assembled expression: every cell
/// except an empty Quartz `year` cell (index 6), which is omitted so a
/// six-field Quartz draft stays clean. [cells] must have the schema length.
List<String> cronActiveCells(CronProfile profile, List<String> cells) =>
    profile == CronProfile.quartz && cells[6].isEmpty
    ? cells.sublist(0, 6)
    : cells;

/// Month and weekday names shared by the unix and quartz field grammars.
const cronMonthNames = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

const cronWeekdayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

/// The shared `*`/number/range/list/step field grammar used by every
/// non-special cron field in either profile. Returns the matched value set,
/// or null when the field text is not a valid expression for the given
/// bounds.
Set<int>? cronFieldValues(
  String field,
  int min,
  int max, [
  List<String> names = const [],
]) {
  int? number(String text) {
    final name = names.indexOf(text.toUpperCase());
    if (name >= 0) return min + name;
    if (!RegExp(r'^[0-9]+$').hasMatch(text)) return null;
    final value = int.tryParse(text);
    return value != null && value >= min && value <= max ? value : null;
  }

  final values = <int>{};
  for (final item in field.split(',')) {
    final parts = item.split('/');
    if (parts.length > 2 || parts.any((part) => part.isEmpty)) return null;
    final increment = parts.length == 2 ? int.tryParse(parts[1]) : 1;
    if (increment == null ||
        increment <= 0 ||
        increment > max - min + 1 ||
        (parts.length == 2 && !RegExp(r'^[0-9]+$').hasMatch(parts[1]))) {
      return null;
    }
    final range = parts[0].split('-');
    if (range.length > 2) return null;
    final first = range[0] == '*' ? min : number(range[0]);
    if (first == null || (range[0] == '*' && range.length > 1)) return null;
    final last = range.length == 2
        ? number(range[1])
        : parts.length == 2 || range[0] == '*'
        ? max
        : first;
    if (last == null) return null;
    final length = (last - first) % (max - min + 1);
    for (var offset = 0; offset <= length; offset += increment) {
      values.add(min + (first - min + offset) % (max - min + 1));
    }
  }
  return values.isEmpty ? null : values;
}

/// Unix field grammar for the field at [index] (0 minute .. 4 day-of-week),
/// mirroring the per-field checks of the free-form expression validator.
///
/// A bare `N/step` item (no `-` range, e.g. `5/15`) is rejected, matching the
/// pre-cell free-form validator exactly: Cronie's `N-max/step` shorthand was
/// never part of the unix accept surface, so cell entry keeps the same
/// accept/reject semantics. The shared [cronFieldValues] grammar used by the
/// quartz profile does accept the shorthand, as its validator always did.
bool unixCronFieldValid(String field, int index) {
  const min = [0, 0, 1, 1, 0];
  const max = [59, 23, 31, 12, 7];
  int? number(String text) {
    if (index == 3 && cronMonthNames.contains(text.toUpperCase())) {
      return cronMonthNames.indexOf(text.toUpperCase()) + 1;
    }
    if (index == 4 && cronWeekdayNames.contains(text.toUpperCase())) {
      return cronWeekdayNames.indexOf(text.toUpperCase());
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(text)) return null;
    return int.tryParse(text);
  }

  for (final item in field.split(',')) {
    final step = item.split('/');
    if (step.length > 2 ||
        (step.length == 2 &&
            (!RegExp(r'^[0-9]+$').hasMatch(step[1]) ||
                (int.tryParse(step[1]) ?? 0) <= 0))) {
      return false;
    }
    if (step[0] == '*') continue;
    final range = step[0].split('-');
    if (range.length > 2 || (step.length == 2 && range.length != 2)) {
      return false;
    }
    final first = number(range[0]);
    final last = range.length == 2 ? number(range[1]) : first;
    if (first == null ||
        last == null ||
        first < min[index] ||
        last > max[index] ||
        first > last) {
      return false;
    }
  }
  return true;
}

/// Quartz `day-of-month` specials: `?`, `L`, `LW`, `L-n`, `L-nW` and `nW`,
/// or an ordinary `1-31` field expression.
bool quartzCronDayOfMonthValid(String field) {
  if (field == '?') return true;
  final nearestWeekday = RegExp(r'^([0-9]+)W$').firstMatch(field);
  final weekdayDay = nearestWeekday == null
      ? null
      : int.tryParse(nearestWeekday.group(1)!);
  final lastOffset = RegExp(r'^L-([0-9]+)W?$').firstMatch(field);
  final offset = lastOffset == null ? null : int.tryParse(lastOffset.group(1)!);
  return field == 'L' ||
      field == 'LW' ||
      (offset != null && offset >= 1 && offset <= 30) ||
      (weekdayDay != null && weekdayDay >= 1 && weekdayDay <= 31) ||
      cronFieldValues(field, 1, 31) != null;
}

/// Quartz `day-of-week` specials: `?`, `L`, `dL` and `d#n`, or an ordinary
/// `1-7` field expression with `SUN`-`SAT` names.
bool quartzCronDayOfWeekValid(String field) {
  if (field == '?' || field == 'L') return true;
  final nthWeekday = RegExp(
    r'^(?:[1-7]|SUN|MON|TUE|WED|THU|FRI|SAT)#[1-5]$',
    caseSensitive: false,
  ).hasMatch(field);
  final lastWeekday = RegExp(
    r'^(?:[1-7]|SUN|MON|TUE|WED|THU|FRI|SAT)L$',
    caseSensitive: false,
  ).hasMatch(field);
  return nthWeekday ||
      lastWeekday ||
      cronFieldValues(field, 1, 7, cronWeekdayNames) != null;
}

/// Field-specific validation error for one cell draft, or null when the
/// draft is acceptable. An empty draft reports no error here; mandatory
/// emptiness is reported by [cronFieldCellsError] instead.
String? cronFieldCellError(CronProfile profile, int cellIndex, String draft) {
  if (draft.isEmpty) return null;
  final cells = cronFieldCells(profile);
  if (cellIndex < 0 || cellIndex >= cells.length) {
    throw ArgumentError.value(cellIndex, 'cellIndex');
  }
  final cell = cells[cellIndex];
  final valid = switch (profile) {
    CronProfile.unix => unixCronFieldValid(draft, cellIndex),
    CronProfile.quartz => switch (cellIndex) {
      0 => cronFieldValues(draft, 0, 59) != null,
      1 => cronFieldValues(draft, 0, 59) != null,
      2 => cronFieldValues(draft, 0, 23) != null,
      3 => quartzCronDayOfMonthValid(draft),
      4 => cronFieldValues(draft, 1, 12, cronMonthNames) != null,
      5 => quartzCronDayOfWeekValid(draft),
      _ => cronFieldValues(draft, 1970, 2199) != null,
    },
  };
  return valid ? null : "'${cell.name}' is invalid; expected ${cell.rangeCue}.";
}

String? _quartzDayExclusivityMessage(String dayOfMonth, String dayOfWeek) =>
    (dayOfMonth == '?') == (dayOfWeek == '?')
    ? 'quartz requires ? in exactly one of day-of-month or day-of-week '
          '(not both and not neither).'
    : null;

/// Ordered whole-draft validation over the cell list: first empty mandatory
/// cell, then first syntactically invalid populated cell, then the Quartz
/// `?` day-exclusivity rule, then the assembled length bound. Returns the
/// offending cell index and a field-specific message, or null when the draft
/// is acceptable.
({int index, String message})? cronFieldCellsError(
  CronProfile profile,
  List<String> cells,
) {
  final schema = cronFieldCells(profile);
  if (cells.length != schema.length) {
    return (
      index: 0,
      message:
          'expected ${schema.length} field cells for the ${profile.name} '
          'profile.',
    );
  }
  for (var i = 0; i < cells.length; i++) {
    if (cells[i].isEmpty && !schema[i].optional) {
      return (index: i, message: "'${schema[i].name}' is required.");
    }
  }
  for (var i = 0; i < cells.length; i++) {
    final error = cronFieldCellError(profile, i, cells[i]);
    if (error != null) return (index: i, message: error);
  }
  if (profile == CronProfile.quartz) {
    final message = _quartzDayExclusivityMessage(cells[3], cells[5]);
    if (message != null) return (index: 3, message: message);
  }
  if (cronActiveCells(profile, cells).join(' ').length >
      cronMaxExpressionLength) {
    return (
      index: cells.length - 1,
      message:
          'assembled expression exceeds $cronMaxExpressionLength UTF-16 '
          'code units.',
    );
  }
  return null;
}

/// Joins cell drafts verbatim with single ASCII spaces. The Quartz `year`
/// cell (index 6) is omitted when empty, producing a clean six-field
/// expression. Throws [ArgumentError] on a wrong cell count or when the
/// assembled expression exceeds [cronMaxExpressionLength] UTF-16 code units
/// including separators.
String cronAssembleExpression(CronProfile profile, List<String> cells) {
  final schema = cronFieldCells(profile);
  if (cells.length != schema.length) {
    throw ArgumentError.value(
      cells.length,
      'cells.length',
      'expected ${schema.length} field cells for the ${profile.name} profile',
    );
  }
  final expression = cronActiveCells(profile, cells).join(' ');
  if (expression.length > cronMaxExpressionLength) {
    throw ArgumentError.value(
      expression.length,
      'cells',
      'assembled expression exceeds $cronMaxExpressionLength UTF-16 code '
          'units',
    );
  }
  return expression;
}

/// Whole-expression validation identical to the free-form cron validator:
/// returns null when [value] is acceptable for [profile], else a message.
String? cronExpressionError(CronProfile profile, String value) {
  if (value.length > cronMaxExpressionLength) {
    return 'expression exceeds $cronMaxExpressionLength UTF-16 code units.';
  }
  if (value.trim() != value) {
    return 'expression must not have leading or trailing whitespace.';
  }
  final fields = value.split(RegExp(r' +'));
  if (profile == CronProfile.unix) {
    if (fields.length != 5) {
      return 'the unix profile requires exactly 5 fields.';
    }
  } else if (fields.length != 6 && fields.length != 7) {
    return 'the quartz profile requires 6 or 7 fields.';
  }
  for (var i = 0; i < fields.length; i++) {
    final error = cronFieldCellError(profile, i, fields[i]);
    if (error != null) return error;
  }
  if (profile == CronProfile.quartz) {
    final message = _quartzDayExclusivityMessage(fields[3], fields[5]);
    if (message != null) return message;
  }
  return null;
}

/// Splits a constructor `initialValue` into the ordered initial cell drafts.
///
/// An empty [initialValue] leaves every cell empty — never coerced to `*` or
/// `?`. A non-empty value must be a valid expression for [profile] (field
/// count, bounds, day rules and the length limit); anything else throws
/// [ArgumentError]. A valid Quartz six-field value leaves the `year` cell
/// empty.
List<String> cronInitialFieldCells(CronProfile profile, String initialValue) {
  final count = cronFieldCells(profile).length;
  if (initialValue.isEmpty) return List.filled(count, '');
  final error = cronExpressionError(profile, initialValue);
  if (error != null) {
    throw ArgumentError.value(initialValue, 'initialValue', error);
  }
  final fields = initialValue.split(RegExp(r' +'));
  if (profile == CronProfile.quartz && fields.length == 6) {
    return [...fields, ''];
  }
  return fields;
}
