import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
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
