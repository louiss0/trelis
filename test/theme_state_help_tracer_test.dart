import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/state_help_presentation.dart';
import 'package:trelis/src/text_input_tracer.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/src/testing/compat_api.dart';

void main() {
  group('traced compact help', () {
    test(
      'hidden instructions still show the primary action and help route',
      () async {
        final output = StringBuffer();
        final tracer = ThemeTextInputTracer(
          'Name',
          io: TerminalEnvironment.scripted(
            input: Stream.value('Ada\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          instructions: InstructionDisplay.hidden,
        );

        expect((await tracer.prompt() as Accepted<String>).value, 'Ada');
        expect(output.toString(), contains('Enter submits; /help opens help.'));
        expect(output.toString(), isNot(contains('Left/Right move')));
      },
    );

    test(
      'screen-reader essential text arrives before the traced prompt',
      () async {
        final output = StringBuffer();
        final tracer = ThemeTextInputTracer(
          'Name',
          io: TerminalEnvironment.scripted(
            input: Stream.value('Ada\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(
            mode: PromptMode.linear,
            screenReader: ScreenReaderPreference.on,
          ),
        );

        expect((await tracer.prompt() as Accepted<String>).value, 'Ada');
        final text = output.toString();
        expect(
          text.indexOf('Name entry.'),
          lessThan(text.indexOf('Name (Optional).')),
        );
        expect(text, contains('/help opens help.'));
        expect(
          text.indexOf('/help opens help.'),
          lessThan(text.indexOf('Name (Optional).')),
        );
      },
    );

    test('live feedback adds no second artificial help hint', () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      final tracer = ThemeTextInputTracer(
        'Name',
        io: TerminalEnvironment.scripted(
          input: input.stream,
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        instructions: InstructionDisplay.hidden,
      );

      final feedback = await tracer.startFeedback((handle) {
        Text('Indexing 3 files').present(session: handle.session);
      }, stop: () {});
      final pending = tracer.prompt();
      await _waitUntil(() => output.toString().contains('Indexing 3 files'));
      input.add('Ada\r');
      await input.close();
      expect((await pending as Accepted<String>).value, 'Ada');
      await feedback.finish();

      expect(
        RegExp(r'/help opens help').allMatches(output.toString()),
        hasLength(1),
        reason: 'only the prompt advertises a help route',
      );
    });

    test('detailed help preserves the draft, focus and caret', () async {
      final output = StringBuffer();
      final transcript = TextInputTranscript();
      final result = await TextInput('Name').prompt(
        source: ScriptedInput(
          Stream.value('ab\x1b[D\x14\x1bX\r'),
          output,
          outputProfile: _richProfile,
          transcript: transcript,
        ),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<String>).value, 'aXb');
      expect(output.toString(), contains('Ctrl+T opens help.'));
      expect(
        transcript.events.map((event) => event.kind),
        contains(TextInputPresentationEventKind.help),
      );
      expect(transcript.currentView!.text, 'aXb');
      expect(transcript.currentView!.caret, 2);
    });

    test('secret help keeps its value out of the traced transcript', () async {
      const canary = 'password-canary-73';
      final output = StringBuffer();
      final tracer = ThemeTextInputTracer(
        'Password',
        secret: true,
        io: TerminalEnvironment.scripted(
          input: Stream.value('$canary\x14\x1b\rsubmit\r'),
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        instructions: InstructionDisplay.hidden,
      );

      expect((await tracer.prompt() as Accepted<String>).value, canary);
      expect(output.toString(), contains('Ctrl+T opens help'));
      expect(output.toString(), isNot(contains(canary)));
      expect(output.toString(), isNot(contains('18 graphemes')));
    });
  });

  group('representative component routes', () {
    test('key capture keeps help outside the armed gesture', () async {
      final helpRouteForCapture = helpRoute(
        mode: PresentationMode.rich,
        component: ComponentRoute.keyCapture,
      );
      expect(helpRouteForCapture.gesture, isNull);

      final before = StringBuffer();
      await Keypress('Shortcut').prompt(
        source: ScriptedInput(
          Stream.value('\x14\x1bca\r'),
          before,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect(before.toString(), contains('Help:'));

      final armed = StringBuffer();
      final result = await KeyChordInput('Sequence').prompt(
        source: ScriptedInput(
          Stream.value('c\x14\r'),
          armed,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect(result, isA<InputEnded<List<KeyGesture>>>());
      expect(armed.toString(), isNot(contains('Help:')));
      expect(armed.toString(), contains('candidate'));
    });

    test('a restricted choice is inspectable but cannot be accepted', () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      final owner = ThemeSession(
        environment: TerminalEnvironment.scripted(
          input: input.stream,
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );
      final restricted = ChoicePresentation(
        label: 'Admin',
        restriction: ChoiceRestriction.locked,
        reason: 'needs owner role',
      );

      final pending = owner.prompt(
        (handle) => Select<int>('Pick', [
          Choice(1, 'Open'),
          Choice(2, 'Admin', disabledReason: 'needs owner role'),
        ]).prompt(session: handle.session),
      );
      await _waitUntil(() => output.toString().contains('Pick'));
      input.add('2\r');
      await _waitUntil(() => output.toString().contains('unavailable'));
      input.add('\x7f1\r');
      final result = await pending;

      expect(restricted.focusable, isTrue);
      expect(restricted.selectable, isFalse);
      expect(restricted.acceptable, isFalse);
      expect((result as Accepted<int>).value, 1);
      expect(output.toString(), contains('needs owner role'));
    });

    test(
      'a failed help render does not disturb the next active prompt',
      () async {
        final output = StringBuffer();
        final context = HelpContext(
          component: 'Name',
          primaryAction: 'Enter submits',
          route: helpRoute(
            mode: PresentationMode.linear,
            component: ComponentRoute.standard,
          ),
          draft: 'draft',
          caret: 2,
        );
        final failed = presentDetailedHelp(
          context: context,
          spaceAvailable: true,
          render: (_) => throw StateError('help writer failed'),
        );
        expect(failed, isA<HelpFailed>());
        expect(failed.state, equals(context.snapshot));

        final tracer = ThemeTextInputTracer(
          'Name',
          io: TerminalEnvironment.scripted(
            input: Stream.value('Ada\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          instructions: InstructionDisplay.hidden,
        );

        expect((await tracer.prompt() as Accepted<String>).value, 'Ada');
        expect(output.toString(), contains('Enter submits; /help opens help.'));
      },
    );
  });
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition was not met before the test deadline');
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 60, rows: 12),
);
