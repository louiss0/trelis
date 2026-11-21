import 'dart:async';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

final class _CountingAdapter implements TerminalIo, TerminalOwnershipIdentity {
  _CountingAdapter(this._sink);

  final StringSink _sink;
  int acquired = 0;
  int restored = 0;

  @override
  Stream<String> get input => const Stream<String>.empty();

  @override
  StringSink get output => _sink;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const {};

  @override
  Object get ownershipIdentity => this;

  @override
  TerminalLease acquire() {
    acquired++;
    return TerminalLease(() => restored++);
  }
}

/// Public-surface tracer for the coordinated theme-instance cutover.
///
/// This file imports only the public barrel. It deliberately avoids the
/// internal component construction seam used by component-level tests.
void main() {
  group('public theme instances', () {
    test('a theme instance creates reusable parameterless prompts', () async {
      final output = StringBuffer();
      final theme = RailTheme(
        io: TerminalEnvironment.scripted(
          input: Stream.fromIterable(['Ada\n']),
          output: output,
        ),
      );
      final prompt = theme.textInput('Name', initialValue: 'seed');
      expect(prompt, isA<ThemePrompt<String>>());
      expect(prompt.structure, PromptStructure.rail);

      expect(await prompt.prompt(), isA<Accepted<String>>());
      expect(await prompt.prompt(), isA<Accepted<String>>());
      final transcript = output.toString();
      // Both invocations restart from the configured initial value rather
      // than retaining the answer from the previous run.
      expect('| Current text: seed\n'.allMatches(transcript), hasLength(2));
    });

    test('all themes construct through instance methods', () {
      final io = TerminalEnvironment.scripted(
        input: const Stream<String>.empty(),
        output: StringBuffer(),
      );
      final themes = <StructuralTheme>[
        PlainTheme(io: io),
        RailTheme(io: io),
        AsciiTheme(io: io),
        DoubleTheme(io: io),
        ChevronTheme(io: io),
        ColonTheme(io: io),
        BoxTheme(io: io),
        BracketTheme(io: io),
        BlockTheme(io: io),
        BranchTheme(io: io),
        RoundTheme(io: io),
        LineTheme(io: io),
        MinimalTheme(io: io),
        FormTheme(io: io),
        LedgerTheme(io: io),
      ];
      expect(themes, hasLength(15));
      for (final theme in themes) {
        expect(theme.textInput('Name'), isA<ThemePrompt<String>>());
        expect(
          theme.select<int>('Choice', [Choice(1, 'One')]),
          isA<ThemePrompt<int>>(),
        );
        expect(theme.text('Done'), isA<ThemeFeedback>());
      }
    });

    test(
      'EOF returns InputEnded and concurrent prompts are rejected',
      () async {
        final theme = PlainTheme(
          io: TerminalEnvironment.scripted(
            input: const Stream<String>.empty(),
            output: StringBuffer(),
          ),
        );
        final first = theme.textInput('Name').prompt();
        expect(await first, isA<InputEnded<String>>());
        final second = theme.textInput('Name');
        final runner = second.prompt();
        final competing = second.prompt();
        expect(await runner, isA<InputEnded<String>>());
        expect(await competing, isA<Unavailable<String>>());
      },
    );

    test('a live feedback component can outlive its prompt', () async {
      final output = StringBuffer();
      final theme = PlainTheme(
        io: TerminalEnvironment.scripted(
          input: Stream.fromIterable(['Ada\n']),
          output: output,
          ownershipIdentity: const Object(),
        ),
      );
      final feedback = theme.spinner('Working');
      final control = await feedback.start();
      expect(await theme.textInput('Name').prompt(), isA<Accepted<String>>());
      expect(output.toString(), contains('Working'));
      await control.finish(FeedbackOutcome.completed);
      expect(await theme.textInput('After').prompt(), isA<Accepted<String>>());
    });

    test(
      'terminal resources are acquired and restored per active period',
      () async {
        final sink = StringBuffer();
        final adapter = _CountingAdapter(sink);
        final theme = PlainTheme(
          io: TerminalEnvironment.custom(adapter: adapter),
        );
        expect(
          await theme.textInput('First').prompt(),
          isA<InputEnded<String>>(),
        );
        final first = adapter.acquired;
        expect(first, greaterThan(0));
        expect(adapter.restored, first);
        expect(
          await theme.textInput('Second').prompt(),
          isA<InputEnded<String>>(),
        );
        expect(adapter.acquired, greaterThan(first));
        expect(adapter.restored, adapter.acquired);
      },
    );

    test('the resolution callback runs once per active period', () async {
      final resolutions = <ResolvedInteraction>[];
      final io = TerminalEnvironment.scripted(
        input: const Stream<String>.empty(),
        output: StringBuffer(),
        ownershipIdentity: const Object(),
      );
      final theme = PlainTheme(io: io, onResolved: resolutions.add);
      final feedback = await theme.spinner('Working').start();
      expect(resolutions, hasLength(1));
      expect(await theme.textInput('Name').prompt(), isA<InputEnded<String>>());
      expect(resolutions, hasLength(1));
      await feedback.finish(FeedbackOutcome.completed);
      expect(
        await theme.textInput('Again').prompt(),
        isA<InputEnded<String>>(),
      );
      expect(resolutions, hasLength(2));
    });
  });
}
