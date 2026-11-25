import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

final _alternateProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  alternateScreen: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.none,
  glyphs: GlyphSet.ascii,
  geometry: OutputGeometry.fixed(columns: 40, rows: 8),
);

final _transcriptProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  alternateScreen: CapabilitySupport.unsupported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.none,
  glyphs: GlyphSet.ascii,
  geometry: OutputGeometry.fixed(columns: 40, rows: 8),
);

void main() {
  test(
    'session-owned alternate help restores latest feedback and editable draft',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      final transcript = TextInputTranscript();

      final result = await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Index')..start(session: session);
          final prompt = TextInput('Project').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          input.add('de\x1bOP');
          await Future<void>.delayed(Duration.zero);

          spinner.update('reading cache');
          Text(
            'Cache is warming',
            kind: TextKind.warning,
          ).present(session: session);
          input.add('\x1bmo\r');
          await input.close();
          return await prompt;
        },
        source: ScriptedInput(
          input.stream,
          output,
          supportsRich: true,
          outputProfile: _alternateProfile,
          transcript: transcript,
        ),
      );

      expect((result as Accepted<String>).value, 'demo');
      expect(transcript.currentView!.text, 'demo');
      expect(transcript.currentView!.caret, 4);
      expect(output.toString(), contains('\x1b[?1049h'));
      expect(output.toString(), contains('\x1b[?1049l'));
      expect(output.toString(), contains('[status] - Index: reading cache'));
      expect(output.toString(), contains('[status] Warning: Cache is warming'));
      expect(
        output.toString().indexOf('\x1b[?1049l'),
        lessThan(
          output.toString().lastIndexOf('[status] - Index: reading cache'),
        ),
      );
    },
  );

  test('two regions reporting the same notice during help keep both events', () async {
    final output = StringBuffer();
    final input = StreamController<String>();
    final first = Spinner('Index');
    final second = Spinner('Index');

    await TerminalSession.run(
      (session) async {
        final prompt = TextInput('Project').prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        first.start(session: session);
        second.start(session: session);
        for (var cycle = 0; cycle < 2; cycle++) {
          input.add('\x1bOP');
          await Future<void>.delayed(Duration.zero);
          if (cycle == 0) {
            // Two independent regions report the same words. They are separate
            // session events, not a repaint of one event.
            first.finish(FeedbackOutcome.failed, detail: 'offline');
            second.finish(FeedbackOutcome.failed, detail: 'offline');
          }
          input.add('\x1b');
          await Future<void>.delayed(Duration.zero);
        }
        input.add('demo\r');
        await input.close();
        await prompt;
      },
      source: ScriptedInput(
        input.stream,
        output,
        supportsRich: true,
        outputProfile: _alternateProfile,
      ),
    );

    expect(
      RegExp(RegExp.escape('Index: failed: offline'))
          .allMatches(output.toString())
          .length,
      2,
      reason: 'each region reports its own occurrence, once',
    );
  });

  test(
    'a repeated identical notice from one region stays a separate event',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      final tasks = MultiSpinner(['compile']);

      await TerminalSession.run(
        (session) async {
          final prompt = TextInput('Project').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          tasks.start(session: session);
          input.add('\x1bOP');
          await Future<void>.delayed(Duration.zero);
          // The outcome line and the final summary line are two occurrences the
          // application emitted; text equality does not merge them.
          tasks.finishTask('compile', FeedbackOutcome.failed, detail: 'broken');
          input.add('\x1b');
          await Future<void>.delayed(Duration.zero);
          input.add('demo\r');
          await input.close();
          await prompt;
        },
        source: ScriptedInput(
          input.stream,
          output,
          supportsRich: true,
          outputProfile: _alternateProfile,
        ),
      );

      expect(
        RegExp(RegExp.escape('compile: failed: broken'))
            .allMatches(output.toString())
            .length,
        2,
        reason: 'the outcome and its summary are distinct events',
      );
    },
  );

  test('an important line that is also the latest is written once', () async {
    final output = StringBuffer();
    final input = StreamController<String>();
    final index = Spinner('Index');

    await TerminalSession.run(
      (session) async {
        final prompt = TextInput('Project').prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        index.start(session: session);
        input.add('\x1bOP');
        await Future<void>.delayed(Duration.zero);
        index.finish(FeedbackOutcome.failed, detail: 'offline');
        input.add('\x1b');
        await Future<void>.delayed(Duration.zero);
        input.add('demo\r');
        await input.close();
        await prompt;
      },
      source: ScriptedInput(
        input.stream,
        output,
        supportsRich: true,
        outputProfile: _alternateProfile,
      ),
    );

    expect(
      RegExp(RegExp.escape('Index: failed: offline'))
          .allMatches(output.toString())
          .length,
      1,
      reason: 'the same occurrence is not replayed from the snapshot',
    );
  });

  test(
    'help keeps a task failure that a later task update would displace',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      final tasks = MultiSpinner(['compile', 'test']);

      await TerminalSession.run(
        (session) async {
          final prompt = TextInput('Project').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          tasks.start(session: session);
          // A failure and a later ordinary update arrive through one shared
          // region while help owns painting. The failure is a notice the
          // transcript still owes the reader, not a snapshot to overwrite.
          for (var cycle = 0; cycle < 2; cycle++) {
            input.add('\x1bOP');
            await Future<void>.delayed(Duration.zero);
            if (cycle == 0) {
              tasks.finishTask(
                'compile',
                FeedbackOutcome.failed,
                detail: 'broken',
              );
            }
            tasks.update('test', TaskActivity.running, phase: 'linking');
            input.add('\x1b');
            await Future<void>.delayed(Duration.zero);
          }
          input.add('demo\r');
          await input.close();
          await prompt;
        },
        source: ScriptedInput(
          input.stream,
          output,
          supportsRich: true,
          outputProfile: _alternateProfile,
        ),
      );

      expect(
        RegExp(RegExp.escape('compile: failed: broken'))
            .allMatches(output.toString())
            .length,
        1,
        reason: 'an important notice survives help and is not replayed',
      );
      expect(output.toString(), contains('test: running, linking'));
    },
  );

  test(
    'dismissing help does not replay feedback the transcript already holds',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();

      await TerminalSession.run(
        (session) async {
          final prompt = TextInput('Project').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          Text('Cache warm', kind: TextKind.success).present(session: session);
          // Two complete help intervals. Retired feedback belongs to history,
          // so returning from help must not print it again.
          for (var cycle = 0; cycle < 2; cycle++) {
            input.add('\x1bOP');
            await Future<void>.delayed(Duration.zero);
            input.add('\x1b');
            await Future<void>.delayed(Duration.zero);
          }
          input.add('demo\r');
          await input.close();
          await prompt;
        },
        source: ScriptedInput(
          input.stream,
          output,
          supportsRich: true,
          outputProfile: _alternateProfile,
        ),
      );

      expect(
        RegExp(RegExp.escape('Success: Cache warm'))
            .allMatches(output.toString())
            .length,
        1,
        reason: 'a retained snapshot is not a second transcript record',
      );
    },
  );

  test(
    'transcript help clears the draft row before writing and repaints once',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();

      final result = await TerminalSession.run(
        (session) async {
          final prompt = TextInput('Project').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          input.add('de\x1bOP');
          await Future<void>.delayed(Duration.zero);
          input.add('\x1b');
          await Future<void>.delayed(Duration.zero);
          input.add('mo\r');
          await input.close();
          return await prompt;
        },
        source: ScriptedInput(
          input.stream,
          output,
          supportsRich: true,
          outputProfile: _transcriptProfile,
        ),
      );

      expect((result as Accepted<String>).value, 'demo');
      final text = output.toString();
      expect(text, isNot(contains('\x1b[?1049h')));
      // A transcript fallback has no alternate screen to hide the draft, so the
      // editor must clear the row the modal replaces instead of writing the
      // help block from the live caret.
      expect(text, isNot(contains('\x1b[uHelp:')));
      expect(text, contains('\r\x1b[2K\nHelp:'));
      // Dismissal repaints the current draft on a fresh row, once.
      expect(
        RegExp(RegExp.escape('\r\x1b[2K> demo')).allMatches(text).length,
        1,
      );
    },
  );

  test(
    'transcript help pauses feedback painting and cleans up on interruption',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();

      final result = await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Index')..start(session: session);
          final prompt = TextInput('Project').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          input.add('de\x1bOP');
          await Future<void>.delayed(Duration.zero);
          spinner.update('reading cache');
          input.add('\x03');
          await input.close();
          return await prompt;
        },
        source: ScriptedInput(
          input.stream,
          output,
          supportsRich: true,
          outputProfile: _transcriptProfile,
        ),
      );

      expect(result, isA<Interrupted<String>>());
      expect(output.toString(), contains('Help:'));
      expect(output.toString(), contains('[status] - Index: reading cache'));
      expect(output.toString(), isNot(contains('\x1b[?1049h')));
      expect(output.toString(), isNot(contains('\x1b[?1049l')));
    },
  );

  test(
    'modal help restores the terminal and notices on EOF and session error',
    () async {
      for (final failure in <Object?>[null, StateError('input failed')]) {
        final output = StringBuffer();
        final input = StreamController<String>();
        final run = TerminalSession.run(
          (session) async {
            final spinner = Spinner('Index')..start(session: session);
            final prompt = TextInput('Project').prompt(session: session);
            await Future<void>.delayed(Duration.zero);
            input.add('\x1bOP');
            await Future<void>.delayed(Duration.zero);
            spinner.update('reading cache');
            if (failure == null) {
              await input.close();
              return prompt;
            }
            throw failure;
          },
          source: ScriptedInput(
            input.stream,
            output,
            supportsRich: true,
            outputProfile: _alternateProfile,
          ),
        );

        final outcome = run.then<Object?>(
          (value) => value,
          onError: (Object error, StackTrace _) => error,
        );
        if (failure == null) {
          expect(await outcome, isA<InputEnded<String>>());
        } else {
          expect(await outcome, same(failure));
        }
        expect(output.toString(), contains('\x1b[?1049h'));
        expect(output.toString(), contains('\x1b[?1049l'));
        expect(output.toString(), contains('[status] - Index: reading cache'));
      }
    },
  );
}
