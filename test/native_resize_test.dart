import 'dart:async';
import 'dart:io';

import 'package:trelis/trelis.dart';
import 'package:trelis/src/native_resize.dart';
import 'package:test/test.dart';

void main() {
  test('a console observation reports the live geometry it reads', () {
    var reads = 0;
    final observer = NativeConsoleResizeObserver(() {
      reads++;
      return (columns: 40, rows: 12);
    });

    expect(observer.readDimensions(), (columns: 40, rows: 12));
    expect(reads, 1);
  });

  test('unknown, zero, negative and failing readings are unusable', () {
    final readings = <({int columns, int rows})? Function()>[
      () => null,
      () => (columns: 0, rows: 12),
      () => (columns: 40, rows: 0),
      () => (columns: -1, rows: 12),
      () => throw const FileSystemException('console geometry unavailable'),
    ];

    for (final read in readings) {
      expect(NativeConsoleResizeObserver(read).readDimensions(), isNull);
    }
  });

  test('a console observation coalesces by reporting, not by remembering', () {
    var dimensions = (columns: 80, rows: 24);
    final observer = NativeConsoleResizeObserver(() => dimensions);

    expect(observer.readDimensions(), (columns: 80, rows: 24));
    dimensions = (columns: 30, rows: 10);
    expect(observer.readDimensions(), (columns: 30, rows: 10));
  });

  test('a native observation reads the console the prompt paints to', () {
    expect(
      nativeConsoleResizeObserver(_FakeStdout(columns: 30, rows: 8))
          .readDimensions(),
      (columns: 30, rows: 8),
    );
    expect(
      nativeConsoleResizeObserver(_FakeStdout(hasTerminal: false))
          .readDimensions(),
      isNull,
    );
    expect(
      nativeConsoleResizeObserver(_FakeStdout(fails: true)).readDimensions(),
      isNull,
    );
  });

  test('a native observation keeps a bounded fallback cadence', () {
    final observer = nativeConsoleResizeObserver(_FakeStdout());

    expect(
      observer.fallbackInterval,
      greaterThanOrEqualTo(const Duration(milliseconds: 100)),
    );
    expect(
      observer.fallbackInterval,
      lessThanOrEqualTo(const Duration(seconds: 30)),
    );
  });

  test('a POSIX console observation is woken by a window change', () async {
    if (Platform.isWindows) return;
    final observer = nativeConsoleResizeObserver(_FakeStdout());
    final seen = Completer<void>();
    final subscription = observer.notifications.listen((_) {
      if (!seen.isCompleted) seen.complete();
    });

    expect(Process.killPid(pid, ProcessSignal.sigwinch), isTrue);
    await seen.future.timeout(const Duration(seconds: 10));
    await subscription.cancel();
  });

  test('a Windows console observation has no signal source', () async {
    if (!Platform.isWindows) return;
    await expectLater(
      nativeConsoleResizeObserver(_FakeStdout()).notifications,
      emitsDone,
    );
  });

  test(
    'an idle prompt reflows from a polling-only console observation',
    () async {
      final keys = StreamController<String>();
      final output = StringBuffer();
      var columns = 80;
      final draft = '0123456789' * 6;
      final observer = NativeConsoleResizeObserver(
        () => (columns: columns, rows: 8),
      );

      final result = TextInput('Name', initialValue: draft).prompt(
        source: ScriptedInput(
          keys.stream,
          output,
          outputProfile: OutputProfile(
            cursor: CapabilitySupport.supported,
            geometry: OutputGeometry.fixed(columns: 80, rows: 8),
          ),
          resizeObserver: observer,
        ),
        mode: PromptMode.rich,
      );
      await pumpEventQueue();
      expect(output.toString(), contains('> $draft'));
      expect(output.toString(), isNot(contains('> <')));

      // The console shrinks and raises nothing: no key is sent, so only the
      // bounded fallback poll can notice the new geometry.
      columns = 30;
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(output.toString(), contains('> <'));
      keys.add('\r');
      expect((await result as Accepted<String>).value, draft);
      await keys.close();
    },
  );
}

final class _FakeStdout implements Stdout {
  _FakeStdout({
    this.columns = 80,
    this.rows = 24,
    this.hasTerminal = true,
    this.fails = false,
  });

  final int columns;
  final int rows;
  final bool fails;

  @override
  final bool hasTerminal;

  @override
  int get terminalColumns =>
      fails ? throw const StdoutException('geometry unavailable') : columns;

  @override
  int get terminalLines =>
      fails ? throw const StdoutException('geometry unavailable') : rows;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
