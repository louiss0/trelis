import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test(
    'automatic mode stays linear when output has cursor but no dimensions',
    () async {
      final output = StringBuffer();

      final result = await TextInput('Name').prompt(
        terminal: _Terminal(
          Stream.value('/cancel\r'),
          output,
          const OutputProfile(cursor: CapabilitySupport.supported),
        ),
      );

      expect(result, isA<Cancelled<String>>());
      expect(output.toString(), contains('Current text: /cancel'));
      expect(output.toString(), isNot(contains('\x1b[2K')));
    },
  );

  test('a prompt leaves alternate output before interruption', () async {
    final output = StringBuffer();

    final result = await TextInput('Name').prompt(
      source: ScriptedInput(
        Stream.value('\x1bOP\x03'),
        output,
        outputProfile: OutputProfile(
          cursor: CapabilitySupport.supported,
          alternateScreen: CapabilitySupport.supported,
          geometry: OutputGeometry.fixed(columns: 80, rows: 24),
        ),
      ),
      mode: PromptMode.rich,
    );

    expect(result, isA<Interrupted<String>>());
    expect(output.toString(), contains('\x1b[?1049h'));
    expect(output.toString(), endsWith('\x1b[?1049l'));
  });

  test('an input failure restores terminal state', () async {
    final inputFailure = StateError('input failed');
    final terminal = _Terminal(
      Stream<String>.error(inputFailure),
      StringBuffer(),
      const OutputProfile(),
    );

    await expectLater(
      TextInput('Name').prompt(terminal: terminal),
      throwsA(same(inputFailure)),
    );
    expect(terminal.events, ['acquire', 'restore']);
  });

  test('a restoration failure retains the original prompt failure', () async {
    final inputFailure = StateError('input failed');
    final restorationFailure = StateError('restore failed');
    final terminal = _Terminal(
      Stream<String>.error(inputFailure),
      StringBuffer(),
      const OutputProfile(),
      restoreError: restorationFailure,
    );

    await expectLater(
      TextInput('Name').prompt(terminal: terminal),
      throwsA(
        isA<TerminalRestorationException>()
            .having(
              (error) => error.operationError,
              'operation error',
              inputFailure,
            )
            .having(
              (error) => error.restorationError,
              'restoration error',
              restorationFailure,
            ),
      ),
    );
    expect(terminal.events, ['acquire', 'restore']);
  });
}

final class _Terminal implements TerminalIo, TerminalIoOutputProfile {
  _Terminal(this.input, this.output, this.outputProfile, {this.restoreError});

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  @override
  final OutputProfile outputProfile;
  final Object? restoreError;
  final events = <String>[];

  @override
  bool get supportsRich => false;
  @override
  Map<String, String?> get environment => const {};

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() {
      events.add('restore');
      if (restoreError != null) throw restoreError!;
    });
  }
}
