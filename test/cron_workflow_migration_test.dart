import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 40, rows: 8),
);

CronPreviewConfig _config() => CronPreviewConfig(
  providerTimeout: const Duration(seconds: 5),
  zone: 'Etc/UTC',
  reference: DateTime.utc(2024),
  start: DateTime.utc(2024),
  end: DateTime.utc(2024, 1, 1, 0, 3),
  count: 1,
  budget: 3,
);

final class _ResizeObserver implements TerminalResizeObserver {
  _ResizeObserver(this.notifications, this._dimensions);

  @override
  final Stream<void> notifications;
  final ({int columns, int rows})? Function() _dimensions;

  @override
  ({int columns, int rows})? readDimensions() => _dimensions();

  @override
  Duration get fallbackInterval => const Duration(days: 1);
}

final class _FakeTerminal implements TerminalIo, TerminalIoOutputProfile {
  _FakeTerminal(this.input, this.output, this.outputProfile);

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  @override
  final OutputProfile outputProfile;

  @override
  Map<String, String?> get environment => const {};

  final List<String> events = [];

  @override
  bool get supportsRich => false;

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}

/// Renders the emitted transcript as physical terminal lines: a carriage
/// return followed by an erase-line sequence leaves only the rewritten tail of
/// that line, so a repainted editable line is measured once.
Iterable<String> _visibleLines(String text) => text
    .split('\n')
    .map(
      (line) => line
          .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '')
          .split('\r')
          .last,
    )
    .where((line) => line.isNotEmpty);

/// Reassembles text that guidance wrapping split at a display-cell boundary.
/// Wrapping only inserts line breaks, so removing them restores the emitted
/// content and lets a test assert content independently of the declared width.
String _unwrapped(String text) => text.replaceAll('\n', '');

/// A selected output whose shared writer fails on every attempt.
final class _ThrowingSink implements StringSink {
  _ThrowingSink(this.failure);

  final Object failure;

  @override
  void write(Object? object) => throw failure;

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      throw failure;

  @override
  void writeCharCode(int charCode) => throw failure;

  @override
  void writeln([Object? object = '']) => throw failure;
}

