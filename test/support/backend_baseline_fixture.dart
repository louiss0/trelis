import 'dart:async';

import 'package:prompty/prompty.dart';

/// Deterministic adapter for a public scripted prompt seam.
final class PromptFixture {
  PromptFixture({
    this.supportsRich = false,
    EnvironmentFixture? environment,
    this.geometry,
    this.clock,
  }) : environment = environment ?? EnvironmentFixture.baseline();

  final bool supportsRich;
  final EnvironmentFixture environment;
  final TerminalGeometryFixture? geometry;
  final ManualClock? clock;
  final RecordedOutput selectedOutput = RecordedOutput();
  final StreamController<String> _input = StreamController<String>();

  ScriptedInput get source =>
      ScriptedInput(_input.stream, selectedOutput, supportsRich: supportsRich);

  void add(String data) => _input.add(data);

  void fail(Object error, [StackTrace? stackTrace]) =>
      _input.addError(error, stackTrace);

  Future<void> close() => _input.close();
}

/// A declared environment, independent of the host process environment.
final class EnvironmentFixture {
  EnvironmentFixture(Map<String, String?> values)
    : values = Map.unmodifiable(values);

  factory EnvironmentFixture.baseline() =>
      EnvironmentFixture({'TERM': 'dumb', 'COLORTERM': null, 'NO_COLOR': '1'});

  final Map<String, String?> values;

  String? operator [](String name) => values[name];
}

/// Positive terminal dimensions declared by a synthetic rich scenario.
final class TerminalGeometryFixture {
  TerminalGeometryFixture({required this.columns, required this.rows}) {
    if (columns <= 0 || rows <= 0) {
      throw ArgumentError('Terminal geometry must be positive.');
    }
  }

  final int columns;
  final int rows;

  @override
  bool operator ==(Object other) =>
      other is TerminalGeometryFixture &&
      columns == other.columns &&
      rows == other.rows;

  @override
  int get hashCode => Object.hash(columns, rows);
}

/// An application-controlled clock for deterministic harness scheduling.
final class ManualClock {
  ManualClock(this._now);

  DateTime _now;

  DateTime get now => _now;

  void elapse(Duration duration) {
    _now = _now.add(duration);
  }
}

/// A deterministic selected-output recording adapter.
final class RecordedOutput implements StringSink {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _buffer.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);
}

/// A selected-output adapter that fails on every write deterministically.
final class FailingOutput implements StringSink {
  FailingOutput(this.error);

  final Object error;
  int writeAttempts = 0;

  Never _fail() {
    writeAttempts++;
    throw error;
  }

  @override
  void write(Object? object) => _fail();

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) => _fail();

  @override
  void writeCharCode(int charCode) => _fail();

  @override
  void writeln([Object? object = '']) => _fail();
}
