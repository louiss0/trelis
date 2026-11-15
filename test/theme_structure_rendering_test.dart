import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _syntheticRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
  glyphs: GlyphSet.unicode,
);

ScriptedInput _scriptedInput(
  PromptMode mode,
  Stream<String> input,
  StringSink output, {
  OutputProfile? profile,
}) => ScriptedInput(
  input,
  output,
  outputProfile:
      profile ??
      (mode == PromptMode.rich ? _syntheticRichProfile : const OutputProfile()),
);

void main() {
  group('RailTheme rendering', () {
    test(
      'TextInput / linear uses ASCII rail spine and closure by default',
      () async {
        final out = StringBuffer();
        await RailTheme.textInput('Name').prompt(
          source: _scriptedInput(PromptMode.linear, Stream.value('Ada\n'), out),
          mode: PromptMode.linear,
        );
        final text = out.toString();
        expect(text, contains('Name'));
        expect(text, contains('|'));
        expect(text, contains(r'\'));
        expect(text, isNot(contains('│')));
      },
    );

    test(
      'TextInput / rich uses Unicode rail continuation when declared',
      () async {
        final out = StringBuffer();
        await RailTheme.textInput('Name').prompt(
          source: _scriptedInput(PromptMode.rich, Stream.value('Ada\r'), out),
          mode: PromptMode.rich,
        );
        final text = out.toString();
        expect(text, contains('Name'));
        expect(text, contains('│'));
      },
    );

    test('PortInput / linear inherits TextInput rail rendering', () async {
      final out = StringBuffer();
      await RailTheme.portInput('Port').prompt(
        source: _scriptedInput(PromptMode.linear, Stream.value('8080\n'), out),
        mode: PromptMode.linear,
      );
      expect(out.toString(), contains('|'));
    });
  });

  group('BranchTheme rendering', () {
    test(
      'TextInput / linear uses ASCII branch start and closure by default',
      () async {
        final out = StringBuffer();
        await BranchTheme.textInput('Name').prompt(
          source: _scriptedInput(PromptMode.linear, Stream.value('Ada\n'), out),
          mode: PromptMode.linear,
        );
        final text = out.toString();
        expect(text, contains('Name'));
        expect(text, contains('+-'));
        expect(text, contains(r'\-'));
        expect(text, isNot(contains('├')));
      },
    );

    test(
      'TextInput / rich uses Unicode branch continuation when declared',
      () async {
        final out = StringBuffer();
        await BranchTheme.textInput('Name').prompt(
          source: _scriptedInput(PromptMode.rich, Stream.value('Ada\r'), out),
          mode: PromptMode.rich,
        );
        final text = out.toString();
        expect(text, contains('Name'));
        expect(text, contains('│'));
      },
    );

    test('BranchTheme is distinct from RailTheme', () async {
      final railOut = StringBuffer();
      await RailTheme.textInput('Name').prompt(
        source: _scriptedInput(
          PromptMode.linear,
          Stream.value('Ada\n'),
          railOut,
        ),
        mode: PromptMode.linear,
      );
      final branchOut = StringBuffer();
      await BranchTheme.textInput('Name').prompt(
        source: _scriptedInput(
          PromptMode.linear,
          Stream.value('Ada\n'),
          branchOut,
        ),
        mode: PromptMode.linear,
      );
      expect(railOut.toString(), isNot(branchOut.toString()));
      expect(branchOut.toString(), contains('+-'));
    });
  });

  group('PlainTheme remains unchanged', () {
    test('TextInput / linear keeps plain grammar', () async {
      final out = StringBuffer();
      await PlainTheme.textInput('Name').prompt(
        source: _scriptedInput(PromptMode.linear, Stream.value('Ada\n'), out),
        mode: PromptMode.linear,
      );
      final text = out.toString();
      expect(text, contains('Name'));
      expect(text, isNot(contains('│')));
      expect(text, isNot(contains('├')));
      expect(text, isNot(contains('| Left/Right')));
    });
  });
}
