import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('supplied logical gesture remains a declaration', () async {
    final result = await Keypress('Shortcut')
        .prompt(source: SuppliedAnswer('Ctrl+A'));
    final gesture = (result as Accepted<KeyGesture>).value;
    expect(gesture.key, 'A');
    expect(gesture.modifiers, {KeyModifier.control});
    expect(gesture.provenance, KeyGestureProvenance.declared);
  });
}
