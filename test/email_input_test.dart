import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'linear email entry displays labeled IDNA domain interpretation',
    () async {
      final out = StringBuffer();
      final result = await EmailInput('Email').prompt(
        source: ScriptedInput(Stream.value('Case@faß.de\n'), out),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, 'Case@faß.de');
      expect(out.toString(), contains('Unicode: faß.de; ASCII: xn--fa-hia.de'));
    },
  );
  test('SMTP grammar, IDNA, SMTPUTF8 and transport limits', () async {
    final ascii = EmailInput('Email');
    for (final value in [
      'Case+tag@bücher.example',
      'x@[192.0.2.1]',
      'x@[IPv6:2001:db8::1]',
      '"a@b"@example.com',
    ]) {
      expect(
        await ascii.prompt(source: SuppliedAnswer(value)),
        isA<Accepted<String>>(),
        reason: value,
      );
    }
    for (final value in [
      'Name <x@example.com>',
      'x@example.com, y@example.com',
      'a..b@example.com',
      'é@example.com',
      'x@-bad.example',
      '${'a' * 65}@example.com',
      'x@[192.0.2.999]',
    ]) {
      expect(
        await ascii.prompt(source: SuppliedAnswer(value)),
        isA<Unavailable<String>>(),
        reason: value,
      );
    }
    expect(
      await EmailInput(
        'Email',
        smtpUtf8: true,
      ).prompt(source: SuppliedAnswer('é@example.com')),
      isA<Accepted<String>>(),
    );
  });
  test(
    'EmailInput preserves a quoted local part and domain spelling',
    () async {
      final result = await EmailInput('Email')
          .prompt(source: SuppliedAnswer('"Case Sensitive"@example.com'));
      expect(
        (result as Accepted<String>).value,
        '"Case Sensitive"@example.com',
      );
    },
  );
}
