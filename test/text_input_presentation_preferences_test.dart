import 'package:test/test.dart';
import 'package:trelis/src/testing/compat_api.dart';
import 'package:trelis/src/presentation_preferences.dart';

void main() {
  final rich = OutputProfile(
    cursor: CapabilitySupport.supported,
    alternateScreen: CapabilitySupport.supported,
    colorDepth: ColorDepth.indexed256,
    geometry: OutputGeometry.fixed(columns: 80, rows: 24),
  );
  Future<({String output, PromptResult<String> result})> run({
    PresentationPreferences? presentation,
    PromptMode? mode,
    String input = 'Ada\r',
    OutputProfile? profile,
  }) async {
    final output = StringBuffer();
    final result = await prototypeTextInputPrompt(
      TextInput('Name'),
      source: ScriptedInput(
        Stream.value(input),
        output,
        outputProfile: profile ?? rich,
      ),
      mode: mode,
      presentation: presentation,
    );
    return (output: output.toString(), result: result);
  }

  test(
    'screen reader on uses sequential editor and help on a rich output',
    () async {
      final runResult = await run(
        presentation: const PresentationPreferences(
          screenReader: ScreenReaderPreference.on,
        ),
        input: '/help\rAda\r',
      );
      expect((runResult.result as Accepted<String>).value, 'Ada');
      expect(runResult.output, contains('Current text:'));
      expect(runResult.output, contains('Cursor position:'));
      expect(runResult.output, isNot(contains('\x1b[?1049')));
      expect(runResult.output, isNot(contains('\x1b[2K')));
      expect(runResult.output, isNot(contains('\r')));
    },
  );

  test(
    'omission keeps rich redraw and off does not select sequential',
    () async {
      final omitted = await run();
      final off = await run(
        presentation: const PresentationPreferences(
          screenReader: ScreenReaderPreference.off,
        ),
      );
      expect(omitted.output, isNot(contains('Current text:')));
      expect(off.output, omitted.output);
      expect(omitted.output, contains('\r'));
    },
  );

  test('explicit rich and screen reader on conflict before output', () async {
    final output = StringBuffer();
    await expectLater(
      prototypeTextInputPrompt(
        TextInput('Name'),
        source: ScriptedInput(
          Stream.value('Ada\r'),
          output,
          outputProfile: rich,
        ),
        mode: PromptMode.rich,
        presentation: const PresentationPreferences(
          screenReader: ScreenReaderPreference.on,
        ),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('rich'),
        ),
      ),
    );
    expect(output.toString(), isEmpty);
  });

  test('selected palette and role reach emitted colors', () async {
    final result = await run(
      presentation: PresentationPreferences(
        background: BackgroundPreference.light,
        lightPalette: ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.indexed(17),
        ),
        roles: ColorRoleOverrides(foreground: TerminalColor.indexed(18)),
        lightRoles: ColorRoleOverrides(foreground: TerminalColor.indexed(19)),
      ),
    );
    expect(result.output, contains('38;5;19'));
    expect(result.output, isNot(contains('38;5;17')));
  });

  test('explicit rich still checks output capability', () async {
    final result = await run(
      mode: PromptMode.rich,
      profile: const OutputProfile(),
      presentation: const PresentationPreferences(),
    );
    expect(result.result, isA<Unavailable<String>>());
    expect(result.output, isEmpty);
  });

  test(
    'short limits allow help and cancel without accepting oversized prefixes',
    () async {
      const preferences = PresentationPreferences(
        screenReader: ScreenReaderPreference.on,
      );
      for (final limit in [0, 1, 3]) {
        final output = StringBuffer();
        final result = await prototypeTextInputPrompt(
          TextInput('Name', maxLength: limit),
          source: ScriptedInput(
            Stream.value('/help\r/cancel\r'),
            output,
            outputProfile: rich,
          ),
          presentation: preferences,
        );
        expect(result, isA<Cancelled<String>>(), reason: 'limit $limit');
        expect(output.toString(), contains('Help:'));
      }
      final output = StringBuffer();
      final result = await prototypeTextInputPrompt(
        TextInput('Name', maxLength: 1),
        source: ScriptedInput(
          Stream.value('/h\r\x7f\x7fx\r'),
          output,
          outputProfile: rich,
        ),
        presentation: preferences,
      );
      expect((result as Accepted<String>).value, 'x');
      // Either the inline 'character limit' rejection or the screen-reader
      // 'Maximum length' wording is acceptable; the guard is what matters.
      expect(
        output.toString(),
        anyOf(contains('Maximum length'), contains('character limit')),
      );
    },
  );

  test(
    'framed paste keeps command literal and rejects multiline input',
    () async {
      const preferences = PresentationPreferences(
        screenReader: ScreenReaderPreference.on,
      );
      final command = await run(
        presentation: preferences,
        input: '\x1b[200~/cancel\x1b[201~\r',
      );
      expect((command.result as Accepted<String>).value, '/cancel');
      final multiline = await run(
        presentation: preferences,
        input: '\x1b[200~a\r/cancel\x1b[201~ok\r',
      );
      expect((multiline.result as Accepted<String>).value, 'ok');
      expect(multiline.output, contains('Paste rejected'));
      expect(multiline.output, isNot(contains('\x1b[2K')));
    },
  );
}
