import 'dart:async';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

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
  });
}
