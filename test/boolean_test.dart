import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('Confirm shortcut changes draft; Enter submits', () async {
    final output = StringBuffer();
    final result = await Confirm('Proceed?').prompt(
      source: ScriptedInput(Stream.value('y\r'), output),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<bool>).value, isTrue);
    expect(output.toString(), contains('No'));
    expect(output.toString(), contains('Yes'));
  });
  test('rich draft changes alone do not submit', () async {
    for (final run in <Future<PromptResult<bool>> Function()>[
      () => Confirm('Confirm').prompt(
        source: ScriptedInput(Stream.value('y'), StringBuffer()),
        mode: PromptMode.rich,
      ),
      () => Checkbox('Check').prompt(
        source: ScriptedInput(Stream.value(' '), StringBuffer()),
        mode: PromptMode.rich,
      ),
      () => Toggle('Toggle').prompt(
        source: ScriptedInput(Stream.value(' '), StringBuffer()),
        mode: PromptMode.rich,
      ),
    ]) {
      expect(await run(), isA<InputEnded<bool>>());
    }
  });
  test('checkbox and toggle announce state and submit only on Enter', () async {
    for (final prompt in [Checkbox('Check').prompt, Toggle('Switch').prompt]) {
      final output = StringBuffer();
      final result = await prompt(
        source: ScriptedInput(Stream.value(' \r'), output),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<bool>).value, isTrue);
      expect(output.toString(), anyOf(contains('unchecked'), contains('off')));
      expect(output.toString(), anyOf(contains('checked'), contains('on')));
    }
  });
  test('linear answers and empty lines use explicit defaults', () async {
    for (final prompt in [
      Confirm('Confirm', initialValue: true).prompt,
      Checkbox('Check', initialValue: true).prompt,
      Toggle('Switch', initialValue: true).prompt,
    ]) {
      final out = StringBuffer();
      expect(
        (await prompt(
          source: ScriptedInput(Stream.value('\r'), out),
          mode: PromptMode.linear,
        ) as Accepted<bool>).value,
        isTrue,
      );
      expect(out.toString(), contains('Default:'));
      expect(
        (await prompt(
          source: ScriptedInput(Stream.value('no\r'), StringBuffer()),
          mode: PromptMode.linear,
        ) as Accepted<bool>).value,
        isFalse,
      );
      expect(
        await prompt(
          source: ScriptedInput(Stream.value(''), StringBuffer()),
          mode: PromptMode.linear,
        ),
        isA<InputEnded<bool>>(),
      );
    }
  });
  test('linear commands, literals and interruption remain distinct', () async {
    Future<PromptResult<bool>> run(String input) => Confirm('Confirm').prompt(
      source: ScriptedInput(Stream.value(input), StringBuffer()),
      mode: PromptMode.linear,
    );
    expect(await run('/cancel\r'), isA<Cancelled<bool>>());
    expect(await run('/cancel'), isA<InputEnded<bool>>());
    expect(await run('\x03'), isA<Interrupted<bool>>());
    expect(await run('\x1b[200~/cancel\x1b[201~\r'), isA<InputEnded<bool>>());
    expect((await run('/help\ryes\r') as Accepted<bool>).value, isTrue);
  });
  test('invalid linear input is retained and can be corrected', () async {
    final output = StringBuffer();
    final result = await Confirm('Proceed').prompt(
      source: ScriptedInput(Stream.value('x\r\x7fyes\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<bool>).value, isTrue);
    expect(output.toString(), contains('Current text: x'));
    expect(output.toString(), contains('Enter yes/y or no/n'));
  });
  test('rich cancellation and configured default are distinct', () async {
    final output = StringBuffer();
    final prompt = Confirm('Proceed', initialValue: true);
    final result = await prompt.prompt(
      source: ScriptedInput(Stream.value('n\x03'), output),
      mode: PromptMode.rich,
    );
    expect(result, isA<Interrupted<bool>>());
    expect(output.toString(), contains('Default: Yes'));
    expect(
      await prompt.prompt(
        source: ScriptedInput(Stream.value('\r'), StringBuffer()),
        mode: PromptMode.rich,
      ),
      isA<Accepted<bool>>().having((x) => x.value, 'value', isTrue),
    );
    expect(
      await prompt.prompt(
        source: ScriptedInput(Stream.value('\x1bx'), StringBuffer()),
        mode: PromptMode.rich,
      ),
      isA<Cancelled<bool>>(),
    );
  });
  test(
    'supplied values are literal and capability failures do not render',
    () async {
      final prompt = Toggle('Switch');
      expect(
        (await prompt.prompt(
          source: SuppliedAnswer('yes'),
        ) as Accepted<bool>).value,
        isTrue,
      );
      expect(
        await prompt.prompt(source: SuppliedAnswer('/cancel')),
        isA<Unavailable<bool>>(),
      );
      final out = StringBuffer();
      expect(
        await prompt.prompt(
          source: ScriptedInput(Stream.value('\r'), out, supportsRich: false),
          mode: PromptMode.rich,
        ),
        isA<Unavailable<bool>>(),
      );
      expect(out.toString(), isEmpty);
    },
  );
}