void main() {
  test(
    'cron honours declared rich facts and refuses undeclared output',
    () async {
      final output = StringBuffer();
      final rich =
          await CronInput(
            'Schedule',
            profile: CronProfile.unix,
            preview: _config(),
          ).prompt(
            source: ScriptedInput(
              Stream.value('* * * * *\r\t\r\t\r'),
              output,
              supportsRich: false,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((rich as Accepted<CronExpression>).value.expression, '* * * * *');
      expect(output.toString(), contains('Review action: Edit.'));

      expect(
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: _config(),
        ).prompt(
          source: ScriptedInput(Stream.value('* * * * *\r'), StringBuffer()),
          mode: PromptMode.rich,
        ),
        isA<Unavailable<CronExpression>>(),
      );

      final linearOutput = StringBuffer();
      final linear =
          await CronInput(
            'Schedule',
            profile: CronProfile.unix,
            preview: _config(),
          ).prompt(
            source: ScriptedInput(
              Stream.value('* * * * *\r/submit\r'),
              linearOutput,
            ),
            mode: PromptMode.automatic,
          );
      expect(
        (linear as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      expect(linearOutput.toString(), isNot(contains('Review action:')));
    },
  );

  test('cron acquires and restores an explicit terminal adapter', () async {
    final output = StringBuffer();
    final terminal = _FakeTerminal(
      Stream.value('* * * * *\r/submit\r'),
      output,
      _richProfile,
    );
    final result = await CronInput(
      'Schedule',
      profile: CronProfile.unix,
      preview: _config(),
    ).prompt(terminal: terminal, mode: PromptMode.linear);

    expect((result as Accepted<CronExpression>).value.expression, '* * * * *');
    expect(terminal.events, ['acquire', 'restore']);
  });

  test(
    'cron inherits an attached session and rejects competing input',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      addTearDown(input.close);

      final pending = TerminalSession.run(
        (session) async {
          await expectLater(
            CronInput(
              'Schedule',
              profile: CronProfile.unix,
              preview: _config(),
            ).prompt(
              session: session,
              source: ScriptedInput(Stream.value('\x03'), StringBuffer()),
            ),
            throwsArgumentError,
          );
          return await CronInput(
            'Schedule',
            profile: CronProfile.unix,
            preview: _config(),
          ).prompt(session: session);
        },
        source: ScriptedInput(
          input.stream,
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );

      await pumpEventQueue();
      input.add('* * * * *\r\t\r\t\r');
      expect(
        (await pending as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      expect(output.toString(), contains('Review action: Edit.'));
    },
  );

  test('cron rich entry help leads with the dialect and its limits', () async {
    final output = StringBuffer();
    final result =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: _config(),
        ).prompt(
          source: ScriptedInput(
            Stream.value('* * *\x14\x1b\x03'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(result, isA<Interrupted<CronExpression>>());
    final text = _unwrapped(output.toString());
    expect(text, contains('Help: Entering the expression'));
    expect(text, contains('five fields'));
    expect(text, contains('4096 UTF-16 code units'));
    expect(text, contains('Ctrl+T opens help'));
    expect(text, contains('not scheduler execution'));
    expect(text, contains('Etc/UTC'));
  });

  test('cron linear entry help keeps the command workflow', () async {
    final output = StringBuffer();
    final result =
        await CronInput(
          'Schedule',
          profile: CronProfile.quartz,
          preview: _config(),
        ).prompt(
          source: ScriptedInput(Stream.value('/help\r/cancel\r'), output),
          mode: PromptMode.linear,
        );
    expect(result, isA<Cancelled<CronExpression>>());
    final text = _unwrapped(output.toString());
    expect(text, contains('Help: Entering the expression'));
    expect(text, contains('six fields'));
    expect(text, contains('/cancel'));
    expect(text, contains('Identified paste is literal'));
    expect(text, contains('not scheduler execution'));

    // A stray Ctrl+T in linear mode must not show rich-worded guidance.
    final ctrlOutput = StringBuffer();
    final interrupted =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: _config(),
        ).prompt(
          source: ScriptedInput(Stream.value('\x14\x03'), ctrlOutput),
          mode: PromptMode.linear,
        );
    expect(interrupted, isA<Interrupted<CronExpression>>());
    expect(
      _unwrapped(ctrlOutput.toString()),
      contains('Exact /help and /cancel are commands'),
    );
    expect(ctrlOutput.toString(), isNot(contains('Tab or Shift-Tab')));
  });

  test('cron rich review help names the focused action', () async {
    final output = StringBuffer();
    final result =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: _config(),
        ).prompt(
          source: ScriptedInput(
            Stream.value('* * * * *\r\t\x14\x1b\x03'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(result, isA<Interrupted<CronExpression>>());
    final text = _unwrapped(output.toString());
    expect(text, contains('Help: Reviewing the retained expression'));
    expect(text, contains('Edit, Preview and Submit'));
    expect(text, contains('Tab or Shift-Tab changes action'));
    // The focused review action stays visible on the editor line rather than
    // being restated inside help, which cannot change while help is open.
    expect(output.toString(), contains('Review action: Preview.'));
    expect(text, contains('not scheduler execution'));
  });

  test('cron linear review help keeps the exact commands', () async {
    final output = StringBuffer();
    final result =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: _config(),
        ).prompt(
          source: ScriptedInput(
            Stream.value('* * * * *\r/help\r/cancel\r'),
            output,
          ),
          mode: PromptMode.linear,
        );
    expect(result, isA<Cancelled<CronExpression>>());
    final text = _unwrapped(output.toString());
    expect(text, contains('Help: Reviewing the retained expression'));
    expect(text, contains('/preview'));
    expect(text, contains('/edit'));
    expect(text, contains('/submit'));
    expect(text, contains('not scheduler execution'));
  });

  test('cron shares one session with coordinated background updates', () async {
    final output = StringBuffer();
    final input = StreamController<String>();

    final pending = TerminalSession.run(
      (session) async {
        final spinner = Spinner('Schedule');
        spinner.start(session: session);
        final answer = CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: _config(),
        ).prompt(session: session);
        await pumpEventQueue();
        spinner.update('reading expression');
        await pumpEventQueue();
        input.add('* * * * *\r');
        await pumpEventQueue();
        spinner.update('reviewing');
        await pumpEventQueue();
        input.add('\t\r\t\r');
        await input.close();
        final result = await answer;
        spinner.finish(FeedbackOutcome.completed);
        return result;
      },
      source: ScriptedInput(input.stream, output, outputProfile: _richProfile),
      mode: PromptMode.rich,
    );

    expect(
      (await pending as Accepted<CronExpression>).value.expression,
      '* * * * *',
    );
    final text = output.toString();
    expect(text, contains('[status] Schedule: reading expression'));
    expect(text, contains('[status] Schedule: reviewing'));
    expect(text, contains('Matching preview: complete'));
    // Each background update is followed by a repaint of the retained review
    // editor, so the draft never depends on the last status write.
    final reviewing = text.indexOf('[status] Schedule: reviewing');
    expect(text.substring(reviewing), contains('\r\x1b[2K> '));
  });

  test(
    'cron repaints at new idle geometry without changing the draft',
    () async {
      final keys = StreamController<String>();
      var watcherCancelled = false;
      final resized = StreamController<void>.broadcast(
        onCancel: () => watcherCancelled = true,
      );
      final output = StringBuffer();
      final observer = _ResizeObserver(
        resized.stream,
        () => (columns: 14, rows: 5),
      );

      final pending =
          CronInput(
            'Schedule',
            profile: CronProfile.unix,
            preview: _config(),
          ).prompt(
            source: ScriptedInput(
              keys.stream,
              output,
              outputProfile: _richProfile,
              resizeObserver: observer,
            ),
            mode: PromptMode.rich,
          );
      await pumpEventQueue();
      keys.add('* * * * *');
      await pumpEventQueue();
      final beforeResize = output.length;

      resized.add(null);
      await pumpEventQueue();

      // A resize is a repaint only: the retained draft stays in the prompt and
      // the editable line is redrawn inside the observed width.
      expect(output.length, greaterThan(beforeResize));
      final tail = _visibleLines(output.toString().substring(beforeResize));
      expect(tail.join(), contains('> * * * * *'));
      for (final line in tail) {
        expect(line.length, lessThanOrEqualTo(14));
      }

      keys.add('\r\t\r\t\r');
      expect(
        (await pending as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      await keys.close();
      await resized.close();
      expect(watcherCancelled, isTrue);
    },
  );

  test('cron keeps a failed shared writer and retires the session', () async {
    final failure = StateError('shared writer failed');
    final output = _ThrowingSink(failure);
    final input = StreamController<String>();
    late TerminalSession closed;

    await expectLater(
      TerminalSession.run(
        (session) {
          closed = session;
          return CronInput(
            'Schedule',
            profile: CronProfile.unix,
            preview: _config(),
          ).prompt(session: session);
        },
        source: ScriptedInput(
          input.stream,
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      throwsA(same(failure)),
    );
    // A retired scope cannot revive a registration after the writer failed.
    expect(() => Spinner('Late').start(session: closed), throwsStateError);
    await input.close();
  });

  test('cron edit stage retains the expression and resubmits it', () async {
    final richOutput = StringBuffer();
    final rich =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: _config(),
        ).prompt(
          source: ScriptedInput(
            Stream.value('* * * * *\r\r\r\t\t\r'),
            richOutput,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((rich as Accepted<CronExpression>).value.expression, '* * * * *');
    // The Edit action returns to the entry stage with the retained draft and
    // the expression is reviewed again before it is accepted.
    expect('Review: * * * * *.'.allMatches(richOutput.toString()).length, 2);

    final linearOutput = StringBuffer();
    final linear =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: _config(),
        ).prompt(
          source: ScriptedInput(
            Stream.value('* * * * *\r/edit\r\r/submit\r'),
            linearOutput,
          ),
          mode: PromptMode.linear,
        );
    expect((linear as Accepted<CronExpression>).value.expression, '* * * * *');
    // /edit returns to the entry stage, which keeps the retained draft and
    // submits it again on Enter before /submit accepts it.
    expect(
      _unwrapped(linearOutput.toString()),
      contains('Current text: * * * * *'),
    );
    expect(linearOutput.toString(), isNot(contains('Invalid cron')));
  });

  test('cron keeps every explicit outcome in both modes', () async {
    CronInput input() =>
        CronInput('Schedule', profile: CronProfile.unix, preview: _config());

    Future<PromptResult<CronExpression>> run(String keys, PromptMode mode) =>
        input().prompt(
          source: ScriptedInput(
            Stream.value(keys),
            StringBuffer(),
            outputProfile: mode == PromptMode.rich
                ? _richProfile
                : const OutputProfile(),
          ),
          mode: mode,
        );

    expect(
      await run('\x1bx', PromptMode.rich),
      isA<Cancelled<CronExpression>>(),
    );
    expect(
      await run('/cancel\r', PromptMode.linear),
      isA<Cancelled<CronExpression>>(),
    );
    expect(
      await run('\x03', PromptMode.rich),
      isA<Interrupted<CronExpression>>(),
    );
    expect(
      await run('\x03', PromptMode.linear),
      isA<Interrupted<CronExpression>>(),
    );
    expect(await run('', PromptMode.rich), isA<InputEnded<CronExpression>>());
    expect(
      await run('* * * * *\r', PromptMode.linear),
      isA<InputEnded<CronExpression>>(),
    );

    // An unsupported source and an invalid supplied answer stay explicit
    // failures instead of becoming accepted expressions.
    expect(
      await input().prompt(source: SuppliedTags(const [])),
      isA<Unavailable<CronExpression>>(),
    );
    expect(
      await input().prompt(source: SuppliedAnswer('@daily')),
      isA<Unavailable<CronExpression>>(),
    );
    final supplied = await input().prompt(
      source: SuppliedAnswer('0 0 * * *'),
    ) as Accepted<CronExpression>;
    expect(supplied.value.expression, '0 0 * * *');
    expect(supplied.value.profile, CronProfile.unix);
    final quartz = await CronInput(
      'Schedule',
      profile: CronProfile.quartz,
      preview: _config(),
    ).prompt(source: SuppliedAnswer('0 0 12 ? * MON'));
    expect(
      (quartz as Accepted<CronExpression>).value.profile,
      CronProfile.quartz,
    );
  });

  test('cron guidance wraps inside a narrow declared width', () async {
    final narrow = OutputProfile(
      cursor: CapabilitySupport.supported,
      colorDepth: ColorDepth.none,
      geometry: OutputGeometry.fixed(columns: 20, rows: 6),
    );
    final emptyConfig = CronPreviewConfig(
      providerTimeout: const Duration(seconds: 5),
      zone: 'Etc/UTC',
      reference: DateTime.utc(2024),
      start: DateTime.utc(2024),
      end: DateTime.utc(2024),
      count: 1,
      budget: 1,
    );

    final richOutput = StringBuffer();
    final rich =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: emptyConfig,
        ).prompt(
          source: ScriptedInput(
            Stream.value('0 0 31 2 *\r\t\r\x03'),
            richOutput,
            outputProfile: narrow,
          ),
          mode: PromptMode.rich,
        );
    expect(rich, isA<Interrupted<CronExpression>>());
    final richText = richOutput.toString();
    for (final line in _visibleLines(richText)) {
      expect(
        line.length,
        lessThanOrEqualTo(20),
        reason: 'rich line exceeds the declared width: "$line"',
      );
    }
    expect(_unwrapped(richText), contains('horizonReached'));

    final linearOutput = StringBuffer();
    final linear =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: emptyConfig,
        ).prompt(
          source: ScriptedInput(
            Stream.value('0 0 31 2 *\r/submit\r'),
            linearOutput,
            outputProfile: narrow,
          ),
          mode: PromptMode.linear,
        );
    expect((linear as Accepted<CronExpression>).value.expression, '0 0 31 2 *');
    final linearGuidance = _visibleLines(linearOutput.toString())
        .takeWhile((line) => !line.startsWith('Current text:'));
    final joined = linearGuidance.join();
    expect(joined, contains('Enter an expression, then /preview'));
    expect(joined, contains('/help opens help'));
    for (final line in linearGuidance) {
      expect(
        line.length,
        lessThanOrEqualTo(20),
        reason: 'linear guidance exceeds the declared width: "$line"',
      );
    }
  });
}
