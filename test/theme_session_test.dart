import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/trelis.dart';

void main() {
  test(
    'prompt-first initialization acquires and resolves before output',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      final environment = _recordingEnvironment(output, events);
      final owner = ThemeSession(
        environment: environment,
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async => events.add('callback'),
      );

      final result = await owner.prompt((handle) async {
        expect(owner.resolvedInteraction?.mode, PromptMode.linear);
        output.write('prompt');
        return Accepted('ok');
      });

      expect(result, isA<Accepted<String>>());
      expect(events, ['acquire', 'callback', 'write:prompt', 'restore']);
      expect(owner.resolvedInteraction, isNull);
    },
  );
}

final class _RecordingSink implements StringSink {
  _RecordingSink(this.events);

  final List<String> events;

  @override
  void write(Object? object) => events.add('write:$object');

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

final class _RecordingTerminal implements TerminalIo {
  _RecordingTerminal(this.input, this.output, this.events);

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final List<String> events;
  @override
  bool get supportsRich => false;
  @override
  Map<String, String?> get environment => const <String, String?>{};

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}

TerminalEnvironment _recordingEnvironment(
  StringSink output,
  List<String> events, {
  Stream<String>? input,
}) => TerminalEnvironment.custom(
  adapter: _RecordingTerminal(
    input ?? const Stream<String>.empty(),
    output,
    events,
  ),
  profile: const OutputProfile(glyphs: GlyphSet.ascii),
);
