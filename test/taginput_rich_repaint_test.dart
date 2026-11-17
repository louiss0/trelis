import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

/// A rich, cursor-capable profile: 40 columns so the stage guidance wraps, 12
/// rows so the stage fits, and ASCII glyphs so the bytes stay readable.
final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 40, rows: 12),
  glyphs: GlyphSet.ascii,
);

/// The marker a rail repeats on the live rows it does not enclose.
const _rail = '| ';

/// One in-place preview redraw: the cleared line, the rail marker, and the
/// canonical draft that keystroke produced.
final _previewLine = RegExp(
  '${RegExp.escape('\r\x1b[2K$_rail')}Preview: ([^\n\x1b]*)',
);

/// The bytes that release the preview: the caret parked on the editable row is
/// saved, the region below the row is cleared to the end of the screen, and the
/// caret returns to the row so typing keeps its place.
const _release = '\x1b[s\n\r\x1b[J\x1b[u';

/// Drives a rail TagInput through [keys] in rich mode and returns its bytes.
Future<String> _richRun(List<String> keys) async {
  final out = StringBuffer();
  final result = await RailTheme.tagInput('Tags').prompt(
    source: ScriptedInput(
      Stream.fromIterable(keys),
      out,
      supportsRich: true,
      outputProfile: _richProfile,
    ),
    mode: PromptMode.rich,
  );
  expect((result as Accepted<List<String>>).value, ['ab']);
  return out.toString();
}

void main() {
  test('a rich TagInput rewrites its preview under the draft row', () async {
    // Two typed keys, then Enter adds the draft as a tag, then Tab focuses
    // Finish and Enter submits the collection.
    final transcript = await _richRun(['a', 'b', '\r', '\t', '\r']);

    // Each keystroke paints its own state once, in order: the empty draft, the
    // two typed drafts, and the empty draft of the round after the tag was
    // added.
    expect(
      [for (final match in _previewLine.allMatches(transcript)) match.group(1)],
      ['', 'a', 'ab', '', ''],
    );
    // Every preview in the transcript is owned by such a redraw: no keystroke
    // appends a second copy of the line to the history above it.
    expect(
      'Preview: '.allMatches(transcript),
      hasLength(_previewLine.allMatches(transcript).length),
    );
    expect(transcript, isNot(contains('\n${_rail}Preview: ')));
    // The editable row keeps its own redraw and caret: `\r\x1b[2K` clears the
    // row and the saved caret is restored between the two halves of the draft.
    expect(transcript, contains('\r\x1b[2K${_rail}ab\x1b[s\x1b[u'));
    // The live line never survives the draft it predicted: committing the tag
    // releases it first, so the reported result follows the draft row alone.
    expect(transcript, contains('$_release\n${_rail}Added: ab'));
  });

  test('a rich TagInput previews a corrected draft in place', () async {
    // Type a tag, correct the last character, then accept it: the corrected
    // form is drawn once more into the same line, and no earlier form is still
    // on the screen underneath it.
    final transcript = await _richRun([
      'a',
      'b',
      '\x7f',
      'b',
      '\r',
      '\t',
      '\r',
    ]);

    expect(
      [for (final match in _previewLine.allMatches(transcript)) match.group(1)],
      ['', 'a', 'ab', 'a', 'ab', '', ''],
    );
    expect(
      'Preview: '.allMatches(transcript),
      hasLength(_previewLine.allMatches(transcript).length),
    );
  });

  test('a linear TagInput stays append-only and never previews', () async {
    // The sequential transcript of the same tag collection in linear mode is
    // the appended report the component always wrote: no cursor movement, no
    // cleared line, and no preview line at all.
    final out = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(Stream.value('ab\r/done\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, ['ab']);
    expect(
      out.toString(),
      'Tags: kebab-case tags. Enter adds; Ctrl+X discards the draft. '
      '/done finishes.\n'
      'Current text: \n'
      'Cursor position: 0 of 0 graphemes.\n'
      'Current text: a\n'
      'Cursor position: 1 of 1 graphemes.\n'
      'Current text: ab\n'
      'Cursor position: 2 of 2 graphemes.\n'
      '\n'
      'Added: ab\n'
      'Current text: \n'
      'Cursor position: 0 of 0 graphemes.\n'
      'Current text: /\n'
      'Cursor position: 1 of 1 graphemes.\n'
      'Current text: /d\n'
      'Cursor position: 2 of 2 graphemes.\n'
      'Current text: /do\n'
      'Cursor position: 3 of 3 graphemes.\n'
      'Current text: /don\n'
      'Cursor position: 4 of 4 graphemes.\n'
      'Current text: /done\n'
      'Cursor position: 5 of 5 graphemes.\n'
      '\n',
    );
    expect(out.toString(), isNot(contains('\x1b')));
  });
}
