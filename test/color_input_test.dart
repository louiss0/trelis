import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('invalidated draft explicitly withdraws previous preview', () async {
    final controller = StreamController<String>();
    final out = StringBuffer();
    final future = ColorInput('Color', initialValue: '#fff').prompt(
      source: ScriptedInput(controller.stream, out),
      mode: PromptMode.linear,
    );
    controller.add('x');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(out.toString(), contains('Preview unavailable'));
    controller.add('/cancel\r');
    await controller.close();
    await future;
  });
  test('accepted source can be supplied as an editable default', () async {
    final source = 'rgba(12.345678 10 20 / 0.123456789)';
    final value = (await ColorInput(
      'Color',
    ).prompt(source: SuppliedAnswer(source)) as Accepted<ColorValue?>).value!;
    final result = await ColorInput('Color', initialValue: value.source).prompt(
      source: ScriptedInput(Stream.value('\r'), StringBuffer()),
      mode: PromptMode.rich,
    );
    final again = (result as Accepted<ColorValue?>).value!;
    expect(again.source, source);
    expect(again.red, value.red);
    expect(again.alpha, value.alpha);
  });
  test('cancellation and unsupported rich preserve prompt semantics', () async {
    expect(
      await ColorInput('Color').prompt(
        source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer()),
        mode: PromptMode.linear,
      ),
      isA<Cancelled<ColorValue?>>(),
    );
    final out = StringBuffer();
    expect(
      await ColorInput('Color').prompt(
        source: ScriptedInput(Stream.value('red\r'), out, supportsRich: false),
        mode: PromptMode.rich,
      ),
      isA<Unavailable<ColorValue?>>(),
    );
    expect(out.toString(), isEmpty);
  });
  test('normalized hue is previewed before submission', () async {
    final controller = StreamController<String>();
    final out = StringBuffer();
    final future = ColorInput('Color', initialValue: 'hsl(480 100% 50%)')
        .prompt(
          source: ScriptedInput(controller.stream, out),
          mode: PromptMode.linear,
        );
    await Future<void>.delayed(Duration.zero);
    expect(out.toString(), contains('Hue: 120'));
    controller.add('\r');
    expect(await future, isA<Accepted<ColorValue?>>());
    await controller.close();
  });
  test('declared hex, legacy and modern forms are interpreted', () async {
    final input = ColorInput('Color');
    final examples = <String, List<double>>{
      '#f00': [1, 0, 0, 1],
      '#ff000080': [1, 0, 0, 128 / 255],
      'rgb(100% 0 0 / 50%)': [1, 0, 0, .5],
      'rgba(255, 0, 0, .25)': [1, 0, 0, .25],
      'rgb(100%, 0%, 0%)': [1, 0, 0, 1],
      'hsl(-240, 100%, 50%)': [0, 1, 0, 1],
      'hsla(.5turn, 100%, 50%, 25%)': [0, 1, 1, .25],
      'hsl(200grad 100% 50%)': [0, 1, 1, 1],
      'blue': [0, 0, 1, 1],
    };
    for (final entry in examples.entries) {
      final result = await input.prompt(source: SuppliedAnswer(entry.key));
      final value = (result as Accepted<ColorValue?>).value!;
      expect(value.source, entry.key);
      for (final (actual, expected) in [
        (value.red, entry.value[0]),
        (value.green, entry.value[1]),
        (value.blue, entry.value[2]),
        (value.alpha, entry.value[3]),
      ]) {
        expect(actual, closeTo(expected, 1e-12), reason: entry.key);
      }
    }
  });
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
