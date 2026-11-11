import 'package:prompty/src/text_measurement.dart';
import 'package:test/test.dart';

void main() {
  test('maps supported graphemes to declared display-cell widths', () {
    final map = TextDisplayMap('e\u0301中·🇺🇳👍🏽👩‍🔬❤️1️⃣1⃣');

    expect(map.entries.map((entry) => entry.cellWidth), [
      1,
      2,
      1,
      2,
      2,
      2,
      2,
      2,
      2,
    ]);
    expect(map.caretCells(0), 0);
    expect(map.caretCells(4), 6);
    expect(map.caretCells(8), 14);
  });

  test('uses visible safe representations for controls and formats', () {
    final map = TextDisplayMap('\t\n\x1b\u202E\u200D\u0301');

    expect(map.entries.map((entry) => entry.display), [
      r'\u{0009}',
      r'\u{000A}',
      r'\u{001B}',
      r'\u{202E}',
      r'\u{200D}́',
    ]);
    expect(map.entries.take(4).every((entry) => entry.cellWidth == 8), isTrue);
    expect(map.entries.last.cellWidth, 9);
  });

  test(
    'uses declared narrow or wide ambiguous policy without changing data',
    () {
      expect(TextDisplayMap('·').cellWidth, 1);
      expect(TextDisplayMap('·', ambiguousIsWide: true).cellWidth, 2);
    },
  );
}
