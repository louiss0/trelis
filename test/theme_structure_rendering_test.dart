import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _syntheticRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
  glyphs: GlyphSet.unicode,
);

/// A 72-column Unicode profile, so a pinned line actually wraps.
final _wrappedProfile = OutputProfile(
  geometry: OutputGeometry.fixed(columns: 72, rows: 20),
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
  group('linear TextInput output is byte-identical', () {
    // These are the exact bytes the merged rail and branch themes produced,
    // captured from `8144538` before the enclosure work. A prefix grammar is
    // a byte contract, not a `contains('|')` property: the guidance continues
    // the spine and only the command hint closes it, and a later enclosure
    // change must never turn that into `guidance-closes` plus a reopened line.
    Future<String> render(
      PromptStructure structure,
      OutputProfile profile,
    ) async {
      final out = StringBuffer();
      await TextInput('Name', structure: structure).prompt(
        source: _scriptedInput(
          PromptMode.linear,
          Stream.value('Ada\n'),
          out,
          profile: profile,
        ),
        mode: PromptMode.linear,
      );
      return out.toString();
    }

    test('RailTheme / automatic glyphs', () async {
      expect(
        await render(PromptStructure.rail, const OutputProfile()),
        '''| Name (Optional).\n| Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n\\ Exact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.\n| Current text: \n\\ Cursor position: 0 of 0 graphemes.\n| Current text: A\n\\ Cursor position: 1 of 1 graphemes.\n| Current text: Ad\n\\ Cursor position: 2 of 2 graphemes.\n| Current text: Ada\n\\ Cursor position: 3 of 3 graphemes.\n\n''',
      );
    });

    test('RailTheme / wrapped Unicode', () async {
      expect(
        await render(PromptStructure.rail, _wrappedProfile),
        '''\u{2502} Name (Optional).\n\u{2502} Left/Right move; Home/End go to boundaries; Backspace/Delete erase; En\n\u{2502} ter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n\u{2502} Exact /help and /cancel are commands. Quote a command with a backslash\n\u{2502} ; double a leading backslash to enter one. Identified paste is literal\n\u{2514} .\n\r\x1B[2K\u{2502} \x1B[s\x1B[u\r\x1B[2K\u{2502} A\x1B[s\x1B[u\r\x1B[2K\u{2502} Ad\x1B[s\x1B[u\r\x1B[2K\u{2502} Ada\x1B[s\x1B[u\r\x1B[2K\u{2502} Ada\n''',
      );
    });

    test('BranchTheme / automatic glyphs', () async {
      expect(
        await render(PromptStructure.branch, const OutputProfile()),
        '''+-Name (Optional).\n| Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n\\-Exact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.\n+-Current text: \n\\-Cursor position: 0 of 0 graphemes.\n+-Current text: A\n\\-Cursor position: 1 of 1 graphemes.\n+-Current text: Ad\n\\-Cursor position: 2 of 2 graphemes.\n+-Current text: Ada\n\\-Cursor position: 3 of 3 graphemes.\n\n''',
      );
    });

    test('BranchTheme / wrapped Unicode', () async {
      expect(
        await render(PromptStructure.branch, _wrappedProfile),
        '''\u{251C} Name (Optional).\n\u{2502} Left/Right move; Home/End go to boundaries; Backspace/Delete erase; En\n\u{2502} ter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n\u{2502} Exact /help and /cancel are commands. Quote a command with a backslash\n\u{2502} ; double a leading backslash to enter one. Identified paste is literal\n\u{2514} .\n\r\x1B[2K\u{2502} \x1B[s\x1B[u\r\x1B[2K\u{2502} A\x1B[s\x1B[u\r\x1B[2K\u{2502} Ad\x1B[s\x1B[u\r\x1B[2K\u{2502} Ada\x1B[s\x1B[u\r\x1B[2K\u{2502} Ada\n''',
      );
    });

    test('PlainTheme / automatic glyphs', () async {
      expect(
        await render(PromptStructure.plain, const OutputProfile()),
        '''Name (Optional).\nLeft/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\nExact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.\nCurrent text: \nCursor position: 0 of 0 graphemes.\nCurrent text: A\nCursor position: 1 of 1 graphemes.\nCurrent text: Ad\nCursor position: 2 of 2 graphemes.\nCurrent text: Ada\nCursor position: 3 of 3 graphemes.\n\n''',
      );
    });

    test('PlainTheme / wrapped Unicode', () async {
      expect(
        await render(PromptStructure.plain, _wrappedProfile),
        '''Name (Optional).\nLeft/Right move; Home/End go to boundaries; Backspace/Delete erase; Ente\nr submits. /help opens help. Escape cancels; Ctrl+C interrupts.\nExact /help and /cancel are commands. Quote a command with a backslash; \ndouble a leading backslash to enter one. Identified paste is literal.\n\r\x1B[2K> \x1B[s\x1B[u\r\x1B[2K> A\x1B[s\x1B[u\r\x1B[2K> Ad\x1B[s\x1B[u\r\x1B[2K> Ada\x1B[s\x1B[u\r\x1B[2K> Ada\n''',
      );
    });
  });

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
