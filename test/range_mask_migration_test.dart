import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 40, rows: 8),
);

final _narrowProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 18, rows: 6),
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

void main() {
  test(
    'slider honours declared rich facts and refuses undeclared rich output',
    () async {
      final output = StringBuffer();
      final accepted =
          await Slider(
            'Volume',
            minimum: '0',
            maximum: '10',
            step: '1',
            initialValue: '2',
          ).prompt(
            source: ScriptedInput(
              Stream.value('\t\t\r'),
              output,
              supportsRich: false,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((accepted as Accepted<String>).value, '2');

      expect(
        await Slider('Volume', minimum: '0', maximum: '10', step: '1').prompt(
          source: ScriptedInput(Stream.value('\t\t\r'), StringBuffer()),
          mode: PromptMode.rich,
        ),
        isA<Unavailable<String>>(),
      );

      final linearOutput = StringBuffer();
      final linear =
          await Slider('Volume', minimum: '0', maximum: '10', step: '1').prompt(
            source: ScriptedInput(Stream.value('3\r'), linearOutput),
            mode: PromptMode.automatic,
          );
      expect((linear as Accepted<String>).value, '3');
      expect(linearOutput.toString(), isNot(contains('Focus:')));
    },
  );

  test('slider rich help leads with the focused control', () async {
    final output = StringBuffer();
    await Slider('Volume', minimum: '0', maximum: '1', step: '0.2').prompt(
      source: ScriptedInput(
        Stream.value('\x14\x1b\t\x14\x1b\t\x14\x1b\x03'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    final text = output.toString();
    expect(text, contains('Help: Adjusting the value'));
    expect(text, contains('Help: Editing the value'));
    expect(text, contains('Help: Submit'));
    // Every help block keeps the bounds, step and accepted format available.
    expect(text, contains('on the 0.2 grid'));
    expect(text, contains('between 0 and 1'));
  });

  test('slider linear help names the exact bounds and step', () async {
    final output = StringBuffer();
    final result =
        await Slider(
          'Level',
          minimum: '0',
          maximum: '1',
          step: '0.1',
          precision: 1,
          units: 'dB',
        ).prompt(
          source: ScriptedInput(Stream.value('/help\r/cancel\r'), output),
          mode: PromptMode.linear,
        );
    expect(result, isA<Cancelled<String>>());
    final text = output.toString();
    expect(text, contains('Help: Entering the value'));
    expect(text, contains('units dB'));
    expect(text, contains('maximum 1 decimal place'));
    expect(text, contains('/cancel cancels'));
  });

  test('narrow slider guidance wraps inside the declared width', () async {
    for (final mode in [PromptMode.rich, PromptMode.linear]) {
      final output = StringBuffer();
      final result =
          await Slider(
            'Volume',
            minimum: '0',
            maximum: '10',
            step: '1',
            units: 'dB',
            initialValue: '4',
          ).prompt(
            source: ScriptedInput(
              Stream.value(mode == PromptMode.rich ? '\t\t\r' : '\r'),
              output,
              outputProfile: _narrowProfile,
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, '4');
      final lines = _visibleLines(output.toString()).toList();
      for (final line in lines) {
        expect(
          line.length,
          lessThanOrEqualTo(18),
          reason: '${mode.name} line exceeds the declared width: "$line"',
        );
      }
      expect(lines.join(), contains('units dB'));
      expect(
        lines.join(),
        contains(
          mode == PromptMode.rich
              ? 'Enter activates Edit or Submit'
              : 'Enter an exact value, then submit',
        ),
      );
    }
  });

  test(
    'slider repaints at new idle geometry without changing the draft',
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
          Slider(
            'Volume',
            minimum: '0',
            maximum: '10',
            step: '1',
            initialValue: '4',
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
      keys.add('\x1b[C');
      await pumpEventQueue();
      final beforeResize = output.length;

      resized.add(null);
      await pumpEventQueue();

      // A resize is a repaint only: the adjusted draft stays in the prompt and
      // the guidance is redrawn inside the observed width.
      expect(output.length, greaterThan(beforeResize));
      final tail = _visibleLines(output.toString().substring(beforeResize))
          .toList();
      expect(tail.join(), contains('Focus: Slider'));
      for (final line in tail) {
        expect(line.length, lessThanOrEqualTo(14));
      }

      keys.add('\t\t\r');
      expect((await pending as Accepted<String>).value, '5');
      await keys.close();
      await resized.close();
      expect(watcherCancelled, isTrue);
    },
  );

  test('slider shares one session with coordinated feedback', () async {
    final output = StringBuffer();
    final input = StreamController<String>();

    final result = await TerminalSession.run(
      (session) async {
        final spinner = Spinner('Volume');
        spinner.start(session: session);
        final pending = Slider(
          'Level',
          minimum: '0',
          maximum: '1',
          step: '0.1',
          initialValue: '0.2',
        ).prompt(session: session);
        await pumpEventQueue();
        spinner.update('checking');
        await pumpEventQueue();
        input.add('\x1b[C\t\t\r');
        await input.close();
        final answer = await pending;
        spinner.finish(FeedbackOutcome.completed);
        return answer;
      },
      source: ScriptedInput(input.stream, output, outputProfile: _richProfile),
      mode: PromptMode.rich,
    );

    expect((result as Accepted<String>).value, '0.3');
    expect(output.toString(), contains('[status] Volume: checking'));
    expect(output.toString(), contains('Focus: Submit'));
  });

  test('slider acquires and restores an explicit terminal adapter', () async {
    final output = StringBuffer();
    final terminal = _FakeTerminal(Stream.value('2\r'), output, _richProfile);
    final result = await Slider(
      'Level',
      minimum: '0',
      maximum: '10',
      step: '1',
    ).prompt(terminal: terminal, mode: PromptMode.linear);

    expect((result as Accepted<String>).value, '2');
    expect(terminal.events, ['acquire', 'restore']);
  });

  test(
    'range honours declared rich facts and refuses undeclared rich output',
    () async {
      final output = StringBuffer();
      final rich =
          await RangeSlider(
            'Window',
            minimum: '0',
            maximum: '10',
            step: '1',
            minimumGap: '2',
            initialLower: '3',
            initialUpper: '5',
          ).prompt(
            source: ScriptedInput(
              Stream.value('\t\t\t\t\r'),
              output,
              supportsRich: false,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((rich as Accepted<(String, String)>).value, ('3', '5'));

      expect(
        await RangeSlider(
          'Window',
          minimum: '0',
          maximum: '10',
          step: '1',
        ).prompt(
          source: ScriptedInput(Stream.value('\t\t\t\t\r'), StringBuffer()),
          mode: PromptMode.rich,
        ),
        isA<Unavailable<(String, String)>>(),
      );

      final linear =
          await RangeSlider(
            'Window',
            minimum: '0',
            maximum: '10',
            step: '1',
          ).prompt(
            source: ScriptedInput(Stream.value('3\r5\r\r'), StringBuffer()),
            mode: PromptMode.automatic,
          );
      expect((linear as Accepted<(String, String)>).value, ('3', '5'));
    },
  );

  test('range help names the endpoints, gap and pair review', () async {
    final output = StringBuffer();
    await RangeSlider(
      'Window',
      minimum: '0',
      maximum: '10',
      step: '1',
      minimumGap: '2',
    ).prompt(
      source: ScriptedInput(
        Stream.value('\x14\x1b\t\x14\x1b\x03'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    final rich = _visibleLines(output.toString()).join();
    expect(rich, contains('Help: Adjusting the Lower endpoint'));
    expect(rich, contains('Help: Adjusting the Upper endpoint'));
    expect(rich, contains('minimum gap 2'));
    expect(rich, contains('pair is reviewed'));

    final linearOutput = StringBuffer();
    final linear =
        await RangeSlider(
          'Window',
          minimum: '0',
          maximum: '10',
          step: '1',
          minimumGap: '2',
        ).prompt(
          source: ScriptedInput(Stream.value('/help\r/cancel\r'), linearOutput),
          mode: PromptMode.linear,
        );
    expect(linear, isA<Cancelled<(String, String)>>());
    final linearText = _visibleLines(linearOutput.toString()).join();
    expect(linearText, contains('Help: Entering the endpoints'));
    expect(linearText, contains('minimum gap 2'));
  });

  test('narrow range guidance wraps and keeps the endpoint caret', () async {
    for (final mode in [PromptMode.rich, PromptMode.linear]) {
      final output = StringBuffer();
      final result =
          await RangeSlider(
            'Window',
            minimum: '0',
            maximum: '10',
            step: '1',
            precision: 0,
            initialLower: '3',
            initialUpper: '5',
          ).prompt(
            source: ScriptedInput(
              Stream.value(mode == PromptMode.rich ? '\t\t\t\t\r' : '\r\r\r'),
              output,
              outputProfile: _narrowProfile,
            ),
            mode: mode,
          );
      expect((result as Accepted<(String, String)>).value, ('3', '5'));
      final lines = _visibleLines(output.toString()).toList();
      for (final line in lines) {
        expect(
          line.length,
          lessThanOrEqualTo(18),
          reason: '${mode.name} line exceeds the declared width: "$line"',
        );
      }
      expect(lines.join(), contains('Lower: 3'));
      expect(lines.join(), contains('Upper: 5'));
    }
  });

  test('rich range keeps endpoint roles and the minimum gap', () async {
    final output = StringBuffer();
    final result =
        await RangeSlider(
          'Window',
          minimum: '0',
          maximum: '10',
          step: '1',
          minimumGap: '2',
          initialLower: '3',
          initialUpper: '5',
        ).prompt(
          source: ScriptedInput(
            // Up on Lower would cross the gap boundary and is refused; Down then
            // moves only that endpoint, so the Upper role and its value survive.
            Stream.value('\x1b[A\x1b[B\t\x1b[B\t\t\t\r'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<(String, String)>).value, ('2', '4'));
    final lines = _visibleLines(output.toString()).join();
    expect(lines, contains('Lower: 3; Upper: 5'));
    expect(lines, contains('Lower: 2; Upper: 5'));
    expect(lines, isNot(contains('Lower: 4')));
  });

  test(
    'rich range repaints at new idle geometry without accepting the pair',
    () async {
      final keys = StreamController<String>();
      var watcherCancelled = false;
      final resized = StreamController<void>.broadcast(
        onCancel: () => watcherCancelled = true,
      );
      final output = StringBuffer();
      final observer = _ResizeObserver(
        resized.stream,
        () => (columns: 16, rows: 6),
      );

      final pending =
          RangeSlider(
            'Window',
            minimum: '0',
            maximum: '10',
            step: '1',
            initialLower: '3',
            initialUpper: '5',
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
      keys.add('\t');
      await pumpEventQueue();
      final beforeResize = output.length;

      resized.add(null);
      await pumpEventQueue();

      var completed = false;
      unawaited(pending.then((_) => completed = true));
      expect(output.length, greaterThan(beforeResize));
      final tail = _visibleLines(output.toString().substring(beforeResize))
          .toList();
      expect(tail.join(), contains('Focus: Upper'));
      for (final line in tail) {
        expect(line.length, lessThanOrEqualTo(16));
      }
      await pumpEventQueue();
      expect(completed, isFalse, reason: 'a repaint must not submit the pair');

      keys.add('\t\t\t\r');
      expect((await pending as Accepted<(String, String)>).value, ('3', '5'));
      await keys.close();
      await resized.close();
      expect(watcherCancelled, isTrue);
    },
  );

  test('range shares one session with coordinated feedback', () async {
    final output = StringBuffer();
    final input = StreamController<String>();

    final result = await TerminalSession.run(
      (session) async {
        final spinner = Spinner('Window');
        spinner.start(session: session);
        final pending = RangeSlider(
          'Window',
          minimum: '0',
          maximum: '10',
          step: '1',
          initialLower: '3',
          initialUpper: '5',
        ).prompt(session: session);
        await pumpEventQueue();
        spinner.update('checking');
        await pumpEventQueue();
        input.add('\t\t\t\t\r');
        await input.close();
        final answer = await pending;
        spinner.finish(FeedbackOutcome.completed);
        return answer;
      },
      source: ScriptedInput(input.stream, output, outputProfile: _richProfile),
      mode: PromptMode.rich,
    );

    expect((result as Accepted<(String, String)>).value, ('3', '5'));
    expect(output.toString(), contains('[status] Window: checking'));
    expect(output.toString(), contains('Focus: Submit'));
  });

  test('masked input honours declared rich facts and refuses undeclared rich output', () async {
    MaskedInput code() => MaskedInput(
      'Code',
      templates: [
        MaskTemplate('code', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
          MaskLiteral('-'),
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ],
    );

    final rich = await code().prompt(
      source: ScriptedInput(
        Stream.value('12\r'),
        StringBuffer(),
        supportsRich: false,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((rich as Accepted<MaskedValue>).value.formatted, '1-2');

    expect(
      await code().prompt(
        source: ScriptedInput(Stream.value('12\r'), StringBuffer()),
        mode: PromptMode.rich,
      ),
      isA<Unavailable<MaskedValue>>(),
    );

    final linear = await code().prompt(
      source: ScriptedInput(Stream.value('12\r/done\r'), StringBuffer()),
      mode: PromptMode.automatic,
    );
    expect((linear as Accepted<MaskedValue>).value.formatted, '1-2');
  });

  test('masked input shares one session with coordinated feedback', () async {
    final output = StringBuffer();
    final input = StreamController<String>();

    final result = await TerminalSession.run(
      (session) async {
        final spinner = Spinner('Code');
        spinner.start(session: session);
        final pending = MaskedInput(
          'Code',
          templates: [
            MaskTemplate('code', [
              MaskSlot('digit', (s) => '0123456789'.contains(s)),
              MaskLiteral('-'),
              MaskSlot('digit', (s) => '0123456789'.contains(s)),
            ]),
          ],
        ).prompt(session: session);
        await pumpEventQueue();
        spinner.update('checking');
        await pumpEventQueue();
        input.add('12\r');
        await input.close();
        final answer = await pending;
        spinner.finish(FeedbackOutcome.completed);
        return answer;
      },
      source: ScriptedInput(input.stream, output, outputProfile: _richProfile),
      mode: PromptMode.rich,
    );

    expect((result as Accepted<MaskedValue>).value.formatted, '1-2');
    expect(output.toString(), contains('[status] Code: checking'));
  });

  test(
    'masked input acquires and restores an explicit terminal adapter',
    () async {
      final output = StringBuffer();
      final terminal = _FakeTerminal(
        Stream.value('12\r/done\r'),
        output,
        _richProfile,
      );
      final result = await MaskedInput(
        'Code',
        templates: [
          MaskTemplate('code', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskLiteral('-'),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
        ],
      ).prompt(terminal: terminal, mode: PromptMode.linear);

      expect((result as Accepted<MaskedValue>).value.formatted, '1-2');
      expect(terminal.events, ['acquire', 'restore']);
    },
  );

  test(
    'narrow masked input keeps guidance inside the declared width',
    () async {
      for (final adaptive in [false, true]) {
        final templates = [
          MaskTemplate('pair', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
          if (adaptive)
            MaskTemplate('dash', [
              MaskSlot('digit', (s) => '0123456789'.contains(s)),
              MaskLiteral('-'),
              MaskSlot('digit', (s) => '0123456789'.contains(s)),
            ]),
        ];
        for (final mode in [PromptMode.rich, PromptMode.linear]) {
          final output = StringBuffer();
          final result = await MaskedInput('Code', templates: templates).prompt(
            source: ScriptedInput(
              Stream.value(
                !adaptive
                    ? (mode == PromptMode.rich ? '12\r' : '12\r/done\r')
                    : (mode == PromptMode.rich
                          ? '12\r2\r\r'
                          : '12\r/template\r2\r/done\r'),
              ),
              output,
              outputProfile: _narrowProfile,
            ),
            mode: mode,
          );
          expect(result, isA<Accepted<MaskedValue>>());
          final lines = _visibleLines(output.toString()).toList();
          for (final line in lines) {
            expect(
              line.length,
              lessThanOrEqualTo(18),
              reason:
                  'adaptive=$adaptive ${mode.name} line exceeds the declared '
                  'width: "$line"',
            );
          }
        }
      }
    },
  );
}
