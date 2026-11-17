import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

/// A rich, cursor-capable profile: 40 columns so the stage and its guidance
/// wrap, 12 rows so the stage fits, and ASCII glyphs so the bytes stay readable
/// in any terminal.
final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 40, rows: 12),
  glyphs: GlyphSet.ascii,
);

/// The rewind a rich repaint emits: the cursor moves up over the lines the
/// previous presentation drew, then the region below it is cleared.
final _rewind = RegExp(r'\x1b\[(\d+)A\x1b\[J');

final _heading = RegExp(RegExp.escape('Pick Select: 3 choices.'));

Future<String> _render(
  PromptMode mode,
  String answer, {
  PromptStructure structure = PromptStructure.box,
}) async {
  final out = StringBuffer();
  final result =
      await Select<String>('Pick', [
        Choice('a', 'Alpha'),
        Choice('b', 'Beta'),
        Choice('c', 'Gamma'),
      ], structure: structure).prompt(
        source: ScriptedInput(
          Stream.value(answer),
          out,
          outputProfile: _richProfile,
        ),
        mode: mode,
      );
  expect((result as Accepted<String>).value, 'c');
  return out.toString();
}

/// Asserts every presentation of a repainted stage is one copy of the list and
/// that each rewind covers exactly the lines the presentation before it drew.
void _expectRepaintsInPlace(String transcript, {required int frames}) {
  expect(
    transcript,
    contains(RegExp(r'\x1b\[\d+A\x1b\[J')),
    reason: 'a rich repaint must rewind the region it drew',
  );
  final parts = transcript.split(_rewind);
  final rewinds = [
    for (final match in _rewind.allMatches(transcript)) match.group(1),
  ];
  expect(parts, hasLength(frames), reason: 'each presentation is one frame');
  expect(rewinds, hasLength(frames - 1), reason: 'one rewind per repaint');
  for (var i = 0; i < parts.length; i++) {
    // Each presentation draws the list once: the previous copy is not still on
    // the screen underneath it.
    expect(
      _heading.allMatches(parts[i]),
      hasLength(1),
      reason: 'frame $i must draw the heading once',
    );
    if (i == parts.length - 1) continue;
    // The rewind covers every line the frame before it drew — including the
    // choice rows a line-prefix structure writes itself — so the repaint starts
    // where that frame started instead of part way into it.
    expect(
      rewinds[i],
      '${'\n'.allMatches(parts[i]).length}',
      reason: 'frame $i must rewind over every line it drew',
    );
  }
}

void main() {
  test('a framed rich stage is rewound and repainted in place', () async {
    // Two down-arrows focus the list three times in all, then Enter accepts the
    // focused choice.
    _expectRepaintsInPlace(
      await _render(PromptMode.rich, '\x1b[B\x1b[B\r'),
      frames: 3,
    );
  });

  test('a line-prefix rich stage rewinds over the rows it drew', () async {
    // A rail row is written with its own marker rather than through the spine,
    // so the rewind only covers the whole list when the row reports the lines
    // it drew.
    for (final structure in [PromptStructure.rail, PromptStructure.branch]) {
      _expectRepaintsInPlace(
        await _render(PromptMode.rich, '\x1b[B\x1b[B\r', structure: structure),
        frames: 3,
      );
    }
  });

  test('a linear re-render stays append-only', () async {
    // The same list in sequential mode. Beyond the line editor's own refreshes,
    // sequential output never rewrites what it already printed.
    final transcript = await _render(PromptMode.linear, '0\r3\r');

    expect(
      transcript,
      isNot(contains(_rewind)),
      reason: 'sequential output must never move the cursor back',
    );
    // The stage is drawn once and every later event is appended below it.
    expect(_heading.allMatches(transcript), hasLength(1));
  });
}
