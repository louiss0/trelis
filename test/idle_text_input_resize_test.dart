import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test('an idle notification repaints at new geometry without changing draft, caret, or events', () async {
    final keys = StreamController<String>();
    final resized = StreamController<void>();
    final output = StringBuffer();
    final transcript = TextInputTranscript();
    final observer = _ResizeObserver(
      resized.stream,
      () => (columns: 10, rows: 4),
    );

    final result = TextInput('A long label', initialValue: 'abcdefgh').prompt(
      source: ScriptedInput(
        keys.stream,
        output,
        outputProfile: _rich(columns: 30),
        transcript: transcript,
        resizeObserver: observer,
      ),
      mode: PromptMode.rich,
    );
    await pumpEventQueue();
    resized.add(null);
    await pumpEventQueue();

    expect(transcript.currentView!.text, 'abcdefgh');
    expect(transcript.currentView!.caret, 8);
    expect(transcript.events.map((event) => event.kind), [
      TextInputPresentationEventKind.opened,
    ]);
    expect(output.toString(), contains('> <cdefgh'));

    keys.add('\r');
    expect((await result as Accepted<String>).value, 'abcdefgh');
    await keys.close();
    await resized.close();
  });

  test('identical, unknown, zero, and failing resize observations do not fabricate geometry or events', () async {
    final keys = StreamController<String>();
    final resized = StreamController<void>();
    final output = StringBuffer();
    final transcript = TextInputTranscript();
    var calls = 0;
    final observer = _ResizeObserver(resized.stream, () {
      calls++;
      return switch (calls) {
        1 => (columns: 20, rows: 4),
        2 => null,
        3 => (columns: 0, rows: 4),
        _ => throw StateError('dimension probe failed'),
      };
    });
    final result = TextInput('Name', initialValue: 'abcdefgh').prompt(
      source: ScriptedInput(
        keys.stream,
        output,
        outputProfile: _rich(columns: 20),
        transcript: transcript,
        resizeObserver: observer,
      ),
      mode: PromptMode.rich,
    );
    await pumpEventQueue();
    resized.addError(StateError('watcher failed'));
    await pumpEventQueue();
    for (var i = 0; i != 4; i++) {
      resized.add(null);
      await pumpEventQueue();
    }
    expect(transcript.currentView!.text, 'abcdefgh');
    expect(transcript.currentView!.caret, 8);
    expect(transcript.events, hasLength(1));
    expect(RegExp(r'> abcdefgh').allMatches(output.toString()).length, 1);

    keys.add('\r');
    await result;
    await keys.close();
    await resized.close();
  });

  test('resize observation is cancelled when the prompt exits', () async {
    final keys = StreamController<String>();
    late final _ResizeObserver observer;
    final resized = StreamController<void>(
      onCancel: () => observer.cancelled = true,
    );
    observer = _ResizeObserver(resized.stream, () => (columns: 10, rows: 4));
    final result = TextInput('Name').prompt(
      source: ScriptedInput(
        keys.stream,
        StringBuffer(),
        outputProfile: _rich(columns: 20),
        resizeObserver: observer,
      ),
      mode: PromptMode.rich,
    );
    await pumpEventQueue();
    keys.add('\r');
    await result;
    await pumpEventQueue();
    expect(observer.cancelled, isTrue);
    await keys.close();
    await resized.close();
  });
}

OutputProfile _rich({required int columns}) => OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: columns, rows: 4),
);

final class _ResizeObserver implements TerminalResizeObserver {
  _ResizeObserver(this.notifications, this._dimensions);

  @override
  final Stream<void> notifications;
  final ({int columns, int rows})? Function() _dimensions;
  bool cancelled = false;

  @override
  ({int columns, int rows})? readDimensions() => _dimensions();

  @override
  Duration get fallbackInterval => const Duration(days: 1);
}
