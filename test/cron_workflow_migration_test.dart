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
