import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/state_help_presentation.dart';
import 'package:trelis/src/theme_choice_components.dart';
import 'package:trelis/trelis.dart';

void main() {
  test(
    'a themed select renders focus, selection, default and restrictions apart',
    () async {
      final output = StringBuffer();
      final prompt = ThemeSingleChoicePrompt<String>.select(
        'Pick',
        [
          ThemeChoiceOption('a', 'Alpha', lockedReason: 'needs owner role'),
          ThemeChoiceOption('b', 'Beta', selected: true),
          ThemeChoiceOption('c', 'Gamma', unavailableReason: 'offline'),
        ],
        io: TerminalEnvironment.scripted(
          input: Stream.value('\x1b[B\r'),
          output: output,
          profile: _richProfile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        defaultValue: 'a',
        selectionStyle: SingleSelectionStyle.squares,
      );

      final result = await prompt.prompt();

      expect((result as Accepted<String>).value, 'b');
      final text = output.toString();
      expect(
        text,
        contains('■'),
        reason: 'selected state uses the configured style',
      );
      expect(
        text,
        contains('□'),
        reason: 'unselected rows have their own glyph',
      );
      expect(text, contains('→'), reason: 'focus is independent of selection');
      expect(
        text,
        contains('★'),
        reason: 'default is independent of selection',
      );
      expect(
        text,
        contains('[L]'),
        reason: 'locked choices carry a visible marker',
      );
      expect(text, contains('needs owner role'));
      expect(
        text,
        contains('[!]'),
        reason: 'unavailable choices carry a visible marker',
      );
      expect(text, contains('offline'));
    },
  );

  group('themed boolean family', () {
    test(
      'a rich confirm keeps its draft, default and bottom guidance',
      () async {
        final output = StringBuffer();
        final prompt = ThemeBooleanPrompt.confirm(
          'Continue?',
          io: TerminalEnvironment.scripted(
            input: Stream.value('n y\r'),
            output: output,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          instructions: InstructionDisplay.hidden,
        );

        expect((await prompt.prompt() as Accepted<bool>).value, isTrue);
        final text = output.toString();
        expect(text, contains('Default: No. Draft: No.'));
        expect(text, contains('Draft: Yes.'));
        expect(text, contains('Accepted: Yes.'));
        final flat = text.replaceAll('\n', '');
        expect(flat, contains('Y/N changes the draft; Enter submits'));
        expect(flat, contains('Ctrl+T opens help'));
        expect(
          text.indexOf('Ctrl+T opens help'),
          greaterThan(text.indexOf('Continue?')),
        );
      },
    );

    test(
      'a screen-reader checkbox announces its action before the prompt',
      () async {
        final output = StringBuffer();
        final prompt = ThemeBooleanPrompt.checkbox(
          'Email me',
          io: TerminalEnvironment.scripted(
            input: Stream.value('y\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(
            mode: PromptMode.linear,
            screenReader: ScreenReaderPreference.on,
          ),
          instructions: InstructionDisplay.hidden,
        );

        expect((await prompt.prompt() as Accepted<bool>).value, isTrue);
        final text = output.toString();
        expect(text, contains('Email me, checkbox question.'));
        expect(
          text,
          contains('Enter yes or no; an empty line accepts the default'),
        );
        expect(text, contains('/help opens help.'));
        expect(
          text.indexOf('Email me, checkbox question.'),
          lessThan(text.indexOf('Default: unchecked')),
        );
      },
    );

    test(
      'boolean families retain their outcomes and reuse their initial value',
      () async {
        final kinds = [
          ThemeBooleanComponent.confirm,
          ThemeBooleanComponent.checkbox,
          ThemeBooleanComponent.toggle,
        ];
        for (final kind in kinds) {
          expect(
            await _boolean(kind, '/cancel\r').prompt(),
            isA<Cancelled<bool>>(),
            reason: '$kind cancel',
          );
          expect(
            await _boolean(kind, '\x03').prompt(),
            isA<Interrupted<bool>>(),
            reason: '$kind interrupt',
          );
          expect(
            await _boolean(kind, '').prompt(),
            isA<InputEnded<bool>>(),
            reason: '$kind EOF',
          );
          final output = StringBuffer();
          final prompt = _booleanProbe(kind, output);
          expect(await prompt.prompt(), isA<Unavailable<bool>>());
          expect(output.toString(), isEmpty, reason: '$kind rich availability');
        }

        var resolutions = 0;
        final reused = ThemeBooleanPrompt.toggle(
          'Flag',
          initialValue: true,
          io: TerminalEnvironment.scripted(
            input: _AnswersPerListen(['\r', 'n\r']),
            output: StringBuffer(),
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          onResolved: (_) async => resolutions++,
        );

        expect((await reused.prompt() as Accepted<bool>).value, isTrue);
        expect((await reused.prompt() as Accepted<bool>).value, isFalse);
        expect(resolutions, 2);
      },
    );

    test(
      'a concurrent boolean prompt is rejected without a second period',
      () async {
        final input = StreamController<String>();
        final output = StringBuffer();
        var resolutions = 0;
        final prompt = ThemeBooleanPrompt.toggle(
          'Flag',
          io: TerminalEnvironment.scripted(
            input: input.stream,
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          onResolved: (_) async => resolutions++,
        );

        final pending = prompt.prompt();
        await _waitUntil(() => output.toString().contains('Flag.'));
        expect(await prompt.prompt(), isA<Unavailable<bool>>());
        expect(resolutions, 1);

        input.add('\r');
        await input.close();
        expect(await pending, isA<Accepted<bool>>());
      },
    );
  });
}

ThemeBooleanPrompt _boolean(ThemeBooleanComponent kind, String input) =>
    _booleanWith(
      kind,
      input: input,
      output: StringBuffer(),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

ThemeBooleanPrompt _booleanProbe(
  ThemeBooleanComponent kind,
  StringBuffer output,
) => _booleanWith(
  kind,
  input: 'y\r',
  output: output,
  interaction: const InteractionPreferences(mode: PromptMode.rich),
);

ThemeBooleanPrompt _booleanWith(
  ThemeBooleanComponent kind, {
  required String input,
  required StringBuffer output,
  required InteractionPreferences interaction,
}) {
  final io = TerminalEnvironment.scripted(
    input: Stream.value(input),
    output: output,
    profile: const OutputProfile(glyphs: GlyphSet.ascii),
  );
  return switch (kind) {
    ThemeBooleanComponent.confirm => ThemeBooleanPrompt.confirm(
      'Ready?',
      io: io,
      interaction: interaction,
    ),
    ThemeBooleanComponent.checkbox => ThemeBooleanPrompt.checkbox(
      'Ready?',
      io: io,
      interaction: interaction,
    ),
    ThemeBooleanComponent.toggle => ThemeBooleanPrompt.toggle(
      'Ready?',
      io: io,
      interaction: interaction,
    ),
  };
}

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
  }) {
    final answer = _answers[_next++];
    return Stream<String>.value(answer).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
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
  geometry: OutputGeometry.fixed(columns: 60, rows: 14),
);
