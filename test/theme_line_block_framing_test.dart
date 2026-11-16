import 'dart:async';
import 'dart:io';

import 'package:prompty/prompty.dart';
import 'package:prompty/src/text_measurement.dart';
import 'package:test/test.dart';

import 'theme_matrix_cases.dart';

/// Verification of the underlined-question and filled-label-band grammars.
///
/// Behavior, accepted values, input bindings, focus, selection and outcomes are
/// covered by the per-component suites and the factory matrices. These tests
/// assert the presentation contract instead: the line grammar underlines the
/// question and indents everything below it, the block grammar draws a filled
/// label band that is readable with no colour and no inverse styling, both
/// decorates are measured against the declared width, neither transforms answer
/// data nor infers an accepted selection from emphasis, and every previously
/// merged structure keeps the bytes it already produced.

OutputProfile _profile(
  PromptMode mode, {
  bool ascii = false,
  bool rgb = false,
  int columns = 72,
  bool inverse = false,
}) => mode == PromptMode.rich
    ? OutputProfile(
        cursor: CapabilitySupport.supported,
        styles: inverse
            ? CapabilitySupport.supported
            : CapabilitySupport.unsupported,
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
  bool inverse = false,
}) => ScriptedInput(
  Stream.value(data),
  out,
  outputProfile: _profile(
    mode,
    ascii: ascii,
    rgb: rgb,
    columns: columns,
    inverse: inverse,
  ),
);

final _csi = RegExp(r'\x1b\[[0-9;]*[A-Za-z]');

/// Removes terminal control sequences, leaving the display text.
String _plain(String text) => text.replaceAll(_csi, '');

/// Splits rendered output into display rows.
///
/// A rich repaint is separated by a carriage return rather than a line feed, so
/// both separate rows here: a repainted heading is a row of its own and never
/// looks like a duplicated line of a sequential transcript.
List<String> _rows(String text) => [
  for (final row in _plain(text).split(RegExp('[\r\n]')))
    if (row.trim().isNotEmpty) row,
];

int _cells(String row) => TextDisplayMap(row).cellWidth;

