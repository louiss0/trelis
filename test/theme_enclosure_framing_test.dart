import 'dart:async';
import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:trelis/src/text_measurement.dart';
import 'package:test/test.dart';

/// Verification of the box, rounded and double enclosure grammars.
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

int _cells(String line) => TextDisplayMap(line).cellWidth;

typedef _Enclosure = ({
  String topLeft,
  String topRight,
  String bottomLeft,
  String bottomRight,
  String horizontal,
  String vertical,
});

/// The enclosure vocabulary a theme must draw for one capability profile.
_Enclosure _expected(PromptStructure structure, {required bool ascii}) {
  final glyphs = enclosureGlyphsFor(structure, ascii: ascii)!;
  return (
    topLeft: glyphs.topLeft,
    topRight: glyphs.topRight,
    bottomLeft: glyphs.bottomLeft,
    bottomRight: glyphs.bottomRight,
    horizontal: glyphs.horizontal,
    vertical: glyphs.vertical,
  );
}

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
    outcome: 'A moved to position 1 of 2.',
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

/// Asserts every frame in [lines] opens and closes exactly once, in order.
///
/// A stage that reopens its frame on a focus move without closing it leaves the
/// following notice or outcome inside an open frame; walking the lines catches
/// that wherever it happens, which a check of the first frame alone cannot. A
/// rule line is identified by its corners, so a title embedded in the top rule
/// is still a rule and a styled line is never mistaken for one.
void _expectClosedFrames(
  List<String> lines, {
  required _Enclosure expected,
  String? outcome,
}) {
  var open = false;
  var closed = 0;
  for (final line in lines) {
    final isTop =
        line.startsWith(expected.topLeft) && line.endsWith(expected.topRight);
    final isBottom =
        line.startsWith(expected.bottomLeft) &&
        line.endsWith(expected.bottomRight);
    if (isTop || isBottom) {
      // A square frame draws the same corners on both rules, so an ambiguous
      // rule closes the open frame and opens the next one.
      final closes = isTop == isBottom ? open : isBottom;
      if (closes) {
        expect(
          open,
          isTrue,
          reason: 'a bottom rule closes an open frame: "$line"',
        );
        open = false;
        closed++;
      } else {
        expect(
          open,
          isFalse,
          reason: 'a frame opens before the previous one closes: "$line"',
        );
        open = true;
      }
      continue;
    }
    if (outcome != null && line.contains(outcome)) {
      expect(
        open,
        isFalse,
        reason: 'the outcome "$outcome" is never a row of an open frame',
      );
      expect(
        line.startsWith(expected.vertical),
        isFalse,
        reason: 'the outcome "$outcome" is not a frame body row',
      );
    }
    if (line.startsWith(expected.vertical)) {
      expect(open, isTrue, reason: 'a body row stays inside a frame: "$line"');
      continue;
    }
    expect(
      open,
      isFalse,
      reason: 'an outside block is never written inside an open frame: "$line"',
    );
  }
  expect(open, isFalse, reason: 'the last frame of the run closes');
  expect(closed, greaterThan(0), reason: 'the run drew at least one frame');
}

/// Asserts the enclosing grammar of one rendered stage.
void _expectEnclosed(
  String text, {
  required PromptStructure structure,
  required bool ascii,
  required String label,
  required int columns,
  String? outcome,
}) {
  final expected = _expected(structure, ascii: ascii);
  final lines = _lines(text);
  expect(lines, isNotEmpty);
  expect(
    lines.first,
    startsWith(expected.topLeft),
    reason: 'the stage opens with the enclosure top rule',
  );
  expect(
    lines.first,
    endsWith(expected.topRight),
    reason: 'the top rule closes at the declared width',
  );
  expect(
    text,
    contains('${expected.bottomLeft}${expected.horizontal}'),
    reason: 'the enclosure has a bottom rule',
  );
  expect(text, contains(label), reason: 'the stage keeps its label');
  // Every framed line carries the same total width, which is the frame width.
  final frameWidth = _cells(lines.first);
  for (final line in lines.where((line) => !line.contains('\x1b'))) {
    expect(_cells(line), lessThanOrEqualTo(columns));
  }
  final bodyRows = lines.where((line) => line.startsWith(expected.vertical));
  expect(bodyRows, isNotEmpty, reason: 'the frame has body rows');
  for (final line in bodyRows) {
    expect(
      _cells(line),
      frameWidth,
      reason: 'body row "$line" keeps the frame width',
    );
    expect(
      line.endsWith(expected.vertical),
      isTrue,
      reason: 'body row "$line" closes at the right rule',
    );
  }
  // The compact hint is outside a closed frame: rich repaints can draw more
  // than one frame, but each of them closes before the hint is written.
  expect(
    lines.any((line) => line.startsWith('  ')),
    isTrue,
    reason: 'the compact hint is indented outside the bottom rule',
  );
  _expectClosedFrames(lines, expected: expected, outcome: outcome);
}

