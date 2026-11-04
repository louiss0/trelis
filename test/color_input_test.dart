import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('modern RGB preserves fractional channels and alpha', () async {
    final result = await ColorInput('Color')
        .prompt(source: SuppliedAnswer('rgb(12.5 20 30 / 25%)'));
    final value = (result as Accepted<ColorValue?>).value!;
    expect(value.red, closeTo(12.5 / 255, 1e-12));
    expect(value.alpha, .25);
  });
  test('supplied alpha-last hex preserves source and transparency', () async {
    final result = await ColorInput('Color')
        .prompt(source: SuppliedAnswer('#1234'));
    final value = (result as Accepted<ColorValue?>).value!;
    expect(value.source, '#1234');
    expect(value.red, closeTo(17 / 255, 1e-12));
    expect(value.alpha, closeTo(68 / 255, 1e-12));
  });
}
