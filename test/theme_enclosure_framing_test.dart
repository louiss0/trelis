import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:prompty/src/text_measurement.dart';
import 'package:test/test.dart';

/// Verification of the box, rounded and double enclosure grammars.
///
/// Behavior, accepted values, input bindings and outcomes are covered by the
/// per-component suites and the factory matrices. These tests assert the
/// presentation contract instead: an enclosure frames the stage it renders, the
/// compact hint stays outside the bottom rule, the frame counts its own chrome
/// against the declared width, capability chooses the ASCII counterpart, and a
/// palette override styles the frame without changing the answer.

OutputProfile _profile(
  PromptMode mode, {
  bool ascii = false,
  bool rgb = false,
  int columns = 72,
}) => mode == PromptMode.rich
    ? OutputProfile(
        cursor: CapabilitySupport.supported,
        styles: CapabilitySupport.supported,
        colorDepth: rgb ? ColorDepth.rgb : ColorDepth.none,
        geometry: OutputGeometry.fixed(columns: columns, rows: 20),
        glyphs: ascii ? GlyphSet.ascii : GlyphSet.unicode,
      )
    : OutputProfile(
        colorDepth: rgb ? ColorDepth.rgb : ColorDepth.none,
        geometry: OutputGeometry.fixed(columns: columns, rows: 20),
        glyphs: ascii ? GlyphSet.ascii : GlyphSet.automatic,
      );

ScriptedInput _scripted(
  PromptMode mode,
  String data,
  StringSink out, {
  bool ascii = false,
  bool rgb = false,
  int columns = 72,
}) => ScriptedInput(
  Stream.value(data),
  out,
  outputProfile: _profile(mode, ascii: ascii, rgb: rgb, columns: columns),
);

/// Splits output into display lines, dropping rich repaint carriage returns.
List<String> _lines(String text) => [
  for (final line in text.split('\n'))
    if (line.isNotEmpty) line.replaceFirst(RegExp(r'^\r+'), ''),
];

int _cells(String line) => TextDisplayMap(line).cellWidth;

/// The enclosure vocabulary a theme must draw for one capability profile.
({
  String topLeft,
  String topRight,
  String bottomLeft,
  String bottomRight,
  String horizontal,
  String vertical,
})
_expected(PromptStructure structure, {required bool ascii}) {
  final glyphs = enclosureGlyphsFor(structure, ascii: ascii)!;
  return (
    topLeft: glyphs.topLeft,
    topRight: glyphs.topRight,
    bottomLeft: glyphs.bottomLeft,
    bottomRight: glyphs.bottomRight,
    horizontal: glyphs.horizontal,
    vertical: glyphs.vertical,
  );
}

class _Case {
  const _Case(this.name, this.label, this.answer, this.run, {this.richAnswer});

  final String name;
  final String label;
  final String answer;
  final String? richAnswer;
  final Future<Object?> Function(
    PromptMode mode,
    ScriptedInput input,
    PromptStructure structure,
  )
  run;

  String answerFor(PromptMode mode) =>
      mode == PromptMode.rich ? (richAnswer ?? answer) : answer;
}

