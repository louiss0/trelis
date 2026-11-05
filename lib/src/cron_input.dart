part of 'text_input.dart';

/// Explicitly selected cron syntax profile.
enum CronProfile { unix, quartz }

/// The original expression and the profile used to interpret it.
final class CronExpression {
  CronExpression._(this.expression, this.profile);
  final String expression;
  final CronProfile profile;
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
      for (final i in [0, 1, 2, 4]) {
        if (!numeric.hasMatch(fields[i])) return false;
      }
      if (fields[3] != '?' && fields[3] != 'L' && !numeric.hasMatch(fields[3]))
        return false;
      if (fields[5] != '?' &&
          !RegExp(
            r'^(?:\*|[1-7]|SUN|MON|TUE|WED|THU|FRI|SAT)$',
            caseSensitive: false,
          ).hasMatch(fields[5])) {
        return false;
      }
      if (fields.length == 7 && !numeric.hasMatch(fields[6])) return false;
      const minimum = [0, 0, 0, 1, 1, 1, 1970];
      const maximum = [59, 59, 23, 31, 12, 7, 2199];
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
