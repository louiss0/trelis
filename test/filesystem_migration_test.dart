import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

final _colourProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  colorDepth: ColorDepth.indexed256,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

final _testTheme = ColorTheme(
  foreground: TerminalColor.indexed(7),
  background: TerminalColor.terminalDefault(),
  muted: TerminalColor.indexed(8),
  accent: TerminalColor.indexed(12),
  selectionForeground: TerminalColor.indexed(0),
  selectionBackground: TerminalColor.indexed(7),
  success: TerminalColor.indexed(10),
  warning: TerminalColor.indexed(11),
  error: TerminalColor.indexed(9),
  border: TerminalColor.indexed(8),
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

  group('filesystem browser integration', () {
    test(
      'rich browsing needs declared geometry and paints nothing without it',
      () async {
        final dir = await Directory.systemTemp.createTemp('browse-rich-');
        addTearDown(() => dir.delete(recursive: true));
        await File('${dir.path}${Platform.pathSeparator}answer.txt')
            .writeAsString('data');

        final unavailableOutput = StringBuffer();
        final unavailable = await FilePicker('File', base: dir.path).prompt(
          source: ScriptedInput(
            Stream.value('choose 1\r\r'),
            unavailableOutput,
          ),
          mode: PromptMode.rich,
        );
        expect(unavailable, isA<Unavailable<String>>());
        expect(unavailableOutput.toString(), isEmpty);

        final acceptedOutput = StringBuffer();
        final accepted = await FilePicker('File', base: dir.path).prompt(
          source: ScriptedInput(
            Stream.value('choose 1\r\r'),
            acceptedOutput,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
        expect(
          (accepted as Accepted<String>).value,
          path.join(dir.path, 'answer.txt'),
        );
        expect(acceptedOutput.toString(), contains('Current directory:'));
      },
    );

    test('a declared terminal adapter is leased and restored once', () async {
      final dir = await Directory.systemTemp.createTemp('browse-lease-');
      addTearDown(() => dir.delete(recursive: true));
      final output = StringBuffer();
      final terminal = _PathTerminal(
        Stream.value('choose\r\r'),
        output,
        _richProfile,
      );
      final result = await DirectoryPicker(
        'Directory',
        base: dir.path,
      ).prompt(terminal: terminal, mode: PromptMode.rich);
      expect((result as Accepted<String>).value, dir.path);
      expect(terminal.events, ['acquire', 'restore']);

      await expectLater(
        () => DirectoryPicker('Directory', base: dir.path).prompt(
          source: ScriptedInput(Stream.value('choose\r\r'), StringBuffer()),
          terminal: terminal,
        ),
        throwsArgumentError,
      );
      expect(terminal.events, ['acquire', 'restore']);
    });

    test(
      'a browser shares its session reader, writer and live feedback',
      () async {
        final dir = await Directory.systemTemp.createTemp('browse-session-');
        addTearDown(() => dir.delete(recursive: true));
        final file = await File(
          '${dir.path}${Platform.pathSeparator}answer.txt',
        ).writeAsString('data');
        final output = StringBuffer();
        final input = StreamController<String>();

        final result = await TerminalSession.run(
          (session) async {
            final spinner = Spinner('Listing');
            spinner.start(session: session);
            final pending = FilePicker(
              'File',
              base: dir.path,
            ).prompt(session: session);
            await Future<void>.delayed(Duration.zero);
            spinner.update('entries');
            await Future<void>.delayed(Duration.zero);
            input.add('choose 1\r');
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

        expect((result as Accepted<String>).value, file.path);
        final transcript = output.toString();
        expect(transcript, contains('Listing: entries'));
        expect(transcript, contains('Choose ${file.path}'));
      },
    );

    test('rich browser help names every action, approval and caveat', () async {
      final dir = await Directory.systemTemp.createTemp('browse-help-');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}${Platform.pathSeparator}answer.txt')
          .writeAsString('data');
      final out = StringBuffer();
      final result = await FilePicker('File', base: dir.path).prompt(
        source: ScriptedInput(
          Stream.value('\x14\x1bchoose 1\r\r'),
          out,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect(
        (result as Accepted<String>).value,
        path.join(dir.path, 'answer.txt'),
      );
      final transcript = out.toString();
      expect(transcript, contains('Help: FilePicker browses'));
      expect(transcript, contains('Help dismissed.'));
      expect(
        transcript,
        contains('Choose ${path.join(dir.path, 'answer.txt')}'),
      );
      expect(
        RegExp('Help: FilePicker browses').allMatches(transcript).length,
        1,
      );
    });

    test(
      'linear browser help is cleared instead of run as an action',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'browse-linear-help-',
        );
        addTearDown(() => dir.delete(recursive: true));
        final file = await File(
          '${dir.path}${Platform.pathSeparator}answer.txt',
        ).writeAsString('data');
        final out = StringBuffer();
        final result = await FilePicker('File', base: dir.path).prompt(
          source: ScriptedInput(Stream.value('/help\rchoose 1\r\r'), out),
          mode: PromptMode.linear,
        );
        expect((result as Accepted<String>).value, file.path);
        final transcript = out.toString();
        expect(transcript, contains('Help: FilePicker browses'));
        expect(transcript, contains('open <n> enters a listed directory'));
        expect(transcript, contains('choose <n> chooses a listed entry'));
        expect(transcript, contains('path enters one literal native path'));
        expect(
          transcript,
          contains('parent moves to the containing directory'),
        );
        expect(transcript, contains('refresh relists'));
        expect(transcript, contains('hidden toggles hidden entries'));
        expect(
          transcript,
          contains('open <n> links approves exactly that one'),
        );
        expect(transcript, contains('not a sandbox'));
        expect(transcript, contains('reported as stale'));
        expect(transcript, contains('later filesystem operations'));
        expect(transcript, contains('/help is cleared'));
        expect(transcript, contains('UNC pair'));
        expect(transcript, contains('Identified paste is literal'));
        expect(transcript, isNot(contains('Unknown action')));
      },
    );

    test('review help keeps the listing context and does not accept', () async {
      final dir = await Directory.systemTemp.createTemp('browse-review-help-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}${Platform.pathSeparator}answer.txt')
          .writeAsString('data');
      final out = StringBuffer();
      final result = await FilePicker('File', base: dir.path).prompt(
        source: ScriptedInput(Stream.value('choose 1\r/help\r\r'), out),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, file.path);
      final transcript = out.toString();
      expect(transcript, contains('Help: FilePicker review'));
      expect(transcript, contains(file.path));
      expect(transcript, contains('type edit'));
      expect(transcript, contains('re-inspected'));
    });

    test('literal path stage keeps escaping rules and its own help', () async {
      final dir = await Directory.systemTemp.createTemp('browse-path-help-');
      addTearDown(() => dir.delete(recursive: true));
      final child = await Directory(
        '${dir.path}${Platform.pathSeparator}literal\$name',
      ).create();
      final out = StringBuffer();
      final result = await DirectoryPicker('Directory', base: dir.path).prompt(
        source: ScriptedInput(
          Stream.value('path\r/help\rliteral\$name\r\r'),
          out,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, child.path);
      final transcript = out.toString();
      expect(transcript, contains('Help: DirectoryPicker literal path'));
      expect(transcript, contains('no shell expansion'));
      expect(transcript, contains('UNC pair'));
      expect(transcript, isNot(contains('Cannot choose /help')));
    });

    test(
      'declared colour styles the browser and warnings stay visible',
      () async {
        final dir = await Directory.systemTemp.createTemp('browse-colour-');
        addTearDown(() => dir.delete(recursive: true));
        await File('${dir.path}${Platform.pathSeparator}answer.txt')
            .writeAsString('data');
        final out = StringBuffer();
        final result =
            await FilePicker('File', base: dir.path, colors: _testTheme).prompt(
              source: ScriptedInput(
                Stream.value('choose 1\r\r'),
                out,
                outputProfile: _colourProfile,
              ),
              mode: PromptMode.rich,
            );
        expect(
          (result as Accepted<String>).value,
          path.join(dir.path, 'answer.txt'),
        );
        final transcript = out.toString();
        expect(transcript, contains('\x1b[38;5;'));
        expect(transcript, contains('not a sandbox'));
        expect(
          transcript,
          contains('Choose ${path.join(dir.path, 'answer.txt')}'),
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
