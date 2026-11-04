import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
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
          source: ScriptedInput(Stream.value('\x03'), StringBuffer()),
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
        source: ScriptedInput(Stream.value('\x1b[C\t\x1b[C\t\t\t\r'), out),
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
        source: ScriptedInput(Stream.value('\x1b[C\t\t\r'), output),
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
