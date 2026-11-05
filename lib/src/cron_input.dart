part of 'text_input.dart';

/// Explicitly selected cron syntax profile.
enum CronProfile { unix, quartz }

/// The original expression and the profile used to interpret it.
final class CronExpression {
  CronExpression._(this.expression, this.profile);
  final String expression;
  final CronProfile profile;

  /// A bounded civil-time preview using timezone 0.11.2 / tzdata 2025c.
  /// Unix searches beginning with sub-minute offsets use second candidates.
  Future<CronPreview> preview(CronPreviewConfig config) async {
    late final timezone.Location location;
    try {
      timezone_data.initializeTimeZones();
      location = timezone.getLocation(config.zone);
    } on timezone.LocationNotFoundException {
      return CronPreview._(const [], CronPreviewStatus.providerError);
    }
    if (profile == CronProfile.quartz &&
        (timezone.TZDateTime.from(config.start, location).year < 1970 ||
            timezone.TZDateTime.from(config.end, location).year > 2199)) {
      return CronPreview._(const [], CronPreviewStatus.unsupportedRange);
    }
    final fields = expression.split(RegExp(r' +'));
    final referenceMicros = config.reference.microsecondsSinceEpoch;
    final startMicros = config.start.microsecondsSinceEpoch;
    final initialOffset = timezone.TZDateTime.from(
      config.start,
      location,
    ).timeZoneOffset;
    final minuteMicros =
        profile == CronProfile.unix && initialOffset.inSeconds % 60 == 0
        ? Duration.microsecondsPerMinute
        : Duration.microsecondsPerSecond;
    final strictlyAfter =
        referenceMicros - referenceMicros % minuteMicros + minuteMicros;
    final startMinute =
        startMicros -
        startMicros % minuteMicros +
        (startMicros % minuteMicros == 0 ? 0 : minuteMicros);
    var instant = DateTime.fromMicrosecondsSinceEpoch(
      strictlyAfter > startMinute ? strictlyAfter : startMinute,
      isUtc: true,
    );
    final matches = <DateTime>[];
    var work = 0;
    while (!instant.isAfter(config.end) &&
        work < config.budget &&
        matches.length < config.count &&
        !config.isCancelled()) {
      final civil = timezone.TZDateTime.from(instant, location);
      if (profile == CronProfile.unix &&
          minuteMicros == Duration.microsecondsPerMinute &&
          civil.second != 0) {
        throw UnsupportedError(
          'Timezone offset changed to sub-minute precision.',
        );
      }
      final matchesExpression = profile == CronProfile.unix
          ? civil.second == 0 && _unixMatches(fields, civil)
          : _quartzMatches(fields, civil);
      if (matchesExpression) matches.add(instant);
      work++;
      if (work % 1024 == 0) await Future<void>.delayed(Duration.zero);
      instant = instant.add(Duration(microseconds: minuteMicros));
    }
    final status = config.isCancelled()
        ? CronPreviewStatus.cancelled
        : matches.length == config.count
        ? CronPreviewStatus.complete
        : instant.isAfter(config.end)
        ? CronPreviewStatus.horizonReached
        : CronPreviewStatus.budgetExhausted;
    return CronPreview._(List.unmodifiable(matches), status);
  }
}

bool _quartzMatches(List<String> fields, DateTime civil) {
  const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  int weekdayNumber(String text) {
    final name = weekdays.indexOf(text.toUpperCase());
    return name < 0 ? int.parse(text) : name + 1;
  }

  bool numeric(String field, int value) {
    if (field == '*') return true;
    for (final item in field.split(',')) {
      if (item.contains('/')) {
        final parts = item.split('/');
        final first = int.parse(parts[0]);
        final step = int.parse(parts[1]);
        if (value >= first && (value - first) % step == 0) return true;
        continue;
      }
      final range = item.split('-');
      final first = int.parse(range[0]);
      final last = range.length == 1 ? first : int.parse(range[1]);
      if (value >= first && value <= last) return true;
    }
    return false;
  }

  final lastDay = DateTime.utc(civil.year, civil.month + 1, 0).day;
  bool dayOfMonth() {
    final field = fields[3];
    if (field == '?') return true;
    if (field == 'L') return civil.day == lastDay;
    if (field == 'LW') {
      final lastWeekday = DateTime.utc(
        civil.year,
        civil.month,
        lastDay,
      ).weekday;
      final day =
          lastDay -
          (lastWeekday == 6
              ? 1
              : lastWeekday == 7
              ? 2
              : 0);
      return civil.day == day;
    }
    if (field.startsWith('L-')) {
      return civil.day == lastDay - int.parse(field.substring(2));
    }
    if (field.endsWith('W')) {
      final day = int.parse(field.substring(0, field.length - 1));
      if (day > lastDay) return false;
      final weekday = DateTime.utc(civil.year, civil.month, day).weekday;
      final nearest = weekday == 6
          ? (day == 1 ? day + 2 : day - 1)
          : weekday == 7
          ? (day == lastDay ? day - 2 : day + 1)
          : day;
      return civil.day == nearest;
    }
    return numeric(field, civil.day);
  }

  bool dayOfWeek() {
    final field = fields[5].toUpperCase();
    if (field == '?' || field == '*') return true;
    final weekday = civil.weekday % 7 + 1;
    if (field.contains('#')) {
      final parts = field.split('#');
      return weekday == weekdayNumber(parts[0]) &&
          (civil.day - 1) ~/ 7 + 1 == int.parse(parts[1]);
    }
    if (field.endsWith('L')) {
      return weekday == weekdayNumber(field.substring(0, field.length - 1)) &&
          civil.day + 7 > lastDay;
    }
    return weekday == weekdayNumber(field);
  }

  return numeric(fields[0], civil.second) &&
      numeric(fields[1], civil.minute) &&
      numeric(fields[2], civil.hour) &&
      dayOfMonth() &&
      numeric(fields[4], civil.month) &&
      dayOfWeek() &&
      (fields.length == 6 || numeric(fields[6], civil.year));
}

