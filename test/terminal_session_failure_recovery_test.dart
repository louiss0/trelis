import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a local feedback failure leaves unrelated session regions usable',
    () async {
      final output = StringBuffer();

      await TerminalSession.run(
        (session) {
          final upload = Progress('Upload', total: 2)..start(session: session);
          expect(() => upload.update(3), throwsArgumentError);

          final index = Spinner('Index')..start(session: session);
          index.update('ready');
          upload.dispose();
          index.dispose();
        },
        output: output,
        mode: PromptMode.linear,
      );

      expect(output.toString(), contains('Index: ready'));
    },
  );

  test('a local registration failure leaves the session writer usable', () async {
    final output = StringBuffer();

    await TerminalSession.run(
      (session) {
        // A standalone writer cannot join a screen that a session already owns.
        expect(
          () => Text('standalone').present(output: output),
          throwsStateError,
        );

        final index = Spinner('Index')..start(session: session);
        index.update('ready');
        index.dispose();
      },
      output: output,
      mode: PromptMode.linear,
    );

    expect(output.toString(), contains('Index: ready'));
    expect(output.toString(), isNot(contains('standalone')));
  });

  test(
    'a native acquisition failure ends the scope and releases its output',
    () async {
      final output = StringBuffer();
      final failure = StateError('acquisition failed');
      final terminal = _RecordingTerminal(
        input: const Stream<String>.empty(),
        output: output,
        acquireError: failure,
      );

      await expectLater(
        TerminalSession.run(
          (session) => TextInput('Name').prompt(session: session),
          terminal: terminal,
          mode: PromptMode.linear,
        ),
        throwsA(same(failure)),
      );

      expect(terminal.events, ['acquire']);
      expect(
        output.toString(),
        isEmpty,
        reason: 'the selected writer was never used',
      );
      // The abandoned scope must not keep the shared output claimed.
      await TerminalSession.run(
        (session) {},
        output: output,
        mode: PromptMode.linear,
      );
    },
  );

  test('a feedback write failure ends an idle prompt even when the caller catches it', () async {
    final failure = StateError('shared writer failed');
    final output = _ConditionalThrowingSink(
      failure,
      (text) => text.contains('Index: tick'),
    );
    final input = StreamController<String>();
    late Spinner spinner;

    final run = TerminalSession.run(
      (session) async {
        spinner = Spinner('Index')..start(session: session);
        final prompt = TextInput('Project').prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        // The caller observes the failure and keeps waiting on the prompt.
        // No further key ever arrives, so retirement itself must decide it.
        try {
          spinner.update('tick');
        } catch (error) {
          expect(error, same(failure));
        }
        return await prompt;
      },
      source: ScriptedInput(
        input.stream,
        output,
        supportsRich: true,
        outputProfile: _richProfile(),
      ),
    );

    await expectLater(run, throwsA(same(failure)));
    final writesBeforeLateUpdate = output.writeAttempts;
    spinner.update('late');
    expect(output.writeAttempts, writesBeforeLateUpdate);
    expect(output.text, isNot(contains('completed')));
    await input.close();
  });

  test(
    'a feedback write failure ends an idle terminal-backed prompt',
    () async {
      final failure = StateError('shared writer failed');
      final output = _ConditionalThrowingSink(
        failure,
        (text) => text.contains('Index: tick'),
      );
      final input = StreamController<String>();
      final terminal = _RecordingTerminal(input: input.stream, output: output);
      late Spinner spinner;

      final run = TerminalSession.run(
        (session) async {
          spinner = Spinner('Index')..start(session: session);
          final prompt = TextInput('Project').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          try {
            spinner.update('tick');
          } catch (error) {
            expect(error, same(failure));
          }
          return await prompt;
        },
        terminal: terminal,
        mode: PromptMode.linear,
      );

      await expectLater(run, throwsA(same(failure)));
      expect(terminal.events, [
        'acquire',
        'restore',
      ], reason: 'the retired scope still restores its acquired lease');
      final writesBeforeLateUpdate = output.writeAttempts;
      spinner.update('late');
      expect(output.writeAttempts, writesBeforeLateUpdate);
      await input.close();
    },
  );

  test(
    'a prompt abandoned by its scope ends instead of staying pending',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      late Future<PromptResult<String>> abandoned;

      final scope = await TerminalSession.run(
        (session) {
          abandoned = TextInput('Project').prompt(session: session);
          return 'scope done';
        },
        source: ScriptedInput(input.stream, output),
        mode: PromptMode.linear,
      );

      expect(scope, 'scope done');
      final result = await abandoned.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw StateError('abandoned prompt never completed'),
      );
      expect(result, isA<InputEnded<String>>());
      final writesAfterClosure = output.toString();
      await input.close();
      expect(output.toString(), writesAfterClosure);
    },
  );

  test(
    'a shared writer failure closes regions and does not invent outcomes',
    () async {
      final failure = StateError('shared writer failed');
      final output = _ThrowingSink(failure);
      late Spinner spinner;
      late TerminalSession closed;

      await expectLater(
        TerminalSession.run(
          (session) {
            closed = session;
            spinner = Spinner('Index');
            spinner.start(session: session);
          },
          output: output,
          mode: PromptMode.linear,
        ),
        throwsA(same(failure)),
      );

      final writesBeforeLateUpdate = output.writeAttempts;
      spinner.update('late');
      expect(output.writeAttempts, writesBeforeLateUpdate);
      expect(() => Spinner('Other').start(session: closed), throwsStateError);
      expect(output.text, isNot(contains('completed')));
      expect(output.text, isNot(contains('failed')));
    },
  );

  test(
    'a session preserves callback context when reader teardown also fails',
    () async {
      const canary = 'CANARY-callback-draft';
      final operationFailure = StateError('callback failed: $canary');
      final cleanupFailure = StateError('reader cancellation failed: $canary');
      final input = StreamController<String>(
        onCancel: () => Future<void>.error(cleanupFailure),
      );

      final failure =
          await TerminalSession.run((session) async {
            TextInput('Name').prompt(session: session);
            await Future<void>.delayed(Duration.zero);
            throw operationFailure;
          }, source: ScriptedInput(input.stream, StringBuffer())).then<Object?>(
            (value) => value,
            onError: (Object error, StackTrace _) => error,
          );

      expect(
        failure,
        isA<TerminalSessionCleanupException>()
            .having(
              (error) => error.operationError,
              'operation error',
              same(operationFailure),
            )
            .having(
              (error) => error.cleanupError,
              'cleanup error',
              same(cleanupFailure),
            ),
      );
      expect(
        failure.toString(),
        isNot(contains(canary)),
        reason: 'diagnostics must not stringify application failures',
      );

      await input.close();
    },
  );

  test(
    'a native restoration failure keeps both causes without their text',
    () async {
      const canary = 'CANARY-restoration-draft';
      final operationFailure = StateError('prompt failed: $canary');
      final restorationFailure = StateError('restore failed: $canary');
      final terminal = _RecordingTerminal(
        input: const Stream<String>.empty(),
        output: _ThrowingSink(operationFailure),
        restoreError: restorationFailure,
      );

      final failure =
          await TerminalSession.run(
            (session) => TextInput('Name').prompt(session: session),
            terminal: terminal,
            mode: PromptMode.linear,
          ).then<Object?>(
            (value) => value,
            onError: (Object error, StackTrace _) => error,
          );

      expect(
        failure,
        isA<TerminalRestorationException>()
            .having(
              (error) => error.operationError,
              'operation error',
              same(operationFailure),
            )
            .having(
              (error) => error.restorationError,
              'restoration error',
              same(restorationFailure),
            ),
      );
      expect(failure.toString(), isNot(contains(canary)));
      expect(terminal.events, ['acquire', 'restore']);
    },
  );

  test(
    'a modal-help writer failure closes the session before late feedback',
    () async {
      final failure = StateError('modal writer failed');
      final output = _ConditionalThrowingSink(
        failure,
        (text) => text.contains('\x1b[?1049h'),
      );
      final input = StreamController<String>();
      late Spinner spinner;

      final run = TerminalSession.run(
        (session) async {
          spinner = Spinner('Index')..start(session: session);
          final prompt = TextInput('Project').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          input.add('\x14');
          return await prompt;
        },
        source: ScriptedInput(
          input.stream,
          output,
          supportsRich: true,
          outputProfile: _richProfile(
            alternateScreen: CapabilitySupport.supported,
          ),
        ),
      );

      await expectLater(run, throwsA(same(failure)));
      final writesBeforeLateUpdate = output.writeAttempts;
      spinner.update('late');
      expect(output.writeAttempts, writesBeforeLateUpdate);
      await input.close();
    },
  );

  test(
    'an overflow history write failure retires the session without an outcome',
    () async {
      final failure = StateError('history writer failed');
      final output = _ConditionalThrowingSink(
        failure,
        (text) => text.contains('Index: failed'),
      );
      final input = StreamController<String>();
      late Spinner spinner;

      final run = TerminalSession.run(
        (session) async {
          spinner = Spinner('Index')..start(session: session);
          final prompt = TextInput('Project').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          expect(
            () => spinner.finish(FeedbackOutcome.failed, detail: 'offline'),
            throwsA(same(failure)),
          );
          // No later key arrives: retirement decides the idle prompt.
          return await prompt;
        },
        source: ScriptedInput(
          input.stream,
          output,
          supportsRich: true,
          outputProfile: _richProfile(rows: 1),
        ),
      );

      await expectLater(run, throwsA(same(failure)));
      final writesBeforeLateUpdate = output.writeAttempts;
      spinner.update('late');
      expect(output.writeAttempts, writesBeforeLateUpdate);
      expect(output.text, isNot(contains('completed')));
      await input.close();
    },
  );

  test(
    'a resize repaint writer failure ends the prompt and stops the watcher',
    () async {
      final failure = StateError('resize writer failed');
      var failRepaint = false;
      final output = _ConditionalThrowingSink(
        failure,
        (text) => failRepaint && text.contains('\r\x1b[2K>'),
      );
      final input = StreamController<String>();
      late final _ResizeObserver observer;
      final resized = StreamController<void>(
        onCancel: () => observer.cancelled = true,
      );
      observer = _ResizeObserver(resized.stream);
      late Spinner spinner;
      late TerminalSession closed;

      final run = TerminalSession.run(
        (session) async {
          closed = session;
          spinner = Spinner('Index')..start(session: session);
          final prompt = TextInput('Project').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          failRepaint = true;
          resized.add(null);
          // The failed repaint, not a later keystroke, must decide this prompt.
          return await prompt;
        },
        source: ScriptedInput(
          input.stream,
          output,
          supportsRich: true,
          outputProfile: _richProfile(),
          resizeObserver: observer,
        ),
      );

      await expectLater(run, throwsA(same(failure)));
      expect(
        observer.cancelled,
        isTrue,
        reason: 'a retired session must not keep observing geometry',
      );
      final writesBeforeLateUpdate = output.writeAttempts;
      spinner.update('late');
      expect(output.writeAttempts, writesBeforeLateUpdate);
      expect(output.text, isNot(contains('completed')));
      expect(() => Spinner('Other').start(session: closed), throwsStateError);
      await input.close();
      await resized.close();
    },
  );

  test(
    'a terminal-backed session restores its lease after a shared write failure',
    () async {
      final failure = StateError('shared writer failed');
      final terminal = _RecordingTerminal(
        input: Stream.value('Ada\r'),
        output: _ThrowingSink(failure),
      );

      await expectLater(
        TerminalSession.run(
          (session) => TextInput('Name').prompt(session: session),
          terminal: terminal,
          mode: PromptMode.linear,
        ),
        throwsA(same(failure)),
      );

      expect(terminal.events, ['acquire', 'restore']);
    },
  );
}

