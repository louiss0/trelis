import 'dart:async';
import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test('TextInput acquires and restores an exposed terminal adapter around public interaction', () async {
    final output = StringBuffer();
    final terminal = RecordingTerminalIo(
      input: Stream.value('Ada\r'),
      output: output,
      supportsRich: false,
      environment: const {'TERM': 'dumb', 'NO_COLOR': '1'},
    );
    final prompt = TextInput('Name');

    expect(terminal.events, isEmpty, reason: 'construction is output-free');
    final result = await prompt.prompt(
      terminal: terminal,
      mode: PromptMode.linear,
    );

    expect((result as Accepted<String>).value, 'Ada');
    expect(output.toString(), contains('Name'));
    expect(terminal.environment['TERM'], 'dumb');
    expect(terminal.events, ['acquire', 'restore']);
  });

  test('feedback selects adapter output without acquiring prompt input', () {
    final output = StringBuffer();
    final terminal = RecordingTerminalIo(
      input: const Stream<String>.empty(),
      output: output,
      supportsRich: false,
      environment: const {},
    );

    Text('Ready', kind: TextKind.success).present(terminal: terminal);
    final spinner = Spinner('Index');
    spinner.start(terminal: terminal, mode: PromptMode.linear);
    spinner.finish(FeedbackOutcome.completed);

    expect(
      output.toString(),
      'Success: Ready\n/ Index: running\n+ Index: completed\n',
    );
    expect(terminal.events, isEmpty);
  });

  test(
    'adapter acquisition and output failures restore an acquired terminal',
    () async {
      final acquisitionFailure = StateError('acquisition failed');
      final unavailableTerminal = RecordingTerminalIo(
        input: const Stream<String>.empty(),
        output: StringBuffer(),
        supportsRich: false,
        environment: const {},
        acquireError: acquisitionFailure,
      );
      await expectLater(
        TextInput('Name').prompt(terminal: unavailableTerminal),
        throwsA(same(acquisitionFailure)),
      );
      expect(unavailableTerminal.events, ['acquire']);

      final outputFailure = StateError('selected output failed');
      final outputTerminal = RecordingTerminalIo(
        input: const Stream<String>.empty(),
        output: ThrowingSink(outputFailure),
        supportsRich: false,
        environment: const {'TERM': 'dumb'},
      );
      await expectLater(
        TextInput('Name')
            .prompt(terminal: outputTerminal, mode: PromptMode.linear),
        throwsA(same(outputFailure)),
      );
      expect(outputTerminal.events, ['acquire', 'restore']);
    },
  );

  test(
    'adapter owns selected input and output when a prompt is invoked',
    () async {
      final terminal = RecordingTerminalIo(
        input: const Stream<String>.empty(),
        output: StringBuffer(),
        supportsRich: false,
        environment: const {},
      );

      await expectLater(
        TextInput('Name').prompt(terminal: terminal, output: stderr),
        throwsArgumentError,
      );
      expect(terminal.events, isEmpty);
    },
  );

  test(
    'adapter restoration failure is observable after public prompt completion',
    () async {
      final restorationFailure = StateError('restoration failed');
      final terminal = RecordingTerminalIo(
        input: Stream.value('Ada\r'),
        output: StringBuffer(),
        supportsRich: false,
        environment: const {},
        restoreError: restorationFailure,
      );

      await expectLater(
        TextInput('Name').prompt(terminal: terminal, mode: PromptMode.linear),
        throwsA(same(restorationFailure)),
      );
      expect(terminal.events, ['acquire', 'restore']);
    },
  );
}

final class RecordingTerminalIo implements TerminalIo {
  RecordingTerminalIo({
    required this.input,
    required this.output,
    required this.supportsRich,
    required this.environment,
    this.acquireError,
    this.restoreError,
  });

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  @override
  final bool supportsRich;

  @override
  final Map<String, String?> environment;

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

final class ThrowingSink implements StringSink {
  ThrowingSink(this.error);

  final Object error;

  Never _throw() => throw error;

  @override
  void write(Object? object) => _throw();

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) => _throw();

  @override
  void writeCharCode(int charCode) => _throw();

  @override
  void writeln([Object? object = '']) => _throw();
}
