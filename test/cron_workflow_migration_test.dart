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

void main() {
  test('cron honours declared rich facts and refuses undeclared output', () async {
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
    expect(
      (rich as Accepted<CronExpression>).value.expression,
      '* * * * *',
    );
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
  });

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

  test('cron inherits an attached session and rejects competing input', () async {
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
      source: ScriptedInput(input.stream, output, outputProfile: _richProfile),
      mode: PromptMode.rich,
    );

    await pumpEventQueue();
    input.add('* * * * *\r\t\r\t\r');
    expect(
      (await pending as Accepted<CronExpression>).value.expression,
      '* * * * *',
    );
    expect(output.toString(), contains('Review action: Edit.'));
  });
}
