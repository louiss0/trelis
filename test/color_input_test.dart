import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('invalid values are not repaired or clamped', () async {
    final input = ColorInput('Color');
    for (final invalid in [
      'rgb(1. 2 3)',
      'rgb(1\u00a02 3)',
      '#12345',
      'rgb(256 0 0)',
      'rgb(-1 0 0)',
      'rgb(1 2 3 / 101%)',
      'rgb(10%, 5, 0%)',
      'hsl(10 101% 50%)',
      'hsl(0 1% -1%)',
      'hsl(0 50% 50% / -1)',
      'currentcolor',
      'var(--c)',
      'color(display-p3 1 0 0)',
      'rgb(from red r g b)',
      'rgb(calc(1) 0 0)',
    ]) {
      expect(
        await input.prompt(source: SuppliedAnswer(invalid)),
        isA<Unavailable>(),
        reason: invalid,
      );
    }
    expect(
      () => ColorInput('Color', initialValue: 'rgb(999 0 0)'),
      throwsArgumentError,
    );
  });
  for (final mode in [PromptMode.rich, PromptMode.linear]) {
    test('$mode retains an invalid draft for correction', () async {
      final out = StringBuffer();
      final result = await ColorInput('Color').prompt(
        source: ScriptedInput(
          Stream.value(
            'rgb(256 0 0)\r\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f#fff\r',
          ),
          out,
        ),
        mode: mode,
      );
      expect((result as Accepted<ColorValue?>).value!.source, '#fff');
      expect(out.toString(), contains('Enter a valid sRGB color'));
    });
  }
  for (final mode in [PromptMode.rich, PromptMode.linear]) {
    test('$mode gives textual alpha and cyclic hue preview', () async {
      final out = StringBuffer();
      final result = await ColorInput(
        'Color',
        initialValue: 'hsl(480deg 100% 50% / .5)',
      ).prompt(source: ScriptedInput(Stream.value('\r'), out), mode: mode);
      expect(result, isA<Accepted<ColorValue?>>());
      expect(out.toString(), contains('Hue: 120'));
      expect(out.toString(), contains('Alpha: 0.5'));
      expect(out.toString(), contains('approximate'));
    });
  }
  test('named transparent is a value distinct from optional absence', () async {
    final input = ColorInput('Color', required: false);
    final transparent = (await input.prompt(
      source: SuppliedAnswer('transparent'),
    ) as Accepted<ColorValue?>).value!;
    expect(transparent.alpha, 0);
    final empty = (await input.prompt(
      source: SuppliedAnswer(''),
    ) as Accepted<ColorValue?>).value;
    expect(empty, isNull);
    final named = (await input.prompt(
      source: SuppliedAnswer('RebeccaPurple'),
    ) as Accepted<ColorValue?>).value!;
    expect(named.red, closeTo(102 / 255, 1e-12));
  });
  test('HSL wraps hue while retaining expression and alpha', () async {
    final result = await ColorInput('Color')
        .prompt(source: SuppliedAnswer('hsl(480deg 100% 50% / .5)'));
    final value = (result as Accepted<ColorValue?>).value!;
    expect(value.source, 'hsl(480deg 100% 50% / .5)');
    expect(value.red, closeTo(0, 1e-12));
    expect(value.green, closeTo(1, 1e-12));
    expect(value.alpha, .5);
  });
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
