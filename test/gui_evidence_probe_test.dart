import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

import '../tool/gui_evidence_probe.dart' as probe;

void main() {
  test('GUI evidence probe interleaves concurrent feedback with caret edits and help', () async {
    final harness = _ProbeHarness();
    expect(harness.profile.colorDepth, ColorDepth.none);
    expect(harness.profile.glyphs, GlyphSet.ascii);

    final run = harness.run();
    await harness.settle();
    // Move the caret left twice, then let one pulse land before the edit that
    // inserts at that caret, so feedback is genuinely concurrent with editing.
    await harness.type('\x1b[D');
    await harness.type('\x1b[D');
    await harness.pulse();
    await harness.type('X');
    await harness.pulse();
    await harness.type('\x14');
    await harness.pulse();
    await harness.type('\x1b');
    await harness.type('\r');
    await harness.type('SYNTHETIC\r');
    await harness.type('submit\r');
    await harness.finish();

    expect(await run, 'accepted:alpXha;secret:accepted');
    final transcript = harness.output.toString();
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

  test(
    'GUI evidence probe repeats sequential prompts inside one session',
    () async {
      final harness = _ProbeHarness();

      final run = harness.run(includeSecret: false, repeats: 2);
      await harness.settle();
      await harness.type('\r');
      await harness.type('\r');
      await harness.finish();

      expect(await run, 'accepted:alpha,alpha');
      final transcript = harness.output.toString();
      expect(
        RegExp(RegExp.escape('> alpha')).allMatches(transcript).length,
        greaterThanOrEqualTo(2),
        reason: 'both prompts paint the same initial draft on their own row',
      );
    },
  );

  test(
    'GUI evidence probe validation scenario rejects once and then recovers',
    () async {
      final harness = _ProbeHarness();

      final run = harness.run(includeSecret: false, requireValue: true);
      await harness.settle();
      const rejection = 'Required: enter a non-empty value and submit again.';
      // The draft opens empty, so an immediate submit is a genuine rejection.
      await harness.type('\r');
      // The declared profile wraps at 40 columns, so compare unwrapped text.
      expect(
        harness.output.toString().replaceAll('\n', ''),
        contains(rejection),
      );
      await harness.type('beta');
      await harness.type('\r');
      await harness.finish();

      expect(await run, 'accepted:beta');
      final transcript = harness.output.toString();
      final unwrapped = transcript.replaceAll('\n', '');
      expect(
        RegExp(RegExp.escape(rejection)).allMatches(unwrapped).length,
        1,
        reason: 'exactly one rejection, then a successful submission',
      );
      expect(
        transcript.lastIndexOf('> beta'),
        greaterThan(transcript.indexOf('Required:')),
        reason: 'the recovering draft is painted after the rejection',
      );
    },
  );

  test(
    'GUI evidence probe stays quiet when the pulse interval is zero',
    () async {
      final harness = _ProbeHarness(drivePulses: false);
      final run = harness.run(includeSecret: false);
      await harness.settle();
      await harness.type('\r');
      await harness.finish();

      expect(await run, 'accepted:alpha');
      final transcript = harness.output.toString();
      expect(transcript, isNot(contains('Concurrent informational write')));
      expect(transcript, isNot(contains('background update')));
      expect(
        transcript,
        contains('[status] Background activity: waiting while help is open'),
        reason: 'the named regions still report their last known state',
      );
    },
  );

  test('GUI evidence probe refuses a non-positive repeat count', () async {
    final harness = _ProbeHarness();

    await expectLater(
      harness.run(repeats: 0),
      throwsA(
        isA<ArgumentError>()
            .having((error) => error.name, 'name', 'repeats')
            .having((error) => error.message, 'message', 'must be positive'),
      ),
    );
    await expectLater(harness.run(repeats: -2), throwsA(isA<ArgumentError>()));
  });
}

/// One scripted GUI-probe run: the controllers, profile and settling that every
/// probe scenario shares.
final class _ProbeHarness {
  _ProbeHarness({this.drivePulses = true});

  final bool drivePulses;
  final input = StreamController<String>();
  final output = StringBuffer();
  final profile = probe.asciiOutputProfile;
  StreamController<void>? _pulses;

  StreamController<void> get _pulseController =>
      _pulses ??= StreamController<void>();

  Future<String> run({
    bool includeSecret = true,
    int repeats = 1,
    bool requireValue = false,
  }) => probe.runGuiEvidenceProbe(
    source: ScriptedInput(input.stream, output, outputProfile: profile),
    outputProfile: profile,
    includeSecret: includeSecret,
    repeats: repeats,
    requireValue: requireValue,
    pulses: drivePulses ? _pulseController.stream : null,
    pulseInterval: drivePulses
        ? const Duration(milliseconds: 350)
        : Duration.zero,
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> type(String text) async {
    input.add(text);
    await settle();
  }

  Future<void> pulse() async {
    _pulseController.add(null);
    await settle();
  }

  Future<void> finish() async {
    await input.close();
    final pulses = _pulses;
    if (pulses != null) await pulses.close();
  }
}
