import 'dart:async';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'standalone feedback that is still running refuses a second screen owner',
    () async {
      final output = StringBuffer();
      final spinner = Spinner('Index')
        ..start(output: output, supportsRich: false);

      await expectLater(
        TerminalSession.run(
          (session) async {},
          output: output,
          mode: PromptMode.linear,
        ),
        throwsStateError,
      );

      // A one-shot informational line is not a screen owner: it stays
      // source-compatible while standalone feedback writes the same sink.
      Text('Cache warm').present(output: output);
      spinner.dispose();

      // Retirement releases the claim, so the sink is reusable afterwards.
      await TerminalSession.run(
        (session) async {},
        output: output,
        mode: PromptMode.linear,
      );
    },
  );

  test(
    'standalone feedback regions remain source-compatible on one sink',
    () async {
      final output = StringBuffer();
      final first = Spinner('Index')
        ..start(output: output, supportsRich: false);
      final second = Progress('Upload', total: 2)
        ..start(output: output, supportsRich: false);

      first.update('reading');
      second.update(1);
      first.dispose();
      second.dispose();

      expect(output.toString(), contains('Index: reading'));
      expect(output.toString(), contains('Upload: running'));
    },
  );

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

  test('rich sessions retire multiple feedback lifecycles without losing the prompt caret', () async {
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
    late Spinner unfinished;

    final answer = await TerminalSession.run(
      (session) async {
        final spinner = Spinner('Index');
        final progress = Progress('Upload', total: 10);
        final tasks = MultiSpinner(['compile', 'test']);
        unfinished = Spinner('Watch');
        spinner.start(session: session);
        progress.start(session: session);
        tasks.start(session: session);
        unfinished.start(session: session);
        final prompt = TextInput('Project').prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        input.add('dem');
        await Future<void>.delayed(Duration.zero);

        spinner.finish(FeedbackOutcome.failed, detail: 'offline');
        progress.update(10);
        progress.phase('verifying');
        progress.dispose();
        tasks.finishTask('test', FeedbackOutcome.failed, detail: 'broken');
        tasks.finishTask('compile', FeedbackOutcome.completed);
        tasks.update('compile', TaskActivity.running, phase: 'stale');
        input.add('o\r');
        await input.close();
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
    expect(transcript.currentView!.text, 'demo');
    expect(transcript.currentView!.caret, 4);
    expect(output.toString(), contains('[status] Index: failed: offline'));
    expect(
      output.toString(),
      contains('[status] Upload: running, 100% (10/10)'),
    );
    expect(output.toString(), contains('[status] Upload: running, verifying'));
    expect(output.toString(), contains('[status] Summary:'));
    expect(output.toString(), contains('[status] compile: completed'));
    expect(output.toString(), contains('[status] test: failed: broken'));
    expect(output.toString(), isNot(contains('Upload: completed')));
    expect(output.toString(), isNot(contains('stale')));

    final beforeLateUpdate = output.toString();
    unfinished.update('late');
    expect(output.toString(), beforeLateUpdate);
  });

  test('linear sessions keep multiple feedback updates separate from the prompt caret', () async {
    final output = StringBuffer();
    final input = StreamController<String>();
    final transcript = TextInputTranscript();

    final answer = await TerminalSession.run(
      (session) async {
        final spinner = Spinner('Index');
        final progress = Progress('Upload', total: 10);
        final tasks = MultiSpinner(['compile', 'test']);
        spinner.start(session: session);
        progress.start(session: session);
        tasks.start(session: session);
        final prompt = TextInput('Project').prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        input.add('dem');
        await Future<void>.delayed(Duration.zero);

        spinner.update('reading cache');
        progress.update(10);
        tasks.finishTask('compile', FeedbackOutcome.completed);
        tasks.finishTask('test', FeedbackOutcome.cancelled);
        input.add('o\r');
        await input.close();
        return (await prompt as Accepted<String>).value;
      },
      source: ScriptedInput(input.stream, output, transcript: transcript),
      mode: PromptMode.linear,
    );

    expect(answer, 'demo');
    expect(transcript.currentView!.text, 'demo');
    expect(transcript.currentView!.caret, 4);
    expect(output.toString(), contains('Index: reading cache'));
    expect(output.toString(), contains('Upload: running, 100%'));
    expect(output.toString(), contains('Summary:'));
    expect(output.toString(), contains('compile: completed'));
    expect(output.toString(), contains('test: cancelled'));
    expect(output.toString(), isNot(contains('\x1b[2K')));
  });
}
