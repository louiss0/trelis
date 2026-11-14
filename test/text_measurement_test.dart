import 'package:prompty/src/presentation.dart';
import 'package:prompty/src/text_measurement.dart';
import 'package:test/test.dart';

/// Adversarial application text: controls, formats, bidi, joiners and the
/// supported grapheme forms that must keep their own shape.
const _adversarial = <String>[
  '\t\n\x1b\x7f\u0085',
  '\u202A\u202E\u2066\u061C\u200E\u200F',
  'a\u200Db',
  'a\u200Bb\u00AD',
  'a\uE000b',
  'e\u0301',
  '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}',
  '1\uFE0F\u20E3',
  '\u{1F1EF}\u{1F1F5}',
  '❤\uFE0F',
];

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

  test('one escaping policy spells whole text and measured entries alike', () {
    for (final value in _adversarial) {
      final map = TextDisplayMap(value);
      expect(
        map.displayBetween(0, map.entries.length),
        DisplayText.from(value).value,
        reason: 'protected content and measured layout must agree',
      );
    }
  });

  test('supported grapheme forms stay whole and unescaped', () {
    const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
    const flag = '\u{1F1EF}\u{1F1F5}';
    const keycap = '1\uFE0F\u20E3';

    expect(TextDisplayMap(family).entries.single.display, family);
    expect(TextDisplayMap(flag).entries.single.display, flag);
    expect(TextDisplayMap(keycap).entries.single.display, keycap);
    expect(DisplayText.from('a\u200Db').value, r'a\u{200D}b');
  });
}
