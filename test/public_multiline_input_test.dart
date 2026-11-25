import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/trelis.dart';

void main() {
  group('public rich Multiline input gestures', () {
    test('Enter then separately delivered Ctrl+J finishes with the trailing blank line', () async {
      final input = StreamController<String>();
      final output = StringBuffer();
      final theme = _theme(input.stream, output);
      final pending = theme.multiline('Notes').prompt().then((result) {
        expect(result, isA<Accepted<String>>());
        return (result as Accepted<String>).value;
      });

      await _waitUntil(() => output.toString().contains('Line 1:'));
      input.add('one');
      await _waitUntil(() => output.toString().contains('Line 1: one'));
      input.add('\r');
      await _waitUntil(() => output.toString().contains('Line 2:'));
      input.add('\n');
      await input.close();

      expect(await pending, 'one\n');
    });

    test('validation failure preserves the draft for a later Ctrl+J', () async {
      final input = StreamController<String>();
      final output = StringBuffer();
      final validated = <String>[];
      final theme = _theme(input.stream, output);
      final pending = theme
          .multiline(
            'Notes',
            validate: (value) {
              validated.add(value);
              return validated.length == 1 ? 'not yet' : null;
            },
          )
          .prompt()
          .then((result) {
            expect(result, isA<Accepted<String>>());
            return (result as Accepted<String>).value;
          });

      await _waitUntil(() => output.toString().contains('Line 1:'));
      input.add('bad');
      await _waitUntil(() => output.toString().contains('Line 1: bad'));
      input.add('\r');
      await _waitUntil(() => output.toString().contains('Line 2:'));
      input.add('\n');
      await _waitUntil(() => output.toString().contains('not yet'));

      input.add('\n');
      await input.close();

      expect(await pending, 'bad\n');
      expect(validated, ['bad\n', 'bad\n']);
    });

    test('same-event CRLF is newline data rather than finish', () async {
      final input = StreamController<String>();
      final output = StringBuffer();
      final theme = _theme(input.stream, output);
      final pending = theme.multiline('Notes').prompt().then((result) {
        expect(result, isA<Accepted<String>>());
        return (result as Accepted<String>).value;
      });

      await _waitUntil(() => output.toString().contains('Line 1:'));
      input.add('one\r\ntwo');
      await _waitUntil(() => output.toString().contains('Line 2: two'));
      input.add('\n');
      await input.close();

      expect(await pending, 'one\ntwo');
    });

    test('framed CRLF paste remains draft data until Ctrl+J', () async {
      final input = StreamController<String>();
      final output = StringBuffer();
      final theme = _theme(input.stream, output);
      final pending = theme.multiline('Notes').prompt().then((result) {
        expect(result, isA<Accepted<String>>());
        return (result as Accepted<String>).value;
      });

      await _waitUntil(() => output.toString().contains('Line 1:'));
      input.add('\x1b[200~one\r\ntwo\x1b[201~');
      await _waitUntil(() => output.toString().contains('Line 2: two'));
      input.add('\n');
      await input.close();

      expect(await pending, 'one\ntwo');
    });
  });
}

AsciiTheme _theme(Stream<String> input, StringSink output) => AsciiTheme(
  io: TerminalEnvironment.scripted(
    input: input,
    output: output,
    profile: _richProfile,
    supportsRich: true,
  ),
  interaction: const InteractionPreferences(mode: PromptMode.rich),
);

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 400; i++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition was not met before the test deadline');
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.none,
  geometry: OutputGeometry.fixed(columns: 60, rows: 12),
);