/// The exact bytes each structure produced for one linear TextInput stage.
///
/// These strings were captured from the merged integration tip before this
/// ticket's decoration was added; the thirteen structures delivered earlier
/// are a byte contract, not a `contains` property. A new structure must not
/// reshape them, so a change to wrapping, indentation or the hint vocabulary
/// fails here even when the visible meaning looks the same.
const _pinnedLinear = <PromptStructure, String>{
  PromptStructure.plain: '''Name (Optional).\nLeft/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\nExact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.\nCurrent text: \nCursor position: 0 of 0 graphemes.\nCurrent text: A\nCursor position: 1 of 1 graphemes.\nCurrent text: Ad\nCursor position: 2 of 2 graphemes.\nCurrent text: Ada\nCursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.rail: '''| Name (Optional).\n| Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n\\ Exact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.\n| Current text: \n\\ Cursor position: 0 of 0 graphemes.\n| Current text: A\n\\ Cursor position: 1 of 1 graphemes.\n| Current text: Ad\n\\ Cursor position: 2 of 2 graphemes.\n| Current text: Ada\n\\ Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.branch: '''+-Name (Optional).\n| Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n\\-Exact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.\n+-Current text: \n\\-Cursor position: 0 of 0 graphemes.\n+-Current text: A\n\\-Cursor position: 1 of 1 graphemes.\n+-Current text: Ad\n\\-Cursor position: 2 of 2 graphemes.\n+-Current text: Ada\n\\-Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.box: '''+------------------------------------------------------------------------------+\n| Name (Optional).                                                             |\n+------------------------------------------------------------------------------+\n  Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter subm\n  its. /help opens help. Escape cancels; Ctrl+C interrupts.\n  Exact /help and /cancel are commands. Quote a command with a backslash; double\n   a leading backslash to enter one. Identified paste is literal.\n  Current text: \n  Cursor position: 0 of 0 graphemes.\n  Current text: A\n  Cursor position: 1 of 1 graphemes.\n  Current text: Ad\n  Cursor position: 2 of 2 graphemes.\n  Current text: Ada\n  Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.round: '''.------------------------------------------------------------------------------.\n| Name (Optional).                                                             |\n'------------------------------------------------------------------------------'\n  Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter subm\n  its. /help opens help. Escape cancels; Ctrl+C interrupts.\n  Exact /help and /cancel are commands. Quote a command with a backslash; double\n   a leading backslash to enter one. Identified paste is literal.\n  Current text: \n  Cursor position: 0 of 0 graphemes.\n  Current text: A\n  Cursor position: 1 of 1 graphemes.\n  Current text: Ad\n  Cursor position: 2 of 2 graphemes.\n  Current text: Ada\n  Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.double: '''+==============================================================================+\n|| Name (Optional).                                                           ||\n+==============================================================================+\n  Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter subm\n  its. /help opens help. Escape cancels; Ctrl+C interrupts.\n  Exact /help and /cancel are commands. Quote a command with a backslash; double\n   a leading backslash to enter one. Identified paste is literal.\n  Current text: \n  Cursor position: 0 of 0 graphemes.\n  Current text: A\n  Cursor position: 1 of 1 graphemes.\n  Current text: Ad\n  Cursor position: 2 of 2 graphemes.\n  Current text: Ada\n  Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.minimal: '''Name (Optional).\nLeft/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\nExact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.\nCurrent text: \nCursor position: 0 of 0 graphemes.\nCurrent text: A\nCursor position: 1 of 1 graphemes.\nCurrent text: Ad\nCursor position: 2 of 2 graphemes.\nCurrent text: Ada\nCursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.ascii: '''? NAME (OPTIONAL).\n  -- Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n  -- Exact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.\n  Current text: \n  Cursor position: 0 of 0 graphemes.\n  Current text: A\n  Cursor position: 1 of 1 graphemes.\n  Current text: Ad\n  Cursor position: 2 of 2 graphemes.\n  Current text: Ada\n  Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.chevron: '''> Name (Optional).\n  -> Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n  -> Exact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.\n  Current text: \n  Cursor position: 0 of 0 graphemes.\n  Current text: A\n  Cursor position: 1 of 1 graphemes.\n  Current text: Ad\n  Cursor position: 2 of 2 graphemes.\n  Current text: Ada\n  Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.bracket: '''[ Name (Optional). ]\n  Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n  Exact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.\n  Current text: \n  Cursor position: 0 of 0 graphemes.\n  Current text: A\n  Cursor position: 1 of 1 graphemes.\n  Current text: Ad\n  Cursor position: 2 of 2 graphemes.\n  Current text: Ada\n  Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.form: '''NAME (OPTIONAL).\n--------------------------------------------------------------------------------\n  Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter subm\n  its. /help opens help. Escape cancels; Ctrl+C interrupts.\n  Exact /help and /cancel are commands. Quote a command with a backslash; double\n   a leading backslash to enter one. Identified paste is literal.\n| Current text: \n| Cursor position: 0 of 0 graphemes.\n| Current text: A\n| Cursor position: 1 of 1 graphemes.\n| Current text: Ad\n| Cursor position: 2 of 2 graphemes.\n| Current text: Ada\n| Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.ledger: '''01 / Name (Optional).\n................................................................................\n   note: Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Ent\n         er submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n   note: Exact /help and /cancel are commands. Quote a command with a backslash;\n          double a leading backslash to enter one. Identified paste is literal.\n   Current text: \n   Cursor position: 0 of 0 graphemes.\n   Current text: A\n   Cursor position: 1 of 1 graphemes.\n   Current text: Ad\n   Cursor position: 2 of 2 graphemes.\n   Current text: Ada\n   Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.colon: '''ask:Name (Optional).\nhint:Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\nhint:Exact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.\nstate:Current text: \nstate:Cursor position: 0 of 0 graphemes.\nstate:Current text: A\nstate:Cursor position: 1 of 1 graphemes.\nstate:Current text: Ad\nstate:Cursor position: 2 of 2 graphemes.\nstate:Current text: Ada\nstate:Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.line: '''Name (Optional).\n--------------------------------------------------------------------------------\n  Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter subm\n  its. /help opens help. Escape cancels; Ctrl+C interrupts.\n  Exact /help and /cancel are commands. Quote a command with a backslash; double\n   a leading backslash to enter one. Identified paste is literal.\n  Current text: \n  Cursor position: 0 of 0 graphemes.\n  Current text: A\n  Cursor position: 1 of 1 graphemes.\n  Current text: Ad\n  Cursor position: 2 of 2 graphemes.\n  Current text: Ada\n  Cursor position: 3 of 3 graphemes.\n\n''',
  PromptStructure.block: '''# NAME (OPTIONAL). #############################################################\n  Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter subm\n  its. /help opens help. Escape cancels; Ctrl+C interrupts.\n  Exact /help and /cancel are commands. Quote a command with a backslash; double\n   a leading backslash to enter one. Identified paste is literal.\n  Current text: \n  Cursor position: 0 of 0 graphemes.\n  Current text: A\n  Cursor position: 1 of 1 graphemes.\n  Current text: Ad\n  Cursor position: 2 of 2 graphemes.\n  Current text: Ada\n  Cursor position: 3 of 3 graphemes.\n\n''',
};

/// Runs one case through a structural theme's rendered structure.
Future<String> _render(
  ThemeMatrixCase testCase,
  PromptMode mode,
  PromptStructure structure, {
  bool ascii = false,
  int columns = 72,
  bool inverse = false,
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
      inverse: inverse,
    ),
    structure,
  );
  expect(result, isNot(isA<Unavailable<Object?>>()));
  return out.toString();
}

/// The heading vocabulary a theme must render for one capability profile.
HeadingGlyphs _heading(PromptStructure structure, {required bool ascii}) =>
    headingGlyphsFor(structure, ascii: ascii)!;

/// The structure-owned part of [row].
///
/// A component that finishes editing one value can write the next stage
/// heading on the same physical line as the caret row it just left
/// (`MaskedInput` does this for every structure, including the merged ones), so
/// one row can hold a live row followed by a decoration row. Measuring from the
/// decoration keeps the width assertion about the structure's own contribution
/// instead of an artefact of how a component terminates its editing line.
String _structurePart(
  String row,
  PromptStructure structure, {
  required bool ascii,
}) {
  final glyphs = _heading(structure, ascii: ascii);
  if (glyphs.bandGlyph.isNotEmpty) {
    final at = row.indexOf('${glyphs.bandGlyph} ');
    return at > 0 ? row.substring(at) : row;
  }
  if (glyphs.ruleGlyph.isNotEmpty) {
    final run = RegExp('${RegExp.escape(glyphs.ruleGlyph)}{8,}')
        .firstMatch(row);
    if (run != null && run.start > 0) return row.substring(run.start);
  }
  return row;
}

