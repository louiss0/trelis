import 'dart:async';

import 'package:trelis/src/shared_terminal.dart';
import 'package:test/test.dart';

void main() {
  test('an idle coordinator owns no reader and can be closed', () async {
    final coordinator = SharedReaderCoordinator();

    expect(coordinator.hasActiveReader, isFalse);
    await coordinator.close();
    expect(
      coordinator.readerFor(const Stream<String>.empty()),
      throwsStateError,
    );
  });

  test('participants share one reader and one input subscription', () async {
    var listens = 0;
    final input = StreamController<String>(onListen: () => listens++);
    final stream = input.stream;
    final coordinator = SharedReaderCoordinator();

    final first = await coordinator.readerFor(stream);
    final second = await coordinator.readerFor(stream);

    expect(second, same(first));
    expect(listens, 1);
    input.add('Ada\r');
    await input.close();
    expect(await first.next(), 'A');
    expect(await first.next(), 'd');
    expect(await first.next(), 'a');
    expect(await first.next(), '\r');
    expect(await first.next(), isNull);
    await coordinator.close();
  });

  test(
    'sequential inputs replace the reader and cancel the old subscription',
    () async {
      var firstCancels = 0;
      var secondListens = 0;
      final firstInput = StreamController<String>(
        onCancel: () => firstCancels++,
      );
      final secondInput = StreamController<String>(
        onListen: () => secondListens++,
      );
      final firstStream = firstInput.stream;
      final secondStream = secondInput.stream;
      final coordinator = SharedReaderCoordinator();
      final first = await coordinator.readerFor(firstStream);
      coordinator.release(first);
      await first.close();

      expect(coordinator.hasActiveReader, isFalse);
      final second = await coordinator.readerFor(secondStream);

      expect(second, isNot(same(first)));
      expect(coordinator.hasActiveReader, isTrue);
      expect(firstCancels, 1);
      expect(secondListens, 1);
      await coordinator.close();
      await firstInput.close();
      await secondInput.close();
    },
  );

  test(
    'retirement ends a pending read and a later reader in the period',
    () async {
      final failure = StateError('shared writer failed');
      final input = StreamController<String>();
      final stream = input.stream;
      final coordinator = SharedReaderCoordinator();
      final reader = await coordinator.readerFor(stream);
      final pending = reader.next();

      coordinator.retire(failure, StackTrace.current);

      final laterInput = StreamController<String>();
      await expectLater(pending, throwsA(same(failure)));
      final laterReader = await coordinator.readerFor(laterInput.stream);
      await expectLater(laterReader.next(), throwsA(same(failure)));
      await coordinator.close();
      await input.close();
      await laterInput.close();
    },
  );

  test(
    'subscription cancellation failure remains observable on close',
    () async {
      final failure = StateError('reader cancellation failed');
      final input = StreamController<String>(
        onCancel: () => Future<void>.error(failure),
      );
      final coordinator = SharedReaderCoordinator();
      await coordinator.readerFor(input.stream);

      await expectLater(coordinator.close(), throwsA(same(failure)));
      expect(coordinator.hasActiveReader, isFalse);
      await input.close();
    },
  );

  test('the shared reader keeps escape and paste parsing behaviour', () async {
    final input = StreamController<String>();
    final coordinator = SharedReaderCoordinator();
    final reader = await coordinator.readerFor(input.stream);

    input.add('\x1b[200~Ada\r\x1b[201~');
    await input.close();

    expect(await reader.next(), '\x1b[200~Ada\r\x1b[201~');
    expect(await reader.next(), isNull);
    await coordinator.close();
  });
}
