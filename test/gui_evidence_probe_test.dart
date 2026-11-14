import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

import '../tool/gui_evidence_probe.dart' as probe;

void main() {
  test('GUI evidence probe retains edited text, feedback, modal help, and redacts its canary', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final profile = probe.asciiOutputProfile;
    expect(profile.colorDepth, ColorDepth.none);
    expect(profile.glyphs, GlyphSet.ascii);

    final run = probe.runGuiEvidenceProbe(
      source: ScriptedInput(input.stream, output, outputProfile: profile),
      outputProfile: profile,
    );
    const settle = Duration(milliseconds: 10);
    await Future<void>.delayed(settle);
    input.add('\x1b[D\x1b[DX\x14');
    await Future<void>.delayed(settle);
    input.add('\x1b');
    await Future<void>.delayed(settle);
    input.add('\r');
    await Future<void>.delayed(settle);
    input.add('SYNTHETIC\r');
    await Future<void>.delayed(settle);
    input.add('submit\r');
    await Future<void>.delayed(settle);
    await input.close();

    expect(await run, 'accepted:alpXha;secret:accepted');
    expect(output.toString(), contains('Help:'));
    expect(output.toString(), contains('[status]'));
    expect(output.toString(), isNot(contains('SYNTHETIC')));
  });
}