/// Whether [row] is a run of [structure]'s underline.
bool _isRule(String row, PromptStructure structure, {required bool ascii}) {
  final glyph = _heading(structure, ascii: ascii).ruleGlyph;
  if (glyph.isEmpty || row.length < 2) return false;
  return row.split('').every((cell) => cell == glyph);
}

/// Whether [row] is a row of [structure]'s label band.
bool _isBand(String row, PromptStructure structure, {required bool ascii}) {
  final fill = _heading(structure, ascii: ascii).bandGlyph;
  if (fill.isEmpty) return false;
  return row.startsWith(fill);
}

/// The structural line prefixes and frame characters neither grammar may draw.
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

/// Asserts the underline grammar of one rendered stage.
///
/// The question is the first row, the underline is drawn directly under it at
/// the width the stage measured, and every row below is indented, so the body
/// and the compact hint read as belonging to the question without any enclosing
/// frame. A stage boundary later in the run opens its own heading, which is
/// underlined in turn; nothing else may sit at the reference column.
void _expectUnderlined(
  String text, {
  required bool ascii,
  required String label,
  required int columns,
  String? outcome,
}) {
  const structure = PromptStructure.line;
  final glyphs = _heading(structure, ascii: ascii);
  final rows = _rows(text);
  expect(rows, isNotEmpty);
  expect(
    rows.first.toLowerCase(),
    contains(label.toLowerCase()),
    reason: 'the question opens the stage: "${rows.first}"',
  );
  expect(
    rows.first,
    contains(label),
    reason: 'the underlined question keeps its own casing: "${rows.first}"',
  );
  final rules = rows
      .where((row) => _isRule(row, structure, ascii: ascii))
      .toList();
  expect(rules, isNotEmpty, reason: 'the question is underlined');
  expect(
    rows.indexWhere((row) => _isRule(row, structure, ascii: ascii)),
    greaterThan(0),
    reason: 'the underline follows the question, never precedes it',
  );
  final expected = columns < 80 ? columns : 80;
  for (final rule in rules) {
    expect(
      _cells(rule),
      expected,
      reason: 'the underline spans the measured stage width',
    );
  }
  expect(
    rows.where((row) => row.startsWith(glyphs.bodyIndent)).length,
    greaterThan(rules.length),
    reason: 'the body and the hint are indented under the underline',
  );
  expect(
    rows.where((row) => row.startsWith('> ')),
    isEmpty,
    reason: 'the stage never falls back to the reference live marker',
  );
  for (final glyph in _framingGlyphs) {
    expect(
      text,
      isNot(contains(glyph)),
      reason: 'the line grammar draws no framing chrome: "$glyph"',
    );
  }
  for (final row in rows) {
    expect(
      _cells(_structurePart(row, structure, ascii: ascii)),
      lessThanOrEqualTo(columns),
      reason: '"$row"',
    );
  }
  if (outcome != null) {
    final reported = rows.where((row) => row.contains(outcome));
    expect(reported, isNotEmpty, reason: 'the run reports "$outcome"');
    for (final row in reported) {
      expect(
        row.startsWith(glyphs.bodyIndent),
        isTrue,
        reason: 'the outcome keeps the structure grammar: "$row"',
      );
    }
  }
}

/// Asserts the label-band grammar of one rendered stage.
///
/// The band opens the stage as a filled row of the measured width, spelled in
/// capitals, and everything below it is indented. The fill is what carries the
/// hierarchy: the same row is readable with no colour and with no inverse
/// styling, and inverse styling is added only when the output declares style
/// support. A stage boundary later in the run opens its own band.
void _expectBanded(
  String text, {
  required bool ascii,
  required String label,
  required int columns,
  bool inverse = false,
  String? outcome,
}) {
  const structure = PromptStructure.block;
  final glyphs = _heading(structure, ascii: ascii);
  final rows = _rows(text);
  expect(rows, isNotEmpty);
  final bands = rows
      .where((row) => _isBand(row, structure, ascii: ascii))
      .toList();
  expect(bands, isNotEmpty, reason: 'the stage opens with a filled label band');
  expect(bands.first, contains(label.toUpperCase()));
  final expected = columns < 80 ? columns : 80;
  for (final band in bands) {
    if (outcome != null) {
      expect(
        band.contains(outcome),
        isFalse,
        reason: 'an outcome is never folded into the label band: "$band"',
      );
    }
    expect(
      _cells(band),
      lessThanOrEqualTo(columns),
      reason: 'the band fits the declared width: "$band"',
    );
    expect(
      _cells(band),
      lessThanOrEqualTo(expected),
      reason: 'the band is bounded by the total-width cap: "$band"',
    );
    if (_cells(band) > 8 &&
        _cells(band) < expected &&
        !band.endsWith(glyphs.bandGlyph)) {
      fail('the band fills the stage width: "$band"');
    }
  }
  expect(
    bands.any((band) => band.endsWith(glyphs.bandGlyph) && _cells(band) > 2),
    isTrue,
    reason: 'the fill is what makes the band textual chrome',
  );
  expect(
    rows.where((row) => row.startsWith(glyphs.bodyIndent)).length,
    greaterThan(bands.length),
    reason: 'the body and the hint are indented under the band',
  );
  expect(
    rows.where((row) => row.startsWith('> ')),
    isEmpty,
    reason: 'the stage never falls back to the reference live marker',
  );
  for (final glyph in _framingGlyphs) {
    expect(
      text,
      isNot(contains(glyph)),
      reason: 'the block grammar draws no framing chrome: "$glyph"',
    );
  }
  for (final row in rows) {
    expect(
      _cells(_structurePart(row, structure, ascii: ascii)),
      lessThanOrEqualTo(columns),
      reason: '"$row"',
    );
  }
  if (inverse) {
    expect(
      text,
      contains('\x1b[7m'),
      reason: 'declared style support emphasises the band',
    );
  } else {
    expect(
      text,
      isNot(contains('\x1b[7m')),
      reason: 'the band never depends on inverse styling',
    );
  }
  if (outcome != null) {
    final reported = rows.where((row) => row.contains(outcome));
    expect(reported, isNotEmpty, reason: 'the run reports "$outcome"');
    for (final row in reported) {
      expect(
        row.startsWith(glyphs.bodyIndent),
        isTrue,
        reason: 'the outcome keeps the structure grammar: "$row"',
      );
    }
  }
}

