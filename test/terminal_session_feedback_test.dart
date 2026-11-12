import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('a rich scoped session keeps live spinner and text status above an editable prompt', () async {
    final output = StringBuffer();
    final input = StreamController<String>();
    final transcript = TextInputTranscript();
    final profile = OutputProfile(
      cursor: CapabilitySupport.supported,
      alternateScreen: CapabilitySupport.unsupported,
      styles: CapabilitySupport.supported,
      colorDepth: ColorDepth.none,
      glyphs: GlyphSet.ascii,
      geometry: OutputGeometry.fixed(columns: 40, rows: 8),
    );

    final answer = await TerminalSession.run(
      (session) async {
        final spinner = Spinner('Index');
        spinner.start(session: session);
        Text(
          'Looking up suggestions',
          kind: TextKind.hint,
        ).present(session: session);
        final prompt = TextInput('Project').prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        spinner.update('reading cache');
        input.add('demo\r');
        await input.close();
        spinner.finish(FeedbackOutcome.completed);
        return (await prompt as Accepted<String>).value;
      },
      source: ScriptedInput(
        input.stream,
        output,
        supportsRich: true,
        outputProfile: profile,
        transcript: transcript,
      ),
    );

    expect(answer, 'demo');
    expect(output.toString(), contains('[status] Index: running'));
    expect(output.toString(), contains('[status] Index: reading cache'));
    expect(output.toString(), contains('Hint: Looking up suggestions'));
    expect(output.toString(), contains('[status] Index: completed'));
    expect(transcript.currentView, isNotNull);
    expect(transcript.currentView!.text, 'demo');
    expect(transcript.currentView!.caret, 4);
  });
}
