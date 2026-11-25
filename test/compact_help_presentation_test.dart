import 'package:test/test.dart';
import 'package:trelis/src/state_help_presentation.dart';

void main() {
  final linearRoute = helpRoute(
    mode: PresentationMode.linear,
    component: ComponentRoute.standard,
  );

  group('compact hints and placement', () {
    test('hidden instructions keep the primary action and help route', () {
      final hint = compactHint(
        mode: PresentationMode.linear,
        component: ComponentRoute.standard,
        primaryAction: 'Enter submits',
        shortPrimaryAction: 'Enter',
      );
      final presentation = composePromptPresentation(
        mode: PresentationMode.linear,
        prompt: 'Name (Required).',
        essential: 'Name is required.',
        hint: hint,
        instructions: InstructionVisibility.hidden,
      );

      expect(hint.text, 'Enter submits; /help opens help.');
      expect(presentation.lines, [
        'Name (Required).',
        'Enter submits; /help opens help.',
      ]);
      expect(presentation.footer, hint.text);
      expect(presentation.essentialBefore, isNull);
    });

    test(
      'rich hints close the active area and linear hints follow content',
      () {
        final hint = compactHint(
          mode: PresentationMode.rich,
          component: ComponentRoute.standard,
          primaryAction: 'Enter submits',
          shortPrimaryAction: 'Enter',
        );
        final rich = composePromptPresentation(
          mode: PresentationMode.rich,
          prompt: 'Name.',
          essential: 'Name entry.',
          hint: hint,
          decoration: const ['decoration'],
        );
        final linear = composePromptPresentation(
          mode: PresentationMode.linear,
          prompt: 'Name.',
          essential: 'Name entry.',
          hint: hint,
          decoration: const ['decoration'],
        );

        expect(rich.placement, HintPlacement.richBottom);
        expect(rich.lines.last, hint.text);
        expect(linear.placement, HintPlacement.linearAfter);
        expect(linear.lines.last, hint.text);
        expect(
          rich.lines.indexOf('decoration'),
          lessThan(rich.lines.length - 1),
        );
        expect(
          linear.lines.indexOf('decoration'),
          lessThan(linear.lines.length - 1),
        );
      },
    );

    test(
      'screen-reader essential text precedes the prompt in a linear record',
      () {
        final hint = compactHint(
          mode: PresentationMode.screenReader,
          component: ComponentRoute.standard,
          primaryAction: 'Enter submits',
          shortPrimaryAction: 'Enter',
        );
        final presentation = composePromptPresentation(
          mode: PresentationMode.screenReader,
          prompt: 'Name (Required).',
          essential: 'Name is required.',
          hint: hint,
        );

        expect(presentation.placement, HintPlacement.screenReaderBefore);
        expect(presentation.essentialBefore, contains('/help opens help'));
        expect(presentation.footer, isNull);
        expect(sequentialTranscript(presentation, response: 'Ada'), [
          'Name is required. Enter submits; /help opens help.',
          'Name (Required).',
          'Ada',
        ]);
      },
    );

    test(
      'short screens drop decoration and shorten hints before essentials',
      () {
        final hint = compactHint(
          mode: PresentationMode.rich,
          component: ComponentRoute.standard,
          primaryAction: 'Enter submits',
          shortPrimaryAction: 'Enter',
        );
        final decorated = composePromptPresentation(
          mode: PresentationMode.rich,
          prompt: 'Name.',
          essential: 'Name entry.',
          hint: hint,
          decoration: const ['rule', 'badge'],
          optionalLines: const ['Left/Right move'],
          availableRows: 3,
        );
        final tight = composePromptPresentation(
          mode: PresentationMode.rich,
          prompt: 'Name.',
          essential: 'Name entry.',
          hint: hint,
          decoration: const ['rule', 'badge'],
          optionalLines: const ['Left/Right move'],
          availableRows: 2,
        );

        expect(decorated.lines, ['Name.', 'Left/Right move', hint.text]);
        expect(tight.lines, ['Name.', hint.shortText]);
        expect(tight.lines.join(), contains('Enter'));
        expect(tight.lines.join(), contains('F1 help'));
      },
    );
  });

  group('feedback and help safety', () {
    test('feedback has no artificial help unless an action exists', () {
      final passive = composeFeedbackPresentation(
        lines: const ['Indexing 3 files'],
      );
      final actionable = composeFeedbackPresentation(
        lines: const ['Confirm removal'],
        actionHint: 'y confirms; /help opens help.',
      );

      expect(passive.lines, ['Indexing 3 files']);
      expect(passive.hint, isNull);
      expect(passive.lines.join(), isNot(contains('/help')));
      expect(passive.lines.join(), isNot(contains('F1')));
      expect(actionable.hint, 'y confirms; /help opens help.');
    });

    test('detailed help reports preserved draft, focus and caret', () {
      final context = HelpContext(
        component: 'Name',
        primaryAction: 'Enter submits',
        route: linearRoute,
        draft: 'ab',
        caret: 1,
        focusedReference: 2,
        supplementary: const ['Names are shown to collaborators.'],
      );
      final outcome = presentDetailedHelp(
        context: context,
        spaceAvailable: true,
      );

      expect(outcome, isA<HelpShown>());
      final text = (outcome as HelpShown).text;
      expect(text, contains('Draft: ab'));
      expect(text, contains('Caret: 1'));
      expect(text, contains('Focus: 2'));
      expect(text, contains('/help'));
      expect(text, contains('Names are shown to collaborators.'));
      expect(outcome.state, equals(context.snapshot));
      expect(context.draft, 'ab');
      expect(context.caret, 1);
      expect(context.focusedReference, 2);
    });

    test('secret help never discloses the value or its length', () {
      const canary = 'password-canary-73';
      final route = helpRoute(
        mode: PresentationMode.linear,
        component: ComponentRoute.secret,
      );
      final context = HelpContext(
        component: 'Password',
        primaryAction: 'Enter submits',
        route: route,
        draft: canary,
        caret: canary.length,
        secret: true,
      );
      final outcome = presentDetailedHelp(
        context: context,
        spaceAvailable: true,
      );

      expect(route.text, contains('F1 opens help'));
      expect(route.text, contains('hidden values stay hidden'));
      final text = (outcome as HelpShown).text;
      expect(text, isNot(contains(canary)));
      expect(text, isNot(contains('18 graphemes')));
      expect(text, contains('Draft: hidden'));
      expect(text, contains('Caret: hidden'));
      expect(outcome.state, equals(context.snapshot));
    });

    test('key-capture help route cannot steal a captured gesture', () {
      final rich = helpRoute(
        mode: PresentationMode.rich,
        component: ComponentRoute.keyCapture,
      );
      final standard = helpRoute(
        mode: PresentationMode.rich,
        component: ComponentRoute.standard,
      );

      expect(rich.kind, HelpRouteKind.outsideCapture);
      expect(rich.gesture, isNull);
      expect(rich.text, isNot(contains('F1')));
      expect(rich.text, contains('after capture'));
      expect(standard.kind, HelpRouteKind.shortcut);
      expect(standard.gesture, 'F1');
    });

    test('unavailable space and failed rendering retain active help state', () {
      final context = HelpContext(
        component: 'Name',
        primaryAction: 'Enter submits',
        route: linearRoute,
        draft: 'draft',
        caret: 2,
        focusedReference: 1,
      );
      final unavailable = presentDetailedHelp(
        context: context,
        spaceAvailable: false,
      );
      final failed = presentDetailedHelp(
        context: context,
        spaceAvailable: true,
        render: (_) => throw StateError('writer failed'),
      );

      expect(unavailable, isA<HelpUnavailable>());
      expect((unavailable as HelpUnavailable).reason, contains('space'));
      expect(failed, isA<HelpFailed>());
      expect((failed as HelpFailed).reason, contains('writer failed'));
      for (final outcome in [unavailable, failed]) {
        expect(outcome.state, equals(context.snapshot));
        expect(context.draft, 'draft');
        expect(context.caret, 2);
      }
    });
  });
}
