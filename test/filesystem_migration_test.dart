import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:trelis/src/testing/compat_api.dart';
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

/// The transcript with the writer's line breaks removed.
///
/// The shared writer wraps at display cells, so a continuation line starts with
/// the preserved separator space and a long token is split across the boundary.
/// Content assertions therefore cannot rely on a phrase landing inside one
/// line: removing `\r`/`\n` rebuilds the text the user actually reads without
/// changing any content.
String _displaySafeText(String transcript) =>
    transcript.replaceAll('\n', '').replaceAll('\r', '');

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
    // Both base lengths are exercised because the writer wraps at display
    // cells: an assertion on literal content must not depend on where a line
    // breaks, which is exactly what a worktree-length base used to hide.
    for (final longBase in [false, true]) {
      test('rich help is stage-led and preserves the draft '
          '(${longBase ? 'long' : 'short'} base)', () async {
        final root = await Directory.systemTemp.createTemp('path-help-wrap-');
        addTearDown(() => root.delete(recursive: true));
        final base = await Directory(
          path.join(root.path, longBase ? 'long-${'x' * 60}' : 'b'),
        ).create();
        final out = StringBuffer();
        final result =
            await PathInput(
              'Path',
              base: base.path,
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
        final transcript = _displaySafeText(out.toString());
        expect(transcript, contains('Help: PathInput accepts one literal'));
        expect(transcript, contains('no link canonicalization'));
        expect(transcript, contains('drive-relative Windows path'));
        expect(transcript, contains('snapshot'));
        expect(transcript, contains('per-open approval'));
        expect(transcript, contains('Ctrl+T opens this help'));
        expect(transcript, contains('Help dismissed.'));
        expect(transcript, isNot(contains('Cursor position')));
      });
    }

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

    // Both base lengths are exercised because the writer wraps at display
    // cells: the review wording and the candidate are separated by line breaks
    // whose position moves with the base length.
    for (final longBase in [false, true]) {
      test('rich review help returns to the same review stage '
          '(${longBase ? 'long' : 'short'} base)', () async {
        final root = await Directory.systemTemp.createTemp('path-review-wrap-');
        addTearDown(() => root.delete(recursive: true));
        final base = await Directory(
          path.join(root.path, longBase ? 'long-${'x' * 60}' : 'b'),
        ).create();
        final out = StringBuffer();
        final result =
            await PathInput(
              'Path',
              base: base.path,
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
        final transcript = _displaySafeText(out.toString());
        expect(transcript, contains('Help: PathInput review'));
        expect(transcript, contains('Help dismissed.'));
        expect(
          transcript.indexOf('Help: PathInput review'),
          lessThan(transcript.indexOf('Help dismissed.')),
        );
        // Dismissal returns to the same review stage instead of accepting.
        expect(RegExp('Resolved candidate:').allMatches(transcript).length, 1);
      });
    }

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
        final transcript = _displaySafeText(output.toString());
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
      final transcript = _displaySafeText(out.toString());
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
        final transcript = _displaySafeText(out.toString());
        expect(transcript, contains('\x1b[38;5;'));
        expect(transcript, contains('not a sandbox'));
        expect(
          transcript,
          contains('Choose ${path.join(dir.path, 'answer.txt')}'),
        );
      },
    );
  });

  group('filesystem terminal outcomes', () {
    test('linear entry distinguishes cancellation and input end', () async {
      final dir = await Directory.systemTemp.createTemp('browse-outcomes-');
      addTearDown(() => dir.delete(recursive: true));
      for (final open in [
        FilePicker('File', base: dir.path).prompt,
        DirectoryPicker('Directory', base: dir.path).prompt,
      ]) {
        expect(
          await open(
            source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer()),
            mode: PromptMode.linear,
          ),
          isA<Cancelled<String>>(),
        );
        expect(
          await open(
            source: ScriptedInput(Stream.value('choose'), StringBuffer()),
            mode: PromptMode.linear,
          ),
          isA<InputEnded<String>>(),
        );
      }
    });

    test(
      'rich browsing distinguishes interrupt, cancel and input end',
      () async {
        final dir = await Directory.systemTemp.createTemp('browse-rich-end-');
        addTearDown(() => dir.delete(recursive: true));
        final picker = FilePicker('File', base: dir.path);
        expect(
          await picker.prompt(
            source: ScriptedInput(
              Stream.value('\x03'),
              StringBuffer(),
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          ),
          isA<Interrupted<String>>(),
        );
        expect(
          await picker.prompt(
            source: ScriptedInput(
              Stream.value('\x1bq'),
              StringBuffer(),
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          ),
          isA<Cancelled<String>>(),
        );
        expect(
          await picker.prompt(
            source: ScriptedInput(
              Stream.empty(),
              StringBuffer(),
              outputProfile: _richProfile,
            ),
            mode: PromptMode.rich,
          ),
          isA<InputEnded<String>>(),
        );
      },
    );

    test('a rich review can be abandoned without choosing', () async {
      final dir = await Directory.systemTemp.createTemp('browse-review-exit-');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}${Platform.pathSeparator}answer.txt')
          .writeAsString('data');
      final out = StringBuffer();
      expect(
        await FilePicker('File', base: dir.path).prompt(
          source: ScriptedInput(
            Stream.value('choose 1\r\x1bq'),
            out,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        ),
        isA<Cancelled<String>>(),
      );
      expect(_displaySafeText(out.toString()), contains('type edit'));

      final pathOut = StringBuffer();
      expect(
        await PathInput('Path', base: dir.path, allowNonexistent: true).prompt(
          source: ScriptedInput(
            Stream.value('draft\r\x1bq'),
            pathOut,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        ),
        isA<Cancelled<String>>(),
      );
      expect(
        _displaySafeText(pathOut.toString()),
        contains('type edit to correct'),
      );
    });

    test('visible safety caveats survive help and dismissal', () async {
      final dir = await Directory.systemTemp.createTemp('browse-caveats-');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}${Platform.pathSeparator}answer.txt')
          .writeAsString('data');
      final out = StringBuffer();
      await FilePicker('File', base: dir.path).prompt(
        source: ScriptedInput(
          Stream.value('\x14\x1b\x03'),
          out,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      final transcript = _displaySafeText(out.toString());
      expect(transcript, contains('Links require explicit per-open approval'));
      expect(transcript, contains('The base is not a sandbox.'));
      expect(transcript, contains('Help: FilePicker browses'));
      expect(transcript, contains('Links are never followed implicitly'));
      expect(transcript, contains('Help dismissed.'));

      final pathOut = StringBuffer();
      await PathInput('Path', base: dir.path, allowNonexistent: true).prompt(
        source: ScriptedInput(Stream.value('\r\r'), pathOut),
        mode: PromptMode.linear,
      );
      expect(
        pathOut.toString(),
        contains('Returned paths do not guarantee later operations succeed'),
      );
    });

    test('repeated browser rejections keep the listing usable', () async {
      final dir = await Directory.systemTemp.createTemp('browse-reject-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}${Platform.pathSeparator}answer.txt')
          .writeAsString('data');
      await Directory('${dir.path}${Platform.pathSeparator}folder').create();
      final out = StringBuffer();
      final result = await FilePicker('File', base: dir.path).prompt(
        source: ScriptedInput(
          Stream.value('open 1\rchoose 3\rchoose 2\rchoose 1\r\r'),
          out,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, file.path);
      final transcript = out.toString();
      expect(transcript, contains('target must be a file'));
      expect(transcript, contains('Invalid entry reference; listing retained'));
      expect(
        RegExp('Current directory:').allMatches(transcript).length,
        greaterThanOrEqualTo(4),
      );
    });

    test(
      'session help keeps live feedback until dismissal restores it',
      () async {
        final dir = await Directory.systemTemp.createTemp('browse-modal-');
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
            await _until(output, 'Current directory:');
            input.add('\x14');
            await _until(output, 'Help: FilePicker browses');
            spinner.update('entries');
            input.add('\x1b');
            await _until(output, 'Help dismissed.');
            input.add('choose 1\r');
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
        expect(transcript, contains('Help: FilePicker browses'));
        expect(transcript, contains('Help dismissed.'));
        // The update written while help owned painting is retained and
        // restored when help is dismissed, rather than lost or interleaved.
        expect(
          transcript.indexOf('Help dismissed.'),
          lessThan(transcript.indexOf('Listing: entries')),
        );
        expect(
          transcript.indexOf('Help dismissed.'),
          lessThan(transcript.indexOf('Choose ${file.path}')),
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

/// Waits for a marker that a prompt writes synchronously.
///
/// Session scenarios then never depend on a fixed number of event-loop turns to
/// reach a particular stage.
Future<void> _until(StringBuffer output, String marker) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (output.toString().contains(marker)) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Timed out waiting for "$marker".');
}
