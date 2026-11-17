import 'dart:async';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

void main() {
  test('Confirm shortcut changes draft; Enter submits', () async {
    final output = StringBuffer();
    final result = await Confirm('Proceed?').prompt(
      source: ScriptedInput(
        Stream.value('y\r'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<bool>).value, isTrue);
    expect(output.toString(), contains('No'));
    expect(output.toString(), contains('Yes'));
  });
  test('rich draft changes alone do not submit', () async {
    for (final run in <Future<PromptResult<bool>> Function()>[
      () => Confirm('Confirm').prompt(
        source: ScriptedInput(
          Stream.value('y'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      () => Checkbox('Check').prompt(
        source: ScriptedInput(
          Stream.value(' '),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      () => Toggle('Toggle').prompt(
        source: ScriptedInput(
          Stream.value(' '),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
    ]) {
      expect(await run(), isA<InputEnded<bool>>());
    }
  });
  test('checkbox and toggle announce state and submit only on Enter', () async {
    for (final prompt in [Checkbox('Check').prompt, Toggle('Switch').prompt]) {
      final output = StringBuffer();
      final result = await prompt(
        source: ScriptedInput(
          Stream.value(' \r'),
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<bool>).value, isTrue);
      expect(output.toString(), anyOf(contains('unchecked'), contains('off')));
      expect(output.toString(), anyOf(contains('checked'), contains('on')));
    }
  });
  test('linear answers and empty lines use explicit defaults', () async {
    for (final prompt in [
      Confirm('Confirm', initialValue: true).prompt,
      Checkbox('Check', initialValue: true).prompt,
      Toggle('Switch', initialValue: true).prompt,
    ]) {
      final out = StringBuffer();
      expect(
        (await prompt(
          source: ScriptedInput(Stream.value('\r'), out),
          mode: PromptMode.linear,
        ) as Accepted<bool>).value,
        isTrue,
      );
      expect(out.toString(), contains('Default:'));
      expect(
        (await prompt(
          source: ScriptedInput(Stream.value('no\r'), StringBuffer()),
          mode: PromptMode.linear,
        ) as Accepted<bool>).value,
        isFalse,
      );
      expect(
        await prompt(
          source: ScriptedInput(Stream.value(''), StringBuffer()),
          mode: PromptMode.linear,
        ),
        isA<InputEnded<bool>>(),
      );
    }
  });
  test('linear commands, literals and interruption remain distinct', () async {
    Future<PromptResult<bool>> run(String input) => Confirm('Confirm').prompt(
      source: ScriptedInput(Stream.value(input), StringBuffer()),
      mode: PromptMode.linear,
    );
    expect(await run('/cancel\r'), isA<Cancelled<bool>>());
    expect(await run('/cancel'), isA<InputEnded<bool>>());
    expect(await run('\x03'), isA<Interrupted<bool>>());
    expect(await run('\x1b[200~/cancel\x1b[201~\r'), isA<InputEnded<bool>>());
    expect((await run('/help\ryes\r') as Accepted<bool>).value, isTrue);
  });
  test('invalid linear input is retained and can be corrected', () async {
    final output = StringBuffer();
    final result = await Confirm('Proceed').prompt(
      source: ScriptedInput(Stream.value('x\r\x7fyes\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<bool>).value, isTrue);
    expect(output.toString(), contains('Current text: x'));
    expect(output.toString(), contains('Enter yes/y or no/n'));
  });
  test('rich cancellation and configured default are distinct', () async {
    final output = StringBuffer();
    final prompt = Confirm('Proceed', initialValue: true);
    final result = await prompt.prompt(
      source: ScriptedInput(
        Stream.value('n\x03'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(result, isA<Interrupted<bool>>());
    expect(output.toString(), contains('Default: Yes'));
    expect(
      await prompt.prompt(
        source: ScriptedInput(
          Stream.value('\r'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<Accepted<bool>>().having((x) => x.value, 'value', isTrue),
    );
    expect(
      await prompt.prompt(
        source: ScriptedInput(
          Stream.value('\x1bx'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<Cancelled<bool>>(),
    );
  });
  test(
    'supplied values are literal and capability failures do not render',
    () async {
      final prompt = Toggle('Switch');
      expect(
        (await prompt.prompt(
          source: SuppliedAnswer('yes'),
        ) as Accepted<bool>).value,
        isTrue,
      );
      expect(
        await prompt.prompt(source: SuppliedAnswer('/cancel')),
        isA<Unavailable<bool>>(),
      );
      final out = StringBuffer();
      expect(
        await prompt.prompt(
          source: ScriptedInput(Stream.value('\r'), out, supportsRich: false),
          mode: PromptMode.rich,
        ),
        isA<Unavailable<bool>>(),
      );
      expect(out.toString(), isEmpty);
    },
  );
  test(
    'boolean help keeps kind-specific controls and linear defaults reviewable',
    () async {
      final linearOutput = StringBuffer();
      final linear = await Checkbox('Terms', initialValue: true).prompt(
        source: ScriptedInput(Stream.value('/help\r\r'), linearOutput),
        mode: PromptMode.linear,
      );

      expect((linear as Accepted<bool>).value, isTrue);
      expect(linearOutput.toString(), contains('Checkbox'));
      expect(linearOutput.toString(), contains('empty line'));
      expect(linearOutput.toString(), contains('displayed default'));
      expect(linearOutput.toString(), contains('backslash'));

      final richOutput = StringBuffer();
      final rich = await Toggle('Cache', initialValue: true).prompt(
        source: ScriptedInput(
          Stream.value('\x14\x1b \r'),
          richOutput,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );

      expect((rich as Accepted<bool>).value, isFalse);
      expect(richOutput.toString(), contains('Space toggles the draft'));
      expect(richOutput.toString(), contains('Default: on'));
      expect(richOutput.toString(), contains('Draft: off'));
    },
  );

  test(
    'boolean prompts forward declared rich output profiles and terminal leases',
    () async {
      final profile = OutputProfile(
        cursor: CapabilitySupport.supported,
        geometry: OutputGeometry.fixed(columns: 80, rows: 24),
      );
      final declaredOutput = StringBuffer();
      final declared = await Confirm('Deploy').prompt(
        source: ScriptedInput(
          Stream.value('y\r'),
          declaredOutput,
          supportsRich: false,
        ),
        outputProfile: profile,
        mode: PromptMode.rich,
      );
      expect((declared as Accepted<bool>).value, isTrue);

      final terminalOutput = StringBuffer();
      final terminal = _BooleanTerminal(
        Stream.value(' \r'),
        terminalOutput,
        profile,
      );
      final terminalResult = await Checkbox('Terms')
          .prompt(terminal: terminal, mode: PromptMode.rich);
      expect((terminalResult as Accepted<bool>).value, isTrue);
      expect(terminal.events, ['acquire', 'restore']);
    },
  );

  test(
    'boolean prompts apply palette colours only to capable outputs',
    () async {
      final palette = ColorTheme(
        foreground: TerminalColor.rgb(1, 2, 3),
        background: TerminalColor.rgb(4, 5, 6),
        muted: TerminalColor.indexed(7),
        accent: TerminalColor.indexed(8),
        selectionForeground: TerminalColor.indexed(9),
        selectionBackground: TerminalColor.indexed(10),
        success: TerminalColor.indexed(11),
        warning: TerminalColor.indexed(12),
        error: TerminalColor.indexed(13),
        border: TerminalColor.indexed(14),
      );
      final profile = OutputProfile(
        cursor: CapabilitySupport.supported,
        colorDepth: ColorDepth.rgb,
        geometry: OutputGeometry.fixed(columns: 80, rows: 24),
      );
      final coloredOutput = StringBuffer();
      await Confirm('Deploy', colors: palette).prompt(
        source: ScriptedInput(Stream.value('y\r'), coloredOutput),
        outputProfile: profile,
        mode: PromptMode.rich,
      );
      expect(coloredOutput.toString(), contains('\x1b[38;2;1;2;3;48;2;4;5;6m'));
      expect(coloredOutput.toString(), contains('\x1b[0m'));

      final noColorOutput = StringBuffer();
      await Confirm('Deploy', colors: palette).prompt(
        terminal: _BooleanTerminal(
          Stream.value('y\r'),
          noColorOutput,
          profile,
          environment: const {'NO_COLOR': '1'},
        ),
        mode: PromptMode.rich,
      );
      expect(noColorOutput.toString(), contains('Deploy'));
      expect(noColorOutput.toString(), isNot(contains('\x1b[38;')));
    },
  );

  test(
    'a boolean prompt shares rich session feedback without losing its draft',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      final profile = OutputProfile(
        cursor: CapabilitySupport.supported,
        geometry: OutputGeometry.fixed(columns: 80, rows: 24),
      );

      final result = await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Policy');
          spinner.start(session: session);
          final pending = Toggle('Cache').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          input.add(' ');
          await Future<void>.delayed(Duration.zero);
          spinner.update('checking');
          input.add('\r');
          await input.close();
          spinner.finish(FeedbackOutcome.completed);
          return await pending;
        },
        source: ScriptedInput(input.stream, output, outputProfile: profile),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<bool>).value, isTrue);
      expect(output.toString(), contains('[status] Policy: checking'));
      expect(output.toString(), contains('Draft: off'));
      expect(output.toString(), contains('Draft: on'));
      expect(output.toString(), contains('Accepted: on'));
    },
  );
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

final class _BooleanTerminal implements TerminalIo, TerminalIoOutputProfile {
  _BooleanTerminal(
    this.input,
    this.output,
    this.outputProfile, {
    this.environment = const {},
  });

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  @override
  final OutputProfile outputProfile;

  @override
  bool get supportsRich => false;

  final List<String> events = [];

  @override
  final Map<String, String?> environment;

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}
