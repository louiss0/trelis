import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Escape from rich numeric editing returns to slider without cancelling',
    () async {
      final input = StreamController<String>();
      final slider = Slider(
        'S',
        minimum: '0',
        maximum: '10',
        step: '1',
        initialValue: '2',
      );
      final result = slider.prompt(
        source: ScriptedInput(
          input.stream,
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      input.add('\t\r9\x1b');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      input.add('\t\r');
      await input.close();
      expect((await result as Accepted<String>).value, '2');
    },
  );
  test(
    'inverted typed range remains editable without swapping endpoints',
    () async {
      final output = StringBuffer();
      final range = RangeSlider('R', minimum: '0', maximum: '10', step: '1');
      final result = await range.prompt(
        source: ScriptedInput(Stream.value('8\r2\r\x7f1\r\r\r'), output),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<(String, String)>).value, ('1', '2'));
      expect(output.toString(), contains('must remain ordered'));
    },
  );
  test('range with no default cannot submit without endpoints', () async {
    final range = RangeSlider('R', minimum: '0', maximum: '10', step: '1');
    expect(
      await range.prompt(
        source: ScriptedInput(Stream.value('\r'), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<InputEnded<(String, String)>>(),
    );
    expect(
      await range.prompt(
        source: ScriptedInput(
          Stream.value('\t\t\t\t\r'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      ),
      isA<InputEnded<(String, String)>>(),
    );
  });
  test(
    'slider numeric editor arrows move the cursor rather than adjust',
    () async {
      final slider = Slider(
        'S',
        minimum: '0',
        maximum: '99',
        step: '1',
        initialValue: '12',
      );
      final result = await slider.prompt(
        source: ScriptedInput(
          Stream.value('\t\r\x1b[D\x7f3\r\t\r'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<String>).value, '32');
    },
  );
  test(
    'slider and range reject concurrent sessions and can be reused',
    () async {
      final slider = Slider('S', minimum: '0', maximum: '2', step: '1');
      final range = RangeSlider('R', minimum: '0', maximum: '2', step: '1');
      final a = StreamController<String>();
      final b = StreamController<String>();
      final first = slider.prompt(
        source: ScriptedInput(
          a.stream,
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      final second = range.prompt(
        source: ScriptedInput(
          b.stream,
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect(
        () => slider.prompt(source: SuppliedAnswer('1')),
        throwsStateError,
      );
      expect(
        () => range.prompt(source: SuppliedAnswer('0,1')),
        throwsStateError,
      );
      a.add('\x03');
      b.add('\x03');
      expect(await first, isA<Interrupted<String>>());
      expect(await second, isA<Interrupted<(String, String)>>());
      await a.close();
      await b.close();
      expect(
        (await slider.prompt(
          source: SuppliedAnswer('1'),
        ) as Accepted<String>).value,
        '1',
      );
      expect(
        (await range.prompt(
          source: SuppliedAnswer('0,1'),
        ) as Accepted<(String, String)>).value,
        ('0', '1'),
      );
    },
  );
  test('rich slider and range help dismisses before interruption', () async {
    for (final run in <Future<Object?> Function(ScriptedInput)>[
      (source) => Slider(
        'S',
        minimum: '0',
        maximum: '2',
        step: '1',
      ).prompt(source: source, mode: PromptMode.rich),
      (source) => RangeSlider(
        'R',
        minimum: '0',
        maximum: '2',
        step: '1',
      ).prompt(source: source, mode: PromptMode.rich),
    ]) {
      final input = StreamController<String>();
      final output = StringBuffer();
      final future = run(
        ScriptedInput(input.stream, output, outputProfile: _richProfile),
      );
      input.add('\x14\x1b');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      input.add('\x03');
      await input.close();
      expect(
        await future,
        anyOf(isA<Interrupted<String>>(), isA<Interrupted<(String, String)>>()),
      );
      expect(output.toString(), contains('Help dismissed'));
    }
  });
  test('range configuration rejects invalid defaults and gap', () {
    expect(
      () => RangeSlider(
        'R',
        minimum: '0',
        maximum: '10',
        step: '1',
        minimumGap: '-1',
      ),
      throwsArgumentError,
    );
    expect(
      () => RangeSlider(
        'R',
        minimum: '0',
        maximum: '10',
        step: '1',
        initialLower: '5',
        initialUpper: '4',
      ),
      throwsArgumentError,
    );
    expect(
      () => RangeSlider(
        'R',
        minimum: '0',
        maximum: '10',
        step: '1',
        initialLower: '2',
      ),
      throwsArgumentError,
    );
  });
  test('range linear default pair is reviewed before submission', () async {
    final out = StringBuffer();
    final range = RangeSlider(
      'R',
      minimum: '0',
      maximum: '10',
      step: '1',
      minimumGap: '2',
      initialLower: '2',
      initialUpper: '5',
    );
    expect(
      await range.prompt(
        source: ScriptedInput(Stream.value('\r\r'), out),
        mode: PromptMode.linear,
      ),
      isA<InputEnded<(String, String)>>(),
    );
    final result = await range.prompt(
      source: ScriptedInput(Stream.value('\r\r\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<(String, String)>).value, ('2', '5'));
    expect(out.toString(), contains('minimum gap 2'));
  });
  test(
    'range cancellation, interruption and unavailable rich mode stay distinct',
    () async {
      final range = RangeSlider('R', minimum: '0', maximum: '10', step: '1');
      expect(
        await range.prompt(
          source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer()),
          mode: PromptMode.linear,
        ),
        isA<Cancelled<(String, String)>>(),
      );
      expect(
        await range.prompt(
          source: ScriptedInput(
            Stream.value('\x03'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        ),
        isA<Interrupted<(String, String)>>(),
      );
      expect(
        await range.prompt(
          source: ScriptedInput(
            Stream.empty(),
            StringBuffer(),
            supportsRich: false,
          ),
          mode: PromptMode.rich,
        ),
        isA<Unavailable<(String, String)>>(),
      );
    },
  );
  test('supplied range validates both endpoints and gap exactly', () async {
    final range = RangeSlider(
      'Window',
      minimum: '0',
      maximum: '1',
      step: '0.1',
      minimumGap: '0.2',
      precision: 1,
      units: 'Hz',
    );
    expect(
      (await range.prompt(
        source: SuppliedAnswer('0.2,0.4'),
      ) as Accepted<(String, String)>).value,
      ('0.2', '0.4'),
    );
    expect(
      await range.prompt(source: SuppliedAnswer('0.2,0.3')),
      isA<Unavailable<(String, String)>>(),
    );
    expect(
      await range.prompt(source: SuppliedAnswer('0.20,0.4')),
      isA<Unavailable<(String, String)>>(),
    );
  });
  test(
    'rich range adjustment respects minimum gap and keeps endpoint roles',
    () async {
      final out = StringBuffer();
      final range = RangeSlider(
        'Window',
        minimum: '0',
        maximum: '10',
        step: '1',
        minimumGap: '2',
        initialLower: '3',
        initialUpper: '5',
      );
      final result = await range.prompt(
        source: ScriptedInput(
          Stream.value('\x1b[C\t\x1b[C\t\t\t\r'),
          out,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<(String, String)>).value, ('3', '6'));
      expect(out.toString(), contains('Lower'));
      expect(out.toString(), contains('Upper'));
    },
  );
  test('linear range reviews both endpoints before accepting', () async {
    final out = StringBuffer();
    final range = RangeSlider('Window', minimum: '0', maximum: '10', step: '1');
    final result = await range.prompt(
      source: ScriptedInput(Stream.value('2\r8\r\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<(String, String)>).value, ('2', '8'));
    expect(out.toString(), contains('Lower'));
    expect(out.toString(), contains('Upper'));
    expect(out.toString(), contains('Submit'));
  });
  test(
    'slider discloses units and rejects excess precision without rounding',
    () async {
      final out = StringBuffer();
      final slider = Slider(
        'Level',
        minimum: '0',
        maximum: '1',
        step: '0.1',
        precision: 1,
        units: 'dB',
      );
      expect(
        await slider.prompt(source: SuppliedAnswer('0.10')),
        isA<Unavailable<String>>(),
      );
      final result = await slider.prompt(
        source: ScriptedInput(Stream.value('0.2\r'), out),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, '0.2');
      expect(out.toString(), contains('dB'));
    },
  );
  test(
    'rich slider adjusts on its focus and submits through visible action',
    () async {
      final output = StringBuffer();
      final slider = Slider(
        'Volume',
        minimum: '0',
        maximum: '1',
        step: '0.2',
        initialValue: '0.4',
      );
      final result = await slider.prompt(
        source: ScriptedInput(
          Stream.value('\x1b[C\t\t\r'),
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<String>).value, '0.6');
      expect(output.toString(), contains('Edit'));
      expect(output.toString(), contains('Submit'));
    },
  );
  test('configured slider default must be on the grid', () async {
    expect(
      () => Slider(
        'Volume',
        minimum: '0',
        maximum: '1',
        step: '0.2',
        initialValue: '0.3',
      ),
      throwsArgumentError,
    );
    final slider = Slider(
      'Volume',
      minimum: '0',
      maximum: '1',
      step: '0.2',
      initialValue: '0.4',
    );
    final result = await slider.prompt(
      source: ScriptedInput(Stream.value('\r'), StringBuffer()),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, '0.4');
  });
  test('Slider accepts an exact on-grid supplied answer', () async {
    final slider = Slider(
      'Volume',
      minimum: '0.1',
      maximum: '1.0',
      step: '0.2',
    );
    final result = await slider.prompt(source: SuppliedAnswer('0.3'));
    expect((result as Accepted<String>).value, '0.3');
    expect(
      await slider.prompt(source: SuppliedAnswer('0.4')),
      isA<Unavailable<String>>(),
    );
  });
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 60, rows: 12),
);
