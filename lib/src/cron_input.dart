part of 'text_input.dart';

/// Explicitly selected cron syntax profile.
enum CronProfile { unix, quartz }

/// The original expression and the profile used to interpret it.
final class CronExpression {
  CronExpression._(this.expression, this.profile);
  final String expression;
  final CronProfile profile;

  /// A bounded civil-time preview using timezone 0.11.2 / tzdata 2026e.
  /// Unix searches beginning with sub-minute offsets use second candidates.
  Future<CronPreview> preview(CronPreviewConfig config) async {
    final loaded = await _loadCronZone(config);
    final location = loaded.location;
    if (location == null) return CronPreview._(const [], loaded.status);
    if (profile == CronProfile.quartz &&
        (timezone.TZDateTime.from(config.start, location).year < 1970 ||
            timezone.TZDateTime.from(config.end, location).year > 2199)) {
      return CronPreview._(const [], CronPreviewStatus.unsupportedRange);
    }
    final fields = expression.split(RegExp(r' +'));
    final unixMatcher = profile == CronProfile.unix
        ? _compileUnix(fields)
        : null;
    final quartzFields = profile == CronProfile.quartz
        ? _compileQuartzFields(fields)
        : null;
    final referenceMicros = config.reference.microsecondsSinceEpoch;
    final startMicros = config.start.microsecondsSinceEpoch;
    final initialOffset = timezone.TZDateTime.from(
      config.start,
      location,
    ).timeZoneOffset;
    final hasSubMinuteOffset =
        initialOffset.inSeconds % 60 != 0 ||
        location.transitionAt.any(
          (at) =>
              at >= config.start.millisecondsSinceEpoch &&
              at <= config.end.millisecondsSinceEpoch &&
              location.timeZone(at).offset.inSeconds % 60 != 0,
        );
    final minuteMicros = profile == CronProfile.unix && !hasSubMinuteOffset
        ? Duration.microsecondsPerMinute
        : Duration.microsecondsPerSecond;
    final strictlyAfter =
        referenceMicros - referenceMicros % minuteMicros + minuteMicros;
    final startMinute =
        startMicros -
        startMicros % minuteMicros +
        (startMicros % minuteMicros == 0 ? 0 : minuteMicros);
    var instantMicros = strictlyAfter > startMinute
        ? strictlyAfter
        : startMinute;
    final endMicros = config.end.microsecondsSinceEpoch;
    final matches = <DateTime>[];
    var work = 0;
    while (instantMicros <= endMicros &&
        work < config.budget &&
        matches.length < config.count &&
        !config.isCancelled()) {
      final instant = DateTime.fromMicrosecondsSinceEpoch(
        instantMicros,
        isUtc: true,
      );
      final civil = timezone.TZDateTime.from(instant, location);
      if (profile == CronProfile.unix &&
          minuteMicros == Duration.microsecondsPerMinute &&
          civil.second != 0) {
        throw UnsupportedError(
          'Timezone offset changed to sub-minute precision.',
        );
      }
      final matchesExpression = profile == CronProfile.unix
          ? civil.second == 0 && unixMatcher!(civil)
          : _quartzMatches(fields, civil, quartzFields!);
      if (matchesExpression) matches.add(instant);
      work++;
      if (work % 1024 == 0) await Future<void>.delayed(Duration.zero);
      instantMicros += minuteMicros;
    }
    final status = config.isCancelled()
        ? CronPreviewStatus.cancelled
        : matches.length == config.count
        ? CronPreviewStatus.complete
        : instantMicros > endMicros
        ? CronPreviewStatus.horizonReached
        : CronPreviewStatus.budgetExhausted;
    return CronPreview._(List.unmodifiable(matches), status);
  }
}

void _cronProviderWorker((SendPort, String, void Function()?) request) {
  final (port, zone, initializer) = request;
  try {
    initializer?.call();
    timezone_data.initializeTimeZones();
    port.send(timezone.getLocation(zone));
  } catch (_) {
    port.send(null);
  }
}