OutputProfile _richProfile({
  int rows = 8,
  CapabilitySupport alternateScreen = CapabilitySupport.unsupported,
}) => OutputProfile(
  cursor: CapabilitySupport.supported,
  alternateScreen: alternateScreen,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.none,
  glyphs: GlyphSet.ascii,
  geometry: OutputGeometry.fixed(columns: 40, rows: rows),
);

final class _ResizeObserver implements TerminalResizeObserver {
  _ResizeObserver(this.notifications);

  @override
  final Stream<void> notifications;
  bool cancelled = false;

  @override
  ({int columns, int rows})? readDimensions() => (columns: 20, rows: 4);

  @override
  Duration get fallbackInterval => const Duration(days: 1);
}

final class _ThrowingSink implements StringSink {
  _ThrowingSink(this.error);

  final Object error;
  int writeAttempts = 0;
  final StringBuffer _recording = StringBuffer();

  String get text => _recording.toString();

  Never _throw(Object? value) {
    writeAttempts++;
    _recording.write(value);
    throw error;
  }

  @override
  void write(Object? object) => _throw(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _throw(objects.join(separator));

  @override
  void writeCharCode(int charCode) => _throw(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => _throw('$object\n');
}

final class _ConditionalThrowingSink implements StringSink {
  _ConditionalThrowingSink(this.error, this._shouldThrow);

  final Object error;
  final bool Function(String text) _shouldThrow;
  int writeAttempts = 0;
  final StringBuffer _recording = StringBuffer();

  String get text => _recording.toString();

  void _write(Object? value) {
    final text = '$value';
    writeAttempts++;
    _recording.write(text);
    if (_shouldThrow(text)) throw error;
  }

  @override
  void write(Object? object) => _write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _write(objects.join(separator));

  @override
  void writeCharCode(int charCode) => _write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => _write('$object\n');
}

final class _RecordingTerminal implements TerminalIo {
  _RecordingTerminal({
    required this.input,
    required this.output,
    this.acquireError,
    this.restoreError,
  });

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  @override
  bool get supportsRich => false;
  @override
  Map<String, String?> get environment => const {};

  final Object? acquireError;
  final Object? restoreError;
  final List<String> events = [];

  @override
  TerminalLease acquire() {
    events.add('acquire');
    if (acquireError != null) throw acquireError!;
    return TerminalLease(() {
      events.add('restore');
      if (restoreError != null) throw restoreError!;
    });
  }
}