bool _unixMatches(List<String> fields, DateTime civil) {
  const months = [
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
  const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  bool contains(
    String field,
    int value,
    int min,
    int max,
    List<String> names, {
    bool sunday = false,
  }) {
    int number(String text) {
      final name = names.indexOf(text.toUpperCase());
      return name >= 0 ? name + min : int.parse(text);
    }

    bool matches(int v) {
      for (final item in field.split(',')) {
        final stepParts = item.split('/');
        final step = stepParts.length == 2 ? int.parse(stepParts[1]) : 1;
        final range = stepParts[0].split('-');
        final first = range[0] == '*' ? min : number(range[0]);
        final last = range[0] == '*'
            ? max
            : range.length == 2
            ? number(range[1])
            : first;
        if (v >= first && v <= last && (v - first) % step == 0) return true;
      }
      return false;
    }

    return matches(value) || (sunday && value == 0 && matches(7));
  }

  final dom = contains(fields[2], civil.day, 1, 31, const []);
  final dow = contains(
    fields[4],
    civil.weekday % 7,
    0,
    7,
    weekdays,
    sunday: true,
  );
  final days = fields[2].startsWith('*') || fields[4].startsWith('*')
      ? dom && dow
      : dom || dow;
  return contains(fields[0], civil.minute, 0, 59, const []) &&
      contains(fields[1], civil.hour, 0, 23, const []) &&
      days &&
      contains(fields[3], civil.month, 1, 12, months);
}

/// All instants are explicit UTC values. The work budget counts candidates.
final class CronPreviewConfig {
  CronPreviewConfig({
    required this.zone,
    required this.reference,
    required this.start,
    required this.end,
    required this.count,
    required this.budget,
    this.isCancelled = _neverCancelled,
  }) {
    if (zone.isEmpty ||
        !reference.isUtc ||
        !start.isUtc ||
        !end.isUtc ||
        end.isBefore(start) ||
        count <= 0 ||
        budget <= 0) {
      throw ArgumentError('Invalid preview configuration.');
    }
  }
  final String zone;
  final DateTime reference;
  final DateTime start;
  final DateTime end;
  final int count;
  final int budget;
  final bool Function() isCancelled;
}

bool _neverCancelled() => false;

enum CronPreviewStatus {
  complete,
  horizonReached,
  budgetExhausted,
  cancelled,
  providerError,
  unsupportedRange,
}

final class CronPreview {
  CronPreview._(this.instants, this.status);
  final List<DateTime> instants;
  final CronPreviewStatus status;
}

/// Cron expression entry. The current implementation only supports a subset of
/// Unix and Quartz syntax; preview is not yet implemented.
final class CronInput {
  CronInput(String label, {required this.profile, String initialValue = ''}) {
    _input = TextInput(
      '$label (Unix five fields: minute 0-59, hour 0-23, day 1-31, month 1-12, weekday 0-7; numeric lists, ranges and steps, month and weekday names; Quartz basic subset only; preview unavailable)',
      initialValue: initialValue,
      required: true,
      validate: (value) => _valid(value)
          ? null
          : 'Invalid or unsupported cron expression for the selected profile.',
    );
  }
  final CronProfile profile;
  late final TextInput _input;

  bool _valid(String value) {
    if (value.trim() != value) return false;
    if (profile == CronProfile.quartz) {
      final fields = value.split(RegExp(r' +'));
      if (fields.length != 6 && fields.length != 7) return false;
      if ((fields[3] == '?') == (fields[5] == '?')) return false;
      final numeric = RegExp(r'^(?:\*|[0-9]+)$');
      const minimum = [0, 0, 0, 1, 1, 1, 1970];
      const maximum = [59, 59, 23, 31, 12, 7, 2199];
      for (final i in [0, 1, 2, 4]) {
        if (i == 0 && RegExp(r'^[0-9]+/[0-9]+$').hasMatch(fields[i])) {
          final parts = fields[i].split('/').map(int.tryParse).toList();
          if (parts[0] == null ||
              parts[1] == null ||
              parts[0]! > 59 ||
              parts[1]! <= 0 ||
              parts[1]! > 59) {
            return false;
          }
          continue;
        }
        if (i == 0 && fields[i].contains(',')) {
          final values = fields[i].split(',');
          if (values.any(
            (part) =>
                !RegExp(r'^[0-9]+$').hasMatch(part) ||
                (int.tryParse(part) ?? 60) > 59,
          )) {
            return false;
          }
          continue;
        }
        if (RegExp(r'^[0-9]+-[0-9]+$').hasMatch(fields[i])) {
          final bounds = fields[i].split('-').map(int.tryParse).toList();
          if (bounds[0] == null ||
              bounds[1] == null ||
              bounds[0]! < minimum[i] ||
              bounds[0]! > bounds[1]! ||
              bounds[1]! > maximum[i]) {
            return false;
          }
          continue;
        }
        if (!numeric.hasMatch(fields[i])) return false;
      }
      final nearestWeekday = RegExp(r'^([0-9]+)W$').firstMatch(fields[3]);
      final weekdayDay = nearestWeekday == null
          ? null
          : int.tryParse(nearestWeekday.group(1)!);
      final lastOffset = RegExp(r'^L-([0-9]+)$').firstMatch(fields[3]);
      final offset = lastOffset == null
          ? null
          : int.tryParse(lastOffset.group(1)!);
      if (fields[3] != '?' &&
          !(offset != null && offset >= 1 && offset <= 30) &&
          fields[3] != 'L' &&
          fields[3] != 'LW' &&
          !(weekdayDay != null && weekdayDay >= 1 && weekdayDay <= 31) &&
          !numeric.hasMatch(fields[3])) {
        return false;
      }
      final nthWeekday = RegExp(
        r'^(?:[1-7]|SUN|MON|TUE|WED|THU|FRI|SAT)#[1-5]$',
        caseSensitive: false,
      ).hasMatch(fields[5]);
      final lastWeekday = RegExp(
        r'^(?:[1-7]|SUN|MON|TUE|WED|THU|FRI|SAT)L$',
        caseSensitive: false,
      ).hasMatch(fields[5]);
      if (fields[5] != '?' &&
          !nthWeekday &&
          !lastWeekday &&
          !RegExp(
            r'^(?:\*|[1-7]|SUN|MON|TUE|WED|THU|FRI|SAT)$',
            caseSensitive: false,
          ).hasMatch(fields[5])) {
        return false;
      }
      if (fields.length == 7 && !numeric.hasMatch(fields[6])) return false;
      for (var i = 0; i < fields.length; i++) {
        final n = int.tryParse(fields[i]);
        if (n != null && (n < minimum[i] || n > maximum[i])) return false;
      }
      return true;
    }
    final fields = value.split(RegExp(r' +'));
    if (fields.length != 5) return false;
    const min = [0, 0, 1, 1, 0];
    const max = [59, 23, 31, 12, 7];
    const months = [
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
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    int? number(String text, int index) {
      if (index == 3 && months.contains(text.toUpperCase())) {
        return months.indexOf(text.toUpperCase()) + 1;
      }
      if (index == 4 && days.contains(text.toUpperCase())) {
        return days.indexOf(text.toUpperCase());
      }
      if (!RegExp(r'^[0-9]+$').hasMatch(text)) return null;
      return int.tryParse(text);
    }

    for (var i = 0; i < fields.length; i++) {
      for (final item in fields[i].split(',')) {
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
        final first = number(range[0], i);
        final last = range.length == 2 ? number(range[1], i) : first;
        if (first == null ||
            last == null ||
            first < min[i] ||
            last > max[i] ||
            first > last) {
          return false;
        }
      }
    }
    return true;
  }

  Future<PromptResult<CronExpression>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    final result = await _input.prompt(
      source: source,
      mode: mode,
      userPreference: userPreference,
      applicationPreference: applicationPreference,
      output: output,
    );
    if (result is Accepted<String>) {
      return Accepted(CronExpression._(result.value, profile));
    }
    if (result is Cancelled<String>) return Cancelled();
    if (result is Interrupted<String>) return Interrupted();
    if (result is InputEnded<String>) return InputEnded();
    return Unavailable((result as Unavailable<String>).reason);
  }
}
