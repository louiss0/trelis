part of 'text_input.dart';

/// Explicitly selected cron syntax profile.
enum CronProfile { unix, quartz }

/// The original expression and the profile used to interpret it.
final class CronExpression {
  CronExpression._(this.expression, this.profile);
  final String expression;
  final CronProfile profile;

  /// A bounded preview. At present only the UTC Unix every-minute expression
  /// is implemented; other schedules fail closed rather than return guesses.
  Future<CronPreview> preview(CronPreviewConfig config) async {
    if (profile != CronProfile.unix ||
        expression != '* * * * *' ||
        config.zone != 'Etc/UTC') {
      throw UnsupportedError(
        'Preview is not supported for this expression or zone.',
      );
    }
    final referenceMicros = config.reference.microsecondsSinceEpoch;
    final startMicros = config.start.microsecondsSinceEpoch;
    const minuteMicros = Duration.microsecondsPerMinute;
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
        matches.length < config.count) {
      matches.add(instant);
      work++;
      instant = instant.add(const Duration(minutes: 1));
    }
    return CronPreview(List.unmodifiable(matches));
  }
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
}

final class CronPreview {
  CronPreview(this.instants);
  final List<DateTime> instants;
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