Future<({timezone.Location? location, CronPreviewStatus status})> _loadCronZone(
  CronPreviewConfig config,
) async {
  final port = ReceivePort();
  final exitPort = ReceivePort();
  final exited = exitPort.first;
  final done =
      Completer<({timezone.Location? location, CronPreviewStatus status})>();
  Isolate? worker;
  void finish(timezone.Location? location, CronPreviewStatus status) {
    if (done.isCompleted) return;
    worker?.kill(priority: Isolate.immediate);
    done.complete((location: location, status: status));
  }

  final deadline = Timer(
    config.providerTimeout,
    () => finish(null, CronPreviewStatus.providerTimedOut),
  );
  final cancellation = Timer.periodic(const Duration(milliseconds: 10), (_) {
    if (config.isCancelled()) finish(null, CronPreviewStatus.cancelled);
  });
  final subscription = port.listen((message) {
    if (message is timezone.Location) {
      finish(message, CronPreviewStatus.complete);
    } else {
      finish(null, CronPreviewStatus.providerError);
    }
  }, onError: (_) => finish(null, CronPreviewStatus.providerError));
  try {
    final spawned =
        Isolate.spawn(
          _cronProviderWorker,
          (port.sendPort, config.zone, config.providerInitializer),
          onError: port.sendPort,
          onExit: exitPort.sendPort,
        ).then<Isolate?>(
          (isolate) {
            worker = isolate;
            if (done.isCompleted) isolate.kill(priority: Isolate.immediate);
            return isolate;
          },
          onError: (Object error, StackTrace stack) {
            finish(null, CronPreviewStatus.providerError);
            return null;
          },
        );
    final result = await done.future;
    final isolate = await spawned;
    if (isolate != null) {
      isolate.kill(priority: Isolate.immediate);
      await exited;
    }
    return result;
  } finally {
    deadline.cancel();
    cancellation.cancel();
    await subscription.cancel();
    port.close();
    exitPort.close();
    worker?.kill(priority: Isolate.immediate);
  }
}

