import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/state_help_presentation.dart';
import 'package:trelis/src/theme_tree_search_components.dart';
import 'package:trelis/src/testing/compat_api.dart';

import 'support/async_search_fixture.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  glyphs: GlyphSet.unicode,
  geometry: OutputGeometry.fixed(columns: 200, rows: 20),
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

ThemeAutocompletePrompt _autocomplete(
  String input,
  StringSink output, {
  InteractionPreferences interaction = const InteractionPreferences(),
  OutputProfile profile = const OutputProfile(),
}) => ThemeAutocompletePrompt(
  'Name',
  suggestions: (_) => ['Ada', 'Grace'],
  io: TerminalEnvironment.scripted(
    input: Stream.value(input),
    output: output,
    profile: profile,
    supportsRich: profile.supportsRichInteraction,
  ),
  interaction: interaction,
  instructions: InstructionDisplay.hidden,
);

List<Choice<String>> _searchChoices() => [
  Choice('a', 'Apple', disabledReason: 'offline'),
  Choice('b', 'Banana'),
  Choice('c', 'Cherry'),
];

ThemeSearchPrompt<String> _search(
  String input,
  StringSink output, {
  InteractionPreferences interaction = const InteractionPreferences(),
  OutputProfile profile = const OutputProfile(),
  FutureOr<List<Choice<String>>> Function(String)? search,
}) => ThemeSearchPrompt<String>(
  'Fruit',
  _searchChoices(),
  io: TerminalEnvironment.scripted(
    input: Stream.value(input),
    output: output,
    profile: profile,
    supportsRich: profile.supportsRichInteraction,
  ),
  interaction: interaction,
  instructions: InstructionDisplay.hidden,
  search: search,
);

final class _AnswersPerListen extends Stream<String> {
  _AnswersPerListen(this._answers);

  final List<String> _answers;
  var _next = 0;

