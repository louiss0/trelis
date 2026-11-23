part of 'text_input.dart';

/// Explicitly selected cron syntax profile.
enum CronProfile { unix, quartz }

/// The original expression and the profile used to interpret it.
final class CronExpression {
  CronExpression._(this.expression, this.profile);
  final String expression;
  final CronProfile profile;

  /// A bounded civil-time preview using the qualified provider snapshot
  /// (timezone 0.11.2 / tzdata 2026e). Unix searches beginning with sub-minute
  /// offsets use second candidates.
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

List<Set<int>?> _compileQuartzFields(List<String> fields) {
  final dom = fields[3];
  final dow = fields[5].toUpperCase();
  return [
    quartzCronField(fields[0], 0, 59),
    quartzCronField(fields[1], 0, 59),
    quartzCronField(fields[2], 0, 23),
    dom == '?' || dom.startsWith('L') || dom.endsWith('W')
        ? null
        : quartzCronField(dom, 1, 31),
    quartzCronField(fields[4], 1, 12, quartzCronMonths),
    dow == '?' || dow.contains('#') || dow.endsWith('L')
        ? null
        : quartzCronField(dow, 1, 7, quartzCronWeekdays),
    fields.length == 7 ? quartzCronField(fields[6], 1970, 2199) : null,
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
extension type CronPreviewConfig._(
  ({
    String zone,
    DateTime reference,
    DateTime start,
    DateTime end,
    int count,
    int budget,
    Duration providerTimeout,
    void Function()? providerInitializer,
    bool Function() isCancelled,
  })
  _value,
) {
  /// Maximum zone identifier length in UTF-16 code units.
  static const maxZoneLength = 255;

  factory CronPreviewConfig({
    required String zone,
    required DateTime reference,
    required DateTime start,
    required DateTime end,
    required int count,
    required int budget,
    required Duration providerTimeout,
    void Function()? providerInitializer,
    bool Function() isCancelled = _neverCancelled,
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
    return CronPreviewConfig._((
      zone: zone,
      reference: reference,
      start: start,
      end: end,
      count: count,
      budget: budget,
      providerTimeout: providerTimeout,
      providerInitializer: providerInitializer,
      isCancelled: isCancelled,
    ));
  }

  String get zone => _value.zone;
  DateTime get reference => _value.reference;
  DateTime get start => _value.start;
  DateTime get end => _value.end;
  int get count => _value.count;
  int get budget => _value.budget;

  /// Maximum provider initialization time; the worker isolate is killed on expiry.
  Duration get providerTimeout => _value.providerTimeout;

  /// Optional isolate-safe hook invoked before provider initialization.
  /// Useful for provider setup and testing. It must be transferable to an isolate.
  void Function()? get providerInitializer => _value.providerInitializer;
  bool Function() get isCancelled => _value.isCancelled;
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
  static const maxExpressionLength = cronMaxExpressionLength;

  CronInput(
    this.label, {
    required this.profile,
    this.initialValue = '',
    this.preview,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    // A non-empty initialValue must be a valid expression for the selected
    // profile; valid values split into the initial field cells that every
    // prompt run resets to.
    _initialFieldCells = cronInitialFieldCells(profile, initialValue);
    _initialDraft = _initialFieldCells.every((cell) => cell.isEmpty)
        ? ''
        : cronAssembleExpression(profile, _initialFieldCells);
    _input = TextInput(
      '$label (${profile.name} profile; expression limit $maxExpressionLength UTF-16 code units; matching preview is not configured)',
      initialValue: _initialDraft,
      required: true,
      maxLength: maxExpressionLength,
      validate: (value) => _valid(value)
          ? null
          : 'Invalid or unsupported cron expression for the selected profile.',
      colors: colors,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    );
  }
  final String label;
  final String initialValue;
  final CronPreviewConfig? preview;
  final CronProfile profile;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  late final TextInput _input;

  /// Initial field-cell drafts split from [initialValue]; every prompt run
  /// resets the cells to these values.
  late final List<String> _initialFieldCells;

  /// The single-space-joined initial draft seeded into each prompt run.
  late final String _initialDraft;
  bool _active = false;

  /// Minimal active-format cue: the field shape of the declared dialect.
  String get _fieldShape => profile == CronProfile.unix
      ? 'five fields: minute hour day-of-month month day-of-week'
      : 'six fields: second minute hour day-of-month month day-of-week, plus an optional seventh year field (1970-2199)';

  String get _syntaxNote => profile == CronProfile.unix
      ? 'Fields accept *, a number, an a-b range, an a,b list, a /n step, and JAN-DEC or SUN-SAT names; 0 and 7 both select Sunday, and a stepped wildcard day still pairs with the weekday field.'
      : 'Fields accept *, a number, an a-b range, an a,b list, a /n step and names; exactly one of day-of-month and day-of-week must be ?, and L, LW, L-n, nW, nth-weekday # and weekday L keep their documented meaning.';

  String get _limitNote =>
      'A valid expression is at most $maxExpressionLength UTF-16 code units, carries no leading or trailing space, and is validated for the selected profile before review; a rejected draft stays available for correction and later submission.';

  String get _previewNote {
    final config = preview;
    if (config == null) {
      return 'No matching preview is configured, so review covers only the expression and its declared profile.';
    }
    return 'The matching preview is a bounded set of matching civil instants for zone ${config.zone} between ${config.start.toIso8601String()} and ${config.end.toIso8601String()}, limited to ${config.count} instants, a work budget of ${config.budget} candidates and a provider timeout of ${config.providerTimeout}, interpreted from the qualified provider snapshot. It is a matching preview, not scheduler execution: it does not promise that a job runs then, gaps are skipped and folds are included.';
  }

  String _entryHelp({required bool linear}) {
    final controls = linear
        ? r'Type the expression and press Enter to review it. Exact /help and /cancel are commands; quote a command with a backslash and double a leading backslash. Identified paste is literal; unframed paste cannot be distinguished from typing.'
        : 'Type to edit; Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter reviews the draft. Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.';
    return 'Help: Entering the expression for the ${profile.name} profile, $_fieldShape. $controls $_limitNote $_syntaxNote $_previewNote';
  }

  String _reviewHelp({required bool linear}) {
    final controls = linear
        ? r'/preview computes the bounded matching preview, /edit returns to the expression and /submit accepts the retained expression; a /cancel during a preview stops only that preview, and a second /cancel ends the prompt. Exact /help and /cancel are commands; quote a command with a backslash and double a leading backslash. Identified paste is literal.'
        : 'The actions are Edit, Preview and Submit; Tab or Shift-Tab changes the focused action, Enter activates it and the focused action is announced after every change. Preview is interruptible with Ctrl+C; Escape cancels the prompt and Ctrl+C interrupts it.';
    return 'Help: Reviewing the retained expression for the ${profile.name} profile, $_fieldShape. $controls $_syntaxNote $_previewNote';
  }

  bool _valid(String value) => cronExpressionError(profile, value) == null;

  /// Whether cell [index] takes part in the assembled expression. Every Unix
  /// cell is mandatory; in Quartz the optional `year` cell (index 6) joins the
  /// expression only when it holds a draft.
  bool _cellActive(int index, List<String> cells) =>
      profile != CronProfile.quartz || index < 6 || cells[index].isNotEmpty;

  /// Grapheme budget for edits inside cell [index]: the assembled-expression
  /// limit minus the other active cells and the separators between them, so a
  /// cell edit can never push the draft past [cronMaxExpressionLength]
  /// without the submit-time check.
  int _cellLimit(List<String> cells, int index) {
    var others = 0;
    var activeOthers = 0;
    for (var j = 0; j < cells.length; j++) {
      if (j == index || !_cellActive(j, cells)) continue;
      others += cells[j].length;
      activeOthers++;
    }
    // Editing a cell always makes it active, so it counts toward the total.
    final active = activeOthers + 1;
    return cronMaxExpressionLength - others - (active - 1);
  }

  /// Stage-led help for one field cell: the dialect summary first, then the
  /// focused cell's own syntax.
  String _cellHelp(CronFieldCell cell) {
    final optional = cell.optional ? ', optional' : '';
    return 'Help: Entering the expression for the ${profile.name} profile, '
        '$_fieldShape. Editing the ${cell.name} field cell '
        '${cell.position}/${cell.total} (${cell.rangeCue}$optional). '
        'Tab or Shift-Tab moves between field cells; Enter validates the whole '
        'draft${preview == null ? ' and submits it' : ' and opens the review stage'}; '
        'Ctrl+T opens help; Escape cancels; Ctrl+C interrupts. '
        '$_limitNote $_syntaxNote $_previewNote';
  }

  /// Help for the trailing Submit stop (only reached without a preview).
  String get _submitHelp =>
      'Help: The Submit stop accepts the whole ${profile.name} profile draft, '
      '$_fieldShape. Tab or Shift-Tab moves between the field cells and this '
      'stop; Enter activates Submit; Ctrl+T opens help; Escape cancels; '
      'Ctrl+C interrupts. $_limitNote $_syntaxNote $_previewNote';

  /// Rich-interaction field-cell entry stage.
  ///
  /// Runs the focus ring `cell 0 -> ... -> cell N-1 -> trailing action ->
  /// cell 0` until the draft validates. Returns the assembled expression when
  /// a preview review is configured, or the accepted result when it is not; a
  /// non-null `result` ends the prompt (cancel, interrupt or input end).
  /// [cells] is mutated in place so a Review `Edit` action can re-enter with
  /// every cell draft preserved.
  Future<PromptResult<CronExpression>?> _fieldCells(
    _Keys inputKeys,
    StringSink out,
    OutputProfile effectiveProfile,
    TerminalSession? session,
    TerminalResizeObserver? resizeObserver,
    List<String> cells,
  ) async {
    final schema = cronFieldCells(profile);
    final actionName = preview == null ? 'Submit' : 'Review';
    final stops = schema.length + 1;
    var focus = 0;
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: _textInputWidth(effectiveProfile),
      background: colors.background,
      border: colors.border,
      rich: true,
      session: session,
    );
    void write(
      String text, {
      bool closes = false,
      StageEvent event = StageEvent.body,
    }) => spine.write(
      out,
      text,
      foreground: colors.foreground,
      closes: closes,
      event: event,
    );

    String draftText() {
      final active = profile == CronProfile.quartz && cells[6].isEmpty
          ? cells.sublist(0, 6)
          : cells;
      return active.join(' ');
    }

    String focusName() =>
        focus < schema.length ? schema[focus].name : actionName;

    String cue() => focus < schema.length
        ? '${profile.name} · ${schema[focus].position}/${schema[focus].total} '
              '${schema[focus].name} (${schema[focus].rangeCue}'
              '${schema[focus].optional ? ', optional' : ''})'
        : '${profile.name} · Focus: $actionName · draft: ${draftText()}';

    String cellToken(int index) {
      final inner = cells[index].isEmpty ? ' ' : cells[index];
      return index == focus ? '[>$inner<]' : '[ $inner ]';
    }

    void show() {
      spine.reset(out);
      spine.opening(
        out,
        title: '$label.',
        body: '${profile.name} profile; draft: ${draftText()}.',
        foreground: colors.foreground,
        bodyForeground: colors.foreground,
      );
      write(
        '${List.generate(schema.length, cellToken).join(' ')} '
        '[${focus == schema.length ? '>$actionName<' : ' $actionName '}]',
      );
      write(cue());
      if (_resolvedInstructions(instructions) != InstructionDisplay.hidden) {
        spine.hint(
          out,
          'Focus: ${focusName()}. Tab moves right; Shift-Tab or Ctrl+B moves left; '
          'Enter ${preview == null ? 'submits' : 'reviews'}; Ctrl+T opens '
          'help; Escape cancels; Ctrl+C interrupts.',
          foreground: colors.foreground,
        );
      }
    }

    // Notices can be emitted while the caret still sits mid-row inside the
    // cell editor; restart the line at column zero so the wrapped notice
    // never inherits the caret column and overflows the declared width.
    void notice(String text) {
      out.write('\r\x1b[2K');
      write(text, closes: true, event: StageEvent.warning);
    }

    // A valid draft returns null so the caller can assemble the expression
    // and enter the review stage; without a configured preview it is
    // accepted directly.
    PromptResult<CronExpression>? finish() {
      final draft = cronAssembleExpression(profile, cells);
      if (preview == null) {
        return Accepted(CronExpression._(draft, profile));
      }
      return null;
    }

    ({int index, String message})? failure() =>
        cronFieldCellsError(profile, cells);

    while (true) {
      show();
      if (focus == schema.length) {
        final stop = await _edit(
          inputKeys,
          '',
          out,
          transientHelp:
              effectiveProfile.alternateScreen == CapabilitySupport.supported,
          helpText: preview == null ? _submitHelp : _reviewHelp(linear: false),
          outputProfile: effectiveProfile,
          structure: structure,
          resizeObserver: resizeObserver,
          session: session,
          intercept: (key, text) {
            if (key == '\t') return 'next';
            if (key == '\x1b[Z' || key == '\x02') return 'previous';
            if ((key == '\r' || key == '\n') && text.isEmpty) {
              return 'activate';
            }
            // The action stop takes no draft text.
            if (key.startsWith('\x1b[200~')) return 'handled';
            if (!key.startsWith('\x1b') && key.codeUnitAt(0) >= 32) {
              return 'handled';
            }
            return null;
          },
        );
        if (stop.action == 'cancel') return Cancelled();
        if (stop.action == 'interrupt') return Interrupted();
        if (stop.action == 'eof') return InputEnded();
        _finishFieldLine(out, stop.action);
        if (stop.action == 'activate' || stop.action == 'submit') {
          final error = failure();
          if (error != null) {
            notice(error.message);
            focus = error.index;
            continue;
          }
          return finish();
        }
        focus = stop.action == 'next' ? 0 : schema.length - 1;
        continue;
      }
      final index = focus;
      final cell = schema[index];
      final edit = await _edit(
        inputKeys,
        cells[index],
        out,
        maxLength: _cellLimit(cells, index),
        transientHelp:
            effectiveProfile.alternateScreen == CapabilitySupport.supported,
        helpText: _cellHelp(cell),
        liveHelpText: () => _cellHelp(cell),
        outputProfile: effectiveProfile,
        structure: structure,
        resizeObserver: resizeObserver,
        session: session,
        intercept: (key, text) {
          if (key == ' ') {
            notice(
              'Space does not insert into a field cell; press Tab to move '
              'to the next field.',
            );
            return 'handled';
          }
          if (key == '\t') return 'next';
          if (key == '\x1b[Z' || key == '\x02') return 'previous';
          if (key.startsWith('\x1b[200~')) {
            final payload = key.length >= 12
                ? key.substring(6, key.length - 6)
                : '';
            if (payload.contains(' ') ||
                payload.contains('\t') ||
                payload.contains('\n') ||
                payload.contains('\r')) {
              notice(
                'Paste rejected: a paste must fit inside one field cell; '
                'use Tab between fields.',
              );
              return 'handled';
            }
            // A single-token paste falls through to the editor's own paste
            // handling, which inserts it at the caret.
          }
          return null;
        },
      );
      if (edit.action == 'cancel') return Cancelled();
      if (edit.action == 'interrupt') return Interrupted();
      if (edit.action == 'eof') return InputEnded();
      _finishFieldLine(out, edit.action);
      cells[index] = edit.value;
      if (edit.action == 'next') {
        focus = (focus + 1) % stops;
        continue;
      }
      if (edit.action == 'previous') {
        focus = (focus + stops - 1) % stops;
        continue;
      }
      if (edit.action == 'submit') {
        final error = failure();
        if (error != null) {
          notice(error.message);
          focus = error.index;
          continue;
        }
        return finish();
      }
    }
  }

  /// The Review interaction stage shared by the linear and field-cell entry
  /// stages. Returns null when the user chooses `Edit`, which re-enters the
  /// entry stage; every other outcome is the prompt's final result.
  Future<PromptResult<CronExpression>?> _reviewStage(
    _Keys inputKeys,
    StringSink out,
    OutputProfile effectiveProfile,
    int? width,
    String draft,
    bool linear,
    TerminalSession? session,
    void Function(String text) writeNotice,
    TerminalResizeObserver? resizeObserver,
  ) async {
    final config = preview;
    if (config == null) {
      throw StateError('The review stage requires a configured preview.');
    }
    writeNotice(
      'Review: $draft. /preview, /edit, or /submit${linear ? '; /help opens help or /cancel cancels' : ''}.',
    );
    var focus = 0;
    const actions = ['Edit', 'Preview', 'Submit'];
    if (!linear) {
      writeNotice(
        'Review action: Edit. Tab or Shift-Tab changes action; Enter activates; Ctrl+T opens help.',
      );
    }
    while (true) {
      final action = await _edit(
        inputKeys,
        '',
        out,
        linear: true,
        sequential: linear,
        extraCommands: const {'/preview', '/edit', '/submit'},
        helpText: _reviewHelp(linear: linear),
        linearHelpText: _reviewHelp(linear: true),
        outputProfile: effectiveProfile,
        structure: structure,
        session: session,
        resizeObserver: linear ? null : resizeObserver,
        intercept: linear
            ? null
            : (key, text) {
                if (key == '\t' || key == '\x1b[Z' || key == '\x02') {
                  focus = (focus + (key == '\t' ? 1 : 2)) % actions.length;
                  writeNotice('Review action: ${actions[focus]}.');
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
        return null;
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
        inputKeys.onKey = (key) {
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
        writeNotice(
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
          inputKeys.onKey = null;
        }
        if (interrupted) return Interrupted();
        writeNotice(
          'Matching preview: ${result.status.name}; zone ${config.zone}; qualified provider snapshot timezone 0.11.2 / tzdata 2026e; strictly after ${config.reference.toIso8601String()}; bounds ${config.start.toIso8601String()} to ${config.end.toIso8601String()}; count ${config.count}; budget ${config.budget}; provider timeout ${config.providerTimeout}; gaps skipped, folds included; not scheduler execution.',
        );
        for (final instant in result.instants) {
          _structureSpine(
            effectiveProfile,
            structure: structure,
            width: width,
            background: colors.background,
            border: colors.border,
          ).write(
            out,
            instant.toString(),
            foreground: colors.foreground,
            closes: true,
          );
        }
        if (!linear) {
          // Review state must never be implicit after a preview round: keep
          // the reviewer's action position and announce it again.
          writeNotice('Review action: ${actions[focus]}.');
        }
        continue;
      }
      writeNotice('Use /preview, /edit, or /submit.');
    }
  }

  Future<PromptResult<CronExpression>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      return session._promptRunner<CronExpression>(
        _run,
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
      );
    }
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          if (terminal != null) {
            return await SharedTerminalLease.run(terminal, () async {
              return _run(
                ScriptedInput(
                  terminal.input,
                  terminal.output,
                  supportsRich: terminal.supportsRich,
                  outputProfile: _terminalOutputProfile(terminal),
                  hardColorDisabled:
                      terminal.environment['NO_COLOR']?.isNotEmpty == true,
                  resizeObserver: _terminalResizeObserver(terminal),
                ),
                selected,
                outputProfile: outputProfile,
              );
            });
          }
          return await _terminal<CronExpression>(
            selected,
            output ?? stdout,
            (source, mode, restore) => _run(
              source,
              mode,
              outputProfile: outputProfile,
              beforeClose: restore,
            ),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  PromptResult<CronExpression> _asCron(PromptResult<String> result) {
    if (result is Accepted<String>) {
      return Accepted(CronExpression._(result.value, profile));
    }
    if (result is Cancelled<String>) return Cancelled();
    if (result is Interrupted<String>) return Interrupted();
    if (result is InputEnded<String>) return InputEnded();
    return Unavailable((result as Unavailable<String>).reason);
  }

  Future<PromptResult<CronExpression>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
    void Function()? beforeClose,
  }) async {
    final config = preview;
    if (source is! ScriptedInput) {
      if (config == null || source is SuppliedAnswer) {
        // Without a configured preview the entry and review stages are the
        // shared text contract, so the existing TextInput flow is reused
        // rather than restated here; supplied answers bypass interaction.
        return _asCron(
          await _input._run(
            source,
            mode,
            outputProfile: outputProfile,
            keys: keys,
            session: session,
          ),
        );
      }
      return Unavailable('Unsupported cron input source.');
    }
    final effectiveProfile = _effectiveOutputProfile(source, outputProfile);
    var resolved = mode;
    if (resolved == PromptMode.automatic) {
      resolved = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    if (resolved == PromptMode.rich &&
        !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    final linear = resolved == PromptMode.linear;
    if (linear && config == null) {
      // Linear entry without a configured preview stays on the shared
      // single-line text contract.
      return _asCron(
        await _input._run(
          source,
          mode,
          outputProfile: outputProfile,
          keys: keys,
          session: session,
        ),
      );
    }
    final out = source.output;
    final width = _textInputWidth(effectiveProfile);
    final inputKeys = keys ?? _Keys(source.input.transform(utf8.encoder));
    // Guidance, validation and preview reports are measured against the
    // declared geometry so a narrow output never overflows. Matching instants
    // are reported as data and are never split.
    //
    // A rich editor owns the physical line with a carriage return and an
    // erase-line sequence; a notice takes that line over the same way instead
    // of being appended to the field the user just left.
    void writeNotice(String text) {
      if (!linear) out.write('\r\x1b[2K');
      // Every notice is its own event, so an enclosure renders it as a compact
      // block outside a frame instead of drawing one frame per message.
      _structureSpine(
        effectiveProfile,
        structure: structure,
        width: width,
        background: colors.background,
        border: colors.border,
      ).hint(out, text, foreground: colors.foreground);
    }

    writeNotice(
      '$label. ${profile.name} profile. Expression limit $maxExpressionLength UTF-16 code units.',
    );
    writeNotice(
      'Enter an expression, then /preview, /edit or /submit; /cancel cancels.${linear ? ' /help opens help.' : ' Ctrl+T opens help.'}',
    );
    try {
      if (linear) {
        var draft = _initialDraft;
        while (true) {
          final entry = await _edit(
            inputKeys,
            draft,
            out,
            linear: true,
            sequential: true,
            maxLength: maxExpressionLength,
            clearHelpCommand: true,
            helpText: _entryHelp(linear: true),
            linearHelpText: _entryHelp(linear: true),
            outputProfile: effectiveProfile,
            structure: structure,
            session: session,
          );
          if (entry.action == 'cancel') return Cancelled();
          if (entry.action == 'interrupt') return Interrupted();
          if (entry.action != 'submit') return InputEnded();
          draft = entry.value;
          if (!_valid(draft)) {
            writeNotice(
              'Invalid cron expression. Correct the retained draft.',
            );
            continue;
          }
          final review = await _reviewStage(
            inputKeys,
            out,
            effectiveProfile,
            width,
            draft,
            true,
            session,
            writeNotice,
            source.resizeObserver,
          );
          if (review != null) return review;
        }
      }
      // Rich interaction edits one field cell at a time. The cell drafts are
      // created once per run and survive validation failures and Review
      // round-trips until the prompt ends.
      final cells = List<String>.of(_initialFieldCells);
      while (true) {
        final result = await _fieldCells(
          inputKeys,
          out,
          effectiveProfile,
          session,
          source.resizeObserver,
          cells,
        );
        if (result != null) return result;
        final review = await _reviewStage(
          inputKeys,
          out,
          effectiveProfile,
          width,
          cronAssembleExpression(profile, cells),
          false,
          session,
          writeNotice,
          source.resizeObserver,
        );
        if (review != null) return review;
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        if (keys == null) await inputKeys.close();
      }
    }
  }
}
