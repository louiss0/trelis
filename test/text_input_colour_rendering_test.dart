import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  final palette = ColorTheme(
    foreground: TerminalColor.rgb(1, 2, 3),
    background: TerminalColor.rgb(4, 5, 6),
    muted: TerminalColor.indexed(7),
    accent: TerminalColor.rgb(8, 9, 10),
    selectionForeground: TerminalColor.indexed(11),
    selectionBackground: TerminalColor.indexed(12),
    success: TerminalColor.indexed(13),
    warning: TerminalColor.indexed(14),
    error: TerminalColor.rgb(15, 16, 17),
    border: TerminalColor.indexed(18),
  );

  test(
    'complete palettes copy immutably and validate terminal colour bounds',
    () {
      expect(
        palette.copyWith(error: TerminalColor.indexed(42)).error,
        isA<Object>(),
      );
      expect(palette.error, isNot(same(palette.copyWith())));
      expect(() => TerminalColor.indexed(256), throwsArgumentError);
      expect(() => TerminalColor.rgb(-1, 0, 0), throwsArgumentError);
    },
  );

  test('TextInput styles owned rich content and restores it', () async {
    final out = StringBuffer();
    await TextInput('Name', colors: palette).prompt(
      source: ScriptedInput(
        Stream.value('Ada\r'),
        out,
        outputProfile: OutputProfile(
          cursor: CapabilitySupport.supported,
          styles: CapabilitySupport.supported,
          colorDepth: ColorDepth.rgb,
          geometry: OutputGeometry.fixed(columns: 40, rows: 10),
        ),
      ),
      mode: PromptMode.rich,
    );
    expect(out.toString(), contains('\x1b[38;2;1;2;3;48;2;4;5;6m'));
    expect(out.toString(), contains('\x1b[0m'));
  });

  test(
    'no colour depth keeps semantic text and emits no colour ANSI',
    () async {
      final out = StringBuffer();
      await TextInput('Name', colors: palette).prompt(
        source: ScriptedInput(
          Stream.value('/cancel\r'),
          out,
          outputProfile: OutputProfile(colorDepth: ColorDepth.none),
        ),
      );
      expect(out.toString(), contains('Name'));
      expect(out.toString(), isNot(contains('\x1b[38;')));
    },
  );
}
