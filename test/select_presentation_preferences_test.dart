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
  const reader = PresentationPreferences(
    screenReader: ScreenReaderPreference.on,
  );
  Select<int> select() => Select<int>(
    'Choose',
    [
      Choice(1, 'Alpha'),
      Choice(2, 'Beta', disabledReason: 'locked'),
      Choice(3, 'Gamma'),
    ],
    defaultValue: 1,
    supplementaryHelp: ['Additional details.'],
  );
  Future<({String output, PromptResult<int> result})> run(
    String input, {
    PresentationPreferences? presentation,
    PromptMode? mode,
  }) async {
    final out = StringBuffer();
    final result = await prototypeSelectPrompt(
      select(),
      source: ScriptedInput(Stream.value(input), out, outputProfile: rich),
      mode: mode,
      presentation: presentation,
    );
    return (output: out.toString(), result: result);
  }

  test(
    'reader uses sequential choice flow, state, instructions and help',
    () async {
      final r = await run('/help\r2\r\x7f3\r', presentation: reader);
      expect((r.result as Accepted<int>).value, 3);
      expect(r.output, contains('[default]'));
      expect(r.output, contains('[unavailable: locked]'));
      expect(r.output, contains('Enter a stable choice number'));
      expect(r.output.replaceAll('\n', ''), contains('Additional details.'));
      expect(r.output, contains('Unavailable: locked'));
      expect(r.output, contains('Accepted: Gamma'));
      expect(r.output, isNot(contains('\r')));
      expect(r.output, isNot(contains('\x1b[2K')));
      expect(r.output, isNot(contains('\x1b[?1049')));
    },
  );
  test(
    'reader paging keeps stable references and unavailable reasons',
    () async {
      final out = StringBuffer();
      final choices = List.generate(
        12,
        (i) => Choice(
          i,
          'Option ${i + 1}',
          disabledReason: i == 11 ? 'not ready' : null,
        ),
      );
      final result = await prototypeSelectPrompt(
        Select<int>('Pick', choices),
        source: ScriptedInput(
          Stream.value('/next\r/help\r11\r'),
          out,
          outputProfile: rich,
        ),
        presentation: reader,
      );
      expect((result as Accepted<int>).value, 10);
      expect(out.toString(), contains('Page 2 of 2'));
      expect(
        out.toString(),
        contains('12. Option 12 [unavailable: not ready]'),
      );
      expect(out.toString(), contains('Accepted: Option 11'));
      expect(out.toString(), isNot(contains('\r')));
    },
  );

  test('omitted and off preserve rich interaction', () async {
    final a = await run('\r');
    final b = await run(
      '\r',
      presentation: const PresentationPreferences(
        screenReader: ScreenReaderPreference.off,
      ),
    );
    expect(a.output, b.output);
    expect((a.result as Accepted<int>).value, 1);
  });
  test(
    'rich conflict fails before output, including supplied answers',
    () async {
      final out = StringBuffer();
      await expectLater(
        prototypeSelectPrompt(
          select(),
          source: ScriptedInput(Stream.value('1\r'), out, outputProfile: rich),
          mode: PromptMode.rich,
          presentation: reader,
        ),
        throwsArgumentError,
      );
      expect(out.toString(), isEmpty);
      await expectLater(
        prototypeSelectPrompt(
          select(),
          source: SuppliedAnswer('1'),
          mode: PromptMode.rich,
          presentation: reader,
        ),
        throwsArgumentError,
      );
    },
  );
  test('session preference rejected without consuming input', () async {
    final out = StringBuffer();
    await TerminalSession.run(
      (session) async {
        await expectLater(
          prototypeSelectPrompt(
            select(),
            session: session,
            presentation: reader,
          ),
          throwsArgumentError,
        );
        final result = await prototypeSelectPrompt(select(), session: session);
        expect((result as Accepted<int>).value, 1);
      },
      source: ScriptedInput(Stream.value('1\r'), out),
      mode: PromptMode.linear,
    );
  });
  test('palette roles reach output and NO_COLOR wins', () async {
    final prefs = PresentationPreferences(
      screenReader: ScreenReaderPreference.on,
      roles: ColorRoleOverrides(foreground: TerminalColor.indexed(19)),
    );
    final normal = await run('\r', presentation: prefs);
    expect(normal.output, contains('38;5;19'));
    final out = StringBuffer();
    final terminal = _Terminal(out, rich);
    await prototypeSelectPrompt(
      select(),
      terminal: terminal,
      presentation: prefs,
    );
    expect(out.toString(), isNot(contains('38;5;19')));
    expect(out.toString(), isNot(contains('\x1b[')));
  });
  test('pasted draft provenance survives retries and editing', () async {
    for (final command in ['/cancel', '/next']) {
      final repeated = await run(
        '\x1b[200~$command\x1b[201~\r\r',
        presentation: reader,
      );
      expect(repeated.result, isA<InputEnded<int>>(), reason: command);
      expect(
        RegExp('Enter a valid choice reference').allMatches(repeated.output),
        hasLength(2),
      );
      final pasted = command.substring(0, command.length - 1);
      final r = await run(
        '\x1b[200~$pasted\x1b[201~x\r\x7f${command[command.length - 1]}\r\r',
        presentation: reader,
      );
      expect(r.result, isA<InputEnded<int>>(), reason: command);
      expect(
        RegExp('Enter a valid choice reference').allMatches(r.output),
        hasLength(3),
      );
    }
  });

  test('deleting pasted characters restores typed command behavior', () async {
    final r = await run(
      '\x1b[200~/cancel\x1b[201~\r\x7f\x7f\x7f\x7f\x7f\x7f\x7f/cancel\r',
      presentation: reader,
    );
    expect(r.result, isA<Cancelled<int>>());
  });

  test('removing only pasted characters permits typed paging', () async {
    final out = StringBuffer();
    final choices = List.generate(11, (i) => Choice(i, 'Option ${i + 1}'));
    final result = await prototypeSelectPrompt(
      Select<int>('Pick', choices),
      source: ScriptedInput(
        Stream.value('\x1b[200~x\x1b[201~\r\x7f/next\r11\r'),
        out,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<int>).value, 10);
    expect(out.toString(), contains('Page 2 of 2'));
  });

  test('quoted commands remain literal on retry', () async {
    final r = await run('\\\\/cancel\r\r', presentation: reader);
    expect(r.result, isA<InputEnded<int>>());
    expect(
      RegExp('Enter a valid choice reference').allMatches(r.output),
      hasLength(2),
    );
  });

  test('pasted commands are literal and multiline paste is rejected', () async {
    final r = await run(
      '\x1b[200~/cancel\x1b[201~\r\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x1b[200~1\r/cancel\x1b[201~3\r',
      presentation: reader,
    );
    expect((r.result as Accepted<int>).value, 3);
    expect(r.output, contains('Enter a valid choice reference'));
    expect(r.output, contains('Paste rejected'));
  });
}

final class _Terminal implements TerminalIo, TerminalIoOutputProfile {
  _Terminal(this.output, this.outputProfile);
  @override
  final StringSink output;
  @override
  final OutputProfile outputProfile;
  @override
  Stream<String> get input => Stream.value('1\r');
  @override
  bool get supportsRich => true;
  @override
  Map<String, String?> get environment => const {'NO_COLOR': '1'};
  @override
  TerminalLease acquire() => TerminalLease(() {});
}
