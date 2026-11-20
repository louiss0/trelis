import 'dart:async';

import 'package:trelis/src/shared_terminal.dart';
import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

void main() {
  test('one owned writer delivers updates and stops after closure', () {
    final output = StringBuffer();
    final writer = SharedOutputCoordinator(output);

    writer.write((sink) => sink.writeln('started'));
    writer.write((sink) => sink.writeln('updated'));
    writer.close();
    writer.write((sink) => sink.writeln('late'));

    expect(output.toString(), 'started\nupdated\n');
  });

  test('a writer failure is observable and later writes replay it', () {
    final failure = StateError('writer failed');
    final output = _ThrowingSink(failure);
    final retireCalls = <Object>[];
    final writer = SharedOutputCoordinator(
      output,
      onFailure: (error, _) {
        retireCalls.add(error);
      },
    );

    expect(
      () => writer.write((sink) => sink.writeln('bad')),
      throwsA(same(failure)),
    );
    expect(writer.failure, same(failure));
    expect(retireCalls, [same(failure)]);

    expect(
      () => writer.write((sink) => sink.writeln('good')),
      throwsA(same(failure)),
    );
    expect(output.writes, 1);
  });

  test(
    'a writer failure retires a shared reader without a competing subscription',
    () async {
      final failure = StateError('writer failed');
      final input = StreamController<String>();
      final readers = SharedReaderCoordinator();
      final reader = await readers.readerFor(input.stream);
      final pending = reader.next();
      final writer = SharedOutputCoordinator(
        StringBuffer(),
        onFailure: (error, stackTrace) {
          readers.retire(error, stackTrace);
        },
      );

      expect(() => writer.write((_) => throw failure), throwsA(same(failure)));

      await expectLater(pending, throwsA(same(failure)));
      await readers.close();
      await input.close();
    },
  );

  test('a writer failure and a restoration failure keep both causes', () async {
    const canary = 'CANARY-feedback-draft';
    final writerError = StateError('writer failed: $canary');
    final restorationError = StateError('restore failed: $canary');
    final writer = SharedOutputCoordinator(_ThrowingSink(writerError));

    final failure =
        await SharedTerminalLease.restoreAfter(() async {
          writer.write((sink) => sink.writeln('failed'));
        }, () => throw restorationError).then<Object?>(
          (value) => value,
          onError: (Object error, StackTrace _) => error,
        );

    expect(
      failure,
      isA<TerminalRestorationException>()
          .having(
            (error) => error.operationError,
            'operation error',
            same(writerError),
          )
          .having(
            (error) => error.restorationError,
            'restoration error',
            same(restorationError),
          ),
    );
    expect(failure.toString(), isNot(contains(canary)));
  });
}

final class _ThrowingSink implements StringSink {
  _ThrowingSink(this.error);

  final Object error;
  var writes = 0;

  @override
  void write(Object? object) {
    writes++;
    throw error;
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      write('');

  @override
  void writeCharCode(int charCode) => write('');

  @override
  void writeln([Object? object = '']) => write('');
}
