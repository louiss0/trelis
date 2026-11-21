import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart' show ComponentColors;
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_formatted_components.dart';
import 'package:trelis/src/testing/compat_api.dart';

void main() {
  group('theme-owned formatted values', () {
    test(
      'a themed slider keeps exact values, cues and mode-specific hints',
      () async {
        final richOutput = StringBuffer();
        final rich = ThemeFormattedPrompt.slider(
          'Volume',
          minimum: '0',
          maximum: '10',
          step: '1',
          initialValue: '4',
          io: TerminalEnvironment.scripted(
            input: Stream.value('\t\t\r'),
            output: richOutput,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
        );
        expect((await rich.prompt() as Accepted<String>).value, '4');
        final richText = _flatten(richOutput.toString());
        expect(richText, contains('minimum0,maximum10,step1'));
        expect(richText, contains('Ctrl+Topenshelp'));

        final linearOutput = StringBuffer();
        final linear = ThemeFormattedPrompt.slider(
          'Volume',
          minimum: '0',
          maximum: '10',
          step: '1',
          initialValue: '4',
          io: TerminalEnvironment.scripted(
            input: Stream.value('\r'),
            output: linearOutput,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
            environment: const {'NO_COLOR': '1'},
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          instructions: InstructionDisplay.hidden,
        );
        expect((await linear.prompt() as Accepted<String>).value, '4');
        final text = linearOutput.toString();
        expect(text, isNot(contains('\x1b[')));
        final flat = _flatten(text);
        expect(flat, contains('minimum0,maximum10,step1'));
        expect(flat, contains('/helpexplainsthebounds;/cancelcancels.'));
      },
    );

    test(
      'themed text-backed inputs preserve their typed values and hints',
      () async {
        for (final fixture in _textBackedFixtures) {
          final output = StringBuffer();
          final result = await fixture
              .build(
                TerminalEnvironment.scripted(
                  input: Stream.value(fixture.keys),
                  output: output,
                  profile: const OutputProfile(glyphs: GlyphSet.ascii),
                  environment: const {'NO_COLOR': '1'},
                ),
                const InteractionPreferences(mode: PromptMode.linear),
              )
              .prompt();

          fixture.expect(result, fixture.name);
          final text = output.toString();
          expect(text, isNot(contains('\x1b[')), reason: fixture.name);
          expect(
            _flatten(text),
            anyOf(contains('/help'), contains('Ctrl+T')),
            reason: '${fixture.name} must keep the mandatory help route',
          );
        }
      },
    );

    test('themed validation retries keep each domain rule intact', () async {
      final portOutput = StringBuffer();
      final port = await ThemeFormattedPrompt.port(
        'Port',
        io: _linearIo('99999\r${_clearDraft}443\r', portOutput),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      ).prompt();
      expect((port as Accepted<int>).value, 443);
      expect(
        _flatten(portOutput.toString()),
        contains('EnteranASCIIdecimalport'),
      );

      final cronOutput = StringBuffer();
      final cron = await ThemeFormattedPrompt.cron(
        'Schedule',
        io: _linearIo('not-a-cron\r$_clearDraft* * * * *\r', cronOutput),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        profile: CronProfile.unix,
        instructions: InstructionDisplay.hidden,
      ).prompt();
      expect((cron as Accepted<CronExpression>).value.expression, '* * * * *');
      expect(
        cronOutput.toString(),
        contains('Invalid or unsupported cron expression'),
      );

      final colorOutput = StringBuffer();
      final color = await ThemeFormattedPrompt.color(
        'Tint',
        io: _linearIo('not-a-color\r$_clearDraft#f00\r', colorOutput),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      ).prompt();
      expect((color as Accepted<ColorValue?>).value?.source, '#f00');
      expect(colorOutput.toString(), contains('Enter a valid sRGB color'));
    });

    test(
      'a themed cron prompt computes its bounded matching preview',
      () async {
        final output = StringBuffer();
        final result = await ThemeFormattedPrompt.cron(
          'Schedule',
          io: _linearIo('* * * * *\r/preview\r/submit\r', output),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          profile: CronProfile.unix,
          preview: _cronPreviewConfig(),
        ).prompt();

        expect(
          (result as Accepted<CronExpression>).value.expression,
          '* * * * *',
        );
        expect(output.toString(), contains('Matching preview: complete'));
      },
    );

    test(
      'themed timezone selection explains unavailable zone reasons',
      () async {
        final output = StringBuffer();
        final result = await ThemeFormattedPrompt.timezone(
          'Zone',
          io: TerminalEnvironment.scripted(
            input: Stream.value('\r'),
            output: output,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          defaultValue: 'US/Eastern',
          unavailable: const {'America/New_York': 'not supported'},
        ).prompt();

        expect(result, isA<InputEnded<String>>());
        expect(output.toString(), contains('not supported'));
      },
    );

    test(
      'component colours and narrow monochrome output stay readable',
      () async {
        final palette = ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(200, 100, 50),
        );
        final coloured = StringBuffer();
        await ThemeFormattedPrompt.port(
          'Port',
          io: TerminalEnvironment.scripted(
            input: Stream.value('443\r'),
            output: coloured,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          colors: ComponentColors.palette(palette),
        ).prompt();
        expect(coloured.toString(), contains('\x1b[38;2;200;100;50;'));

        final narrow = OutputProfile(
          glyphs: GlyphSet.ascii,
          geometry: OutputGeometry.fixed(columns: 18, rows: 6),
        );
        final output = StringBuffer();
        final result = await ThemeFormattedPrompt.port(
          'Port',
          io: TerminalEnvironment.scripted(
            input: Stream.value('443\r'),
            output: output,
            profile: narrow,
            environment: const {'NO_COLOR': '1'},
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          instructions: InstructionDisplay.hidden,
        ).prompt();
        expect((result as Accepted<int>).value, 443);
        final text = output.toString();
        expect(text, isNot(contains('\x1b[')));
        expect(_flatten(text), contains('ASCIIdecimal'));
        expect(_flatten(text), contains('/help'));
        for (final line in _visibleLines(text)) {
          expect(line.length, lessThanOrEqualTo(18), reason: line);
        }
      },
    );

    test('live feedback shares the themed prompt period', () async {
      var cancellations = 0;
      final input = StreamController<String>(onCancel: () => cancellations++);
      final output = StringBuffer();
      final prompt = ThemeFormattedPrompt.port(
        'Port',
        io: TerminalEnvironment.scripted(
          input: input.stream,
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      late final Spinner spinner;
      final feedback = await prompt.startFeedback((handle) {
        spinner = Spinner('Policy')..start(session: handle.session);
      }, stop: () => spinner.dispose());

      final pending = prompt.prompt();
      await _waitUntil(() => output.toString().contains('Port ('));
      spinner.update('checking');
      await Future<void>.delayed(Duration.zero);
      input.add('443\r');

      expect((await pending as Accepted<int>).value, 443);
      await feedback.finish(() => spinner.finish(FeedbackOutcome.completed));
      expect(output.toString(), contains('Policy: checking'));
      expect(cancellations, 1);
      await input.close();
    });

    test(
      'identified paste stays literal across retries and cleans up',
      () async {
        var cancellations = 0;
        final input = StreamController<String>(onCancel: () => cancellations++);
        final output = StringBuffer();
        final prompt = ThemeFormattedPrompt.number(
          'Amount',
          io: TerminalEnvironment.scripted(
            input: input.stream,
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          convention: NumericConvention.ascii(),
          required: true,
        );

        final pending = prompt.prompt();
        await _waitUntil(() => output.toString().contains('Amount ('));
        input.add('\x1b[200~/cancel\x1b[201~\r');
        await _waitUntil(
          () => output.toString().contains('Enter a complete base-ten number'),
        );
        input.add('${_clearDraft}123\r');
        await input.close();

        expect(
          (await pending as Accepted<NumericAnswer?>).value?.spelling,
          '123',
        );
        expect(output.toString(), isNot(contains('Cancelled')));
        expect(cancellations, 1);
        expect(input.isClosed, isTrue);
      },
    );

    test(
      'short-limit tag fields keep help, cancel and multiline-paste safety',
      () async {
        final helpOutput = StringBuffer();
        final helped = await ThemeFormattedPrompt.tag(
          'Labels',
          io: _linearIo('/help\r${_clearDraft}ab\r/done\r', helpOutput),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          maxLength: 2,
        ).prompt();
        expect((helped as Accepted<List<String>>).value, ['ab']);
        expect(helpOutput.toString(), contains('Help: Enter adds'));

        final cancelled = await ThemeFormattedPrompt.tag(
          'Labels',
          io: _linearIo('/cancel\r', StringBuffer()),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          maxLength: 2,
        ).prompt();
        expect(cancelled, isA<Cancelled<List<String>>>());

        final pasteOutput = StringBuffer();
        final pasted = await ThemeFormattedPrompt.port(
          'Port',
          io: _linearIo('\x1b[200~first\nsecond\x1b[201~80\r', pasteOutput),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          initialValue: '80',
        ).prompt();
        expect((pasted as Accepted<int>).value, 8080);
        expect(
          pasteOutput.toString(),
          contains('Paste rejected: single-line printable text only.'),
        );
      },
    );

    test(
      'detailed help preserves the draft and caret through the owner',
      () async {
        final output = StringBuffer();
        final result = await ThemeFormattedPrompt.number(
          'Amount',
          io: _linearIo('12\x1b[D3\x14\x1b\r', output),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          convention: NumericConvention.ascii(),
        ).prompt();

        expect((result as Accepted<NumericAnswer?>).value?.spelling, '132');
        expect(output.toString(), contains('Help:'));
      },
    );

    test(
      'themed prompts keep outcomes and restart from initial values',
      () async {
        ThemeFormattedPrompt<String> prompt(String keys, StringSink output) =>
            ThemeFormattedPrompt.slider(
              'Volume',
              io: TerminalEnvironment.scripted(
                input: Stream.value(keys),
                output: output,
                profile: const OutputProfile(glyphs: GlyphSet.ascii),
              ),
              interaction: const InteractionPreferences(
                mode: PromptMode.linear,
              ),
              minimum: '0',
              maximum: '10',
              step: '1',
            );

        expect(
          await prompt('/cancel\r', StringBuffer()).prompt(),
          isA<Cancelled<String>>(),
        );
        expect(
          await prompt('\x03', StringBuffer()).prompt(),
          isA<Interrupted<String>>(),
        );
        expect(
          await prompt('', StringBuffer()).prompt(),
          isA<InputEnded<String>>(),
        );

        final unavailableOutput = StringBuffer();
        final unavailable = await ThemeFormattedPrompt.slider(
          'Volume',
          io: TerminalEnvironment.scripted(
            input: Stream.value('4\r'),
            output: unavailableOutput,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          minimum: '0',
          maximum: '10',
          step: '1',
        ).prompt();
        expect(unavailable, isA<Unavailable<String>>());
        expect(unavailableOutput.toString(), isEmpty);

        var callbacks = 0;
        final reused = ThemeFormattedPrompt.slider(
          'Volume',
          io: TerminalEnvironment.scripted(
            input: _AnswersPerListen(['\x7f5\r', '\r']),
            output: StringBuffer(),
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          minimum: '0',
          maximum: '10',
          step: '1',
          initialValue: '4',
          onResolved: (_) async => callbacks++,
        );
        expect((await reused.prompt() as Accepted<String>).value, '5');
        expect((await reused.prompt() as Accepted<String>).value, '4');
        expect(callbacks, 2);
      },
    );

    test('a second concurrent themed prompt is rejected', () async {
      final input = StreamController<String>();
      final output = StringBuffer();
      var callbacks = 0;
      final prompt = ThemeFormattedPrompt.slider(
        'Volume',
        io: TerminalEnvironment.scripted(
          input: input.stream,
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        minimum: '0',
        maximum: '10',
        step: '1',
        initialValue: '4',
        onResolved: (_) async => callbacks++,
      );

      final pending = prompt.prompt();
      await _waitUntil(() => output.toString().contains('Volume'));
      expect(await prompt.prompt(), isA<Unavailable<String>>());
      expect(callbacks, 1);
      expect(
        RegExp(r'Volume \(minimum').allMatches(output.toString()),
        hasLength(1),
      );

      input.add('\r');
      await input.close();
      expect(await pending, isA<Accepted<String>>());
    });

    test('every themed formatted input also runs in rich mode', () async {
      for (final fixture in _textBackedFixtures) {
        final output = StringBuffer();
        final result = await fixture
            .build(
              TerminalEnvironment.scripted(
                input: Stream.value(_richKeysFor(fixture)),
                output: output,
                profile: _richProfile,
                supportsRich: true,
              ),
              const InteractionPreferences(mode: PromptMode.rich),
            )
            .prompt();

        fixture.expect(result, fixture.name);
        expect(
          _flatten(output.toString()),
          anyOf(contains('Ctrl+T'), contains('/help')),
          reason: '${fixture.name} help route in rich mode',
        );
      }
    });

    test(
      'screen-reader essentials precede every themed formatted prompt',
      () async {
        for (final fixture in _textBackedFixtures) {
          final output = StringBuffer();
          final result = await fixture
              .build(
                TerminalEnvironment.scripted(
                  input: Stream.value(fixture.keys),
                  output: output,
                  profile: const OutputProfile(glyphs: GlyphSet.ascii),
                ),
                const InteractionPreferences(
                  mode: PromptMode.linear,
                  screenReader: ScreenReaderPreference.on,
                ),
              )
              .prompt();

          fixture.expect(result, fixture.name);
          final text = _flatten(output.toString());
          expect(
            text,
            startsWith(_flatten(_essentialFor(fixture.name))),
            reason: '${fixture.name} must introduce itself sequentially',
          );
          expect(
            text,
            contains('/help'),
            reason: '${fixture.name} essential help route',
          );
        }
      },
    );

    test(
      'screen-reader essentials precede range, date, time and zone prompts',
      () async {
        const interaction = InteractionPreferences(
          mode: PromptMode.linear,
          screenReader: ScreenReaderPreference.on,
        );

        final rangeOutput = StringBuffer();
        final range = ThemeFormattedPrompt.rangeSlider(
          'Band',
          io: _linearIo('3\r7\r\r', rangeOutput),
          interaction: interaction,
          minimum: '0',
          maximum: '10',
          step: '1',
          minimumGap: '2',
          instructions: InstructionDisplay.hidden,
        );
        expect((await range.prompt() as Accepted<(String, String)>).value, (
          '3',
          '7',
        ));
        expect(
          _flatten(rangeOutput.toString())
              .startsWith(_flatten('Band lower and upper exact decimals')),
          isTrue,
        );

        final dateOutput = StringBuffer();
        final date = ThemeFormattedPrompt.date(
          'Date',
          io: _linearIo('29/2/2024\r/submit\r', dateOutput),
          interaction: interaction,
          order: DateFieldOrder.dayMonthYear,
          instructions: InstructionDisplay.hidden,
        );
        expect((await date.prompt() as Accepted<CivilDate>).value.day, 29);
        expect(
          _flatten(
            dateOutput.toString(),
          ).startsWith(_flatten('Date civil date entry in dayMonthYear order')),
          isTrue,
        );

        final timeOutput = StringBuffer();
        final time = ThemeFormattedPrompt.time(
          'Departure',
          io: _linearIo('23:00\r', timeOutput),
          interaction: interaction,
          instructions: InstructionDisplay.hidden,
        );
        expect(
          (await time.prompt()
                  as Accepted<({int hour, int minute, int? second})>)
              .value,
          (hour: 23, minute: 0, second: null),
        );
        expect(
          _flatten(timeOutput.toString()).startsWith(
            _flatten('Departure time of day, not a date or timezone'),
          ),
          isTrue,
        );

        final zoneOutput = StringBuffer();
        final zone = ThemeFormattedPrompt.timezone(
          'Zone',
          io: _linearIo('US/Eastern\r105\r', zoneOutput),
          interaction: interaction,
          instructions: InstructionDisplay.hidden,
        );
        expect(
          (await zone.prompt() as Accepted<String>).value,
          'America/New_York',
        );
        expect(
          _flatten(zoneOutput.toString())
              .startsWith(_flatten('Zone IANA zone identity search')),
          isTrue,
        );
      },
    );

    test(
      'themed temporal components preserve civil, time and zone values',
      () async {
        final richDate = StringBuffer();
        final date = ThemeFormattedPrompt.date(
          'Date',
          io: TerminalEnvironment.scripted(
            input: Stream.value('29\t2\t2024\t\r\t\r'),
            output: richDate,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          order: DateFieldOrder.dayMonthYear,
        );
        final civil = (await date.prompt() as Accepted<CivilDate>).value;
        expect((civil.year, civil.month, civil.day), (2024, 2, 29));
        expect(_flatten(richDate.toString()), contains('Ctrl+T'));

        final linearDate = StringBuffer();
        final linearCivil =
            (await ThemeFormattedPrompt.date(
                      'Date',
                      io: TerminalEnvironment.scripted(
                        input: Stream.value('29/2/2024\r/submit\r'),
                        output: linearDate,
                        profile: const OutputProfile(glyphs: GlyphSet.ascii),
                      ),
                      interaction: const InteractionPreferences(
                        mode: PromptMode.linear,
                      ),
                      order: DateFieldOrder.dayMonthYear,
                    ).prompt()
                    as Accepted<CivilDate>)
                .value;
        expect(
          (linearCivil.year, linearCivil.month, linearCivil.day),
          (2024, 2, 29),
        );
        expect(_flatten(linearDate.toString()), contains('/help'));

        final richTime = StringBuffer();
        final time =
            (await ThemeFormattedPrompt.time(
                      'Departure',
                      io: TerminalEnvironment.scripted(
                        input: Stream.value('12\r34\r\t\r'),
                        output: richTime,
                        profile: _richProfile,
                        supportsRich: true,
                      ),
                      interaction: const InteractionPreferences(
                        mode: PromptMode.rich,
                      ),
                    ).prompt()
                    as Accepted<({int hour, int minute, int? second})>)
                .value;
        expect(time, (hour: 12, minute: 34, second: null));
        expect(_flatten(richTime.toString()), contains('Ctrl+T'));

        final linearTime =
            (await ThemeFormattedPrompt.time(
                      'Departure',
                      io: TerminalEnvironment.scripted(
                        input: Stream.value('23:00\r'),
                        output: StringBuffer(),
                        profile: const OutputProfile(glyphs: GlyphSet.ascii),
                      ),
                      interaction: const InteractionPreferences(
                        mode: PromptMode.linear,
                      ),
                    ).prompt()
                    as Accepted<({int hour, int minute, int? second})>)
                .value;
        expect(linearTime, (hour: 23, minute: 0, second: null));

        final zoneOutput = StringBuffer();
        final zone = await ThemeFormattedPrompt.timezone(
          'Zone',
          io: TerminalEnvironment.scripted(
            input: Stream.value('US/Eastern\r105\r'),
            output: zoneOutput,
            profile: _richProfile,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        ).prompt();
        expect((zone as Accepted<String>).value, 'America/New_York');
        expect(_flatten(zoneOutput.toString()), contains('2025c'));
      },
    );

    test(
      'a themed range slider preserves both exact endpoints and the gap',
      () async {
        final output = StringBuffer();
        final range = ThemeFormattedPrompt.rangeSlider(
          'Band',
          minimum: '0',
          maximum: '10',
          step: '1',
          minimumGap: '2',
          initialLower: '3',
          initialUpper: '7',
          io: TerminalEnvironment.scripted(
            input: Stream.value('\t\t\t\t\r'),
            output: output,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
        );

        expect((await range.prompt() as Accepted<(String, String)>).value, (
          '3',
          '7',
        ));
        final text = _flatten(output.toString());
        expect(text, contains('minimumgap2'));
        expect(text, contains('Ctrl+Topenshelp'));
      },
    );
  });
}

final class _TextBackedFixture {
  const _TextBackedFixture(this.name, this.keys, this.build, this.expect);

  final String name;
  final String keys;
  final ThemeFormattedPrompt Function(
    TerminalEnvironment io,
    InteractionPreferences interaction,
  )
  build;
  final void Function(PromptResult<Object?> result, String name) expect;
}

final _maskTemplate = MaskTemplate('code', [
  MaskSlot('digit', (value) => '0123456789'.contains(value)),
  MaskLiteral('-'),
  MaskSlot('digit', (value) => '0123456789'.contains(value)),
]);

final _textBackedFixtures = <_TextBackedFixture>[
  _TextBackedFixture(
    'NumberInput',
    '1.5\r',
    (io, interaction) => ThemeFormattedPrompt.number(
      'Amount',
      io: io,
      interaction: interaction,
      convention: NumericConvention.ascii(),
      decimal: true,
      precision: 2,
      instructions: InstructionDisplay.hidden,
    ),
    (result, name) => expect(
      (result as Accepted<NumericAnswer?>).value?.spelling,
      '1.5',
      reason: name,
    ),
  ),
  _TextBackedFixture(
    'PortInput',
    '443\r',
    (io, interaction) => ThemeFormattedPrompt.port(
      'Port',
      io: io,
      interaction: interaction,
      allowZero: true,
      instructions: InstructionDisplay.hidden,
    ),
    (result, name) =>
        expect((result as Accepted<int>).value, 443, reason: name),
  ),
  _TextBackedFixture(
    'IPAddressInput',
    '192.0.2.7/24\r',
    (io, interaction) => ThemeFormattedPrompt.ipAddress(
      'Host',
      io: io,
      interaction: interaction,
      cidr: true,
      scoped: true,
      instructions: InstructionDisplay.hidden,
    ),
    (result, name) {
      final value = (result as Accepted<IPAddressValue>).value;
      expect(value.spelling, '192.0.2.7/24', reason: name);
      expect(value.prefixLength, 24, reason: name);
    },
  ),
  _TextBackedFixture(
    'URLInput',
    'https://example.com/\r',
    (io, interaction) => ThemeFormattedPrompt.url(
      'Site',
      io: io,
      interaction: interaction,
      allowedSchemes: const {'https'},
      instructions: InstructionDisplay.hidden,
    ),
    (result, name) => expect(
      (result as Accepted<String>).value,
      'https://example.com/',
      reason: name,
    ),
  ),
  _TextBackedFixture(
    'EmailInput',
    'x@example.com\r',
    (io, interaction) => ThemeFormattedPrompt.email(
      'Mail',
      io: io,
      interaction: interaction,
      smtpUtf8: true,
      instructions: InstructionDisplay.hidden,
    ),
    (result, name) => expect(
      (result as Accepted<String>).value,
      'x@example.com',
      reason: name,
    ),
  ),
  _TextBackedFixture(
    'ColorInput',
    '#f00\r',
    (io, interaction) => ThemeFormattedPrompt.color(
      'Tint',
      io: io,
      interaction: interaction,
      instructions: InstructionDisplay.hidden,
    ),
    (result, name) {
      final value = (result as Accepted<ColorValue?>).value!;
      expect(value.source, '#f00', reason: name);
      expect(value.red, 1, reason: name);
    },
  ),
  _TextBackedFixture(
    'DurationInput',
    '-1s\r',
    (io, interaction) => ThemeFormattedPrompt.duration(
      'Wait',
      io: io,
      interaction: interaction,
      durationMode: DurationInputMode.elapsed,
      signed: true,
      instructions: InstructionDisplay.hidden,
    ),
    (result, name) => expect(
      (result as Accepted<DurationValue>).value.microseconds,
      BigInt.from(-1000000),
      reason: name,
    ),
  ),
  _TextBackedFixture(
    'CronInput',
    '* * * * *\r',
    (io, interaction) => ThemeFormattedPrompt.cron(
      'Schedule',
      io: io,
      interaction: interaction,
      profile: CronProfile.unix,
      instructions: InstructionDisplay.hidden,
    ),
    (result, name) => expect(
      (result as Accepted<CronExpression>).value.expression,
      '* * * * *',
      reason: name,
    ),
  ),
  _TextBackedFixture(
    'MaskedInput',
    '12\r/done\r',
    (io, interaction) => ThemeFormattedPrompt.masked(
      'Code',
      io: io,
      interaction: interaction,
      templates: [_maskTemplate],
      instructions: InstructionDisplay.hidden,
    ),
    (result, name) => expect(
      (result as Accepted<MaskedValue>).value.formatted,
      '1-2',
      reason: name,
    ),
  ),
  _TextBackedFixture(
    'TagInput',
    'Hello World\rSecond Tag\r/done\r',
    (io, interaction) => ThemeFormattedPrompt.tag(
      'Labels',
      io: io,
      interaction: interaction,
      instructions: InstructionDisplay.hidden,
    ),
    (result, name) => expect((result as Accepted<List<String>>).value, [
      'hello-world',
      'second-tag',
    ], reason: name),
  ),
];

CronPreviewConfig _cronPreviewConfig() => CronPreviewConfig(
  providerTimeout: const Duration(seconds: 5),
  zone: 'Etc/UTC',
  reference: DateTime.utc(2024),
  start: DateTime.utc(2024),
  end: DateTime.utc(2024, 1, 1, 0, 3),
  count: 1,
  budget: 3,
);

Iterable<String> _visibleLines(String text) => text
    .split('\n')
    .map(
      (line) => line
          .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '')
          .split('\r')
          .last,
    )
    .where((line) => line.isNotEmpty);

final _clearDraft = '\x01${'\x1b[3~' * 40}';

final class _AnswersPerListen extends Stream<String> {
  _AnswersPerListen(this._answers);

  final List<String> _answers;
  var _next = 0;

  @override
  StreamSubscription<String> listen(
    void Function(String event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final answer = _answers[_next++];
    return Stream<String>.value(answer).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition was not met before the test deadline');
}

TerminalEnvironment _linearIo(String keys, StringSink output) =>
    TerminalEnvironment.scripted(
      input: Stream.value(keys),
      output: output,
      profile: const OutputProfile(glyphs: GlyphSet.ascii),
    );

final _richKeys = <String, String>{
  'MaskedInput': '\x14\x1b12\r',
  'TagInput': '\x14\x1bHello World\rSecond Tag\r\t\r',
};

String _richKeysFor(_TextBackedFixture fixture) =>
    _richKeys[fixture.name] ?? '\x14\x1b${fixture.keys}';

String _essentialFor(String name) => switch (name) {
  'NumberInput' => 'Amount decimal numeric entry.',
  'PortInput' => 'Port ASCII decimal port, 0 to 65535.',
  'IPAddressInput' => 'Host numeric IPv4 or IPv6 address with prefix and zone.',
  'URLInput' => 'Site absolute URL; allowed schemes https.',
  'EmailInput' => 'Mail bare SMTP address entry.',
  'ColorInput' => 'Tint CSS sRGB colour entry',
  'DurationInput' =>
    'Wait elapsed duration entry with a textual interpretation.',
  'CronInput' => 'Schedule unix cron expression entry.',
  'MaskedInput' => 'Code mask entry; templates code.',
  'TagInput' => 'Labels kebab-case tag collection',
  _ => throw ArgumentError(name),
};

String _flatten(String text) => text
    .replaceAll(RegExp(r'\x1b\][^\x07]*\x07'), '')
    .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '')
    .replaceAll(RegExp(r'\s+'), '');

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 70, rows: 14),
);
