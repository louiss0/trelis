import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

import '../tool/gui_evidence_probe.dart' as probe;

void main() {
  test('GUI evidence probe interleaves concurrent feedback with caret edits and help', () async {
    final input = StreamController<String>();
    final pulses = StreamController<void>();
    final output = StringBuffer();
    final profile = probe.asciiOutputProfile;
    expect(profile.colorDepth, ColorDepth.none);
    expect(profile.glyphs, GlyphSet.ascii);

    final run = probe.runGuiEvidenceProbe(
      source: ScriptedInput(input.stream, output, outputProfile: profile),
      outputProfile: profile,
      pulses: pulses.stream,
    );
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    await settle();
    // Move the caret left twice, then let one pulse land before the edit that
    // inserts at that caret, so feedback is genuinely concurrent with editing.
    input.add('\x1b[D');
    await settle();
    input.add('\x1b[D');
    await settle();
    pulses.add(null);
    await settle();
    input.add('X');
    await settle();
    pulses.add(null);
    await settle();
    input.add('\x14');
    await settle();
    pulses.add(null);
    await settle();
    input.add('\x1b');
    await settle();
    input.add('\r');
    await settle();
    input.add('SYNTHETIC\r');
    await settle();
    input.add('submit\r');
    await settle();
    await input.close();
    await pulses.close();

    expect(await run, 'accepted:alpXha;secret:accepted');
    final transcript = output.toString();
    final movedCaret = transcript.indexOf('\r\x1b[2K> alp\x1b[sha');
    final firstWrite = transcript.indexOf(
      '[status] Concurrent informational write #1',
    );
    final inserted = transcript.indexOf('\r\x1b[2K> alpX\x1b[sha');
    expect(movedCaret, isNonNegative);
    expect(
      firstWrite,
      greaterThan(movedCaret),
      reason: 'concurrent feedback lands after the caret moved',
    );
    expect(
      inserted,
      greaterThan(firstWrite),
      reason: 'the edit is still accepted after the concurrent write',
    );
    for (var pulse = 1; pulse <= 3; pulse++) {
      expect(
        RegExp(RegExp.escape('[status] Concurrent informational write #$pulse'))
            .allMatches(transcript)
            .length,
        1,
      );
    }
    expect(
      transcript,
      contains('[status] Background activity: background update 3'),
    );
    expect(
      transcript,
      contains('[status] Indexing visible GUI evidence: running, 100% (3/3)'),
    );
    // Help opens on a fresh row and its supplementary entries are display
    // lines rather than escaped controls.
    expect(transcript, isNot(contains('\x1b[uHelp:')));
    expect(transcript, contains('\r\x1b[2K\nHelp:'));
    expect(transcript, isNot(contains(r'\u{000A}')));
    expect(transcript, contains('probe,\nnot a human'));
    expect(transcript, contains('Help dismissed.'));
    expect(transcript, isNot(contains('SYNTHETIC')));
  });
}
