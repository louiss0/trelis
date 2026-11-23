import 'dart:async';
import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:trelis/src/text_measurement.dart';
import 'package:test/test.dart';

/// Verification of the form, ledger and diagnostic colon grammars.
///
/// Behavior, accepted values, input bindings and outcomes are covered by the
/// per-component suites and the factory matrices. These tests assert the
/// presentation contract instead: a fixed-label form rules and edges its field,
/// a ledger numbers the task stage it renders and keeps that number across a
/// repaint or a help screen, a diagnostic structure labels its heading, its hint
/// and its events with typed display prefixes, and none of the three ever falls
/// back to an undecorated or enclosured presentation.

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

/// The repaint sequence a rich presentation writes before the region it
/// redraws: the cursor moves up over the region and the screen is cleared from
/// there.
final _repaintPrefix = RegExp(r'^(?:(?:\r|\x1b\[\d+A\x1b\[J))+');

/// Splits output into display lines, dropping rich repaint sequences.
///
/// A rich repaint rewinds over the region it drew and clears it, so that
/// sequence is prefixed to the line that takes the region's place rather than
/// being a line of its own, and a carriage return is the shared editor's own
/// refresh of one line.
List<String> _lines(String text) => [
  for (final line in text.split('\n'))
    if (line.isNotEmpty) line.replaceFirst(_repaintPrefix, ''),
];

