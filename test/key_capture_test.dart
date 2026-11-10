import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'key capture instances reject overlapping sessions and can be reused',
    () async {
      for (final chord in [false, true]) {
        final input = StreamController<String>();
        final key = Keypress('Key');
        final sequence = KeyChordInput('Sequence');
        final pending = chord
            ? sequence.prompt(
                source: ScriptedInput(input.stream, StringBuffer()),
              )
            : key.prompt(source: ScriptedInput(input.stream, StringBuffer()));
        if (chord) {
          await expectLater(
            sequence.prompt(source: SuppliedAnswer('A')),
            throwsStateError,
          );
        } else {
          await expectLater(
            key.prompt(source: SuppliedAnswer('A')),
            throwsStateError,
          );
        }
        await input.close();
        await pending;
        final result = chord
            ? await sequence.prompt(source: SuppliedAnswer('A'))
            : await key.prompt(source: SuppliedAnswer('A'));
        expect(result, isA<Accepted>());
      }
    },
  );
  test('key capture rejects unsafe labels', () {
    expect(() => Keypress('\x1b[2J'), throwsArgumentError);
    expect(() => KeyChordInput('  '), throwsArgumentError);
  });

  test(
    'declarations retain letter case in single and sequence prompts',
    () async {
      final single = await Keypress('Shortcut')
          .prompt(source: SuppliedAnswer('Shift+a'));
      final gesture = (single as Accepted<KeyGesture>).value;
      expect(gesture.key, 'a');
      expect(gesture.modifiers, {KeyModifier.shift});
      expect(gesture.provenance, KeyGestureProvenance.declared);

      final sequence = await KeyChordInput('Sequence')
          .prompt(source: SuppliedAnswer('Ctrl+a,Shift+A'));
      final gestures = (sequence as Accepted<List<KeyGesture>>).value;
      expect(gestures.map((g) => g.key), ['a', 'A']);
      expect(gestures.map((g) => g.provenance), [
        KeyGestureProvenance.declared,
        KeyGestureProvenance.declared,
      ]);
    },
  );

  test('scripted captures retain received letter case and ambiguity', () async {
    final result = await KeyChordInput('Sequence').prompt(
      source: ScriptedInput(Stream.value('cacA\r'), StringBuffer()),
      mode: PromptMode.rich,
    );
    final gestures = (result as Accepted<List<KeyGesture>>).value;
    expect(gestures.map((g) => g.key), ['a', 'A']);
    expect(gestures.map((g) => g.modifiers), [
      <KeyModifier>{},
      <KeyModifier>{},
    ]);
    expect(gestures.map((g) => g.provenance), [
      KeyGestureProvenance.ambiguous,
      KeyGestureProvenance.ambiguous,
    ]);
  });

  test('legacy arrow capture retains ambiguous provenance', () async {
    final result = await Keypress('Shortcut').prompt(
      source: ScriptedInput(Stream.value('c\x1b[A\r'), StringBuffer()),
      mode: PromptMode.rich,
    );
    final gesture = (result as Accepted<KeyGesture>).value;
    expect(gesture.key, 'ArrowUp');
    expect(gesture.provenance, KeyGestureProvenance.ambiguous);
  });

  test(
    'capture alone never submits and Ctrl+C interrupts when armed',
    () async {
      expect(
        await Keypress('Shortcut').prompt(
          source: ScriptedInput(Stream.value('ca'), StringBuffer()),
          mode: PromptMode.rich,
        ),
        isA<InputEnded<KeyGesture>>(),
      );
      expect(
        await Keypress('Shortcut').prompt(
          source: ScriptedInput(Stream.value('c\x03'), StringBuffer()),
          mode: PromptMode.rich,
        ),
        isA<Interrupted<KeyGesture>>(),
      );
    },
  );

  test('observation policy rejects ambiguous stream capture', () async {
    final out = StringBuffer();
    final result = await Keypress('Shortcut', requireObservation: true).prompt(
      source: ScriptedInput(Stream.value('ca\r'), out),
      mode: PromptMode.rich,
    );
    expect(result, isA<InputEnded<KeyGesture>>());
    expect(out.toString(), contains('Observation required'));
  });

  test('rich sequence can remove last and clear before review', () async {
    final result = await KeyChordInput('Sequence').prompt(
      source: ScriptedInput(Stream.value('cacbrxcz\r'), StringBuffer()),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<List<KeyGesture>>).value.map((g) => g.key), [
      'z',
    ]);
  });

  test('Escape cancels armed capture before root cancellation', () async {
    final out = StringBuffer();
    final result = await Keypress('Shortcut').prompt(
      source: ScriptedInput(Stream.value('c\x1b\x1b'), out),
      mode: PromptMode.rich,
    );
    expect(result, isA<Cancelled<KeyGesture>>());
    expect(out.toString(), contains('Capture cancelled'));
  });

  test('linear declaration is reviewed and explicitly submitted', () async {
    final out = StringBuffer();
    final result = await Keypress('Shortcut').prompt(
      source: ScriptedInput(Stream.value('/declare\rCtrl+C\r/done\r'), out),
      mode: PromptMode.linear,
    );
    final gesture = (result as Accepted<KeyGesture>).value;
    expect(gesture.provenance, KeyGestureProvenance.declared);
    expect(gesture.warnings.join(' '), contains('reserved'));
    expect(out.toString(), contains('unverified'));
  });

  test(
    'reserved declarations retain unverified and reserved warnings',
    () async {
      final result = await Keypress('Shortcut')
          .prompt(source: SuppliedAnswer('Ctrl+C'));
      final gesture = (result as Accepted<KeyGesture>).value;
      expect(gesture.warnings.join(' '), contains('reserved'));
      expect(gesture.warnings.join(' '), contains('unverified'));
    },
  );

  test('linear capture reviews and submits an ordered sequence', () async {
    final out = StringBuffer();
    final result = await KeyChordInput('Sequence').prompt(
      source: ScriptedInput(Stream.value('/capture\ra/capture\rb/done\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<KeyGesture>>).value.map((g) => g.key), [
      'a',
      'b',
    ]);
    expect(out.toString(), contains('Review:'));
  });

  test(
    'rich key sequence captures ordered gestures and submits explicitly',
    () async {
      final result = await KeyChordInput('Sequence').prompt(
        source: ScriptedInput(Stream.value('cacb\r'), StringBuffer()),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<List<KeyGesture>>).value.map((g) => g.key), [
        'a',
        'b',
      ]);
    },
  );

  test('rich capture returns to review before explicit submission', () async {
    final out = StringBuffer();
    final result = await Keypress('Shortcut').prompt(
      source: ScriptedInput(Stream.value('ca\r'), out),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<KeyGesture>).value.key, 'a');
    expect(out.toString(), contains('Review'));
  });

  test(
    'a supplied key sequence retains ordered declaration provenance',
    () async {
      final result = await KeyChordInput('Sequence')
          .prompt(source: SuppliedAnswer('Ctrl+A,Alt+B'));
      final gestures = (result as Accepted<List<KeyGesture>>).value;
      expect(gestures.map((g) => g.key), ['A', 'B']);
      expect(gestures.map((g) => g.modifiers), [
        {KeyModifier.control},
        {KeyModifier.alt},
      ]);
      expect(
        gestures.every((g) => g.provenance == KeyGestureProvenance.declared),
        isTrue,
      );
    },
  );

  test('observation-required policy rejects a supplied declaration', () async {
    final result = await Keypress(
      'Shortcut',
      requireObservation: true,
    ).prompt(source: SuppliedAnswer('Ctrl+A'));
    expect(result, isA<Unavailable<KeyGesture>>());
  });

  test('invalid logical key names are rejected rather than invented', () async {
    final result = await Keypress('Shortcut')
        .prompt(source: SuppliedAnswer('Ctrl+NotAKey'));
    expect(result, isA<Unavailable<KeyGesture>>());
  });

  test('supplied logical gesture remains a declaration', () async {
    final result = await Keypress('Shortcut')
        .prompt(source: SuppliedAnswer('Ctrl+A'));
    final gesture = (result as Accepted<KeyGesture>).value;
    expect(gesture.key, 'A');
    expect(gesture.modifiers, {KeyModifier.control});
    expect(gesture.provenance, KeyGestureProvenance.declared);
  });
}
