import 'package:prompty/prompty.dart';
import 'package:characters/characters.dart';
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
  test(
    'declared raw and formatted interpretations retain provenance',
    () async {
      final templates = [
        MaskTemplate('code', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
          MaskLiteral('-'),
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ];
      final raw = await MaskedInput(
        'Code',
        templates: templates,
        interpretation: MaskInterpretation.raw,
      ).prompt(source: SuppliedAnswer('12'));
      expect(raw, isA<Accepted<MaskedValue>>());
      expect(
        (raw as Accepted<MaskedValue>).value.interpretation,
        MaskInterpretation.raw,
      );
      final formatted = await MaskedInput(
        'Code',
        templates: templates,
        interpretation: MaskInterpretation.formatted,
      ).prompt(source: SuppliedAnswer('1-2'));
      expect(
        (formatted as Accepted<MaskedValue>).value.interpretation,
        MaskInterpretation.formatted,
      );
      expect(
        await MaskedInput(
          'Code',
          templates: templates,
          interpretation: MaskInterpretation.raw,
        ).prompt(source: SuppliedAnswer('1-2')),
        isA<Unavailable<MaskedValue>>(),
      );
    },
  );

  test(
    'adaptive ambiguity requires explicit linear template selection',
    () async {
      final input = MaskedInput(
        'Code',
        templates: [
          MaskTemplate('pair', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
          MaskTemplate('dash', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskLiteral('-'),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
        ],
      );
      final out = StringBuffer();
      final result = await input.prompt(
        source: ScriptedInput(Stream.value('12\r/template\r2\r/done\r'), out),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<MaskedValue>).value.template, 'dash');
      expect(out.toString(), contains('1. pair'));
      expect(out.toString(), contains('2. dash'));
    },
  );

  test(
    'adaptive rich ambiguity preserves draft and selects by number',
    () async {
      final input = MaskedInput(
        'Code',
        templates: [
          MaskTemplate('pair', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
          MaskTemplate('dash', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskLiteral('-'),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
        ],
      );
      final out = StringBuffer();
      final result = await input.prompt(
        source: ScriptedInput(Stream.value('12\r2\r'), out),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<MaskedValue>).value.formatted, '1-2');
      expect(out.toString(), contains('Draft preserved: 12'));
      expect(out.toString(), contains('Selected template: dash'));
    },
  );

  test(
    'adaptive rich unique selection supports stable grapheme editing',
    () async {
      final input = MaskedInput(
        'Code',
        templates: [
          MaskTemplate('pair', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
          MaskTemplate('dash', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskLiteral('-'),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
        ],
      );
      final out = StringBuffer();
      final result = await input.prompt(
        source: ScriptedInput(Stream.value('1-2\r\x7f3\r'), out),
        mode: PromptMode.rich,
      );
      expect(out.toString(), isNot(contains('Invalid')));
      expect((result as Accepted<MaskedValue>).value.formatted, '1-3');
    },
  );

  test(
    'adaptive slot correction reopens ambiguity without losing data',
    () async {
      final input = MaskedInput(
        'Code',
        templates: [
          MaskTemplate('pair', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
          MaskTemplate('dash', [
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
            MaskLiteral('-'),
            MaskSlot('digit', (s) => '0123456789'.contains(s)),
          ]),
        ],
        initialValue: MaskedValue('dash', ['1', '2'], '1-2'),
      );
      final out = StringBuffer();
      final result = await input.prompt(
        source: ScriptedInput(
          Stream.value('/edit\r2\r3\r/template\r1\r/done\r'),
          out,
        ),
        mode: PromptMode.linear,
      );
      final value = (result as Accepted<MaskedValue>).value;
      expect(value.template, 'pair');
      expect(value.raw, '13');
      expect(out.toString(), contains('Ambiguity reopened'));
    },
  );

  test(
    'adaptive linear cannot submit after clearing a required slot',
    () async {
      final templates = [
        MaskTemplate('pair', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
        MaskTemplate('single', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ];
      final input = MaskedInput(
        'Code',
        templates: templates,
        initialValue: MaskedValue('pair', ['1', '2'], '12'),
      );
      final out = StringBuffer();
      final result = await input.prompt(
        source: ScriptedInput(Stream.value('/edit\r2\r\r/done\r'), out),
        mode: PromptMode.linear,
      );
      expect(result, isA<InputEnded<MaskedValue>>());
      expect(out.toString(), contains('Required slots are incomplete'));
    },
  );

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
  test('accepted default is editable in rich and linear modes', () async {
    final templates = [
      MaskTemplate('code', [
        MaskSlot('digit', (s) => '0123456789'.contains(s)),
        MaskLiteral('-'),
        MaskSlot('digit', (s) => '0123456789'.contains(s)),
      ]),
    ];
    final input = MaskedInput(
      'Code',
      templates: templates,
      initialValue: MaskedValue('code', ['1', '2'], '1-2'),
    );
    for (final mode in [PromptMode.rich, PromptMode.linear]) {
      final result = await input.prompt(
        source: ScriptedInput(
          Stream.value(
            mode == PromptMode.rich ? '\x7f3\r' : '/value\r\x7f3\r/done\r',
          ),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<MaskedValue>).value.formatted, '1-3');
    }
  });
  test('linear slot correction preserves other slots', () async {
    final templates = [
      MaskTemplate('code', [
        MaskSlot('digit', (s) => '0123456789'.contains(s)),
        MaskLiteral('-'),
        MaskSlot('digit', (s) => '0123456789'.contains(s)),
        MaskSlot('digit', (s) => '0123456789'.contains(s)),
      ]),
    ];
    final input = MaskedInput(
      'Code',
      templates: templates,
      initialValue: MaskedValue('code', ['1', '2', '3'], '1-23'),
    );
    final out = StringBuffer();
    final result = await input.prompt(
      source: ScriptedInput(Stream.value('/edit\r2\r9\r/done\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<MaskedValue>).value.formatted, '1-93');
    expect(out.toString(), contains('Slot 3: 3'));
  });
  test('rich oversized paste is atomic and preserves its draft', () async {
    final input = MaskedInput(
      'Code',
      templates: [
        MaskTemplate('code', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
          MaskLiteral('-'),
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ],
      initialValue: MaskedValue('code', ['1', '2'], '1-2'),
    );
    final out = StringBuffer();
    final result = await input.prompt(
      source: ScriptedInput(Stream.value('\x1b[200~9-8-7\x1b[201~\r'), out),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<MaskedValue>).value.formatted, '1-2');
    expect(
      out.toString(),
      contains('Paste rejected: exceeds template capacity.'),
    );
    expect(out.toString(), contains('Draft preserved: 9-8-7'));
  });

  test('rich combining mark joins the prior grapheme slot', () async {
    final input = MaskedInput(
      'Text',
      templates: [
        MaskTemplate('text', [
          MaskSlot('grapheme', (s) => s.characters.length == 1),
          MaskSlot('grapheme', (s) => s.characters.length == 1),
        ]),
      ],
    );
    final result = await input.prompt(
      source: ScriptedInput(Stream.value('e\u0301x\r'), StringBuffer()),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<MaskedValue>).value.slots, ['e\u0301', 'x']);
  });
  test(
    'rich formatted paste retains its interpretation on submission',
    () async {
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
      final result = await input.prompt(
        source: ScriptedInput(
          Stream.value('\x1b[200~1-2\x1b[201~\r'),
          StringBuffer(),
        ),
        mode: PromptMode.rich,
      );
      expect(
        (result as Accepted<MaskedValue>).value.interpretation,
        MaskInterpretation.formatted,
      );
    },
  );

  test('rich formatted paste fills slots atomically', () async {
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
    final result = await input.prompt(
      source: ScriptedInput(
        Stream.value('\x1b[200~1-2\x1b[201~\r'),
        StringBuffer(),
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<MaskedValue>).value.raw, '12');
  });
}
