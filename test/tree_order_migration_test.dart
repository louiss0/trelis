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

final class _FakeTerminal implements TerminalIo, TerminalIoOutputProfile {
  _FakeTerminal(this.input, this.output, this.outputProfile);

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  @override
  final OutputProfile outputProfile;

  @override
  Map<String, String?> get environment => const {};

  final List<String> events = [];

  @override
  bool get supportsRich => false;

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}

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

  test('rich tree help leads with the navigating stage', () async {
    final output = StringBuffer();
    final result =
        await TreeSelect<String>('Pick', [
          TreeNode(
            'a',
            'Archive',
            disabledReason: 'offline',
            children: [TreeNode('b', 'Report')],
          ),
          TreeNode('c', 'Second root'),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('\x14\x1b\x14\x1b\x03'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(result, isA<Interrupted<String>>());
    final text = _visibleLines(output.toString()).join('');
    expect(text, contains('Help: Navigating the tree'));
    // The focused node's own path, expansion and selectability are the context
    // the assistance is about, and every unavailable reason is protected.
    expect(text, contains('Focus: 3. Second root'));
    expect(text, contains('offline'));
    expect(text, contains('Right expands'));
    expect(text, contains('Ctrl+C interrupts'));
  });

  test(
    'linear tree help separates choosing from entering a reference',
    () async {
      final output = StringBuffer();
      final result =
          await TreeSelect<String>('Pick', [
            TreeNode(
              'a',
              'Archive',
              children: [TreeNode('b', 'Report', disabledReason: 'revoked')],
            ),
            TreeNode('c', 'Second root'),
          ]).prompt(
            source: ScriptedInput(
              Stream.value('/help\r/open\r/help\r1\r/up\r/choose\r3\r'),
              output,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'c');
      final text = _visibleLines(output.toString()).join('');
      expect(text, contains('Help: Choosing a node'));
      expect(text, contains('Help: Entering a node reference'));
      expect(text, contains('preorder'));
      expect(text, contains('Archive / Report is unavailable (revoked)'));
      expect(text, contains('/up returns'));
    },
  );

  test('rich order help leads with the moving and idle stages', () async {
    final output = StringBuffer();
    final result =
        await SortableSelect<String>('Order', [
          Choice('a', 'A'),
          Choice('x', 'Anchor', disabledReason: 'protected'),
          Choice('b', 'B'),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('\x14\x1b \x14\x1b\x03'),
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(result, isA<Interrupted<List<String>>>());
    final text = _visibleLines(output.toString()).join('');
    expect(text, contains('Help: Ordering the list'));
    expect(text, contains('Help: Moving A'));
    expect(text, contains('2. Anchor is a locked anchor (protected)'));
    expect(text, contains('Escape reverts'));
  });

  test('linear order help names each requesting stage', () async {
    final output = StringBuffer();
    final result =
        await SortableSelect<String>('Order', [
          Choice('a', 'A'),
          Choice('b', 'B'),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('/help\r/move\r/help\r2\r/help\r1\r/done\r'),
            output,
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<List<String>>).value, ['b', 'a']);
    final text = _visibleLines(output.toString()).join('');
    expect(text, contains('Help: Ordering the list'));
    expect(text, contains('Help: Entering a reference'));
    expect(text, contains('Help: Entering a destination position'));
    expect(text, contains('/done submits'));
  });
  test('tree keeps a background update away from its retained focus', () async {
    final output = StringBuffer();
    final input = StreamController<String>();
    var rowsAfterFeedback = 0;

    final result = await TerminalSession.run(
      (session) async {
        final spinner = Spinner('Tree');
        spinner.start(session: session);
        final pending = TreeSelect<String>('Pick', [
          TreeNode('a', 'A', children: [TreeNode('b', 'B')]),
        ]).prompt(session: session);
        await pumpEventQueue();
        spinner.update('loading branches');
        await pumpEventQueue();
        rowsAfterFeedback = '[focused]'.allMatches(output.toString()).length;
        input.add('\x1b[C\x1b[C\r');
        await input.close();
        final answer = await pending;
        spinner.finish(FeedbackOutcome.completed);
        return answer;
      },
      source: ScriptedInput(input.stream, output, outputProfile: _richProfile),
      mode: PromptMode.rich,
    );

    expect((result as Accepted<String>).value, 'b');
    expect(output.toString(), contains('[status] Tree: loading branches'));
    // The shared feedback write repaints the live prompt instead of leaving the
    // last frame stale, so the focused row is drawn again after the update.
    expect(rowsAfterFeedback, greaterThan(1));
  });

  test(
    'order keeps a background update away from its picked-up item',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      var rowsAfterFeedback = 0;

      final result = await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Order');
          spinner.start(session: session);
          final pending = SortableSelect<String>('Order', [
            Choice('a', 'A'),
            Choice('b', 'B'),
          ]).prompt(session: session);
          await pumpEventQueue();
          input.add(' ');
          await pumpEventQueue();
          spinner.update('saving');
          await pumpEventQueue();
          rowsAfterFeedback = '[moving]'.allMatches(output.toString()).length;
          input.add('\r\r');
          await input.close();
          final answer = await pending;
          spinner.finish(FeedbackOutcome.completed);
          return answer;
        },
        source: ScriptedInput(
          input.stream,
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<List<String>>).value, ['a', 'b']);
      expect(output.toString(), contains('[status] Order: saving'));
      expect(rowsAfterFeedback, greaterThan(1));
    },
  );

  test(
    'tree and order acquire and restore an explicit terminal adapter',
    () async {
      final treeOutput = StringBuffer();
      final treeTerminal = _FakeTerminal(
        Stream.value('/choose\r1\r'),
        treeOutput,
        _richProfile,
      );
      final accepted = await TreeSelect<String>('Pick', [
        TreeNode('a', 'A'),
      ]).prompt(terminal: treeTerminal, mode: PromptMode.linear);
      expect((accepted as Accepted<String>).value, 'a');
      expect(treeTerminal.events, ['acquire', 'restore']);

      final orderOutput = StringBuffer();
      final orderTerminal = _FakeTerminal(
        Stream.value('/cancel\r'),
        orderOutput,
        _richProfile,
      );
      final cancelled = await SortableSelect<String>('Order', [
        Choice('a', 'A'),
      ]).prompt(terminal: orderTerminal, mode: PromptMode.linear);
      expect(cancelled, isA<Cancelled<List<String>>>());
      expect(orderTerminal.events, ['acquire', 'restore']);
    },
  );
}
