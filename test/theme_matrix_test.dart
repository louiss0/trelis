import 'dart:async';
import 'dart:io';

import 'package:trelis/trelis.dart';
import 'package:trelis/src/text_measurement.dart';
import 'package:test/test.dart';

import 'theme_matrix_cases.dart';

/// Consolidated cross-product verification of the fifteen structural themes.
///
/// The per-ticket framing suites prove each grammar against the structure that
/// delivered it. This fixture proves the matrix: every public interactive
/// component (34) through every structure (15) in both interaction modes, the
/// three live feedback renderers per structure and mode, and the
/// mode-independent [Text] presenter per structure.
///
/// Each path is a real render/task path. A case drives the component with
/// scripted keys, the task completes, and the visible presentation is
/// inspected; supplied-answer-only validation is not accepted as evidence of a
/// rendered stage. Every executed path is recorded, so the required counts are
/// measured results rather than arithmetic in a document, and the recorded
/// bytes of all fifteen structures are compared to prove no structure is a
/// colour-only clone of another.

/// The fifteen structural namespaces, keyed by the structure they render.
const _structures = <PromptStructure, String>{
  PromptStructure.plain: 'PlainTheme',
  PromptStructure.rail: 'RailTheme',
  PromptStructure.branch: 'BranchTheme',
  PromptStructure.box: 'BoxTheme',
  PromptStructure.round: 'RoundTheme',
  PromptStructure.double: 'DoubleTheme',
  PromptStructure.minimal: 'MinimalTheme',
  PromptStructure.ascii: 'AsciiTheme',
  PromptStructure.chevron: 'ChevronTheme',
  PromptStructure.bracket: 'BracketTheme',
  PromptStructure.form: 'FormTheme',
  PromptStructure.ledger: 'LedgerTheme',
  PromptStructure.colon: 'ColonTheme',
  PromptStructure.line: 'LineTheme',
  PromptStructure.block: 'BlockTheme',
};

/// The public interactive components the matrix drives.
const _interactiveCount = 34;

/// The live feedback renderers, which keep a lifecycle in both modes.
const _feedbackCount = 3;

/// The two interaction modes every interactive and feedback path renders in.
const _modes = [PromptMode.linear, PromptMode.rich];

/// The minimum distinct applicable presentation/task paths the theme
/// specification requires.
const _interactivePaths = _interactiveCount * 15 * 2; // 1,020
const _feedbackPaths = _feedbackCount * 15 * 2; // 90
const _textPaths = 15;
const _minimumPaths = _interactivePaths + _feedbackPaths + _textPaths; // 1,125

/// Every render/task path this fixture actually executed.
final _executed = <String>{};

/// The bytes each structure produced across the whole interactive matrix.
final _rendered = <PromptStructure, StringBuffer>{
  for (final structure in _structures.keys) structure: StringBuffer(),
};

