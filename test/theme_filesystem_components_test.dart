import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_filesystem_components.dart';
import 'package:trelis/src/testing/compat_api.dart';

void main() {
  group('theme-owned filesystem family', () {
    test(
      'a rich path prompt uses the resolved palette and help route',
      () async {
        final output = StringBuffer();
        final palette = ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(9, 8, 7),
          background: TerminalColor.rgb(1, 2, 3),
        );
        final prompt = ThemeFilesystemPrompt.path(
          'Destination',
          io: TerminalEnvironment.scripted(
            input: Stream.value('draft\r\r'),
            output: output,
            profile: _richProfile,
            supportsRich: true,
          ),
          interaction: const InteractionPreferences(mode: PromptMode.rich),
          themeColors: const ColorPreferences(
            background: BackgroundPreference.dark,
          ),
          colors: ComponentColors.palette(palette),
          allowNonexistent: true,
        );

        final result = await prompt.prompt();

        expect((result as Accepted<String>).value, endsWith('draft'));
        expect(output.toString(), contains('\x1b[38;2;9;8;7;48;2;1;2;3m'));
        expect(_displaySafe(output.toString()), contains('F1 opens help;'));
      },
    );

    test(
      'a linear file browser filters by type and keeps the listing',
      () async {
        final root = await Directory.systemTemp.createTemp('theme-picker-');
        addTearDown(() => root.delete(recursive: true));
        await Directory(path.join(root.path, 'a_dir')).create();
        final file = await File(path.join(root.path, 'b_file.txt'))
            .writeAsString('data');
        final output = StringBuffer();
        final prompt = ThemeFilesystemPrompt.filePicker(
          'File',
          io: TerminalEnvironment.scripted(
            input: Stream.value('choose 1\rchoose 2\r\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          base: root.path,
        );

        expect((await prompt.prompt() as Accepted<String>).value, file.path);
        final text = output.toString();
        expect(text, contains('target must be a file'));
        expect(text, contains('Current directory:'));
        expect(_displaySafe(text), contains('/help opens help.'));
      },
    );

    test(
      'a screen-reader directory browser introduces itself before entry',
      () async {
        final root = await Directory.systemTemp.createTemp('theme-sr-picker-');
        addTearDown(() => root.delete(recursive: true));
        final output = StringBuffer();
        final prompt = ThemeFilesystemPrompt.directoryPicker(
          'Directory',
          io: TerminalEnvironment.scripted(
            input: Stream.value('choose\r\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(
            mode: PromptMode.linear,
            screenReader: ScreenReaderPreference.on,
          ),
          instructions: InstructionDisplay.hidden,
          base: root.path,
        );

        expect((await prompt.prompt() as Accepted<String>).value, root.path);
        final text = output.toString();
        expect(text, contains('Directory browser.'));
        expect(_displaySafe(text), contains('/help opens help.'));
        expect(
          text.indexOf('Directory browser.'),
          lessThan(text.indexOf('Current directory:')),
        );
      },
    );

    test(
      'an inaccessible listing keeps the prompt usable and cancellable',
      () async {
        final root = await Directory.systemTemp.createTemp('theme-missing-');
        await root.delete();
        final output = StringBuffer();
        final prompt = ThemeFilesystemPrompt.filePicker(
          'File',
          io: TerminalEnvironment.scripted(
            input: Stream.value('/cancel\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          base: root.path,
        );

        expect(await prompt.prompt(), isA<Cancelled<String>>());
        expect(output.toString(), contains('Cannot list'));
        expect(output.toString(), contains('Context retained'));
      },
    );
  });

  group('theme-owned network family', () {
    test('an IP address keeps its typed spelling and parsed value', () async {
      final output = StringBuffer();
      final prompt = ThemeFilesystemPrompt.ipAddress(
        'Address',
        io: TerminalEnvironment.scripted(
          input: Stream.value('not-an-ip\r${'\x7f' * 9}2001:db8::1/64\r'),
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        cidr: true,
      );

      final result = await prompt.prompt();
      final value = (result as Accepted<IPAddressValue>).value;
      expect(value.spelling, '2001:db8::1/64');
      expect(value.prefixLength, 64);
      expect(value.address.type, InternetAddressType.IPv6);
      expect(output.toString(), contains('valid numeric IPv4 or IPv6'));
      expect(_displaySafe(output.toString()), contains('/help opens help.'));
    });

    test('a URL retries invalid input without disclosing the draft', () async {
      final output = StringBuffer();
      final prompt = ThemeFilesystemPrompt.url(
        'Endpoint',
        io: TerminalEnvironment.scripted(
          input: Stream.value(
            'ftp://example.org\r${'\x7f' * 17}https://bücher.example/a\r',
          ),
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        allowedSchemes: const {'https'},
      );

      final result = await prompt.prompt();
      expect((result as Accepted<String>).value, 'https://bücher.example/a');
      final text = output.toString();
      expect(text, contains('valid absolute URL'));
      expect(text, isNot(contains('ftp://example.org')));
      expect(text, contains('Host interpretation -- Unicode:'));
      expect(_displaySafe(text), contains('/help opens help.'));
    });

    test('an email accepts a configured SMTPUTF8 local part', () async {
      final output = StringBuffer();
      final prompt = ThemeFilesystemPrompt.email(
        'Contact',
        io: TerminalEnvironment.scripted(
          input: Stream.value(
            'bad address\r${'\x7f' * 11}üser@bücher.example\r',
          ),
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        smtpUtf8: true,
      );

      final result = await prompt.prompt();
      expect((result as Accepted<String>).value, 'üser@bücher.example');
      final text = output.toString();
      expect(text, contains('valid bare SMTP address'));
      expect(text, contains('Domain interpretation -- Unicode:'));
      expect(_displaySafe(text), contains('/help opens help.'));
    });
  });

  group('theme-owned component modes and outcomes', () {
    for (final interaction in [
      const InteractionPreferences(mode: PromptMode.rich),
      const InteractionPreferences(mode: PromptMode.linear),
      const InteractionPreferences(
        mode: PromptMode.linear,
        screenReader: ScreenReaderPreference.on,
      ),
    ]) {
      final mode = interaction.screenReader == ScreenReaderPreference.on
          ? 'screen reader'
          : interaction.mode.name;
      for (final kind in ThemeFilesystemKind.values) {
        test('$kind accepts a real answer in $mode presentation', () async {
          final root = await Directory.systemTemp.createTemp('theme-mode-');
          addTearDown(() => root.delete(recursive: true));
          await File(path.join(root.path, 'answer.txt')).writeAsString('data');
          final output = StringBuffer();
          final rich = interaction.mode == PromptMode.rich;
          final prompt = _make(
            kind,
            io: TerminalEnvironment.scripted(
              input: Stream.value(_answer(kind)),
              output: output,
              profile: rich
                  ? _richProfile
                  : const OutputProfile(glyphs: GlyphSet.ascii),
              supportsRich: rich,
            ),
            interaction: interaction,
            base: root.path,
          );

          expect(await prompt.prompt(), isA<Accepted<dynamic>>());
          final text = output.toString();
          if (interaction.screenReader == ScreenReaderPreference.on) {
            expect(text, contains(_essential(kind)));
            expect(
              text.indexOf(_essential(kind)),
              lessThan(text.indexOf(_componentAnchor(kind))),
            );
          } else if (rich) {
            expect(_displaySafe(text), contains('F1 opens help'));
          } else {
            expect(_displaySafe(text), contains('/help opens help.'));
          }
        });
      }
    }

    test(
      'every family reports cancellation, interruption and end of input',
      () async {
        final root = await Directory.systemTemp.createTemp('theme-outcomes-');
        addTearDown(() => root.delete(recursive: true));
        await File(path.join(root.path, 'answer.txt')).writeAsString('data');
        for (final kind in ThemeFilesystemKind.values) {
          for (final (input, outcome) in [
            (_cancelFor(kind), 'cancel'),
            ('\x03', 'interrupt'),
            ('', 'end'),
          ]) {
            final result = await _make(
              kind,
              io: TerminalEnvironment.scripted(
                input: Stream.value(input),
                output: StringBuffer(),
                profile: const OutputProfile(glyphs: GlyphSet.ascii),
              ),
              interaction: const InteractionPreferences(
                mode: PromptMode.linear,
              ),
              base: root.path,
            ).prompt();
            expect(result, switch (outcome) {
              'cancel' => isA<Cancelled<dynamic>>(),
              'interrupt' => isA<Interrupted<dynamic>>(),
              _ => isA<InputEnded<dynamic>>(),
            }, reason: '$kind $outcome');
          }
        }
      },
    );

    test(
      'sequential prompts restart from their configured initial values',
      () async {
        var resolutions = 0;
        final pathPrompt = ThemeFilesystemPrompt.path(
          'Path',
          io: TerminalEnvironment.scripted(
            input: _AnswersPerListen(['x\r\r', '\r\r']),
            output: StringBuffer(),
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          initialValue: 'seed',
          allowNonexistent: true,
          onResolved: (_) async => resolutions++,
        );
        expect(
          (await pathPrompt.prompt() as Accepted<String>).value,
          endsWith('seedx'),
        );
        expect(
          (await pathPrompt.prompt() as Accepted<String>).value,
          endsWith('seed'),
        );

        final emailPrompt = ThemeFilesystemPrompt.email(
          'Contact',
          io: TerminalEnvironment.scripted(
            input: _AnswersPerListen(['x\r', '\r']),
            output: StringBuffer(),
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          initialValue: 'seed@example.org',
        );
        expect(
          (await emailPrompt.prompt() as Accepted<String>).value,
          'seed@example.orgx',
        );
        expect(
          (await emailPrompt.prompt() as Accepted<String>).value,
          'seed@example.org',
        );
        expect(resolutions, 2);
      },
    );

    test(
      'a second concurrent prompt is rejected without new resolution',
      () async {
        final input = StreamController<String>();
        final output = StringBuffer();
        var resolutions = 0;
        final prompt = ThemeFilesystemPrompt.path(
          'Path',
          io: TerminalEnvironment.scripted(
            input: input.stream,
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          allowNonexistent: true,
          onResolved: (_) async => resolutions++,
        );

        final pending = prompt.prompt();
        await _waitUntil(() => output.toString().contains('Path. Base:'));
        final rejected = await prompt.prompt();

        expect(rejected, isA<Unavailable<String>>());
        expect(resolutions, 1);
        expect(
          RegExp('Path\\. Base:').allMatches(output.toString()),
          hasLength(1),
        );
        input.add('x\r');
        await Future<void>.delayed(Duration.zero);
        input.add('\r');
        await Future<void>.delayed(Duration.zero);
        await input.close();
        expect(await pending, isA<Accepted<String>>());
      },
    );
  });

  group('theme-owned presentation states and owner', () {
    test(
      'narrow monochrome output keeps validation and review readable',
      () async {
        final output = StringBuffer();
        final palette = ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(9, 8, 7),
        );
        final prompt = ThemeFilesystemPrompt.path(
          'Path',
          io: TerminalEnvironment.scripted(
            input: Stream.value('\rfile\r\r'),
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
          allowNonexistent: true,
        );

        expect(
          (await prompt.prompt() as Accepted<String>).value,
          endsWith('file'),
        );
        final text = output.toString();
        expect(text, isNot(contains('\x1b[')));
        expect(
          _displaySafe(text),
          contains('Enter a non-empty valid native path'),
        );
        expect(_displaySafe(text), contains('Resolved candidate:'));
        expect(_displaySafe(text), contains('/help'));
        expect(text.split('\n').every((line) => line.length <= 24), isTrue);
      },
    );

    test('unicode NO_COLOR output keeps its own help route', () async {
      final output = StringBuffer();
      final prompt = ThemeFilesystemPrompt.email(
        'Contact',
        io: TerminalEnvironment.scripted(
          input: Stream.value('user@example.org\r'),
          output: output,
          profile: OutputProfile(
            glyphs: GlyphSet.unicode,
            colorDepth: ColorDepth.rgb,
            geometry: OutputGeometry.fixed(columns: 32, rows: 8),
          ),
          environment: const {'NO_COLOR': '1'},
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      expect(
        (await prompt.prompt() as Accepted<String>).value,
        'user@example.org',
      );
      final text = output.toString();
      expect(text, isNot(contains('\x1b[')));
      expect(text, contains('Domain interpretation -- Unicode:'));
      expect(_displaySafe(text), contains('/help'));
    });

    test(
      'hidden instructions keep the essential help hint in every mode',
      () async {
        for (final rich in [false, true]) {
          final output = StringBuffer();
          final prompt = ThemeFilesystemPrompt.path(
            'Path',
            io: TerminalEnvironment.scripted(
              input: Stream.value('draft\r\r'),
              output: output,
              profile: rich
                  ? _richProfile
                  : const OutputProfile(glyphs: GlyphSet.ascii),
              supportsRich: rich,
            ),
            interaction: InteractionPreferences(
              mode: rich ? PromptMode.rich : PromptMode.linear,
            ),
            instructions: InstructionDisplay.hidden,
            allowNonexistent: true,
          );

          expect(
            (await prompt.prompt() as Accepted<String>).value,
            endsWith('draft'),
          );
          final text = _displaySafe(output.toString());
          expect(text, contains(rich ? 'F1 opens help' : '/help opens help.'));
        }
      },
    );

    test('rich URL help keeps a hidden query draft intact', () async {
      const draft = 'https://example.org/a';
      final output = StringBuffer();
      final prompt = ThemeFilesystemPrompt.url(
        'Endpoint',
        io: TerminalEnvironment.scripted(
          input: Stream.value('$draft\x1bOP\x1b\r\r'),
          output: output,
          profile: _richProfile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        allowedSchemes: const {'https'},
      );

      expect((await prompt.prompt() as Accepted<String>).value, draft);
      final flattened = _displaySafe(output.toString());
      expect(flattened, contains('Help:'));
      expect(flattened, contains('Help dismissed.'));
    });

    test(
      'a browser shares one owner with live feedback and one resolution',
      () async {
        final root = await Directory.systemTemp.createTemp('theme-owner-');
        addTearDown(() => root.delete(recursive: true));
        await File(path.join(root.path, 'answer.txt')).writeAsString('data');
        final input = StreamController<String>();
        final output = StringBuffer();
        var resolutions = 0;
        final prompt = ThemeFilesystemPrompt.filePicker(
          'File',
          io: TerminalEnvironment.scripted(
            input: input.stream,
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          onResolved: (_) async => resolutions++,
          base: root.path,
        );

        late final Spinner spinner;
        final feedback = await prompt.startFeedback((handle) {
          spinner = Spinner('Listing')..start(session: handle.session);
        }, stop: () => spinner.dispose());
        final pending = prompt.prompt();
        await _waitUntil(
          () => output.toString().contains('Current directory:'),
        );
        spinner.update('entries');
        input.add('choose 1\r');
        await Future<void>.delayed(Duration.zero);
        input.add('\r');
        await input.close();

        expect(
          (await pending as Accepted<String>).value,
          endsWith('answer.txt'),
        );
        await feedback.finish(() => spinner.finish(FeedbackOutcome.completed));
        expect(resolutions, 1);
        expect(output.toString(), contains('Listing: entries'));
        expect(prompt.cleanupFailures, isEmpty);
      },
    );
  });

  group('theme-owned editing safety', () {
    test('an escaped command-shaped path survives invalid retries', () async {
      final output = StringBuffer();
      final prompt = ThemeFilesystemPrompt.path(
        'Path',
        io: TerminalEnvironment.scripted(
          input: Stream.value('\\/help\r\r\x1bq'),
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        base: Directory.current.path,
        target: PathTarget.directory,
      );

      expect(await prompt.prompt(), isA<Cancelled<String>>());
      final text = output.toString();
      expect(
        RegExp(
          'Candidate: ${RegExp.escape(path.rootPrefix(Directory.current.path))}help',
        ).allMatches(text),
        hasLength(greaterThanOrEqualTo(2)),
      );
      expect(text, contains('Target must exist.'));
      expect(text, isNot(contains('Help: PathInput accepts')));
    });

    test(
      'an identified pasted URL command stays literal across retries',
      () async {
        final output = StringBuffer();
        final prompt = ThemeFilesystemPrompt.url(
          'Endpoint',
          io: TerminalEnvironment.scripted(
            input: Stream.value(
              '\x1b[200~/cancel\x1b[201~\r'
              '${'\x7f' * 8}'
              '\x1b[200~https://example.org/ok\x1b[201~\r',
            ),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          allowedSchemes: const {'https'},
        );

        expect(
          (await prompt.prompt() as Accepted<String>).value,
          'https://example.org/ok',
        );
        final text = output.toString();
        expect(text, contains('valid absolute URL'));
        expect(text, isNot(contains('Help: Enter text to submit')));
        expect(text, isNot(contains('\x1b[200~')));
      },
    );

    test('help and cancel work with a one-character draft', () async {
      for (final kind in [
        ThemeFilesystemKind.path,
        ThemeFilesystemKind.ipAddress,
        ThemeFilesystemKind.email,
      ]) {
        final output = StringBuffer();
        final helpedInput = kind == ThemeFilesystemKind.path
            ? 'x\x1bOP\x1bq\r\r'
            : 'x\x1bOP\x1bq\x7f\x7f${_answer(kind)}';
        final helped = _make(
          kind,
          io: TerminalEnvironment.scripted(
            input: Stream.value(helpedInput),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          base: Directory.current.path,
        );
        expect(
          await helped.prompt(),
          isA<Accepted<dynamic>>(),
          reason: '$kind',
        );
        expect(output.toString(), contains('Help:'), reason: '$kind');
        expect(output.toString(), contains('Help dismissed.'), reason: '$kind');

        final cancelInput = kind == ThemeFilesystemKind.path
            ? 'x\r/cancel\r'
            : 'x\r\x7f/cancel\r';
        final cancelled = await _make(
          kind,
          io: TerminalEnvironment.scripted(
            input: Stream.value(cancelInput),
            output: StringBuffer(),
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          base: Directory.current.path,
        ).prompt();
        expect(cancelled, isA<Cancelled<dynamic>>(), reason: '$kind');
      }
    });

    test('rich help preserves the draft and caret', () async {
      final output = StringBuffer();
      final prompt = ThemeFilesystemPrompt.path(
        'Path',
        io: TerminalEnvironment.scripted(
          input: Stream.value('\x1b[D\x1bOP\x1bX\r\r'),
          output: output,
          profile: _richProfile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        initialValue: 'ab',
        allowNonexistent: true,
      );

      expect(
        (await prompt.prompt() as Accepted<String>).value,
        endsWith('aXb'),
      );
      final flattened = _displaySafe(output.toString());
      expect(flattened, contains('Help: PathInput accepts'));
      expect(flattened, contains('Help dismissed.'));
    });

    test(
      'a rejected multiline paste preserves the single-line draft',
      () async {
        final output = StringBuffer();
        final prompt = ThemeFilesystemPrompt.path(
          'Path',
          io: TerminalEnvironment.scripted(
            input: Stream.value('\x1b[200~line1\nline2\x1b[201~\r\r'),
            output: output,
            profile: const OutputProfile(glyphs: GlyphSet.ascii),
          ),
          interaction: const InteractionPreferences(mode: PromptMode.linear),
          initialValue: 'se',
          allowNonexistent: true,
        );

        expect(
          (await prompt.prompt() as Accepted<String>).value,
          endsWith('se'),
        );
        expect(
          output.toString(),
          contains('Paste rejected: single-line printable text only.'),
        );
      },
    );

    test('one shared reader is released after a themed paste prompt', () async {
      var cancellations = 0;
      final input = StreamController<String>(onCancel: () => cancellations++);
      final output = StringBuffer();
      final prompt = ThemeFilesystemPrompt.path(
        'Path',
        io: TerminalEnvironment.scripted(
          input: input.stream,
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        allowNonexistent: true,
      );

      final pending = prompt.prompt();
      await _waitUntil(() => output.toString().contains('Path. Base:'));
      input.add('\x1b[200~/cancel\x1b[201~\r');
      await Future<void>.delayed(Duration.zero);
      input.add('\r');

      expect(
        (await pending as Accepted<String>).value,
        endsWith('${path.separator}cancel'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cancellations, 1);
      expect(input.isClosed, isFalse);
      await input.close();
    });

    test(
      'rich requests on a linear output are unavailable without painting',
      () async {
        for (final kind in ThemeFilesystemKind.values) {
          final output = StringBuffer();
          final result = await _make(
            kind,
            io: TerminalEnvironment.scripted(
              input: Stream.value(_answer(kind)),
              output: output,
              profile: const OutputProfile(glyphs: GlyphSet.ascii),
            ),
            interaction: const InteractionPreferences(mode: PromptMode.rich),
            base: Directory.current.path,
          ).prompt();
          expect(result, isA<Unavailable<dynamic>>(), reason: '$kind');
          expect(output.toString(), isEmpty, reason: '$kind');
        }
      },
    );
  });
}

String _displaySafe(String text) =>
    text.replaceAll('\r', '').replaceAll('\n', '');

String _label(ThemeFilesystemKind kind) => switch (kind) {
  ThemeFilesystemKind.path => 'Path',
  ThemeFilesystemKind.filePicker => 'File',
  ThemeFilesystemKind.directoryPicker => 'Directory',
  ThemeFilesystemKind.ipAddress => 'Address',
  ThemeFilesystemKind.url => 'Endpoint',
  ThemeFilesystemKind.email => 'Contact',
};

String _answer(ThemeFilesystemKind kind) => switch (kind) {
  ThemeFilesystemKind.path => 'draft\r\r',
  ThemeFilesystemKind.filePicker => 'choose 1\r\r',
  ThemeFilesystemKind.directoryPicker => 'choose\r\r',
  ThemeFilesystemKind.ipAddress => '192.0.2.1\r',
  ThemeFilesystemKind.url => 'https://example.org/\r',
  ThemeFilesystemKind.email => 'user@example.org\r',
};

String _componentAnchor(ThemeFilesystemKind kind) => switch (kind) {
  ThemeFilesystemKind.filePicker ||
  ThemeFilesystemKind.directoryPicker => 'Current directory:',
  ThemeFilesystemKind.url => 'Endpoint.',
  _ => 'Current text:',
};

String _cancelFor(ThemeFilesystemKind kind) =>
    kind == ThemeFilesystemKind.url ? '\x1bq' : '/cancel\r';

String _essential(ThemeFilesystemKind kind) => switch (kind) {
  ThemeFilesystemKind.path => 'Path entry.',
  ThemeFilesystemKind.filePicker => 'File browser.',
  ThemeFilesystemKind.directoryPicker => 'Directory browser.',
  ThemeFilesystemKind.ipAddress => 'Address numeric address entry.',
  ThemeFilesystemKind.url => 'Endpoint URL entry.',
  ThemeFilesystemKind.email => 'Contact mailbox entry.',
};

ThemeFilesystemPrompt<dynamic> _make(
  ThemeFilesystemKind kind, {
  required TerminalEnvironment io,
  required InteractionPreferences interaction,
  required String base,
}) {
  final label = _label(kind);
  return switch (kind) {
    ThemeFilesystemKind.path => ThemeFilesystemPrompt.path(
      label,
      io: io,
      interaction: interaction,
      base: base,
      allowNonexistent: true,
    ),
    ThemeFilesystemKind.filePicker => ThemeFilesystemPrompt.filePicker(
      label,
      io: io,
      interaction: interaction,
      base: base,
    ),
    ThemeFilesystemKind.directoryPicker =>
      ThemeFilesystemPrompt.directoryPicker(
        label,
        io: io,
        interaction: interaction,
        base: base,
      ),
    ThemeFilesystemKind.ipAddress => ThemeFilesystemPrompt.ipAddress(
      label,
      io: io,
      interaction: interaction,
    ),
    ThemeFilesystemKind.url => ThemeFilesystemPrompt.url(
      label,
      io: io,
      interaction: interaction,
      allowedSchemes: const {'https'},
    ),
    ThemeFilesystemKind.email => ThemeFilesystemPrompt.email(
      label,
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
  }) => Stream<String>.value(_answers[_next++]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition was not met before the test deadline');
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 80, rows: 20),
);
