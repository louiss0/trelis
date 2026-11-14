import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

OutputProfile _profile(int rows) => OutputProfile(
  cursor: CapabilitySupport.supported,
  alternateScreen: CapabilitySupport.unsupported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.none,
  glyphs: GlyphSet.ascii,
  geometry: OutputGeometry.fixed(columns: 40, rows: rows),
);

void main() {
  test('a short rich session compacts ordered background feedback before its active prompt', () async {
    final output = StringBuffer();
    final input = StreamController<String>();
    final transcript = TextInputTranscript();

    final answer = await TerminalSession.run(
      (session) async {
        final index = Spinner('Index')..start(session: session);
        final upload = Progress('Upload', total: 10)..start(session: session);
        final tasks = MultiSpinner(['compile', 'test'])
          ..start(session: session);
        final prompt = TextInput('Project').prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        index.update('reading cache');
        upload.update(1);
        tasks.update('compile', TaskActivity.running, phase: 'building');
        input.add('demo\r');
        await input.close();
        return (await prompt as Accepted<String>).value;
      },
      source: ScriptedInput(
        input.stream,
        output,
        supportsRich: true,
        outputProfile: _profile(2),
        transcript: transcript,
      ),
    );

    expect(answer, 'demo');
    expect(transcript.currentView!.text, 'demo');
    expect(transcript.currentView!.caret, 4);
    expect(
      output.toString(),
      contains('[status] Feedback (3): Index, Upload +1'),
    );
  });

  test('short feedback keeps failures reviewable and visibly severe', () async {
    final output = StringBuffer();
    final input = StreamController<String>();

    await TerminalSession.run(
      (session) async {
        final index = Spinner('Index')..start(session: session);
        final prompt = TextInput('Project').prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        index.finish(FeedbackOutcome.failed, detail: 'offline');
        Text('Cache stale', kind: TextKind.warning).present(session: session);
        Text('Network offline', kind: TextKind.error).present(session: session);
        input.add('demo\r');
        await input.close();
        await prompt;
      },
      source: ScriptedInput(
        input.stream,
        output,
        supportsRich: true,
        outputProfile: _profile(1),
      ),
    );

    expect(output.toString(), contains('[status] Index: failed: offline'));
    expect(output.toString(), contains('[status] Warning: Cache stale'));
    expect(output.toString(), contains('[status] Error: Network offline'));
    expect(output.toString(), contains('[status] [!] Feedback (0)'));
  });

  test('a retired failure does not mark later short-screen status', () async {
    final output = StringBuffer();
    final input = StreamController<String>();

    await TerminalSession.run(
      (session) async {
        final index = Spinner('Index')..start(session: session);
        final prompt = TextInput('Project').prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        index.finish(FeedbackOutcome.failed, detail: 'offline');
        Text('Cache stale', kind: TextKind.warning).present(session: session);
        final later = Spinner('Upload')..start(session: session);
        later.update('reading');
        input.add('demo\r');
        await input.close();
        await prompt;
      },
      source: ScriptedInput(
        input.stream,
        output,
        supportsRich: true,
        outputProfile: _profile(1),
      ),
    );

    expect(output.toString(), contains('[status] [!] Feedback (0)'));
    final composed = output
        .toString()
        .split('\n')
        .lastWhere((line) => line.contains('[status] Feedback'));
    expect(
      composed.contains('[!]'),
      isFalse,
      reason: 'the severity indicator describes current feedback',
    );
    expect(composed, endsWith('[status] Feedback (1): Upload'));
  });

  test(
    'short-session composition recovers after resize without duplicate events',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      final resized = StreamController<void>();
      var rows = 1;
      final observer = _ResizeObserver(
        resized.stream,
        () => (columns: 40, rows: rows),
      );
      final transcript = TextInputTranscript();

      await TerminalSession.run(
        (session) async {
          final index = Spinner('Index')..start(session: session);
          final upload = Progress('Upload', total: 10)..start(session: session);
          final prompt = TextInput('Project').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          rows = 0;
          resized.add(null);
          resized.add(null);
          await Future<void>.delayed(Duration.zero);
          index.update('waiting for geometry');
          rows = 5;
          resized.add(null);
          await Future<void>.delayed(Duration.zero);
          index.update('reading cache');
          upload.update(1);
          input.add('demo\r');
          await input.close();
          await prompt;
        },
        source: ScriptedInput(
          input.stream,
          output,
          supportsRich: true,
          outputProfile: _profile(1),
          resizeObserver: observer,
          transcript: transcript,
        ),
      );
      await resized.close();

      expect(
        output.toString(),
        contains('[status] Feedback (2): Index, Upload'),
      );
      expect(output.toString(), contains('[status] Index: reading cache'));
      expect(
        output.toString(),
        contains('[status] Upload: running, 10% (1/10)'),
      );
      expect(transcript.currentView!.text, 'demo');
      expect(transcript.currentView!.caret, 4);
      expect(transcript.events.map((event) => event.kind), [
        TextInputPresentationEventKind.opened,
        TextInputPresentationEventKind.submitted,
      ]);
    },
  );
}

final class _ResizeObserver implements TerminalResizeObserver {
  _ResizeObserver(this.notifications, this._dimensions);

  @override
  final Stream<void> notifications;
  final ({int columns, int rows})? Function() _dimensions;

  @override
  Duration get fallbackInterval => const Duration(days: 1);

  @override
  ({int columns, int rows})? readDimensions() => _dimensions();
}