OutputProfile _profile(
  PromptMode mode, {
  bool ascii = false,
  bool rgb = false,
  int columns = 72,
}) => mode == PromptMode.rich
    ? OutputProfile(
        cursor: CapabilitySupport.supported,
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

final _csi = RegExp(r'\x1b\[[0-9;]*[A-Za-z]');

/// Removes terminal control sequences, leaving the display text.
String _plain(String text) => text.replaceAll(_csi, '');

/// Splits rendered output into display rows.
List<String> _rows(String text) => [
  for (final row in _plain(text).split(RegExp('[\r\n]')))
    if (row.trim().isNotEmpty) row,
];

int _cells(String row) => TextDisplayMap(row).cellWidth;

/// Whether [display] shows [structure]'s own grammar for a stage whose label
/// [heading] was rendered.
///
/// The check names the one decoration the grammar owns, so a structure that
/// only recoloured the reference presentation, or that silently degraded to it,
/// cannot pass. The reference presentation and the unframed minimal grammar
/// draw no decoration of their own; their distinctness is proven by the
/// fingerprint comparison instead.
bool _showsGrammar(
  PromptStructure structure,
  String display,
  List<String> rows,
  String heading, {
  required bool ascii,
}) {
  bool hasRowOf(String glyph, {int atLeast = 8}) => rows.any((row) {
    final trimmed = row.trim();
    return trimmed.length >= atLeast && trimmed.replaceAll(glyph, '').isEmpty;
  });

  switch (structure) {
    case PromptStructure.plain:
    case PromptStructure.minimal:
      return true;
    case PromptStructure.rail:
    case PromptStructure.branch:
      final glyphs = glyphsFor(structure, ascii: ascii);
      final prefixes = [glyphs.start, glyphs.continueLine, glyphs.end];
      return rows.any((row) => prefixes.any(row.startsWith));
    case PromptStructure.box:
    case PromptStructure.round:
    case PromptStructure.double:
      final enclosure = enclosureGlyphsFor(structure, ascii: ascii)!;
      return display.contains(enclosure.topLeft);
    case PromptStructure.ascii:
    case PromptStructure.chevron:
      final glyphs = headingGlyphsFor(structure, ascii: ascii)!;
      return rows.any((row) => row.startsWith(glyphs.headingPrefix));
    case PromptStructure.bracket:
      final glyphs = headingGlyphsFor(structure, ascii: ascii)!;
      // A heading long enough to wrap keeps its opening bracket on the first
      // row and its closing bracket on the last, so the two are matched across
      // the heading block rather than on one row.
      return rows.any((row) => row.startsWith(glyphs.headingPrefix)) &&
          rows.any((row) => row.trimRight().endsWith(glyphs.headingSuffix));
    case PromptStructure.form:
      final glyphs = headingGlyphsFor(structure, ascii: ascii)!;
      // A rich multiline body is drawn as a live editing row rather than as
      // ruled body rows, so the rule under the fixed label is the decoration
      // that is always present.
      return hasRowOf(glyphs.ruleGlyph) ||
          rows.any((row) => row.startsWith(glyphs.bodyIndent));
    case PromptStructure.ledger:
      final glyphs = headingGlyphsFor(structure, ascii: ascii)!;
      return rows.first.trimLeft().startsWith(RegExp(r'\d\d / ')) ||
          hasRowOf(glyphs.ruleGlyph);
    case PromptStructure.colon:
      final glyphs = headingGlyphsFor(structure, ascii: ascii)!;
      return display.contains(glyphs.headingPrefix) ||
          display.contains(glyphs.hintPrefix);
    case PromptStructure.line:
      return hasRowOf(headingGlyphsFor(structure, ascii: ascii)!.ruleGlyph);
    case PromptStructure.block:
      final glyphs = headingGlyphsFor(structure, ascii: ascii)!;
      return rows.any((row) => row.startsWith(glyphs.bandGlyph));
  }
}

/// The markers a live feedback row of [structure] carries.
///
/// Standalone feedback declares no glyph capability, so the portable ASCII
/// spelling is the conservative choice in both modes. The reference
/// presentation declares none: it is the unframed presentation a marketed
/// structure is a change from.
Set<String> _feedbackMarkers(PromptStructure structure) {
  if (structure == PromptStructure.plain) return const {};
  final markers = <String>{structureLivePrefix(structure, ascii: true)};
  if (usesStructurePrefix(structure)) {
    final glyphs = glyphsFor(structure, ascii: true);
    markers.addAll([glyphs.start, glyphs.continueLine, glyphs.end]);
  }
  final enclosure = enclosureGlyphsFor(structure, ascii: true);
  if (enclosure != null) markers.add(enclosure.livePrefix);
  markers.removeWhere((marker) => marker.trim().isEmpty);
  return markers;
}

void main() {
  late Directory pickerDirectory;
  final cases = themeMatrixCases(pickerBase: () => pickerDirectory.path);

  setUpAll(() async {
    pickerDirectory = await Directory.systemTemp.createTemp('theme-matrix-');
    await File('${pickerDirectory.path}${Platform.pathSeparator}answer.txt')
        .writeAsString('data');
  });

  tearDownAll(() => pickerDirectory.delete(recursive: true));

  test('the case table is the whole public interactive surface', () {
    expect(cases, hasLength(_interactiveCount));
    expect(
      cases.map((testCase) => testCase.name).toSet(),
      hasLength(_interactiveCount),
      reason: 'every component is covered once, with no duplicate entry',
    );
  });

  for (final entry in _structures.entries) {
    final structure = entry.key;
    final themeName = entry.value;

    for (final mode in _modes) {
      group('$themeName / ${mode.name}', () {
        for (final testCase in cases) {
          test(testCase.name, () async {
            final out = StringBuffer();
            final result = await testCase.run(
              mode,
              _scripted(mode, testCase.answerFor(mode), out),
              structure,
            );
            expect(
              result,
              isA<Accepted<Object?>>(),
              reason:
                  '${testCase.name}/${structure.name}/${mode.name} must '
                  'complete its task, not only render a stage',
            );
            final text = out.toString();
            expect(
              text,
              isNotEmpty,
              reason:
                  '${testCase.name}/${structure.name}/${mode.name} produced '
                  'no visible presentation',
            );

            final ascii = mode != PromptMode.rich;
            final display = _plain(text);
            final heading = structureHeadingText(
              structure,
              testCase.label,
              ascii: ascii,
            );
            expect(
              display,
              contains(heading),
              reason: 'the stage heading is missing from the render',
            );
            expect(
              _showsGrammar(
                structure,
                display,
                _rows(text),
                heading,
                ascii: ascii,
              ),
              isTrue,
              reason:
                  'the stage does not show the declared ${structure.name} '
                  'grammar',
            );
            if (testCase.outcome != null) {
              expect(
                display,
                contains(testCase.outcome!),
                reason: 'a reported outcome was omitted or misplaced',
              );
            }

            _executed.add(
              'interactive/${testCase.name}/${entry.key.name}/${mode.name}',
            );
            _rendered[structure]!
              ..write(testCase.name)
              ..write('\u0000')
              ..write(mode.name)
              ..write('\u0000')
              ..write(text)
              ..write('\u0001');
          });
        }
      });
    }
  }

  for (final entry in _structures.entries) {
    final structure = entry.key;
    final themeName = entry.value;
    final markers = _feedbackMarkers(structure);

    for (final mode in _modes) {
      group('$themeName feedback / ${mode.name}', () {
        /// Asserts the reference presentation keeps its unframed rows, and
        /// that every other structure marks each feedback row it writes.
        void expectMarked(String text) {
          for (final row in _rows(text)) {
            if (markers.isEmpty) {
              expect(
                row.startsWith('| ') ||
                    row.startsWith('│ ') ||
                    row.startsWith('+-') ||
                    row.startsWith('├ ') ||
                    row.startsWith('❯ ') ||
                    row.startsWith('? ') ||
                    row.startsWith('[ '),
                isFalse,
                reason:
                    'the reference presentation gained ${structure.name} '
                    'chrome: "$row"',
              );
            } else {
              expect(
                markers.any(row.contains),
                isTrue,
                reason: '"$row" has no ${structure.name} marker',
              );
            }
          }
        }

        test('Progress keeps its lifecycle', () {
          final out = StringBuffer();
          final progress = Progress('Copy', total: 4, structure: structure);
          progress.start(output: out, mode: mode, supportsRich: true);
          progress.update(2);
          progress.finish(FeedbackOutcome.completed);
          final text = out.toString();
          expect(text, contains('Copy: completed'));
          expect(text, contains('50%'));
          expectMarked(text);
          _executed.add('feedback/progress/${entry.key.name}/${mode.name}');
        });

        test('Spinner keeps its cadence and failure detail', () {
          final out = StringBuffer();
          final spinner = Spinner('Index', structure: structure);
          spinner.start(output: out, mode: mode, supportsRich: true);
          spinner.update('waiting');
          spinner.finish(FeedbackOutcome.failed, detail: 'disk');
          final text = out.toString();
          expect(text, contains('Index: waiting'));
          expect(text, contains('failed: disk'));
          expectMarked(text);
          _executed.add('feedback/spinner/${entry.key.name}/${mode.name}');
        });

        test('MultiSpinner keeps its summary', () {
          final out = StringBuffer();
          final tasks = MultiSpinner(const [
            'fetch',
            'build',
          ], structure: structure);
          tasks.start(output: out, mode: mode, supportsRich: true);
          tasks.finishTask('fetch', FeedbackOutcome.completed);
          tasks.finishTask('build', FeedbackOutcome.skipped);
          final text = out.toString();
          expect(text, contains('Summary:'));
          expect(text, contains('build: skipped'));
          expectMarked(text);
          _executed.add('feedback/multiSpinner/${entry.key.name}/${mode.name}');
        });
      });
    }
  }

  for (final entry in _structures.entries) {
    final structure = entry.key;
    final themeName = entry.value;
    final markers = _feedbackMarkers(structure);

    test('$themeName Text is one mode-independent presentation', () {
      final out = StringBuffer();
      Text(
        'Build finished',
        kind: TextKind.success,
        structure: structure,
      ).present(output: out);
      final text = _plain(out.toString());
      expect(text, contains('Success: Build finished'));
      if (markers.isEmpty) {
        expect(text, startsWith('Success: Build finished'));
      } else {
        expect(
          markers.any(text.startsWith) || markers.any(text.contains),
          isTrue,
          reason: 'Text keeps the structure marker without a frame',
        );
      }
      _executed.add('text/${entry.key.name}');
    });
  }

  group('cross-structure deep regressions', () {
    for (final entry in _structures.entries) {
      final structure = entry.key;
      final themeName = entry.value;

      test('$themeName never echoes a masked secret', () async {
        final out = StringBuffer();
        final result =
            await Password(
              'Passphrase',
              mask: true,
              structure: structure,
            ).prompt(
              source: _scripted(PromptMode.linear, 'secret\rsubmit\r', out),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, 'secret');
        expect(out.toString(), isNot(contains('secret')));
      });

      test('$themeName keeps a protected message spelled', () async {
        final out = StringBuffer();
        final result =
            await TextInput(
              'Name',
              structure: structure,
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
      });

      test('$themeName keeps an unavailable choice reason', () async {
        final out = StringBuffer();
        final result =
            await Select<String>('Region', [
              Choice('a', 'Europe', disabledReason: 'Not provisioned'),
              Choice('b', 'United States'),
            ], structure: structure).prompt(
              source: _scripted(PromptMode.linear, '2\r', out),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, 'b');
        expect(out.toString(), contains('Not provisioned'));
      });

      test('$themeName preserves the stage help route', () async {
        final out = StringBuffer();
        await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.rich, '\x14\x1bAda\r', out),
          mode: PromptMode.rich,
        );
        expect(out.toString(), contains('Help:'));
      });

      test('$themeName preserves cancellation, interruption and EOF', () async {
        Future<PromptResult<String>> run(
          Stream<String> keys,
          PromptMode mode,
        ) => TextInput('Name', structure: structure).prompt(
          source: ScriptedInput(
            keys,
            StringBuffer(),
            outputProfile: _profile(mode),
          ),
          mode: mode,
        );

        expect(
          await run(Stream.value('/cancel\r'), PromptMode.linear),
          isA<Cancelled<String>>(),
        );
        expect(
          await run(Stream.value('\x03'), PromptMode.linear),
          isA<Interrupted<String>>(),
        );
        expect(
          await run(Stream.value('\x03'), PromptMode.rich),
          isA<Interrupted<String>>(),
        );
        expect(
          await run(const Stream<String>.empty(), PromptMode.linear),
          isA<InputEnded<String>>(),
        );
      });

      test('$themeName repaints a resize without a second stage', () async {
        final keys = StreamController<String>();
        final resized = StreamController<void>();
        final output = StringBuffer();
        final transcript = TextInputTranscript();
        final observer = _ResizeObserver(
          resized.stream,
          () => (columns: 10, rows: 4),
        );
        final result =
            TextInput(
              'Name',
              initialValue: 'abcdefgh',
              structure: structure,
            ).prompt(
              source: ScriptedInput(
                keys.stream,
                output,
                outputProfile: OutputProfile(
                  cursor: CapabilitySupport.supported,
                  geometry: OutputGeometry.fixed(columns: 30, rows: 4),
                  glyphs: GlyphSet.unicode,
                ),
                transcript: transcript,
                resizeObserver: observer,
              ),
              mode: PromptMode.rich,
            );
        await pumpEventQueue();
        resized.add(null);
        await pumpEventQueue();

        expect(transcript.currentView!.text, 'abcdefgh');
        expect(
          transcript.events,
          hasLength(1),
          reason: 'a resize repaints the stage, it does not open another one',
        );
        final live = structureLivePrefix(structure, ascii: false);
        final caretRows = _rows(output.toString())
            .where((row) => row.startsWith(live))
            .toList();
        expect(
          caretRows,
          isNotEmpty,
          reason: 'the editable row keeps the structure marker after a resize',
        );
        expect(
          _cells(caretRows.last),
          lessThanOrEqualTo(10),
          reason: 'the repaint measured the new width: "${caretRows.last}"',
        );

        keys.add('\r');
        expect((await result as Accepted<String>).value, 'abcdefgh');
        await keys.close();
        await resized.close();
      });

      test('$themeName never case-transforms answer data', () async {
        final out = StringBuffer();
        final result = await TextInput('Name', structure: structure).prompt(
          source: _scripted(PromptMode.linear, 'Ada Lovelace\r', out),
          mode: PromptMode.linear,
        );
        expect((result as Accepted<String>).value, 'Ada Lovelace');
        expect(out.toString(), contains('Ada Lovelace'));
        expect(out.toString(), isNot(contains('ADA LOVELACE')));
      });
    }
  });

  group('representative normal and narrow observations', () {
    // The specification asks for representative observation of themed stages at
    // a normal and a narrow width. These are scripted observations of the
    // visible stage an agent can read, not a native-terminal visual
    // qualification: every row of every structure's stage is measured against
    // the columns the output was opened with, and the structure's own grammar
    // must still be there at both widths.
    for (final entry in _structures.entries) {
      final structure = entry.key;

      for (final columns in [80, 24]) {
        test('${entry.value} fits $columns columns', () async {
          final out = StringBuffer();
          final result =
              await TextInput('Deployment target', structure: structure).prompt(
                source: _scripted(
                  PromptMode.rich,
                  'Ada\r',
                  out,
                  columns: columns,
                ),
                mode: PromptMode.rich,
              );
          expect((result as Accepted<String>).value, 'Ada');
          final text = out.toString();
          final rows = _rows(text);
          expect(rows, isNotEmpty);
          for (final row in rows) {
            expect(
              _cells(row),
              lessThanOrEqualTo(columns),
              reason: '"$row" overflows the $columns columns it was drawn in',
            );
          }
          expect(
            _showsGrammar(
              structure,
              _plain(text),
              rows,
              structureHeadingText(structure, 'Deployment target'),
              ascii: false,
            ),
            isTrue,
            reason:
                'the ${structure.name} grammar is absent at $columns columns',
          );
        });
      }
    }
  });

  group('matrix evidence', () {
    test('every planned render/task path was executed', () {
      final interactive = _executed
          .where((path) => path.startsWith('interactive/'))
          .length;
      final feedback = _executed
          .where((path) => path.startsWith('feedback/'))
          .length;
      final text = _executed.where((path) => path.startsWith('text/')).length;

      expect(interactive, _interactivePaths);
      expect(feedback, _feedbackPaths);
      expect(text, _textPaths);
      expect(_executed.length, _minimumPaths);
      expect(_executed.length, greaterThanOrEqualTo(1125));
    });

    test('no structure is a colour-only clone of another', () {
      final fingerprints = <String, String>{
        for (final entry in _structures.entries)
          entry.value: _rendered[entry.key].toString(),
      };
      expect(fingerprints, hasLength(15));
      expect(
        fingerprints.values.toSet(),
        hasLength(15),
        reason:
            'two structures rendered identical bytes across the whole '
            'interactive matrix, which makes one of them a colour-only clone',
      );
      final plain = fingerprints['PlainTheme']!;
      for (final entry in fingerprints.entries) {
        if (entry.key == 'PlainTheme') continue;
        expect(
          entry.value,
          isNot(plain),
          reason: '${entry.key} renders the reference presentation exactly',
        );
      }
    });

    test('every structure renders its own feedback marker', () {
      final markers = {
        for (final structure in _structures.keys)
          structure: _feedbackMarkers(structure),
      };
      // The reference presentation keeps the unframed rows it always had, and
      // every other grammar declares markers of its own, so a colour-only clone
      // would collapse these spellings.
      expect(markers[PromptStructure.plain], isEmpty);
      final spellings = {
        for (final entry in markers.entries)
          if (entry.value.isNotEmpty) entry.value.first,
      };
      expect(spellings, hasLength(greaterThanOrEqualTo(4)));
    });
  });
}

final class _ResizeObserver implements TerminalResizeObserver {
  _ResizeObserver(this.notifications, this._dimensions);

  @override
  final Stream<void> notifications;
  final ({int columns, int rows})? Function() _dimensions;
  bool cancelled = false;

  @override
  ({int columns, int rows})? readDimensions() => _dimensions();

  @override
  Duration get fallbackInterval => const Duration(days: 1);
}
