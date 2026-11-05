import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('fixed template accepts raw and formatted supplied values', () async {
    final input = MaskedInput(
      'Code',
      templates: [
        MaskTemplate('code', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
          MaskLiteral('-'),
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ],
    );
    for (final text in ['12', '1-2']) {
      final result = await input.prompt(source: SuppliedAnswer(text));
      final value = (result as Accepted<MaskedValue>).value;
      expect(value.template, 'code');
      expect(value.raw, '12');
      expect(value.formatted, '1-2');
    }
  });
  test('rich typing fills stable slots', () async {
    final input = MaskedInput(
      'Code',
      templates: [
        MaskTemplate('code', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
          MaskLiteral('-'),
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ],
    );
    final out = StringBuffer();
    final result = await input.prompt(
      source: ScriptedInput(Stream.value('12\r'), out),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<MaskedValue>).value.formatted, '1-2');
  });
  test('rich delete clears a slot without shifting the next slot', () async {
    final input = MaskedInput(
      'Code',
      templates: [
        MaskTemplate('code', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
          MaskLiteral('-'),
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ],
    );
    final out = StringBuffer();
    final result = await input.prompt(
      source: ScriptedInput(Stream.value('123\x1b[D\x1b[D\x1b[3~\r9\r'), out),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<MaskedValue>).value.formatted, '1-93');
    expect(out.toString(), contains('Slot 3: 3'));
  });
}