const _themes = <PromptStructure, String>{
  PromptStructure.box: 'BoxTheme',
  PromptStructure.round: 'RoundTheme',
  PromptStructure.double: 'DoubleTheme',
};

void main() {
  late Directory pickerDirectory;

  setUpAll(() async {
    pickerDirectory = await Directory.systemTemp.createTemp('enclosure-');
    await File('${pickerDirectory.path}${Platform.pathSeparator}answer.txt')
        .writeAsString('data');
    _pickerBase = pickerDirectory.path;
  });

  tearDownAll(() => pickerDirectory.delete(recursive: true));

  for (final entry in _themes.entries) {
    final structure = entry.key;
    final themeName = entry.value;

    for (final mode in [PromptMode.linear, PromptMode.rich]) {
      group('$themeName encloses every component / ${mode.name}', () {
        for (final testCase in _cases()) {
          test(testCase.name, () async {
            final text = await _render(testCase, mode, structure);
            _expectEnclosed(
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
      '$themeName uses its Unicode vocabulary when the profile supports it',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.rich, 'Ada\r', out),
          mode: PromptMode.rich,
        );
        final expected = _expected(structure, ascii: false);
        expect(out.toString(), contains(expected.topLeft));
        expect(out.toString(), contains(expected.bottomRight));
        expect(out.toString(), isNot(contains('+-')));
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
        final expected = _expected(structure, ascii: true);
        expect(out.toString(), contains(expected.topLeft));
        expect(out.toString(), contains(expected.bottomRight));
        expect(out.toString(), isNot(contains('┌')));
        expect(out.toString(), isNot(contains('╭')));
        expect(out.toString(), isNot(contains('╔')));
        expect(out.toString(), isNot(contains('│')));
      },
    );

    test('$themeName never exceeds the 80-column total width cap', () async {
      final out = StringBuffer();
      await Select<String>('Region', [
        Choice('a', 'Europe'),
        Choice('b', 'United States'),
      ], structure: structure).prompt(
        source: _scripted(PromptMode.rich, '\r', out, columns: 200),
        mode: PromptMode.rich,
      );
      final lines = _lines(out.toString());
      expect(_cells(lines.first), 80);
      for (final line in lines) {
        expect(line, isNot(contains('[2K')));
        if (line.contains('\x1b')) continue;
        expect(_cells(line), lessThanOrEqualTo(80));
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
          expect(_cells(line), lessThanOrEqualTo(24));
        }
      },
    );

    test(
      '$themeName simplifies to its left rule when width cannot frame',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.linear, 'Ada\r', out, columns: 8),
          mode: PromptMode.linear,
        );
        final expected = _expected(structure, ascii: true);
        final text = out.toString();
        for (final line in _lines(text)) {
          if (line.contains('\x1b')) continue;
          expect(
            line.startsWith(expected.topLeft),
            isFalse,
            reason: 'narrow output draws no top rule',
          );
          expect(
            line.startsWith(expected.bottomLeft),
            isFalse,
            reason: 'narrow output draws no bottom rule',
          );
          expect(_cells(line), lessThanOrEqualTo(8));
        }
        expect(
          text,
          contains(enclosureGlyphsFor(structure, ascii: true)!.livePrefix),
        );
        expect(text, contains('Name'));
      },
    );

    test('$themeName keeps a narrow choice list marked by the structure', () async {
      final out = StringBuffer();
      await Select<String>('Region', [
        Choice('a', 'Europe'),
        Choice('b', 'Asia'),
      ], structure: structure).prompt(
        source: _scripted(PromptMode.linear, '1\r', out, columns: 10),
        mode: PromptMode.linear,
      );
      final expected = _expected(structure, ascii: true);
      final marker = enclosureGlyphsFor(structure, ascii: true)!.livePrefix;
      final text = out.toString();
      for (final line in _lines(text)) {
        if (line.contains('\x1b')) continue;
        expect(
          line.startsWith(marker),
          isTrue,
          reason:
              'narrow output keeps the structure marker on every row: "$line"',
        );
      }
      expect(expected.vertical, isNotEmpty);
      expect(text, contains('1. '));
    });

    test(
      '$themeName keeps a palette border without changing the answer',
      () async {
        final palette = ColorThemes.signal.copyWith(
          border: TerminalColor.rgb(12, 34, 56),
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
        final text = out.toString();
        expect(text, contains('\x1b[38;2;12;34;56;'));
        // Both rules are chrome, so both carry the palette's border colour.
        final expected = _expected(structure, ascii: false);
        final rules = _lines(text).where(
          (line) =>
              line.contains(expected.topLeft) ||
              line.contains(expected.bottomLeft),
        );
        expect(rules, isNotEmpty);
        for (final rule in rules) {
          expect(
            rule,
            contains('\x1b[38;2;12;34;56;'),
            reason: 'the rule is styled as a border: "$rule"',
          );
        }
      },
    );
  }

  group('rich navigation closes every frame', () {
    for (final entry in _themes.entries) {
      final structure = entry.key;

      test('${entry.value} closes the frame a focus move reopens', () async {
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
        final expected = _expected(structure, ascii: false);
        final lines = _lines(out.toString());
        _expectClosedFrames(
          lines,
          expected: expected,
          outcome: 'Accepted: United States.',
        );
        // The navigation redrew the stage, so the outcome belongs to the frame
        // that closed last, not to a frame that never did.
        final lastRule = lines.lastIndexWhere(
          (line) =>
              line.startsWith(expected.bottomLeft) &&
              line.contains(expected.horizontal * 3),
        );
        final outcome = lines.indexWhere(
          (line) => line.contains('Accepted: United States.'),
        );
        expect(outcome, greaterThan(lastRule));
      });

      test('${entry.value} closes the frame a toggle reopens', () async {
        final out = StringBuffer();
        final result =
            await MultiSelect<String>('Choices', [
              Choice('a', 'Alpha'),
              Choice('b', 'Beta'),
            ], structure: structure).prompt(
              source: _scripted(PromptMode.rich, '\x1b[B \r', out),
              mode: PromptMode.rich,
            );
        expect((result as Accepted<List<String>>).value, ['b']);
        final expected = _expected(structure, ascii: false);
        _expectClosedFrames(
          _lines(out.toString()),
          expected: expected,
          outcome: 'Beta: checked.',
        );
      });

      test(
        '${entry.value} closes the frame a date field move reopens',
        () async {
          final out = StringBuffer();
          await DateInput(
            'Date',
            order: DateFieldOrder.dayMonthYear,
            structure: structure,
          ).prompt(
            source: _scripted(PromptMode.rich, '29\t02\r', out),
            mode: PromptMode.rich,
          );
          final expected = _expected(structure, ascii: false);
          final lines = _lines(out.toString());
          _expectClosedFrames(lines, expected: expected);
          expect(
            lines
                .where(
                  (line) =>
                      line.startsWith(expected.topLeft) &&
                      line.contains(expected.horizontal * 3),
                )
                .length,
            greaterThan(1),
            reason: 'each field stage is framed, not just the introduction',
          );
        },
      );

      test('${entry.value} closes the frame a time stage reopens', () async {
        final out = StringBuffer();
        await TimeInput('Time', structure: structure).prompt(
          source: _scripted(PromptMode.rich, '10\t30\r\t\r', out),
          mode: PromptMode.rich,
        );
        final expected = _expected(structure, ascii: false);
        final lines = _lines(out.toString());
        _expectClosedFrames(lines, expected: expected);
        expect(
          lines
              .where(
                (line) =>
                    line.startsWith(expected.topLeft) &&
                    line.contains(expected.horizontal * 3),
              )
              .length,
          greaterThan(1),
          reason: 'each field stage is framed, not just the introduction',
        );
      });
    }
  });

  group('enclosure body composition', () {
    for (final entry in _themes.entries) {
      test(
        '${entry.value} draws the breathing row above the choices',
        () async {
          final out = StringBuffer();
          await Select<String>('Region', [
            Choice('a', 'Europe'),
          ], structure: entry.key).prompt(
            source: _scripted(PromptMode.linear, '1\r', out),
            mode: PromptMode.linear,
          );
          final expected = _expected(entry.key, ascii: true);
          final lines = _lines(out.toString());
          bool isBreathing(String line) =>
              line.startsWith(expected.vertical) &&
              line.replaceAll(expected.vertical, '').trim().isEmpty;
          final heading = lines.indexWhere(
            (line) =>
                line.startsWith(expected.vertical) && line.contains('Region'),
          );
          final breathing = lines.indexWhere(isBreathing);
          expect(heading, greaterThanOrEqualTo(0));
          expect(
            breathing,
            greaterThan(heading),
            reason: 'the breathing row separates the heading from the choices',
          );
          expect(lines[breathing + 1], contains('1. Europe'));
        },
      );

      test('${entry.value} keeps validation before the compact hint', () async {
        final out = StringBuffer();
        final result =
            await TextInput(
              'Name',
              structure: entry.key,
              validate: (value) => value == 'Ada' ? null : 'Name must be Ada.',
            ).prompt(
              source: _scripted(
                PromptMode.linear,
                'Bob\r\x7f\x7f\x7fAda\r',
                out,
              ),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, 'Ada');
        final text = out.toString();
        final validation = text.indexOf('Name must be Ada.');
        expect(validation, greaterThan(0));
        expect(
          text.lastIndexOf('Left/Right move'),
          greaterThan(validation),
          reason: 'the compact hint closes the stage after the warning',
        );
        expect(
          text
              .substring(validation)
              .contains('${_expected(entry.key, ascii: true).vertical} '),
          isTrue,
          reason: 'the warning sits inside the frame, not below the hint',
        );
      });
    }
  });

  group('enclosure feedback', () {
    for (final entry in _themes.entries) {
      final structure = entry.key;
      final expected = _expected(structure, ascii: true);
      // Standalone feedback has no declared glyph capability, so the portable
      // ASCII marker is the conservative choice.
      final marker = enclosureGlyphsFor(structure, ascii: true)!.livePrefix;

      /// A feedback event is a marked line, never a frame around one line.
      void expectMarkedLines(String text) {
        final lines = [
          for (final line in text.split('\n'))
            if (line.isNotEmpty) line,
        ];
        expect(lines, isNotEmpty);
        for (final line in lines) {
          expect(
            line,
            contains(marker),
            reason: 'a feedback line keeps the structure marker: "$line"',
          );
          expect(
            line,
            isNot(contains(expected.horizontal * 3)),
            reason: 'a feedback event never draws a rule: "$line"',
          );
        }
      }

      test('${entry.value} keeps the lifecycle and gains the marker', () {
        final out = StringBuffer();
        Text(
          'Build finished',
          kind: TextKind.success,
          structure: structure,
        ).present(output: out);
        expect(out.toString(), contains('Success: Build finished'));
        expect(out.toString(), startsWith(marker));
      });

      for (final mode in [PromptMode.linear, PromptMode.rich]) {
        test('${entry.value} progress is a marked line / ${mode.name}', () {
          final out = StringBuffer();
          final progress = Progress('Copy', total: 4, structure: structure);
          progress.start(output: out, mode: mode, supportsRich: true);
          progress.update(2);
          progress.finish(FeedbackOutcome.completed);
          final text = out.toString();
          expect(text, contains('Copy: completed'));
          expectMarkedLines(text);
        });

        test('${entry.value} spinner keeps its cadence / ${mode.name}', () {
          final out = StringBuffer();
          final spinner = Spinner('Index', structure: structure);
          spinner.start(output: out, mode: mode, supportsRich: true);
          spinner.update('waiting');
          spinner.finish(FeedbackOutcome.failed, detail: 'disk');
          final text = out.toString();
          expect(text, contains('Index: waiting'));
          expect(text, contains('failed: disk'));
          expectMarkedLines(text);
        });

        test(
          '${entry.value} multi-spinner keeps its summary / ${mode.name}',
          () {
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
            expectMarkedLines(text);
          },
        );
      }
    }
  });

  group('enclosure vocabulary', () {
    test('only the three enclosure structures have enclosure glyphs', () {
      for (final structure in PromptStructure.values) {
        final encloses =
            structure == PromptStructure.box ||
            structure == PromptStructure.round ||
            structure == PromptStructure.double;
        expect(usesStructureEnclosure(structure), encloses);
        expect(enclosureGlyphsFor(structure, ascii: false) != null, encloses);
        expect(enclosureGlyphsFor(structure, ascii: true) != null, encloses);
        expect(
          usesStructureFraming(structure),
          encloses ||
              usesStructurePrefix(structure) ||
              usesStructureHeading(structure),
          reason: '$structure',
        );
      }
    });

    test('the ASCII counterparts match the approved portable spellings', () {
      final box = enclosureGlyphsFor(PromptStructure.box, ascii: true)!;
      expect(
        [box.topLeft, box.topRight, box.bottomLeft, box.bottomRight],
        ['+', '+', '+', '+'],
      );
      expect(box.horizontal, '-');
      expect(box.vertical, '|');

      final round = enclosureGlyphsFor(PromptStructure.round, ascii: true)!;
      expect(round.topLeft, '.');
      expect(round.topRight, '.');
      expect(round.bottomLeft, "'");
      expect(round.bottomRight, "'");
      expect(round.horizontal, '-');
      expect(round.vertical, '|');

      final double = enclosureGlyphsFor(PromptStructure.double, ascii: true)!;
      expect(double.horizontal, '=');
      expect(double.vertical, '||');
      expect(double.verticalCells, 2);
      expect(double.livePrefix, '|| ');
    });

    test('the Unicode vocabulary is the declared enclosure grammar', () {
      final box = enclosureGlyphsFor(PromptStructure.box, ascii: false)!;
      expect([box.topLeft, box.topRight, box.horizontal], ['┌', '┐', '─']);
      expect([box.bottomLeft, box.bottomRight, box.vertical], ['└', '┘', '│']);

      final round = enclosureGlyphsFor(PromptStructure.round, ascii: false)!;
      expect([round.topLeft, round.topRight], ['╭', '╮']);
      expect([round.bottomLeft, round.bottomRight], ['╰', '╯']);

      final double = enclosureGlyphsFor(PromptStructure.double, ascii: false)!;
      expect([double.horizontal, double.vertical], ['═', '║']);
    });

    test('a live row repeats the whole side rule of its frame', () {
      expect(structurePrefixCells(PromptStructure.box), 2);
      expect(
        structurePrefixCells(PromptStructure.double, ascii: true),
        3,
        reason: 'the ASCII double frame draws a two-cell side rule',
      );
      expect(
        structurePrefixCells(PromptStructure.double, ascii: false),
        2,
        reason: 'the Unicode double frame draws a one-cell side rule',
      );
      expect(structureLivePrefix(PromptStructure.box, ascii: false), '│ ');
      expect(structureLivePrefix(PromptStructure.round, ascii: true), '| ');
      expect(structureLivePrefix(PromptStructure.double, ascii: false), '║ ');
      expect(structureLivePrefix(PromptStructure.double, ascii: true), '|| ');
      expect(structureLivePrefix(PromptStructure.plain, ascii: false), '> ');
      expect(structureLivePrefix(PromptStructure.rail, ascii: false), '│ ');
    });

    test('composed frames keep every line at the declared total width', () {
      for (final structure in [
        PromptStructure.box,
        PromptStructure.round,
        PromptStructure.double,
      ]) {
        for (final ascii in [false, true]) {
          for (final width in [16, 40, 80]) {
            final lines = frameEnclosureLines(
              structure,
              ascii: ascii,
              title: 'Title',
              body: const ['first row', 'second row'],
              width: width,
            );
            expect(lines, hasLength(4));
            for (final line in lines) {
              expect(_cells(line), width, reason: '$structure/$ascii/$width');
            }
          }
        }
      }
    });

    test('a title that cannot fit the rule stays out of the frame top', () {
      final lines = frameEnclosureLines(
        PromptStructure.box,
        ascii: false,
        title: 'A title far wider than the frame',
        body: const [],
        width: 16,
      );
      expect(lines.first, '┌${'─' * 14}┐');
      expect(_cells(lines.first), 16);
    });

    test('composing a non-enclosure structure returns its body unchanged', () {
      expect(
        frameEnclosureLines(
          PromptStructure.rail,
          ascii: false,
          body: const ['a', 'b'],
          width: 20,
        ),
        ['a', 'b'],
      );
    });
  });

  group('enclosure content contracts', () {
    test(
      'a protected validation message stays spelled inside the frame',
      () async {
        final out = StringBuffer();
        final result =
            await BoxTheme.textInput(
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
        expect(out.toString(), contains('+---'));
      },
    );

    test('a masked password is never echoed into the frame', () async {
      final out = StringBuffer();
      final result = await DoubleTheme.password('Passphrase', mask: true)
          .prompt(
            source: _scripted(PromptMode.linear, 'secret\rsubmit\r', out),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'secret');
      expect(out.toString(), isNot(contains('secret')));
      expect(out.toString(), contains('+==='));
    });

    test('unavailable choices keep their reason inside the frame', () async {
      final out = StringBuffer();
      final result =
          await RoundTheme.select<String>('Region', [
            Choice('a', 'Europe', disabledReason: 'Not provisioned'),
            Choice('b', 'United States'),
          ]).prompt(
            source: _scripted(PromptMode.linear, '2\r', out),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'b');
      expect(out.toString(), contains('Not provisioned'));
      expect(out.toString(), contains('.'));
    });

    test('stage help keeps the enclosure grammar', () async {
      final out = StringBuffer();
      await BoxTheme.textInput('Name').prompt(
        source: _scripted(PromptMode.rich, '\x14\x1bAda\r', out),
        mode: PromptMode.rich,
      );
      expect(out.toString(), contains('Help:'));
      expect(out.toString(), contains('┌'));
      expect(out.toString(), contains('└'));
    });

    test('feedback keeps its lifecycle and gains the enclosure marker', () {
      final out = StringBuffer();
      BoxTheme.text(
        'Build finished',
        kind: TextKind.success,
      ).present(output: out);
      expect(
        out.toString(),
        // Standalone feedback has no declared glyph capability, so the
        // portable ASCII marker is the conservative choice.
        contains('| Success: Build finished'),
      );
    });

    test('a narrow enclosure never draws a partial frame', () async {
      final out = StringBuffer();
      await RoundTheme.textInput('Name').prompt(
        source: _scripted(PromptMode.linear, 'Ada\r', out, columns: 10),
        mode: PromptMode.linear,
      );
      expect(out.toString(), isNot(contains('╭')));
      expect(out.toString(), isNot(contains('╰')));
      for (final line in _lines(out.toString())) {
        if (line.contains('\x1b')) continue;
        expect(_cells(line), lessThanOrEqualTo(10));
      }
    });
  });

  group('theme factory integration', () {
    for (final entry in _themes.entries) {
      test('${entry.value} renders its declared structure', () async {
        final out = StringBuffer();
        final result = await switch (entry.key) {
          PromptStructure.box => BoxTheme.textInput('Name').prompt(
            source: _scripted(PromptMode.rich, 'Ada\r', out),
            mode: PromptMode.rich,
          ),
          PromptStructure.round => RoundTheme.textInput('Name').prompt(
            source: _scripted(PromptMode.rich, 'Ada\r', out),
            mode: PromptMode.rich,
          ),
          _ => DoubleTheme.textInput('Name').prompt(
            source: _scripted(PromptMode.rich, 'Ada\r', out),
            mode: PromptMode.rich,
          ),
        };
        expect((result as Accepted<String>).value, 'Ada');
        _expectEnclosed(
          out.toString(),
          structure: entry.key,
          ascii: false,
          label: 'Name',
          columns: 72,
        );
      });
    }
  });

  group('behavior is unchanged by the enclosure', () {
    /// The components whose answer contract is easiest to compare across
    /// structures: text, choice, boolean, number and date.
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
            for (final structure in [
              PromptStructure.box,
              PromptStructure.round,
              PromptStructure.double,
            ]) {
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

    test('the unframed structure still emits no enclosure chrome', () async {
      final out = StringBuffer();
      await TextInput('Name').prompt(
        source: _scripted(PromptMode.rich, 'Ada\r', out),
        mode: PromptMode.rich,
      );
      for (final glyph in [
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
      ]) {
        expect(out.toString(), isNot(contains(glyph)));
      }
      expect(out.toString(), isNot(contains('+-')));
    });
  });
}
