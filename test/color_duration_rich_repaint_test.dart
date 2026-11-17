import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

/// A rich, cursor-capable profile: 100 columns so a preview row stays one row,
/// 30 rows so the stage fits, and ASCII glyphs so the bytes stay readable.
final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
  glyphs: GlyphSet.ascii,
);

/// The marker a rail repeats on the live rows it does not enclose.
const _rail = '| ';

/// The rows one presentation of a preview rewrote below the draft row: the
/// caret is saved, every row is cleared and rewritten, and the region below is
/// cleared to the end of the screen before the caret returns to the draft.
final _region = RegExp(
  '${RegExp.escape('\x1b[s')}((?:${RegExp.escape('\n\r\x1b[2K$_rail')}'
  '[^\\n\\x1b]*)+)${RegExp.escape('\x1b[J\x1b[u')}',
);

/// One rewritten preview row inside a region, without its rail marker.
final _row = RegExp('${RegExp.escape('\r\x1b[2K$_rail')}([^\\n\\x1b]*)');

/// The bytes that release a preview: the caret parked on the editable row is
/// saved, the region below the row is cleared, and the caret returns to the
/// row so typing keeps its place.
const _release = '\x1b[s\n\r\x1b[J\x1b[u';

/// Every preview region in [transcript], as the rows it drew in order.
List<List<String>> _regions(String transcript) => [
  for (final region in _region.allMatches(transcript))
    [for (final row in _row.allMatches(region.group(0)!)) row.group(1)!],
];

/// The colour preview of a parsed draft: the value row and its hex row.
const _colourValue = 'Value: #f00. sRGB: 1.0, 0.0, 0.0. Alpha: 1.0.';
const _colourHex =
    'approximate rounded hex preview: #ff0000ff (not the stored value).';
const _colourNoDraft = 'Preview unavailable: no color entered.';
const _colourInvalid = 'Preview unavailable: draft is not a valid color.';

/// Drives a rail colour input through [keys] in [mode] and returns its bytes.
Future<String> _colour(String keys, PromptMode mode, {bool rich = true}) async {
  final out = StringBuffer();
  final result = await ColorInput('Color', structure: PromptStructure.rail)
      .prompt(
        source: ScriptedInput(
          Stream.value(keys),
          out,
          outputProfile: rich ? _richProfile : const OutputProfile(),
        ),
        mode: mode,
      );
  expect(result, isA<Accepted<ColorValue?>>());
  return out.toString();
}

/// Drives a rail duration input through [keys] in [mode] and returns its bytes.
Future<String> _duration(
  String keys,
  PromptMode mode, {
  bool rich = true,
}) async {
  final out = StringBuffer();
  final result =
      await DurationInput(
        'Span',
        durationMode: DurationInputMode.elapsed,
        structure: PromptStructure.rail,
      ).prompt(
        source: ScriptedInput(
          Stream.value(keys),
          out,
          outputProfile: rich ? _richProfile : const OutputProfile(),
        ),
        mode: mode,
      );
  expect(result, isA<Accepted<DurationValue>>());
  return out.toString();
}

void main() {
  test('a rich colour input rewrites both preview rows in place', () async {
    // Type a valid colour, invalidate it again, then correct it: the draft
    // shrinks the preview from two rows to one before it grows back, and the
    // validation retry opens the editor once more.
    final transcript = await _colour('#f00x\r\x7f\r', PromptMode.rich);

    expect(_regions(transcript), [
      [_colourNoDraft],
      [_colourInvalid],
      [_colourInvalid],
      [_colourInvalid],
      [_colourValue, _colourHex],
      // The invalidated draft draws one row, so the previous two-row preview
      // cannot still be underneath it: the region clears to the end of screen.
      [_colourInvalid],
      // The retained draft rejected by validation repaints its own preview.
      [_colourInvalid],
      [_colourValue, _colourHex],
    ]);
    // Every copy of a preview row belongs to one of those regions: no keystroke
    // appends a duplicate line to the history around the draft.
    final outside = transcript.replaceAll(_region, '');
    for (final line in [_colourValue, _colourHex, _colourInvalid]) {
      expect(
        outside,
        isNot(contains(line)),
        reason: '$line must only appear as a rewritten preview row',
      );
    }
    // The editable row keeps its own redraw and caret around the two halves of
    // the draft it saves and restores.
    expect(transcript, contains('\r\x1b[2K$_rail#f00\x1b[s\x1b[u'));
    expect(transcript, contains('\r\x1b[2K$_rail#f00x\x1b[s\x1b[u'));
    // The live rows never survive the draft they predicted: submitting releases
    // them before the editor commits its line.
    expect(transcript, endsWith('$_release\n'));
  });

  test('a rich duration input rewrites its interpretation in place', () async {
    final transcript = await _duration('1s\r', PromptMode.rich);

    expect(_regions(transcript), [
      ['Interpretation unavailable: enter a valid duration.'],
      ['Interpretation unavailable: enter a valid duration.'],
      ['Elapsed interpretation: 1000000 microseconds.'],
    ]);
    expect(
      'Elapsed interpretation: 1000000 microseconds.'.allMatches(transcript),
      hasLength(1),
    );
    expect(
      'Interpretation unavailable: enter a valid duration.'.allMatches(
        transcript,
      ),
      hasLength(2),
    );
    expect(
      transcript,
      isNot(contains('\n${_rail}Elapsed interpretation')),
      reason: 'the interpretation must not be appended to the transcript',
    );
    expect(transcript, contains('\r\x1b[2K${_rail}1s\x1b[s\x1b[u'));
    expect(transcript, endsWith('$_release\n'));
  });

  test('a linear colour input keeps its appended preview', () async {
    // The sequential transcript of the same drafts, byte for byte: the colour
    // preview is appended above the state rows the editor already writes, and
    // no rich repaint sequence appears at all.
    final transcript = await _colour('#f00\r', PromptMode.linear, rich: false);

    expect(transcript, isNot(contains('\x1b')));
    expect(
      transcript,
      '| Color (CSS sRGB color: hex, RGB, HSL, or static name). (Required).\n'
      '| Left/Right move; Home/End go to boundaries; Backspace/Delete erase; '
      'Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n'
      '\\ Exact /help and /cancel are commands. Quote a command with a '
      'backslash; double a leading backslash to enter one. Identified paste is '
      'literal.\n'
      '| $_colourNoDraft\n'
      '| Current text: \n'
      '\\ Cursor position: 0 of 0 graphemes.\n'
      '| $_colourInvalid\n'
      '| Current text: #\n'
      '\\ Cursor position: 1 of 1 graphemes.\n'
      '| $_colourInvalid\n'
      '| Current text: #f\n'
      '\\ Cursor position: 2 of 2 graphemes.\n'
      '| $_colourInvalid\n'
      '| Current text: #f0\n'
      '\\ Cursor position: 3 of 3 graphemes.\n'
      '| $_colourValue\n'
      '\\ $_colourHex\n'
      '| Current text: #f00\n'
      '\\ Cursor position: 4 of 4 graphemes.\n'
      '\n',
    );
  });

  test('a linear duration input keeps its appended interpretation', () async {
    final transcript = await _duration('1s\r', PromptMode.linear, rich: false);

    expect(transcript, isNot(contains('\x1b')));
    expect(
      transcript,
      '| Span (elapsed duration; units w d h m s ms us). (Required, maximum '
      '1024 graphemes).\n'
      '| Left/Right move; Home/End go to boundaries; Backspace/Delete erase; '
      'Enter submits. /help opens help. Escape cancels; Ctrl+C interrupts.\n'
      '\\ Exact /help and /cancel are commands. Quote a command with a '
      'backslash; double a leading backslash to enter one. Identified paste is '
      'literal.\n'
      '| Interpretation unavailable: enter a valid duration.\n'
      '| Current text: \n'
      '\\ Cursor position: 0 of 0 graphemes.\n'
      '| Interpretation unavailable: enter a valid duration.\n'
      '| Current text: 1\n'
      '\\ Cursor position: 1 of 1 graphemes.\n'
      '| Elapsed interpretation: 1000000 microseconds.\n'
      '| Current text: 1s\n'
      '\\ Cursor position: 2 of 2 graphemes.\n'
      '\n',
    );
  });

  test(
    'a linear entry with a rich profile still appends its preview',
    () async {
      // A linear mode over a cursor-capable output repaints the draft row in
      // place, but the preview stays the appended report linear mode owns: an
      // in-place preview is a rich-mode behaviour only.
      final colour = await _colour('#f00\r', PromptMode.linear);
      expect(_regions(colour), isEmpty);
      expect(colour, isNot(contains(_release)));
      expect(colour, contains('\n$_rail$_colourInvalid'));
      expect(colour, contains('\n$_rail$_colourValue'));

      final duration = await _duration('1s\r', PromptMode.linear);
      expect(_regions(duration), isEmpty);
      expect(duration, isNot(contains(_release)));
      expect(
        duration,
        contains('\n${_rail}Elapsed interpretation: 1000000 microseconds.'),
      );
    },
  );
}
