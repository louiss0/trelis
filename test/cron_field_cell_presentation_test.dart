import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:trelis/src/text_measurement.dart';
import 'package:test/test.dart';

OutputProfile _profile({int columns = 80, GlyphSet glyphs = GlyphSet.ascii}) =>
    OutputProfile(
      cursor: CapabilitySupport.supported,
      glyphs: glyphs,
      geometry: OutputGeometry.fixed(columns: columns, rows: 24),
    );

CronPreviewConfig _config() => CronPreviewConfig(
  providerTimeout: const Duration(seconds: 5),
  zone: 'Etc/UTC',
  reference: DateTime.utc(2024),
  start: DateTime.utc(2024),
  end: DateTime.utc(2024, 1, 1, 0, 3),
  count: 1,
  budget: 3,
);

/// Renders the emitted transcript as physical terminal lines: a carriage
/// return followed by an erase-line sequence leaves only the rewritten tail
/// of that line, so a repainted editable line is measured once.
Iterable<String> _visibleLines(String text) => text
    .split('\n')
    .map(
      (line) => line
          .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '')
          .split('\r')
          .last,
    )
    .where((line) => line.isNotEmpty);

int _cells(String line) => TextDisplayMap(line).cellWidth;

final class _ResizeObserver implements TerminalResizeObserver {
  _ResizeObserver(this.notifications, this._dimensions);

  @override
  final Stream<void> notifications;
  final ({int columns, int rows})? Function() _dimensions;

  @override
  ({int columns, int rows})? readDimensions() => _dimensions();

  @override
  Duration get fallbackInterval => const Duration(days: 1);
}