const _themes = <PromptStructure, String>{
  PromptStructure.line: 'LineTheme',
  PromptStructure.block: 'BlockTheme',
};

/// The structures merged before this ticket, whose rendered bytes are a
/// contract this ticket may not change.
const _merged = <PromptStructure>[
  PromptStructure.plain,
  PromptStructure.rail,
  PromptStructure.branch,
  PromptStructure.box,
  PromptStructure.round,
  PromptStructure.double,
  PromptStructure.minimal,
  PromptStructure.ascii,
  PromptStructure.chevron,
  PromptStructure.bracket,
  PromptStructure.form,
  PromptStructure.ledger,
  PromptStructure.colon,
];

void main() {
  late Directory pickerDirectory;

  setUpAll(() async {
    pickerDirectory = await Directory.systemTemp.createTemp('line-block-');
    await File('${pickerDirectory.path}${Platform.pathSeparator}answer.txt')
        .writeAsString('data');
    _pickerBase = pickerDirectory.path;
  });

  tearDownAll(() => pickerDirectory.delete(recursive: true));

  for (final entry in _themes.entries) {
    final structure = entry.key;
    final themeName = entry.value;

    for (final mode in [PromptMode.linear, PromptMode.rich]) {
      group('$themeName draws every component / ${mode.name}', () {
        for (final testCase in themeMatrixCases(
          pickerBase: () => _pickerBase,
        )) {
          test(testCase.name, () async {
            final text = await _render(testCase, mode, structure);
            if (structure == PromptStructure.line) {
              _expectUnderlined(
                text,
                ascii: mode != PromptMode.rich,
                label: testCase.label,
                columns: 72,
                outcome: testCase.outcome,
              );
            } else {
              _expectBanded(
                text,
                ascii: mode != PromptMode.rich,
                label: testCase.label,
                columns: 72,
                outcome: testCase.outcome,
              );
            }
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
        final text = out.toString();
        final glyphs = _heading(structure, ascii: false);
        expect(text, contains(glyphs.bodyMarker));
        expect(text, isNot(contains('┌')));
        if (structure == PromptStructure.line) {
          expect(text, contains('─' * 72));
          expect(text, isNot(contains('█')));
        } else {
          expect(text, contains('█ '));
          expect(text, startsWith('█ NAME (OPTIONAL). '));
          expect(text, isNot(contains('─')));
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
        final text = out.toString();
        final glyphs = _heading(structure, ascii: true);
        expect(text, contains(glyphs.bodyMarker));
        for (final glyph in ['█', '─', '▶', '›']) {
          expect(text, isNot(contains(glyph)));
        }
        if (structure == PromptStructure.line) {
          expect(text, contains('-' * 72));
        } else {
          expect(text, contains('# NAME'));
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
      final decoration = _heading(structure, ascii: false);
      for (final row in _rows(out.toString())) {
        expect(row, isNot(contains('[2K')));
        expect(_cells(row), lessThanOrEqualTo(120), reason: '"$row"');
      }
      if (structure == PromptStructure.line) {
        final rule = _rows(out.toString())
            .firstWhere((row) => _isRule(row, structure, ascii: false));
        expect(_cells(rule), 80);
      } else {
        final band = _rows(out.toString())
            .firstWhere((row) => _isBand(row, structure, ascii: false));
        expect(_cells(band), 80);
        expect(band.endsWith(decoration.bandGlyph), isTrue);
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
        final glyphs = _heading(structure, ascii: true);
        final rows = _rows(out.toString());
        for (final row in rows) {
          expect(_cells(row), lessThanOrEqualTo(24), reason: '"$row"');
        }
        expect(
          rows.where(
            (row) => structure == PromptStructure.line
                ? _isRule(row, structure, ascii: true)
                : _isBand(row, structure, ascii: true),
          ),
          isNotEmpty,
          reason: 'the narrow stage keeps the structure decoration',
        );
        expect(rows.first, startsWith(glyphs.bandGlyph.isEmpty ? '' : '#'));
      },
    );

    test(
      '$themeName simplifies the decoration when width cannot hold it',
      () async {
        // The width has to hold the structure's own live-row marker plus one
        // overflow cell and one content cell, so this is the narrowest stage
        // that can still show a caret. Below it the terminal has no room for
        // the row the component edits at all, exactly as for every grammar
        // whose live marker is wider than the reference one.
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.linear, 'Ada\r', out, columns: 8),
          mode: PromptMode.linear,
        );
        final rows = _rows(out.toString());
        for (final row in rows) {
          expect(_cells(row), lessThanOrEqualTo(8), reason: '"$row"');
        }
        final keepsDecoration = rows.any(
          (row) => structure == PromptStructure.line
              ? _isRule(row, structure, ascii: true)
              : _isBand(row, structure, ascii: true),
        );
        expect(
          keepsDecoration,
          isTrue,
          reason:
              'a narrow stage keeps the structure marker instead of becoming '
              'the unframed reference presentation',
        );
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
        final decorationRow = _rows(out.toString()).firstWhere(
          (row) => structure == PromptStructure.line
              ? _isRule(row, structure, ascii: false)
              : _isBand(row, structure, ascii: false),
        );
        expect(
          _cells(decorationRow),
          lessThanOrEqualTo(72),
          reason: 'the palette does not change the measured width',
        );
      },
    );
  }

  group('line and block stage contracts', () {
    for (final entry in _themes.entries) {
      final structure = entry.key;
      final themeName = entry.value;

      test('$themeName re-decorates the stage on every presentation', () async {
        final out = StringBuffer();
        final result =
            await Select<String>('Region', [
              Choice('a', 'Europe'),
              Choice('b', 'United States'),
            ], structure: structure).prompt(
              source: _scripted(
                PromptMode.rich,
                '\x1b[B\r',
                out,
                inverse: true,
              ),
              mode: PromptMode.rich,
            );
        expect((result as Accepted<String>).value, 'b');
        final decorations = _rows(out.toString()).where(
          (row) => structure == PromptStructure.line
              ? _isRule(row, structure, ascii: false)
              : _isBand(row, structure, ascii: false),
        );
        expect(
          decorations.length,
          greaterThan(1),
          reason: 'the focus move redrew the decorated stage',
        );
      });

      test(
        '$themeName never duplicates its decoration in linear mode',
        () async {
          final out = StringBuffer();
          await TextInput('Name', structure: structure).prompt(
            source: _scripted(PromptMode.linear, 'Ada\r', out),
            mode: PromptMode.linear,
          );
          final decorations = _rows(out.toString()).where(
            (row) => structure == PromptStructure.line
                ? _isRule(row, structure, ascii: true)
                : _isBand(row, structure, ascii: true),
          );
          expect(
            decorations.length,
            1,
            reason: 'a keystroke is a compact event, not a new stage',
          );
        },
      );

      test(
        '$themeName keeps the real caret on a live row of its own',
        () async {
          final out = StringBuffer();
          final result = await TextInput('Name', structure: structure).prompt(
            source: _scripted(PromptMode.rich, 'Ada\r', out),
            mode: PromptMode.rich,
          );
          expect((result as Accepted<String>).value, 'Ada');
          final livePrefix = structureLivePrefix(structure, ascii: false);
          final caretRows = out
              .toString()
              .split('\r')
              .where((row) => row.contains('\x1b[s'))
              .map(_plain)
              .toList();
          expect(caretRows, isNotEmpty);
          for (final row in caretRows) {
            expect(
              row.startsWith(livePrefix),
              isTrue,
              reason: 'the editable row keeps the structure marker: "$row"',
            );
            expect(_cells(row), lessThanOrEqualTo(72), reason: '"$row"');
          }
          expect(
            out.toString(),
            contains('Ada'),
            reason: 'the caret row shows the real draft, not a placeholder',
          );
        },
      );

      test('$themeName never transforms answer data', () async {
        final out = StringBuffer();
        final result = await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.rich, 'Ada Lovelace\r', out),
          mode: PromptMode.rich,
        );
        expect((result as Accepted<String>).value, 'Ada Lovelace');
        final text = out.toString();
        expect(text, contains('Ada Lovelace'));
        for (final row in _rows(text)) {
          final decorated = structure == PromptStructure.line
              ? _isRule(row, structure, ascii: false)
              : _isBand(row, structure, ascii: false);
          if (structure == PromptStructure.block &&
              _isBand(row, structure, ascii: false)) {
            expect(row.contains('Ada Lovelace'), isFalse);
            expect(row.contains('ADA LOVELACE'), isFalse);
          }
          if (structure == PromptStructure.line && decorated) {
            expect(row.contains('Ada'), isFalse);
          }
        }
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
        final rows = _rows(out.toString());
        expect(out.toString(), contains('Help:'));
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i];
          if (row.startsWith(glyphs.bodyIndent)) continue;
          if (structure == PromptStructure.line &&
              _isRule(row, structure, ascii: true)) {
            continue;
          }
          expect(
            _isBand(row, structure, ascii: true) ||
                (i + 1 < rows.length &&
                    _isRule(rows[i + 1], structure, ascii: true)),
            isTrue,
            reason: 'help keeps the structure grammar: "$row"',
          );
        }
      });
    }
  });

  group('monochrome label bands', () {
    test(
      'a band is textual chrome with no colour and no inverse styling',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: PromptStructure.block).prompt(
          source: _scripted(PromptMode.rich, 'Ada\r', out, columns: 40),
          mode: PromptMode.rich,
        );
        final text = out.toString();
        expect(text, isNot(contains('\x1b[7m')));
        expect(text, isNot(contains('\x1b[38')));
        final band = _rows(text).first;
        expect(band, startsWith('█ NAME (OPTIONAL). '));
        expect(band.endsWith('█'), isTrue);
        expect(_cells(band), 40);
      },
    );

    test(
      'declared style support adds inverse emphasis to the same band',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: PromptStructure.block).prompt(
          source: _scripted(
            PromptMode.rich,
            'Ada\r',
            out,
            columns: 40,
            inverse: true,
          ),
          mode: PromptMode.rich,
        );
        final text = out.toString();
        expect(text, contains('\x1b[7m█ NAME (OPTIONAL). '));
        final band = _rows(text).first;
        expect(band, startsWith('█ NAME (OPTIONAL). '));
        expect(band.endsWith('█'), isTrue);
        expect(_cells(band), 40);
      },
    );

    test('an automatic style profile falls back to the textual band', () async {
      final out = StringBuffer();
      await TextInput('Name', structure: PromptStructure.block).prompt(
        source: ScriptedInput(
          Stream.value('Ada\n'),
          out,
          outputProfile: OutputProfile(
            geometry: OutputGeometry.fixed(columns: 40, rows: 20),
            glyphs: GlyphSet.unicode,
          ),
        ),
        mode: PromptMode.linear,
      );
      final text = out.toString();
      expect(text, isNot(contains('\x1b[7m')));
      expect(_rows(text).first, startsWith('█ NAME (OPTIONAL). '));
    });

    test(
      'a redirected log keeps the band and carries no SGR styling',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: PromptStructure.block).prompt(
          source: ScriptedInput(
            Stream.value('Ada\n'),
            out,
            outputProfile: OutputProfile(
              colorDepth: ColorDepth.none,
              geometry: OutputGeometry.fixed(columns: 40, rows: 20),
              glyphs: GlyphSet.unicode,
              styles: CapabilitySupport.unsupported,
            ),
          ),
          mode: PromptMode.linear,
        );
        final text = out.toString();
        expect(
          text,
          isNot(matches(RegExp(r'\x1b\[[0-9;]*m'))),
          reason: 'a redirected log carries no colour and no inverse styling',
        );
        expect(_rows(text).first, startsWith('█ NAME (OPTIONAL). '));
        expect(_rows(text).first.endsWith('█'), isTrue);
      },
    );

    test('the underline is drawn in the same monochrome profile', () async {
      final out = StringBuffer();
      await TextInput('Name', structure: PromptStructure.line).prompt(
        source: ScriptedInput(
          Stream.value('Ada\n'),
          out,
          outputProfile: OutputProfile(
            colorDepth: ColorDepth.none,
            geometry: OutputGeometry.fixed(columns: 40, rows: 20),
            glyphs: GlyphSet.unicode,
          ),
        ),
        mode: PromptMode.linear,
      );
      final text = out.toString();
      expect(text, isNot(matches(RegExp(r'\x1b\[[0-9;]*m'))));
      expect(_rows(text)[1], '─' * 40);
    });
  });

  group('emphasis never reports a selection', () {
    test('the inverse band never covers a choice row', () async {
      final out = StringBuffer();
      final result =
          await Select<String>('Region', [
            Choice('a', 'Europe'),
            Choice('b', 'United States'),
          ], structure: PromptStructure.block).prompt(
            source: _scripted(PromptMode.rich, '\x1b[B\r', out, inverse: true),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'b');
      final emphasised = out
          .toString()
          .split(RegExp('[\r\n]'))
          .where((row) => row.contains('\x1b[7m'))
          .map(_plain)
          .toList();
      expect(emphasised, isNotEmpty);
      for (final row in emphasised) {
        expect(row.contains('Europe'), isFalse, reason: '"$row"');
        expect(row.contains('United States'), isFalse, reason: '"$row"');
        expect(_isBand(row, PromptStructure.block, ascii: false), isTrue);
      }
      expect(out.toString(), contains('Accepted: United States.'));
    });

    test('a retained default is not marked as an accepted answer', () async {
      final out = StringBuffer();
      final result =
          await Select<String>(
            'Region',
            [Choice('a', 'Europe'), Choice('b', 'United States')],
            defaultValue: 'a',
            structure: PromptStructure.block,
          ).prompt(
            source: _scripted(PromptMode.linear, '2\r', out),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'b');
      final text = out.toString();
      expect(text, contains('default'));
      expect(text, contains('Accepted: United States.'));
      expect(_rows(text).first, isNot(contains('Europe')));
      expect(_rows(text).first, isNot(contains('United States')));
    });

    test('checked, focused and unavailable stay distinct facts', () async {
      final out = StringBuffer();
      final result =
          await MultiSelect<String>('Choices', [
            Choice('a', 'Alpha'),
            Choice('b', 'Beta'),
            Choice('c', 'Gamma', disabledReason: 'Not provisioned'),
          ], structure: PromptStructure.block).prompt(
            source: _scripted(
              PromptMode.rich,
              '\x1b[B \x1b[B\r',
              out,
              inverse: true,
            ),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<List<String>>).value, ['b']);
      final rows = _rows(out.toString());
      expect(
        rows.where((row) => row.contains('Beta') && row.contains('checked')),
        isNotEmpty,
      );
      expect(rows.where((row) => row.contains('Not provisioned')), isNotEmpty);
      for (final row in rows.where((row) => row.contains('focused'))) {
        expect(_isBand(row, PromptStructure.block, ascii: false), isFalse);
      }
    });

    test('both grammars accept the same outcome as the reference', () async {
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
            'Select': (structure, mode, input) => Select<String>('Region', [
              Choice('a', 'Europe'),
              Choice('b', 'United States'),
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
      for (final probe in probes.entries) {
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
              _scripted(mode, answer, StringBuffer(), inverse: true),
            );
            expect(
              outcome(themed),
              outcome(baseline),
              reason: '${probe.key}/${structure.name}/${mode.name}',
            );
          }
        }
      }
    });
  });

  group('line and block feedback', () {
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
        expect(_plain(text), startsWith(marker));
        for (final glyph in _framingGlyphs) {
          expect(text, isNot(contains(glyph)));
        }
      });

      for (final mode in [PromptMode.linear, PromptMode.rich]) {
        test('$themeName progress keeps its lifecycle / ${mode.name}', () {
          final out = StringBuffer();
          final progress = Progress('Copy', total: 4, structure: structure);
          progress.start(output: out, mode: mode, supportsRich: true);
          progress.update(2);
          progress.finish(FeedbackOutcome.completed);
          final text = out.toString();
          expect(text, contains('Copy: completed'));
          for (final row in _rows(text)) {
            expect(row, contains(marker), reason: '"$row"');
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
          for (final row in _rows(text)) {
            expect(row, contains(marker), reason: '"$row"');
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
          for (final row in _rows(text)) {
            expect(row, contains(marker), reason: '"$row"');
          }
        });
      }
    }
  });

  group('line and block decoration width', () {
    test('the band and the underline share the total-width cap', () {
      for (final width in [null, 1, 4, 24, 80, 81, 200]) {
        final expected = width == null ? 80 : width.clamp(1, 80);
        expect(structureBandWidth(PromptStructure.block, width), expected);
        expect(structureRuleWidth(PromptStructure.line, width), expected);
      }
    });

    test('a band row is exactly the stage width it was composed for', () {
      for (final width in [80, 40, 24, 8]) {
        final row = structureBandRow(
          PromptStructure.block,
          ascii: false,
          label: 'NAME',
          width: width,
        );
        expect(_cells(row), width, reason: '$width: "$row"');
        expect(row, startsWith('█ NAME '));
        expect(row, endsWith('█'));
      }
    });

    test('narrow band rows simplify the fill instead of overflowing', () {
      for (final width in [7, 6, 5, 4, 3, 2, 1]) {
        for (final ascii in [false, true]) {
          final row = structureBandRow(
            PromptStructure.block,
            ascii: ascii,
            label: 'N',
            width: width,
          );
          expect(
            _cells(row),
            lessThanOrEqualTo(width),
            reason: '$width: "$row"',
          );
        }
      }
      expect(
        structureBandRow(
          PromptStructure.block,
          ascii: true,
          label: 'N',
          width: 4,
        ),
        '# N ',
        reason: 'the padding cell either side of the label is part of the band',
      );
      expect(
        structureBandRow(
          PromptStructure.block,
          ascii: true,
          label: 'N',
          width: 3,
        ),
        '# N',
        reason: 'the trailing fill goes first when the width cannot hold it',
      );
      expect(
        structureBandRow(
          PromptStructure.block,
          ascii: true,
          label: 'NAME',
          width: 4,
        ),
        'NAME',
        reason: 'a label too wide for the band is kept whole, never truncated',
      );
    });

    test('a structure without a band returns the label unchanged', () {
      for (final structure in PromptStructure.values) {
        if (structure == PromptStructure.block) continue;
        expect(
          structureBandRow(structure, ascii: false, label: 'NAME', width: 20),
          'NAME',
          reason: '$structure',
        );
      }
    });
  });

  group('line and block grammar vocabulary', () {
    test('only the block draws a label band', () {
      for (final structure in PromptStructure.values) {
        final glyphs = headingGlyphsFor(structure, ascii: false);
        expect(
          glyphs?.drawsBand ?? false,
          structure == PromptStructure.block,
          reason: '$structure',
        );
      }
    });

    test('only the form, ledger and line draw a heading rule', () {
      for (final structure in PromptStructure.values) {
        final glyphs = headingGlyphsFor(structure, ascii: false);
        final ruled =
            structure == PromptStructure.form ||
            structure == PromptStructure.ledger ||
            structure == PromptStructure.line;
        expect(glyphs?.drawsRule ?? false, ruled, reason: '$structure');
      }
    });

    test('the underline and the band are the approved spellings', () {
      final line = headingGlyphsFor(PromptStructure.line, ascii: false)!;
      expect(line.ruleGlyph, '─');
      expect(line.uppercaseHeading, isFalse);
      expect(line.bodyIndent, '  ');
      expect(line.hintPrefix, isEmpty);
      expect(line.bodyMarker, '  › ');

      final asciiLine = headingGlyphsFor(PromptStructure.line, ascii: true)!;
      expect(asciiLine.ruleGlyph, '-');
      expect(asciiLine.bodyMarker, '  > ');

      final block = headingGlyphsFor(PromptStructure.block, ascii: false)!;
      expect(block.bandGlyph, '█');
      expect(block.uppercaseHeading, isTrue);
      expect(block.bodyIndent, '  ');
      expect(block.hintPrefix, isEmpty);
      expect(block.bodyMarker, '  ▶ ');
      expect(block.drawsRule, isFalse);

      final asciiBlock = headingGlyphsFor(PromptStructure.block, ascii: true)!;
      expect(asciiBlock.bandGlyph, '#');
      expect(asciiBlock.bodyMarker, '  > ');
    });

    test('both grammars report their body cells and live marker', () {
      for (final structure in _themes.keys) {
        expect(structurePrefixCells(structure), 2);
        expect(
          structureLivePrefix(structure, ascii: true),
          headingGlyphsFor(structure, ascii: true)!.bodyMarker,
        );
        expect(
          structureLivePrefix(structure, ascii: false),
          headingGlyphsFor(structure, ascii: false)!.bodyMarker,
        );
        expect(usesStructureHeading(structure), isTrue);
        expect(usesStructureFraming(structure), isTrue);
        expect(usesStructurePrefix(structure), isFalse);
        expect(usesStructureEnclosure(structure), isFalse);
      }
    });

    test('only the block case-transforms its heading', () {
      expect(
        structureHeadingText(PromptStructure.block, 'Deploy target'),
        'DEPLOY TARGET',
      );
      expect(
        structureHeadingText(PromptStructure.line, 'Deploy target'),
        'Deploy target',
      );
    });

    test('the two grammars never render the same bytes', () async {
      final line = StringBuffer();
      final block = StringBuffer();
      final plain = StringBuffer();
      for (final (structure, out) in [
        (PromptStructure.line, line),
        (PromptStructure.block, block),
        (PromptStructure.plain, plain),
      ]) {
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.linear, 'Ada\r', out),
          mode: PromptMode.linear,
        );
      }
      expect(line.toString(), isNot(block.toString()));
      expect(line.toString(), isNot(plain.toString()));
      expect(block.toString(), isNot(plain.toString()));
    });
  });

  group('the merged structures keep their bytes', () {
    // The exact bytes every previously merged structure produced for one
    // linear TextInput stage. Adding a structure may not reshape the bytes of a
    // structure that was already delivered: this map is the byte contract.
    Future<String> render(PromptStructure structure) async {
      final out = StringBuffer();
      await TextInput('Name', structure: structure).prompt(
        source: ScriptedInput(Stream.value('Ada\n'), out),
        mode: PromptMode.linear,
      );
      return out.toString();
    }

    for (final structure in _merged) {
      test('${structure.name} keeps its linear bytes', () async {
        expect(await render(structure), _pinnedLinear[structure]);
      });
    }

    test('the reference presentation stays plain', () async {
      final text = await render(PromptStructure.plain);
      for (final glyph in [
        '? ',
        '[ ',
        '❯ ',
        '↳ ',
        '» ',
        '› ',
        '▶ ',
        '█',
        '# ',
      ]) {
        expect(text, isNot(contains(glyph)));
      }
    });
  });

  group('a resize recomposes the decoration', () {
    for (final entry in _themes.entries) {
      final structure = entry.key;
      final themeName = entry.value;

      test(
        '$themeName repaints at the new width without losing the draft',
        () async {
          final keys = StreamController<String>();
          final resized = StreamController<void>();
          final output = StringBuffer();
          final transcript = TextInputTranscript();
          final observer = _ResizeObserver(
            resized.stream,
            () => (columns: 10, rows: 4),
          );
          final result =
              TextInput(
                'Name',
                initialValue: 'abcdefgh',
                structure: structure,
              ).prompt(
                source: ScriptedInput(
                  keys.stream,
                  output,
                  outputProfile: OutputProfile(
                    cursor: CapabilitySupport.supported,
                    geometry: OutputGeometry.fixed(columns: 30, rows: 4),
                    glyphs: GlyphSet.unicode,
                  ),
                  transcript: transcript,
                  resizeObserver: observer,
                ),
                mode: PromptMode.rich,
              );
          await pumpEventQueue();
          resized.add(null);
          await pumpEventQueue();

          expect(transcript.currentView!.text, 'abcdefgh');
          expect(transcript.currentView!.caret, 8);
          expect(transcript.events, hasLength(1));
          final rows = _rows(output.toString());
          final decorations = rows
              .where(
                (row) => structure == PromptStructure.line
                    ? _isRule(row, structure, ascii: false)
                    : _isBand(row, structure, ascii: false),
              )
              .toList();
          expect(
            decorations.length,
            1,
            reason:
                'a resize is a repaint, not a second stage: it never '
                'duplicates the decoration in the transcript',
          );
          expect(
            _cells(decorations.single),
            30,
            reason: 'the stage measured the width it was opened at',
          );
          final live = structureLivePrefix(structure, ascii: false);
          final caretRows = rows.where((row) => row.startsWith(live)).toList();
          expect(
            caretRows,
            isNotEmpty,
            reason:
                'the editable row keeps the structure marker after a resize',
          );
          expect(
            _cells(caretRows.last),
            lessThanOrEqualTo(10),
            reason: 'the repaint measured the new width: "${caretRows.last}"',
          );
          expect(
            caretRows.last,
            contains('<'),
            reason: 'the caret viewport shows the offscreen overflow marker',
          );

          keys.add('\r');
          expect((await result as Accepted<String>).value, 'abcdefgh');
          await keys.close();
          await resized.close();
        },
      );
    }
  });
}

final class _ResizeObserver implements TerminalResizeObserver {
  _ResizeObserver(this.notifications, this._dimensions);

  @override
  final Stream<void> notifications;
  final ({int columns, int rows})? Function() _dimensions;
  bool cancelled = false;

  @override
  ({int columns, int rows})? readDimensions() => _dimensions();

  @override
  Duration get fallbackInterval => const Duration(days: 1);
}

late String _pickerBase;
