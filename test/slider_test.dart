import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
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
