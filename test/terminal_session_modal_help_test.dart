import 'dart:async';

import 'package:prompty/prompty.dart';
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
          input.add('de\x14');
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
      expect(output.toString(), contains('[status] Index: reading cache'));
      expect(output.toString(), contains('[status] Warning: Cache is warming'));
      expect(
        output.toString().indexOf('\x1b[?1049l'),
        lessThan(
          output.toString().lastIndexOf('[status] Index: reading cache'),
        ),
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
          input.add('de\x14');
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
      expect(output.toString(), contains('[status] Index: reading cache'));
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
            input.add('\x14');
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
        expect(output.toString(), contains('[status] Index: reading cache'));
      }
    },
  );
}
