import 'dart:async';
import 'dart:io';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _syntheticRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

ScriptedInput scriptedInput(
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
    final sessions =
        <
          String,
          Future<PromptResult<Object?>> Function({
            PromptSource? source,
            PromptMode? mode,
          })
        >{
          'TextInput': TextInput('Name').prompt,
          'Password': Password('Password').prompt,
          'Multiline': Multiline('Notes').prompt,
          'Autocomplete': Autocomplete(
            'Name',
            suggestions: (_) => ['Ada'],
          ).prompt,
          'TagInput': TagInput('Tags').prompt,
          'Confirm': Confirm('Confirm').prompt,
          'Checkbox': Checkbox('Checkbox').prompt,
          'Toggle': Toggle('Toggle').prompt,
          'Select': Select('Choice', [Choice('a', 'A')]).prompt,
          'Radio': Radio('Choice', [Choice('a', 'A')]).prompt,
          'MultiSelect': MultiSelect('Choices', [Choice('a', 'A')]).prompt,
          'SearchSelect': SearchSelect('Search', [Choice('a', 'A')]).prompt,
          'CommandPalette': CommandPalette('Command', [
            Choice('a', 'A'),
          ]).prompt,
          'TimezoneSelect': TimezoneSelect('Zone').prompt,
          'TreeSelect': TreeSelect('Tree', [TreeNode('a', 'A')]).prompt,
          'SortableSelect': SortableSelect('Order', [Choice('a', 'A')]).prompt,
          'Slider': Slider(
            'Volume',
            minimum: '0',
            maximum: '10',
            step: '1',
          ).prompt,
          'RangeSlider': RangeSlider(
            'Range',
            minimum: '0',
            maximum: '10',
            step: '1',
          ).prompt,
          'TimeInput': TimeInput('Time').prompt,
          'PathInput': PathInput('Path').prompt,
          'FilePicker': FilePicker('File').prompt,
          'DirectoryPicker': DirectoryPicker('Directory').prompt,
          'Keypress': Keypress('Key').prompt,
          'KeyChordInput': KeyChordInput('Sequence').prompt,
          'NumberInput': NumberInput(
            'Number',
            convention: NumericConvention.ascii(),
          ).prompt,
          'PortInput': PortInput('Port').prompt,
          'IPAddressInput': IPAddressInput('Address').prompt,
          'URLInput': URLInput('URL', allowedSchemes: {'https'}).prompt,
          'EmailInput': EmailInput('Email').prompt,
          'ColorInput': ColorInput('Color').prompt,
          'MaskedInput': MaskedInput(
            'Code',
            templates: [
              MaskTemplate('digit', [
                MaskSlot('digit', (s) => '0123456789'.contains(s)),
              ]),
            ],
          ).prompt,
          'DurationInput': DurationInput(
            'Span',
            durationMode: DurationInputMode.elapsed,
          ).prompt,
          'DateInput': DateInput(
            'Date',
            order: DateFieldOrder.dayMonthYear,
          ).prompt,
          'CronInput': CronInput('Schedule', profile: CronProfile.unix).prompt,
        };
    for (final entry in sessions.entries) {
      test('${entry.key} / ${mode.name}: reject overlap and recover', () async {
        final input = StreamController<String>();
        addTearDown(input.close);
        final pending = entry.value(
          source: scriptedInput(mode, input.stream, StringBuffer()),
          mode: mode,
        );
        await expectLater(
          entry.value(
            source: scriptedInput(mode, Stream.value('\x03'), StringBuffer()),
            mode: mode,
          ),
          throwsStateError,
        );
        final failure = StateError('input failed');
        final failed = expectLater(pending, throwsA(same(failure)));
        input.addError(failure);
        await failed;
        expect(
          await entry.value(
            source: scriptedInput(
              mode,
              const Stream<String>.empty(),
              StringBuffer(),
            ),
            mode: mode,
          ),
          isA<InputEnded<Object?>>(),
        );
        expect(
          await entry.value(
            source: scriptedInput(mode, Stream.value('\x03'), StringBuffer()),
            mode: mode,
          ),
          isA<Interrupted<Object?>>(),
        );
        expect(
          await entry.value(
            source: scriptedInput(
              mode,
              const Stream<String>.empty(),
              StringBuffer(),
            ),
            mode: mode,
          ),
          isA<InputEnded<Object?>>(),
        );
      });
    }
    test('TextInput / ${mode.name}: submit an edited answer', () async {
      final out = StringBuffer();
      final result = await TextInput('Name').prompt(
        source: scriptedInput(mode, Stream.value('Ada\r'), out),
        mode: mode,
      );
      expect((result as Accepted<String>).value, 'Ada');
      expect(out.toString(), contains('Name'));
    });
    test(
      'Password / ${mode.name}: validate without revealing the secret',
      () async {
        final out = StringBuffer();
        final result =
            await Password(
              'Password',
              validate: (v) => v == 'secret99' ? null : 'invalid',
            ).prompt(
              source: scriptedInput(
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
      final result = await Multiline('Notes').prompt(
        source: scriptedInput(
          mode,
          Stream.value(mode == PromptMode.rich ? 'abc\t\r' : 'abc\r/done\r'),
          out,
        ),
        mode: mode,
      );
      expect(result, isA<Accepted<String>>());
      expect((result as Accepted<String>).value, 'abc');
      expect(out.toString(), contains('Notes'));
    });
    for (final component in ['Confirm', 'Checkbox', 'Toggle']) {
      test('$component / ${mode.name}: choose and submit yes', () async {
        final out = StringBuffer();
        final input = scriptedInput(
          mode,
          Stream.value(
            mode == PromptMode.rich
                ? (component == 'Confirm' ? 'y\r' : ' \r')
                : 'yes\r',
          ),
          out,
        );
        final PromptResult<bool> result = switch (component) {
          'Confirm' => await Confirm(
            'Decision',
          ).prompt(source: input, mode: mode),
          'Checkbox' => await Checkbox(
            'Decision',
          ).prompt(source: input, mode: mode),
          _ => await Toggle('Decision').prompt(source: input, mode: mode),
        };
        expect((result as Accepted<bool>).value, isTrue);
        expect(out.toString(), contains('Decision'));
      });
    }
    test('Autocomplete / ${mode.name}: accept suggestion', () async {
      final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
          .prompt(
            source: scriptedInput(
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
    test('MultiSelect / ${mode.name}: select two identities', () async {
      final result =
          await MultiSelect<String>('Choices', [
            Choice('a', 'A'),
            Choice('b', 'B'),
          ]).prompt(
            source: scriptedInput(
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
    test('SearchSelect / ${mode.name}: choose a search result', () async {
      final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
        source: scriptedInput(
          mode,
          Stream.value(mode == PromptMode.rich ? '\r\r' : '\r1\r'),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<String>).value, 'a');
    });
    test('CommandPalette / ${mode.name}: choose command identity', () async {
      final result = await CommandPalette('Commands', [Choice('save', 'Save')])
          .prompt(
            source: scriptedInput(
              mode,
              Stream.value(mode == PromptMode.rich ? 'sav\r\r' : 'sav\r1\r'),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, 'save');
    });
    test('TimezoneSelect / ${mode.name}: resolve alias', () async {
      final result = await TimezoneSelect('Zone').prompt(
        source: scriptedInput(
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
    test('NumberInput / ${mode.name}: submit numeric spelling', () async {
      final result =
          await NumberInput(
            'Count',
            convention: NumericConvention.ascii(),
          ).prompt(
            source: scriptedInput(mode, Stream.value('12\r'), StringBuffer()),
            mode: mode,
          );
      expect((result as Accepted<NumericAnswer?>).value?.spelling, '12');
    });
    test('PortInput / ${mode.name}: correct an invalid port', () async {
      final result = await PortInput('Port').prompt(
        source: scriptedInput(
          mode,
          Stream.value('99999\r\x7f\x7f\x7f\x7f\x7f443\r'),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<int>).value, 443);
    });
    test('URLInput / ${mode.name}: submit URL', () async {
      final result = await URLInput('URL', allowedSchemes: {'https'}).prompt(
        source: scriptedInput(
          mode,
          Stream.value('https://example.com/\r'),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<String>).value, 'https://example.com/');
    });
    test('EmailInput / ${mode.name}: submit email', () async {
      final result = await EmailInput('Email').prompt(
        source: scriptedInput(
          mode,
          Stream.value('Case@example.com\r'),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<String>).value, 'Case@example.com');
    });
    test('ColorInput / ${mode.name}: submit color', () async {
      final result = await ColorInput('Color', initialValue: '#fff').prompt(
        source: scriptedInput(mode, Stream.value('\r'), StringBuffer()),
        mode: mode,
      );
      expect((result as Accepted<ColorValue?>).value?.source, '#fff');
    });
    test('DurationInput / ${mode.name}: submit elapsed duration', () async {
      final result =
          await DurationInput(
            'Span',
            durationMode: DurationInputMode.elapsed,
          ).prompt(
            source: scriptedInput(mode, Stream.value('1s\r'), StringBuffer()),
            mode: mode,
          );
      expect(
        (result as Accepted<DurationValue>).value.microseconds,
        BigInt.from(1000000),
      );
    });
    test('Text / ${mode.name}: present literal information', () {
      final out = StringBuffer();
      Text('Hello').present(output: out);
      expect(out.toString(), contains('Hello'));
    });
    test('Keypress / ${mode.name}: capture and review key', () async {
      final result = await Keypress('Shortcut').prompt(
        source: scriptedInput(
          mode,
          Stream.value(mode == PromptMode.rich ? 'ca\r' : '/capture\ra/done\r'),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<KeyGesture>).value.key, 'a');
    });
    test('KeyChordInput / ${mode.name}: submit ordered gestures', () async {
      final result = await KeyChordInput('Sequence').prompt(
        source: scriptedInput(
          mode,
          Stream.value(
            mode == PromptMode.rich
                ? 'cacb\r'
                : '/capture\ra/capture\rb/done\r',
          ),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<List<KeyGesture>>).value.map((g) => g.key), [
        'a',
        'b',
      ]);
    });
    test('DateInput / ${mode.name}: review a leap day', () async {
      final result = await DateInput('Date', order: DateFieldOrder.dayMonthYear)
          .prompt(
            source: scriptedInput(
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
      final result = await CronInput('Schedule', profile: CronProfile.unix)
          .prompt(
            source: scriptedInput(
              mode,
              Stream.value(
                mode == PromptMode.rich
                    ? '* * * * *\r\t\r\t\r'
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
    test('TreeSelect / ${mode.name}: select a node', () async {
      final result =
          await TreeSelect<String>('Tree', [
            TreeNode('a', 'A'),
            TreeNode('b', 'B'),
          ], defaultValue: 'b').prompt(
            source: scriptedInput(
              mode,
              Stream.value(mode == PromptMode.rich ? '\r' : '/choose\r2\r'),
              StringBuffer(),
            ),
            mode: mode,
          );
      expect((result as Accepted<String>).value, 'b');
    });
    test('SortableSelect / ${mode.name}: reorder two identities', () async {
      final result =
          await SortableSelect<String>('Order', [
            Choice('a', 'A'),
            Choice('b', 'B'),
          ]).prompt(
            source: scriptedInput(
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
    test('Progress / ${mode.name}: finish work', () {
      final out = StringBuffer();
      final progress = Progress('Build', total: 10);
      progress.start(output: out, mode: mode, supportsRich: true);
      progress.update(10);
      progress.finish(FeedbackOutcome.completed);
      expect(out.toString(), contains('completed'));
    });
    test('Spinner / ${mode.name}: report failure', () {
      final out = StringBuffer();
      final spinner = Spinner('Build');
      spinner.start(output: out, mode: mode, supportsRich: true);
      spinner.finish(FeedbackOutcome.failed, detail: 'disk');
      expect(out.toString(), contains('failed: disk'));
    });
    test('MultiSpinner / ${mode.name}: retain task outcomes', () {
      final out = StringBuffer();
      final group = MultiSpinner(['build', 'test']);
      group.start(output: out, mode: mode, supportsRich: true);
      group.finishTask('test', FeedbackOutcome.failed);
      group.finishTask('build', FeedbackOutcome.completed);
      expect(out.toString(), contains('build: completed'));
      expect(out.toString(), contains('test: failed'));
    });
    test('TagInput / ${mode.name}: submit a canonical tag', () async {
      final result = await TagInput('Tags').prompt(
        source: scriptedInput(
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
    test('Slider / ${mode.name}: submit an on-grid value', () async {
      final result =
          await Slider(
            'Volume',
            minimum: '0',
            maximum: '1',
            step: '0.2',
            initialValue: '0.4',
          ).prompt(
            source: scriptedInput(
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
          await RangeSlider(
            'Window',
            minimum: '0',
            maximum: '10',
            step: '1',
            initialLower: '3',
            initialUpper: '5',
            minimumGap: '2',
          ).prompt(
            source: scriptedInput(
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
      final result = await TimeInput('Time', initialValue: '23:59').prompt(
        source: scriptedInput(
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
    test('PathInput / ${mode.name}: review a path', () async {
      final result =
          await PathInput(
            'Path',
            initialValue: 'draft',
            allowNonexistent: true,
          ).prompt(
            source: scriptedInput(mode, Stream.value('\r\r'), StringBuffer()),
            mode: mode,
          );
      expect((result as Accepted<String>).value, endsWith('draft'));
    });
    test('FilePicker / ${mode.name}: choose a file', () async {
      final dir = await Directory.systemTemp.createTemp('matrix-file-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}${Platform.pathSeparator}answer.txt')
          .writeAsString('data');
      final result = await FilePicker('File', base: dir.path).prompt(
        source: scriptedInput(
          mode,
          Stream.value('choose 1\r\r'),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<String>).value, file.path);
    });
    test('DirectoryPicker / ${mode.name}: choose current directory', () async {
      final dir = await Directory.systemTemp.createTemp('matrix-directory-');
      addTearDown(() => dir.delete(recursive: true));
      final result = await DirectoryPicker('Directory', base: dir.path).prompt(
        source: scriptedInput(mode, Stream.value('choose\r\r'), StringBuffer()),
        mode: mode,
      );
      expect((result as Accepted<String>).value, dir.path);
    });
    test('IPAddressInput / ${mode.name}: preserve host bits', () async {
      final result = await IPAddressInput('Address', cidr: true).prompt(
        source: scriptedInput(
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
    test('MaskedInput / ${mode.name}: edit a formatted default', () async {
      final input = MaskedInput(
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
        source: scriptedInput(
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
    for (final component in ['Select', 'Radio']) {
      test('$component / ${mode.name}: select the second identity', () async {
        final out = StringBuffer();
        final input = scriptedInput(
          mode,
          Stream.value(mode == PromptMode.rich ? '\x1b[B\r' : '2\r'),
          out,
        );
        final choices = [Choice('a', 'First'), Choice('b', 'Second')];
        final result = component == 'Select'
            ? await Select<String>(
                'Choice',
                choices,
              ).prompt(source: input, mode: mode)
            : await Radio<String>(
                'Choice',
                choices,
              ).prompt(source: input, mode: mode);
        expect((result as Accepted<String>).value, 'b');
        expect(out.toString(), contains('Choice'));
      });
    }
  }
}
