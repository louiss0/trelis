import 'dart:isolate';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('URL and email accept concurrent IDNA prompts in isolates', () async {
    final results = await Future.wait([
      for (var i = 0; i < 40; i++) ...[
        Isolate.run(
          () => URLInput(
            'URL',
            allowedSchemes: {'https'},
          ).prompt(source: SuppliedAnswer('https://faß.de/$i')),
        ),
        Isolate.run(
          () =>
              EmailInput('Email')
                  .prompt(source: SuppliedAnswer('user$i@bücher.example')),
        ),
      ],
    ]);
    expect(results, everyElement(isA<Accepted<String>>()));
  });

  test('URL displays labeled nontransitional IDNA interpretations', () async {
    final out = StringBuffer();
    final result = await URLInput('URL', allowedSchemes: {'https'}).prompt(
      source: ScriptedInput(Stream.value('https://faß.de/\n'), out),
      mode: PromptMode.linear,
    );
    expect(result, isA<Accepted<String>>());
    expect(out.toString(), contains('Unicode: faß.de; ASCII: xn--fa-hia.de'));
  });
  test(
    'rich and linear reject credentials without disclosing the draft',
    () async {
      for (final mode in [PromptMode.rich, PromptMode.linear]) {
        final out = StringBuffer();
        final invalid = [
          'https://',
          'private-name',
          ':',
          'sensitive',
          '@',
          'example.com',
        ].join();
        final result = await URLInput('URL', allowedSchemes: {'https'}).prompt(
          source: ScriptedInput(Stream.value('$invalid\n\u0003'), out),
          mode: mode,
        );
        expect(result, isA<Interrupted<String>>());
        expect(out.toString(), isNot(contains('sensitive')));
        expect(out.toString(), isNot(contains('private-name')));
      }
    },
  );
  test(
    'URL rejects repairs and credentials while preserving query at-signs',
    () async {
      final input = URLInput('URL', allowedSchemes: {'https'});
      final withCredentials = [
        'https://',
        'user',
        ':',
        'secret',
        '@',
        'example.com/',
      ].join();
      for (final value in [
        withCredentials,
        'https://@example.com/',
        'https:example.com',
        'https://example.com/%xx',
        'https://example.com/a b',
        'https://example.com\\foo',
        'https://example.com:99999/',
      ]) {
        final result = await input.prompt(source: SuppliedAnswer(value));
        expect(result, isA<Unavailable<String>>(), reason: value);
        expect(
          (result as Unavailable<String>).reason,
          isNot(contains('secret')),
        );
      }
      expect(
        await input.prompt(
          source: SuppliedAnswer('https://example.com/?a=b@c'),
        ),
        isA<Accepted<String>>(),
      );
    },
  );
  test(
    'URL applies NFC and Bidi rules to Unicode and Punycode hosts',
    () async {
      final input = URLInput('URL', allowedSchemes: {'https'});
      for (final value in [
        'https://fa\u0308.de/',
        'https://솣.example/',
        'https://꧐Ӏ\u1BAA\u08F6.눵/',
      ]) {
        expect(
          await input.prompt(source: SuppliedAnswer(value)),
          isA<Accepted<String>>(),
          reason: value,
        );
      }
      for (final value in [
        'https://aא.example/',
        'https://xn--a-0hc.example/',
        'https://0a.xn--4db/',
      ]) {
        expect(
          await input.prompt(source: SuppliedAnswer(value)),
          isA<Unavailable<String>>(),
          reason: value,
        );
      }
    },
  );

  test('URL DNS names use nontransitional IDNA validation', () async {
    final input = URLInput('URL', allowedSchemes: {'https'});
    for (final value in [
      'https://faß.de/',
      'https://xn--fa-hia.de/',
      'https://bücher.example/',
    ]) {
      expect(
        await input.prompt(source: SuppliedAnswer(value)),
        isA<Accepted<String>>(),
        reason: value,
      );
    }
    for (final value in [
      'https://a\u200db.example/',
      'https://xn--.example/',
      'https://-bad.example/',
    ]) {
      expect(
        await input.prompt(source: SuppliedAnswer(value)),
        isA<Unavailable<String>>(),
        reason: value,
      );
    }
  });
  test('URLInput preserves an accepted absolute HTTPS spelling', () async {
    final result = await URLInput(
      'URL',
      allowedSchemes: {'https'},
    ).prompt(source: SuppliedAnswer('https://example.com/a%2Fb?x=One'));
    expect(result, isA<Accepted<String>>());
    expect(
      (result as Accepted<String>).value,
      'https://example.com/a%2Fb?x=One',
    );
  });
}