List<_Case> _cases() => [
  _Case(
    'TextInput',
    'Deployment target',
    'Ada\r',
    (mode, input, structure) => TextInput(
      'Deployment target',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'Password',
    'Passphrase',
    'secret\rsubmit\r',
    (mode, input, structure) => Password(
      'Passphrase',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'Confirm',
    'Decision',
    'yes\r',
    (mode, input, structure) => Confirm(
      'Decision',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'y\r',
  ),
  _Case(
    'Multiline',
    'Notes',
    'abc\r/done\r',
    (mode, input, structure) => Multiline(
      'Notes',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'abc\t\r',
  ),
  _Case(
    'Select',
    'Choice',
    '2\r',
    (mode, input, structure) => Select<String>('Choice', [
      Choice('a', 'First'),
      Choice('b', 'Second'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B\r',
  ),
  _Case(
    'MultiSelect',
    'Choices',
    '2\r1\r/done\r',
    (mode, input, structure) => MultiSelect<String>('Choices', [
      Choice('a', 'Alpha'),
      Choice('b', 'Beta'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B \x1b[A \r',
  ),
  _Case(
    'Slider',
    'Volume',
    '\x7f\x7f\x7f0.6\r',
    (mode, input, structure) => Slider(
      'Volume',
      minimum: '0',
      maximum: '1',
      step: '0.2',
      initialValue: '0.4',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '\x1b[C\t\t\r',
  ),
  _Case(
    'NumberInput',
    'Count',
    '12\r',
    (mode, input, structure) => NumberInput(
      'Count',
      convention: NumericConvention.ascii(),
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'DateInput',
    'Date',
    '29/02/2024\r/submit\r',
    (mode, input, structure) => DateInput(
      'Date',
      order: DateFieldOrder.dayMonthYear,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  _Case(
    'TagInput',
    'Tags',
    'NewTag\r/done\r',
    (mode, input, structure) => TagInput(
      'Tags',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'NewTag\r\t\r',
  ),
  _Case(
    'Keypress',
    'Shortcut',
    '/capture\ra/done\r',
    (mode, input, structure) => Keypress(
      'Shortcut',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'ca\r',
  ),
  _Case(
    'PathInput',
    'Path',
    '\r\r',
    (mode, input, structure) => PathInput(
      'Path',
      initialValue: 'draft',
      allowNonexistent: true,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
];

/// Runs one case through a structural theme's rendered structure.
Future<String> _render(
  _Case testCase,
  PromptMode mode,
  PromptStructure structure, {
  bool ascii = false,
  int columns = 72,
}) async {
  final out = StringBuffer();
  final result = await testCase.run(
    mode,
    _scripted(
      mode,
      testCase.answerFor(mode),
      out,
      ascii: ascii,
      columns: columns,
    ),
    structure,
  );
  expect(result, isNot(isA<Unavailable<Object?>>()));
  return out.toString();
}

/// Asserts the enclosing grammar of one rendered stage.
void _expectEnclosed(
  String text, {
  required PromptStructure structure,
  required bool ascii,
  required String label,
  required int columns,
}) {
  final expected = _expected(structure, ascii: ascii);
  final lines = _lines(text);
  expect(lines, isNotEmpty);
  expect(
    lines.first,
    startsWith(expected.topLeft),
    reason: 'the stage opens with the enclosure top rule',
  );
  expect(
    lines.first,
    endsWith(expected.topRight),
    reason: 'the top rule closes at the declared width',
  );
  expect(
    text,
    contains('${expected.bottomLeft}${expected.horizontal}'),
    reason: 'the enclosure has a bottom rule',
  );
  expect(text, contains(label), reason: 'the stage keeps its label');
  // Every framed line carries the same total width, which is the frame width.
  final frameWidth = _cells(lines.first);
  for (final line in lines.where((line) => !line.contains('\x1b'))) {
    expect(_cells(line), lessThanOrEqualTo(columns));
  }
  final bodyRows = lines.where((line) => line.startsWith(expected.vertical));
  expect(bodyRows, isNotEmpty, reason: 'the frame has body rows');
  for (final line in bodyRows) {
    expect(
      _cells(line),
      frameWidth,
      reason: 'body row "$line" keeps the frame width',
    );
    expect(
      line.endsWith(expected.vertical),
      isTrue,
      reason: 'body row "$line" closes at the right rule',
    );
  }
  // The compact hint is outside a bottom rule. Rich repaints can draw more than
  // one frame, so the contract is that some closed frame is followed by an
  // indented outside block, never that the hint continues the frame.
  bool isRule(String line) =>
      (line.startsWith(expected.bottomLeft) ||
          line.startsWith(expected.topLeft)) &&
      line.contains(expected.horizontal * 3) &&
      !line.contains('\x1b');
  final rules = [
    for (var index = 0; index < lines.length; index++)
      if (isRule(lines[index])) index,
  ];
  expect(rules, isNotEmpty, reason: 'the frame closes');
  final closes = rules.any((index) {
    final after = lines.skip(index + 1).where((line) => line.isNotEmpty);
    return after.isNotEmpty &&
        after.first.startsWith('  ') &&
        !after.first.startsWith(expected.vertical);
  });
  expect(
    closes,
    isTrue,
    reason: 'the compact hint is indented outside the bottom rule',
  );
}

const _themes = <PromptStructure, String>{
  PromptStructure.box: 'BoxTheme',
  PromptStructure.round: 'RoundTheme',
  PromptStructure.double: 'DoubleTheme',
};

void main() {
  for (final entry in _themes.entries) {
    final structure = entry.key;
    final themeName = entry.value;

    for (final mode in [PromptMode.linear, PromptMode.rich]) {
      group('$themeName encloses every component / ${mode.name}', () {
        for (final testCase in _cases()) {
          test(testCase.name, () async {
            final text = await _render(testCase, mode, structure);
            _expectEnclosed(
              text,
              structure: structure,
              ascii: mode != PromptMode.rich,
              label: testCase.label,
              columns: 72,
            );
          });
        }
      });
    }

    test(
      '$themeName uses its Unicode vocabulary when the profile supports it',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.rich, 'Ada\r', out),
          mode: PromptMode.rich,
        );
        final expected = _expected(structure, ascii: false);
        expect(out.toString(), contains(expected.topLeft));
        expect(out.toString(), contains(expected.bottomRight));
        expect(out.toString(), isNot(contains('+-')));
      },
    );

    test(
      '$themeName falls back to ASCII for an automatic glyph profile',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.linear, 'Ada\r', out),
          mode: PromptMode.linear,
        );
        final expected = _expected(structure, ascii: true);
        expect(out.toString(), contains(expected.topLeft));
        expect(out.toString(), contains(expected.bottomRight));
        expect(out.toString(), isNot(contains('┌')));
        expect(out.toString(), isNot(contains('╭')));
        expect(out.toString(), isNot(contains('╔')));
        expect(out.toString(), isNot(contains('│')));
      },
    );

    test('$themeName never exceeds the 80-column total width cap', () async {
      final out = StringBuffer();
      await Select<String>('Region', [
        Choice('a', 'Europe'),
        Choice('b', 'United States'),
      ], structure: structure).prompt(
        source: _scripted(PromptMode.rich, '\r', out, columns: 200),
        mode: PromptMode.rich,
      );
      final lines = _lines(out.toString());
      expect(_cells(lines.first), 80);
      for (final line in lines) {
        expect(line, isNot(contains('[2K')));
        if (line.contains('\x1b')) continue;
        expect(_cells(line), lessThanOrEqualTo(80));
      }
    });

    test(
      '$themeName narrow output keeps every line inside the columns',
      () async {
        final out = StringBuffer();
        await Select<String>('Region', [
          Choice('a', 'A deliberately long choice label that must wrap'),
        ], structure: structure).prompt(
          source: _scripted(PromptMode.linear, '1\r', out, columns: 24),
          mode: PromptMode.linear,
        );
        for (final line in _lines(out.toString())) {
          if (line.contains('\x1b')) continue;
          expect(_cells(line), lessThanOrEqualTo(24));
        }
      },
    );

    test(
      '$themeName simplifies to its left rule when width cannot frame',
      () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.linear, 'Ada\r', out, columns: 8),
          mode: PromptMode.linear,
        );
        final expected = _expected(structure, ascii: true);
        final text = out.toString();
        for (final line in _lines(text)) {
          if (line.contains('\x1b')) continue;
          expect(
            line.startsWith(expected.topLeft),
            isFalse,
            reason: 'narrow output draws no top rule',
          );
          expect(
            line.startsWith(expected.bottomLeft),
            isFalse,
            reason: 'narrow output draws no bottom rule',
          );
          expect(_cells(line), lessThanOrEqualTo(8));
        }
        expect(text, contains('${expected.vertical[0]} '));
        expect(text, contains('Name'));
      },
    );

    test(
      '$themeName keeps a palette border without changing the answer',
      () async {
        final palette = ColorThemes.signal.copyWith(
          border: TerminalColor.rgb(12, 34, 56),
        );
        final out = StringBuffer();
        final result =
            await TextInput(
              'Name',
              structure: structure,
              colors: palette,
            ).prompt(
              source: _scripted(PromptMode.rich, 'Ada\r', out, rgb: true),
              mode: PromptMode.rich,
            );
        expect((result as Accepted<String>).value, 'Ada');
        expect(out.toString(), contains('\x1b[38;2;12;34;56;'));
      },
    );
  }

  group('enclosure vocabulary', () {
    test('only the three enclosure structures have enclosure glyphs', () {
      for (final structure in PromptStructure.values) {
        final encloses =
            structure == PromptStructure.box ||
            structure == PromptStructure.round ||
            structure == PromptStructure.double;
        expect(usesStructureEnclosure(structure), encloses);
        expect(enclosureGlyphsFor(structure, ascii: false) != null, encloses);
        expect(enclosureGlyphsFor(structure, ascii: true) != null, encloses);
        expect(
          usesStructureFraming(structure),
          encloses || usesStructurePrefix(structure),
          reason: '$structure',
        );
      }
    });

    test('the ASCII counterparts match the approved portable spellings', () {
      final box = enclosureGlyphsFor(PromptStructure.box, ascii: true)!;
      expect(
        [box.topLeft, box.topRight, box.bottomLeft, box.bottomRight],
        ['+', '+', '+', '+'],
      );
      expect(box.horizontal, '-');
      expect(box.vertical, '|');

      final round = enclosureGlyphsFor(PromptStructure.round, ascii: true)!;
      expect(round.topLeft, '.');
      expect(round.topRight, '.');
      expect(round.bottomLeft, "'");
      expect(round.bottomRight, "'");
      expect(round.horizontal, '-');
      expect(round.vertical, '|');

      final double = enclosureGlyphsFor(PromptStructure.double, ascii: true)!;
      expect(double.horizontal, '=');
      expect(double.vertical, '||');
      expect(double.verticalCells, 2);
    });

    test('the Unicode vocabulary is the declared enclosure grammar', () {
      final box = enclosureGlyphsFor(PromptStructure.box, ascii: false)!;
      expect([box.topLeft, box.topRight, box.horizontal], ['┌', '┐', '─']);
      expect([box.bottomLeft, box.bottomRight, box.vertical], ['└', '┘', '│']);

      final round = enclosureGlyphsFor(PromptStructure.round, ascii: false)!;
      expect([round.topLeft, round.topRight], ['╭', '╮']);
      expect([round.bottomLeft, round.bottomRight], ['╰', '╯']);

      final double = enclosureGlyphsFor(PromptStructure.double, ascii: false)!;
      expect([double.horizontal, double.vertical], ['═', '║']);
    });

    test('a framed line uses the two-cell live marker', () {
      expect(structurePrefixCells(PromptStructure.box), 2);
      expect(structureLivePrefix(PromptStructure.box, ascii: false), '│ ');
      expect(structureLivePrefix(PromptStructure.round, ascii: true), '| ');
      expect(structureLivePrefix(PromptStructure.double, ascii: false), '║ ');
      expect(structureLivePrefix(PromptStructure.double, ascii: true), '| ');
      expect(structureLivePrefix(PromptStructure.plain, ascii: false), '> ');
      expect(structureLivePrefix(PromptStructure.rail, ascii: false), '│ ');
    });

    test('composed frames keep every line at the declared total width', () {
      for (final structure in [
        PromptStructure.box,
        PromptStructure.round,
        PromptStructure.double,
      ]) {
        for (final ascii in [false, true]) {
          for (final width in [16, 40, 80]) {
            final lines = frameEnclosureLines(
              structure,
              ascii: ascii,
              title: 'Title',
              body: const ['first row', 'second row'],
              width: width,
            );
            expect(lines, hasLength(4));
            for (final line in lines) {
              expect(_cells(line), width, reason: '$structure/$ascii/$width');
            }
          }
        }
      }
    });

    test('a title that cannot fit the rule stays out of the frame top', () {
      final lines = frameEnclosureLines(
        PromptStructure.box,
        ascii: false,
        title: 'A title far wider than the frame',
        body: const [],
        width: 16,
      );
      expect(lines.first, '┌${'─' * 14}┐');
      expect(_cells(lines.first), 16);
    });

    test('composing a non-enclosure structure returns its body unchanged', () {
      expect(
        frameEnclosureLines(
          PromptStructure.rail,
          ascii: false,
          body: const ['a', 'b'],
          width: 20,
        ),
        ['a', 'b'],
      );
    });
  });

  group('enclosure content contracts', () {
    test(
      'a protected validation message stays spelled outside the frame',
      () async {
        final out = StringBuffer();
        final result =
            await BoxTheme.textInput(
              'Name',
              validate: (value) =>
                  value == 'Ada' ? null : 'Name must be Ada\u0007.',
            ).prompt(
              source: _scripted(
                PromptMode.linear,
                'Bob\r\x7f\x7f\x7fAda\r',
                out,
              ),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, 'Ada');
        expect(out.toString(), contains('Name must be Ada\\u{0007}.'));
        expect(out.toString(), contains('+---'));
      },
    );

    test('a masked password is never echoed into the frame', () async {
      final out = StringBuffer();
      final result = await DoubleTheme.password('Passphrase', mask: true)
          .prompt(
            source: _scripted(PromptMode.linear, 'secret\rsubmit\r', out),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'secret');
      expect(out.toString(), isNot(contains('secret')));
      expect(out.toString(), contains('+==='));
    });

    test('unavailable choices keep their reason inside the frame', () async {
      final out = StringBuffer();
      final result =
          await RoundTheme.select<String>('Region', [
            Choice('a', 'Europe', disabledReason: 'Not provisioned'),
            Choice('b', 'United States'),
          ]).prompt(
            source: _scripted(PromptMode.linear, '2\r', out),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'b');
      expect(out.toString(), contains('Not provisioned'));
      expect(out.toString(), contains('.'));
    });

    test('stage help keeps the enclosure grammar', () async {
      final out = StringBuffer();
      await BoxTheme.textInput('Name').prompt(
        source: _scripted(PromptMode.rich, '\x14\x1bAda\r', out),
        mode: PromptMode.rich,
      );
      expect(out.toString(), contains('Help:'));
      expect(out.toString(), contains('┌'));
      expect(out.toString(), contains('└'));
    });

    test(
      'feedback keeps its lifecycle and gains the enclosure marker',
      () async {
        final out = StringBuffer();
        BoxTheme.text(
          'Build finished',
          kind: TextKind.success,
        ).present(output: out);
        expect(
          out.toString(),
          // Standalone feedback has no declared glyph capability, so the
          // portable ASCII marker is the conservative choice.
          contains('| Success: Build finished'),
        );
      },
    );

    test('a narrow enclosure never draws a partial frame', () async {
      final out = StringBuffer();
      await RoundTheme.textInput('Name').prompt(
        source: _scripted(PromptMode.linear, 'Ada\r', out, columns: 10),
        mode: PromptMode.linear,
      );
      expect(out.toString(), isNot(contains('╭')));
      expect(out.toString(), isNot(contains('╰')));
      for (final line in _lines(out.toString())) {
        if (line.contains('\x1b')) continue;
        expect(_cells(line), lessThanOrEqualTo(10));
      }
    });
  });

  group('theme factory integration', () {
    for (final entry in _themes.entries) {
      test('${entry.value} renders its declared structure', () async {
        final out = StringBuffer();
        final result = await switch (entry.key) {
          PromptStructure.box => BoxTheme.textInput('Name').prompt(
            source: _scripted(PromptMode.rich, 'Ada\r', out),
            mode: PromptMode.rich,
          ),
          PromptStructure.round => RoundTheme.textInput('Name').prompt(
            source: _scripted(PromptMode.rich, 'Ada\r', out),
            mode: PromptMode.rich,
          ),
          _ => DoubleTheme.textInput('Name').prompt(
            source: _scripted(PromptMode.rich, 'Ada\r', out),
            mode: PromptMode.rich,
          ),
        };
        expect((result as Accepted<String>).value, 'Ada');
        _expectEnclosed(
          out.toString(),
          structure: entry.key,
          ascii: false,
          label: 'Name',
          columns: 72,
        );
      });
    }
  });

  group('behavior is unchanged by the enclosure', () {
    /// The components whose answer contract is easiest to compare across
    /// structures: text, choice, boolean, number and date.
    final probes =
        <
          String,
          Future<PromptResult<Object?>> Function(
            PromptStructure structure,
            PromptMode mode,
            ScriptedInput input,
          )
        >{
          'TextInput': (structure, mode, input) => TextInput(
            'Name',
            structure: structure,
          ).prompt(source: input, mode: mode),
          'Select': (structure, mode, input) => Select<String>('Choice', [
            Choice('a', 'First'),
            Choice('b', 'Second'),
          ], structure: structure).prompt(source: input, mode: mode),
          'Confirm': (structure, mode, input) => Confirm(
            'Decision',
            structure: structure,
          ).prompt(source: input, mode: mode),
          'Password': (structure, mode, input) => Password(
            'Passphrase',
            structure: structure,
          ).prompt(source: input, mode: mode),
        };

    final answers = <String, ({String linear, String rich})>{
      'TextInput': (linear: 'Ada\r', rich: 'Ada\r'),
      'Select': (linear: '2\r', rich: '\x1b[B\r'),
      'Confirm': (linear: 'yes\r', rich: 'y\r'),
      'Password': (linear: 'secret\r', rich: 'secret\r'),
    };

    Object? outcome(PromptResult<Object?> result) => switch (result) {
      Accepted(:final value) => ('accepted', value),
      Cancelled() => 'cancelled',
      Interrupted() => 'interrupted',
      InputEnded() => 'input-ended',
      Unavailable(:final reason) => ('unavailable', reason),
    };

    for (final probe in probes.entries) {
      test(
        '${probe.key} accepts the same outcome in every structure',
        () async {
          for (final mode in [PromptMode.linear, PromptMode.rich]) {
            final answer = mode == PromptMode.rich
                ? answers[probe.key]!.rich
                : answers[probe.key]!.linear;
            final baseline = await probe.value(
              PromptStructure.plain,
              mode,
              _scripted(mode, answer, StringBuffer()),
            );
            for (final structure in [
              PromptStructure.box,
              PromptStructure.round,
              PromptStructure.double,
            ]) {
              final themed = await probe.value(
                structure,
                mode,
                _scripted(mode, answer, StringBuffer()),
              );
              expect(
                outcome(themed),
                outcome(baseline),
                reason: '${probe.key}/${structure.name}/${mode.name}',
              );
            }
          }
        },
      );
    }

    test('the unframed structure still emits no enclosure chrome', () async {
      final out = StringBuffer();
      await TextInput('Name').prompt(
        source: _scripted(PromptMode.rich, 'Ada\r', out),
        mode: PromptMode.rich,
      );
      for (final glyph in [
        '┌',
        '┐',
        '└',
        '┘',
        '╭',
        '╮',
        '╰',
        '╯',
        '╔',
        '╗',
        '╚',
        '╝',
      ]) {
        expect(out.toString(), isNot(contains(glyph)));
      }
      expect(out.toString(), isNot(contains('+-')));
    });
  });
}
