import 'dart:async';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 40, rows: 8),
);

final _narrowProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 24, rows: 6),
);

final class _ResizeObserver implements TerminalResizeObserver {
  _ResizeObserver(this.notifications, this._dimensions);

  @override
  final Stream<void> notifications;
  final ({int columns, int rows})? Function() _dimensions;

  @override
  ({int columns, int rows})? readDimensions() => _dimensions();

  @override
  Duration get fallbackInterval => const Duration(days: 1);
}

final class _FakeTerminal implements TerminalIo, TerminalIoOutputProfile {
  _FakeTerminal(
    this.input,
    this.output,
    this.outputProfile, {
    this.environment = const {},
  });

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  @override
  final OutputProfile outputProfile;

  @override
  final Map<String, String?> environment;

  final List<String> events = [];

  @override
  bool get supportsRich => false;

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}

final _colorProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  colorDepth: ColorDepth.indexed256,
  geometry: OutputGeometry.fixed(columns: 80, rows: 20),
);

/// A distinguishable palette so each semantic role is recognisable in output.
final _palette = ColorThemes.terminalDefault.copyWith(
  foreground: TerminalColor.indexed(12),
  muted: TerminalColor.indexed(8),
  accent: TerminalColor.indexed(10),
  success: TerminalColor.indexed(2),
  warning: TerminalColor.indexed(9),
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
  test('tree repaints at a new idle geometry and keeps its focus', () async {
    final keys = StreamController<String>();
    var watcherCancelled = false;
    final resized = StreamController<void>.broadcast(
      onCancel: () => watcherCancelled = true,
    );
    final output = StringBuffer();
    final observer = _ResizeObserver(
      resized.stream,
      () => (columns: 30, rows: 8),
    );

    final pending =
        TreeSelect<String>('Pick', [
          TreeNode('a', 'A', children: [TreeNode('b', 'B')]),
        ]).prompt(
          source: ScriptedInput(
            keys.stream,
            output,
            outputProfile: _richProfile,
            resizeObserver: observer,
          ),
          mode: PromptMode.rich,
        );
    await pumpEventQueue();
    final beforeResize = output.length;

    resized.add(null);
    await pumpEventQueue();

    // A resize is a repaint only: the expansion and focus survive and the rows
    // are drawn again inside the observed width.
    expect(output.length, greaterThan(beforeResize));
    final tail = _componentLines(output.toString().substring(beforeResize))
        .toList();
    expect(tail.join(''), contains('[focused]'));
    for (final line in tail) {
      expect(
        line.length,
        lessThanOrEqualTo(30),
        reason: 'resized line exceeds the observed width: "$line"',
      );
    }

    // A later help request is wrapped at the observed width too, because the
    // effective profile follows the resize.
    keys.add('\x14');
    await pumpEventQueue();
    final duringHelp = output.length;
    for (final line in _componentLines(
      output.toString().substring(beforeResize),
    )) {
      expect(
        line.length,
        lessThanOrEqualTo(30),
        reason: 'post-resize line exceeds the observed width: "$line"',
      );
    }

    // Help owns the screen until it is dismissed, so a resize does not repaint
    // underneath it.
    resized.add(null);
    await pumpEventQueue();
    expect(output.length, duringHelp);
    keys.add('\x1bx');

    keys.add('\x1b[C\x1b[C\r');
    expect(((await pending) as Accepted<String>).value, 'b');
    await keys.close();
    await resized.close();
    expect(watcherCancelled, isTrue);
  });

  test('order repaints at a new idle geometry and keeps its pick-up', () async {
    final keys = StreamController<String>();
    var watcherCancelled = false;
    final resized = StreamController<void>.broadcast(
      onCancel: () => watcherCancelled = true,
    );
    final output = StringBuffer();
    final observer = _ResizeObserver(
      resized.stream,
      () => (columns: 30, rows: 8),
    );

    final pending =
        SortableSelect<String>('Order', [
          Choice('a', 'A'),
          Choice('b', 'B'),
        ]).prompt(
          source: ScriptedInput(
            keys.stream,
            output,
            outputProfile: _richProfile,
            resizeObserver: observer,
          ),
          mode: PromptMode.rich,
        );
    await pumpEventQueue();
    keys.add(' ');
    await pumpEventQueue();

    final beforeResize = output.length;
    resized.add(null);
    await pumpEventQueue();

    final tail = _componentLines(output.toString().substring(beforeResize))
        .toList();
    expect(tail.join(''), contains('[moving]'));
    for (final line in tail) {
      expect(
        line.length,
        lessThanOrEqualTo(30),
        reason: 'resized line exceeds the observed width: "$line"',
      );
    }

    keys.add('\r\r');
    expect(((await pending) as Accepted<List<String>>).value, ['a', 'b']);
    await keys.close();
    await resized.close();
    expect(watcherCancelled, isTrue);
  });
  test('tree uses its palette for rows, reasons and acceptance', () async {
    final output = StringBuffer();
    final result =
        await TreeSelect<String>('Pick', [
          TreeNode('a', 'A', disabledReason: 'offline'),
          TreeNode('b', 'B'),
        ], colors: _palette).prompt(
          source: ScriptedInput(
            Stream.value('/choose\r1\r/choose\r2\r'),
            output,
            outputProfile: _colorProfile,
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'b');
    final text = output.toString();
    // Warning refusal, success acceptance and the component foreground are
    // distinct semantic roles rather than one undifferentiated span.
    expect(text, contains('\x1b[38;5;9;'));
    expect(text, contains('\x1b[38;5;2;'));
    expect(text, contains('\x1b[38;5;12;'));

    final terminal = _FakeTerminal(
      Stream.value('/choose\r1\r/choose\r2\r'),
      StringBuffer(),
      _colorProfile,
      environment: {'NO_COLOR': '1'},
    );
    final suppressed = await TreeSelect<String>('Pick', [
      TreeNode('a', 'A', disabledReason: 'offline'),
      TreeNode('b', 'B'),
    ], colors: _palette).prompt(terminal: terminal, mode: PromptMode.linear);
    expect((suppressed as Accepted<String>).value, 'b');
    expect(terminal.output.toString(), isNot(contains('\x1b[38;5;9;')));
    expect(terminal.output.toString(), contains('unavailable: offline'));
  });

  test('order uses its palette for movement, locks and acceptance', () async {
    final output = StringBuffer();
    final result =
        await SortableSelect<String>('Order', [
          Choice('a', 'A'),
          Choice('x', 'Anchor', disabledReason: 'fixed'),
        ], colors: _palette).prompt(
          source: ScriptedInput(
            Stream.value(' \x1b[B \r\r'),
            output,
            outputProfile: _colorProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['a', 'x']);
    final text = output.toString();
    expect(text, contains('\x1b[38;5;10;')); // focused accent
    expect(text, contains('\x1b[38;5;9;')); // lock refusal warning
    expect(text, contains('\x1b[38;5;2;')); // acceptance success
  });

  test('incomplete tree and order actions never accept an answer', () async {
    final tree = TreeSelect<String>('Pick', [
      TreeNode('a', 'A', children: [TreeNode('b', 'B')]),
    ]);
    // Expansion without Enter and an unfinished rich interaction end with input.
    expect(
      await tree.prompt(
        source: ScriptedInput(
          Stream.value('\x1b[C\x1b[C'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<InputEnded<String>>(),
    );
    // A chosen command whose reference never arrives is not an answer either.
    expect(
      await tree.prompt(
        source: ScriptedInput(Stream.value('/choose\r'), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<InputEnded<String>>(),
    );

    final order = SortableSelect<String>('Order', [
      Choice('a', 'A'),
      Choice('b', 'B'),
    ]);
    // A picked-up item that is never dropped is not a submitted order.
    expect(
      await order.prompt(
        source: ScriptedInput(
          Stream.value(' \x1b[B'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<InputEnded<List<String>>>(),
    );
    expect(
      await order.prompt(
        source: ScriptedInput(Stream.value('/move\r2\r'), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<InputEnded<List<String>>>(),
    );
  });

  test(
    'a failed shared writer ends a tree prompt with the original failure',
    () async {
      final failure = StateError('shared writer failed');
      final output = _ThrowingSink(failure);
      final input = StreamController<String>();
      late TerminalSession closed;

      await expectLater(
        TerminalSession.run(
          (session) {
            closed = session;
            return TreeSelect<String>('Pick', [
              TreeNode('a', 'A'),
            ]).prompt(session: session);
          },
          source: ScriptedInput(
            input.stream,
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        ),
        throwsA(same(failure)),
      );
      // A retired scope cannot revive a registration after the writer failed.
      expect(() => Spinner('Late').start(session: closed), throwsStateError);
      expect(output.text, isNot(contains('Accepted')));
      await input.close();
    },
  );

  test(
    'a failed shared writer ends an order prompt with the original failure',
    () async {
      final failure = StateError('shared writer failed');
      final output = _ThrowingSink(failure);
      final input = StreamController<String>();

      await expectLater(
        TerminalSession.run(
          (session) => SortableSelect<String>('Order', [
            Choice('a', 'A'),
          ]).prompt(session: session),
          source: ScriptedInput(
            input.stream,
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        ),
        throwsA(same(failure)),
      );
      expect(output.text, isNot(contains('Accepted')));
      await input.close();
    },
  );

  test('rich tree and order paint transcript rows without owning the caret', () async {
    // A monochrome rich profile: the components compose rows and notices only.
    // No cursor addressing, erase-line, alternate-screen or caret sequence is
    // emitted, so the shared editor keeps caret and viewport ownership in the
    // modes that have one.
    final treeOutput = StringBuffer();
    final tree =
        await TreeSelect<String>('Pick', [
          TreeNode('a', 'A', children: [TreeNode('b', 'B')]),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[C\x1b[C\r'),
            treeOutput,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((tree as Accepted<String>).value, 'b');
    expect(treeOutput.toString(), isNot(contains('\x1b')));

    final orderOutput = StringBuffer();
    final order =
        await SortableSelect<String>('Order', [
          Choice('a', 'A'),
          Choice('b', 'B'),
        ]).prompt(
          source: ScriptedInput(
            Stream.value(' \x1b[B\r\r'),
            orderOutput,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((order as Accepted<List<String>>).value, ['b', 'a']);
    expect(orderOutput.toString(), isNot(contains('\x1b')));
  });

  test('tree keeps every terminal outcome distinct', () async {
    final tree = TreeSelect<String>('Pick', [TreeNode('a', 'A')]);
    expect(
      await tree.prompt(
        source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<Cancelled<String>>(),
    );
    expect(
      await tree.prompt(
        source: ScriptedInput(
          Stream.value('\x1bx'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<Cancelled<String>>(),
    );
    expect(
      await tree.prompt(
        source: ScriptedInput(Stream.value('\x03'), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<Interrupted<String>>(),
    );
    expect(
      await tree.prompt(
        source: ScriptedInput(
          Stream.value('\x03'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<Interrupted<String>>(),
    );
    expect(
      await tree.prompt(
        source: ScriptedInput(Stream.value(''), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<InputEnded<String>>(),
    );
    expect(
      await tree.prompt(
        source: ScriptedInput(
          Stream.value(''),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<InputEnded<String>>(),
    );
    expect(
      await tree.prompt(source: SuppliedAnswer('2')),
      isA<Unavailable<String>>(),
    );
    expect(
      await TreeSelect<String>('Pick', [TreeNode('a', 'A')]).prompt(
        source: ScriptedInput(Stream.value(''), StringBuffer()),
        mode: PromptMode.rich,
      ),
      isA<Unavailable<String>>(),
    );
  });

  test('order keeps every terminal outcome distinct', () async {
    final order = SortableSelect<String>('Order', [
      Choice('a', 'A'),
      Choice('b', 'B'),
    ]);
    expect(
      await order.prompt(
        source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<Cancelled<List<String>>>(),
    );
    expect(
      await order.prompt(
        source: ScriptedInput(
          Stream.value('\x1bx'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<Cancelled<List<String>>>(),
    );
    expect(
      await order.prompt(
        source: ScriptedInput(Stream.value('\x03'), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<Interrupted<List<String>>>(),
    );
    expect(
      await order.prompt(
        source: ScriptedInput(
          Stream.value('\x03'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<Interrupted<List<String>>>(),
    );
    expect(
      await order.prompt(
        source: ScriptedInput(Stream.value(''), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<InputEnded<List<String>>>(),
    );
    expect(
      await order.prompt(
        source: ScriptedInput(
          Stream.value(''),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<InputEnded<List<String>>>(),
    );
    expect(
      await order.prompt(source: SuppliedAnswer('1,3')),
      isA<Unavailable<List<String>>>(),
    );
    expect(
      await SortableSelect<String>('Order', [Choice('a', 'A')]).prompt(
        source: ScriptedInput(Stream.value(''), StringBuffer()),
        mode: PromptMode.rich,
      ),
      isA<Unavailable<List<String>>>(),
    );
  });
}

final class _ThrowingSink implements StringSink {
  _ThrowingSink(this.error);

  final Object error;
  final StringBuffer _recording = StringBuffer();

  String get text => _recording.toString();

  Never _throw(Object? value) {
    _recording.write(value);
    throw error;
  }

  @override
  void write(Object? object) => _throw(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _throw(objects.join(separator));

  @override
  void writeCharCode(int charCode) => _throw(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => _throw('$object\n');
}
