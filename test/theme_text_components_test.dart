import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_text_components.dart';
import 'package:trelis/src/testing/compat_api.dart';

void main() {
  group('theme-owned text family', () {
    test(
      'a rich text prompt renders its resolved palette and compact hint',
      () async {
        final output = StringBuffer();
        final palette = ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(9, 8, 7),
          background: TerminalColor.rgb(1, 2, 3),
        );
        final prompt = ThemeTextPrompt.text(
          'Name',
          io: TerminalEnvironment.scripted(
            input: Stream.value('Ada\r'),
            output: output,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          themeColors: const ColorPreferences(
            background: BackgroundPreference.dark,
          ),
          colors: ComponentColors.palette(palette),
        );

        final result = await prompt.prompt();

        expect((result as Accepted<String>).value, 'Ada');
        expect(
          output.toString(),
          contains('\x1b[38;2;9;8;7;48;2;1;2;3mName (Optional).'),
        );
        expect(output.toString(), contains('Ctrl+T opens help.'));
      },
    );

    test(
      'a screen-reader secret prompt introduces its safe route before entry',
      () async {
        const canary = '/cancel-canary-73';
        final output = StringBuffer();
        final prompt = ThemeTextPrompt.secret(
          'Password',
          io: TerminalEnvironment.scripted(
            input: Stream.value('$canary\x14\x1b\rsubmit\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(
            mode: PromptMode.linear,
            screenReader: ScreenReaderPreference.on,
          ),
        );

        final result = await prompt.prompt();

        expect((result as Accepted<String>).value, canary);
        final text = output.toString();
        expect(text, contains('Hidden entry for Password.'));
        expect(text, contains('Ctrl+T opens help; hidden values stay hidden.'));
        expect(
          text.indexOf('Hidden entry for Password.'),
          lessThan(text.indexOf('Hidden entry; Enter opens actions.')),
        );
        expect(text, isNot(contains(canary)));
      },
    );

    test(
      'a rich secret prompt keeps its value hidden in both routes',
      () async {
        const canary = 'rich-secret-canary-73';
        final output = StringBuffer();
        final prompt = ThemeTextPrompt.secret(
          'Password',
          io: TerminalEnvironment.scripted(
            input: Stream.value('$canary\x14\x1b\rsubmit\r'),
            output: output,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
        );

        expect((await prompt.prompt() as Accepted<String>).value, canary);
        final text = output.toString();
        expect(text, contains('Hidden entry'));
        expect(text.replaceAll('\n', ''), contains('Ctrl+T opens help'));
        expect(text, isNot(contains(canary)));
      },
    );

    test(
      'a rich multiline prompt keeps line editing and its help route',
      () async {
        final output = StringBuffer();
        final prompt = ThemeTextPrompt.multiline(
          'Notes',
          io: TerminalEnvironment.scripted(
            input: Stream.value('line1\rline2\t\r'),
            output: output,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
        );

        final result = await prompt.prompt();

        expect((result as Accepted<String>).value, 'line1\nline2');
        expect(output.toString(), contains('Line 2:'));
        expect(
          output.toString().replaceAll('\n', ''),
          contains('Ctrl+T opens help'),
        );
      },
    );

    test(
      'a linear multiline prompt keeps commands with hidden instructions',
      () async {
        final output = StringBuffer();
        final prompt = ThemeTextPrompt.multiline(
          'Notes',
          io: TerminalEnvironment.scripted(
            input: Stream.value('first\r/done\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          instructions: InstructionDisplay.hidden,
        );

        final result = await prompt.prompt();

        expect((result as Accepted<String>).value, 'first');
        expect(output.toString(), contains('/done'));
        expect(output.toString(), contains('/help opens help.'));
      },
    );

    test(
      'a screen-reader multiline prompt states its primary action first',
      () async {
        final output = StringBuffer();
        final prompt = ThemeTextPrompt.multiline(
          'Notes',
          io: TerminalEnvironment.scripted(
            input: Stream.value('first\r/done\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(
            mode: PromptMode.linear,
            screenReader: ScreenReaderPreference.on,
          ),
        );

        final result = await prompt.prompt();

        expect((result as Accepted<String>).value, 'first');
        final text = output.toString();
        expect(text, contains('Notes lines. Enter adds a line'));
        expect(
          text.indexOf('Notes lines.'),
          lessThan(text.indexOf('Notes (Optional')),
        );
      },
    );

    test('each family keeps its distinct task outcomes', () async {
      for (final kind in ThemeTextComponentKind.values) {
        final cancellation = switch (kind) {
          ThemeTextComponentKind.secret => 'hidden\r/cancel\r',
          _ => '/cancel\r',
        };
        expect(
          await _run(kind, cancellation),
          isA<Cancelled<String>>(),
          reason: '$kind cancellation',
        );
        expect(
          await _run(kind, '\x03'),
          isA<Interrupted<String>>(),
          reason: '$kind interruption',
        );
        expect(
          await _run(kind, ''),
          isA<InputEnded<String>>(),
          reason: '$kind input exhaustion',
        );
        final output = StringBuffer();
        final unavailable = await _make(
          kind,
          input: 'x\r',
          output: output,
          interaction: const InteractionPreferences(mode: PromptMode.rich),
        ).prompt();
        expect(unavailable, isA<Unavailable<String>>());
        expect(output.toString(), isEmpty, reason: '$kind rich availability');
      }
    });

    test('sequential prompts restart from configured initial values', () async {
      var callbacks = 0;
      final text = ThemeTextPrompt.text(
        'Name',
        initialValue: 'seed',
        io: TerminalEnvironment.scripted(
          input: _AnswersPerListen(['x\r', '\r']),
          output: StringBuffer(),
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async => callbacks++,
      );

      expect((await text.prompt() as Accepted<String>).value, 'seedx');
      expect((await text.prompt() as Accepted<String>).value, 'seed');
      expect(callbacks, 2);

      final multiline = ThemeTextPrompt.multiline(
        'Notes',
        initialValue: 'seed',
        io: TerminalEnvironment.scripted(
          input: _AnswersPerListen(['x\r/done\r', '/done\r']),
          output: StringBuffer(),
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      expect((await multiline.prompt() as Accepted<String>).value, 'seed\nx');
      expect((await multiline.prompt() as Accepted<String>).value, 'seed');
    });

    test(
      'a second concurrent prompt is rejected without new resolution',
      () async {
        final output = StringBuffer();
        final input = StreamController<String>();
        var callbacks = 0;
        final prompt = ThemeTextPrompt.multiline(
          'Notes',
          io: TerminalEnvironment.scripted(
            input: input.stream,
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          onResolved: (_) async => callbacks++,
        );

        final pending = prompt.prompt();
        await _waitUntil(() => output.toString().contains('Notes (Optional'));
        final rejected = await prompt.prompt();

        expect(rejected, isA<Unavailable<String>>());
        expect(callbacks, 1);
        expect(
          RegExp(r'Notes \(Optional').allMatches(output.toString()),
          hasLength(1),
        );

        input.add('/done\r');
        await input.close();
        expect(await pending, isA<Accepted<String>>());
      },
    );
  });

  group('editor safety in the themed family', () {
    test('help and cancel survive a smaller submitted-value limit', () async {
      final output = StringBuffer();
      ThemeTextPrompt prompt(String input) => ThemeTextPrompt.text(
        'Name',
        io: TerminalEnvironment.scripted(
          input: Stream.value(input),
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        maxLength: 3,
      );

      final helped = await prompt('/help\r\x7f\x7f\x7f\x7f\x7fAda\r').prompt();
      expect((helped as Accepted<String>).value, 'Ada');
      expect(output.toString(), contains('Help: Enter text to submit'));
      expect(output.toString(), isNot(contains('Insertion rejected')));

      final cancelled = await prompt('/cancel\r').prompt();
      expect(cancelled, isA<Cancelled<String>>());

      final tooLong = await prompt('four\r').prompt();
      expect((tooLong as Accepted<String>).value, 'fou');
      expect(output.toString(), contains('Insertion rejected'));
    });

    test(
      'identified pasted commands stay literal across validation retries',
      () async {
        final output = StringBuffer();
        final prompt = ThemeTextPrompt.text(
          'Name',
          required: true,
          io: TerminalEnvironment.scripted(
            input: Stream.value('\x1b[200~/cancel\x1b[201~\r\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );

        expect((await prompt.prompt() as Accepted<String>).value, '/cancel');
        expect(output.toString(), contains('Required'));
      },
    );

    test(
      'a pasted command is literal and still subject to the value limit',
      () async {
        final output = StringBuffer();
        final prompt = ThemeTextPrompt.text(
          'Name',
          io: TerminalEnvironment.scripted(
            input: Stream.value(
              '\x1b[200~/help\x1b[201~/help\r\x7f\x7f\x7f\x7f\x7fAda\r',
            ),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          maxLength: 3,
        );

        expect((await prompt.prompt() as Accepted<String>).value, 'Ada');
        expect(output.toString(), contains('Insertion rejected'));
        expect(output.toString(), contains('Help: Enter text to submit'));
      },
    );

    test(
      'an escaped literal command is checked against the value limit',
      () async {
        final output = StringBuffer();
        final prompt = ThemeTextPrompt.text(
          'Name',
          io: TerminalEnvironment.scripted(
            input: Stream.value('\\/help\r\x7f\x7f\x7f\x7f\x7f\x7fAda\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          maxLength: 3,
        );

        expect((await prompt.prompt() as Accepted<String>).value, 'Ada');
        expect(output.toString(), contains('Value rejected'));
      },
    );

    test(
      'a rejected multiline paste preserves the single-line draft',
      () async {
        final output = StringBuffer();
        final prompt = ThemeTextPrompt.text(
          'Name',
          initialValue: 'se',
          io: TerminalEnvironment.scripted(
            input: Stream.value('\x1b[200~line1\nline2\x1b[201~ed\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );

        expect((await prompt.prompt() as Accepted<String>).value, 'seed');
        expect(
          output.toString(),
          contains('Paste rejected: single-line printable text only.'),
        );
      },
    );

    test(
      'secret validation never echoes a canary into output or errors',
      () async {
        const canary = 'validator-canary-73';
        final output = StringBuffer();
        final prompt = ThemeTextPrompt.secret(
          'Password',
          validate: (value) => throw StateError('leak: $value'),
          io: TerminalEnvironment.scripted(
            input: Stream.value('$canary\rsubmit\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );

        final result = await prompt.prompt();

        expect(result, isA<Unavailable<String>>());
        expect(output.toString(), isNot(contains(canary)));
        expect(output.toString(), isNot(contains('leak:')));
      },
    );

    test('one shared reader is released after a themed paste prompt', () async {
      var cancellations = 0;
      final input = StreamController<String>(onCancel: () => cancellations++);
      final output = StringBuffer();
      final prompt = ThemeTextPrompt.text(
        'Name',
        io: TerminalEnvironment.scripted(
          input: input.stream,
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      final pending = prompt.prompt();
      await _waitUntil(() => output.toString().contains('Name (Optional'));
      input.add('\x1b[200~/cancel\x1b[201~\r');

      expect((await pending as Accepted<String>).value, '/cancel');
      await Future<void>.delayed(Duration.zero);
      expect(cancellations, 1);
      expect(input.isClosed, isFalse);
      await input.close();
    });

    test(
      'monochrome narrow output still presents draft and status text',
      () async {
        final output = StringBuffer();
        final palette = ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(9, 8, 7),
        );
        final prompt = ThemeTextPrompt.text(
          'Name',
          required: true,
          validate: (value) => value == 'ok' ? null : 'not ok',
          io: TerminalEnvironment.scripted(
            input: Stream.value('\rbad\r\x7f\x7f\x7fok\r'),
            output: output,
            profile: OutputProfile(
              glyphs: GlyphSet.ascii,
              colorDepth: ColorDepth.rgb,
              geometry: OutputGeometry.fixed(columns: 24, rows: 6),
            ),
            environment: const {'NO_COLOR': '1'},
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          colors: ComponentColors.palette(palette),
        );

        final result = await prompt.prompt();

        expect((result as Accepted<String>).value, 'ok');
        final text = output.toString();
        expect(text, isNot(contains('\x1b[')));
        expect(text, contains('Required'));
        expect(text, contains('not ok'));
        expect(text, contains('Current text: ok'));
        final flattened = text.replaceAll('\n', '');
        expect(flattened, contains('Enter submits'));
        expect(flattened, contains('/help opens help.'));
        expect(text.split('\n').every((line) => line.length <= 24), isTrue);
      },
    );

    test('unicode output keeps its primary route under NO_COLOR', () async {
      final output = StringBuffer();
      final prompt = ThemeTextPrompt.text(
        'Name',
        io: TerminalEnvironment.scripted(
          input: Stream.value('ok\r'),
          output: output,
          profile: OutputProfile(
            glyphs: GlyphSet.unicode,
            colorDepth: ColorDepth.rgb,
            geometry: OutputGeometry.fixed(columns: 24, rows: 6),
          ),
          environment: const {'NO_COLOR': '1'},
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      expect((await prompt.prompt() as Accepted<String>).value, 'ok');
      final text = output.toString();
      expect(text, isNot(contains('\x1b[')));
      expect(text.replaceAll('\n', ''), contains('Enter submits'));
      expect(text.replaceAll('\n', ''), contains('/help opens help.'));
    });

    test(
      'detailed help preserves the draft and caret through the owner',
      () async {
        final output = StringBuffer();
        final prompt = ThemeTextPrompt.text(
          'Name',
          io: TerminalEnvironment.scripted(
            input: Stream.value('ab\x1b[D\x14\x1bX\r'),
            output: output,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
        );

        expect((await prompt.prompt() as Accepted<String>).value, 'aXb');
        expect(output.toString(), contains('Help:'));
      },
    );
  });
}

Future<PromptResult<String>> _run(ThemeTextComponentKind kind, String input) =>
    _make(
      kind,
      input: input,
      output: StringBuffer(),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    ).prompt();

ThemeTextPrompt _make(
  ThemeTextComponentKind kind, {
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
    ThemeTextComponentKind.text => ThemeTextPrompt.text(
      'Name',
      io: io,
      interaction: interaction,
    ),
    ThemeTextComponentKind.secret => ThemeTextPrompt.secret(
      'Password',
      io: io,
      interaction: interaction,
    ),
    ThemeTextComponentKind.multiline => ThemeTextPrompt.multiline(
      'Notes',
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
  geometry: OutputGeometry.fixed(columns: 60, rows: 12),
);
