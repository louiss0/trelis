import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 40, rows: 8),
);

final _narrowProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 24, rows: 6),
);

/// Renders the emitted transcript as physical terminal lines: a carriage
/// return followed by an erase-line sequence leaves only the rewritten tail of
/// that line, so a repainted editable line is measured once.
Iterable<String> _visibleLines(String text) => text
    .split('\n')
    .map(
      (line) => line
          .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '')
          .split('\r')
          .last,
    )
    .where((line) => line.isNotEmpty);

/// The component's own lines.
///
/// The shared sequential editor's status lines are not width-wrapped; they are
/// owned by the text-input tickets and are excluded so a narrow-width tree or
/// order row is measured without hiding a real overflow.
Iterable<String> _componentLines(String text) => _visibleLines(text).where(
  (line) =>
      !line.startsWith('Current text:') && !line.startsWith('Cursor position:'),
);

void main() {
  test(
    'tree honours declared rich facts and refuses undeclared rich output',
    () async {
      final declared =
          await TreeSelect<String>('Pick', [
            TreeNode('a', 'A', children: [TreeNode('b', 'B')]),
          ]).prompt(
            source: ScriptedInput(
              Stream.value('\x1b[C\x1b[C\r'),
              StringBuffer(),
              supportsRich: false,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((declared as Accepted<String>).value, 'b');

      expect(
        await TreeSelect<String>('Pick', [TreeNode('a', 'A')]).prompt(
          source: ScriptedInput(Stream.value('\r'), StringBuffer()),
          mode: PromptMode.rich,
        ),
        isA<Unavailable<String>>(),
      );

      final linearOutput = StringBuffer();
      final automatic =
          await TreeSelect<String>('Pick', [
            TreeNode('a', 'A'),
            TreeNode('b', 'B'),
          ]).prompt(
            source: ScriptedInput(Stream.value('/choose\r2\r'), linearOutput),
            mode: PromptMode.automatic,
          );
      expect((automatic as Accepted<String>).value, 'b');
      expect(linearOutput.toString(), contains('Path: root'));
    },
  );

  test(
    'order honours declared rich facts and refuses undeclared rich output',
    () async {
      final declared =
          await SortableSelect<String>('Order', [
            Choice('a', 'A'),
            Choice('b', 'B'),
          ]).prompt(
            source: ScriptedInput(
              Stream.value(' \x1b[B\r\r'),
              StringBuffer(),
              supportsRich: false,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((declared as Accepted<List<String>>).value, ['b', 'a']);

      expect(
        await SortableSelect<String>('Order', [Choice('a', 'A')]).prompt(
          source: ScriptedInput(Stream.value('\r'), StringBuffer()),
          mode: PromptMode.rich,
        ),
        isA<Unavailable<List<String>>>(),
      );

      final automatic =
          await SortableSelect<String>('Order', [
            Choice('a', 'A'),
            Choice('b', 'B'),
          ]).prompt(
            source: ScriptedInput(
              Stream.value('/move\r2\r1\r/done\r'),
              StringBuffer(),
            ),
            mode: PromptMode.automatic,
          );
      expect((automatic as Accepted<List<String>>).value, ['b', 'a']);
    },
  );

  test(
    'tree rows keep path, reference and state markers inside a narrow width',
    () async {
      final output = StringBuffer();
      final result =
          await TreeSelect<String>('Pick', [
            TreeNode(
              'a',
              'Very long branch label that cannot fit',
              disabledReason: 'offline',
              children: [TreeNode('b', 'Nested leaf')],
            ),
            TreeNode('c', 'Second root'),
          ], defaultValue: 'c').prompt(
            source: ScriptedInput(
              Stream.value('/open\r1\r/help\r/cancel\r'),
              output,
              outputProfile: _narrowProfile,
            ),
            mode: PromptMode.linear,
          );
      expect(result, isA<Cancelled<String>>());
      final lines = _componentLines(output.toString()).toList();
      for (final line in lines) {
        expect(
          line.length,
          lessThanOrEqualTo(24),
          reason: 'line exceeds the declared width: "$line"',
        );
      }
      final text = lines.join('\n');
      // The reference prefix and every meaningful marker survive wrapping as
      // one unit; they are never split across physical lines.
      expect(text, contains('1.'));
      expect(text, contains('[collapsed]'));
      expect(text, contains('[selectable]'));
      expect(text, contains('[unavailable: offline]'));
      expect(text, contains('[default]'));
      expect(text, contains('Very long branch'));
    },
  );

  test(
    'order rows keep position, focus and locked markers inside a narrow width',
    () async {
      final output = StringBuffer();
      final result =
          await SortableSelect<String>('Order', [
            Choice('a', 'A first item with a long label'),
            Choice('x', 'Anchor', disabledReason: 'protected'),
            Choice('b', 'B'),
          ]).prompt(
            source: ScriptedInput(
              Stream.value(' \x1b[B \x1b[B\r\r'),
              output,
              outputProfile: _narrowProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<List<String>>).value, ['a', 'x', 'b']);
      final lines = _visibleLines(output.toString()).toList();
      for (final line in lines) {
        expect(
          line.length,
          lessThanOrEqualTo(24),
          reason: 'line exceeds the declared width: "$line"',
        );
      }
      final text = lines.join('\n');
      expect(text, contains('[position 1 of 3]'));
      expect(text, contains('[locked: protected]'));
      expect(text, contains('[focused]'));
      expect(text, contains('[moving]'));
    },
  );
}
