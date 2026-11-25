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

  test('CRLF in one decoded input event emits only the CR gesture', () async {
    final input = StreamController<String>();
    final coordinator = SharedReaderCoordinator();
    final reader = await coordinator.readerFor(input.stream);

    input.add('a\r\nb');
    await input.close();

    expect(await reader.next(), 'a');
    expect(await reader.next(), '\r');
    expect(await reader.next(), 'b');
    expect(await reader.next(), isNull);
    await coordinator.close();
  });

  test('CR and LF in separate input events remain distinct gestures', () async {
    final input = StreamController<String>();
    final coordinator = SharedReaderCoordinator();
    final reader = await coordinator.readerFor(input.stream);

    input.add('a\r');
    await pumpEventQueue();
    input.add('\nb');
    await input.close();

    expect(await reader.next(), 'a');
    expect(await reader.next(), '\r');
    expect(await reader.next(), '\n');
    expect(await reader.next(), 'b');
    expect(await reader.next(), isNull);
    await coordinator.close();
  });

  test('framed paste remains atomic when CRLF crosses input events', () async {
    final input = StreamController<String>();
    final coordinator = SharedReaderCoordinator();
    final reader = await coordinator.readerFor(input.stream);

    input.add('\x1b[200~one\r');
    await pumpEventQueue();
    input.add('\ntwo\x1b[201~');
    await input.close();

    expect(await reader.next(), '\x1b[200~one\r\ntwo\x1b[201~');
    expect(await reader.next(), isNull);
    await coordinator.close();
  });

  test('framed paste remains atomic when the opener fractures beyond the '
      'escape disambiguation window', () async {
    // Pty, ssh and pseudoconsole transports may split the paste opener
    // across reads with arbitrarily long gaps. The opener is unambiguous
    // sequence data, not a keypress, so the escape disambiguation window
    // must never corrupt it into a bare escape plus typed text.
    final input = StreamController<String>();
    final coordinator = SharedReaderCoordinator();
    final reader = await coordinator.readerFor(input.stream);

    input.add('\x1b[20');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    input.add('0~x\r\n/cancel\x1b[201~');
    await input.close();

    expect(await reader.next(), '\x1b[200~x\r\n/cancel\x1b[201~');
    expect(await reader.next(), isNull);
    await coordinator.close();
  });

  test('a bare escape still flushes after the disambiguation window', () async {
    final input = StreamController<String>();
    final coordinator = SharedReaderCoordinator();
    final reader = await coordinator.readerFor(input.stream);

    input.add('\x1b');
    final key = await reader.next().timeout(
      const Duration(seconds: 2),
      onTimeout: () => '<timed out>',
    );
    expect(key, '\x1b');
    await input.close();
    await coordinator.close();
  });

  test(
    'an escape followed within the window by non-sequence text stays a key',
    () async {
      final input = StreamController<String>();
      final coordinator = SharedReaderCoordinator();
      final reader = await coordinator.readerFor(input.stream);

      input.add('\x1b');
      await pumpEventQueue();
      input.add('a');
      await input.close();

      expect(await reader.next(), '\x1b');
      expect(await reader.next(), 'a');
      expect(await reader.next(), isNull);
      await coordinator.close();
    },
  );
}
