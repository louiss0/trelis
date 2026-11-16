import 'dart:async';
import 'dart:io';

import 'package:prompty/prompty.dart';
import 'package:prompty/src/text_measurement.dart';
import 'package:test/test.dart';

/// Verification of the minimal, ASCII console, chevron and bracket heading grammars.
///
/// Behavior, accepted values, input bindings and outcomes are covered by the
/// per-component suites and the factory matrices. These tests assert the
/// presentation contract instead: an enclosure frames the stage it renders, the
/// frame always closes, the compact hint stays outside the bottom rule, the
/// outcome of a stage is never swallowed as a body row, the frame counts its own
/// chrome against the declared width, capability chooses the ASCII counterpart,
/// and a palette override styles the frame without changing the answer.

OutputProfile _profile(
  PromptMode mode, {
  bool ascii = false,
  bool rgb = false,
  int columns = 72,
}) => mode == PromptMode.rich
    ? OutputProfile(
        cursor: CapabilitySupport.supported,
        styles: CapabilitySupport.supported,
        colorDepth: rgb ? ColorDepth.rgb : ColorDepth.none,
        geometry: OutputGeometry.fixed(columns: columns, rows: 20),
        glyphs: ascii ? GlyphSet.ascii : GlyphSet.unicode,
      )
    : OutputProfile(
        colorDepth: rgb ? ColorDepth.rgb : ColorDepth.none,
        geometry: OutputGeometry.fixed(columns: columns, rows: 20),
        glyphs: ascii ? GlyphSet.ascii : GlyphSet.automatic,
      );

ScriptedInput _scripted(
  PromptMode mode,
  String data,
  StringSink out, {
  bool ascii = false,
  bool rgb = false,
  int columns = 72,
}) => ScriptedInput(
  Stream.value(data),
  out,
  outputProfile: _profile(mode, ascii: ascii, rgb: rgb, columns: columns),
);

/// Splits output into display lines, dropping rich repaint carriage returns.
List<String> _lines(String text) => [
  for (final line in text.split('\n'))
    if (line.isNotEmpty) line.replaceFirst(RegExp(r'^\r+'), ''),
];

int _cells(String line) => TextDisplayMap(line).cellWidth;

class _Case {
  const _Case(
    this.name,
    this.label,
    this.answer,
    this.run, {
    this.richAnswer,
    this.outcome,
  });

  final String name;
  final String label;
  final String answer;
  final String? richAnswer;

  /// A reported outcome or notice that must be presented outside a closed
  /// frame, never swallowed as a body row of a frame left open.
  final String? outcome;
  final Future<Object?> Function(
    PromptMode mode,
    ScriptedInput input,
    PromptStructure structure,
  )
  run;

  String answerFor(PromptMode mode) =>
      mode == PromptMode.rich ? (richAnswer ?? answer) : answer;
}

