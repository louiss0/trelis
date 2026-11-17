import 'dart:async';
import 'dart:io';

import 'package:trelis/trelis.dart';
import 'package:trelis/src/text_measurement.dart';
import 'package:test/test.dart';

/// Verification of the rail and branch grammars on every distinct render path.
///
/// Behavior, accepted values, input bindings and outcomes are covered by the
/// per-theme acceptance matrices. These tests assert the presentation contract
/// instead: a rail or branch theme frames the stage it renders, an unframed
/// theme does not, the prefix is measured as part of the width, ASCII and
/// Unicode are chosen by capability, and palette overrides style the frame
/// without changing the accepted answer.

const _railStart = '│ ';
const _railEnd = '└ ';
const _branchStart = '├ ';
const _asciiRailStart = '| ';
const _asciiRailEnd = r'\ ';
const _asciiBranchStart = '+-';
const _asciiBranchEnd = r'\-';

OutputProfile _profile(
  PromptMode mode, {
  bool ascii = false,
  int columns = 80,
}) => mode == PromptMode.rich
    ? OutputProfile(
        cursor: CapabilitySupport.supported,
        geometry: OutputGeometry.fixed(columns: columns, rows: 20),
        glyphs: ascii ? GlyphSet.ascii : GlyphSet.unicode,
      )
    : OutputProfile(
        geometry: OutputGeometry.fixed(columns: columns, rows: 20),
        glyphs: ascii ? GlyphSet.ascii : GlyphSet.automatic,
      );

ScriptedInput _scripted(
  PromptMode mode,
  String data,
  StringSink out, {
  bool ascii = false,
  int columns = 80,
}) => ScriptedInput(
  Stream.value(data),
  out,
  outputProfile: _profile(mode, ascii: ascii, columns: columns),
);

/// Splits output into display lines, dropping carriage returns a rich repaint
/// leaves at the start of a repainted row.
List<String> _lines(String text) => [
  for (final line in text.split('\n'))
    if (line.isNotEmpty) line.replaceFirst(RegExp(r'^\r+'), ''),
];

/// Asserts that [text] opens with [start] and, when [closes] is set, ends a
/// framed block with [end].
void _expectFramed(
  String text, {
  required String start,
  required String end,
  bool closes = true,
}) {
  final lines = _lines(text);
  expect(lines, isNotEmpty);
  expect(
    text,
    startsWith(start),
    reason: 'the first framed line opens the structure',
  );
  if (closes) {
    expect(text, contains(end), reason: 'a compact hint closes the structure');
  }
}

/// Asserts that [text] keeps every line inside [columns] display cells.
void _expectFitsWidth(String text, int columns) {
  for (final line in _lines(text)) {
    expect(
      TextDisplayMap(line).cellWidth,
      lessThanOrEqualTo(columns),
      reason: 'framed line "$line" must fit $columns columns',
    );
  }
}

class _Case {
  const _Case(this.name, this.answer, this.run, {this.richAnswer});

  final String name;
  final String answer;
  final String? richAnswer;
  final Future<Object?> Function(PromptMode mode, ScriptedInput input) run;

  String answerFor(PromptMode mode) =>
      mode == PromptMode.rich ? (richAnswer ?? answer) : answer;
}

