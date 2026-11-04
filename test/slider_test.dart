import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
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
