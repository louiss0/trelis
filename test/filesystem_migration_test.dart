import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

void main() {
  group('PathInput source ownership', () {
    test('rich entry needs declared cursor support and geometry', () async {
      final unavailableOutput = StringBuffer();
      final unavailable = await PathInput('Path', allowNonexistent: true)
          .prompt(
            source: ScriptedInput(Stream.value('\r\r'), unavailableOutput),
            mode: PromptMode.rich,
          );
      expect(unavailable, isA<Unavailable<String>>());
      expect(unavailableOutput.toString(), isEmpty);

      final acceptedOutput = StringBuffer();
      final accepted = await PathInput('Path', allowNonexistent: true).prompt(
        source: ScriptedInput(
          Stream.value('draft\r\r'),
          acceptedOutput,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect((accepted as Accepted<String>).value, endsWith('draft'));
      expect(acceptedOutput.toString(), contains('Base:'));
    });

    test(
      'automatic mode falls back to linear without declared geometry',
      () async {
        final out = StringBuffer();
        final result = await PathInput('Path', allowNonexistent: true).prompt(
          source: ScriptedInput(
            Stream.value('${path.separator}tmp-or-draft\r\r'),
            out,
          ),
        );
        expect(result, isA<Accepted<String>>());
        expect(
          out.toString(),
          contains('Exact /help and /cancel are commands'),
        );
      },
    );

    test(
      'a declared terminal adapter is leased, restored and exclusive',
      () async {
        final output = StringBuffer();
        final terminal = _PathTerminal(
          Stream.value('typed\r\r'),
          output,
          _richProfile,
        );
        final result = await PathInput(
          'Path',
          allowNonexistent: true,
        ).prompt(terminal: terminal, mode: PromptMode.rich);
        expect((result as Accepted<String>).value, endsWith('typed'));
        expect(terminal.events, ['acquire', 'restore']);
        expect(output.toString(), contains('Path'));

        await expectLater(
          () => PathInput('Path').prompt(
            source: ScriptedInput(Stream.value('\r\r'), StringBuffer()),
            terminal: terminal,
          ),
          throwsArgumentError,
        );
        await expectLater(
          () => PathInput('Path').prompt(terminal: terminal, output: stdout),
          throwsArgumentError,
        );
        expect(terminal.events, ['acquire', 'restore']);
      },
    );

    test(
      'a path prompt shares its session reader, writer and feedback',
      () async {
        final output = StringBuffer();
        final input = StreamController<String>();

        final result = await TerminalSession.run(
          (session) async {
            final spinner = Spinner('Scan');
            spinner.start(session: session);
            final pending = PathInput(
              'Path',
              initialValue: 'draft',
              allowNonexistent: true,
            ).prompt(session: session);
            await Future<void>.delayed(Duration.zero);
            spinner.update('listing');
            await Future<void>.delayed(Duration.zero);
            input.add('\r');
            await Future<void>.delayed(Duration.zero);
            input.add('\r');
            await input.close();
            spinner.finish(FeedbackOutcome.completed);
            return await pending;
          },
          source: ScriptedInput(
            input.stream,
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );

        expect((result as Accepted<String>).value, endsWith('draft'));
        final transcript = output.toString();
        expect(transcript, contains('Base:'));
        expect(transcript, contains('Scan: listing'));
      },
    );

    test(
      'an attached path prompt rejects competing invocation options',
      () async {
        await TerminalSession.run((session) async {
          await expectLater(
            () =>
                PathInput('Path')
                    .prompt(session: session, mode: PromptMode.rich),
            throwsArgumentError,
          );
          return null;
        }, source: ScriptedInput(const Stream.empty(), StringBuffer()));
      },
    );
  });

  group('PathInput stage help', () {
    test('rich help is stage-led and preserves the draft', () async {
      final out = StringBuffer();
      final result =
          await PathInput(
            'Path',
            base: Directory.current.path,
            allowNonexistent: true,
          ).prompt(
            source: ScriptedInput(
              Stream.value('\x14\x1bdraft\r\r'),
              out,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, endsWith('draft'));
      final transcript = out.toString();
      expect(transcript, contains('Help: PathInput accepts one literal'));
      expect(transcript, contains('no link canonicalization'));
      expect(transcript, contains('drive-relative Windows path'));
      expect(transcript, contains('snapshot'));
      expect(transcript, contains('per-open approval'));
      expect(transcript, contains('Ctrl+T opens this help'));
      expect(transcript, contains('Help dismissed.'));
      expect(transcript, isNot(contains('Cursor position')));
    });

    test(
      'linear help is component-specific and never becomes a path',
      () async {
        final out = StringBuffer();
        final result =
            await PathInput(
              'Path',
              base: Directory.current.path,
              allowNonexistent: true,
            ).prompt(
              source: ScriptedInput(Stream.value('/help\rdraft\r\r'), out),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, endsWith('draft'));
        final transcript = out.toString();
        expect(transcript, contains('Help: PathInput accepts one literal'));
        expect(transcript, contains('no variable, tilde or glob expansion'));
        expect(transcript, contains('/help is cleared instead'));
        expect(transcript, contains('UNC pair'));
        expect(transcript, contains('Identified paste is literal'));
        expect(transcript, isNot(contains('Resolved candidate: /help')));
      },
    );

    test('linear review help does not accept the candidate', () async {
      final out = StringBuffer();
      final result =
          await PathInput(
            'Path',
            base: Directory.current.path,
            allowNonexistent: true,
          ).prompt(
            source: ScriptedInput(
              Stream.value('draft\r/help\redit\r\r\r'),
              out,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, endsWith('draft'));
      final transcript = out.toString();
      expect(transcript, contains('Help: PathInput review'));
      expect(transcript, contains('type edit'));
      expect(transcript, contains('later filesystem operation'));
      expect(
        RegExp('Resolved candidate:').allMatches(transcript).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('rich review help returns to the same review stage', () async {
      final out = StringBuffer();
      final result =
          await PathInput(
            'Path',
            base: Directory.current.path,
            allowNonexistent: true,
          ).prompt(
            source: ScriptedInput(
              Stream.value('draft\r\x14\x1b\r'),
              out,
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, endsWith('draft'));
      final transcript = out.toString();
      expect(transcript, contains('Help: PathInput review'));
      expect(transcript, contains('Help dismissed.'));
      expect(
        transcript.indexOf('Help: PathInput review'),
        lessThan(transcript.indexOf('Help dismissed.')),
      );
      // Dismissal returns to the same review stage instead of accepting.
      expect(RegExp('Resolved candidate:').allMatches(transcript).length, 1);
    });

    test(
      'documented escaping still enters a literal command-shaped path',
      () async {
        final base = Directory.current.path;
        final out = StringBuffer();
        final result =
            await PathInput('Path', base: base, allowNonexistent: true).prompt(
              source: ScriptedInput(Stream.value('\\/help\r\r'), out),
              mode: PromptMode.linear,
            );
        expect(
          (result as Accepted<String>).value,
          Platform.isWindows
              ? '${path.rootPrefix(base)}help'
              : path.normalize('${path.separator}help'),
        );
      },
    );
  });
}

final class _PathTerminal implements TerminalIo, TerminalIoOutputProfile {
  _PathTerminal(this.input, this.output, this.outputProfile);

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  @override
  final OutputProfile outputProfile;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const {};

  final List<String> events = [];

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}
