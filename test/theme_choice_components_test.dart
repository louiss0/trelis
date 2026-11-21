import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
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

  group('themed single-choice family', () {
    test(
      'all five selection styles render through the real component',
      () async {
        for (final style in SingleSelectionStyle.values) {
          final output = StringBuffer();
          final prompt = ThemeSingleChoicePrompt<String>.select(
            'Pick',
            [
              ThemeChoiceOption('a', 'Alpha', selected: true),
              ThemeChoiceOption('b', 'Beta', isDefault: true),
            ],
            io: TerminalEnvironment.scripted(
              input: Stream.value('2\r'),
              output: output,
              profile: const OutputProfile(glyphs: GlyphSet.ascii),
            ),
            interaction: const InteractionPreferences(mode: PromptMode.linear),
            instructions: InstructionDisplay.hidden,
            selectionStyle: style,
            defaultValue: 'b',
          );

          expect(
            await prompt.prompt(),
            isA<Accepted<String>>(),
            reason: '${style.name} accepts a focused identity',
          );
          final text = output.toString().replaceAll('\n', '');
          expect(text, contains(style.asciiSelected), reason: style.name);
          expect(text, contains(style.asciiUnselected), reason: style.name);
          expect(text, contains('/help opens help.'), reason: style.name);
          final selectedLine = output
              .toString()
              .split('\n')
              .firstWhere((line) => line.contains('Alpha'));
          final defaultLine = output
              .toString()
              .split('\n')
              .firstWhere((line) => line.contains('Beta'));
          expect(selectedLine, contains(style.asciiSelected));
          expect(defaultLine, contains(style.asciiUnselected));
          expect(
            defaultLine,
            contains('D'),
            reason: 'default is a separate position',
          );
        }

        final unicodeOutput = StringBuffer();
        final unicode = ThemeSingleChoicePrompt<String>.radio(
          'Pick',
          [
            ThemeChoiceOption('a', 'Alpha', selected: true),
            ThemeChoiceOption('b', 'Beta'),
          ],
          io: TerminalEnvironment.scripted(
            input: Stream.value('2\r'),
            output: unicodeOutput,
            profile: const OutputProfile(glyphs: GlyphSet.unicode),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          selectionStyle: SingleSelectionStyle.triangles,
        );
        await unicode.prompt();
        expect(unicodeOutput.toString(), contains('▲'));
        expect(unicodeOutput.toString(), contains('△'));
      },
    );

    test(
      'locked and unavailable choices stay focusable but cannot be accepted',
      () async {
        final output = StringBuffer();
        final prompt = ThemeSingleChoicePrompt<String>.select(
          'Pick',
          [
            ThemeChoiceOption('a', 'Alpha', lockedReason: 'needs owner role'),
            ThemeChoiceOption('b', 'Beta', unavailableReason: 'offline'),
            ThemeChoiceOption('c', 'Gamma'),
          ],
          io: TerminalEnvironment.scripted(
            input: Stream.value('\r\x1b[B\r\x1b[B\x14\x1b\r'),
            output: output,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          defaultValue: 'a',
        );

        expect((await prompt.prompt() as Accepted<String>).value, 'c');
        final text = output.toString();
        expect(text, contains('[L]'));
        expect(text, contains('needs owner role'));
        expect(text, contains('[!'));
        expect(text, contains('Unavailable: offline'));
        final flat = text.replaceAll('\n', '');
        expect(
          flat,
          contains(
            'Unavailable: needs owner role. Navigate to an enabled choice.',
          ),
        );
        expect(
          flat,
          contains('Unavailable: offline. Navigate to an enabled choice.'),
        );
        final helpIndex = text.indexOf('Help: Select');
        expect(helpIndex, greaterThan(0));
        expect(
          text.lastIndexOf('Gamma'),
          greaterThan(helpIndex),
          reason: 'help dismissal restores the focused row',
        );
      },
    );

    test(
      'linear choice validation, paging and restrictions stay readable',
      () async {
        final output = StringBuffer();
        final prompt = ThemeSingleChoicePrompt<String>.radio(
          'Pick',
          [
            ...List.generate(11, (i) => ThemeChoiceOption('id$i', 'Choice $i')),
            ThemeChoiceOption('last', 'Later', unavailableReason: 'offline'),
          ],
          io: TerminalEnvironment.scripted(
            input: Stream.value('99\r\x7f\x7f12\r\x7f\x7f/next\r11\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          instructions: InstructionDisplay.hidden,
        );

        expect((await prompt.prompt() as Accepted<String>).value, 'id10');
        final text = output.toString();
        expect(text, contains('Enter a valid choice reference.'));
        expect(
          text,
          contains('Unavailable: offline. Choose an enabled reference.'),
        );
        expect(text, contains('Page 2 of 2'));
        expect(text, contains('/next, /previous, /help and /cancel'));
        expect(text, contains('/help opens help.'));
      },
    );

    test(
      'a screen-reader single choice introduces the prompt in sequence',
      () async {
        final output = StringBuffer();
        final prompt = ThemeSingleChoicePrompt<String>.select(
          'Pick',
          [
            ThemeChoiceOption('a', 'Alpha'),
            ThemeChoiceOption('b', 'Beta', lockedReason: 'needs owner role'),
          ],
          io: TerminalEnvironment.scripted(
            input: Stream.value('1\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(
            mode: PromptMode.linear,
            screenReader: ScreenReaderPreference.on,
          ),
        );

        expect((await prompt.prompt() as Accepted<String>).value, 'a');
        final text = output.toString();
        expect(text, contains('Pick, selection of 2 choices.'));
        expect(text, contains('Enter a choice number to accept'));
        expect(text, contains('/help opens help.'));
        expect(
          text.indexOf('Pick, selection of 2 choices.'),
          lessThan(text.indexOf('Pick Select:')),
        );
        expect(text, contains('needs owner role'));
      },
    );

    test(
      'single-choice families retain outcomes, reuse and per-period resolution',
      () async {
        for (final kind in ThemeSingleChoiceComponent.values) {
          expect(
            await _single(kind, '/cancel\r').prompt(),
            isA<Cancelled<String>>(),
            reason: '$kind cancel',
          );
          expect(
            await _single(kind, '\x03').prompt(),
            isA<Interrupted<String>>(),
            reason: '$kind interrupt',
          );
          expect(
            await _single(kind, '').prompt(),
            isA<InputEnded<String>>(),
            reason: '$kind EOF',
          );
          final output = StringBuffer();
          expect(
            await _singleProbe(kind, output).prompt(),
            isA<Unavailable<String>>(),
            reason: '$kind rich availability',
          );
          expect(output.toString(), isEmpty);
        }

        var resolutions = 0;
        final reused = ThemeSingleChoicePrompt<String>.radio(
          'Pick',
          [
            ThemeChoiceOption('a', 'Alpha', selected: true),
            ThemeChoiceOption('b', 'Beta'),
          ],
          io: TerminalEnvironment.scripted(
            input: _AnswersPerListen(['2\r', '1\r']),
            output: StringBuffer(),
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          onResolved: (_) async => resolutions++,
        );

        expect((await reused.prompt() as Accepted<String>).value, 'b');
        expect((await reused.prompt() as Accepted<String>).value, 'a');
        expect(resolutions, 2);
      },
    );
  });

  group('themed multi-selection family', () {
    test(
      'checked, unchecked, focus, default and restrictions stay independent',
      () async {
        final output = StringBuffer();
        final prompt = ThemeMultiSelectPrompt<String>(
          'Features',
          [
            ThemeChoiceOption('a', 'Alpha', selected: true, isDefault: true),
            ThemeChoiceOption('b', 'Beta', selected: true),
            ThemeChoiceOption('c', 'Gamma', lockedReason: 'needs owner role'),
            ThemeChoiceOption('d', 'Delta', unavailableReason: 'offline'),
          ],
          io: TerminalEnvironment.scripted(
            input: Stream.value('/done\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          instructions: InstructionDisplay.hidden,
        );

        expect((await prompt.prompt() as Accepted<List<String>>).value, [
          'a',
          'b',
        ]);
        final text = output.toString();
        expect(
          text,
          contains('x'),
          reason: 'checked rows have their own marker',
        );
        expect(
          text,
          contains('-'),
          reason: 'unchecked rows have their own marker',
        );
        expect(
          text,
          contains('D'),
          reason: 'the default position is independent',
        );
        expect(text, contains('[L]'));
        expect(text, contains('needs owner role'));
        expect(text, contains('[!'));
        expect(text, contains('offline'));
        expect(text, contains('/help opens help.'));
      },
    );

    test(
      'narrow no-color linear output keeps validation and readable states',
      () async {
        final output = StringBuffer();
        final prompt = ThemeMultiSelectPrompt<String>(
          'Features',
          [
            ThemeChoiceOption('a', 'Alpha', selected: true),
            ThemeChoiceOption('b', 'Beta'),
            ThemeChoiceOption('c', 'Charlie', unavailableReason: 'offline'),
            ThemeChoiceOption('d', 'Delta'),
          ],
          io: TerminalEnvironment.scripted(
            input: Stream.value('/done\r2\r3\r4\r/done\r'),
            output: output,
            profile: OutputProfile(
              glyphs: GlyphSet.ascii,
              colorDepth: ColorDepth.rgb,
              geometry: OutputGeometry.fixed(columns: 28, rows: 8),
            ),
            environment: const {'NO_COLOR': '1'},
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          min: 2,
          max: 2,
          instructions: InstructionDisplay.hidden,
        );

        expect((await prompt.prompt() as Accepted<List<String>>).value, [
          'a',
          'b',
        ]);
        final text = output.toString();
        final flat = text.replaceAll('\n', '');
        expect(text, isNot(contains('\x1b[')));
        expect(text.split('\n').every((line) => line.length <= 28), isTrue);
        expect(flat, contains('Minimum 2 selections required.'));
        expect(flat, contains('Unavailable: offline.'));
        expect(flat, contains('Maximum 2 selections.'));
        expect(flat, contains('/help opens help.'));
      },
    );

    test('unicode rows keep distinct glyphs under NO_COLOR', () async {
      final output = StringBuffer();
      final prompt = ThemeMultiSelectPrompt<String>(
        'Features',
        [
          ThemeChoiceOption('a', 'Alpha', selected: true),
          ThemeChoiceOption('b', 'Beta', lockedReason: 'needs owner role'),
        ],
        io: TerminalEnvironment.scripted(
          input: Stream.value('/done\r'),
          output: output,
          profile: OutputProfile(
            glyphs: GlyphSet.unicode,
            colorDepth: ColorDepth.rgb,
            geometry: OutputGeometry.fixed(columns: 28, rows: 8),
          ),
          environment: const {'NO_COLOR': '1'},
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      expect((await prompt.prompt() as Accepted<List<String>>).value, ['a']);
      final text = output.toString();
      expect(text, isNot(contains('\x1b[')));
      expect(text, contains('✓'));
      expect(text, contains('○'));
      expect(text, contains('[L]'));
      expect(text.replaceAll('\n', ''), contains('needs owner role'));
    });

    test(
      'a screen-reader multi-selection announces its own controls first',
      () async {
        final output = StringBuffer();
        final prompt = ThemeMultiSelectPrompt<String>(
          'Features',
          [ThemeChoiceOption('a', 'Alpha'), ThemeChoiceOption('b', 'Beta')],
          io: TerminalEnvironment.scripted(
            input: Stream.value('1\r/done\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(
            mode: PromptMode.linear,
            screenReader: ScreenReaderPreference.on,
          ),
        );

        expect((await prompt.prompt() as Accepted<List<String>>).value, ['a']);
        final text = output.toString();
        expect(text, contains('Features, multiple selection of 2 choices.'));
        expect(text, contains('Enter a number to toggle; /done submits'));
        expect(text, contains('/help opens help.'));
        expect(
          text.indexOf('Features, multiple selection of 2 choices.'),
          lessThan(text.indexOf('Features MultiSelect')),
        );
      },
    );

    test(
      'multi-selection outcomes, reuse and concurrent invocations',
      () async {
        expect(
          await _multi('/cancel\r').prompt(),
          isA<Cancelled<List<String>>>(),
        );
        expect(await _multi('\x03').prompt(), isA<Interrupted<List<String>>>());
        expect(await _multi('').prompt(), isA<InputEnded<List<String>>>());
        final output = StringBuffer();
        final probe = ThemeMultiSelectPrompt<String>(
          'Features',
          [ThemeChoiceOption('a', 'Alpha')],
          io: TerminalEnvironment.scripted(
            input: Stream.value('1\r/done\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
        );
        expect(await probe.prompt(), isA<Unavailable<List<String>>>());
        expect(output.toString(), isEmpty);

        var resolutions = 0;
        final reused = ThemeMultiSelectPrompt<String>(
          'Features',
          [
            ThemeChoiceOption('a', 'Alpha', selected: true),
            ThemeChoiceOption('b', 'Beta'),
          ],
          io: TerminalEnvironment.scripted(
            input: _AnswersPerListen(['2\r/done\r', '/done\r']),
            output: StringBuffer(),
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          onResolved: (_) async => resolutions++,
        );
        expect((await reused.prompt() as Accepted<List<String>>).value, [
          'a',
          'b',
        ]);
        expect((await reused.prompt() as Accepted<List<String>>).value, ['a']);
        expect(resolutions, 2);

        final input = StreamController<String>();
        final sharedOutput = StringBuffer();
        var sharedResolutions = 0;
        final shared = ThemeMultiSelectPrompt<String>(
          'Features',
          [ThemeChoiceOption('a', 'Alpha', selected: true)],
          io: TerminalEnvironment.scripted(
            input: input.stream,
            output: sharedOutput,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          onResolved: (_) async => sharedResolutions++,
        );
        final pending = shared.prompt();
        await _waitUntil(
          () => sharedOutput.toString().contains('Features MultiSelect'),
        );
        expect(await shared.prompt(), isA<Unavailable<List<String>>>());
        expect(sharedResolutions, 1);
        input.add('/done\r');
        await input.close();
        expect(await pending, isA<Accepted<List<String>>>());
      },
    );

    test('component colors and live feedback share the owner period', () async {
      final output = StringBuffer();
      final palette = ColorThemes.terminalDefault.copyWith(
        foreground: TerminalColor.rgb(9, 8, 7),
        background: TerminalColor.rgb(1, 2, 3),
      );
      var resolutions = 0;
      final prompt = ThemeMultiSelectPrompt<String>(
        'Features',
        [
          ThemeChoiceOption('a', 'Alpha', selected: true),
          ThemeChoiceOption('b', 'Beta'),
        ],
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
      expect((await prompt.prompt() as Accepted<List<String>>).value, ['a']);
      await feedback.finish();

      expect(resolutions, 1);
      final text = output.toString();
      expect(text, contains('\x1b[38;2;9;8;7;48;2;1;2;3m'));
      expect(
        text.indexOf('[status] working'),
        lessThan(text.indexOf('Features MultiSelect')),
      );
    });
    test(
      'locked choices refuse acceptance in both linear and rich modes',
      () async {
        final selectOutput = StringBuffer();
        final select = ThemeSingleChoicePrompt<String>.select(
          'Pick',
          [
            ThemeChoiceOption('a', 'Alpha', lockedReason: 'needs owner role'),
            ThemeChoiceOption('b', 'Beta'),
          ],
          io: TerminalEnvironment.scripted(
            input: Stream.value('1\r\x7f2\r'),
            output: selectOutput,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );
        expect((await select.prompt() as Accepted<String>).value, 'b');
        expect(
          selectOutput.toString(),
          contains(
            'Unavailable: needs owner role. Choose an enabled reference.',
          ),
        );

        final multiOutput = StringBuffer();
        final multi = ThemeMultiSelectPrompt<String>(
          'Features',
          [
            ThemeChoiceOption('a', 'Alpha', selected: true),
            ThemeChoiceOption('b', 'Beta', lockedReason: 'needs owner role'),
          ],
          io: TerminalEnvironment.scripted(
            input: Stream.value('\x1b[B \r'),
            output: multiOutput,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
        );
        expect((await multi.prompt() as Accepted<List<String>>).value, ['a']);
        expect(
          multiOutput.toString(),
          contains('Unavailable: needs owner role.'),
        );
      },
    );
  });

  group('narrow and pasted input across the choice families', () {
    test(
      'each family keeps a usable hint and intact lines at 24 columns',
      () async {
        final outputs = <StringBuffer>[];
        final narrow = OutputProfile(
          glyphs: GlyphSet.ascii,
          colorDepth: ColorDepth.rgb,
          geometry: OutputGeometry.fixed(columns: 24, rows: 8),
        );
        StringBuffer output() {
          final buffer = StringBuffer();
          outputs.add(buffer);
          return buffer;
        }

        final boolean = ThemeBooleanPrompt.confirm(
          'Ready?',
          io: TerminalEnvironment.scripted(
            input: Stream.value('y\r'),
            output: output(),
            profile: narrow,
            environment: const {'NO_COLOR': '1'},
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );
        final select = ThemeSingleChoicePrompt<String>.select(
          'Pick',
          [
            ThemeChoiceOption('a', 'Alpha'),
            ThemeChoiceOption('b', 'Beta', selected: true),
          ],
          io: TerminalEnvironment.scripted(
            input: Stream.value('2\r'),
            output: output(),
            profile: narrow,
            environment: const {'NO_COLOR': '1'},
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          selectionStyle: SingleSelectionStyle.triangles,
        );
        final multi = ThemeMultiSelectPrompt<String>(
          'Features',
          [
            ThemeChoiceOption('a', 'Alpha', selected: true),
            ThemeChoiceOption('b', 'Beta'),
          ],
          io: TerminalEnvironment.scripted(
            input: Stream.value('2\r/done\r'),
            output: output(),
            profile: narrow,
            environment: const {'NO_COLOR': '1'},
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );

        expect((await boolean.prompt() as Accepted<bool>).value, isTrue);
        expect((await select.prompt() as Accepted<String>).value, 'b');
        expect((await multi.prompt() as Accepted<List<String>>).value, [
          'a',
          'b',
        ]);
        for (final buffer in outputs) {
          final text = buffer.toString();
          expect(text, isNot(contains('\x1b[')));
          expect(text.split('\n').every((line) => line.length <= 24), isTrue);
          expect(text.replaceAll('\n', ''), contains('/help opens help.'));
        }
        expect(outputs[1].toString(), contains('<^>'));
        expect(outputs[1].toString(), contains('< >'));
        expect(outputs[2].toString(), contains('x'));
        expect(outputs[2].toString(), contains('-'));
      },
    );

    test(
      'identified paste stays literal answer data in linear choice editors',
      () async {
        final selectOutput = StringBuffer();
        final select = ThemeSingleChoicePrompt<String>.select(
          'Pick',
          [ThemeChoiceOption('a', 'Alpha'), ThemeChoiceOption('b', 'Beta')],
          io: TerminalEnvironment.scripted(
            input: Stream.value('\x1b[200~2\x1b[201~\r'),
            output: selectOutput,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );
        expect((await select.prompt() as Accepted<String>).value, 'b');

        final multiOutput = StringBuffer();
        final multi = ThemeMultiSelectPrompt<String>(
          'Features',
          [ThemeChoiceOption('a', 'Alpha'), ThemeChoiceOption('b', 'Beta')],
          io: TerminalEnvironment.scripted(
            input: Stream.value('\x1b[200~1\x1b[201~\r/done\r'),
            output: multiOutput,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
        );
        expect((await multi.prompt() as Accepted<List<String>>).value, ['a']);
        expect(multiOutput.toString(), isNot(contains('Unrecognized command')));
      },
    );
  });
}

ThemeMultiSelectPrompt<String> _multi(String input) =>
    ThemeMultiSelectPrompt<String>(
      'Features',
      [ThemeChoiceOption('a', 'Alpha')],
      io: TerminalEnvironment.scripted(
        input: Stream.value(input),
        output: StringBuffer(),
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

ThemeSingleChoicePrompt<String> _single(
  ThemeSingleChoiceComponent kind,
  String input,
) => _singleWith(
  kind,
  input: input,
  output: StringBuffer(),
  interaction: const InteractionPreferences(mode: PromptMode.linear),
);

ThemeSingleChoicePrompt<String> _singleProbe(
  ThemeSingleChoiceComponent kind,
  StringBuffer output,
) => _singleWith(
  kind,
  input: '1\r',
  output: output,
  interaction: const InteractionPreferences(mode: PromptMode.rich),
);

ThemeSingleChoicePrompt<String> _singleWith(
  ThemeSingleChoiceComponent kind, {
  required String input,
  required StringBuffer output,
  required InteractionPreferences interaction,
}) {
  final io = TerminalEnvironment.scripted(
    input: Stream.value(input),
    output: output,
    profile: const OutputProfile(glyphs: GlyphSet.ascii),
  );
  final choices = [
    ThemeChoiceOption('a', 'Alpha'),
    ThemeChoiceOption('b', 'Beta'),
  ];
  return switch (kind) {
    ThemeSingleChoiceComponent.select => ThemeSingleChoicePrompt.select(
      'Pick',
      choices,
      io: io,
      interaction: interaction,
    ),
    ThemeSingleChoiceComponent.radio => ThemeSingleChoicePrompt.radio(
      'Pick',
      choices,
      io: io,
      interaction: interaction,
    ),
  };
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
