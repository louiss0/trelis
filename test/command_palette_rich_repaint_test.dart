import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

/// A rich, cursor-capable profile with room for the whole stage.
final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
  glyphs: GlyphSet.unicode,
);

/// Emulates the cursor-addressed bytes a rich prompt emits: line feeds,
/// carriage returns, cursor up/save/restore and erase-in-display. Every other
/// sequence (colours, modes, private markers) is ignored. Returns the visible
/// rows top to bottom.
List<String> _visibleRows(String transcript, {int rows = 40}) {
  final screen = List.generate(rows, (_) => List.filled(120, ' '));
  var row = 0;
  var col = 0;
  var savedRow = 0;
  var savedCol = 0;
  final text = transcript;
  var i = 0;
  while (i < text.length) {
    final ch = text[i];
    if (ch == '\x1b') {
      final match = RegExp(r'\x1b\[([0-9;?]*)([A-Za-z@`])')
          .matchAsPrefix(text, i);
      if (match != null) {
        i = match.end;
        final params = match.group(1)!;
        final command = match.group(2);
        final count = params.isEmpty || params.startsWith('?')
            ? 1
            : int.tryParse(params.split(';').first) ?? 1;
        switch (command) {
          case 'A':
            row = (row - count).clamp(0, rows - 1);
          case 'B':
            row = (row + count).clamp(0, rows - 1);
          case 'C':
            col += count;
          case 'D':
            col = (col - count).clamp(0, 119);
          case 'H':
            row = 0;
            col = 0;
          case 'J':
            for (var rr = row; rr < rows; rr++) {
              for (var cc = rr == row ? col : 0; cc < 120; cc++) {
                screen[rr][cc] = ' ';
              }
            }
          case 'K':
            for (var cc = col; cc < 120; cc++) {
              screen[row][cc] = ' ';
            }
          case 's':
            savedRow = row;
            savedCol = col;
          case 'u':
            row = savedRow;
            col = savedCol;
        }
        continue;
      }
      final other = RegExp(r'\x1b[=>()][0-9;]*').matchAsPrefix(text, i);
      if (other != null) {
        i = other.end;
        continue;
      }
      i++;
      continue;
    }
    if (ch == '\r') {
      col = 0;
      i++;
      continue;
    }
    if (ch == '\n') {
      // Terminals pair a line feed with a carriage return, so the next row
      // starts at column zero.
      row = (row + 1).clamp(0, rows - 1);
      col = 0;
      i++;
      continue;
    }
    if (col < 120) {
      screen[row][col] = ch;
      col++;
      if (col >= 120) {
        col = 0;
        row = (row + 1).clamp(0, rows - 1);
      }
    }
    i++;
  }
  return [for (final line in screen) line.join().trimRight()];
}

void main() {
  test(
    'rich command palette repaints its frame in place while the query is typed',
    () async {
      final out = StringBuffer();
      final result =
          await CommandPalette('Commands', [
            Choice('save', 'Save'),
            Choice('edit', 'Edit'),
          ], structure: PromptStructure.chevron).prompt(
            source: ScriptedInput(
              Stream.value('sav\r\r'),
              out,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'save');

      final rows = _visibleRows(out.toString());
      final headings = rows
          .where((line) => line.contains('CommandPalette:'))
          .toList();
      // Every repaint must replace the previous frame: a single heading row
      // survives however many times the query changed.
      expect(headings, hasLength(1));
      expect(
        rows.where((line) => line.contains('results for "sav"')),
        hasLength(1),
      );
    },
  );

  test(
    'rich palette keeps one frame while session feedback reports progress',
    () async {
      final out = StringBuffer();
      final input = StreamController<String>();
      await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Sync');
          spinner.start(session: session);
          final prompt = CommandPalette('Commands', [
            Choice('save', 'Save'),
            Choice('edit', 'Edit'),
          ], structure: PromptStructure.chevron).prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          spinner.update('fetching');
          await Future<void>.delayed(Duration.zero);
          input.add('s');
          await Future<void>.delayed(Duration.zero);
          spinner.update('merging');
          await Future<void>.delayed(Duration.zero);
          input.add('av\r\r');
          await Future<void>.delayed(Duration.zero);
          spinner.finish(FeedbackOutcome.completed);
          await input.close();
          return (await prompt as Accepted<String>).value;
        },
        source: ScriptedInput(
          input.stream,
          out,
          supportsRich: true,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );

      final rows = _visibleRows(out.toString());
      // Feedback rows are transcript: they commit above the frame instead of
      // accumulating inside the repaint region or duplicating the heading.
      expect(
        rows.where((line) => line.contains('CommandPalette:')),
        hasLength(1),
      );
      expect(
        rows.where((line) => line.contains('[status] - Sync: fetching')),
        hasLength(1),
      );
      expect(
        rows.where((line) => line.contains(r'[status] \ Sync: merging')),
        hasLength(1),
      );
      expect(
        rows.where((line) => line.contains('[status] + Sync: completed')),
        hasLength(1),
      );
    },
  );
}