void main() {
  test(
    'rich stage shows the clean label, padded cells, cue and compact hint',
    () async {
      final output = StringBuffer();
      final result = await CronInput('Schedule', profile: CronProfile.unix)
          .prompt(
            source: ScriptedInput(
              Stream.value('*\t*\t*\t*\t*\t\r'),
              output,
              outputProfile: _profile(),
            ),
            mode: PromptMode.rich,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
      );
      final text = output.toString();
      // The verbose parenthetical banner is gone from the rich stage.
      expect(text, contains('Schedule.'));
      expect(text, isNot(contains('expression limit')));
      expect(text, isNot(contains('matching preview is not configured')));
      // Symmetric cell delimiters: padded empty and filled cells.
      expect(text, contains('[   ]'));
      expect(text, contains('[ * ]'));
      // There is no trailing action stop: the row holds only field cells.
      expect(text, isNot(contains('[ Submit ]')));
      expect(text, isNot(contains('Focus:')));
      // The active-format cue tracks focus across the cells.
      expect(text, contains('unix · 1/5 minute (0-59)'));
      expect(text, contains('unix · 5/5 day-of-week'));
      // The compact hint states the primary controls and the help route.
      expect(
        text,
        contains('Tab/Shift-Tab move; Enter submits; Ctrl+T help; Esc cancels'),
      );
    },
  );

  test('preview configuration switches the cue and hint to review', () async {
    final output = StringBuffer();
    final result =
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          preview: _config(),
        ).prompt(
          source: ScriptedInput(
            Stream.value('*\t*\t*\t*\t*\t\x1b'),
            output,
            outputProfile: _profile(),
          ),
          mode: PromptMode.rich,
        );
    // The trailing Escape lands as the stream ends, so the prompt reports
    // InputEnded after the wrapped cue was emitted.
    expect(result, isA<InputEnded<CronExpression>>());
    final text = output.toString();
    expect(text, contains('unix · 1/5 minute (0-59)'));
    expect(text, isNot(contains('Focus:')));
    expect(text, contains('Enter reviews; Ctrl+T help; Esc cancels'));
  });

  test('quartz marks the optional year cell in the cue', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.quartz)
        .prompt(
          source: ScriptedInput(
            Stream.value('0\t0\t0\t?\t*\tMON\t\x1b'),
            output,
            outputProfile: _profile(),
          ),
          mode: PromptMode.rich,
        );
    // A trailing bare Escape is indistinguishable from stream end, so the
    // prompt reports InputEnded after the year cell's cue was emitted.
    expect(result, isA<InputEnded<CronExpression>>());
    expect(
      output.toString(),
      contains('quartz · 7/7 year (1970-2199, optional)'),
    );
  });

  test('the active-format cue survives hidden instructions', () async {
    final output = StringBuffer();
    await CronInput(
      'Schedule',
      profile: CronProfile.unix,
      instructions: InstructionDisplay.hidden,
    ).prompt(
      source: ScriptedInput(
        Stream.value('\x1b'),
        output,
        outputProfile: _profile(),
      ),
      mode: PromptMode.rich,
    );
    final text = output.toString();
    // The cue is protected content: it stays visible when optional
    // instructions are hidden, while the editable-controls hint does not.
    expect(text, contains('unix · 1/5 minute (0-59)'));
    expect(text, isNot(contains('Tab/Shift-Tab move')));
    expect(text, contains('Enter submits; Ctrl+T opens help.'));
  });

  test(
    'focus markers are explicit glyphs in ascii and unicode profiles',
    () async {
      Future<String> run(GlyphSet glyphs) async {
        final output = StringBuffer();
        await CronInput('Schedule', profile: CronProfile.unix).prompt(
          source: ScriptedInput(
            Stream.value('*\t'),
            output,
            outputProfile: _profile(glyphs: glyphs),
          ),
          mode: PromptMode.rich,
        );
        return output.toString();
      }

      final ascii = await run(GlyphSet.ascii);
      // An ASCII profile marks the focused cell with > and < inside the cell.
      expect(ascii, contains('[> <]'));
      expect(ascii, isNot(contains('→')));

      final unicode = await run(GlyphSet.unicode);
      // A Unicode profile uses the matching arrow markers, never colour alone.
      expect(unicode, contains('[→ ←]'));
      expect(unicode, isNot(contains('[> <]')));
    },
  );

  test(
    'the circle cell frame renders round brackets in ascii and unicode',
    () async {
      Future<String> run(GlyphSet glyphs) async {
        final output = StringBuffer();
        await CronInput(
          'Schedule',
          profile: CronProfile.unix,
          cellFrame: CronCellFrame.circle,
        ).prompt(
          source: ScriptedInput(
            // '*' fills cell0; Tab moves focus to the empty cell1.
            Stream.value('*\t'),
            output,
            outputProfile: _profile(glyphs: glyphs),
          ),
          mode: PromptMode.rich,
        );
        return output.toString();
      }

      final ascii = await run(GlyphSet.ascii);
      // Unfocused cells keep symmetric padding; the focused cell swaps the
      // inner padding for the ASCII focus markers inside round brackets.
      expect(ascii, contains('( * )'));
      expect(ascii, contains('(> <)'));
      expect(ascii, contains('(   )'));
      expect(ascii, isNot(contains('[ * ]')));
      expect(ascii, isNot(contains('[> <]')));
      expect(ascii, isNot(contains('→')));

      final unicode = await run(GlyphSet.unicode);
      expect(unicode, contains('( * )'));
      expect(unicode, contains('(→ ←)'));
      expect(unicode, isNot(contains('(> <)')));
      expect(unicode, isNot(contains('[→ ←]')));
    },
  );

  test('the circle frame reaches the theme cronInput seam', () async {
    final output = StringBuffer();
    final result =
        await PlainTheme.cronInput(
          'Schedule',
          profile: CronProfile.unix,
          cellFrame: CronCellFrame.circle,
        ).prompt(
          source: ScriptedInput(
            Stream.value('*\t*\t*\t*\t*\t\r'),
            output,
            outputProfile: _profile(),
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<CronExpression>).value.expression, '* * * * *');
    expect(output.toString(), contains('( * )'));
    expect(output.toString(), isNot(contains('[ * ]')));
  });

  test('narrow geometry wraps between whole cells without overflow', () async {
    final output = StringBuffer();
    final result = await CronInput('Schedule', profile: CronProfile.unix)
        .prompt(
          source: ScriptedInput(
            Stream.value('*\t*/15\t1-5\tJAN-MAR\tMON-FRI\t\r'),
            output,
            outputProfile: _profile(columns: 36),
          ),
          mode: PromptMode.rich,
        );
    expect(
      (result as Accepted<CronExpression>).value.expression,
      '* */15 1-5 JAN-MAR MON-FRI',
    );
    final lines = _visibleLines(output.toString()).toList();
    for (final line in lines) {
      expect(_cells(line), lessThanOrEqualTo(36), reason: 'line: $line');
    }
    // The row wrapped between cells: at least one line carries two complete
    // cell tokens and no line begins inside a cell's closing delimiter.
    expect(
      lines.any((line) => RegExp(r'\[[^\]]*\] \[[^\]]*\]').hasMatch(line)),
      isTrue,
    );
    expect(lines.any((line) => RegExp(r'^\s*\]').hasMatch(line)), isFalse);
  });

  test('narrow geometry wraps whole cells inside enclosing themes', () async {
    // The spec calls out ~40-column profiles across enclosing and rail
    // structural themes: the cell row must wrap between whole cells inside
    // the theme chrome without overflowing the declared width.
    final factories = <(String, CronInput Function(String))>[
      ('rail', (l) => RailTheme.cronInput(l, profile: CronProfile.unix)),
      ('box', (l) => BoxTheme.cronInput(l, profile: CronProfile.unix)),
      ('round', (l) => RoundTheme.cronInput(l, profile: CronProfile.unix)),
      ('double', (l) => DoubleTheme.cronInput(l, profile: CronProfile.unix)),
    ];
    for (final (name, factory) in factories) {
      final output = StringBuffer();
      final result = await factory('Schedule').prompt(
        source: ScriptedInput(
          Stream.value('*\t*/15\t1-5\tJAN-MAR\tMON-FRI\t\r'),
          output,
          outputProfile: _profile(columns: 40),
        ),
        mode: PromptMode.rich,
      );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* */15 1-5 JAN-MAR MON-FRI',
        reason: name,
      );
      final lines = _visibleLines(output.toString()).toList();
      for (final line in lines) {
        expect(_cells(line), lessThanOrEqualTo(40), reason: '$name: $line');
      }
      // Whole-cell wrapping: at least one line carries two complete cells
      // and no line begins inside a cell's closing delimiter.
      expect(
        lines.any((line) => RegExp(r'\[[^\]]*\] \[[^\]]*\]').hasMatch(line)),
        isTrue,
        reason: name,
      );
      expect(
        lines.any((line) => RegExp(r'^\s*\]').hasMatch(line)),
        isFalse,
        reason: name,
      );
    }
  });

  test('a single over-wide cell windows inside the declared width', () async {
    final output = StringBuffer();
    final wide = List.filled(20, '1-2').join(','); // 79 cells of content.
    await CronInput('Schedule', profile: CronProfile.unix).prompt(
      source: ScriptedInput(
        // Tab leaves the cell so the stage row repaints with the wide draft.
        Stream.value('\x1b[200~$wide\x1b[201~\t'),
        output,
        outputProfile: _profile(columns: 36),
      ),
      mode: PromptMode.rich,
    );
    final lines = _visibleLines(output.toString()).toList();
    for (final line in lines) {
      expect(_cells(line), lessThanOrEqualTo(36), reason: 'line: $line');
    }
    // The windowed cell keeps its delimiters and marks the hidden head.
    expect(output.toString(), contains('...'));
    expect(lines.any((line) => line.contains(']')), isTrue);
  });

  test(
    'an over-wide cell windows around the caret, not just the tail',
    () async {
      final output = StringBuffer();
      final wide = List.filled(20, '1-2').join(','); // 79 cells of content.
      final result = await CronInput('Schedule', profile: CronProfile.unix)
          .prompt(
            source: ScriptedInput(
              // Paste the wide draft, move the caret to the head with Home,
              // leave the cell and fill the rest so the wide cell repaints
              // unfocused with its caret still at the head.
              Stream.value('\x1b[200~$wide\x1b[201~\x1b[H\t*\t*\t*\t*\r'),
              output,
              outputProfile: _profile(columns: 36),
            ),
            mode: PromptMode.rich,
          );
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '$wide * * * *',
      );
      final row = _visibleLines(output.toString())
          .where((line) => line.contains('1-2') && line.contains(']'))
          .last;
      // The window keeps the head of the draft visible and marks the hidden
      // tail; a caret-at-end window would hide the head instead.
      expect(row, contains('[ 1-2,1-2,'), reason: row);
      expect(row, contains('... ]'), reason: row);
      expect(row, isNot(contains('[ ...')), reason: row);
    },
  );

  test('idle resize repaints the stage rows without touching drafts', () async {
    final keys = StreamController<String>();
    addTearDown(keys.close);
    final resized = StreamController<void>.broadcast();
    addTearDown(resized.close);
    final output = StringBuffer();
    final observer = _ResizeObserver(
      resized.stream,
      () => (columns: 30, rows: 8),
    );

    final pending = CronInput('Schedule', profile: CronProfile.unix).prompt(
      source: ScriptedInput(
        keys.stream,
        output,
        outputProfile: _profile(),
        resizeObserver: observer,
      ),
      mode: PromptMode.rich,
    );
    await pumpEventQueue();
    keys.add('*\t*\t*\t');
    await pumpEventQueue();
    final beforeResize = output.length;

    resized.add(null);
    await pumpEventQueue();

    // The stage — label, cell row, cue and hint — repaints at the new width
    // while the retained drafts stay untouched.
    final repaint = output.toString().substring(beforeResize);
    expect(repaint, contains('unix · 4/5 month'));
    expect(repaint, contains('[ * ]'));
    for (final line in _visibleLines(repaint)) {
      expect(_cells(line), lessThanOrEqualTo(30), reason: 'line: $line');
    }

    keys.add('*\t*\r');
    expect(
      (await pending as Accepted<CronExpression>).value.expression,
      '* * * * *',
    );
  });

  test('field cells compose inside every structural theme', () async {
    final cases = <(String, CronInput Function(String))>[
      ('plain', (l) => PlainTheme.cronInput(l, profile: CronProfile.unix)),
      ('rail', (l) => RailTheme.cronInput(l, profile: CronProfile.unix)),
      ('branch', (l) => BranchTheme.cronInput(l, profile: CronProfile.unix)),
      ('box', (l) => BoxTheme.cronInput(l, profile: CronProfile.unix)),
      ('round', (l) => RoundTheme.cronInput(l, profile: CronProfile.unix)),
      ('double', (l) => DoubleTheme.cronInput(l, profile: CronProfile.unix)),
      ('minimal', (l) => MinimalTheme.cronInput(l, profile: CronProfile.unix)),
      ('ascii', (l) => AsciiTheme.cronInput(l, profile: CronProfile.unix)),
      ('chevron', (l) => ChevronTheme.cronInput(l, profile: CronProfile.unix)),
      ('bracket', (l) => BracketTheme.cronInput(l, profile: CronProfile.unix)),
      ('form', (l) => FormTheme.cronInput(l, profile: CronProfile.unix)),
      ('ledger', (l) => LedgerTheme.cronInput(l, profile: CronProfile.unix)),
      ('colon', (l) => ColonTheme.cronInput(l, profile: CronProfile.unix)),
      ('line', (l) => LineTheme.cronInput(l, profile: CronProfile.unix)),
      ('block', (l) => BlockTheme.cronInput(l, profile: CronProfile.unix)),
    ];
    for (final (name, factory) in cases) {
      final output = StringBuffer();
      final result = await factory('Schedule').prompt(
        source: ScriptedInput(
          Stream.value('*\t*\t*\t*\t*\t\r'),
          output,
          outputProfile: _profile(),
        ),
        mode: PromptMode.rich,
      );
      expect(result, isA<Accepted<CronExpression>>(), reason: '$name theme');
      expect(
        (result as Accepted<CronExpression>).value.expression,
        '* * * * *',
        reason: '$name theme',
      );
      final text = output.toString();
      expect(text, contains('unix · 1/5 minute (0-59)'), reason: name);
      expect(text, contains('[ * ]'), reason: name);
      expect(text, contains('Tab/Shift-Tab move; Enter submits'), reason: name);
    }
  });
}
