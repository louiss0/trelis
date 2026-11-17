import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  colorDepth: ColorDepth.indexed256,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

final _palette = ColorThemes.terminalDefault.copyWith(
  foreground: TerminalColor.indexed(12),
);

final _commaConvention = NumericConvention(
  decimalSeparator: ',',
  groupingSeparator: '.',
  grouping: const [3],
  nativeDigits: '0123456789',
);

/// An exact command-clear sequence after `/help` leaves the command in the
/// draft: go to the start and delete each character.
const _clearHelpCommand = '\x01\x1b[3~\x1b[3~\x1b[3~\x1b[3~\x1b[3~';

/// Erases a failed linear draft: go to the start and delete every character.
final _clearDraft = '\x01${'\x1b[3~' * 40}';

/// One public component invocation under test.
final class _Invocation {
  const _Invocation({
    required this.output,
    required this.keys,
    this.mode = PromptMode.linear,
    this.instructions = InstructionDisplay.themeDefault,
    this.supplementaryHelp = const [],
    this.session,
    this.supplied = false,
    this.colors,
  });

  final StringBuffer output;
  final String keys;
  final PromptMode mode;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final TerminalSession? session;
  final bool supplied;
  final ColorTheme? colors;
}

/// A formatted-value component and the public contract this ticket preserves.
final class _Formatted {
  const _Formatted({
    required this.name,
    required this.cue,
    required this.details,
    required this.answer,
    required this.invalid,
    required this.validation,
    required this.prompt,
    required this.expectAnswer,
  });

  final String name;

  /// The compact active-format cue that stays in the opening.
  final String cue;

  /// Syntax and limitation detail that belongs in component help.
  final List<String> details;

  /// A valid answer for this configuration.
  final String answer;

  /// A supplied answer this configuration rejects.
  final String invalid;

  /// The validation message an invalid interactive draft produces.
  final String validation;

  final Future<PromptResult<Object?>> Function(_Invocation) prompt;

  final void Function(PromptResult<Object?>) expectAnswer;
}

PromptSource? _source(_Invocation invocation) => invocation.session != null
    ? null
    : invocation.supplied
    ? SuppliedAnswer(invocation.keys)
    : ScriptedInput(
        invocation.keys.isEmpty
            ? const Stream<String>.empty()
            : Stream.value(invocation.keys),
        invocation.output,
        outputProfile: _richProfile,
      );

PromptMode? _mode(_Invocation invocation) =>
    invocation.session == null ? invocation.mode : null;

OutputProfile? _profile(_Invocation invocation) =>
    invocation.session == null ? _richProfile : null;

final _formatted = <_Formatted>[
  _Formatted(
    name: 'NumberInput',
    cue: 'decimal numeric entry; decimal separator .',
    details: const [
      'Number format: base-ten decimal values use the active numeric convention',
      'maximum 2 decimal places',
    ],
    answer: '1.5',
    invalid: 'not-a-number',
    validation: 'Enter a complete base-ten number',
    prompt: (i) =>
        NumberInput(
          'Amount',
          convention: NumericConvention.ascii(),
          decimal: true,
          precision: 2,
          instructions: i.instructions,
          supplementaryHelp: i.supplementaryHelp,
          colors: i.colors ?? ColorThemes.terminalDefault,
        ).prompt(
          source: _source(i),
          mode: _mode(i),
          outputProfile: _profile(i),
          session: i.session,
        ),
    expectAnswer: (result) =>
        expect((result as Accepted<NumericAnswer?>).value?.spelling, '1.5'),
  ),
  _Formatted(
    name: 'PortInput',
    cue: 'ASCII decimal 0-65535',
    details: const [
      'Port format: ASCII decimal 0 through 65535; zero requests automatic allocation',
      'Availability and reachability are not checked.',
    ],
    answer: '443',
    invalid: 'not-a-port',
    validation: 'Enter an ASCII decimal port',
    prompt: (i) =>
        PortInput(
          'Port',
          allowZero: true,
          instructions: i.instructions,
          supplementaryHelp: i.supplementaryHelp,
          colors: i.colors ?? ColorThemes.terminalDefault,
        ).prompt(
          source: _source(i),
          mode: _mode(i),
          outputProfile: _profile(i),
          session: i.session,
        ),
    expectAnswer: (result) => expect((result as Accepted<int>).value, 443),
  ),
  _Formatted(
    name: 'IPAddressInput',
    cue: 'with /prefix and IPv6 %zone',
    details: const [
      'host bits are retained',
      'zone identity is environment-dependent',
      'reachability and interface existence are not checked.',
    ],
    answer: '192.0.2.7/24',
    invalid: 'not-an-address',
    validation: 'Enter a valid numeric IPv4 or IPv6 address',
    prompt: (i) =>
        IPAddressInput(
          'Host',
          cidr: true,
          scoped: true,
          instructions: i.instructions,
          supplementaryHelp: i.supplementaryHelp,
          colors: i.colors ?? ColorThemes.terminalDefault,
        ).prompt(
          source: _source(i),
          mode: _mode(i),
          outputProfile: _profile(i),
          session: i.session,
        ),
    expectAnswer: (result) {
      final value = (result as Accepted<IPAddressValue>).value;
      expect(value.spelling, '192.0.2.7/24');
      expect(value.prefixLength, 24);
    },
  ),
  _Formatted(
    name: 'EmailInput',
    cue: 'SMTPUTF8 local part allowed',
    details: const [
      'Email format: one bare SMTP mailbox; SMTPUTF8 is required for Unicode local parts',
      'Deliverability and transport availability are not checked.',
    ],
    answer: 'x@example.com',
    invalid: 'not-an-address',
    validation: 'Enter one valid bare SMTP address.',
    prompt: (i) =>
        EmailInput(
          'Mail',
          smtpUtf8: true,
          instructions: i.instructions,
          supplementaryHelp: i.supplementaryHelp,
          colors: i.colors ?? ColorThemes.terminalDefault,
        ).prompt(
          source: _source(i),
          mode: _mode(i),
          outputProfile: _profile(i),
          session: i.session,
        ),
    expectAnswer: (result) =>
        expect((result as Accepted<String>).value, 'x@example.com'),
  ),
  _Formatted(
    name: 'ColorInput',
    cue: 'CSS sRGB color: hex, RGB, HSL, or static name',
    details: const [
      'Color format: CSS Color 4 sRGB #RGB, #RGBA, #RRGGBB, #RRGGBBAA',
      'hue wraps modulo 360 degrees',
      'Expressions and other colour spaces are not supported.',
    ],
    answer: '#f00',
    invalid: 'not-a-color',
    validation: 'Enter a valid sRGB color',
    prompt: (i) =>
        ColorInput(
          'Tint',
          instructions: i.instructions,
          supplementaryHelp: i.supplementaryHelp,
          colors: i.colors ?? ColorThemes.terminalDefault,
        ).prompt(
          source: _source(i),
          mode: _mode(i),
          outputProfile: _profile(i),
          session: i.session,
        ),
    expectAnswer: (result) {
      final value = (result as Accepted<ColorValue?>).value!;
      expect(value.source, '#f00');
      expect(value.red, 1);
      expect(value.alpha, 1);
    },
  ),
  _Formatted(
    name: 'DurationInput',
    cue: 'elapsed duration; units w d h m s ms us',
    details: const [
      'Duration format: elapsed; units w d h m s ms us; d is 24 hours',
      'fractions must convert exactly to integer microseconds',
      'Calendar periods are unapplied and do not imply an elapsed total.',
    ],
    answer: '-1s',
    invalid: 'not-a-duration',
    validation: 'Invalid duration',
    prompt: (i) =>
        DurationInput(
          'Wait',
          durationMode: DurationInputMode.elapsed,
          signed: true,
          instructions: i.instructions,
          supplementaryHelp: i.supplementaryHelp,
          colors: i.colors ?? ColorThemes.terminalDefault,
        ).prompt(
          source: _source(i),
          mode: _mode(i),
          outputProfile: _profile(i),
          session: i.session,
        ),
    expectAnswer: (result) => expect(
      (result as Accepted<DurationValue>).value.microseconds,
      BigInt.from(-1000000),
    ),
  ),
];

/// One component whose live preview or interpretation writes into a session.
final class _PreviewScenario {
  const _PreviewScenario({
    required this.name,
    required this.marker,
    required this.keys,
    required this.prompt,
  });

  final String name;

  /// The preview write that must fail, so the failure is the preview's own.
  final String marker;
  final String keys;
  final Future<PromptResult<Object?>> Function(TerminalSession) prompt;
}

final _previewScenarios = <_PreviewScenario>[
  _PreviewScenario(
    name: 'ColorInput',
    marker: 'Value: #f00',
    keys: '#f00\r',
    prompt: (session) => ColorInput('Tint').prompt(session: session),
  ),
  _PreviewScenario(
    name: 'DurationInput',
    marker: 'Elapsed interpretation',
    keys: '1s\r',
    prompt: (session) => DurationInput(
      'Wait',
      durationMode: DurationInputMode.elapsed,
    ).prompt(session: session),
  ),
  _PreviewScenario(
    name: 'EmailInput',
    marker: 'Domain interpretation',
    keys: 'x@example.com\r',
    prompt: (session) => EmailInput('Mail').prompt(session: session),
  ),
];

/// The declared shared-writer failure; its diagnostic carries a canary that
/// must never be copied into selected output.
final class _WriterFailure implements Exception {
  _WriterFailure(this.name) : canary = 'CANARY-$name';

  final String name;
  final String canary;

  @override
  String toString() => 'SharedWriterFailure($canary) for $name';
}

/// Records selected-output writes and fails on the declared preview write.
final class _FailingSink implements StringSink {
  _FailingSink(this.marker, this.failure);

  final String marker;
  final Object failure;
  final writes = <String>[];

  int get writeCount => writes.length;

  void _add(String text) {
    if (text.contains(marker)) throw failure;
    writes.add(text);
  }

  @override
  void write(Object? object) => _add('$object');

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _add(objects.map((object) => '$object').join(separator));

  @override
  void writeCharCode(int charCode) => _add(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => _add('$object\n');
}

/// A public [TerminalIo] adapter with its own selected output and lease.
final class _RecordingTerminalIo implements TerminalIo {
  _RecordingTerminalIo(this.input, this.output);

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  final events = <String>[];

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const {'NO_COLOR': null};

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}

/// Joins wrapped transcript lines back into one flowed string so a wrapped
/// cue or help sentence is still observable as continuous text.
///
/// The shared wrapper trims the space at a wrap point, which ticket 21
/// introduced for choice rows, so the transcript and every phrase compared
/// against it drop whitespace. This matches the convention in
/// `test/select_radio_test.dart`, `test/multi_select_test.dart` and
/// `test/date_time_migration_test.dart`.
String _flowed(String text) => text.replaceAll(RegExp(r'\s+'), '');

/// A phrase compared against [_flowed] transcript text.
Matcher _containsPhrase(String phrase) => contains(_flowed(phrase));

/// Where the shared editing guidance starts; the active-format cue precedes it.
int _nextGuidance(String text, int from) {
  var first = text.length;
  for (final marker in ['Left/Right move', 'Enter submits;', 'opens help.']) {
    final at = text.indexOf(_flowed(marker), from);
    if (at >= 0 && at < first) first = at;
  }
  return first;
}

/// Checks one component's cue/help contract and returns where its run starts.
int _expectFixtureSegment(_Formatted fixture, String text, {int from = 0}) {
  final cue = text.indexOf(_flowed(fixture.cue), from);
  expect(cue, isNonNegative, reason: '${fixture.name} is missing its cue');
  expect(
    cue,
    lessThan(_nextGuidance(text, cue)),
    reason: '${fixture.name} cue must stay in the opening',
  );
  final help = text.indexOf('Help:', cue);
  expect(
    help,
    isNonNegative,
    reason: '${fixture.name} help was not shown after its cue',
  );
  for (final detail in fixture.details) {
    expect(
      text.indexOf(_flowed(detail), cue),
      greaterThan(help),
      reason: '${fixture.name} must keep "$detail" in component help',
    );
  }
  return cue;
}

void main() {
  test(
    'each formatted input opens with a compact cue and keeps detail in help',
    () async {
      for (final fixture in _formatted) {
        final output = StringBuffer();
        final result = await fixture.prompt(
          _Invocation(
            output: output,
            keys: '/help\r$_clearHelpCommand${fixture.answer}\r',
            supplementaryHelp: ['Caller note for ${fixture.name}.'],
          ),
        );
        final text = _flowed(output.toString());

        fixture.expectAnswer(result);
        _expectFixtureSegment(fixture, text);
        expect(
          text,
          _containsPhrase('Caller note for ${fixture.name}.'),
          reason: '${fixture.name} must append supplementary help',
        );
        expect(
          text,
          _containsPhrase('Enter text to submit'),
          reason: '${fixture.name} must retain the shared editing help',
        );
      }
    },
  );

  test(
    'every instruction policy keeps the cue and help, and only edits guidance',
    () async {
      for (final fixture in _formatted) {
        for (final policy in [
          InstructionDisplay.hidden,
          InstructionDisplay.compact,
          InstructionDisplay.expanded,
        ]) {
          final output = StringBuffer();
          await fixture.prompt(
            _Invocation(
              output: output,
              keys: '/help\r$_clearHelpCommand${fixture.answer}\r',
              instructions: policy,
            ),
          );
          final text = _flowed(output.toString());

          _expectFixtureSegment(fixture, text);
          switch (policy) {
            case InstructionDisplay.hidden:
              expect(
                text,
                isNot(_containsPhrase('Left/Right move')),
                reason: '${fixture.name} hidden guidance',
              );
              expect(
                text,
                isNot(_containsPhrase('Enter submits;')),
                reason: '${fixture.name} hidden guidance',
              );
            case InstructionDisplay.compact:
              expect(
                text,
                _containsPhrase('Enter submits;'),
                reason: '${fixture.name} compact guidance',
              );
              expect(
                text,
                isNot(_containsPhrase('Left/Right move')),
                reason: '${fixture.name} compact guidance',
              );
            case InstructionDisplay.expanded:
              expect(
                text,
                _containsPhrase('Left/Right move'),
                reason: '${fixture.name} expanded guidance',
              );
            case InstructionDisplay.themeDefault:
              fail('themeDefault is resolved before rendering.');
          }
        }
      }
    },
  );

  test('rich interaction keeps the cue and component help', () async {
    for (final fixture in _formatted) {
      final output = StringBuffer();
      final result = await fixture.prompt(
        _Invocation(
          output: output,
          keys: '\x14\x1b${fixture.answer}\r',
          mode: PromptMode.rich,
        ),
      );
      final text = _flowed(output.toString());

      fixture.expectAnswer(result);
      _expectFixtureSegment(fixture, text);
      expect(
        text,
        _containsPhrase('Help dismissed.'),
        reason: '${fixture.name} must restore the prompt after help',
      );
    }
  });

  test('every formatted input reports distinct explicit outcomes', () async {
    for (final fixture in _formatted) {
      final cancelled = StringBuffer();
      expect(
        await fixture.prompt(_Invocation(output: cancelled, keys: '/cancel\r')),
        isA<Cancelled<Object?>>(),
        reason: '${fixture.name} cancellation',
      );

      final interrupted = StringBuffer();
      expect(
        await fixture.prompt(_Invocation(output: interrupted, keys: '\x03')),
        isA<Interrupted<Object?>>(),
        reason: '${fixture.name} interruption',
      );

      final ended = StringBuffer();
      expect(
        await fixture.prompt(_Invocation(output: ended, keys: '')),
        isA<InputEnded<Object?>>(),
        reason: '${fixture.name} input ended',
      );

      final unavailable = await fixture.prompt(
        _Invocation(
          output: StringBuffer(),
          keys: fixture.invalid,
          supplied: true,
        ),
      );
      expect(
        unavailable,
        isA<Unavailable<Object?>>(),
        reason: '${fixture.name} invalid supplied answer',
      );
      expect(
        (unavailable as Unavailable<Object?>).reason,
        isNotEmpty,
        reason: '${fixture.name} must explain an unavailable answer',
      );
    }
  });

  test(
    'invalid drafts are corrected with a visible validation message',
    () async {
      for (final fixture in _formatted) {
        final output = StringBuffer();
        final result = await fixture.prompt(
          _Invocation(
            output: output,
            keys: '${fixture.invalid}\r$_clearDraft${fixture.answer}\r',
          ),
        );

        expect(
          _flowed(output.toString()),
          _containsPhrase(fixture.validation),
          reason: '${fixture.name} must explain the rejected draft',
        );
        fixture.expectAnswer(result);
      }
    },
  );

  test('one shared linear session runs all six formatted inputs', () async {
    final output = StringBuffer();
    final keys = _formatted
        .map((f) => '/help\r$_clearHelpCommand${f.answer}\r')
        .join();
    final results = await TerminalSession.run(
      (session) async => [
        for (final fixture in _formatted)
          await fixture.prompt(
            _Invocation(output: output, keys: '', session: session),
          ),
      ],
      source: ScriptedInput(Stream.value(keys), output),
      mode: PromptMode.linear,
    );
    final text = _flowed(output.toString());

    var cursor = 0;
    for (var index = 0; index < _formatted.length; index++) {
      final fixture = _formatted[index];
      fixture.expectAnswer(results[index]);
      cursor = _expectFixtureSegment(fixture, text, from: cursor) + 1;
    }
    expect(
      text,
      _containsPhrase('Elapsed interpretation: -1000000 microseconds.'),
      reason: 'duration interpretation must share the session output',
    );
    expect(
      text,
      _containsPhrase('approximate rounded hex preview: #ff0000ff'),
      reason: 'colour preview must share the session output',
    );
    expect(
      text,
      _containsPhrase('Domain interpretation -- Unicode: example.com'),
      reason: 'email interpretation must share the session output',
    );
  });

  test('one shared rich session runs all six formatted inputs', () async {
    final output = StringBuffer();
    final keys = _formatted.map((f) => '\x14\x1b${f.answer}\r').join();
    final results = await TerminalSession.run(
      (session) async => [
        for (final fixture in _formatted)
          await fixture.prompt(
            _Invocation(output: output, keys: '', session: session),
          ),
      ],
      source: ScriptedInput(
        Stream.value(keys),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    final text = _flowed(output.toString());

    var cursor = 0;
    for (var index = 0; index < _formatted.length; index++) {
      final fixture = _formatted[index];
      fixture.expectAnswer(results[index]);
      cursor = _expectFixtureSegment(fixture, text, from: cursor) + 1;
    }

    await expectLater(
      TerminalSession.run((session) async {
        await expectLater(
          PortInput('Port').prompt(session: session, mode: PromptMode.rich),
          throwsArgumentError,
        );
      }, source: ScriptedInput(const Stream<String>.empty(), StringBuffer())),
      completes,
    );
  });

  test(
    'a failed shared preview write retires the session and blocks late writes',
    () async {
      for (final scenario in _previewScenarios) {
        final failure = _WriterFailure(scenario.name);
        final sink = _FailingSink(scenario.marker, failure);
        TerminalSessionFeedbackRegion? region;
        TerminalSession? session;
        Object? previewFailure;
        Object? secondOutcome;
        var writesAtFailure = 0;
        var lateWrites = 0;

        final run = TerminalSession.run(
          (scope) async {
            session = scope;
            region = scope.startFeedbackRegion();
            region!.write('status before preview');
            try {
              await scenario.prompt(scope);
            } catch (error) {
              previewFailure = error;
            }
            // Still inside the scope: the failed writer must already have
            // retired it, so neither a late region update nor another
            // attached prompt may reach the selected output.
            writesAtFailure = sink.writeCount;
            region!.write('late update');
            lateWrites = sink.writeCount - writesAtFailure;
            try {
              secondOutcome = await scenario.prompt(scope);
            } catch (error) {
              secondOutcome = error;
            }
            throw previewFailure!;
          },
          source: ScriptedInput(
            Stream.value(scenario.keys),
            sink,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.linear,
        );

        await expectLater(run, throwsA(same(failure)));
        expect(
          previewFailure,
          same(failure),
          reason: '${scenario.name} must surface the original writer failure',
        );
        expect(
          writesAtFailure,
          greaterThan(0),
          reason: '${scenario.name} must have written the opening and status',
        );
        expect(
          lateWrites,
          0,
          reason:
              '${scenario.name} late updates must not reach a failed writer',
        );
        expect(
          secondOutcome,
          isA<StateError>(),
          reason: '${scenario.name} must retire the session on writer failure',
        );
        expect(sink.writes.join(), isNot(contains('late update')));
        expect(
          sink.writes.join(),
          isNot(contains(failure.canary)),
          reason:
              '${scenario.name} must not copy a writer diagnostic into output',
        );

        await expectLater(scenario.prompt(session!), throwsStateError);
      }
    },
  );

  test('email interpretation follows the selected terminal output', () async {
    final output = StringBuffer();
    final terminal = _RecordingTerminalIo(
      Stream.value('x@example.com\r'),
      output,
    );

    final result = await EmailInput('Mail').prompt(terminal: terminal);

    expect((result as Accepted<String>).value, 'x@example.com');
    expect(
      _flowed(output.toString()),
      _containsPhrase('Domain interpretation -- Unicode: example.com'),
      reason: 'the interpretation must use the selected terminal output',
    );
    expect(terminal.events, ['acquire', 'restore']);
  });

  test('distinguishable configuration reaches every formatted input', () async {
    expect(
      (await PortInput('Port', allowZero: true).prompt(
        source: ScriptedInput(Stream.value('0\r'), StringBuffer()),
        mode: PromptMode.linear,
      ) as Accepted<int>).value,
      0,
    );
    expect(
      await PortInput(
        'Port',
        allowZero: false,
      ).prompt(source: SuppliedAnswer('0')),
      isA<Unavailable<int>>(),
    );

    final scoped = (await IPAddressInput('Host', scoped: true).prompt(
      source: ScriptedInput(Stream.value('fe80::1%eth0\r'), StringBuffer()),
      mode: PromptMode.linear,
    ) as Accepted<IPAddressValue>).value;
    expect(scoped.zone, 'eth0');
    expect(
      await IPAddressInput(
        'Host',
        scoped: false,
      ).prompt(source: SuppliedAnswer('fe80::1%eth0')),
      isA<Unavailable<IPAddressValue>>(),
    );
    expect(
      await IPAddressInput(
        'Host',
        scoped: true,
      ).prompt(source: SuppliedAnswer('192.0.2.7/24')),
      isA<Unavailable<IPAddressValue>>(),
    );

    expect(
      (await EmailInput('Mail', smtpUtf8: true).prompt(
        source: ScriptedInput(Stream.value('ü@example.com\r'), StringBuffer()),
        mode: PromptMode.linear,
      ) as Accepted<String>).value,
      'ü@example.com',
    );
    expect(
      await EmailInput(
        'Mail',
        smtpUtf8: false,
      ).prompt(source: SuppliedAnswer('ü@example.com')),
      isA<Unavailable<String>>(),
    );

    expect(
      (await NumberInput(
                'Amount',
                convention: _commaConvention,
                decimal: true,
                precision: 2,
              ).prompt(
                source: ScriptedInput(Stream.value('1,5\r'), StringBuffer()),
                mode: PromptMode.linear,
              )
              as Accepted<NumericAnswer?>)
          .value
          ?.spelling,
      '1,5',
    );
    expect(
      await NumberInput(
        'Amount',
        convention: NumericConvention.ascii(),
        decimal: true,
        precision: 2,
      ).prompt(source: SuppliedAnswer('1.234')),
      isA<Unavailable<NumericAnswer?>>(),
    );
    expect(
      await NumberInput(
        'Amount',
        convention: NumericConvention.ascii(),
      ).prompt(source: SuppliedAnswer('1.5')),
      isA<Unavailable<NumericAnswer?>>(),
    );

    expect(
      (await NumberInput(
        'Amount',
        convention: NumericConvention.ascii(),
        required: false,
      ).prompt(source: SuppliedAnswer('')) as Accepted<NumericAnswer?>).value,
      isNull,
    );

    expect(
      (await ColorInput('Tint', required: false).prompt(
        source: ScriptedInput(Stream.value('\r'), StringBuffer()),
        mode: PromptMode.linear,
      ) as Accepted<ColorValue?>).value,
      isNull,
    );
    expect(
      await ColorInput('Tint').prompt(source: SuppliedAnswer('')),
      isA<Unavailable<ColorValue?>>(),
    );

    final calendar =
        (await DurationInput(
                  'Gap',
                  durationMode: DurationInputMode.calendarRelative,
                ).prompt(
                  source: ScriptedInput(
                    Stream.value('1mo 2d\r'),
                    StringBuffer(),
                  ),
                  mode: PromptMode.linear,
                )
                as Accepted<DurationValue>)
            .value;
    expect(calendar.components, {'mo': BigInt.one, 'd': BigInt.two});
    expect(
      await DurationInput(
        'Gap',
        durationMode: DurationInputMode.elapsed,
      ).prompt(source: SuppliedAnswer('1mo')),
      isA<Unavailable<DurationValue>>(),
    );
    expect(
      await DurationInput(
        'Gap',
        durationMode: DurationInputMode.elapsed,
      ).prompt(source: SuppliedAnswer('-1s')),
      isA<Unavailable<DurationValue>>(),
    );
    expect(
      (await DurationInput(
            'Gap',
            durationMode: DurationInputMode.elapsed,
            signed: true,
          ).prompt(source: SuppliedAnswer('-1s')) as Accepted<DurationValue>)
          .value
          .microseconds,
      BigInt.from(-1000000),
    );
  });

  test('palette styles reach all six components', () async {
    for (final fixture in _formatted) {
      final output = StringBuffer();
      await fixture.prompt(
        _Invocation(
          output: output,
          keys: '${fixture.answer}\r',
          colors: _palette,
        ),
      );
      expect(
        output.toString(),
        contains('\x1b[38;5;12;49m'),
        reason: '${fixture.name} must apply the declared palette',
      );
    }
  });

  test(
    'transport, availability and approximation limits stay visible',
    () async {
      final port = StringBuffer();
      await PortInput('Port').prompt(
        source: ScriptedInput(Stream.value('/help\r\x03'), port),
        mode: PromptMode.linear,
      );
      expect(
        _flowed(port.toString()),
        _containsPhrase('Availability and reachability are not checked.'),
      );

      final address = StringBuffer();
      await IPAddressInput('Host', cidr: true, scoped: true).prompt(
        source: ScriptedInput(Stream.value('/help\r\x03'), address),
        mode: PromptMode.linear,
      );
      final addressText = _flowed(address.toString());
      expect(addressText, _containsPhrase('host bits are retained'));
      expect(
        addressText,
        _containsPhrase('zone identity is environment-dependent'),
      );
      expect(
        addressText,
        _containsPhrase(
          'reachability and interface existence are not checked.',
        ),
      );

      final mail = StringBuffer();
      final literal = await EmailInput('Mail').prompt(
        source: ScriptedInput(Stream.value('x@[192.0.2.1]\r'), mail),
        mode: PromptMode.linear,
      );
      expect(literal, isA<Accepted<String>>());
      expect(
        _flowed(mail.toString()),
        _containsPhrase('Transport address literal: [192.0.2.1].'),
      );

      final mailHelp = StringBuffer();
      await EmailInput('Mail').prompt(
        source: ScriptedInput(Stream.value('/help\r\x03'), mailHelp),
        mode: PromptMode.linear,
      );
      expect(
        _flowed(mailHelp.toString()),
        _containsPhrase(
          'Deliverability and transport availability are not checked.',
        ),
      );

      final colour = StringBuffer();
      await ColorInput('Tint').prompt(
        source: ScriptedInput(Stream.value('#f00\r'), colour),
        mode: PromptMode.linear,
      );
      expect(
        _flowed(colour.toString()),
        _containsPhrase(
          'approximate rounded hex preview: #ff0000ff (not the stored value)',
        ),
      );

      final calendar = StringBuffer();
      final period =
          await DurationInput(
            'Gap',
            durationMode: DurationInputMode.calendarRelative,
          ).prompt(
            source: ScriptedInput(Stream.value('1mo 2d\r'), calendar),
            mode: PromptMode.linear,
          );
      expect((period as Accepted<DurationValue>).value.components, {
        'mo': BigInt.one,
        'd': BigInt.two,
      });
      expect(
        _flowed(calendar.toString()),
        _containsPhrase('Unapplied calendar components: {mo: 1, d: 2}'),
      );
    },
  );
}
