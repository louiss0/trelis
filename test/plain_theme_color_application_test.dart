import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _linearRgbProfile = OutputProfile(colorDepth: ColorDepth.rgb);

final class _RgbTerminal implements TerminalIo, TerminalIoOutputProfile {
  _RgbTerminal({StringSink? output}) : _output = output ?? StringBuffer();

  final StringSink _output;

  @override
  Map<String, String?> get environment => const {};

  @override
  Stream<String> get input => const Stream.empty();

  @override
  StringSink get output => _output;

  @override
  bool get supportsRich => true;

  @override
  TerminalLease acquire() => throw UnsupportedError('Not used in tests');

  @override
  OutputProfile get outputProfile => _linearRgbProfile;
}

void main() {
  group('PlainTheme colour application in output', () {
    test('Text.present styles ordinary text with the palette foreground', () {
      final out = StringBuffer();
      PlainTheme.text(
        'Ready',
        kind: TextKind.ordinary,
        colors: ColorThemes.signal,
      ).present(output: out);
      expect(out.toString(), contains('\x1b['));
      expect(out.toString(), contains('Ready'));
    });

    test('Text.present keeps plain text when palette is terminalDefault', () {
      final out = StringBuffer();
      PlainTheme.text(
        'Ready',
        kind: TextKind.ordinary,
        colors: ColorThemes.terminalDefault,
      ).present(output: out);
      expect(out.toString(), isNot(contains('\x1b[')));
    });

    test('Progress emits ANSI when a non-default palette is used', () {
      final terminal = _RgbTerminal();
      final progress = PlainTheme.progress(
        'Build',
        total: 10,
        colors: ColorThemes.signal,
      );
      progress.start(terminal: terminal);
      expect(terminal.output.toString(), contains('\x1b['));
      expect(terminal.output.toString(), contains('Build'));
    });

    test('Spinner emits ANSI when a non-default palette is used', () {
      final terminal = _RgbTerminal();
      final spinner = PlainTheme.spinner('Work', colors: ColorThemes.signal);
      spinner.start(terminal: terminal);
      expect(terminal.output.toString(), contains('\x1b['));
      expect(terminal.output.toString(), contains('Work'));
    });

    test('MultiSpinner emits ANSI when a non-default palette is used', () {
      final terminal = _RgbTerminal();
      final group = PlainTheme.multiSpinner(const [
        'a',
      ], colors: ColorThemes.signal);
      group.start(terminal: terminal);
      expect(terminal.output.toString(), contains('\x1b['));
      expect(terminal.output.toString(), contains('a'));
    });

    test('Password opening is coloured with non-default palette', () async {
      final out = StringBuffer();
      await PlainTheme.password('Token', colors: ColorThemes.signal).prompt(
        source: ScriptedInput(
          Stream.value('\x03'),
          out,
          outputProfile: _linearRgbProfile,
        ),
        mode: PromptMode.linear,
      );
      expect(out.toString(), contains('Token'));
      expect(out.toString(), contains('\x1b['));
    });

    test('URLInput guidance is coloured with non-default palette', () async {
      final out = StringBuffer();
      await PlainTheme.urlInput(
        'Site',
        allowedSchemes: const {'https'},
        colors: ColorThemes.signal,
      ).prompt(
        source: ScriptedInput(
          Stream.value('https://example.com/\r'),
          out,
          outputProfile: _linearRgbProfile,
        ),
        mode: PromptMode.linear,
      );
      expect(out.toString(), contains('Site'));
      expect(out.toString(), contains('\x1b['));
    });

    test('Multiline opening is coloured with non-default palette', () async {
      final out = StringBuffer();
      await PlainTheme.multiline('Notes', colors: ColorThemes.signal).prompt(
        source: ScriptedInput(
          Stream.value('abc\r/done\r'),
          out,
          outputProfile: _linearRgbProfile,
        ),
        mode: PromptMode.linear,
      );
      expect(out.toString(), contains('Notes'));
      expect(out.toString(), contains('\x1b['));
    });

    test('Keypress guidance is coloured with non-default palette', () async {
      final out = StringBuffer();
      await PlainTheme.keypress('Shortcut', colors: ColorThemes.signal).prompt(
        source: ScriptedInput(
          Stream.value('/capture\ra/done\r'),
          out,
          outputProfile: _linearRgbProfile,
        ),
        mode: PromptMode.linear,
      );
      expect(out.toString(), contains('Shortcut'));
      expect(out.toString(), contains('\x1b['));
    });

    test(
      'palette background stays component-local; no global surface is forced',
      () {
        // Terminal-default palette produces no ANSI escape sequences.
        final text = PlainTheme.text(
          'Hello',
          colors: ColorThemes.terminalDefault,
        );
        final out = StringBuffer();
        text.present(output: out);
        expect(out.toString(), isNot(contains('\x1b[')));
      },
    );
  });
}
