import 'dart:async';
import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

final _syntheticRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

ScriptedInput _scriptedInput(
  PromptMode mode,
  Stream<String> input,
  StringSink output,
) => ScriptedInput(
  input,
  output,
  outputProfile: mode == PromptMode.rich
      ? _syntheticRichProfile
      : const OutputProfile(),
);

void main() {
  for (final mode in [PromptMode.rich, PromptMode.linear]) {
    test('TextInput / ${mode.name}: submit an edited answer', () async {
      final out = StringBuffer();
      final result = await MinimalTheme.textInput('Name').prompt(
        source: _scriptedInput(mode, Stream.value('Ada\r'), out),
        mode: mode,
      );
      expect((result as Accepted<String>).value, 'Ada');
      expect(out.toString().toLowerCase(), contains('name'));
    });

    test(
      'Password / ${mode.name}: validate without revealing the secret',
      () async {
        final out = StringBuffer();
        final result =
            await MinimalTheme.password(
              'Password',
              validate: (v) => v == 'secret99' ? null : 'invalid',
            ).prompt(
              source: _scriptedInput(
                mode,
                Stream.value('secret\rsubmit\redit\r99\rsubmit\r'),
                out,
              ),
              mode: mode,
            );
        expect((result as Accepted<String>).value, 'secret99');
        expect(out.toString(), isNot(contains('secret99')));
      },
    );

    test('Multiline / ${mode.name}: submit a line', () async {
      final out = StringBuffer();
      final result = await MinimalTheme.multiline('Notes').prompt(
        source: _scriptedInput(
          mode,
          Stream.value(mode == PromptMode.rich ? 'abc\t\r' : 'abc\r/done\r'),
          out,
        ),
        mode: mode,
      );
      expect(result, isA<Accepted<String>>());
      expect((result as Accepted<String>).value, 'abc');
      expect(out.toString().toLowerCase(), contains('notes'));
    });

    for (final component in ['Confirm', 'Checkbox', 'Toggle']) {
      test('$component / ${mode.name}: choose and submit yes', () async {
        final out = StringBuffer();
        final input = _scriptedInput(
          mode,
          Stream.value(
            mode == PromptMode.rich
                ? (component == 'Confirm' ? 'y\r' : ' \r')
                : 'yes\r',
          ),
          out,
        );
        final PromptResult<bool> result = switch (component) {
          'Confirm' => await MinimalTheme.confirm(
            'Decision',
          ).prompt(source: input, mode: mode),
          'Checkbox' => await MinimalTheme.checkbox(
            'Decision',
          ).prompt(source: input, mode: mode),
          _ => await MinimalTheme.toggle(
            'Decision',
          ).prompt(source: input, mode: mode),
        };
        expect((result as Accepted<bool>).value, isTrue);
        expect(out.toString().toLowerCase(), contains('decision'));
      });
    }

    test('Select / ${mode.name}: select the second identity', () async {
      final out = StringBuffer();
      final result =
          await MinimalTheme.select<String>('Choice', [
            Choice('a', 'First'),
            Choice('b', 'Second'),
          ]).prompt(
            source: _scriptedInput(
              mode,
              Stream.value(mode == PromptMode.rich ? '\x1b[B\r' : '2\r'),
              out,
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, 'b');
      expect(out.toString().toLowerCase(), contains('choice'));
    });

    test('Radio / ${mode.name}: select the second identity', () async {
      final result =
          await MinimalTheme.radio<String>('Choice', [
            Choice('a', 'First'),
            Choice('b', 'Second'),
          ]).prompt(
            source: _scriptedInput(
              mode,
              Stream.value(mode == PromptMode.rich ? '\x1b[B\r' : '2\r'),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, 'b');
    });

    test('MultiSelect / ${mode.name}: select two identities', () async {
      final result =
          await MinimalTheme.multiSelect<String>('Choices', [
            Choice('a', 'A'),
            Choice('b', 'B'),
          ]).prompt(
            source: _scriptedInput(
              mode,
              Stream.value(
                mode == PromptMode.rich ? '\x1b[B \x1b[A \r' : '2\r1\r/done\r',
              ),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<List<String>>).value, ['a', 'b']);
    });

    test('Autocomplete / ${mode.name}: accept suggestion', () async {
      final result =
          await MinimalTheme.autocomplete(
            'Name',
            suggestions: (_) => ['Ada'],
          ).prompt(
            source: _scriptedInput(
              mode,
              Stream.value(
                mode == PromptMode.rich ? 'A\x1b[B\r\r' : 'A\r1\r/submit\r',
              ),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, 'Ada');
    });

    test('SearchSelect / ${mode.name}: choose a search result', () async {
      final result =
          await MinimalTheme.searchSelect<String>('Fruit', [
            Choice('a', 'Apple'),
          ]).prompt(
            source: _scriptedInput(
              mode,
              Stream.value(mode == PromptMode.rich ? '\r\r' : '\r1\r'),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, 'a');
    });

    test('SortableSelect / ${mode.name}: reorder two identities', () async {
      final result =
          await MinimalTheme.sortableSelect<String>('Order', [
            Choice('a', 'A'),
            Choice('b', 'B'),
          ]).prompt(
            source: _scriptedInput(
              mode,
              Stream.value(
                mode == PromptMode.rich
                    ? ' \x1b[B\r\r'
                    : '/move\r2\r1\r/done\r',
              ),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<List<String>>).value, ['b', 'a']);
    });

    test('TreeSelect / ${mode.name}: select a node', () async {
      final result =
          await MinimalTheme.treeSelect<String>('Tree', [
            TreeNode('a', 'A'),
            TreeNode('b', 'B'),
          ], defaultValue: 'b').prompt(
            source: _scriptedInput(
              mode,
              Stream.value(mode == PromptMode.rich ? '\r' : '/choose\r2\r'),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, 'b');
    });

    test('Slider / ${mode.name}: submit an on-grid value', () async {
      final result =
          await MinimalTheme.slider(
            'Volume',
            minimum: '0',
            maximum: '1',
            step: '0.2',
            initialValue: '0.4',
          ).prompt(
            source: _scriptedInput(
              mode,
              Stream.value(
                mode == PromptMode.rich ? '\x1b[C\t\t\r' : '\x7f\x7f\x7f0.6\r',
              ),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, '0.6');
    });

    test('RangeSlider / ${mode.name}: submit ordered endpoints', () async {
      final result =
          await MinimalTheme.rangeSlider(
            'Window',
            minimum: '0',
            maximum: '10',
            step: '1',
            initialLower: '3',
            initialUpper: '5',
            minimumGap: '2',
          ).prompt(
            source: _scriptedInput(
              mode,
              Stream.value(
                mode == PromptMode.rich
                    ? '\x1b[C\t\x1b[C\t\t\t\r'
                    : '\x7f2\r\x7f8\r\r',
              ),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect(
        (result as Accepted<(String, String)>).value,
        mode == PromptMode.rich ? ('3', '6') : ('2', '8'),
      );
    });

    test('TimeInput / ${mode.name}: submit a time', () async {
      final result = await MinimalTheme.timeInput('Time', initialValue: '23:59')
          .prompt(
            source: _scriptedInput(
              mode,
              Stream.value(mode == PromptMode.rich ? '+\t+\t\t\r' : '\r'),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect(
        (result as Accepted<({int hour, int minute, int? second})>).value,
        (hour: 23, minute: 59, second: null),
      );
    });

    test('TagInput / ${mode.name}: submit a canonical tag', () async {
      final result = await MinimalTheme.tagInput('Tags').prompt(
        source: _scriptedInput(
          mode,
          Stream.value(
            mode == PromptMode.rich ? 'NewTag\r\t\r' : 'NewTag\r/done\r',
          ),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<List<String>>).value, ['new-tag']);
    });

    test('NumberInput / ${mode.name}: submit numeric spelling', () async {
      final result =
          await MinimalTheme.numberInput(
            'Count',
            convention: NumericConvention.ascii(),
          ).prompt(
            source: _scriptedInput(mode, Stream.value('12\r'), StringBuffer()),
            mode: mode,
          );
      expect((result as Accepted<NumericAnswer?>).value?.spelling, '12');
    });

    test('PortInput / ${mode.name}: correct an invalid port', () async {
      final result = await MinimalTheme.portInput('Port').prompt(
        source: _scriptedInput(
          mode,
          Stream.value('99999\r\x7f\x7f\x7f\x7f\x7f443\r'),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<int>).value, 443);
    });

    test('IPAddressInput / ${mode.name}: preserve host bits', () async {
      final result = await MinimalTheme.ipAddressInput('Address', cidr: true)
          .prompt(
            source: _scriptedInput(
              mode,
              Stream.value('192.0.2.7/24\r'),
              StringBuffer(),
            ),
            mode: mode,
          );
      final value = (result as Accepted<IPAddressValue>).value;
      expect(value.address.address, '192.0.2.7');
      expect(value.prefixLength, 24);
    });

    test('URLInput / ${mode.name}: submit URL', () async {
      final result =
          await MinimalTheme.urlInput('URL', allowedSchemes: {'https'}).prompt(
            source: _scriptedInput(
              mode,
              Stream.value('https://example.com/\r'),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, 'https://example.com/');
    });

    test('EmailInput / ${mode.name}: submit email', () async {
      final result = await MinimalTheme.emailInput('Email').prompt(
        source: _scriptedInput(
          mode,
          Stream.value('Case@example.com\r'),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<String>).value, 'Case@example.com');
    });

    test('ColorInput / ${mode.name}: submit color', () async {
      final result =
          await MinimalTheme.colorInput('Color', initialValue: '#fff').prompt(
            source: _scriptedInput(mode, Stream.value('\r'), StringBuffer()),
            mode: mode,
          );
      expect((result as Accepted<ColorValue?>).value?.source, '#fff');
    });

    test('MaskedInput / ${mode.name}: edit a formatted default', () async {
      final input = MinimalTheme.maskedInput(
        'Code',
        templates: [
          MaskTemplate('code', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskLiteral('-'),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
        ],
        initialValue: MaskedValue('code', ['1', '2'], '1-2'),
      );
      final result = await input.prompt(
        source: _scriptedInput(
          mode,
          Stream.value(
            mode == PromptMode.rich ? '\x7f3\r' : '/value\r\x7f3\r/done\r',
          ),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<MaskedValue>).value.formatted, '1-3');
    });

    test('DurationInput / ${mode.name}: submit elapsed duration', () async {
      final result =
          await MinimalTheme.durationInput(
            'Span',
            durationMode: DurationInputMode.elapsed,
          ).prompt(
            source: _scriptedInput(mode, Stream.value('1s\r'), StringBuffer()),
            mode: mode,
          );
      expect(
        (result as Accepted<DurationValue>).value.microseconds,
        BigInt.from(1000000),
      );
    });

    test('DateInput / ${mode.name}: review a leap day', () async {
      final result =
          await MinimalTheme.dateInput(
            'Date',
            order: DateFieldOrder.dayMonthYear,
          ).prompt(
            source: _scriptedInput(
              mode,
              Stream.value('29/02/2024\r/submit\r'),
              StringBuffer(),
            ),
            mode: mode,
          );
      final date = (result as Accepted<CivilDate>).value;
      expect((date.year, date.month, date.day), (2024, 2, 29));
    });

    test('CronInput / ${mode.name}: review schedule', () async {
      final result =
          await MinimalTheme.cronInput(
            'Schedule',
            profile: CronProfile.unix,
          ).prompt(
            source: _scriptedInput(
              mode,
              Stream.value(
                mode == PromptMode.rich
                    ? '*\t*\t*\t*\t*\r'
                    : '* * * * *\r/submit\r',
              ),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
    });

    test('TimezoneSelect / ${mode.name}: resolve alias', () async {
      final result = await MinimalTheme.timezoneSelect('Zone').prompt(
        source: _scriptedInput(
          mode,
          Stream.value(
            mode == PromptMode.rich ? 'US/Eastern\r\r' : 'US/Eastern\r105\r',
          ),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<String>).value, 'America/New_York');
    });

    test('PathInput / ${mode.name}: review a path', () async {
      final result =
          await MinimalTheme.pathInput(
            'Path',
            initialValue: 'draft',
            allowNonexistent: true,
          ).prompt(
            source: _scriptedInput(mode, Stream.value('\r\r'), StringBuffer()),
            mode: mode,
          );
      expect((result as Accepted<String>).value, endsWith('draft'));
    });

    test('FilePicker / ${mode.name}: choose a file', () async {
      final dir = await Directory.systemTemp.createTemp('plain-file-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}${Platform.pathSeparator}answer.txt')
          .writeAsString('data');
      final result = await MinimalTheme.filePicker('File', base: dir.path)
          .prompt(
            source: _scriptedInput(
              mode,
              Stream.value('choose 1\r\r'),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, file.path);
    });

    test('DirectoryPicker / ${mode.name}: choose current directory', () async {
      final dir = await Directory.systemTemp.createTemp('plain-directory-');
      addTearDown(() => dir.delete(recursive: true));
      final result =
          await MinimalTheme.directoryPicker(
            'Directory',
            base: dir.path,
          ).prompt(
            source: _scriptedInput(
              mode,
              Stream.value('choose\r\r'),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, dir.path);
    });

    test('Keypress / ${mode.name}: capture and review key', () async {
      final result = await MinimalTheme.keypress('Shortcut').prompt(
        source: _scriptedInput(
          mode,
          Stream.value(mode == PromptMode.rich ? 'ca\r' : '/capture\ra/done\r'),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<KeyGesture>).value.key, 'a');
    });

    test('Keybind / ${mode.name}: submit ordered tokens', () async {
      final result =
          await MinimalTheme.keybind(
            'Sequence',
            symbols: const ['A', 'B'],
          ).prompt(
            source: _scriptedInput(
              mode,
              Stream.value(
                mode == PromptMode.rich ? '\x1b[B\t\x1b[B\x1b[B\r' : 'Ctrl,B\r',
              ),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<List<String>>).value, ['Ctrl', 'B']);
    });

    test('Progress / ${mode.name}: finish work', () {
      final out = StringBuffer();
      final progress = MinimalTheme.progress('Build', total: 10);
      progress.start(output: out, mode: mode, supportsRich: true);
      progress.update(10);
      progress.finish(FeedbackOutcome.completed);
      expect(out.toString(), contains('completed'));
    });

    test('Spinner / ${mode.name}: report failure', () {
      final out = StringBuffer();
      final spinner = MinimalTheme.spinner('Build');
      spinner.start(output: out, mode: mode, supportsRich: true);
      spinner.finish(FeedbackOutcome.failed, detail: 'disk');
      expect(out.toString(), contains('failed: disk'));
    });

    test('MultiSpinner / ${mode.name}: retain task outcomes', () {
      final out = StringBuffer();
      final group = MinimalTheme.multiSpinner(['build', 'test']);
      group.start(output: out, mode: mode, supportsRich: true);
      group.finishTask('test', FeedbackOutcome.failed);
      group.finishTask('build', FeedbackOutcome.completed);
      expect(out.toString(), contains('build: completed'));
      expect(out.toString(), contains('test: failed'));
    });

    test('Text / ${mode.name}: present literal information', () {
      final out = StringBuffer();
      MinimalTheme.text('Hello').present(output: out);
      expect(out.toString(), contains('Hello'));
    });
  }
}
