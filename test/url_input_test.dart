import 'dart:async';
import 'dart:isolate';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

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
          source: ScriptedInput(
            Stream.value('$invalid\n\u0003'),
            out,
            outputProfile: mode == PromptMode.rich
                ? _richProfile
                : const OutputProfile(),
          ),
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

  test('a URL session hides its draft while retaining its approved host interpretation', () async {
    const url = 'https://faß.de/private-path?private-query=73';
    final output = StringBuffer();
    final transcript = TextInputTranscript();
    final input = StreamController<String>();
    final profile = OutputProfile(
      cursor: CapabilitySupport.supported,
      geometry: OutputGeometry.fixed(columns: 80, rows: 24),
    );

    final result = await TerminalSession.run(
      (session) async {
        final spinner = Spinner('Network');
        spinner.start(session: session);
        final pending = URLInput(
          'URL',
          allowedSchemes: {'https'},
        ).prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        input.add(url);
        await Future<void>.delayed(Duration.zero);
        spinner.update('waiting for entry');
        input.add('\r');
        await input.close();
        spinner.dispose();
        return await pending;
      },
      source: ScriptedInput(
        input.stream,
        output,
        outputProfile: profile,
        transcript: transcript,
      ),
      mode: PromptMode.linear,
    );

    expect((result as Accepted<String>).value, url);
    expect(output.toString(), contains('Network: waiting for entry'));
    expect(
      output.toString(),
      contains('Unicode: faß.de; ASCII: xn--fa-hia.de'),
    );
    expect(output.toString(), isNot(contains('private-path')));
    expect(output.toString(), isNot(contains('private-query')));
    expect(output.toString(), isNot(contains('Accepted URL:')));
    expect(transcript.currentView!.text, '<private entry>');
    expect(transcript.currentView!.caret, 0);
    expect(transcript.events.map((event) => event.text), isNot(contains(url)));
  });

  test(
    'rich and linear F1 help describes URL entry without the draft',
    () async {
      for (final mode in [PromptMode.rich, PromptMode.linear]) {
        final out = StringBuffer();
        final result = await URLInput('URL', allowedSchemes: {'https'}).prompt(
          source: ScriptedInput(
            Stream.value('private-draft-path\x1bOP\r\x03'),
            out,
            outputProfile: mode == PromptMode.rich
                ? _richProfile
                : const OutputProfile(),
          ),
          mode: mode,
        );

        expect(result, isA<Interrupted<String>>());
        expect(
          out.toString(),
          contains('Help: Enter validates an absolute URL'),
          reason: '${mode.name} help is URL-specific, not generic editor help',
        );
        expect(
          out.toString(),
          isNot(contains('private-draft-path')),
          reason: 'help must not disclose a hidden draft',
        );
      }
    },
  );

  test('/help is literal URL entry data rather than a command', () async {
    final out = StringBuffer();
    final result = await URLInput('URL', allowedSchemes: {'https'}).prompt(
      source: ScriptedInput(Stream.value('/help\r\x03'), out),
      mode: PromptMode.linear,
    );

    expect(result, isA<Interrupted<String>>());
    expect(
      out.toString(),
      isNot(contains('Help: Enter validates an absolute URL')),
      reason: 'a hidden draft treats /help as answer data; F1 is the route',
    );
    expect(out.toString(), contains('Enter a valid absolute URL'));
  });
}