const _quartzMonths = [
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

const _quartzWeekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

Set<int>? _quartzField(
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

List<Set<int>?> _compileQuartzFields(List<String> fields) {
  final dom = fields[3];
  final dow = fields[5].toUpperCase();
  return [
    _quartzField(fields[0], 0, 59),
    _quartzField(fields[1], 0, 59),
    _quartzField(fields[2], 0, 23),
    dom == '?' || dom.startsWith('L') || dom.endsWith('W')
        ? null
        : _quartzField(dom, 1, 31),
    _quartzField(fields[4], 1, 12, _quartzMonths),
    dow == '?' || dow.contains('#') || dow.endsWith('L')
        ? null
        : _quartzField(dow, 1, 7, _quartzWeekdays),
    fields.length == 7 ? _quartzField(fields[6], 1970, 2199) : null,
  ];
}

bool _quartzMatches(
  List<String> fields,
  DateTime civil,
  List<Set<int>?> compiled,
) {
  const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  int weekdayNumber(String text) {
    final name = weekdays.indexOf(text.toUpperCase());
    return name < 0 ? int.parse(text) : name + 1;
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
      final nearest = field.endsWith('W');
      final offset = int.parse(
        field.substring(2, nearest ? field.length - 1 : field.length),
      );
      final day = lastDay - offset;
      if (day < 1) return false;
      if (!nearest) return civil.day == day;
      final weekday = DateTime.utc(civil.year, civil.month, day).weekday;
      final target = weekday == 6
          ? (day == 1 ? day + 2 : day - 1)
          : weekday == 7
          ? (day == lastDay ? day - 2 : day + 1)
          : day;
      return civil.day == target;
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
    return compiled[3]!.contains(civil.day);
  }

  bool dayOfWeek() {
    final field = fields[5].toUpperCase();
    if (field == '?' || field == '*') return true;
    final weekday = civil.weekday % 7 + 1;
    if (field == 'L') return weekday == 7;
    if (field.contains('#')) {
      final parts = field.split('#');
      return weekday == weekdayNumber(parts[0]) &&
          (civil.day - 1) ~/ 7 + 1 == int.parse(parts[1]);
    }
    if (field.endsWith('L')) {
      return weekday == weekdayNumber(field.substring(0, field.length - 1)) &&
          civil.day + 7 > lastDay;
    }
    return compiled[5]!.contains(weekday);
  }

  return compiled[0]!.contains(civil.second) &&
      compiled[1]!.contains(civil.minute) &&
      compiled[2]!.contains(civil.hour) &&
      dayOfMonth() &&
      compiled[4]!.contains(civil.month) &&
      dayOfWeek() &&
      (fields.length == 6 || compiled[6]!.contains(civil.year));
}

bool Function(DateTime) _compileUnix(List<String> fields) {
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
  Set<int> parse(String field, int min, int max, List<String> names) {
    int number(String text) {
      final index = names.indexOf(text.toUpperCase());
      return index < 0 ? int.parse(text) : index + min;
    }

    final values = <int>{};
    for (final item in field.split(',')) {
      final step = item.split('/');
      final increment = step.length == 2 ? int.parse(step[1]) : 1;
      final range = step[0].split('-');
      final first = range[0] == '*' ? min : number(range[0]);
      final last = range[0] == '*'
          ? max
          : range.length == 2
          ? number(range[1])
          : first;
      var value = first;
      while (value <= last) {
        values.add(value);
        if (increment > last - value) break;
        value += increment;
      }
    }
    return values;
  }

  final minutes = parse(fields[0], 0, 59, const []);
  final hours = parse(fields[1], 0, 23, const []);
  final dom = parse(fields[2], 1, 31, const []);
  final month = parse(fields[3], 1, 12, months);
  final dow = parse(fields[4], 0, 7, weekdays);
  final dayAnd = fields[2].startsWith('*') || fields[4].startsWith('*');
  return (civil) {
    final dayOfMonth = dom.contains(civil.day);
    final weekday = civil.weekday % 7;
    final dayOfWeek =
        dow.contains(weekday) || (weekday == 0 && dow.contains(7));
    return minutes.contains(civil.minute) &&
        hours.contains(civil.hour) &&
        month.contains(civil.month) &&
        (dayAnd ? dayOfMonth && dayOfWeek : dayOfMonth || dayOfWeek);
  };
}

/// All instants are explicit UTC values. The work budget counts candidates.
final class CronPreviewConfig {
  /// Maximum zone identifier length in UTF-16 code units.
  static const maxZoneLength = 255;

  CronPreviewConfig({
    required this.zone,
    required this.reference,
    required this.start,
    required this.end,
    required this.count,
    required this.budget,
    required this.providerTimeout,
    this.providerInitializer,
    this.isCancelled = _neverCancelled,
  }) {
    if (zone.isEmpty ||
        zone.length > maxZoneLength ||
        !reference.isUtc ||
        !start.isUtc ||
        !end.isUtc ||
        end.isBefore(start) ||
        count <= 0 ||
        budget <= 0 ||
        providerTimeout <= Duration.zero) {
      throw ArgumentError('Invalid preview configuration.');
    }
  }
  final String zone;
  final DateTime reference;
  final DateTime start;
  final DateTime end;
  final int count;
  final int budget;

  /// Maximum provider initialization time; the worker isolate is killed on expiry.
  final Duration providerTimeout;

  /// Optional isolate-safe hook invoked before provider initialization.
  /// Useful for provider setup and testing. It must be transferable to an isolate.
  final void Function()? providerInitializer;
  final bool Function() isCancelled;
}

bool _neverCancelled() => false;

enum CronPreviewStatus {
  complete,
  horizonReached,
  budgetExhausted,
  cancelled,
  providerError,
  providerTimedOut,
  unsupportedRange,
}

final class CronPreview {
  CronPreview._(this.instants, this.status);
  final List<DateTime> instants;
  final CronPreviewStatus status;
}

/// Cron expression entry with explicitly configured optional matching preview.
/// Quartz syntax and provider behavior are not yet fully qualified.
final class CronInput {
  /// Maximum expression length in UTF-16 code units.
  static const maxExpressionLength = 4096;

  CronInput(
    this.label, {
    required this.profile,
    this.initialValue = '',
    this.preview,
  }) {
    _input = TextInput(
      '$label (${profile.name} profile; expression limit $maxExpressionLength UTF-16 code units; matching preview is not configured)',
      initialValue: initialValue,
      required: true,
      maxLength: maxExpressionLength,
      validate: (value) => _valid(value)
          ? null
          : 'Invalid or unsupported cron expression for the selected profile.',
    );
  }
  final String label;
  final String initialValue;
  final CronPreviewConfig? preview;
  final CronProfile profile;
  late final TextInput _input;
  bool _active = false;

  bool _valid(String value) {
    if (value.length > maxExpressionLength || value.trim() != value) {
      return false;
    }
    if (profile == CronProfile.quartz) {
      final fields = value.split(RegExp(r' +'));
      if (fields.length != 6 && fields.length != 7) return false;
      if ((fields[3] == '?') == (fields[5] == '?')) return false;
      if (_quartzField(fields[0], 0, 59) == null ||
          _quartzField(fields[1], 0, 59) == null ||
          _quartzField(fields[2], 0, 23) == null ||
          _quartzField(fields[4], 1, 12, _quartzMonths) == null ||
          (fields.length == 7 && _quartzField(fields[6], 1970, 2199) == null)) {
        return false;
      }
      final nearestWeekday = RegExp(r'^([0-9]+)W$').firstMatch(fields[3]);
      final weekdayDay = nearestWeekday == null
          ? null
          : int.tryParse(nearestWeekday.group(1)!);
      final lastOffset = RegExp(r'^L-([0-9]+)W?$').firstMatch(fields[3]);
      final offset = lastOffset == null
          ? null
          : int.tryParse(lastOffset.group(1)!);
      if (fields[3] != '?' &&
          !(offset != null && offset >= 1 && offset <= 30) &&
          fields[3] != 'L' &&
          fields[3] != 'LW' &&
          !(weekdayDay != null && weekdayDay >= 1 && weekdayDay <= 31) &&
          _quartzField(fields[3], 1, 31) == null) {
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
          fields[5] != 'L' &&
          !nthWeekday &&
          !lastWeekday &&
          _quartzField(fields[5], 1, 7, _quartzWeekdays) == null) {
        return false;
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
    final config = preview;
    if (config != null && source is! SuppliedAnswer) {
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
            return await _terminal<CronExpression>(
              selected,
              output ?? stderr,
              (source, mode, restore) =>
                  _runPreview(source, mode, config, beforeClose: restore),
            );
          } finally {
            _terminalActive = false;
          }
        }
        return await _runPreview(source, selected, config);
      } finally {
        _active = false;
      }
    }
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

  Future<PromptResult<CronExpression>> _runPreview(
    PromptSource source,
    PromptMode mode,
    CronPreviewConfig config, {
    void Function()? beforeClose,
  }) async {
    if (source is! ScriptedInput) {
      return Unavailable('Unsupported cron input source.');
    }
    if (mode == PromptMode.rich && !source.supportsRich) {
      return Unavailable('Rich interaction unavailable.');
    }
    final linear =
        mode == PromptMode.linear ||
        (mode == PromptMode.automatic && !source.supportsRich);
    final out = source.output;
    final keys = _Keys(source.input.transform(utf8.encoder));
    var draft = initialValue;
    out.writeln(
      '$label. ${profile.name} profile. Expression limit $maxExpressionLength UTF-16 code units. Enter an expression, then /preview, /edit or /submit; /cancel cancels.',
    );
    try {
      while (true) {
        final entry = await _edit(
          keys,
          draft,
          out,
          linear: linear,
          sequential: linear,
          maxLength: maxExpressionLength,
        );
        if (entry.action == 'cancel') return Cancelled();
        if (entry.action == 'interrupt') return Interrupted();
        if (entry.action != 'submit') return InputEnded();
        draft = entry.value;
        if (!_valid(draft)) {
          out.writeln('Invalid cron expression. Correct the retained draft.');
          continue;
        }
        out.writeln('Review: $draft. /preview, /edit, or /submit.');
        var focus = 0;
        const actions = ['Edit', 'Preview', 'Submit'];
        if (!linear) {
          out.writeln(
            'Review action: Edit. Tab or Shift-Tab changes action; Enter activates.',
          );
        }
        while (true) {
          final action = await _edit(
            keys,
            '',
            out,
            linear: true,
            sequential: linear,
            extraCommands: const {'/preview', '/edit', '/submit'},
            intercept: linear
                ? null
                : (key, text) {
                    if (key == '\t' || key == '\x1b[Z' || key == '\x02') {
                      focus = (focus + (key == '\t' ? 1 : 2)) % actions.length;
                      out.writeln('Review action: ${actions[focus]}.');
                      return 'handled';
                    }
                    if ((key == '\r' || key == '\n') && text.isEmpty) {
                      return 'review-${actions[focus].toLowerCase()}';
                    }
                    return null;
                  },
          );
          if (action.action == 'cancel') return Cancelled();
          if (action.action == 'interrupt') return Interrupted();
          if (action.action == 'eof') return InputEnded();
          if (action.action == 'review-edit' ||
              (action.action == 'command' && action.value == '/edit')) {
            break;
          }
          if (action.action == 'review-submit' ||
              (action.action == 'command' && action.value == '/submit')) {
            return Accepted(CronExpression._(draft, profile));
          }
          if (action.action == 'review-preview' ||
              (action.action == 'command' && action.value == '/preview')) {
            var interrupted = false;
            var cancelled = false;
            var line = '';
            keys.onKey = (key) {
              if (key == '\x03') {
                interrupted = true;
                return true;
              }
              if (!linear && key == '\x1b') {
                cancelled = true;
                return true;
              }
              if (linear) {
                if (key == '\r' || key == '\n') {
                  if (line == '/cancel') cancelled = true;
                  line = '';
                } else if (line.length < 16) {
                  line += key;
                }
                // While a linear preview is active, only /cancel is meaningful.
                // Do not leak the cancelled command or other keystrokes into
                // the review editor that resumes after the preview.
                return true;
              }
              return false;
            };
            out.writeln(
              'Calculating preview; Ctrl+C interrupts${linear ? ', /cancel cancels' : ', Escape cancels'}.',
            );
            final cancellable = CronPreviewConfig(
              zone: config.zone,
              reference: config.reference,
              start: config.start,
              end: config.end,
              count: config.count,
              budget: config.budget,
              providerTimeout: config.providerTimeout,
              providerInitializer: config.providerInitializer,
              isCancelled: () =>
                  interrupted || cancelled || config.isCancelled(),
            );
            late final CronPreview result;
            try {
              result = await CronExpression._(
                draft,
                profile,
              ).preview(cancellable);
            } finally {
              keys.onKey = null;
            }
            if (interrupted) return Interrupted();
            out.writeln(
              'Matching preview: ${result.status.name}; zone ${config.zone}; timezone 0.11.2 / tzdata 2026e; strictly after ${config.reference.toIso8601String()}; bounds ${config.start.toIso8601String()} to ${config.end.toIso8601String()}; count ${config.count}; budget ${config.budget}; provider timeout ${config.providerTimeout}; gaps skipped, folds included; not scheduler execution.',
            );
            for (final instant in result.instants) {
              out.writeln(instant);
            }
            if (!linear) {
              // Review state must never be implicit after a preview round: keep
              // the reviewer's action position and announce it again.
              out.writeln('Review action: ${actions[focus]}.');
            }
            continue;
          }
          out.writeln('Use /preview, /edit, or /submit.');
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