  @override
  StreamSubscription<String> listen(
    void Function(String event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<String>.value(_answers[_next++]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var turn = 0; turn < 200; turn++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Fixture did not settle.');
}

void main() {
  test('themed search keeps identities, hints and help', () async {
    final searchOutput = StringBuffer();
    final cancelled = await _search(
      '\r1\r/cancel\r',
      searchOutput,
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    ).prompt();
    expect(cancelled, isA<Cancelled<String>>());
    final searchText = searchOutput.toString();
    expect(searchText, contains('[!'));
    expect(searchText, contains('offline'));
    expect(searchText, contains('Enter a query'));
    expect(searchText, contains('/help'));

    final readerOutput = StringBuffer();
    final reader = await _search(
      '/cancel\r',
      readerOutput,
      interaction: const InteractionPreferences(
        mode: PromptMode.linear,
        screenReader: ScreenReaderPreference.on,
      ),
    ).prompt();
    expect(reader, isA<Cancelled<String>>());
    final text = readerOutput.toString();
    expect(text, contains('Fruit, search selection of 3 choices.'));
    expect(
      text.indexOf('Fruit, search selection'),
      lessThan(text.indexOf('Fruit.')),
    );
  });

  test('themed search presents rich and screen-reader results', () async {
    final richSearchOutput = StringBuffer();
    final richSearch = await _search(
      '\r\x1b[B\r',
      richSearchOutput,
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      profile: _richProfile,
    ).prompt();
    expect((richSearch as Accepted<String>).value, 'c');
    expect(richSearchOutput.toString(), contains('Fruit SearchSelect:'));
    expect(richSearchOutput.toString(), contains('→'));

    final readerOutput = StringBuffer();
    final reader = await _search(
      '/cancel\r',
      readerOutput,
      interaction: const InteractionPreferences(
        mode: PromptMode.linear,
        screenReader: ScreenReaderPreference.on,
      ),
    ).prompt();
    expect(reader, isA<Cancelled<String>>());
    expect(
      readerOutput.toString(),
      contains('Fruit, search selection of 3 choices.'),
    );
  });

  test('themed async search rejects failures and recovers without losing the query', () async {
    final requests = PendingRequests<List<Choice<String>>>();
    final input = StreamController<String>();
    final output = StringBuffer();
    final prompt = ThemeSearchPrompt<String>.search(
      'Fruit',
      [Choice('a', 'Apple')],
      io: TerminalEnvironment.scripted(input: input.stream, output: output),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      search: requests.record,
    ).prompt();

    input.add('ap\r');
    await settleUntil(() => requests.requested('ap'));
    expect(output.toString(), contains('Searching.'));
    requests.fail('ap', StateError('offline'));
    await settleUntil(() => output.toString().contains('Search unavailable'));

    input.add('/search\r\x7f\x7fx\r');
    await settleUntil(() => requests.requested('x'));
    requests.complete('x', [Choice('a', 'Apple')]);
    await settleUntil(() => output.toString().contains('1 results for "x"'));
    input.add('1\r');
    expect((await prompt as Accepted<String>).value, 'a');
    await input.close();
  });

  test(
    'themed autocomplete keeps response-local candidates and essential help',
    () async {
      final linearOutput = StringBuffer();
      final linear = await _autocomplete(
        'A\r1\r/submit\r',
        linearOutput,
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      ).prompt();
      expect((linear as Accepted<String>).value, 'Ada');
      expect(linearOutput.toString(), contains('Position 1 of 2'));
      expect(linearOutput.toString(), contains('Enter a query'));
      expect(linearOutput.toString(), contains('/help'));

      final richOutput = StringBuffer();
      final rich = await _autocomplete(
        'a\x1b[B\x1b[B\t\r',
        richOutput,
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        profile: _richProfile,
      ).prompt();
      expect((rich as Accepted<String>).value, 'Grace');
      expect(richOutput.toString(), contains('Position 2 of 2'));
      expect(richOutput.toString(), contains('→'));

      final readerOutput = StringBuffer();
      final reader = await _autocomplete(
        '/cancel\r',
        readerOutput,
        interaction: const InteractionPreferences(
          mode: PromptMode.linear,
          screenReader: ScreenReaderPreference.on,
        ),
      ).prompt();
      expect(reader, isA<Cancelled<String>>());
      final text = readerOutput.toString();
      expect(text, contains('Name autocomplete query.'));
      expect(
        text.indexOf('Name autocomplete query.'),
        lessThan(text.indexOf('Name.')),
      );
    },
  );

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

  test(
    'themed help preserves the query and the short-limit command routes',
    () async {
      final helpOutput = StringBuffer();
      final helped = await _autocomplete(
        'A\r/help\r/edit\r\r/submit\r',
        helpOutput,
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      ).prompt();
      expect((helped as Accepted<String>).value, 'A');
      final helpText = helpOutput.toString();
      expect(helpText, contains('Help: Autocomplete results.'));
      expect(
        helpText.lastIndexOf('Current text: A'),
        greaterThan(helpText.indexOf('Help: Autocomplete results.')),
      );

      final shortOutput = StringBuffer();
      final short = await ThemeAutocompletePrompt(
        'Name',
        suggestions: (_) => ['Ada'],
        io: TerminalEnvironment.scripted(
          input: Stream.value('/help\r/cancel\r'),
          output: shortOutput,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        maxLength: 2,
        instructions: InstructionDisplay.hidden,
      ).prompt();
      expect(short, isA<Cancelled<String>>());
      expect(shortOutput.toString(), contains('Help: Autocomplete query.'));
      expect(shortOutput.toString(), contains('/help'));
    },
  );

  test(
    'themed search keeps escaped or pasted command-shaped text as data',
    () async {
      final escapedOutput = StringBuffer();
      final escaped = await ThemeAutocompletePrompt(
        'Name',
        suggestions: (_) => const [],
        io: TerminalEnvironment.scripted(
          input: Stream.value('\\/help\r/submit\r'),
          output: escapedOutput,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        maxLength: 8,
      ).prompt();
      expect((escaped as Accepted<String>).value, '/help');

      final pasteOutput = StringBuffer();
      final pasted = await ThemeAutocompletePrompt(
        'Name',
        suggestions: (_) => const [],
        io: TerminalEnvironment.scripted(
          input: Stream.value('\x1b[200~\\/help\x1b[201~\r/submit\r'),
          output: pasteOutput,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        maxLength: 8,
      ).prompt();
      expect(pasted, isA<Accepted<String>>());
      expect(pasteOutput.toString(), isNot(contains('Unrecognized command')));

      final multilineOutput = StringBuffer();
      final multiline = await ThemeAutocompletePrompt(
        'Name',
        suggestions: (_) => const [],
        io: TerminalEnvironment.scripted(
          input: Stream.value('\x1b[200~first\nsecond\x1b[201~\r/cancel\r'),
          output: multilineOutput,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        maxLength: 20,
      ).prompt();
      expect(multiline, isA<Cancelled<String>>());
      expect(multilineOutput.toString(), contains('Paste rejected'));
    },
  );

  test('a stale themed search cannot overwrite the current query or write after cancel', () async {
    final requests = PendingRequests<List<Choice<String>>>();
    final input = StreamController<String>();
    final output = StringBuffer();
    final prompt = ThemeSearchPrompt<String>.search(
      'Fruit',
      [Choice('a', 'Apple'), Choice('b', 'Banana')],
      io: TerminalEnvironment.scripted(input: input.stream, output: output),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      search: requests.record,
    ).prompt();

    input.add('a\r');
    await settleUntil(() => requests.requested('a'));
    input.add('/search\r\x7fb\r');
    await settleUntil(() => requests.requested('b'));
    requests.complete('a', [Choice('b', 'Banana')]);
    await settle();
    final staleText = output.toString();
    expect(staleText, contains('results for "b"'));
    expect(
      staleText.lastIndexOf('results for "b"'),
      greaterThan(staleText.lastIndexOf('results for "a"')),
      reason: 'a stale response must not repaint the newer query',
    );

    input.add('/cancel\r');
    expect(await prompt, isA<Cancelled<String>>());
    final beforeLate = output.toString();
    requests.complete('b', [Choice('a', 'Apple')]);
    await settle();
    expect(output.toString(), beforeLate);
    await input.close();
  });

  test('ASCII narrow no-color tree keeps states readable and restrictions focusable', () async {
    final narrow = OutputProfile(
      cursor: CapabilitySupport.supported,
      glyphs: GlyphSet.ascii,
      geometry: OutputGeometry.fixed(columns: 24, rows: 8),
    );
    final output = StringBuffer();
    final prompt = ThemeTreeSelectPrompt<String>(
      'Pick',
      [
        TreeNode(
          'branch',
          'A branch that wraps across the narrow layout',
          children: [TreeNode('child', 'Nested child leaf')],
          selectable: true,
        ),
        TreeNode('blocked', 'Blocked', disabledReason: 'offline'),
        TreeNode(
          'locked',
          'Locked branch',
          children: [TreeNode('leaf', 'Leaf')],
          selectable: false,
        ),
      ],
      io: TerminalEnvironment.scripted(
        input: Stream.value('\x1b[B\r\x1b[B\r\x03'),
        output: output,
        profile: narrow,
        environment: {'NO_COLOR': '1'},
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      glyphs: StateGlyphs.ascii,
    );
    expect(await prompt.prompt(), isA<Interrupted<String>>());
    final text = output.toString();
    expect(text, contains('v'));
    expect(text, contains('>'));
    expect(text, contains('[!]'));
    expect(text, contains('offline'));
    expect(text, contains('[L]'));
    expect(text, contains('not selectable'));
    expect(text, isNot(contains('▾')));
    expect(text, isNot(contains('→')));
    expect(
      text,
      isNot(matches(RegExp(r'\x1b\[[0-9;]*m'))),
      reason: 'NO_COLOR forbids SGR styling',
    );
    final rows = text
        .split('\n')
        .where((line) => RegExp(r'\d+\.\s').hasMatch(line))
        .toList();
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(
        row.length,
        lessThanOrEqualTo(24),
        reason: 'row exceeds the declared width: $row',
      );
    }
  });

  test('themed tree keeps the theme-wide selection style', () async {
    final output = StringBuffer();
    final prompt = ThemeTreeSelectPrompt<String>(
      'Pick',
      [TreeNode('a', 'Alpha', selectable: true)],
      io: TerminalEnvironment.scripted(
        input: Stream.value('/cancel\r'),
        output: output,
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      glyphs: StateGlyphs.ascii,
      selectionStyle: SingleSelectionStyle.squares,
      selectedValue: 'a',
    );
    expect(await prompt.prompt(), isA<Cancelled<String>>());
    expect(output.toString(), contains('[x]'));
  });

  test('all four themed families keep terminal outcomes distinct', () async {
    final linear = const InteractionPreferences(mode: PromptMode.linear);
    final cases = <({String name, Future<Object> Function(String) run})>[
      (
        name: 'tree',
        run: (input) =>
            _tree(input, StringBuffer(), interaction: linear).prompt(),
      ),
      (
        name: 'order',
        run: (input) =>
            _order(input, StringBuffer(), interaction: linear).prompt(),
      ),
      (
        name: 'autocomplete',
        run: (input) =>
            _autocomplete(input, StringBuffer(), interaction: linear).prompt(),
      ),
      (
        name: 'search',
        run: (input) =>
            _search(input, StringBuffer(), interaction: linear).prompt(),
      ),
    ];
    for (final component in cases) {
      expect(
        await component.run('/cancel\r'),
        isA<Cancelled>(),
        reason: '${component.name} cancel',
      );
      expect(
        await component.run('\x03'),
        isA<Interrupted>(),
        reason: '${component.name} interrupt',
      );
      expect(
        await component.run(''),
        isA<InputEnded>(),
        reason: '${component.name} EOF',
      );
      final unavailableOutput = StringBuffer();
      final unavailable = switch (component.name) {
        'tree' => _tree(
          '\r',
          unavailableOutput,
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ).prompt(),
        'order' => _order(
          '\r',
          unavailableOutput,
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ).prompt(),
        'autocomplete' => _autocomplete(
          '\r',
          unavailableOutput,
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ).prompt(),
        _ => _search(
          '\r',
          unavailableOutput,
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ).prompt(),
      };
      expect(
        await unavailable,
        isA<Unavailable>(),
        reason: '${component.name} rich availability',
      );
      expect(unavailableOutput.toString(), isEmpty);
    }
  });

  test(
    'themed prompts reuse initial state and reject concurrent prompts',
    () async {
      var resolutions = 0;
      final reused = ThemeOrderPrompt<String>(
        'Order',
        _choices(),
        io: TerminalEnvironment.scripted(
          input: _AnswersPerListen(['/done\r', '/cancel\r']),
          output: StringBuffer(),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async => resolutions++,
      );
      expect((await reused.prompt() as Accepted<List<String>>).value, [
        'a',
        'b',
        'anchor',
      ]);
      expect(await reused.prompt(), isA<Cancelled<List<String>>>());
      expect(resolutions, 2);

      final input = StreamController<String>();
      final output = StringBuffer();
      var concurrentResolutions = 0;
      final concurrent = ThemeOrderPrompt<String>(
        'Order',
        _choices(),
        io: TerminalEnvironment.scripted(input: input.stream, output: output),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async => concurrentResolutions++,
      );
      final pending = concurrent.prompt();
      await _waitUntil(
        () => output.toString().contains('Order SortableSelect'),
      );
      expect(await concurrent.prompt(), isA<Unavailable<List<String>>>());
      expect(concurrentResolutions, 1);
      input.add('/done\r');
      await input.close();
      expect(await pending, isA<Accepted<List<String>>>());
    },
  );

  test(
    'themed component colors and feedback share one active period',
    () async {
      final output = StringBuffer();
      final palette = ColorThemes.terminalDefault.copyWith(
        foreground: TerminalColor.rgb(9, 8, 7),
        background: TerminalColor.rgb(1, 2, 3),
      );
      var resolutions = 0;
      final prompt = ThemeOrderPrompt<String>(
        'Order',
        _choices(),
        io: TerminalEnvironment.scripted(
          input: Stream.value('/done\r'),
          output: output,
          profile: const OutputProfile(
            glyphs: GlyphSet.ascii,
            colorDepth: ColorDepth.rgb,
          ),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        colors: ComponentColors.palette(palette),
        onResolved: (_) async => resolutions++,
      );
      final feedback = await prompt.startFeedback(
        (handle) => handle.session.presentText('[status] working'),
        stop: () {},
      );
      expect((await prompt.prompt() as Accepted<List<String>>).value, [
        'a',
        'b',
        'anchor',
      ]);
      await feedback.finish();
      expect(resolutions, 1);
      final text = output.toString();
      expect(text, contains('\x1b[38;2;9;8;7;48;2;1;2;3m'));
      expect(
        text.indexOf('[status] working'),
        lessThan(text.indexOf('Order SortableSelect')),
      );
    },
  );
}
