import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/state_help_presentation.dart';
import 'package:trelis/trelis.dart';

final _unicodeProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  glyphs: GlyphSet.unicode,
  geometry: OutputGeometry.fixed(columns: 100, rows: 20),
);

final _asciiProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  glyphs: GlyphSet.ascii,
  geometry: OutputGeometry.fixed(columns: 100, rows: 20),
);

List<String> _rows(String text) => text
    .split('\n')
    .where((line) => RegExp(r'\d+\.\s').hasMatch(line))
    .toList();

Future<String> _renderTree({
  required StateGlyphs glyphs,
  required String input,
  String? defaultValue,
}) async {
  final output = StringBuffer();
  await TreeSelect<String>(
    'Pick',
    [
      TreeNode('branch', 'Branch', children: [TreeNode('child', 'Child')]),
      TreeNode('leaf', 'Leaf'),
    ],
    defaultValue: defaultValue,
    presentation: ChoicePresentationConfig(glyphs: glyphs),
  ).prompt(
    source: ScriptedInput(
      Stream.value(input),
      output,
      outputProfile: glyphs == StateGlyphs.ascii
          ? _asciiProfile
          : _unicodeProfile,
    ),
    mode: PromptMode.rich,
  );
  return output.toString();
}

void main() {
  test('tree disclosure uses a separate aligned position in Unicode', () async {
    final expanded = await _renderTree(
      glyphs: StateGlyphs.unicode,
      input: '\x1b',
      defaultValue: 'child',
    );
    final rows = _rows(expanded);
    expect(rows, hasLength(3));
    expect(rows[0], startsWith('▾'));
    expect(rows[1], startsWith(' '), reason: 'a leaf keeps a blank disclosure');
    expect(rows[2], startsWith(' '));
    expect(rows[1].indexOf('2.'), rows[0].indexOf('1.'));

    final collapsed = await _renderTree(
      glyphs: StateGlyphs.unicode,
      input: '\x1b',
    );
    expect(_rows(collapsed).first, startsWith('▸'));
  });

  test('tree disclosure uses the portable ASCII pair', () async {
    final expanded = await _renderTree(
      glyphs: StateGlyphs.ascii,
      input: '\x1b',
      defaultValue: 'child',
    );
    final rows = _rows(expanded);
    expect(rows[0], startsWith('v'));
    expect(rows[1], startsWith(' '));

    final collapsed = await _renderTree(
      glyphs: StateGlyphs.ascii,
      input: '\x1b',
    );
    expect(_rows(collapsed).first, startsWith('>'));
  });
}
