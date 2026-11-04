import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('hidden literal entry needs separate submission', () async {
    final output = StringBuffer();
    final result = await Password('Password').prompt(
      source: ScriptedInput(Stream.value('/cancel\rsubmit\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, '/cancel');
    expect('/cancel'.allMatches(output.toString()).length, 1);
  });
  test('validation does not disclose caller error or thrown secret', () async {
    final output = StringBuffer();
    final result =
        await Password(
          'Password',
          validate: (value) => throw StateError(value),
        ).prompt(
          source: ScriptedInput(Stream.value('temporary\rsubmit\r'), output),
          mode: PromptMode.linear,
        );
    expect(result, isA<Unavailable<String>>());
    expect(output.toString(), isNot(contains('temporary')));
  });
  test(
    'linear actions advertise the shared help and cancellation commands',
    () async {
      final output = StringBuffer();
      final result = await Password('Password').prompt(
        source: ScriptedInput(Stream.value('x\r/help\r/cancel\r'), output),
        mode: PromptMode.linear,
      );
      expect(result, isA<Cancelled<String>>());
      expect(output.toString(), contains('/help'));
      expect(output.toString(), contains('/cancel'));
    },
  );
  test('masked prefill makes the disclosure explicit before editing', () async {
    final output = StringBuffer();
    final result = await Password('Password', initialValue: 'abc', mask: true)
        .prompt(
          source: ScriptedInput(Stream.value('\rsubmit\r'), output),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'abc');
    expect(output.toString(), contains('prefill'));
    expect(output.toString(), contains('length'));
    expect(output.toString(), isNot(contains('abc')));
  });
  for (final mode in [PromptMode.rich, PromptMode.linear]) {
    test(
      '$mode preserves failed validation for editing without revealing it',
      () async {
        final output = StringBuffer();
        final result =
            await Password(
              'Password',
              validate: (v) => v == 'ab' ? null : 'leak: $v',
            ).prompt(
              source: ScriptedInput(
                Stream.value('a\rsubmit\redit\rb\rsubmit\r'),
                output,
              ),
              mode: mode,
            );
        expect((result as Accepted<String>).value, 'ab');
        expect(output.toString(), isNot(contains('leak:')));
        expect(output.toString(), contains('requirements'));
      },
    );
    test('$mode clear discards prefill and EOF never accepts', () async {
      final result = await Password('Password', initialValue: 'old').prompt(
        source: ScriptedInput(
          Stream.value('\rclear\rnew\rsubmit\r'),
          StringBuffer(),
        ),
        mode: mode,
      );
      expect((result as Accepted<String>).value, 'new');
      expect(
        await Password('Password', initialValue: 'old').prompt(
          source: ScriptedInput(Stream.value('\r'), StringBuffer()),
          mode: mode,
        ),
        isA<InputEnded<String>>(),
      );
    });
  }
  test('empty action and partial EOF never submit a retained secret', () async {
    expect(
      await Password(
        'Password',
        initialValue: 'old',
      ).prompt(source: ScriptedInput(Stream.value('\r\rsub'), StringBuffer())),
      isA<InputEnded<String>>(),
    );
  });
  test('required empty input cannot be submitted', () async {
    final output = StringBuffer();
    final result = await Password(
      'Password',
      required: true,
    ).prompt(source: ScriptedInput(Stream.value('\rsubmit\rcancel\r'), output));
    expect(result, isA<Cancelled<String>>());
    expect(output.toString(), contains('requirements'));
  });
  test(
    'supplied secrets bypass command syntax and failed validation is generic',
    () async {
      expect(
        (await Password(
          'Password',
        ).prompt(source: SuppliedAnswer('/cancel')) as Accepted<String>).value,
        '/cancel',
      );
      final result = await Password(
        'Password',
        validate: (v) => v,
      ).prompt(source: SuppliedAnswer('disposable'));
      expect(
        (result as Unavailable<String>).reason,
        isNot(contains('disposable')),
      );
    },
  );
}