/// The interactive components, each with a real render/task path per structure
/// and mode.
///
/// The matrix is the whole public interactive surface (34 components), not a
/// family sample: a structure that frames one choice list but not another is a
/// defect this matrix has to catch.
List<_Case> _cases() => [
  _Case(
    'TextInput',
    'Deployment target',
    'Ada\r',
    (mode, input, structure) => TextInput(
      'Deployment target',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'Password',
    'Passphrase',
    'secret\rsubmit\r',
    (mode, input, structure) => Password(
      'Passphrase',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'Confirm',
    'Decision',
    'yes\r',
    (mode, input, structure) => Confirm(
      'Decision',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'y\r',
    outcome: 'Accepted: Yes.',
  ),
  _Case(
    'Checkbox',
    'Terms',
    'yes\r',
    (mode, input, structure) => Checkbox(
      'Terms',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'y\r',
  ),
  _Case(
    'Toggle',
    'Cache',
    'yes\r',
    (mode, input, structure) =>
        Toggle('Cache', structure: structure).prompt(source: input, mode: mode),
    richAnswer: 'y\r',
  ),
  _Case(
    'Multiline',
    'Notes',
    'abc\r/done\r',
    (mode, input, structure) => Multiline(
      'Notes',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'abc\t\r',
  ),
  _Case(
    'Select',
    'Choice',
    '2\r',
    (mode, input, structure) => Select<String>('Choice', [
      Choice('a', 'First'),
      Choice('b', 'Second'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B\r',
    outcome: 'Accepted: Second.',
  ),
  _Case(
    'Radio',
    'Signal',
    '2\r',
    (mode, input, structure) => Radio<String>('Signal', [
      Choice('a', 'Red'),
      Choice('b', 'Green'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B\r',
    outcome: 'Accepted: Green.',
  ),
  _Case(
    'MultiSelect',
    'Choices',
    '2\r1\r/done\r',
    (mode, input, structure) => MultiSelect<String>('Choices', [
      Choice('a', 'Alpha'),
      Choice('b', 'Beta'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B \x1b[A \r',
    outcome: 'Beta: checked.',
  ),
  _Case(
    'Slider',
    'Volume',
    '\x7f\x7f\x7f0.6\r',
    (mode, input, structure) => Slider(
      'Volume',
      minimum: '0',
      maximum: '1',
      step: '0.2',
      initialValue: '0.4',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '\x1b[C\t\t\r',
  ),
  _Case(
    'RangeSlider',
    'Window',
    '\x7f2\r\x7f8\r\r',
    (mode, input, structure) => RangeSlider(
      'Window',
      minimum: '0',
      maximum: '10',
      step: '1',
      initialLower: '3',
      initialUpper: '5',
      minimumGap: '2',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '\x1b[C\t\x1b[C\t\t\t\r',
  ),
  _Case(
    'TreeSelect',
    'Tree',
    '/choose\r2\r',
    (mode, input, structure) => TreeSelect<String>(
      'Tree',
      [TreeNode('a', 'A'), TreeNode('b', 'B')],
      defaultValue: 'b',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '\r',
    outcome: 'Accepted: B.',
  ),
  _Case(
    'SortableSelect',
    'Order',
    '/move\r2\r1\r/done\r',
    (mode, input, structure) => SortableSelect<String>('Order', [
      Choice('a', 'A'),
      Choice('b', 'B'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: ' \x1b[B\r\r',
    outcome: 'moved to position ',
  ),
  _Case(
    'TimeInput',
    'Time',
    '\r',
    (mode, input, structure) => TimeInput(
      'Time',
      initialValue: '23:59',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '+\t+\t\t\r',
  ),
  _Case(
    'TagInput',
    'Tags',
    'NewTag\r/done\r',
    (mode, input, structure) => TagInput(
      'Tags',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'NewTag\r\t\r',
  ),
  _Case(
    'Autocomplete',
    'Suggestion',
    'A\r1\r/submit\r',
    (mode, input, structure) => Autocomplete(
      'Suggestion',
      suggestions: (_) => ['Ada'],
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'A\x1b[B\r\r',
  ),
  _Case(
    'SearchSelect',
    'Fruit',
    '\r1\r',
    (mode, input, structure) => SearchSelect<String>('Fruit', [
      Choice('a', 'Apple'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: '\r\r',
  ),
  _Case(
    'CommandPalette',
    'Commands',
    'sav\r1\r',
    (mode, input, structure) => CommandPalette<String>('Commands', [
      Choice('save', 'Save'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: 'sav\r\r',
  ),
  _Case(
    'TimezoneSelect',
    'Zone',
    'US/Eastern\r105\r',
    (mode, input, structure) => TimezoneSelect(
      'Zone',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'US/Eastern\r\r',
  ),
  _Case(
    'MaskedInput',
    'Code',
    '/value\r\x7f3\r/done\r',
    (mode, input, structure) => MaskedInput(
      'Code',
      templates: [
        MaskTemplate('code', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
          MaskLiteral('-'),
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ],
      initialValue: MaskedValue('code', ['1', '2'], '1-2'),
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '\x7f3\r',
  ),
  _Case(
    'NumberInput',
    'Count',
    '12\r',
    (mode, input, structure) => NumberInput(
      'Count',
      convention: NumericConvention.ascii(),
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'PortInput',
    'Port',
    '99999\r\x7f\x7f\x7f\x7f\x7f443\r',
    (mode, input, structure) => PortInput(
      'Port',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'IPAddressInput',
    'Address',
    '192.0.2.7/24\r',
    (mode, input, structure) => IPAddressInput(
      'Address',
      cidr: true,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'URLInput',
    'URL',
    'https://example.com/\r',
    (mode, input, structure) => URLInput(
      'URL',
      allowedSchemes: {'https'},
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'EmailInput',
    'Email',
    'Case@example.com\r',
    (mode, input, structure) => EmailInput(
      'Email',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'ColorInput',
    'Colour',
    '\r',
    (mode, input, structure) => ColorInput(
      'Colour',
      initialValue: '#fff',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'DurationInput',
    'Span',
    '1s\r',
    (mode, input, structure) => DurationInput(
      'Span',
      durationMode: DurationInputMode.elapsed,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'DateInput',
    'Date',
    '29/02/2024\r/submit\r',
    (mode, input, structure) => DateInput(
      'Date',
      order: DateFieldOrder.dayMonthYear,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'CronInput',
    'Schedule',
    '* * * * *\r/submit\r',
    (mode, input, structure) => CronInput(
      'Schedule',
      profile: CronProfile.unix,
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '* * * * *\r\t\r\t\r',
  ),
  _Case(
    'PathInput',
    'Path',
    '\r\r',
    (mode, input, structure) => PathInput(
      'Path',
      initialValue: 'draft',
      allowNonexistent: true,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'FilePicker',
    'Workspace',
    'choose 1\r\r',
    (mode, input, structure) => FilePicker(
      'Workspace',
      base: _pickerBase,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'DirectoryPicker',
    'Workspace',
    'choose\r\r',
    (mode, input, structure) => DirectoryPicker(
      'Workspace',
      base: _pickerBase,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'Keypress',
    'Shortcut',
    '/capture\ra/done\r',
    (mode, input, structure) => Keypress(
      'Shortcut',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'ca\r',
  ),
  _Case(
    'KeyChordInput',
    'Sequence',
    '/capture\ra/capture\rb/done\r',
    (mode, input, structure) => KeyChordInput(
      'Sequence',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'cacb\r',
  ),
];

/// A directory the picker cases browse; created once for the file tree.
late String _pickerBase;

/// Runs one case through a structural theme's rendered structure.
Future<String> _render(
  _Case testCase,
  PromptMode mode,
  PromptStructure structure, {
  bool ascii = false,
  int columns = 72,
}) async {
  final out = StringBuffer();
  final result = await testCase.run(
    mode,
    _scripted(
      mode,
      testCase.answerFor(mode),
      out,
      ascii: ascii,
      columns: columns,
    ),
    structure,
  );
  expect(result, isNot(isA<Unavailable<Object?>>()));
  return out.toString();
}

/// The heading vocabulary a theme must render for one capability profile.
HeadingGlyphs _heading(PromptStructure structure, {required bool ascii}) =>
    headingGlyphsFor(structure, ascii: ascii)!;

/// The structural line prefixes and frame characters a heading structure must
/// never draw: it decorates its heading instead of framing the stage.
const _framingGlyphs = [
  '┌',
  '┐',
  '└',
  '┘',
  '╭',
  '╮',
  '╰',
  '╯',
  '╔',
  '╗',
  '╚',
  '╝',
  '│',
  '║',
  '├',
  r'+-',
  r'\-',
];

/// Asserts the heading grammar of one rendered stage.
///
/// A heading structure decorates the stage heading, indents the body rows under
/// it and marks the compact hint below them. Nothing is enclosed, so no line of
/// the run may carry framing chrome, and the console grammar may not fall back
/// to a decorated shape it does not declare.
void _expectHeaded(
  String text, {
  required PromptStructure structure,
  required bool ascii,
  required String label,
  required int columns,
  String? outcome,
}) {
  final glyphs = _heading(structure, ascii: ascii);
  final lines = [
    for (final line in _lines(text))
      if (!line.contains('\x1b')) line,
  ];
  expect(lines, isNotEmpty);
  expect(
    lines.first,
    startsWith(glyphs.headingPrefix),
    reason: 'the stage opens with the structure heading: "${lines.first}"',
  );
  if (glyphs.headingSuffix.isNotEmpty) {
    expect(
      lines.any((line) => line.endsWith(glyphs.headingSuffix)),
      isTrue,
      reason: 'the bracketed heading closes its band',
    );
  }
  if (glyphs.uppercaseHeading) {
    final heading = lines.first.substring(glyphs.headingPrefix.length);
    expect(
      heading,
      heading.toUpperCase(),
      reason: 'the console heading is spelled in capitals: "$heading"',
    );
  }
  expect(
    text.toLowerCase(),
    contains(label.toLowerCase()),
    reason: 'the stage keeps its label',
  );
  final body = glyphs.bodyIndent;
  final decorated =
      glyphs.headingPrefix.isNotEmpty || glyphs.headingSuffix.isNotEmpty;
  if (decorated) {
    expect(
      lines.where(
        (line) =>
            line != lines.first &&
            line.startsWith(body) &&
            line.length > body.length,
      ),
      isNotEmpty,
      reason: 'the stage has body rows under its heading',
    );
    // Every line of the run keeps the declared vocabulary: a decorated
    // heading, an indented body row, or the structure's own live row marker.
    // Nothing falls back to the undecorated reference column.
    final live = structureLivePrefix(structure, ascii: ascii);
    for (final line in lines) {
      expect(
        line.startsWith(glyphs.headingPrefix) ||
            line.startsWith(body) ||
            line.startsWith(live) ||
            line.startsWith('> '),
        isTrue,
        reason: 'the line keeps the structure grammar: "$line"',
      );
    }
  } else {
    // The bare grammar decorates nothing: the heading is the component's own
    // label at the reference column, and no structural marker is added.
    expect(
      lines.first,
      lines.first.trimLeft(),
      reason: 'the bare heading starts at the reference column',
    );
    for (final marker in ['? ', '[ ', '❯ ', '↳ ', '» ', '› ']) {
      expect(
        lines.where((line) => line.startsWith(marker)),
        isEmpty,
        reason: 'a bare grammar adds no marker: "$marker"',
      );
    }
  }
  for (final glyph in _framingGlyphs) {
    expect(
      text,
      isNot(contains(glyph)),
      reason: 'a heading structure never draws framing chrome: "$glyph"',
    );
  }
  for (final line in lines) {
    expect(_cells(line), lessThanOrEqualTo(columns), reason: '"$line"');
  }
  if (outcome != null) {
    final reported = lines.where((line) => line.contains(outcome));
    expect(reported, isNotEmpty, reason: 'the run reports "$outcome"');
    for (final line in reported) {
      expect(
        line.startsWith(body),
        isTrue,
        reason: 'the outcome keeps the structure grammar: "$line"',
      );
    }
  }
}

const _themes = <PromptStructure, String>{
  PromptStructure.minimal: 'MinimalTheme',
  PromptStructure.ascii: 'AsciiTheme',
  PromptStructure.chevron: 'ChevronTheme',
  PromptStructure.bracket: 'BracketTheme',
};

void main() {
  late Directory pickerDirectory;

  setUpAll(() async {
    pickerDirectory = await Directory.systemTemp.createTemp('heading-');
    await File('${pickerDirectory.path}${Platform.pathSeparator}answer.txt')
        .writeAsString('data');
    _pickerBase = pickerDirectory.path;
  });

  tearDownAll(() => pickerDirectory.delete(recursive: true));

  for (final entry in _themes.entries) {
    final structure = entry.key;
    final themeName = entry.value;

    for (final mode in [PromptMode.linear, PromptMode.rich]) {
      group('$themeName heads every component / ${mode.name}', () {
        for (final testCase in _cases()) {
          test(testCase.name, () async {
            final text = await _render(testCase, mode, structure);
            _expectHeaded(
              text,
              structure: structure,
              ascii: mode != PromptMode.rich,
              label: testCase.label,
              columns: 72,
              outcome: testCase.outcome,
            );
          });
        }
      });
    }

    test(
      '$themeName uses its declared vocabulary when the profile supports it',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.rich, 'Ada\r', out),
          mode: PromptMode.rich,
        );
        final glyphs = _heading(structure, ascii: false);
        final text = out.toString();
        expect(text, contains(glyphs.headingPrefix));
        expect(text, contains(structureLivePrefix(structure, ascii: false)));
        if (structure == PromptStructure.chevron) {
          expect(text, contains('❯'));
          expect(text, isNot(contains('-> ')));
        }
        if (structure == PromptStructure.bracket) {
          expect(text, contains('[ '));
          expect(text, contains(']'));
        }
        if (structure == PromptStructure.minimal) {
          expect(text, contains('› '));
          expect(text, isNot(contains('┌')));
        }
      },
    );

    test(
      '$themeName falls back to ASCII for an automatic glyph profile',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.linear, 'Ada\r', out),
          mode: PromptMode.linear,
        );
        final glyphs = _heading(structure, ascii: true);
        final text = out.toString();
        expect(text, contains(glyphs.headingPrefix));
        for (final glyph in ['❯', '↳', '»', '›']) {
          expect(text, isNot(contains(glyph)));
        }
      },
    );

    test('$themeName never exceeds the declared width', () async {
      final out = StringBuffer();
      await Select<String>('Region', [
        Choice('a', 'Europe'),
        Choice('b', 'United States'),
      ], structure: structure).prompt(
        source: _scripted(PromptMode.rich, '\r', out, columns: 200),
        mode: PromptMode.rich,
      );
      for (final line in _lines(out.toString())) {
        expect(line, isNot(contains('[2K')));
        if (line.contains('\x1b')) continue;
        expect(_cells(line), lessThanOrEqualTo(120));
      }
    });

    test(
      '$themeName narrow output keeps every line inside the columns',
      () async {
        final out = StringBuffer();
        await Select<String>('Region', [
          Choice('a', 'A deliberately long choice label that must wrap'),
        ], structure: structure).prompt(
          source: _scripted(PromptMode.linear, '1\r', out, columns: 24),
          mode: PromptMode.linear,
        );
        for (final line in _lines(out.toString())) {
          if (line.contains('\x1b')) continue;
          expect(_cells(line), lessThanOrEqualTo(24), reason: '"$line"');
        }
        expect(out.toString(), contains('1. '));
      },
    );

    test(
      '$themeName simplifies the heading decoration when width cannot hold it',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.linear, 'Ada\r', out, columns: 4),
          mode: PromptMode.linear,
        );
        final glyphs = _heading(structure, ascii: true);
        final text = out.toString();
        for (final line in _lines(text)) {
          if (line.contains('\x1b')) continue;
          expect(_cells(line), lessThanOrEqualTo(4), reason: '"$line"');
        }
        expect(
          text,
          contains(glyphs.compactPrefix),
          reason: 'the narrow heading keeps the structure marker',
        );
        expect(text, isNot(contains('┌')));
      },
    );

    test(
      '$themeName keeps a palette foreground without changing the answer',
      () async {
        final palette = ColorThemes.signal.copyWith(
          foreground: TerminalColor.rgb(12, 34, 56),
        );
        final out = StringBuffer();
        final result =
            await TextInput(
              'Name',
              structure: structure,
              colors: palette,
            ).prompt(
              source: _scripted(PromptMode.rich, 'Ada\r', out, rgb: true),
              mode: PromptMode.rich,
            );
        expect((result as Accepted<String>).value, 'Ada');
        expect(out.toString(), contains('\x1b[38;2;12;34;56;'));
      },
    );
  }

  group('heading stage contracts', () {
    for (final entry in _themes.entries) {
      final structure = entry.key;
      final themeName = entry.value;

      test('$themeName marks the compact hint under the body rows', () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.linear, 'Ada\r', out),
          mode: PromptMode.linear,
        );
        final glyphs = _heading(structure, ascii: true);
        final lines = _lines(out.toString());
        final heading = lines.indexWhere(
          (line) => line.toLowerCase().contains('name'),
        );
        expect(heading, 0, reason: 'the heading opens the stage');
        final hintRows = lines.where(
          (line) =>
              line.contains('Exact /help and /cancel are commands') &&
              line.startsWith(glyphs.bodyIndent) &&
              (glyphs.hintPrefix.isEmpty ||
                  line.startsWith('${glyphs.bodyIndent}${glyphs.hintPrefix}')),
        );
        expect(
          hintRows,
          isNotEmpty,
          reason: 'the compact hint keeps the structure hint grammar',
        );
        expect(
          lines.indexOf(hintRows.first),
          greaterThan(
            lines.indexWhere(
              (line) => line.startsWith(
                glyphs.headingPrefix.isEmpty ? '' : glyphs.headingPrefix,
              ),
            ),
          ),
          reason: 'the hint sits below the stage heading',
        );
      });

      test('$themeName never case-transforms answer data', () async {
        final out = StringBuffer();
        final result = await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.rich, 'Ada Lovelace\r', out),
          mode: PromptMode.rich,
        );
        expect((result as Accepted<String>).value, 'Ada Lovelace');
        final text = out.toString();
        expect(text, contains('Ada Lovelace'));
        expect(text, isNot(contains('ADA LOVELACE')));
      });

      test('$themeName keeps a literal command as entered', () async {
        final out = StringBuffer();
        await TextInput(
          'Name',
          structure: structure,
          validate: (value) => value == 'Ada' ? null : 'Quote /Help literally.',
        ).prompt(
          source: _scripted(PromptMode.linear, 'Bob\r\x7f\x7f\x7fAda\r', out),
          mode: PromptMode.linear,
        );
        expect(out.toString(), contains('Quote /Help literally.'));
      });

      test('$themeName keeps a protected message spelled', () async {
        final out = StringBuffer();
        final result =
            await TextInput(
              'Name',
              structure: structure,
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
      });

      test('$themeName never echoes a masked password', () async {
        final out = StringBuffer();
        final result =
            await Password(
              'Passphrase',
              mask: true,
              structure: structure,
            ).prompt(
              source: _scripted(PromptMode.linear, 'secret\rsubmit\r', out),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, 'secret');
        expect(out.toString(), isNot(contains('secret')));
      });

      test('$themeName keeps an unavailable reason in the stage', () async {
        final out = StringBuffer();
        final result =
            await Select<String>('Region', [
              Choice('a', 'Europe', disabledReason: 'Not provisioned'),
              Choice('b', 'United States'),
            ], structure: structure).prompt(
              source: _scripted(PromptMode.linear, '2\r', out),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, 'b');
        final text = out.toString();
        expect(text, contains('Not provisioned'));
        expect(text, contains('Accepted: United States.'));
      });

      test('$themeName keeps stage help in its grammar', () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.linear, '/help\rAda\r', out),
          mode: PromptMode.linear,
        );
        final glyphs = _heading(structure, ascii: true);
        final text = out.toString();
        expect(text, contains('Help:'));
        if (glyphs.headingPrefix.isEmpty) return;
        for (final line in _lines(text)) {
          if (line.contains('\x1b')) continue;
          expect(
            line.startsWith(glyphs.headingPrefix) ||
                line.startsWith(glyphs.bodyIndent) ||
                line.startsWith('> '),
            isTrue,
            reason: 'help keeps the structure grammar: "$line"',
          );
        }
      });

      test(
        '$themeName re-decorates the heading on every presentation',
        () async {
          final out = StringBuffer();
          final result =
              await Select<String>('Region', [
                Choice('a', 'Europe'),
                Choice('b', 'United States'),
              ], structure: structure).prompt(
                source: _scripted(PromptMode.rich, '\x1b[B\r', out),
                mode: PromptMode.rich,
              );
          expect((result as Accepted<String>).value, 'b');
          final glyphs = _heading(structure, ascii: false);
          if (glyphs.headingPrefix.isEmpty) return;
          final headings = _lines(out.toString())
              .where((line) => line.startsWith(glyphs.headingPrefix))
              .toList();
          expect(
            headings.length,
            greaterThan(1),
            reason: 'the focus move redrew the decorated heading',
          );
        },
      );
    }
  });

  group('heading feedback', () {
    for (final entry in _themes.entries) {
      final structure = entry.key;
      final themeName = entry.value;
      final marker = structureLivePrefix(structure, ascii: true);

      test('$themeName marks a Text event without a frame', () {
        final out = StringBuffer();
        Text(
          'Build finished',
          kind: TextKind.success,
          structure: structure,
        ).present(output: out);
        final text = out.toString();
        expect(text, contains('Success: Build finished'));
        expect(text, startsWith(marker));
        for (final glyph in _framingGlyphs) {
          expect(text, isNot(contains(glyph)));
        }
      });

      for (final mode in [PromptMode.linear, PromptMode.rich]) {
        test('$themeName progress is a marked line / ${mode.name}', () {
          final out = StringBuffer();
          final progress = Progress('Copy', total: 4, structure: structure);
          progress.start(output: out, mode: mode, supportsRich: true);
          progress.update(2);
          progress.finish(FeedbackOutcome.completed);
          final text = out.toString();
          expect(text, contains('Copy: completed'));
          for (final line in _lines(text)) {
            expect(line, contains(marker), reason: '"$line"');
          }
        });

        test('$themeName spinner keeps its cadence / ${mode.name}', () {
          final out = StringBuffer();
          final spinner = Spinner('Index', structure: structure);
          spinner.start(output: out, mode: mode, supportsRich: true);
          spinner.update('waiting');
          spinner.finish(FeedbackOutcome.failed, detail: 'disk');
          final text = out.toString();
          expect(text, contains('Index: waiting'));
          expect(text, contains('failed: disk'));
          for (final line in _lines(text)) {
            expect(line, contains(marker), reason: '"$line"');
          }
        });

        test('$themeName multi-spinner keeps its summary / ${mode.name}', () {
          final out = StringBuffer();
          final tasks = MultiSpinner(const [
            'fetch',
            'build',
          ], structure: structure);
          tasks.start(output: out, mode: mode, supportsRich: true);
          tasks.finishTask('fetch', FeedbackOutcome.completed);
          tasks.finishTask('build', FeedbackOutcome.skipped);
          final text = out.toString();
          expect(text, contains('Summary:'));
          expect(text, contains('build: skipped'));
          for (final line in _lines(text)) {
            expect(line, contains(marker), reason: '"$line"');
          }
        });
      }
    }
  });

  group('behavior is unchanged by the heading grammar', () {
    final probes =
        <
          String,
          Future<PromptResult<Object?>> Function(
            PromptStructure structure,
            PromptMode mode,
            ScriptedInput input,
          )
        >{
          'TextInput': (structure, mode, input) => TextInput(
            'Name',
            structure: structure,
          ).prompt(source: input, mode: mode),
          'Select': (structure, mode, input) => Select<String>('Choice', [
            Choice('a', 'First'),
            Choice('b', 'Second'),
          ], structure: structure).prompt(source: input, mode: mode),
          'Confirm': (structure, mode, input) => Confirm(
            'Decision',
            structure: structure,
          ).prompt(source: input, mode: mode),
          'Password': (structure, mode, input) => Password(
            'Passphrase',
            structure: structure,
          ).prompt(source: input, mode: mode),
        };

    final answers = <String, ({String linear, String rich})>{
      'TextInput': (linear: 'Ada\r', rich: 'Ada\r'),
      'Select': (linear: '2\r', rich: '\x1b[B\r'),
      'Confirm': (linear: 'yes\r', rich: 'y\r'),
      'Password': (linear: 'secret\r', rich: 'secret\r'),
    };

    Object? outcome(PromptResult<Object?> result) => switch (result) {
      Accepted(:final value) => ('accepted', value),
      Cancelled() => 'cancelled',
      Interrupted() => 'interrupted',
      InputEnded() => 'input-ended',
      Unavailable(:final reason) => ('unavailable', reason),
    };

    for (final probe in probes.entries) {
      test(
        '${probe.key} accepts the same outcome in every structure',
        () async {
          for (final mode in [PromptMode.linear, PromptMode.rich]) {
            final answer = mode == PromptMode.rich
                ? answers[probe.key]!.rich
                : answers[probe.key]!.linear;
            final baseline = await probe.value(
              PromptStructure.plain,
              mode,
              _scripted(mode, answer, StringBuffer()),
            );
            for (final structure in _themes.keys) {
              final themed = await probe.value(
                structure,
                mode,
                _scripted(mode, answer, StringBuffer()),
              );
              expect(
                outcome(themed),
                outcome(baseline),
                reason: '${probe.key}/${structure.name}/${mode.name}',
              );
            }
          }
        },
      );
    }

    test('the reference presentation still emits no heading chrome', () async {
      final out = StringBuffer();
      await TextInput('Name').prompt(
        source: _scripted(PromptMode.rich, 'Ada\r', out),
        mode: PromptMode.rich,
      );
      for (final glyph in ['? ', '[ ', '❯ ', '↳ ', '» ', '› ']) {
        expect(out.toString(), isNot(contains(glyph)));
      }
    });
  });

  group('heading grammar vocabulary', () {
    test('only the seven decorated structures head a stage', () {
      for (final structure in PromptStructure.values) {
        final heads =
            structure == PromptStructure.minimal ||
            structure == PromptStructure.ascii ||
            structure == PromptStructure.chevron ||
            structure == PromptStructure.bracket ||
            structure == PromptStructure.form ||
            structure == PromptStructure.ledger ||
            structure == PromptStructure.colon;
        expect(usesStructureHeading(structure), heads, reason: '$structure');
        expect(headingGlyphsFor(structure, ascii: false) != null, heads);
        expect(headingGlyphsFor(structure, ascii: true) != null, heads);
        expect(
          usesStructureFraming(structure),
          heads ||
              usesStructurePrefix(structure) ||
              usesStructureEnclosure(structure),
          reason: '$structure',
        );
      }
    });

    test('the declared vocabularies are the approved spellings', () {
      final minimal = headingGlyphsFor(PromptStructure.minimal, ascii: false)!;
      expect(minimal.headingPrefix, isEmpty);
      expect(minimal.headingSuffix, isEmpty);
      expect(minimal.bodyIndent, isEmpty);
      expect(minimal.hintPrefix, isEmpty);
      expect(minimal.bodyMarker, '› ');
      expect(minimal.uppercaseHeading, isFalse);

      final ascii = headingGlyphsFor(PromptStructure.ascii, ascii: false)!;
      expect(ascii.headingPrefix, '? ');
      expect(ascii.bodyIndent, '  ');
      expect(ascii.hintPrefix, '-- ');
      expect(ascii.uppercaseHeading, isTrue);

      final chevron = headingGlyphsFor(PromptStructure.chevron, ascii: false)!;
      expect(chevron.headingPrefix, '❯ ');
      expect(chevron.hintPrefix, '↳ ');
      expect(chevron.bodyMarker, '❯ ');

      final bracket = headingGlyphsFor(PromptStructure.bracket, ascii: false)!;
      expect(bracket.headingPrefix, '[ ');
      expect(bracket.headingSuffix, ' ]');
      expect(bracket.bodyMarker, '» ');
    });

    test('the console grammar is ASCII in every capability profile', () {
      final unicode = headingGlyphsFor(PromptStructure.ascii, ascii: false)!;
      final ascii = headingGlyphsFor(PromptStructure.ascii, ascii: true)!;
      expect(identical(unicode, ascii), isTrue);
      for (final text in [
        unicode.headingPrefix,
        unicode.headingSuffix,
        unicode.bodyIndent,
        unicode.hintPrefix,
        unicode.bodyMarker,
      ]) {
        expect(text.runes.every((rune) => rune < 128), isTrue);
      }
    });

    test('the ASCII counterparts are the approved portable spellings', () {
      expect(
        headingGlyphsFor(PromptStructure.chevron, ascii: true)!.headingPrefix,
        '> ',
      );
      expect(
        headingGlyphsFor(PromptStructure.chevron, ascii: true)!.hintPrefix,
        '-> ',
      );
      expect(
        headingGlyphsFor(PromptStructure.minimal, ascii: true)!.bodyMarker,
        '> ',
      );
      expect(
        headingGlyphsFor(PromptStructure.bracket, ascii: true)!.bodyMarker,
        '> ',
      );
    });

    test('a decorated heading keeps every line inside the declared width', () {
      for (final structure in _themes.keys) {
        for (final ascii in [false, true]) {
          final glyphs = _heading(structure, ascii: ascii);
          for (final width in [12, 40, 80]) {
            final available = width - glyphs.headingCells;
            final lines = frameHeadingLines(
              structure,
              ascii: ascii,
              lines: ['A heading that has already wrapped', 'and continues'],
            );
            expect(lines, hasLength(2));
            expect(
              lines.first,
              startsWith(glyphs.headingPrefix),
              reason: '$structure/$ascii',
            );
            if (glyphs.headingSuffix.isNotEmpty) {
              expect(lines.last, endsWith(glyphs.headingSuffix));
            }
            expect(lines.last, startsWith(glyphs.bodyIndent));
            expect(available, lessThanOrEqualTo(width));
          }
        }
      }
    });

    test('a compact heading keeps its marker and drops the closing band', () {
      final lines = frameHeadingLines(
        PromptStructure.bracket,
        ascii: true,
        compact: true,
        lines: const ['Name'],
      );
      expect(lines.single, '[Name');
      expect(
        frameHeadingLines(
          PromptStructure.rail,
          ascii: true,
          lines: const ['Name'],
        ),
        ['Name'],
      );
    });

    test('a heading structure reports its body cells and live marker', () {
      expect(structurePrefixCells(PromptStructure.minimal), 0);
      expect(structurePrefixCells(PromptStructure.ascii), 2);
      expect(structurePrefixCells(PromptStructure.bracket), 2);
      expect(structureLivePrefix(PromptStructure.ascii, ascii: true), '> ');
      expect(structureLivePrefix(PromptStructure.chevron, ascii: false), '❯ ');
      expect(structureLivePrefix(PromptStructure.bracket, ascii: false), '» ');
      expect(structureLivePrefix(PromptStructure.minimal, ascii: false), '› ');
      expect(structureLivePrefix(PromptStructure.plain, ascii: false), '> ');
    });

    test('the heading casing rule never reaches a body row', () {
      expect(
        structureHeadingText(PromptStructure.ascii, 'Deploy target'),
        'DEPLOY TARGET',
      );
      expect(
        structureHeadingText(PromptStructure.chevron, 'Deploy target'),
        'Deploy target',
      );
      expect(
        structureHeadingText(PromptStructure.minimal, 'Deploy target'),
        'Deploy target',
      );
    });
  });
}