/// The display lines a reader actually sees, with styling removed.
List<String> _visibleLines(String text) => [
  for (final line in _lines(text))
    if (!line.contains('\x1b')) line,
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

  /// A reported outcome or notice that must be presented in the stage, never
  /// swallowed by a frame left open.
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
/// family sample: a structure that rules one form but not another is a defect
/// this matrix has to catch.
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
    richAnswer: '*\t*\t*\t*\t*\r',
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

/// Enclosure and spine chrome none of these structures may draw.
const _frameCorners = [
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
  '║',
  '├',
];

/// The lead a body row of [structure] takes, or null when it adds none.
String _bodyLead(PromptStructure structure, {required bool ascii}) =>
    headingGlyphsFor(structure, ascii: ascii)!.bodyIndent;

/// Whether [line] is a rule line of [structure].
bool _isRule(PromptStructure structure, String line, {required bool ascii}) {
  final glyphs = headingGlyphsFor(structure, ascii: ascii)!;
  if (!glyphs.drawsRule || line.length < 4) return false;
  return line.split('').every((char) => char == glyphs.ruleGlyph);
}

/// Asserts the stage grammar of one rendered run.
void _expectStage(
  String text, {
  required PromptStructure structure,
  required bool ascii,
  required String label,
  required int columns,
  String? outcome,
}) {
  final glyphs = headingGlyphsFor(structure, ascii: ascii)!;
  final lines = _visibleLines(text);
  expect(lines, isNotEmpty);
  final first = lines.first;
  switch (structure) {
    case PromptStructure.form:
      expect(
        first,
        first.toUpperCase(),
        reason: 'the form heading is a fixed uppercase label: "$first"',
      );
      expect(
        first.toLowerCase(),
        contains(label.toLowerCase()),
        reason: 'the form heading keeps the component label',
      );
      expect(
        headingGlyphsFor(structure, ascii: ascii)!.uppercaseHeading,
        isTrue,
      );
    case PromptStructure.ledger:
      expect(
        first,
        startsWith(structureStageNumberLabel(structure, 1, ascii: ascii)),
        reason: 'the ledger numbers its first task stage from 01: "$first"',
      );
      expect(
        first.toLowerCase(),
        contains(label.toLowerCase()),
        reason: 'the numbered heading keeps the component label',
      );
    case PromptStructure.colon:
      expect(
        first,
        startsWith('ask:'),
        reason: 'the diagnostic heading is a typed ask: label: "$first"',
      );
      expect(
        first.toLowerCase(),
        contains(label.toLowerCase()),
        reason: 'the ask: heading keeps the component label',
      );
    default:
      fail('unexpected structure $structure');
  }
  expect(
    text.toLowerCase(),
    contains(label.toLowerCase()),
    reason: 'the stage keeps its label',
  );
  // The rule line, when the grammar draws one, follows the heading block and
  // spans the stage width.
  final ruleIndex = lines.indexWhere(
    (line) => _isRule(structure, line, ascii: ascii),
  );
  if (glyphs.drawsRule) {
    expect(
      ruleIndex,
      greaterThanOrEqualTo(1),
      reason: 'the rule follows the heading block',
    );
    expect(
      lines.sublist(0, ruleIndex).join(' ').toLowerCase(),
      contains(label.toLowerCase()),
      reason: 'the heading block precedes the rule',
    );
    expect(
      _cells(lines[ruleIndex]),
      greaterThanOrEqualTo(10),
      reason: 'the rule spans the stage width',
    );
  } else {
    expect(ruleIndex, -1, reason: 'the diagnostic grammar draws no rule');
  }
  // Every visible line keeps the declared vocabulary.
  final lead = _bodyLead(structure, ascii: ascii);
  final live = structureLivePrefix(structure, ascii: ascii);
  final typed = <String>[
    for (final event in StageEvent.values)
      if (event != StageEvent.body) ?glyphs.eventPrefix(event),
  ];
  for (final line in lines) {
    final isHeading =
        line == first ||
        (glyphs.headingPrefix.isNotEmpty &&
            line.startsWith(glyphs.headingPrefix)) ||
        // A repaint re-heads the same stage, and a wrapped heading continues
        // under the body indent of its own grammar.
        (structure == PromptStructure.form && line == line.toUpperCase()) ||
        (structure == PromptStructure.ledger &&
            RegExp(r'^\d{2} / ').hasMatch(line));
    final isRule = _isRule(structure, line, ascii: ascii);
    final isBody = lead.isEmpty ? false : line.startsWith(lead);
    final isLive = line.startsWith(live);
    final isHint =
        glyphs.hintLead.isNotEmpty && line.startsWith(glyphs.hintLead);
    final isTyped = typed.any(
      (prefix) => prefix.isNotEmpty && line.startsWith(prefix),
    );
    expect(
      isHeading || isRule || isBody || isLive || isHint || isTyped,
      isTrue,
      reason: 'the line keeps the ${structure.name} grammar: "$line"',
    );
  }
  for (final glyph in _frameCorners) {
    expect(
      text,
      isNot(contains(glyph)),
      reason: 'a decorated structure never draws enclosure corners: "$glyph"',
    );
  }
  for (final line in lines) {
    expect(_cells(line), lessThanOrEqualTo(columns), reason: '"$line"');
  }
  if (outcome != null) {
    expect(
      lines.where((line) => line.contains(outcome)),
      isNotEmpty,
      reason: 'the run reports "$outcome"',
    );
  }
}

const _themes = <PromptStructure, String>{
  PromptStructure.form: 'FormTheme',
  PromptStructure.ledger: 'LedgerTheme',
  PromptStructure.colon: 'ColonTheme',
};

void main() {
  late Directory pickerDirectory;

  setUpAll(() async {
    pickerDirectory = await Directory.systemTemp.createTemp('form-ledger-');
    await File('${pickerDirectory.path}${Platform.pathSeparator}answer.txt')
        .writeAsString('data');
    _pickerBase = pickerDirectory.path;
  });

  tearDownAll(() => pickerDirectory.delete(recursive: true));

  for (final entry in _themes.entries) {
    final structure = entry.key;
    final themeName = entry.value;

    for (final mode in [PromptMode.linear, PromptMode.rich]) {
      group('$themeName renders every component / ${mode.name}', () {
        for (final testCase in _cases()) {
          test(testCase.name, () async {
            final text = await _render(testCase, mode, structure);
            _expectStage(
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
      '$themeName uses its declared vocabulary when it supports it',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.rich, 'Ada\r', out),
          mode: PromptMode.rich,
        );
        final text = out.toString();
        final glyphs = headingGlyphsFor(structure, ascii: false)!;
        if (glyphs.headingPrefix.isNotEmpty) {
          expect(text, contains(glyphs.headingPrefix));
        }
        if (glyphs.drawsRule) {
          expect(text, contains(glyphs.ruleGlyph));
        }
        expect(text, contains(structureLivePrefix(structure, ascii: false)));
        expect(text, contains(glyphs.hintLead.trimRight()));
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
        final text = out.toString();
        final ascii = headingGlyphsFor(structure, ascii: true)!;
        for (final glyph in ['│', '─', '·']) {
          if (glyph == ascii.ruleGlyph) continue;
          expect(
            text,
            isNot(contains(glyph)),
            reason:
                'no Unicode structure glyph in a portable profile: "$glyph"',
          );
        }
        expect(text, contains(ascii.bodyMarker.trimRight()));
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
        expect(_cells(line), lessThanOrEqualTo(120), reason: '"$line"');
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
      '$themeName simplifies the decoration instead of replacing the structure',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.linear, 'Ada\r', out, columns: 4),
          mode: PromptMode.linear,
        );
        final text = out.toString();
        for (final line in _lines(text)) {
          if (line.contains('\x1b')) continue;
          expect(_cells(line), lessThanOrEqualTo(4), reason: '"$line"');
        }
        final glyphs = headingGlyphsFor(structure, ascii: true)!;
        expect(
          text,
          contains(glyphs.bodyMarker.trimRight()),
          reason: 'the narrow stage keeps the structure marker',
        );
        for (final glyph in _frameCorners) {
          expect(text, isNot(contains(glyph)));
        }
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

    test(
      '$themeName styles its own chrome from the palette border role',
      () async {
        final palette = ColorThemes.signal.copyWith(
          border: TerminalColor.rgb(7, 8, 9),
        );
        final out = StringBuffer();
        await TextInput('Name', structure: structure, colors: palette).prompt(
          source: _scripted(PromptMode.rich, 'Ada\r', out, rgb: true),
          mode: PromptMode.rich,
        );
        final text = out.toString();
        final glyphs = headingGlyphsFor(structure, ascii: false)!;
        if (glyphs.drawsRule) {
          final rule = _lines(text).where(
            (line) => _isRule(
              structure,
              line.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), ''),
              ascii: false,
            ),
          );
          expect(rule, isNotEmpty, reason: 'the rule is drawn');
          expect(rule.first, contains('\x1b[38;2;7;8;9;'));
        }
      },
    );

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
            source: _scripted(PromptMode.linear, 'Bob\r\x7f\x7f\x7fAda\r', out),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'Ada');
      expect(out.toString(), contains('Name must be Ada\\u{0007}.'));
    });

    test('$themeName never echoes a masked password', () async {
      final out = StringBuffer();
      final result =
          await Password('Passphrase', mask: true, structure: structure).prompt(
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
      final text = out.toString();
      expect(text, contains('Help:'));
      for (final line in _visibleLines(text)) {
        expect(
          line.startsWith(headingGlyphsFor(structure, ascii: true)!.hintLead) ||
              line.startsWith(_bodyLead(structure, ascii: true)) ||
              line.startsWith(
                structureStageNumberLabel(structure, 1, ascii: true),
              ) ||
              line.startsWith(
                headingGlyphsFor(structure, ascii: true)!.headingPrefix,
              ) ||
              line.startsWith(structureLivePrefix(structure, ascii: true)) ||
              line.startsWith('Name'),
          isTrue,
          reason: 'help keeps the structure grammar: "$line"',
        );
      }
    });
  }

  group('form stage contracts', () {
    test('the fixed label, rule and left edge are the declared spellings', () {
      final unicode = headingGlyphsFor(PromptStructure.form, ascii: false)!;
      expect(unicode.headingPrefix, isEmpty);
      expect(unicode.uppercaseHeading, isTrue);
      expect(unicode.ruleGlyph, '─');
      expect(unicode.bodyIndent, '│ ');
      expect(unicode.hintIndent, '  ');
      expect(unicode.hintLead, '  ');
      expect(unicode.bodyMarker, '│ ');

      final ascii = headingGlyphsFor(PromptStructure.form, ascii: true)!;
      expect(ascii.ruleGlyph, '-');
      expect(ascii.bodyIndent, '| ');
      expect(ascii.bodyMarker, '| ');
    });

    test('the rule is measured, never a specimen constant', () {
      expect(structureRuleWidth(PromptStructure.form, null), 80);
      expect(structureRuleWidth(PromptStructure.form, 40), 40);
      expect(structureRuleWidth(PromptStructure.form, 4), 4);
      expect(structureRuleWidth(PromptStructure.form, 400), 80);
      final glyphs = headingGlyphsFor(PromptStructure.form, ascii: true)!;
      expect(glyphs.rule(3), '---');
      expect(glyphs.rule(0), isEmpty);
    });

    test('a form stage edges its field and keeps the hint unedged', () async {
      final out = StringBuffer();
      await Select<String>('Name', [
        Choice('a', 'Ada'),
      ], structure: PromptStructure.form).prompt(
        source: _scripted(PromptMode.linear, '1\r', out),
        mode: PromptMode.linear,
      );
      final lines = _visibleLines(out.toString());
      expect(lines.first, startsWith('NAME SELECT:'));
      expect(lines[1].split('').every((char) => char == '-'), isTrue);
      expect(
        lines.where((line) => line.startsWith('| ')),
        isNotEmpty,
        reason: 'the field body carries the left edge',
      );
      expect(
        lines.where((line) => line.startsWith('  ')),
        isNotEmpty,
        reason: 'the hint sits below the edged field',
      );
    });

    test(
      'the form rule never becomes an unbounded alignment requirement',
      () async {
        for (final columns in [8, 12, 40, 120]) {
          final out = StringBuffer();
          await TextInput('Name', structure: PromptStructure.form).prompt(
            source: _scripted(
              PromptMode.linear,
              'Ada\r',
              out,
              columns: columns,
            ),
            mode: PromptMode.linear,
          );
          for (final line in _visibleLines(out.toString())) {
            expect(_cells(line), lessThanOrEqualTo(columns), reason: '"$line"');
          }
        }
      },
    );
  });

  group('ruled stage width', () {
    test('a rule spans the stage above the width cap', () async {
      // The rule is chrome capped at 80 cells, so the heading, the body rows
      // and the hint are measured against the same width: above 80 columns the
      // rule must not fall short of the content it rules.
      for (final structure in [PromptStructure.form, PromptStructure.ledger]) {
        for (final mode in [PromptMode.linear, PromptMode.rich]) {
          final ascii = mode != PromptMode.rich;
          for (final columns in [80, 120]) {
            final out = StringBuffer();
            await Select<String>('Region', [
              Choice(
                'a',
                'A deliberately long choice label that has to wrap inside '
                    'the stage it belongs to',
              ),
            ], structure: structure).prompt(
              source: _scripted(mode, '1\r', out, columns: columns),
              mode: mode,
            );
            final lines = _visibleLines(out.toString());
            final ruleIndex = lines.indexWhere(
              (line) => _isRule(structure, line, ascii: ascii),
            );
            expect(
              ruleIndex,
              greaterThanOrEqualTo(1),
              reason: '${structure.name}/${mode.name}/$columns',
            );
            final ruleCells = _cells(lines[ruleIndex]);
            expect(
              ruleCells,
              structureRuleWidth(structure, 80),
              reason:
                  'the rule is drawn at the measured stage width, not at the '
                  'columns the output offers: ${structure.name}/$columns',
            );
            expect(
              ruleCells,
              lessThanOrEqualTo(columns),
              reason: 'the rule never exceeds the columns: $columns',
            );
            for (final line in lines) {
              expect(
                _cells(line),
                lessThanOrEqualTo(ruleCells),
                reason:
                    'no heading or body row is wider than the rule that '
                    'spans it: "$line"',
              );
            }
          }
        }
      }
    });

    test('above the cap 80 and 120 columns render the same stage', () async {
      for (final structure in [PromptStructure.form, PromptStructure.ledger]) {
        for (final mode in [PromptMode.linear, PromptMode.rich]) {
          Future<List<String>> stage(int columns) async {
            final out = StringBuffer();
            await Select<String>('Region', [
              Choice(
                'a',
                'A deliberately long choice label that has to wrap and then '
                    'wrap again inside the stage it belongs to',
              ),
            ], structure: structure).prompt(
              source: _scripted(mode, '1\r', out, columns: columns),
              mode: mode,
            );
            return _visibleLines(out.toString());
          }

          expect(
            await stage(120),
            await stage(80),
            reason:
                'above the rule cap the stage width is the cap, so more '
                'columns do not widen it: ${structure.name}/${mode.name}',
          );
        }
      }
    });
  });

  group('ledger numbering', () {
    /// Every stage number label the run displayed, in order.
    List<String> numbers(String text) {
      final shown = <String>[];
      for (final line in _visibleLines(text)) {
        final match = RegExp(r'^\d{2} / ').firstMatch(line);
        if (match != null) shown.add(match.group(0)!);
      }
      return shown;
    }

    test('a ledger stage starts at 01 in every mode', () async {
      for (final mode in [PromptMode.linear, PromptMode.rich]) {
        final out = StringBuffer();
        await TextInput(
          'Name',
          structure: PromptStructure.ledger,
        ).prompt(source: _scripted(mode, 'Ada\r', out), mode: mode);
        expect(numbers(out.toString()), ['01 / '], reason: mode.name);
      }
    });

    test('a repaint keeps the number it already displayed', () async {
      final out = StringBuffer();
      final result =
          await Select<String>('Region', [
            Choice('a', 'Europe'),
            Choice('b', 'United States'),
          ], structure: PromptStructure.ledger).prompt(
            source: _scripted(PromptMode.rich, '\x1b[B\x1b[A\x1b[B\r', out),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'b');
      final shown = numbers(out.toString());
      expect(shown.length, greaterThan(1), reason: 'the repaint re-headed');
      expect(shown.toSet(), {
        '01 / ',
      }, reason: 'a repaint never advances the numbering: $shown');
    });

    test('temporary help does not allocate another number', () async {
      final out = StringBuffer();
      final result =
          await Select<String>('Region', [
            Choice('a', 'Europe'),
            Choice('b', 'United States'),
          ], structure: PromptStructure.ledger).prompt(
            source: _scripted(PromptMode.linear, '/help\r2\r', out),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'b');
      final text = out.toString();
      expect(text, contains('Help:'));
      final shown = numbers(text);
      expect(shown, isNotEmpty);
      expect(shown.toSet(), {
        '01 / ',
      }, reason: 'help and the resumed stage share the first number: $shown');
    });

    test('revisiting a stage keeps its number', () async {
      final out = StringBuffer();
      final result =
          await TimeInput(
            'Time',
            initialValue: '23:59',
            structure: PromptStructure.ledger,
          ).prompt(
            source: _scripted(PromptMode.rich, '+\t+\t\t\r', out),
            mode: PromptMode.rich,
          );
      expect(result, isA<Accepted<Object?>>());
      final shown = numbers(out.toString());
      expect(shown.length, greaterThan(1), reason: 'several field stages ran');
      expect(shown.toSet(), {'01 / '}, reason: 'later fields reuse the number');
    });

    test('each invocation starts a fresh sequence', () async {
      final first = StringBuffer();
      final second = StringBuffer();
      await TextInput('Name', structure: PromptStructure.ledger).prompt(
        source: _scripted(PromptMode.linear, 'Ada\r', first),
        mode: PromptMode.linear,
      );
      await TextInput('Other', structure: PromptStructure.ledger).prompt(
        source: _scripted(PromptMode.linear, 'Grace\r', second),
        mode: PromptMode.linear,
      );
      expect(numbers(first.toString()), ['01 / ']);
      expect(numbers(second.toString()), ['01 / ']);
    });

    test('concurrent invocations do not share a counter', () async {
      final left = StringBuffer();
      final right = StringBuffer();
      await Future.wait([
        TextInput('Left', structure: PromptStructure.ledger).prompt(
          source: _scripted(PromptMode.linear, 'Ada\r', left),
          mode: PromptMode.linear,
        ),
        Select<String>('Right', [
          Choice('a', 'A'),
        ], structure: PromptStructure.ledger).prompt(
          source: _scripted(PromptMode.linear, '1\r', right),
          mode: PromptMode.linear,
        ),
      ]);
      expect(numbers(left.toString()), ['01 / ']);
      expect(numbers(right.toString()), ['01 / ']);
    });

    test('the theme namespace holds no numbering state', () async {
      // Factories are construction-pure and stateless: building two ledgers
      // never advances anything, and each run still starts at 01.
      final first = LedgerTheme.textInput('Name');
      final second = LedgerTheme.textInput('Name');
      expect(identical(first, second), isFalse);
      expect(first.structure, PromptStructure.ledger);
      final out = StringBuffer();
      await second.prompt(
        source: _scripted(PromptMode.linear, 'Ada\r', out),
        mode: PromptMode.linear,
      );
      expect(numbers(out.toString()), ['01 / ']);
    });

    test('a ledger body is indented and its hint is a note', () async {
      final out = StringBuffer();
      await TextInput('Name', structure: PromptStructure.ledger).prompt(
        source: _scripted(PromptMode.linear, 'Ada\r', out),
        mode: PromptMode.linear,
      );
      final lines = _visibleLines(out.toString());
      expect(lines.first, startsWith('01 / Name'));
      expect(
        lines.where((line) => line.startsWith('   note: ')),
        isNotEmpty,
        reason: 'the compact hint is a note under the body',
      );
      expect(
        lines.where(
          (line) => line.startsWith('   ') && !line.startsWith('   note: '),
        ),
        isNotEmpty,
        reason: 'the body rows are indented under the rule',
      );
    });

    test('numbering never changes an outcome', () async {
      for (final structure in [PromptStructure.plain, PromptStructure.ledger]) {
        final out = StringBuffer();
        final result =
            await Select<String>('Region', [
              Choice('a', 'Europe'),
              Choice('b', 'United States'),
            ], structure: structure).prompt(
              source: _scripted(PromptMode.linear, '2\r', out),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, 'b', reason: '$structure');
      }
    });
  });

  group('diagnostic prefixes', () {
    test('the diagnostic vocabulary is the declared spelling', () {
      final glyphs = headingGlyphsFor(PromptStructure.colon, ascii: false)!;
      expect(glyphs.headingPrefix, 'ask:');
      expect(glyphs.hintPrefix, 'hint:');
      expect(glyphs.hintLead, 'hint:');
      expect(glyphs.bodyIndent, '  ');
      expect(glyphs.bodyMarker, '  :: ');
      expect(glyphs.eventPrefix(StageEvent.state), 'state:');
      expect(glyphs.eventPrefix(StageEvent.warning), 'warning:');
      expect(glyphs.eventPrefix(StageEvent.result), 'result:');
      expect(glyphs.eventPrefix(StageEvent.body), isNull);
      expect(glyphs.drawsRule, isFalse);
      expect(glyphs.numbered, isFalse);
    });

    test('the diagnostic vocabulary is ASCII in every profile', () {
      final unicode = headingGlyphsFor(PromptStructure.colon, ascii: false)!;
      final ascii = headingGlyphsFor(PromptStructure.colon, ascii: true)!;
      expect(identical(unicode, ascii), isTrue);
      for (final text in [
        unicode.headingPrefix,
        unicode.hintPrefix,
        unicode.bodyIndent,
        unicode.bodyMarker,
        ...unicode.eventPrefixes.values,
      ]) {
        expect(text.runes.every((rune) => rune < 128), isTrue);
      }
    });

    test('the typed labels are exposed by the vocabulary helper', () {
      expect(
        structureEventPrefix(PromptStructure.colon, StageEvent.state),
        'state:',
      );
      expect(
        structureEventPrefix(PromptStructure.colon, StageEvent.warning),
        'warning:',
      );
      expect(
        structureEventPrefix(PromptStructure.colon, StageEvent.result),
        'result:',
      );
      expect(
        structureEventPrefix(PromptStructure.colon, StageEvent.body),
        isNull,
      );
      expect(
        structureEventPrefix(PromptStructure.form, StageEvent.warning),
        isNull,
      );
      expect(
        structureEventPrefix(PromptStructure.ledger, StageEvent.result),
        isNull,
      );
    });

    test('a warning is a typed row that keeps its semantic content', () async {
      final out = StringBuffer();
      final result =
          await TextInput(
            'Name',
            structure: PromptStructure.colon,
            validate: (value) => value == 'Ada' ? null : 'Name must be Ada.',
          ).prompt(
            source: _scripted(PromptMode.linear, 'Bob\r\x7f\x7f\x7fAda\r', out),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'Ada');
      final lines = _visibleLines(out.toString());
      expect(
        lines.where((line) => line == 'warning:Name must be Ada.'),
        isNotEmpty,
        reason: 'the notice keeps its own words after the typed label',
      );
    });

    test('a slider refusal is a typed warning', () async {
      final out = StringBuffer();
      final result =
          await Slider(
            'Opacity',
            minimum: '0',
            maximum: '10',
            step: '1',
            structure: PromptStructure.colon,
          ).prompt(
            source: _scripted(PromptMode.linear, '\r0\r', out),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, '0');
      expect(
        _visibleLines(out.toString()),
        contains('warning:Required: enter a non-empty value and submit again.'),
        reason: 'the slider refusal is a typed warning, not a body row',
      );
    });

    test('a masked-input refusal is a typed warning', () async {
      final out = StringBuffer();
      final digit = MaskSlot(
        'digit',
        (value) => RegExp(r'^[0-9]$').hasMatch(value),
      );
      final result =
          await MaskedInput(
            'Code',
            templates: [
              MaskTemplate('pair', [digit, MaskLiteral('-'), digit]),
            ],
            structure: PromptStructure.colon,
          ).prompt(
            source: _scripted(PromptMode.rich, '\r12\r', out),
            mode: PromptMode.rich,
          );
      expect(result, isA<Accepted<MaskedValue>>());
      expect(
        _visibleLines(out.toString()),
        contains('warning:Required slots are incomplete.'),
        reason: 'the masked-input refusal is a typed warning',
      );
    });

    test('a result is a typed row that keeps its semantic content', () async {
      final out = StringBuffer();
      await Select<String>('Region', [
        Choice('a', 'Europe'),
        Choice('b', 'United States'),
      ], structure: PromptStructure.colon).prompt(
        source: _scripted(PromptMode.linear, '2\r', out),
        mode: PromptMode.linear,
      );
      expect(
        _visibleLines(out.toString()),
        contains('result:Accepted: United States.'),
      );
    });

    test('a state row is typed and an editable row keeps its marker', () async {
      final out = StringBuffer();
      await Select<String>('Name', [
        Choice('a', 'Ada'),
      ], structure: PromptStructure.colon).prompt(
        source: _scripted(PromptMode.linear, '1\r', out),
        mode: PromptMode.linear,
      );
      final lines = _visibleLines(out.toString());
      expect(
        lines.where((line) => line.startsWith('state:')),
        isNotEmpty,
        reason: 'the page cue and the caret are typed state rows',
      );
      final live = StringBuffer();
      await TextInput('Name', structure: PromptStructure.colon).prompt(
        source: _scripted(PromptMode.rich, 'Ada\r', live),
        mode: PromptMode.rich,
      );
      expect(
        live.toString(),
        contains('  :: '),
        reason: 'the editable row carries the diagnostic body marker',
      );
    });

    test('a typed label is not a command and never replaces one', () async {
      final out = StringBuffer();
      // "ask:/help" is answer text, while a bare /help is still the command.
      final result = await TextInput('Name', structure: PromptStructure.colon)
          .prompt(
            source: _scripted(PromptMode.linear, 'ask:/help\r', out),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'ask:/help');
      final text = out.toString();
      expect(text, contains('ask:/help'));
      expect(text, contains('hint:'));
    });

    test(
      'a literal command keeps its spelling in a diagnostic stage',
      () async {
        final out = StringBuffer();
        final result =
            await TextInput(
              'Name',
              structure: PromptStructure.colon,
              validate: (value) =>
                  value == 'Ada' ? null : r'Quote \/help literally.',
            ).prompt(
              source: _scripted(
                PromptMode.linear,
                'Bob\r\x7f\x7f\x7fAda\r',
                out,
              ),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, 'Ada');
        expect(out.toString(), contains(r'Quote \/help literally.'));
      },
    );

    test('the typed hints cover both modes', () async {
      for (final mode in [PromptMode.linear, PromptMode.rich]) {
        final out = StringBuffer();
        await TextInput(
          'Name',
          structure: PromptStructure.colon,
        ).prompt(source: _scripted(mode, 'Ada\r', out), mode: mode);
        expect(
          _visibleLines(out.toString())
              .where((line) => line.startsWith('hint:')),
          isNotEmpty,
          reason: mode.name,
        );
        expect(
          _visibleLines(out.toString()).where(
            (line) => line.startsWith(
              headingGlyphsFor(
                PromptStructure.colon,
                ascii: true,
              )!.headingPrefix,
            ),
          ),
          isNotEmpty,
          reason: mode.name,
        );
        expect(
          _visibleLines(out.toString()).where((line) => line.startsWith('  ')),
          isNotEmpty,
          reason: mode.name,
        );
      }
    });
  });

  group('grammar vocabulary', () {
    test('only the nine decorated structures head a stage', () {
      for (final structure in PromptStructure.values) {
        final heads =
            structure == PromptStructure.minimal ||
            structure == PromptStructure.ascii ||
            structure == PromptStructure.chevron ||
            structure == PromptStructure.bracket ||
            structure == PromptStructure.form ||
            structure == PromptStructure.ledger ||
            structure == PromptStructure.colon ||
            structure == PromptStructure.line ||
            structure == PromptStructure.block;
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

    test('only the ledger numbers its stages', () {
      for (final structure in PromptStructure.values) {
        final glyphs = headingGlyphsFor(structure, ascii: false);
        expect(glyphs?.numbered ?? false, structure == PromptStructure.ledger);
      }
    });

    test('only the form, ledger and line draw a rule', () {
      for (final structure in PromptStructure.values) {
        final glyphs = headingGlyphsFor(structure, ascii: false);
        final ruled =
            structure == PromptStructure.form ||
            structure == PromptStructure.ledger ||
            structure == PromptStructure.line;
        expect(glyphs?.drawsRule ?? false, ruled, reason: '$structure');
      }
    });

    test('the stage number label is a two-digit display sequence', () {
      expect(structureStageNumberLabel(PromptStructure.ledger, 1), '01 / ');
      expect(structureStageNumberLabel(PromptStructure.ledger, 9), '09 / ');
      expect(structureStageNumberLabel(PromptStructure.ledger, 10), '10 / ');
      expect(structureStageNumberLabel(PromptStructure.ledger, 123), '123 / ');
      expect(structureStageNumberLabel(PromptStructure.form, 1), isEmpty);
      expect(
        structureStageHeading(PromptStructure.ledger, 2, 'Choose a template'),
        '02 / Choose a template',
      );
      expect(
        structureStageHeading(PromptStructure.form, 2, 'Project name'),
        'PROJECT NAME',
      );
      expect(
        structureStageHeading(PromptStructure.colon, 2, 'Project name'),
        'Project name',
      );
    });

    test('a decorated structure reports its body cells and live marker', () {
      expect(structurePrefixCells(PromptStructure.form, ascii: false), 2);
      expect(structurePrefixCells(PromptStructure.ledger, ascii: false), 3);
      expect(structurePrefixCells(PromptStructure.colon, ascii: false), 2);
      expect(structureLivePrefix(PromptStructure.form, ascii: false), '│ ');
      expect(structureLivePrefix(PromptStructure.form, ascii: true), '| ');
      expect(structureLivePrefix(PromptStructure.ledger, ascii: true), '   > ');
      expect(structureLivePrefix(PromptStructure.colon, ascii: false), '  :: ');
    });

    test('the heading casing rule never reaches a body row', () {
      expect(
        structureHeadingText(PromptStructure.form, 'Deploy target'),
        'DEPLOY TARGET',
      );
      expect(
        structureHeadingText(PromptStructure.ledger, 'Deploy target'),
        'Deploy target',
      );
      expect(
        structureHeadingText(PromptStructure.colon, 'Deploy target'),
        'Deploy target',
      );
    });

    test('a ruled heading keeps every line inside the declared width', () {
      for (final structure in [PromptStructure.form, PromptStructure.ledger]) {
        for (final ascii in [false, true]) {
          final glyphs = headingGlyphsFor(structure, ascii: ascii)!;
          for (final width in [12, 40, 80, 200]) {
            final cells = structureRuleWidth(structure, width);
            expect(cells, lessThanOrEqualTo(width));
            expect(cells, lessThanOrEqualTo(80));
            final rule = glyphs.rule(cells);
            expect(rule.length, cells);
            expect(
              rule.split('').every((char) => char == glyphs.ruleGlyph),
              isTrue,
            );
          }
        }
      }
    });
  });

  group('feedback keeps the structure marker', () {
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
        for (final glyph in _frameCorners) {
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

  group('behavior is unchanged by the decorated grammar', () {
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

    test('the reference presentation still emits no decoration', () async {
      final out = StringBuffer();
      await TextInput('Name').prompt(
        source: _scripted(PromptMode.rich, 'Ada\r', out),
        mode: PromptMode.rich,
      );
      final text = out.toString();
      for (final glyph in ['ask:', 'hint:', 'state:', '01 / ', '│ ']) {
        expect(text, isNot(contains(glyph)));
      }
    });
  });
}
