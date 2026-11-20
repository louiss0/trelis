import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/background_query.dart';
import 'package:trelis/src/shared_terminal.dart';
import 'package:trelis/trelis.dart';

void main() {
  test(
    'a valid OSC response is consumed while keyboard bytes retain order',
    () async {
      final input = StreamController<String>();
      final coordinator = SharedReaderCoordinator();
      final reader = await coordinator.readerFor(input.stream);
      final requests = <String>[];

      final pending = reader.queryBackground(
        writeRequest: () => requests.add(osc11BackgroundRequest),
      );
      input.add('A');
      input.add('\x1b]11;rgb:ffff/ffff/ffff\x07');
      input.add('B\r');
      await input.close();

      expect(await pending, BackgroundQueryResult.light);
      expect(requests, [osc11BackgroundRequest]);

      final keys = <String>[];
      String? key;
      while ((key = await reader.next()) != null) {
        keys.add(key!);
      }
      expect(keys.join(), 'AB\r');
      await coordinator.close();
    },
  );

  test(
    'malformed and late replies remain input around one valid reply',
    () async {
      final input = StreamController<String>();
      final coordinator = SharedReaderCoordinator();
      final reader = await coordinator.readerFor(input.stream);
      const malformed = '\x1b]11;rgb:zzzz/ffff/ffff\x07';
      const late = '\x1b]11;rgb:ffff/ffff/ffff\x07';
      const unsolicited = '\x1b]12;rgb:ffff/ffff/ffff\x07';

      final pending = reader.queryBackground(writeRequest: () {});
      input.add(malformed);
      input.add('\x1b]11;rgb:0000/0000/0000\x07');
      input.add(late);
      input.add(unsolicited);
      await input.close();

      expect(await pending, BackgroundQueryResult.dark);
      expect(await _drain(reader), malformed + late + unsolicited);
      await coordinator.close();
    },
  );

  test(
    'a partial reply waits for completion while other bytes keep order',
    () async {
      final input = StreamController<String>();
      final coordinator = SharedReaderCoordinator();
      final reader = await coordinator.readerFor(input.stream);
      const paste = '\x1b[200~X\tY\x1b[201~';

      final pending = reader.queryBackground(writeRequest: () {});
      input.add('\x1b]11;rgb:ffff/ff');
      input.add('ff/ffff\x07');
      input.add('A');
      input.add(paste);
      input.add('B\r');
      await input.close();

      expect(await pending, BackgroundQueryResult.light);
      expect(await _drain(reader), 'A${paste}B\r');
      await coordinator.close();
    },
  );

  test(
    'the fixed bound falls back and preserves a partial and late reply',
    () async {
      final input = StreamController<String>();
      final coordinator = SharedReaderCoordinator();
      final reader = await coordinator.readerFor(input.stream);
      const partial = '\x1b]11;rgb:ffff/ff';
      const late = '\x1b]11;rgb:0000/0000/0000\x07';
      final watch = Stopwatch()..start();

      final pending = reader.queryBackground(writeRequest: () {});
      input.add(partial);

      expect(await pending, BackgroundQueryResult.unavailable);
      expect(
        watch.elapsedMilliseconds,
        inInclusiveRange(backgroundQueryTimeout.inMilliseconds - 20, 1000),
      );
      input.add(late);
      await input.close();
      expect(await _drain(reader), partial + late);
      await coordinator.close();
    },
  );

  test(
    'a session query uses its own reader and leaves input in order',
    () async {
      var listens = 0;
      final input = StreamController<String>(onListen: () => listens++);
      final output = _QuerySink();
      final environment = TerminalEnvironment.scripted(
        input: input.stream,
        output: output,
        profile: OutputProfile(
          cursor: CapabilitySupport.supported,
          colorDepth: ColorDepth.rgb,
          geometry: OutputGeometry.fixed(columns: 80, rows: 24),
        ),
      );

      await TerminalSession.run(
        (session) async {
          final query = session.queryBackground();
          await output.requested.future;
          input.add('\x1b]11;rgb:ffff/ffff/ffff\x07');
          input.add('A\r');
          await input.close();

          expect(await query, BackgroundQueryResult.light);
          final answer = await TextInput('Name').prompt(session: session);
          expect((answer as Accepted<String>).value, 'A');
        },
        terminal: environment,
        mode: PromptMode.linear,
      );

      expect(listens, 1);
      expect(output.text, contains(osc11BackgroundRequest));
    },
  );

  test(
    'a query write failure falls back without escaping the session',
    () async {
      final failure = StateError('cannot write query');
      final environment = TerminalEnvironment.scripted(
        input: const Stream<String>.empty(),
        output: _ThrowingSink(failure),
        profile: const OutputProfile(colorDepth: ColorDepth.rgb),
      );

      await TerminalSession.run(
        (session) async {
          expect(
            await session.queryBackground(),
            BackgroundQueryResult.unavailable,
          );
        },
        terminal: environment,
        mode: PromptMode.linear,
      );
    },
  );

  test('an OSC reply with no query waiting is ordinary input', () async {
    final input = StreamController<String>();
    final coordinator = SharedReaderCoordinator();
    final reader = await coordinator.readerFor(input.stream);
    const response = '\x1b]11;rgb:0000/0000/0000\x07';

    input.add(response);
    input.add('A');
    await input.close();

    expect(await _drain(reader), '${response}A');
    await coordinator.close();
  });
}

Future<String> _drain(SharedTerminalReader reader) async {
  final buffer = StringBuffer();
  String? key;
  while ((key = await reader.next()) != null) {
    buffer.write(key);
  }
  return buffer.toString();
}

final class _QuerySink implements StringSink {
  final _buffer = StringBuffer();
  final requested = Completer<void>();

  String get text => _buffer.toString();

  @override
  void write(Object? object) {
    _buffer.write(object);
    if (text.contains(osc11BackgroundRequest) && !requested.isCompleted) {
      requested.complete();
    }
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    for (final object in objects) {
      write(object);
      if (separator.isNotEmpty) write(separator);
    }
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) {
    write(object);
    write('\n');
  }
}

final class _ThrowingSink implements StringSink {
  _ThrowingSink(this.failure);

  final Object failure;

  @override
  void write(Object? object) =>
      Error.throwWithStackTrace(failure, StackTrace.empty);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      write(objects.join(separator));

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => write(object);
}
