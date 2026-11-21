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

  test('order rows keep position, movement and locked reasons apart', () async {
    final output = StringBuffer();
    final result =
        await SortableSelect<String>(
          'Order',
          [
            Choice('a', 'Alpha'),
            Choice('b', 'Beta'),
            Choice('anchor', 'Anchor', disabledReason: 'protected'),
          ],
          presentation: const ChoicePresentationConfig(
            glyphs: StateGlyphs.ascii,
            restrictions: {3: ChoiceRestriction.locked},
          ),
        ).prompt(
          source: ScriptedInput(
            Stream.value(' \x1b[B\r\r'),
            output,
            outputProfile: _asciiProfile,
          ),
          mode: PromptMode.rich,
        );

    expect((result as Accepted<List<String>>).value, ['b', 'a', 'anchor']);
    final text = output.toString();
    expect(text, contains('Position 1 of 3'));
    expect(text, contains('Position 3 of 3'));
    expect(text, contains('(moving)'));
    expect(text, contains('[L]'));
    expect(text, contains('protected'));

    final helpOutput = StringBuffer();
    await SortableSelect<String>(
      'Order',
      [
        Choice('a', 'Alpha'),
        Choice('b', 'Beta'),
        Choice('anchor', 'Anchor', disabledReason: 'protected'),
      ],
      presentation: const ChoicePresentationConfig(
        restrictions: {3: ChoiceRestriction.locked},
      ),
    ).prompt(
      source: ScriptedInput(Stream.value('/help\r/cancel\r'), helpOutput),
      mode: PromptMode.linear,
    );
    expect(helpOutput.toString(), contains('Help: Ordering the list.'));
    expect(helpOutput.toString(), contains('Ordering 3 identities.'));
    expect(helpOutput.toString(), contains('protected'));
  });

  test(
    'search and command results use themed focus, default and restrictions',
    () async {
      final searchOutput = StringBuffer();
      final cancelled =
          await SearchSelect<String>(
            'Fruit',
            [
              Choice('a', 'Apple', disabledReason: 'offline'),
              Choice('b', 'Banana'),
              Choice('c', 'Cherry'),
            ],
            defaultValue: 'b',
            presentation: const ChoicePresentationConfig(
              restrictions: {1: ChoiceRestriction.unavailable},
            ),
          ).prompt(
            source: ScriptedInput(Stream.value('\r1\r/cancel\r'), searchOutput),
            mode: PromptMode.linear,
          );
      expect(cancelled, isA<Cancelled<String>>());
      final searchText = searchOutput.toString();
      expect(searchText, contains('[!]'));
      expect(searchText, contains('offline'));
      expect(searchText, contains('→'));
      expect(searchText, contains('★'));
      expect(searchText, contains('Unavailable: offline.'));

      final commandOutput = StringBuffer();
      final accepted =
          await CommandPalette<String>(
            'Commands',
            [Choice('open', 'Open file'), Choice('save', 'Save file')],
            presentation: const ChoicePresentationConfig(
              glyphs: StateGlyphs.ascii,
              selectedReference: 2,
            ),
          ).prompt(
            source: ScriptedInput(
              Stream.value('\r2\r'),
              commandOutput,
              outputProfile: _asciiProfile,
            ),
            mode: PromptMode.linear,
          );
      expect((accepted as Accepted<String>).value, 'save');
      expect(commandOutput.toString(), contains('(*)'));
      expect(commandOutput.toString(), contains('( )'));
    },
  );

  test('autocomplete candidates use positions, not stale references', () async {
    final linearOutput = StringBuffer();
    final linear =
        await Autocomplete(
          'Name',
          suggestions: (_) => ['Ada', 'Grace'],
          presentation: const ChoicePresentationConfig(
            showReference: false,
            selectedReference: 2,
          ),
        ).prompt(
          source: ScriptedInput(Stream.value('A\r1\r/submit\r'), linearOutput),
          mode: PromptMode.linear,
        );
    expect((linear as Accepted<String>).value, 'Ada');
    final linearText = linearOutput.toString();
    expect(linearText, contains('Position 1 of 2'));
    expect(linearText, contains('●'), reason: 'selection is a separate glyph');
    expect(
      linearText.indexOf('Position 1 of 2'),
      lessThan(linearText.indexOf('Accepted into pending answer')),
    );

    final richOutput = StringBuffer();
    final rich =
        await Autocomplete(
          'Name',
          suggestions: (_) => ['Ada', 'Grace'],
          presentation: const ChoicePresentationConfig(showReference: false),
        ).prompt(
          source: ScriptedInput(
            Stream.value('a\x1b[B\x1b[B\t\r'),
            richOutput,
            outputProfile: _unicodeProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((rich as Accepted<String>).value, 'Grace');
    expect(richOutput.toString(), contains('Position 2 of 2'));
    expect(richOutput.toString(), contains('→'));
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