List<_Case> _cases() => [
  _Case(
    'TextInput',
    'Ada\r',
    (mode, input) =>
        RailTheme.textInput('Name').prompt(source: input, mode: mode),
  ),
  _Case(
    'Password',
    'secret\rsubmit\r',
    (mode, input) =>
        RailTheme.password('Password').prompt(source: input, mode: mode),
  ),
  _Case(
    'Confirm',
    'yes\r',
    (mode, input) =>
        RailTheme.confirm('Decision').prompt(source: input, mode: mode),
    richAnswer: 'y\r',
  ),
  _Case(
    'Multiline',
    'abc\r/done\r',
    (mode, input) =>
        RailTheme.multiline('Notes').prompt(source: input, mode: mode),
    richAnswer: 'abc\t\r',
  ),
  _Case(
    'Select',
    '2\r',
    (mode, input) => RailTheme.select<String>('Choice', [
      Choice('a', 'First'),
      Choice('b', 'Second'),
    ]).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B\r',
  ),
  _Case(
    'MultiSelect',
    '2\r1\r/done\r',
    (mode, input) => RailTheme.multiSelect<String>('Choices', [
      Choice('a', 'A'),
      Choice('b', 'B'),
    ]).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B \x1b[A \r',
  ),
  _Case(
    'Slider',
    '\x7f\x7f\x7f0.6\r',
    (mode, input) => RailTheme.slider(
      'Volume',
      minimum: '0',
      maximum: '1',
      step: '0.2',
      initialValue: '0.4',
    ).prompt(source: input, mode: mode),
    richAnswer: '\x1b[C\t\t\r',
  ),
  _Case(
    'RangeSlider',
    '\x7f2\r\x7f8\r\r',
    (mode, input) => RailTheme.rangeSlider(
      'Window',
      minimum: '0',
      maximum: '10',
      step: '1',
      initialLower: '3',
      initialUpper: '5',
      minimumGap: '2',
    ).prompt(source: input, mode: mode),
    richAnswer: '\x1b[C\t\x1b[C\t\t\t\r',
  ),
  _Case(
    'TreeSelect',
    '/choose\r2\r',
    (mode, input) => RailTheme.treeSelect<String>('Tree', [
      TreeNode('a', 'A'),
      TreeNode('b', 'B'),
    ], defaultValue: 'b').prompt(source: input, mode: mode),
    richAnswer: '\r',
  ),
  _Case(
    'SortableSelect',
    '/move\r2\r1\r/done\r',
    (mode, input) => RailTheme.sortableSelect<String>('Order', [
      Choice('a', 'A'),
      Choice('b', 'B'),
    ]).prompt(source: input, mode: mode),
    richAnswer: ' \x1b[B\r\r',
  ),
  _Case(
    'TimeInput',
    '\r',
    (mode, input) => RailTheme.timeInput(
      'Time',
      initialValue: '23:59',
    ).prompt(source: input, mode: mode),
    richAnswer: '+\t+\t\t\r',
  ),
  _Case(
    'TagInput',
    'NewTag\r/done\r',
    (mode, input) =>
        RailTheme.tagInput('Tags').prompt(source: input, mode: mode),
    richAnswer: 'NewTag\r\t\r',
  ),
  _Case(
    'Autocomplete',
    'A\r1\r/submit\r',
    (mode, input) => RailTheme.autocomplete(
      'Name',
      suggestions: (_) => ['Ada'],
    ).prompt(source: input, mode: mode),
    richAnswer: 'A\x1b[B\r\r',
  ),
  _Case(
    'SearchSelect',
    '\r1\r',
    (mode, input) => RailTheme.searchSelect<String>('Fruit', [
      Choice('a', 'Apple'),
    ]).prompt(source: input, mode: mode),
    richAnswer: '\r\r',
  ),
  _Case(
    'CommandPalette',
    'sav\r1\r',
    (mode, input) => RailTheme.commandPalette<String>('Commands', [
      Choice('save', 'Save'),
    ]).prompt(source: input, mode: mode),
    richAnswer: 'sav\r\r',
  ),
  _Case(
    'TimezoneSelect',
    'US/Eastern\r105\r',
    (mode, input) =>
        RailTheme.timezoneSelect('Zone').prompt(source: input, mode: mode),
    richAnswer: 'US/Eastern\r\r',
  ),
  _Case(
    'MaskedInput',
    '/value\r\x7f3\r/done\r',
    (mode, input) => RailTheme.maskedInput(
      'Code',
      templates: [
        MaskTemplate('code', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
          MaskLiteral('-'),
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ],
      initialValue: MaskedValue('code', ['1', '2'], '1-2'),
    ).prompt(source: input, mode: mode),
    richAnswer: '\x7f3\r',
  ),
  _Case(
    'NumberInput',
    '12\r',
    (mode, input) => RailTheme.numberInput(
      'Count',
      convention: NumericConvention.ascii(),
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'PortInput',
    '99999\r\x7f\x7f\x7f\x7f\x7f443\r',
    (mode, input) =>
        RailTheme.portInput('Port').prompt(source: input, mode: mode),
  ),
  _Case(
    'IPAddressInput',
    '192.0.2.7/24\r',
    (mode, input) => RailTheme.ipAddressInput(
      'Address',
      cidr: true,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'URLInput',
    'https://example.com/\r',
    (mode, input) => RailTheme.urlInput(
      'URL',
      allowedSchemes: {'https'},
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'EmailInput',
    'Case@example.com\r',
    (mode, input) =>
        RailTheme.emailInput('Email').prompt(source: input, mode: mode),
  ),
  _Case(
    'ColorInput',
    '\r',
    (mode, input) => RailTheme.colorInput(
      'Color',
      initialValue: '#fff',
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'DurationInput',
    '1s\r',
    (mode, input) => RailTheme.durationInput(
      'Span',
      durationMode: DurationInputMode.elapsed,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'DateInput',
    '29/02/2024\r/submit\r',
    (mode, input) => RailTheme.dateInput(
      'Date',
      order: DateFieldOrder.dayMonthYear,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'CronInput',
    '* * * * *\r/submit\r',
    (mode, input) => RailTheme.cronInput(
      'Schedule',
      profile: CronProfile.unix,
    ).prompt(source: input, mode: mode),
    richAnswer: '* * * * *\r\t\r\t\r',
  ),
  _Case(
    'PathInput',
    '\r\r',
    (mode, input) => RailTheme.pathInput(
      'Path',
      initialValue: 'draft',
      allowNonexistent: true,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'FilePicker',
    'choose 1\r\r',
    (mode, input) => RailTheme.filePicker(
      'File',
      base: _pickerBase,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'DirectoryPicker',
    'choose\r\r',
    (mode, input) => RailTheme.directoryPicker(
      'Directory',
      base: _pickerBase,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'Keypress',
    '/capture\ra/done\r',
    (mode, input) =>
        RailTheme.keypress('Shortcut').prompt(source: input, mode: mode),
    richAnswer: 'ca\r',
  ),
  _Case(
    'KeyChordInput',
    '/capture\ra/capture\rb/done\r',
    (mode, input) =>
        RailTheme.keyChordInput('Sequence').prompt(source: input, mode: mode),
    richAnswer: 'cacb\r',
  ),
];

/// A directory the picker cases browse; created once for the file tree.
late String _pickerBase;

void main() {
  late Directory pickerDirectory;

  setUpAll(() async {
    pickerDirectory = await Directory.systemTemp.createTemp('structure-');
    await File('${pickerDirectory.path}${Platform.pathSeparator}answer.txt')
        .writeAsString('data');
    _pickerBase = pickerDirectory.path;
  });

  tearDownAll(() => pickerDirectory.delete(recursive: true));

  for (final mode in [PromptMode.linear, PromptMode.rich]) {
    group('RailTheme frames every component / ${mode.name}', () {
      for (final testCase in _cases()) {
        test(testCase.name, () async {
          final out = StringBuffer();
          final result = await testCase.run(
            mode,
            _scripted(mode, testCase.answerFor(mode), out),
          );
          expect(result, isNot(isA<Unavailable<Object?>>()));
          if (mode == PromptMode.rich) {
            _expectFramed(
              out.toString(),
              start: _railStart,
              end: _railEnd,
              closes: false,
            );
          } else {
            _expectFramed(
              out.toString(),
              start: _asciiRailStart,
              end: _asciiRailEnd,
              closes: false,
            );
            expect(
              out.toString(),
              isNot(contains('│')),
              reason: 'automatic glyph support falls back to ASCII',
            );
          }
        });
      }
    });

    group('BranchTheme frames every component / ${mode.name}', () {
      for (final testCase in _cases()) {
        test(testCase.name, () async {
          final out = StringBuffer();
          final result = await _branchRun(testCase, mode, out);
          expect(result, isNot(isA<Unavailable<Object?>>()));
          if (mode == PromptMode.rich) {
            _expectFramed(
              out.toString(),
              start: _branchStart,
              end: _railEnd,
              closes: false,
            );
          } else {
            _expectFramed(
              out.toString(),
              start: _asciiBranchStart,
              end: _asciiBranchEnd,
              closes: false,
            );
            expect(out.toString(), isNot(contains('├')));
          }
        });
      }
    });
  }

  group('PlainTheme stays unframed', () {
    for (final mode in [PromptMode.linear, PromptMode.rich]) {
      test('TextInput / ${mode.name}', () async {
        final out = StringBuffer();
        await PlainTheme.textInput('Name').prompt(
          source: _scripted(mode, 'Ada\r', out, ascii: true),
          mode: mode,
        );
        for (final glyph in [
          _railStart.trim(),
          _railEnd.trim(),
          _branchStart.trim(),
          _asciiRailStart.trim(),
          _asciiRailEnd.trim(),
          _asciiBranchStart,
        ]) {
          expect(out.toString(), isNot(contains(glyph)));
        }
      });
    }
  });

  group('structure width and carets', () {
    test(
      'a narrow rail keeps every framed line inside the declared width',
      () async {
        final out = StringBuffer();
        await RailTheme.textInput(
          'A deliberately long label that must wrap inside a narrow terminal',
        ).prompt(
          source: _scripted(PromptMode.rich, 'Ada\r', out, columns: 28),
          mode: PromptMode.rich,
        );
        _expectFitsWidth(
          out
              .toString()
              .split('\n')
              .where((line) => !line.contains('[2K'))
              .join('\n'),
          28,
        );
      },
    );

    test('a narrow branch keeps wrapping inside the declared width', () async {
      final out = StringBuffer();
      await BranchTheme.select<String>('Pick', [
        Choice('a', 'A very long choice label that needs wrapping'),
      ]).prompt(
        source: _scripted(PromptMode.rich, '\r', out, columns: 30),
        mode: PromptMode.rich,
      );
      _expectFitsWidth(
        out
            .toString()
            .split('\n')
            .where((line) => !line.contains('[2K'))
            .join('\n'),
        30,
      );
    });

    test(
      'the rich editable row keeps the rail prefix and the caret anchor',
      () async {
        final out = StringBuffer();
        await RailTheme.textInput('Name').prompt(
          source: _scripted(PromptMode.rich, 'Ada\r', out),
          mode: PromptMode.rich,
        );
        expect(out.toString(), contains('\r\x1b[2K$_railStart'));
        expect(out.toString(), contains('\x1b[s'));
        expect(out.toString(), contains('\x1b[u'));
      },
    );
  });

  group('structure stage help and protected content', () {
    test('rail help keeps the structure grammar in linear mode', () async {
      final out = StringBuffer();
      await RailTheme.textInput('Name').prompt(
        source: _scripted(PromptMode.linear, '/help\rAda\r', out),
        mode: PromptMode.linear,
      );
      expect(out.toString(), contains('Help:'));
      expect(out.toString(), contains(_asciiRailStart));
    });

    test('branch help keeps the structure grammar in rich mode', () async {
      final out = StringBuffer();
      await BranchTheme.textInput('Name').prompt(
        source: _scripted(PromptMode.rich, '\x14\x1bAda\r', out),
        mode: PromptMode.rich,
      );
      expect(out.toString(), contains('Help:'));
      expect(out.toString(), contains(_branchContinue));
    });

    test(
      'a protected validation message keeps its spelling inside the frame',
      () async {
        final out = StringBuffer();
        final result =
            await RailTheme.textInput(
              'Name',
              validate: (value) =>
                  value == 'Ada' ? null : 'Name must be Ada\u0007.',
            ).prompt(
              source: _scripted(
                PromptMode.linear,
                'Bob\r\x7f\x7f\x7fAda\r',
                out,
              ),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, 'Ada');
        expect(out.toString(), contains('Name must be Ada\\u{0007}.'));
        expect(out.toString(), contains(_asciiRailStart));
      },
    );

    test(
      'the compact hint closes the rail before the accepted summary',
      () async {
        final out = StringBuffer();
        final result = await RailTheme.confirm('Decision').prompt(
          source: _scripted(PromptMode.linear, 'yes\r', out),
          mode: PromptMode.linear,
        );
        expect((result as Accepted<bool>).value, isTrue);
        expect(out.toString(), contains(_asciiRailEnd));
        expect(out.toString(), contains('Accepted: Yes.'));
      },
    );
  });

  group('structure palette overrides', () {
    test(
      'a custom palette styles the framed rail without changing the answer',
      () async {
        final out = StringBuffer();
        final result =
            await RailTheme.textInput(
              'Name',
              colors: ColorThemes.midnightMint,
            ).prompt(
              source: _scripted(PromptMode.linear, 'Ada\r', out),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, 'Ada');
        expect(out.toString(), contains('\x1b['));
        expect(out.toString(), contains(_asciiRailStart));
      },
    );

    test('feedback keeps its lifecycle while gaining a structure prefix', () {
      final out = StringBuffer();
      final spinner = BranchTheme.spinner('Build');
      spinner.start(output: out, mode: PromptMode.linear, supportsRich: true);
      spinner.finish(FeedbackOutcome.failed, detail: 'disk');
      expect(out.toString(), contains('failed: disk'));
      expect(out.toString(), contains(_asciiBranchStart));
    });
  });
}

const _branchContinue = '│ ';

Future<Object?> _branchRun(
  _Case testCase,
  PromptMode mode,
  StringSink out,
) async {
  final input = _scripted(mode, testCase.answerFor(mode), out);
  return _branchDispatch(testCase.name, mode, input);
}

/// Runs the branch-theme counterpart of one acceptance case.
///
/// The cases share their scripted input; only the factory namespace differs, so
/// the branch run mirrors the rail matrix without duplicating 30 closures.
Future<Object?> _branchDispatch(
  String name,
  PromptMode mode,
  ScriptedInput input,
) async {
  switch (name) {
    case 'TextInput':
      return BranchTheme.textInput('Name').prompt(source: input, mode: mode);
    case 'Password':
      return BranchTheme.password('Password').prompt(source: input, mode: mode);
    case 'Confirm':
      return BranchTheme.confirm('Decision').prompt(source: input, mode: mode);
    case 'Multiline':
      return BranchTheme.multiline('Notes').prompt(source: input, mode: mode);
    case 'Select':
      return BranchTheme.select<String>('Choice', [
        Choice('a', 'First'),
        Choice('b', 'Second'),
      ]).prompt(source: input, mode: mode);
    case 'MultiSelect':
      return BranchTheme.multiSelect<String>('Choices', [
        Choice('a', 'A'),
        Choice('b', 'B'),
      ]).prompt(source: input, mode: mode);
    case 'Slider':
      return BranchTheme.slider(
        'Volume',
        minimum: '0',
        maximum: '1',
        step: '0.2',
        initialValue: '0.4',
      ).prompt(source: input, mode: mode);
    case 'RangeSlider':
      return BranchTheme.rangeSlider(
        'Window',
        minimum: '0',
        maximum: '10',
        step: '1',
        initialLower: '3',
        initialUpper: '5',
        minimumGap: '2',
      ).prompt(source: input, mode: mode);
    case 'TreeSelect':
      return BranchTheme.treeSelect<String>('Tree', [
        TreeNode('a', 'A'),
        TreeNode('b', 'B'),
      ], defaultValue: 'b').prompt(source: input, mode: mode);
    case 'SortableSelect':
      return BranchTheme.sortableSelect<String>('Order', [
        Choice('a', 'A'),
        Choice('b', 'B'),
      ]).prompt(source: input, mode: mode);
    case 'TimeInput':
      return BranchTheme.timeInput(
        'Time',
        initialValue: '23:59',
      ).prompt(source: input, mode: mode);
    case 'TagInput':
      return BranchTheme.tagInput('Tags').prompt(source: input, mode: mode);
    case 'Autocomplete':
      return BranchTheme.autocomplete(
        'Name',
        suggestions: (_) => ['Ada'],
      ).prompt(source: input, mode: mode);
    case 'SearchSelect':
      return BranchTheme.searchSelect<String>('Fruit', [
        Choice('a', 'Apple'),
      ]).prompt(source: input, mode: mode);
    case 'CommandPalette':
      return BranchTheme.commandPalette<String>('Commands', [
        Choice('save', 'Save'),
      ]).prompt(source: input, mode: mode);
    case 'TimezoneSelect':
      return BranchTheme.timezoneSelect('Zone')
          .prompt(source: input, mode: mode);
    case 'MaskedInput':
      return BranchTheme.maskedInput(
        'Code',
        templates: [
          MaskTemplate('code', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskLiteral('-'),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
        ],
        initialValue: MaskedValue('code', ['1', '2'], '1-2'),
      ).prompt(source: input, mode: mode);
    case 'NumberInput':
      return BranchTheme.numberInput(
        'Count',
        convention: NumericConvention.ascii(),
      ).prompt(source: input, mode: mode);
    case 'PortInput':
      return BranchTheme.portInput('Port').prompt(source: input, mode: mode);
    case 'IPAddressInput':
      return BranchTheme.ipAddressInput(
        'Address',
        cidr: true,
      ).prompt(source: input, mode: mode);
    case 'URLInput':
      return BranchTheme.urlInput(
        'URL',
        allowedSchemes: {'https'},
      ).prompt(source: input, mode: mode);
    case 'EmailInput':
      return BranchTheme.emailInput('Email').prompt(source: input, mode: mode);
    case 'ColorInput':
      return BranchTheme.colorInput(
        'Color',
        initialValue: '#fff',
      ).prompt(source: input, mode: mode);
    case 'DurationInput':
      return BranchTheme.durationInput(
        'Span',
        durationMode: DurationInputMode.elapsed,
      ).prompt(source: input, mode: mode);
    case 'DateInput':
      return BranchTheme.dateInput(
        'Date',
        order: DateFieldOrder.dayMonthYear,
      ).prompt(source: input, mode: mode);
    case 'CronInput':
      return BranchTheme.cronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt(source: input, mode: mode);
    case 'PathInput':
      return BranchTheme.pathInput(
        'Path',
        initialValue: 'draft',
        allowNonexistent: true,
      ).prompt(source: input, mode: mode);
    case 'FilePicker':
      return BranchTheme.filePicker(
        'File',
        base: _pickerBase,
      ).prompt(source: input, mode: mode);
    case 'DirectoryPicker':
      return BranchTheme.directoryPicker(
        'Directory',
        base: _pickerBase,
      ).prompt(source: input, mode: mode);
    case 'Keypress':
      return BranchTheme.keypress('Shortcut').prompt(source: input, mode: mode);
    case 'KeyChordInput':
      return BranchTheme.keyChordInput('Sequence')
          .prompt(source: input, mode: mode);
    default:
      throw StateError('No branch case for $name');
  }
}
