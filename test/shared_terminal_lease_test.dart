import 'dart:async';

import 'package:trelis/src/shared_terminal.dart';
import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a lease is acquired for one operation and restored after it succeeds',
    () async {
      final terminal = _SeamTerminal(Stream.value('Ada\r'));

      final result = await SharedTerminalLease.run(
        terminal,
        () async => 'done',
      );

      expect(result, 'done');
      expect(terminal.events, ['acquire', 'restore']);
    },
  );

  test(
    'a failed acquisition starts no operation and restores nothing',
    () async {
      final failure = StateError('acquisition failed');
      final terminal = _SeamTerminal(
        const Stream<String>.empty(),
        acquireError: failure,
      );
      var ran = false;

      await expectLater(
        SharedTerminalLease.run(terminal, () async {
          ran = true;
        }),
        throwsA(same(failure)),
      );

      expect(ran, isFalse);
      expect(terminal.events, ['acquire']);
    },
  );

  test('a successful operation with a failing restoration reports the restoration error', () async {
    final failure = StateError('restoration failed');
    final terminal = _SeamTerminal(
      const Stream<String>.empty(),
      restoreError: failure,
    );

    await expectLater(
      SharedTerminalLease.run(terminal, () async => 'done'),
      throwsA(same(failure)),
    );
    expect(terminal.events, ['acquire', 'restore']);
  });

  test(
    'a primary failure and a restoration failure remain both observable',
    () async {
      const canary = 'CANARY-lease-draft';
      final operationError = StateError('operation failed: $canary');
      final restorationError = StateError('restoration failed: $canary');
      final terminal = _SeamTerminal(
        const Stream<String>.empty(),
        restoreError: restorationError,
      );

      final failure =
          await SharedTerminalLease.run(
            terminal,
            () => Future<String>.error(operationError),
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
              same(operationError),
            )
            .having(
              (error) => error.restorationError,
              'restoration error',
              same(restorationError),
            ),
      );
      expect(
        failure.toString(),
        isNot(contains(canary)),
        reason: 'diagnostics must not stringify application failures',
      );
      expect(terminal.events, ['acquire', 'restore']);
    },
  );

  test(
    'a native-style restore callback is shared through the same seam',
    () async {
      final events = <String>[];
      final result = await SharedTerminalLease.restoreAfter(() async {
        events.add('operation');
        return 42;
      }, () => events.add('restore'));

      expect(result, 42);
      expect(events, ['operation', 'restore']);
    },
  );
}

final class _SeamTerminal implements TerminalIo {
  _SeamTerminal(this.input, {this.acquireError, this.restoreError});

  @override
  final Stream<String> input;
  @override
  final output = StringBuffer();
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
