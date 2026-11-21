import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/state_help_presentation.dart';
import 'package:trelis/src/theme_tree_search_components.dart';
import 'package:trelis/trelis.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  glyphs: GlyphSet.unicode,
  geometry: OutputGeometry.fixed(columns: 200, rows: 20),
);

final _asciiProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  glyphs: GlyphSet.ascii,
  geometry: OutputGeometry.fixed(columns: 80, rows: 15),
);

List<TreeNode<String>> _nodes() => [
  TreeNode(
    'branch',
    'Branch',
    children: [TreeNode('child', 'Child')],
    selectable: true,
  ),
  TreeNode('blocked', 'Blocked', disabledReason: 'offline'),
  TreeNode(
    'branchOnly',
    'Branch only',
    children: [TreeNode('leaf', 'Leaf')],
    selectable: false,
  ),
];

ThemeTreeSelectPrompt<String> _tree(
  String input,
  StringSink output, {
  InteractionPreferences interaction = const InteractionPreferences(),
  OutputProfile profile = const OutputProfile(),
  String? defaultValue,
  SingleSelectionStyle style = SingleSelectionStyle.circles,
}) => ThemeTreeSelectPrompt<String>(
  'Pick',
  _nodes(),
  io: TerminalEnvironment.scripted(
    input: Stream.value(input),
    output: output,
    profile: profile,
    supportsRich: profile.supportsRichInteraction,
  ),
  interaction: interaction,
  instructions: InstructionDisplay.hidden,
  defaultValue: defaultValue,
  glyphs: style == SingleSelectionStyle.circles
      ? StateGlyphs.unicode
      : StateGlyphs.ascii,
  selectionStyle: style,
);

List<Choice<String>> _choices() => [
  Choice('a', 'Alpha'),
  Choice('b', 'Beta'),
  Choice('anchor', 'Anchor', disabledReason: 'protected'),
];

ThemeOrderPrompt<String> _order(
  String input,
  StringSink output, {
  InteractionPreferences interaction = const InteractionPreferences(),
  OutputProfile profile = const OutputProfile(),
}) => ThemeOrderPrompt<String>(
  'Order',
  _choices(),
  io: TerminalEnvironment.scripted(
    input: Stream.value(input),
    output: output,
    profile: profile,
    supportsRich: profile.supportsRichInteraction,
  ),
  interaction: interaction,
  instructions: InstructionDisplay.hidden,
  glyphs: profile.glyphs == GlyphSet.ascii
      ? StateGlyphs.ascii
      : StateGlyphs.unicode,
);

void main() {
  test(
    'themed tree keeps disclosure, focus, default and restrictions apart',
    () async {
      final richOutput = StringBuffer();
      final rich = await _tree(
        '\x1b[C\r',
        richOutput,
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        profile: _richProfile,
        defaultValue: 'child',
      ).prompt();
      expect((rich as Accepted<String>).value, 'child');
      expect(richOutput.toString(), contains('▾'));
      expect(richOutput.toString(), contains('→'));
      expect(richOutput.toString(), contains('★'));
      expect(richOutput.toString(), contains('[!]'));
      expect(richOutput.toString(), contains('offline'));
      expect(richOutput.toString(), contains('[L]'));
      expect(richOutput.toString(), contains('not selectable'));
      expect(
        richOutput.toString().replaceAll(RegExp(r'\s+'), ' '),
        contains('Ctrl+T help'),
      );

      final linearOutput = StringBuffer();
      final linear = await _tree(
        '/open\r1\r/choose\r2\r',
        linearOutput,
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      ).prompt();
      expect((linear as Accepted<String>).value, 'child');
      expect(linearOutput.toString(), contains('/help'));

      final readerOutput = StringBuffer();
      final reader = await _tree(
        '/choose\r2\r',
        readerOutput,
        interaction: const InteractionPreferences(
          mode: PromptMode.linear,
          screenReader: ScreenReaderPreference.on,
        ),
      ).prompt();
      expect((reader as Accepted<String>).value, 'child');
      final text = readerOutput.toString();
      expect(text, contains('Pick, tree selection of 5 nodes.'));
      expect(
        text.indexOf('Pick, tree selection'),
        lessThan(text.indexOf('Pick TreeSelect')),
      );
      expect(text, contains('/help opens help.'));
    },
  );
  test(
    'themed ordering keeps positions, locks and ordering help apart',
    () async {
      final richOutput = StringBuffer();
      final rich = await _order(
        ' \x1b[B\r\r',
        richOutput,
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        profile: _richProfile,
      ).prompt();
      expect((rich as Accepted<List<String>>).value, ['b', 'a', 'anchor']);
      final richText = richOutput.toString().replaceAll(RegExp(r'\s+'), ' ');
      expect(richText, contains('Position 1 of 3'));
      expect(richText, contains('(moving)'));
      expect(richText, contains('[L]'));
      expect(richText, contains('protected'));
      expect(richText, contains('Ctrl+T help'));

      final linearOutput = StringBuffer();
      final linear = await _order(
        '/help\r/move\r2\r1\r/done\r',
        linearOutput,
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      ).prompt();
      expect((linear as Accepted<List<String>>).value, ['b', 'a', 'anchor']);
      expect(linearOutput.toString(), contains('Help: Ordering the list.'));
      expect(linearOutput.toString(), contains('/help and /cancel'));

      final readerOutput = StringBuffer();
      final reader = await _order(
        '/done\r',
        readerOutput,
        interaction: const InteractionPreferences(
          mode: PromptMode.linear,
          screenReader: ScreenReaderPreference.on,
        ),
      ).prompt();
      expect((reader as Accepted<List<String>>).value, ['a', 'b', 'anchor']);
      final text = readerOutput.toString();
      expect(text, contains('Order, ordering of 3 choices.'));
      expect(
        text.indexOf('Order, ordering'),
        lessThan(text.indexOf('Order SortableSelect')),
      );
    },
  );
}
